@icon("res://assets/core/editor_icons/icn_manager.svg")
extends "res://scripts/core/interfaces/i_scene_manager.gd"
class_name M_SceneManager

## Scene Manager - Coordinates scene transitions and overlays
##
## Responsibilities:
## - Manage transition queue with priorities
## - Load/unload scenes from ActiveSceneContainer
## - Manage UI overlay stack
## - Dispatch scene actions to M_StateStore
## - Subscribe to scene state changes
##
## Discovery: Registered via ServiceLocator during scene bootstrap
##
## Signals:
## - transition_visual_complete(scene_id): Emitted when fade-in completes and scene is fully visible

## Emitted when transition visual effects complete and scene is fully visible
## This is the signal MobileControls should use to show controls (not state changes)
signal transition_visual_complete(scene_id: StringName)

const M_STATE_STORE := preload("res://scripts/core/state/m_state_store.gd")
const I_CURSOR_MANAGER := preload("res://scripts/core/interfaces/i_cursor_manager.gd")
const I_SPAWN_MANAGER := preload("res://scripts/core/interfaces/i_spawn_manager.gd")
const U_SCENE_ACTIONS := preload("res://scripts/core/state/actions/u_scene_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/core/state/actions/u_navigation_actions.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/core/state/actions/u_gameplay_actions.gd")
const U_SCENE_REGISTRY := preload("res://scripts/core/scene_management/u_scene_registry.gd")
const U_UI_REGISTRY := preload("res://scripts/core/ui/utils/u_ui_registry.gd")
const U_TRANSITION_FACTORY := preload("res://scripts/core/scene_management/u_transition_factory.gd")
const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")
const U_SCENE_CACHE := preload("res://scripts/core/scene_management/helpers/u_scene_cache.gd")
const U_SCENE_LOADER := preload("res://scripts/core/scene_management/helpers/u_scene_loader.gd")
const U_OVERLAY_STACK_MANAGER := preload("res://scripts/core/scene_management/helpers/u_overlay_stack_manager.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/core/events/ecs/u_ecs_event_names.gd")
const U_TRANSITION_ORCHESTRATOR := preload("res://scripts/core/scene_management/u_transition_orchestrator.gd")
const U_SCENE_TRANSITION_QUEUE := preload("res://scripts/core/scene_management/helpers/u_scene_transition_queue.gd")
const U_SCENE_MANAGER_NODE_FINDER := preload("res://scripts/core/scene_management/helpers/u_scene_manager_node_finder.gd")
const U_NAVIGATION_RECONCILER := preload("res://scripts/core/scene_management/helpers/u_navigation_reconciler.gd")
const U_TRANSITION_STATE := preload("res://scripts/core/scene_management/helpers/u_transition_state.gd")
const U_INPUT_MAP_BOOTSTRAPPER := preload("res://scripts/core/input/u_input_map_bootstrapper.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/core/state/selectors/u_localization_selectors.gd")
const U_DEBUG_SELECTORS := preload("res://scripts/core/state/selectors/u_debug_selectors.gd")
const U_SCENE_SELECTORS := preload("res://scripts/core/state/selectors/u_scene_selectors.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/core/state/selectors/u_navigation_selectors.gd")
const CFG_GAME_CONFIG := preload("res://resources/core/cfg_game_config.tres")
const HUD_OVERLAY_SCENE := preload("res://scenes/core/ui/hud/ui_hud_overlay.tscn")
const UI_HUD_CONTROLLER := preload("res://scripts/core/ui/hud/ui_hud_controller.gd")
# T209: Transition class imports removed - now handled by U_TransitionFactory
# Kept for type checking only:
const FADE_TRANSITION := preload("res://scripts/core/scene_management/transitions/trans_fade.gd")
const LOADING_SCREEN_TRANSITION := preload("res://scripts/core/scene_management/transitions/trans_loading_screen.gd")

# T137a: Phase 10B-3 - Scene type handler imports
const H_GAMEPLAY_SCENE_HANDLER := preload("res://scripts/core/scene_management/handlers/h_gameplay_scene_handler.gd")
const H_MENU_SCENE_HANDLER := preload("res://scripts/core/scene_management/handlers/h_menu_scene_handler.gd")
const H_UI_SCENE_HANDLER := preload("res://scripts/core/scene_management/handlers/h_ui_scene_handler.gd")
const H_ENDGAME_SCENE_HANDLER := preload("res://scripts/core/scene_management/handlers/h_endgame_scene_handler.gd")
const DEBUG_VICTORY_TRACE := false

## Priority enum (re-exported from U_SceneTransitionQueue for external callers)
enum Priority {
	NORMAL = U_SCENE_TRANSITION_QUEUE.Priority.NORMAL,
	HIGH = U_SCENE_TRANSITION_QUEUE.Priority.HIGH,
	CRITICAL = U_SCENE_TRANSITION_QUEUE.Priority.CRITICAL
}

## Internal references
var _store: I_StateStore = null
var _cursor_manager: I_CURSOR_MANAGER = null
var _spawn_manager: I_SPAWN_MANAGER = null
var _camera_manager: I_CAMERA_MANAGER = null
var _active_scene_container: Node = null
var _ui_overlay_stack: CanvasLayer = null
var _transition_overlay: CanvasLayer = null
var _loading_overlay: CanvasLayer = null
var _hud_instance: CanvasLayer = null
var _owns_hud_instance: bool = false

## Transition queue helper
var _transition_queue_helper := U_SCENE_TRANSITION_QUEUE.new()
var _queue_processing_scheduled: bool = false

## Current scene tracking for reactive cursor updates
var _current_scene_id: StringName = StringName("")
var _active_transition_target: StringName = StringName("")
var _navigation_slice_connected: bool = false
var _initial_navigation_synced: bool = false
var _pause_suppressed_process_frame: int = -1
var _pause_suppressed_physics_frame: int = -1

## Navigation reconciliation helper
var _navigation_reconciler := U_NAVIGATION_RECONCILER.new()

## Scene history tracking for UI navigation (T109)
## Only tracks UI/Menu scenes, cleared when entering gameplay
var _scene_history: Array[StringName] = []

## Overlay return stack for generic overlay navigation (Phase 6.5)
## Tracks previous overlay ID when pushing with return, enabling stack-based navigation
## Example: pause→settings→back returns to pause without hardcoded methods
var _overlay_return_stack: Array[StringName] = []

## Scene cache management (Phase 8)
## Backed by U_SceneCache helper
var _scene_cache_helper := U_SCENE_CACHE.new()

## Cache: path → PackedScene (exposed for tests via manager properties)
@warning_ignore("unused_private_class_variable")
var _scene_cache:
	get:
		return _scene_cache_helper._scene_cache

## Background loading tracking (Phase 8)
## Key: path (String), Value: { scene_id, status, start_time }
var _background_loads:
	get:
		return _scene_cache_helper._background_loads

## Cache limits (Phase 8)
@warning_ignore("unused_private_class_variable")
var _max_cached_scenes:
	get:
		return _scene_cache_helper._max_cached_scenes
	set(value):
		_scene_cache_helper._max_cached_scenes = int(value)
@warning_ignore("unused_private_class_variable")
var _max_cache_memory:
	get:
		return _scene_cache_helper._max_cache_memory
	set(value):
		_scene_cache_helper._max_cache_memory = int(value)

## LRU tracking (Phase 8)
## Key: path (String), Value: timestamp (float)
@warning_ignore("unused_private_class_variable")
var _cache_access_times:
	get:
		return _scene_cache_helper._cache_access_times

## Background polling active flag (Phase 8)
@warning_ignore("unused_private_class_variable")
var _is_background_polling_active:
	get:
		return _scene_cache_helper._is_background_polling_active

## Helpers
var _scene_loader := U_SCENE_LOADER.new()
var _overlay_helper := U_OVERLAY_STACK_MANAGER.new()
var _transition_orchestrator := U_TRANSITION_ORCHESTRATOR.new()
var _spawned_scene_roots: Dictionary = {} # instance_id -> WeakRef

## Scene type handlers (T137a: Phase 10B-3)
## Maps SceneType enum values to handler instances
var _scene_type_handlers: Dictionary = {} # int (SceneType) -> I_SCENE_TYPE_HANDLER

## Store subscription
var _unsubscribe: Callable

## ECS event bus subscriptions
var _entity_death_unsubscribe: Callable

## Skip initial scene load (for tests)
var skip_initial_scene_load: bool = false

## Initial scene to load on startup (configurable for testing)
@export var initial_scene_id: StringName = StringName("splash_screen")

func _debug_log(message: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	print_verbose("[VictoryDebug][M_SceneManager] %s" % message)

func _ready() -> void:
	# Find managers via ServiceLocator (Phase 10B-7: T141c)
	await get_tree().process_frame # Wait for ServiceLocator to initialize

	# Phase 3 (InputMap determinism): ensure required actions exist in dev/test.
	# This avoids brittle test ordering where other suites erase actions.
	U_INPUT_MAP_BOOTSTRAPPER.ensure_required_actions(
		U_INPUT_MAP_BOOTSTRAPPER.REQUIRED_ACTIONS,
		U_INPUT_MAP_BOOTSTRAPPER.should_patch_missing_actions()
	)

	_store = U_ServiceLocator.get_service(StringName("state_store")) as M_StateStore
	if not _store:
		push_error("M_SceneManager: No M_StateStore registered with ServiceLocator")
		return

	# Optional dependencies - use try_get_service to avoid error spam in tests
	_cursor_manager = U_ServiceLocator.try_get_service(StringName("cursor_manager")) as I_CURSOR_MANAGER
	if not _cursor_manager:
		push_warning("M_SceneManager: No M_CursorManager registered with ServiceLocator")

	# Find M_SpawnManager via ServiceLocator (Phase 12.1: T225)
	_spawn_manager = U_ServiceLocator.try_get_service(StringName("spawn_manager")) as I_SPAWN_MANAGER
	if not _spawn_manager:
		push_warning("M_SceneManager: No M_SpawnManager registered with ServiceLocator")

	# Find M_CameraManager via ServiceLocator (Phase 12.2: T243)
	_camera_manager = U_ServiceLocator.try_get_service(StringName("camera_manager"))
	if not _camera_manager:
		push_warning("M_SceneManager: No M_CameraManager registered with ServiceLocator")

	# Find container nodes (delegates to helper)
	var containers := U_SCENE_MANAGER_NODE_FINDER.find_containers(self )
	_active_scene_container = containers.active_scene_container
	_ui_overlay_stack = containers.ui_overlay_stack
	_transition_overlay = containers.transition_overlay
	_loading_overlay = containers.loading_overlay
	_ensure_hud_overlay()

	_sync_overlay_stack_state()

	# Subscribe to scene slice updates
	if _store != null:
		_unsubscribe = _store.subscribe(_on_state_changed)
		if not _store.slice_updated.is_connected(_on_slice_updated):
			_store.slice_updated.connect(_on_slice_updated)
			_navigation_slice_connected = true

	# Subscribe to ECS events with priorities
	# entity_death: Priority 10 (high - quick transition to game over)
	_entity_death_unsubscribe = U_ECS_EVENT_BUS.subscribe(U_ECS_EVENT_NAMES.EVENT_ENTITY_DEATH, _on_entity_death, 10)

	# Channel taxonomy: victory routing arrives via Redux dispatch (managers dispatch to Redux)
	if _store != null and _store.has_signal("action_dispatched"):
		_store.action_dispatched.connect(_on_action_dispatched)
	# Register scene type handlers (T137c: Phase 10B-3)
	_register_scene_type_handlers()

	# Validate U_SceneRegistry door pairings
	if not U_SCENE_REGISTRY.validate_door_pairings():
		push_error("M_SceneManager: U_SceneRegistry door pairing validation failed")

	# Phase 8: Preload critical scenes in background (main_menu, pause_menu, loading_screen)
	var critical_scenes: Array = U_SCENE_REGISTRY.get_preloadable_scenes(10)
	_scene_cache_helper.preload_critical_scenes(critical_scenes)

	# Load initial scene (main_menu) unless skipped for tests
	if not skip_initial_scene_load:
		_load_initial_scene()
	call_deferred("_request_navigation_reconciliation")

func _request_navigation_reconciliation() -> void:
	if _initial_navigation_synced:
		return
	_initial_navigation_synced = true
	if skip_initial_scene_load:
		return
	if _store == null:
		return
	var nav_state: Dictionary = _store.get_slice(StringName("navigation"))
	if nav_state.is_empty():
		return
	_navigation_reconciler.reconcile_navigation_state(
		nav_state,
		self ,
		_current_scene_id,
		_overlay_helper,
		Callable(_scene_loader, "load_scene"),
		_ui_overlay_stack,
		_store,
		func(): pass,
		get_tree().root,
		Callable(self , "_get_transition_queue_state"),
		Callable(self , "_set_overlay_reconciliation_pending")
	)


## Register all scene type handlers (T137c: Phase 10B-3)
##
## Creates handler instances for each SceneType enum value and registers them
## in the _scene_type_handlers dictionary. Handlers encapsulate scene-type-specific
## behavior for loading, unloading, and navigation.
func _register_scene_type_handlers() -> void:
	_scene_type_handlers[U_SCENE_REGISTRY.SceneType.GAMEPLAY] = H_GAMEPLAY_SCENE_HANDLER.new()
	_scene_type_handlers[U_SCENE_REGISTRY.SceneType.MENU] = H_MENU_SCENE_HANDLER.new()
	_scene_type_handlers[U_SCENE_REGISTRY.SceneType.UI] = H_UI_SCENE_HANDLER.new()
	_scene_type_handlers[U_SCENE_REGISTRY.SceneType.END_GAME] = H_ENDGAME_SCENE_HANDLER.new()

func _exit_tree() -> void:
	if _owns_hud_instance and _hud_instance != null and is_instance_valid(_hud_instance):
		_hud_instance.queue_free()
	_hud_instance = null
	_owns_hud_instance = false

	# Unsubscribe from state updates
	if _unsubscribe != null and _unsubscribe.is_valid():
		_unsubscribe.call()
	if _store != null and _navigation_slice_connected and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)
	_navigation_slice_connected = false

	# Disconnect Redux action_dispatched subscription (victory routing)
	if _store != null and _store.has_signal("action_dispatched"):
		if _store.action_dispatched.is_connected(_on_action_dispatched):
			_store.action_dispatched.disconnect(_on_action_dispatched)

	# Unsubscribe from ECS events
	if _entity_death_unsubscribe != null and _entity_death_unsubscribe.is_valid():
		_entity_death_unsubscribe.call()

func _ensure_hud_overlay() -> void:
	var hud_layer := U_ServiceLocator.try_get_service(StringName("hud_layer")) as CanvasLayer
	if hud_layer == null:
		push_warning("M_SceneManager: No HUDLayer registered with ServiceLocator")
		return

	var existing_hud := _find_existing_hud_controller(hud_layer)
	if existing_hud != null:
		_hud_instance = existing_hud
		_owns_hud_instance = false
		return

	var hud_node: Node = HUD_OVERLAY_SCENE.instantiate()
	var hud_controller := hud_node as CanvasLayer
	if hud_controller == null:
		push_error("M_SceneManager: HUD overlay scene root must be a CanvasLayer")
		hud_node.queue_free()
		return

	hud_layer.add_child(hud_controller)
	_hud_instance = hud_controller
	_owns_hud_instance = true

func _find_existing_hud_controller(hud_layer: CanvasLayer) -> CanvasLayer:
	for child: Node in hud_layer.get_children():
		var child_script: Variant = child.get_script()
		if child_script == UI_HUD_CONTROLLER:
			return child as CanvasLayer
	return null

func _ensure_store_reference() -> void:
	_store = U_SCENE_MANAGER_NODE_FINDER.ensure_store_reference(_store, self )

## State change callback
func _on_state_changed(___action: Dictionary, state: Dictionary) -> void:
	# Detect scene changes and update cursor reactively
	var new_scene_id: StringName = U_SCENE_SELECTORS.get_current_scene_id(state)

	# Only track scene_id when it actually changes and is not empty
	# Phase 2 (T022): Cursor updates removed - M_TimeManager is now sole authority
	if new_scene_id != _current_scene_id and not new_scene_id.is_empty():
		_current_scene_id = new_scene_id
		if _navigation_reconciler.get_pending_scene_id() == new_scene_id:
			_navigation_reconciler.set_pending_scene_id(StringName(""))
		# NOTE: _sync_navigation_shell_with_scene() now called AFTER transition completes
		# in _process_transition_queue() to prevent mobile controls flashing (line 316)

## ECS event handler: entity_death
## Phase 10B (T130): Subscribe to entity_death event instead of direct call from S_HealthSystem
func _on_entity_death(_event: Dictionary) -> void:
	# Trigger game over transition when player dies
	transition_to_scene(StringName("game_over"), "fade", Priority.CRITICAL)

## Channel taxonomy: victory routing arrives via Redux dispatch (managers dispatch to Redux)
func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))
	if action_type != U_GAMEPLAY_ACTIONS.ACTION_TRIGGER_VICTORY_ROUTING:
		return
	var target_scene: StringName = action.get("target_scene", StringName(""))
	_debug_log(
		"received victory_routing target_scene=%s current_scene=%s queue_size=%s is_processing=%s"
		% [
			str(target_scene),
			str(get_current_scene()),
			str(_transition_queue_helper.size()),
			str(_transition_queue_helper.is_processing()),
		]
	)
	if target_scene == StringName(""):
		push_warning("M_SceneManager: victory_routing missing target_scene")
		return
	if target_scene == get_current_scene():
		return
	transition_to_scene(target_scene, "fade", Priority.HIGH)

func _load_initial_scene() -> void:
	# Load initial scene (configurable via export var)
	# Default is splash_screen which handles language_selector/main_menu redirect
	var scene_id := initial_scene_id
	# Debug: skip splash entirely if flag is set
	if scene_id == StringName("splash_screen") and _store != null:
		var state: Dictionary = _store.get_state()
		if U_DEBUG_SELECTORS.should_skip_splash(state):
			scene_id = StringName("language_selector")
			_start_background_gameplay_preload()
	# Promote language_selector to main_menu if language already selected or skip flag set
	if scene_id == StringName("language_selector") and _store != null:
		var state: Dictionary = _store.get_state()
		if U_LOCALIZATION_SELECTORS.has_selected_language(state) or U_DEBUG_SELECTORS.should_skip_language_selection(state):
			scene_id = StringName("main_menu")
	# Sync navigation state so the reconciler doesn't override the initial scene
	if _store != null:
		var shell := StringName("main_menu") if scene_id == StringName("main_menu") else StringName("boot")
		_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(shell, scene_id))
	transition_to_scene(scene_id, "instant", Priority.CRITICAL)

## Start background preload of the default gameplay scene (mirrors splash screen preload)
func _start_background_gameplay_preload() -> void:
	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(CFG_GAME_CONFIG.get_default_gameplay_scene_id())
	if scene_data.is_empty():
		return
	var path: String = str(scene_data.get("path", ""))
	if path.is_empty():
		return
	ResourceLoader.load_threaded_request(path, "PackedScene")

## Transition to a new scene
func transition_to_scene(scene_id: StringName, transition_type: String = "fade", priority: int = Priority.NORMAL) -> void:
	# Validate scene exists in registry
	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(scene_id)
	if scene_data.is_empty():
		push_error("M_SceneManager: transition dropped — '%s' not in scene registry" % scene_id)
		return

	_ensure_store_reference()

	# Add to queue based on priority (delegates to helper)
	_transition_queue_helper.enqueue(scene_id, transition_type, priority)
	_debug_log(
		"transition enqueued scene_id=%s transition_type=%s priority=%s queue_size=%s is_processing=%s"
		% [
			str(scene_id),
			transition_type,
			str(priority),
			str(_transition_queue_helper.size()),
			str(_transition_queue_helper.is_processing()),
		]
	)

	# Process queue if not already processing
	if not _transition_queue_helper.is_processing() and not _queue_processing_scheduled:
		_queue_processing_scheduled = true
		call_deferred("_process_transition_queue")

## Process transition queue
func _process_transition_queue() -> void:
	_queue_processing_scheduled = false
	if _transition_queue_helper.is_empty():
		_transition_queue_helper.set_processing(false)
		_active_transition_target = StringName("")
		_reconcile_pending_navigation_overlays()
		return

	_ensure_store_reference()

	_transition_queue_helper.set_processing(true)

	# Get next transition from queue
	var request := _transition_queue_helper.pop_front()
	if request == null:
		_transition_queue_helper.set_processing(false)
		_active_transition_target = StringName("")
		_reconcile_pending_navigation_overlays()
		return

	_active_transition_target = request.scene_id
	_debug_log(
		"processing transition scene_id=%s transition_type=%s remaining_queue=%s"
		% [str(request.scene_id), request.transition_type, str(_transition_queue_helper.size())]
	)

	# Dispatch transition started action
	if _store != null:
		_store.dispatch(U_SCENE_ACTIONS.transition_started(
			request.scene_id,
			request.transition_type
		))

	# Perform transition
	await _perform_transition(request)

	# Dispatch transition completed action
	if _store != null:
		_store.dispatch(U_SCENE_ACTIONS.transition_completed(request.scene_id))

	# Emit signal that visual transition is complete (scene is fully visible)
	# MobileControls waits for this signal before showing controls
	transition_visual_complete.emit(request.scene_id)

	if _active_transition_target == request.scene_id:
		_active_transition_target = StringName("")

	# Process next transition in queue.
	# Do not `await` here: tests may free the manager after each test, and any
	# pending await would attempt to resume on a freed instance.
	if not _queue_processing_scheduled:
		_queue_processing_scheduled = true
		call_deferred("_process_transition_queue")
	return

## Perform the actual scene transition (orchestration only)
##
## Decomposed into focused helper methods:
## - _prepare_transition_context: cache check, camera state capture, context assembly
## - _execute_scene_swap: scene removal, loading, camera blending, handler delegation
## - _finalize_camera_blend: post-transition camera finalization
##
## The scene_swap_callback uses a thin lambda that delegates to _execute_scene_swap.
## The orchestrator awaits the callback, so async loading inside _execute_scene_swap
## is properly sequenced.
func _perform_transition(request) -> void:
	var scene_path: String = U_SCENE_REGISTRY.get_scene_path(request.scene_id)
	if scene_path.is_empty():
		push_error("M_SceneManager: No path for scene '%s'" % request.scene_id)
		return
	_update_scene_history(request.scene_id)
	var transition_ctx := _prepare_transition_context(request, scene_path)
	var scene_swap_callback := func() -> void:
		await _execute_scene_swap(request, scene_path, transition_ctx)
	var overlays := {
		"transition_overlay": _transition_overlay,
		"loading_overlay": _loading_overlay
	}
	await _transition_orchestrator.execute_transition_effect(
		request.transition_type,
		scene_swap_callback,
		func() -> void: pass,
		overlays
	)
	_finalize_camera_blend(transition_ctx)
	var transition_state := _resolve_transition_state(transition_ctx)
	if transition_state.new_scene_ref != null:
		await _unfreeze_player_physics(transition_state.new_scene_ref)

## Prepare transition context: cache check, progress callback, camera state capture
##
## Returns a Dictionary with:
## - use_cached: bool - Whether scene is in the cache
## - progress_callback: Callable - Callback for async loading progress
## - transition_state: U_TransitionState - mutable transition state object
func _prepare_transition_context(request, scene_path: String) -> Dictionary:
	var use_cached: bool = _scene_cache_helper.is_scene_cached(scene_path)
	var transition_state := U_TRANSITION_STATE.new()
	var progress_callback: Callable = func(progress: float) -> void:
		transition_state.progress = clamp(progress, 0.0, 1.0)
	if _camera_manager != null and request.transition_type != "instant":
		if _active_scene_container != null and _active_scene_container.get_child_count() > 0:
			var old_scene: Node = _active_scene_container.get_child(0)
			transition_state.old_camera_state = _camera_manager.capture_camera_state(old_scene)
	transition_state.should_blend = transition_state.old_camera_state != null and _camera_manager != null
	return {
		"use_cached": use_cached,
		"progress_callback": progress_callback,
		"transition_state": transition_state,
	}

## Execute the scene swap: remove old scene, load new, blend cameras, delegate to handlers
##
## This replaces the 88-line closure that was previously inlined in _perform_transition.
## The orchestrator awaits the callback that calls this, so async loading works correctly.
func _execute_scene_swap(request, scene_path: String, transition_ctx: Dictionary) -> void:
	if _active_scene_container != null:
		_scene_loader.remove_current_scene(_active_scene_container)

	var use_cached: bool = bool(transition_ctx.get("use_cached", false))
	var progress_callback: Callable = transition_ctx.get("progress_callback", func(_p: float) -> void: pass)
	var new_scene: Node = null
	if use_cached:
		var cached_scene: PackedScene = _scene_cache_helper.get_cached_scene(scene_path)
		if cached_scene != null:
			new_scene = cached_scene.instantiate()
	elif request.transition_type == "loading" and not (OS.has_feature("headless") or DisplayServer.get_name() == "headless"):
		new_scene = await _scene_loader.load_scene_async(scene_path, progress_callback, _background_loads)
	else:
		new_scene = _scene_loader.load_scene(scene_path)
		if request.transition_type == "loading":
			progress_callback.call(1.0)

	if new_scene == null:
		push_error("M_SceneManager: Failed to load scene '%s'" % scene_path)
		return

	_validate_scene_contract(new_scene, request.scene_id)

	var scene_type: int = U_SCENE_REGISTRY.get_scene_type(request.scene_id)
	if scene_type == U_SCENE_REGISTRY.SceneType.GAMEPLAY:
		mark_scene_spawned(new_scene)

	if _active_scene_container != null:
		_scene_loader.add_scene(_active_scene_container, new_scene)
	var transition_state := _resolve_transition_state(transition_ctx)
	transition_state.new_scene_ref = new_scene
	transition_state.scene_swap_complete = true

	var should_blend: bool = transition_state.should_blend
	var old_camera_state = transition_state.old_camera_state
	if should_blend and _camera_manager != null:
		_camera_manager.blend_cameras(null, new_scene, 0.2, old_camera_state)
	else:
		var new_camera: Camera3D = null
		if _camera_manager != null:
			new_camera = _camera_manager.initialize_scene_camera(new_scene)
		else:
			var camera_manager := U_ServiceLocator.try_get_service(StringName("camera_manager")) as I_CAMERA_MANAGER
			if camera_manager != null:
				new_camera = camera_manager.initialize_scene_camera(new_scene)
				if new_camera == null:
					new_camera = camera_manager.get_main_camera()
		if new_camera != null:
			new_camera.current = true

	if is_instance_valid(new_scene):
		var handler := _scene_type_handlers.get(scene_type) as I_SCENE_TYPE_HANDLER
		if handler != null:
			var managers := {
				"spawn_manager": _spawn_manager,
				"state_store": _store
			}
			handler.on_load(new_scene, request.scene_id, managers)

	if _store != null:
		_store.dispatch(U_SCENE_ACTIONS.scene_swapped(request.scene_id))
		_sync_navigation_shell_with_scene(request.scene_id)

## Finalize camera blend after transition completes
##
## Only finalizes if camera manager reports no active blend (fade transitions run
## the blend in parallel, and cutting it short would cause a visual jump).
func _finalize_camera_blend(transition_ctx: Dictionary) -> void:
	var transition_state := _resolve_transition_state(transition_ctx)
	if _camera_manager == null or transition_state.new_scene_ref == null:
		return
	var has_active_blend: bool = _camera_manager.is_blend_active()
	if not has_active_blend:
		_camera_manager.finalize_blend_to_scene(transition_state.new_scene_ref)

func _resolve_transition_state(transition_ctx: Dictionary) -> U_TRANSITION_STATE:
	var state_variant: Variant = transition_ctx.get("transition_state", null)
	if state_variant is U_TRANSITION_STATE:
		return state_variant as U_TRANSITION_STATE

	var fallback_state := U_TRANSITION_STATE.new()
	fallback_state.old_camera_state = transition_ctx.get("old_camera_state", null)
	fallback_state.should_blend = bool(transition_ctx.get("should_blend", false))
	var legacy_new_scene_ref: Variant = transition_ctx.get("new_scene_ref", null)
	if legacy_new_scene_ref is Array:
		var legacy_array := legacy_new_scene_ref as Array
		if not legacy_array.is_empty() and legacy_array[0] is Node:
			fallback_state.new_scene_ref = legacy_array[0] as Node
	transition_ctx["transition_state"] = fallback_state
	return fallback_state

## Re-enable player physics after transition completes
## Includes physics warmup frame to prevent bobble from stale collision state
func _unfreeze_player_physics(scene: Node) -> void:
	if scene == null:
		return
	var did_unfreeze: bool = _scene_loader.unfreeze_player_physics(scene)
	if not did_unfreeze:
		return

	# FIX: Physics warmup frame - let CharacterBody3D refresh collision state
	# before ECS systems start making decisions based on ground detection.
	# Without this, the first physics frame may have stale collision cache,
	# causing spring/bounce effects (bobble).
	await get_tree().physics_frame

## Push overlay scene onto UIOverlayStack
func push_overlay(scene_id: StringName, force: bool = false) -> void:
	_overlay_helper.push_overlay(
		scene_id,
		force,
		Callable(_scene_loader, "load_scene"),
		_ui_overlay_stack,
		_store,
		func(): pass
	)

## Pop top overlay from UIOverlayStack
func pop_overlay() -> void:
	var viewport: Viewport = get_tree().root
	_overlay_helper.pop_overlay(
		_ui_overlay_stack,
		_store,
		func(): pass,
		viewport
	)

## Suppress pause menu activation for the current frame
##
## Used when auto-triggering scene transitions to prevent ESC key
## from opening pause menu on the same frame.
##
## Note: Stub implementation (Phase: Duck Typing Cleanup Phase 3)
## Full implementation would coordinate with M_TimeManager
func suppress_pause_for_current_frame() -> void:
	_pause_suppressed_process_frame = Engine.get_process_frames()
	_pause_suppressed_physics_frame = Engine.get_physics_frames()

func is_pause_suppressed_for_current_frame() -> bool:
	return (
		_pause_suppressed_process_frame == Engine.get_process_frames()
		and _pause_suppressed_physics_frame == Engine.get_physics_frames()
	)

## Push overlay with automatic return navigation (Phase 6.5)
##
## Replaces the current overlay (if any) with a new overlay and remembers the previous one.
## When pop_overlay_with_return() is called, the previous overlay will be restored.
##
## This enables generic overlay transitions without hardcoded methods:
## - pause → settings → back (returns to pause)
## - inventory → skill_tree → back (returns to inventory)
## - map → quests → back (returns to map)
##
## Behavior: REPLACE mode (not stack mode)
## - If overlay already exists: pop it, remember it, push new one
## - If no overlay exists: remember empty, push new one
##
## Example:
##   push_overlay("pause_menu")                 # 1 overlay: pause
##   push_overlay_with_return("settings_panel")  # Remember pause, replace → 1 overlay: settings
##   pop_overlay_with_return()                  # Restore pause → 1 overlay: pause
func push_overlay_with_return(overlay_id: StringName) -> void:
	var viewport: Viewport = get_tree().root
	_overlay_helper.push_overlay_with_return(
		overlay_id,
		_overlay_return_stack,
		Callable(_scene_loader, "load_scene"),
		_ui_overlay_stack,
		_store,
		func(): pass,
		viewport
	)

## Pop overlay with automatic return navigation (Phase 6.5)
##
## Pops the current overlay and restores the previous overlay from the return stack.
## If the return stack is empty, this behaves like pop_overlay().
## If the return stack has a non-empty overlay ID, that overlay is pushed.
##
## This provides stack-based overlay navigation without hardcoded logic.
func pop_overlay_with_return() -> void:
	var viewport: Viewport = get_tree().root
	var deferred_push_overlay_for_return: Callable = func(scene_id: StringName) -> void:
		call_deferred("_push_overlay_for_return", scene_id)
	_overlay_helper.pop_overlay_with_return(
		_overlay_return_stack,
		Callable(_scene_loader, "load_scene"),
		_ui_overlay_stack,
		_store,
		func(): pass,
		viewport,
		deferred_push_overlay_for_return
	)

## Internal: deferred restore helper for return navigation
func _push_overlay_for_return(scene_id: StringName) -> void:
	push_overlay(scene_id, true)

## Get the scene_id of the current top overlay (helper for return stack)
##
## Returns StringName("") if no overlays are active.
func _get_top_overlay_id() -> StringName:
	return _overlay_helper.get_top_overlay_id(_ui_overlay_stack)

## Configure overlay scene for pause handling
func _configure_overlay_scene(overlay_scene: Node, scene_id: StringName) -> void:
	_overlay_helper.configure_overlay_scene(overlay_scene, scene_id)

func has_scene_been_spawned(scene_root: Node) -> bool:
	_prune_spawned_scene_roots()
	if scene_root == null:
		return false
	var id := scene_root.get_instance_id()
	if not _spawned_scene_roots.has(id):
		return false
	var ref: WeakRef = _spawned_scene_roots[id] as WeakRef
	return ref != null and ref.get_ref() != null

func mark_scene_spawned(scene_root: Node) -> void:
	if scene_root == null:
		return
	_spawned_scene_roots[scene_root.get_instance_id()] = weakref(scene_root)

func _prune_spawned_scene_roots() -> void:
	var stale: Array = []
	for id in _spawned_scene_roots.keys():
		var ref: WeakRef = _spawned_scene_roots[id] as WeakRef
		if ref == null or ref.get_ref() == null:
			stale.append(id)
	for id in stale:
		_spawned_scene_roots.erase(id)

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("navigation"):
		return
	if slice_state.is_empty():
		return
	_navigation_reconciler.reconcile_navigation_state(
		slice_state,
		self ,
		_current_scene_id,
		_overlay_helper,
		Callable(_scene_loader, "load_scene"),
		_ui_overlay_stack,
		_store,
		func(): pass,
		get_tree().root,
		Callable(self , "_get_transition_queue_state"),
		Callable(self , "_set_overlay_reconciliation_pending")
	)

func _is_scene_in_queue(scene_id: StringName) -> bool:
	return _transition_queue_helper.contains_scene(scene_id)

## Helper for navigation reconciler callback
func _get_active_transition_target() -> StringName:
	return _active_transition_target

## Helper for overlay stack manager to check transition state
func _get_transition_queue_state() -> Dictionary:
	return {
		"is_processing": _transition_queue_helper.is_processing(),
		"queue_size": _transition_queue_helper.size()
	}

## Helper for overlay stack manager to set reconciliation pending flag
func _set_overlay_reconciliation_pending(pending: bool) -> void:
	_navigation_reconciler.set_overlay_reconciliation_pending(pending)

## Helper for tests to set/get navigation pending scene
func _set_navigation_pending_scene_id(scene_id: StringName) -> void:
	_navigation_reconciler.set_pending_scene_id(scene_id)

func _get_navigation_pending_scene_id() -> StringName:
	return _navigation_reconciler.get_pending_scene_id()

func _reconcile_overlay_stack(desired_overlay_ids: Array[StringName], current_stack: Array[StringName]) -> void:
	var viewport: Viewport = get_tree().root
	_overlay_helper.reconcile_overlay_stack(
		desired_overlay_ids,
		current_stack,
		Callable(_scene_loader, "load_scene"),
		_ui_overlay_stack,
		_store,
		func(): pass,
		viewport,
		Callable(self , "_get_transition_queue_state"),
		Callable(self , "_set_overlay_reconciliation_pending")
	)

func _reconcile_pending_navigation_overlays() -> void:
	_navigation_reconciler.reconcile_pending_overlays(
		self ,
		_overlay_helper,
		Callable(_scene_loader, "load_scene"),
		_ui_overlay_stack,
		_store,
		func(): pass,
		get_tree().root,
		Callable(self , "_get_transition_queue_state"),
		Callable(self , "_set_overlay_reconciliation_pending")
	)

## Ensure scene_stack metadata matches actual overlay stack
func _sync_overlay_stack_state() -> void:
	if _store == null or _ui_overlay_stack == null:
		return

	var state: Dictionary = _store.get_state()
	var current_stack_variant: Array = U_SCENE_SELECTORS.get_scene_stack(state)
	var current_stack: Array[StringName] = []
	for entry in current_stack_variant:
		if entry is StringName:
			current_stack.append(entry)
		elif entry is String:
			current_stack.append(StringName(entry))

	var desired_stack: Array[StringName] = _get_overlay_scene_ids_from_ui()

	if _overlay_stacks_match(current_stack, desired_stack):
		return

	if current_stack.size() > 0:
		_clear_scene_stack_state(current_stack.size())

	for scene_id in desired_stack:
		_store.dispatch(U_SCENE_ACTIONS.push_overlay(scene_id))

## Collect overlay scene IDs from UIOverlayStack metadata
func _get_overlay_scene_ids_from_ui() -> Array[StringName]:
	return _overlay_helper.get_overlay_scene_ids_from_ui(_ui_overlay_stack)

## Clear scene_stack metadata by dispatching pop actions
func _clear_scene_stack_state(count: int) -> void:
	if _store == null or count <= 0:
		return

	for _i in range(count):
		_store.dispatch(U_SCENE_ACTIONS.pop_overlay())

## Compare overlay stacks for equality
func _overlay_stacks_match(stack_a: Array[StringName], stack_b: Array[StringName]) -> bool:
	return _overlay_helper.overlay_stacks_match(stack_a, stack_b)

## Update overlay visibility based on top overlay's hides_previous_overlays flag
func _update_overlay_visibility(overlay_ids: Array[StringName]) -> void:
	_overlay_helper.update_overlay_visibility(_ui_overlay_stack, overlay_ids)

## Get current scene ID from state
func get_current_scene() -> StringName:
	if _store == null:
		return StringName("")

	var state: Dictionary = _store.get_state()
	return U_SCENE_SELECTORS.get_current_scene_id(state)

## Check if currently transitioning
func is_transitioning() -> bool:
	if _store == null:
		return false

	var state: Dictionary = _store.get_state()
	return U_SCENE_SELECTORS.is_transitioning(state)

## Keep navigation shell/base scene aligned with the actual scene (manual transitions/tests)
## Phase 2 (T022): Removed _update_cursor_for_scene() - M_TimeManager now handles cursor state
func _sync_navigation_shell_with_scene(scene_id: StringName) -> void:
	if not _initial_navigation_synced:
		return
	if _store == null:
		return

	var state: Dictionary = _store.get_state()
	var nav_state: Dictionary = _store.get_slice(StringName("navigation"))
	if nav_state.is_empty():
		return

	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(scene_id)
	if scene_data.is_empty():
		return

	var scene_type: int = scene_data.get("scene_type", U_SCENE_REGISTRY.SceneType.GAMEPLAY)

	# T137c (Phase 10B-3): Delegate shell determination to handler
	var handler := _scene_type_handlers.get(scene_type) as I_SCENE_TYPE_HANDLER
	if handler == null:
		push_error("M_SceneManager: No handler registered for scene_type %d" % scene_type)
		return

	var desired_shell: StringName = handler.get_shell_id()

	var current_shell: StringName = U_NAVIGATION_SELECTORS.get_shell(state)
	var current_scene: StringName = U_NAVIGATION_SELECTORS.get_base_scene_id(state)

	# If navigation already matches the loaded scene, no reconciliation needed.
	if current_shell == desired_shell and current_scene == scene_id:
		return

	# When a navigation-driven transition is in progress, the navigation slice
	# is the source of truth. Avoid clobbering a newer navigation target with
	# stale scene_id values from earlier transitions.
	var pending_scene: StringName = _navigation_reconciler.get_pending_scene_id()
	if pending_scene != StringName(""):
		# Endgame scenes (death/victory) must always override any stale pending
		# navigation targets so UI state matches the actual loaded screen.
		if scene_type == U_SCENE_REGISTRY.SceneType.END_GAME:
			_navigation_reconciler.set_pending_scene_id(StringName(""))
			pending_scene = StringName("")
		else:
			# If navigation has requested a DIFFERENT scene than the one that just
			# finished loading, skip reconciliation entirely. This prevents races
			# where a late _sync_navigation_shell_with_scene call for a previous
			# scene overwrites the more recent navigation target.
			if pending_scene != scene_id:
				var pending_is_active: bool = pending_scene == _active_transition_target
				var pending_in_queue: bool = _transition_queue_helper.contains_scene(pending_scene)

				# If the pending scene isn't actively transitioning (or queued), treat it as stale.
				# This can happen on manual transitions like load-from-save, where the navigation
				# slice isn't the driver but a previous pending target was never cleared.
				if not pending_is_active and not pending_in_queue:
					_navigation_reconciler.set_pending_scene_id(StringName(""))
					pending_scene = StringName("")
				else:
					return
			else:
				return

	# T137c (Phase 10B-3): Dispatch navigation action from handler
	var nav_action := handler.get_navigation_action(scene_id)
	if not nav_action.is_empty():
		_store.dispatch(nav_action)

## Configure transition-specific settings (T209)
##
## Applies default configuration to transition effects after creation by factory.
## Centralizes transition configuration that was previously in _create_transition_effect().
##
## Parameters:
##   transition: The transition effect instance to configure
##   transition_type: The transition type name (for type-checking)
func _configure_transition(transition: BaseTransitionEffect, __transition_type: String) -> void:
	if transition == null:
		return

	# Configure fade transitions
	if transition is FADE_TRANSITION:
		var fade := transition as FADE_TRANSITION
		fade.duration = 0.2 # Shorter duration for faster tests

	# Configure loading screen transitions
	if transition is LOADING_SCREEN_TRANSITION:
		var loading := transition as LOADING_SCREEN_TRANSITION
		loading.min_duration = 1.5 # Minimum display time


## Get current scene type (helper for input handler)
func _get_current_scene_type() -> int:
	if _current_scene_id.is_empty():
		return -1
	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(_current_scene_id)
	return scene_data.get("scene_type", -1)

## Check if can navigate back in history (T110)
func can_go_back() -> bool:
	return _scene_history.size() > 0

## Navigate back to previous UI scene (T110)
func go_back() -> void:
	if not can_go_back():
		return # No history to go back to

	# Pop the most recent scene from history
	var previous_scene: StringName = _scene_history.pop_back()

	# Transition to that scene
	# Use HIGH priority to jump the queue for back navigation
	transition_to_scene(previous_scene, "instant", Priority.HIGH)

## Update scene history based on scene type (T111-T113)
func _update_scene_history(target_scene_id: StringName) -> void:
	# Get current and target scene types
	var current_scene_type: int = _get_current_scene_type()
	var target_scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(target_scene_id)
	var target_scene_type: int = target_scene_data.get("scene_type", -1)

	# T112 + T137c (Phase 10B-3): Delegate history tracking decision to handlers
	# Add current scene to history BEFORE transitioning (if handler says to track)
	var current_handler := _scene_type_handlers.get(current_scene_type) as I_SCENE_TYPE_HANDLER
	var should_track_current: bool = current_handler != null and current_handler.should_track_history()

	if should_track_current and not _current_scene_id.is_empty():
		# Avoid adding duplicate consecutive entries
		if _scene_history.is_empty() or _scene_history.back() != _current_scene_id:
			_scene_history.append(_current_scene_id)

	# T113 + T137c (Phase 10B-3): Clear history if target scene handler doesn't track
	# (e.g., GAMEPLAY scenes clear history stack, END_GAME scenes don't track)
	var target_handler := _scene_type_handlers.get(target_scene_type) as I_SCENE_TYPE_HANDLER
	if target_handler != null and not target_handler.should_track_history():
		_scene_history.clear()

## ============================================================================
## Phase 8: Scene Cache Management
## ============================================================================

## ============================================================================
## Phase 8: Scene Preloading at Startup
## ============================================================================

## Hint to preload a scene in background (Phase 8)
##
## Called when player approaches a door trigger to preload target scene.
## Non-blocking - loads in background while player is in trigger zone.
##
## @param scene_path: Resource path to .tscn file
func hint_preload_scene(scene_path: String) -> void:
	_scene_cache_helper.hint_preload_scene(scene_path)

## Validate scene contract (Phase 12.5 - T306)
##
## Checks that loaded scene meets required contract based on scene type.
## Logs errors and warnings but does NOT block scene loading (fail-safe design).
##
## Parameters:
##   scene: The loaded scene to validate
##   scene_id: Scene identifier for looking up scene type
##
## Returns:
##   void (logs errors but always continues)
func _validate_scene_contract(scene: Node, scene_id: StringName) -> void:
	_scene_loader.validate_scene_contract(scene, scene_id)
