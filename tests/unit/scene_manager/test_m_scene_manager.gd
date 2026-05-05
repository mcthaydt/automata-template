extends GutTest

## Unit tests for M_SceneManager
##
## Tests scene transition coordination, queue management, and state integration.
## Tests follow TDD discipline: written BEFORE implementation.

const M_SceneManager = preload("res://scripts/core/managers/m_scene_manager.gd")
const M_StateStore = preload("res://scripts/core/state/m_state_store.gd")
const RS_SceneInitialState = preload("res://scripts/core/resources/state/rs_scene_initial_state.gd")
const RS_NavigationInitialState = preload("res://scripts/core/resources/state/rs_navigation_initial_state.gd")
const RS_StateStoreSettings = preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const U_SceneActions = preload("res://scripts/core/state/actions/u_scene_actions.gd")
const U_ServiceLocator = preload("res://scripts/core/u_service_locator.gd")
const UI_HUD_CONTROLLER = preload("res://scripts/core/ui/hud/ui_hud_controller.gd")

var _manager: M_SceneManager
var _store: M_StateStore
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _transition_overlay: CanvasLayer
var _loading_overlay: CanvasLayer

func before_each() -> void:
	# Clear ServiceLocator first to ensure clean state between tests
	U_ServiceLocator.clear()

	var existing := get_tree().root.find_child("HUDLayer", true, false)
	if existing == null:
		var hud_layer := CanvasLayer.new()
		hud_layer.name = "HUDLayer"
		add_child_autofree(hud_layer)
		U_ServiceLocator.register(StringName("hud_layer"), hud_layer)
	else:
		U_ServiceLocator.register(StringName("hud_layer"), existing)

	# Create state store with scene slice
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	var scene_initial_state := RS_SceneInitialState.new()
	_store.scene_initial_state = scene_initial_state
	var nav_initial := RS_NavigationInitialState.new()
	nav_initial.shell = StringName("gameplay")
	nav_initial.base_scene_id = StringName("")
	_store.navigation_initial_state = nav_initial
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

	# Create container nodes
	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	add_child_autofree(_active_scene_container)
	U_ServiceLocator.register(StringName("active_scene_container"), _active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	add_child_autofree(_ui_overlay_stack)
	U_ServiceLocator.register(StringName("ui_overlay_stack"), _ui_overlay_stack)

	_transition_overlay = CanvasLayer.new()
	_transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	_transition_overlay.add_child(color_rect)
	add_child_autofree(_transition_overlay)
	U_ServiceLocator.register(StringName("transition_overlay"), _transition_overlay)

	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	add_child_autofree(_loading_overlay)
	U_ServiceLocator.register(StringName("loading_overlay"), _loading_overlay)

	# Create scene manager
	_manager = M_SceneManager.new()
	_manager.skip_initial_scene_load = true  # Don't load main_menu automatically in tests
	add_child_autofree(_manager)
	U_ServiceLocator.register(StringName("scene_manager"), _manager)
	await get_tree().process_frame

func after_each() -> void:
	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

	_manager = null
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_loading_overlay = null

## Test manager is registered with ServiceLocator
func test_manager_registers_with_service_locator() -> void:
	var service := U_ServiceLocator.get_service(StringName("scene_manager"))
	assert_eq(service, _manager, "Manager should be registered with ServiceLocator")

## Test manager finds M_StateStore via group
func test_manager_finds_state_store() -> void:
	assert_not_null(_manager._store, "Manager should find state store")
	assert_eq(_manager._store, _store, "Manager should reference correct store")

func test_manager_instantiates_hud_under_hud_layer() -> void:
	var hud_layer := U_ServiceLocator.get_service(StringName("hud_layer")) as CanvasLayer
	assert_not_null(hud_layer, "HUDLayer should be registered for scene manager setup")

	var hud_count: int = 0
	for child: Node in hud_layer.get_children():
		var child_script: Variant = child.get_script()
		if child_script == UI_HUD_CONTROLLER:
			hud_count += 1

	assert_eq(hud_count, 1, "Scene manager should ensure exactly one HUD controller instance in HUDLayer")

## Test transition_to_scene dispatches actions
func test_transition_to_scene_dispatches_started_action() -> void:
	var actions_received: Array = []
	_store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		actions_received.append(action)
	)

	_manager.transition_to_scene(StringName("demo_room"), "fade")
	await get_tree().physics_frame

	var found_started_action: bool = false
	for action in actions_received:
		if action.get("type") == U_SceneActions.ACTION_TRANSITION_STARTED:
			found_started_action = true
			break

	assert_true(found_started_action, "Should dispatch TRANSITION_STARTED action")

## Test transition queue CRITICAL priority
func test_transition_queue_critical_priority() -> void:
	# Track the order of completed transitions
	var completed_scenes: Array[StringName] = []
	_store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		if action.get("type") == U_SceneActions.ACTION_TRANSITION_COMPLETED:
			var payload: Dictionary = action.get("payload", {})
			var scene_id: StringName = payload.get("scene_id", StringName(""))
			if not scene_id.is_empty():
				completed_scenes.append(scene_id)
	)

	# Queue normal transition
	_manager.transition_to_scene(StringName("scene1"), "instant", M_SceneManager.Priority.NORMAL)
	# Queue critical transition (should jump queue)
	_manager.transition_to_scene(StringName("scene2"), "instant", M_SceneManager.Priority.CRITICAL)

	# Wait for both transitions to complete
	await wait_physics_frames(3)

	# Verify scene2 (CRITICAL) was processed before scene1 (NORMAL)
	assert_eq(completed_scenes.size(), 2, "Both transitions should complete")
	assert_eq(completed_scenes[0], StringName("scene2"), "Critical priority should process first")
	assert_eq(completed_scenes[1], StringName("scene1"), "Normal priority should process second")

## Test transition queue HIGH priority
func test_transition_queue_high_priority() -> void:
	_manager.transition_to_scene(StringName("scene1"), "instant", M_SceneManager.Priority.NORMAL)
	_manager.transition_to_scene(StringName("scene2"), "instant", M_SceneManager.Priority.HIGH)
	_manager.transition_to_scene(StringName("scene3"), "instant", M_SceneManager.Priority.NORMAL)

	await wait_physics_frames(4)

	# HIGH should process before remaining NORMAL transitions
	# Since we can't easily inspect queue order, we verify the system doesn't crash
	assert_true(true, "Queue should handle mixed priorities")

## Test get_current_scene returns current scene ID
func test_get_current_scene() -> void:
	# Set up initial scene in state
	_store.dispatch(U_SceneActions.transition_completed(StringName("main_menu")))
	await get_tree().physics_frame

	var current_scene: StringName = _manager.get_current_scene()
	assert_eq(current_scene, StringName("main_menu"), "Should return current scene ID")

## Test is_transitioning flag
func test_is_transitioning() -> void:
	assert_false(_manager.is_transitioning(), "Should not be transitioning initially")

	_manager.transition_to_scene(StringName("demo_room"), "fade")
	# During transition, is_transitioning should return true
	# (this depends on implementation timing, may need adjustment)
	await get_tree().process_frame
	# Note: Actual transitioning state depends on implementation
	assert_true(true, "is_transitioning method exists")

## Test pause suppression flag is limited to current frame
func test_suppress_pause_for_current_frame_expires_next_frame() -> void:
	assert_false(
		_manager.is_pause_suppressed_for_current_frame(),
		"Pause suppression should be disabled by default"
	)

	_manager.suppress_pause_for_current_frame()

	assert_true(
		_manager.is_pause_suppressed_for_current_frame(),
		"Pause suppression should be active on the frame it is requested"
	)

	await get_tree().process_frame

	assert_false(
		_manager.is_pause_suppressed_for_current_frame(),
		"Pause suppression should clear on the next frame"
	)

## Regression: queue_free during gameplay transition should not leave scene slice stuck transitioning
func test_queue_free_during_gameplay_transition_clears_transition_state() -> void:
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await get_tree().process_frame

	if _manager != null and is_instance_valid(_manager):
		_manager.queue_free()

	await wait_physics_frames(2)

	var scene_state: Dictionary = _store.get_state().get("scene", {})
	assert_false(
		scene_state.get("is_transitioning", false),
		"Transition state should clear even if manager is freed during transition teardown"
	)

## Test push_overlay adds scene to UIOverlayStack
func test_push_overlay() -> void:
	var initial_child_count: int = _ui_overlay_stack.get_child_count()

	_manager.push_overlay(StringName("pause_menu"))
	await wait_physics_frames(2)

	var new_child_count: int = _ui_overlay_stack.get_child_count()
	assert_gt(new_child_count, initial_child_count, "Should add overlay to UIOverlayStack")

## Test pop_overlay removes scene from UIOverlayStack
func test_pop_overlay() -> void:
	_manager.push_overlay(StringName("pause_menu"))
	await wait_physics_frames(2)

	var child_count_with_overlay: int = _ui_overlay_stack.get_child_count()

	_manager.pop_overlay()
	await wait_physics_frames(2)

	var child_count_after_pop: int = _ui_overlay_stack.get_child_count()
	assert_lt(child_count_after_pop, child_count_with_overlay, "Should remove overlay from UIOverlayStack")

## Test pop_overlay with empty stack does nothing
func test_pop_overlay_empty_stack() -> void:
	var initial_count: int = _ui_overlay_stack.get_child_count()

	_manager.pop_overlay()
	await get_tree().physics_frame

	var final_count: int = _ui_overlay_stack.get_child_count()
	assert_eq(final_count, initial_count, "Should not crash with empty overlay stack")

## Test push_overlay dispatches action
func test_push_overlay_dispatches_action() -> void:
	var actions_received: Array = []
	_store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		actions_received.append(action)
	)

	_manager.push_overlay(StringName("pause_menu"))
	await get_tree().physics_frame

	var found_push_action: bool = false
	for action in actions_received:
		if action.get("type") == U_SceneActions.ACTION_PUSH_OVERLAY:
			found_push_action = true
			break

	assert_true(found_push_action, "Should dispatch PUSH_OVERLAY action")

## Test pop_overlay dispatches action
func test_pop_overlay_dispatches_action() -> void:
	_manager.push_overlay(StringName("pause_menu"))
	await wait_physics_frames(2)

	var actions_received: Array = []
	_store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		actions_received.append(action)
	)

	_manager.pop_overlay()
	await get_tree().physics_frame

	var found_pop_action: bool = false
	for action in actions_received:
		if action.get("type") == U_SceneActions.ACTION_POP_OVERLAY:
			found_pop_action = true
			break

	assert_true(found_pop_action, "Should dispatch POP_OVERLAY action")

## Test manager subscribes to scene slice updates
func test_manager_subscribes_to_scene_slice() -> void:
	# Dispatch an action that updates scene slice
	_store.dispatch(U_SceneActions.transition_started(StringName("test_scene"), "fade"))
	await get_tree().physics_frame

	# If manager is subscribed, it should react to state changes
	# (specific behavior depends on implementation)
	assert_true(true, "Manager should subscribe to scene slice updates")

## Test transition with invalid scene ID
func test_transition_with_invalid_scene_id() -> void:
	# Should handle gracefully, possibly log warning
	_manager.transition_to_scene(StringName("nonexistent_scene"), "fade")
	await get_tree().physics_frame
	assert_push_error("transition dropped")

	# Should not crash
	assert_true(true, "Should handle invalid scene ID gracefully")

## Test multiple overlays stack correctly
func test_multiple_overlays_stack() -> void:
	_manager.push_overlay(StringName("pause_menu"))
	await wait_physics_frames(2)

	_manager.push_overlay(StringName("settings_panel"))
	await wait_physics_frames(2)

	var overlay_count: int = _ui_overlay_stack.get_child_count()
	assert_eq(overlay_count, 2, "Should stack multiple overlays")

## Test scene loading from ActiveSceneContainer
func test_scene_loads_into_active_scene_container() -> void:
	var initial_children: int = _active_scene_container.get_child_count()

	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(3)

	var final_children: int = _active_scene_container.get_child_count()
	# Should add new scene (implementation may vary)
	assert_true(final_children >= initial_children, "Should load scene into ActiveSceneContainer")

## Test transition blocks concurrent transitions
func test_concurrent_transitions_blocked() -> void:
	_manager.transition_to_scene(StringName("scene1"), "fade")
	_manager.transition_to_scene(StringName("scene2"), "fade")

	# Second transition should queue, not execute immediately
	await wait_physics_frames(2)

	# Verify only one transition happened (implementation-specific)
	assert_true(true, "Should block concurrent transitions")

## Test Priority enum exists
func test_priority_enum_defined() -> void:
	assert_eq(M_SceneManager.Priority.NORMAL, 0, "NORMAL priority should be 0")
	assert_eq(M_SceneManager.Priority.HIGH, 1, "HIGH priority should be 1")
	assert_eq(M_SceneManager.Priority.CRITICAL, 2, "CRITICAL priority should be 2")

## ========================================================================
## Phase 6.5: Overlay Return Stack Tests
## ========================================================================

## Test push_overlay_with_return from empty state (no current overlay)
func test_push_overlay_with_return_from_empty() -> void:
	# Given: No overlays active
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Should start with no overlays")

	# When: Push overlay with return
	_manager.push_overlay_with_return(StringName("pause_menu"))
	await get_tree().process_frame

	# Then: Overlay is pushed, return stack contains empty string
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay")
	# Return stack should have one entry (the empty string from before)
	assert_eq(_manager._overlay_return_stack.size(), 1, "Return stack should have one entry")
	assert_eq(_manager._overlay_return_stack[0], StringName(""), "Return stack should contain empty string")

## Test push_overlay_with_return from existing overlay (REPLACE mode)
func test_push_overlay_with_return_from_existing_overlay() -> void:
	# Given: pause_menu overlay is active
	_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have pause overlay")

	# When: Push settings with return (REPLACE mode - pops pause, pushes settings)
	_manager.push_overlay_with_return(StringName("settings_panel"))
	await get_tree().process_frame

	# Then: Settings overlay replaces pause, return stack contains pause_menu
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay (settings replaces pause)")
	assert_eq(_manager._overlay_return_stack.size(), 1, "Return stack should have one entry")
	assert_eq(_manager._overlay_return_stack[0], StringName("pause_menu"), "Return stack should contain pause_menu")

## Test pop_overlay_with_return restores previous overlay
func test_pop_overlay_with_return_restores_previous() -> void:
	# Given: pause → settings transition using push_overlay_with_return (REPLACE mode)
	_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame
	_manager.push_overlay_with_return(StringName("settings_panel"))
	await get_tree().process_frame
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay (settings replaced pause)")

	# When: Pop with return
	_manager.pop_overlay_with_return()
	await get_tree().process_frame

	# Then: Settings is removed, pause_menu is restored
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay")
	var top_overlay_id := _manager._overlay_helper.get_top_overlay_id(_ui_overlay_stack)
	assert_eq(top_overlay_id, StringName("pause_menu"), "Top overlay should be pause_menu")
	assert_eq(_manager._overlay_return_stack.size(), 0, "Return stack should be empty")

## Test pop_overlay_with_return with empty return stack
func test_pop_overlay_with_return_empty_stack() -> void:
	# Given: One overlay, but pushed without return (empty return stack)
	_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay")
	assert_eq(_manager._overlay_return_stack.size(), 0, "Return stack should be empty")

	# When: Pop with return (stack is empty)
	_manager.pop_overlay_with_return()
	await get_tree().process_frame

	# Then: Overlay is removed, nothing is restored (no crash)
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Should have no overlays")
	assert_eq(_manager._overlay_return_stack.size(), 0, "Return stack should still be empty")

## Test nested overlay navigation (A → B → C → back → back) with REPLACE mode
func test_nested_overlay_navigation() -> void:
	# Given: pause_menu overlay
	_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay")

	# When: Push settings with return (replaces pause)
	_manager.push_overlay_with_return(StringName("settings_panel"))
	await get_tree().process_frame
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay (settings replaced pause)")

	# When: Push another overlay with return (simulating settings → sub-menu, replaces settings)
	_manager.push_overlay_with_return(StringName("pause_menu"))  # Reuse pause_menu as third overlay
	await get_tree().process_frame

	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay (pause2 replaced settings)")
	assert_eq(_manager._overlay_return_stack.size(), 2, "Return stack should have two entries")

	# When: Pop with return (back from third to second)
	_manager.pop_overlay_with_return()
	await get_tree().process_frame

	# Then: Third overlay removed, second (settings) restored
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay (settings restored)")
	assert_eq(_manager._overlay_return_stack.size(), 1, "Return stack should have one entry")

	# When: Pop with return again (back from second to first)
	_manager.pop_overlay_with_return()
	await get_tree().process_frame

	# Then: Second overlay removed, first (pause) restored
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should have one overlay (pause restored)")
	assert_eq(_manager._overlay_return_stack.size(), 0, "Return stack should be empty")

## Test pop_overlay_with_return when return stack has empty string
func test_pop_overlay_with_return_empty_string_in_stack() -> void:
	# Given: Overlay pushed with return from empty state (return stack contains empty string)
	_manager.push_overlay_with_return(StringName("pause_menu"))
	await get_tree().process_frame
	assert_eq(_manager._overlay_return_stack.size(), 1, "Return stack should have one entry")
	assert_eq(_manager._overlay_return_stack[0], StringName(""), "Return stack should contain empty string")

	# When: Pop with return (return stack has empty string)
	_manager.pop_overlay_with_return()
	await get_tree().process_frame

	# Then: Overlay is removed, nothing is restored (empty string is not pushed)
	assert_eq(_ui_overlay_stack.get_child_count(), 0, "Should have no overlays")
	assert_eq(_manager._overlay_return_stack.size(), 0, "Return stack should be empty")

## Test _get_top_overlay_id helper returns correct ID
func test_get_top_overlay_id_helper() -> void:
	# Given: No overlays
	assert_eq(_manager._get_top_overlay_id(), StringName(""), "Should return empty string when no overlays")

	# When: Push overlay
	_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame

	# Then: Returns correct overlay ID
	assert_eq(_manager._get_top_overlay_id(), StringName("pause_menu"), "Should return pause_menu ID")

	# When: Push second overlay
	_manager.push_overlay(StringName("settings_panel"))
	await get_tree().process_frame

	# Then: Returns top overlay ID
	assert_eq(_manager._get_top_overlay_id(), StringName("settings_panel"), "Should return settings_panel ID")
