extends GutTest

## Integration test for state persistence across scene transitions
##
## Tests that gameplay state (paused, move_input, jump_pressed, etc.) persists
## correctly when transitioning between scenes and across save/load cycles.
##
## Phase 4 - User Story 2: Persistent Game State (T068-T079)
## Tests follow TDD discipline: written BEFORE implementation validation.

const M_SceneManager = preload("res://scripts/core/managers/m_scene_manager.gd")
const M_StateStore = preload("res://scripts/core/state/m_state_store.gd")
const RS_SceneInitialState = preload("res://scripts/core/resources/state/rs_scene_initial_state.gd")
const RS_GameplayInitialState = preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const RS_StateStoreSettings = preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const U_SceneRegistry = preload("res://scripts/core/scene_management/u_scene_registry.gd")
const U_GameplayActions = preload("res://scripts/core/state/actions/u_gameplay_actions.gd")

var _root_scene: Node
var _manager: M_SceneManager
var _store: M_StateStore
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _test_save_path: String = "user://test_state_persistence_integration.json"

func before_each() -> void:
	U_ServiceLocator.clear()

	# Create root scene structure (includes HUDLayer + overlays)
	var root_ctx := U_SceneTestHelpers.create_root_with_containers(true)
	_root_scene = root_ctx["root"]
	add_child_autofree(_root_scene)
	_active_scene_container = root_ctx["active_scene_container"]
	_ui_overlay_stack = root_ctx["ui_overlay_stack"]

	# Create state store with all slices (including gameplay)
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_root_scene.add_child(_store)
	# Register state store via ServiceLocator BEFORE managers run _ready()
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

	U_SceneTestHelpers.register_scene_manager_dependencies(_root_scene)

	# Create scene manager
	_manager = M_SceneManager.new()
	_manager.skip_initial_scene_load = true  # Don't load main_menu automatically in tests
	_root_scene.add_child(_manager)
	await get_tree().process_frame

	# Clean up any existing test save file
	if FileAccess.file_exists(_test_save_path):
		DirAccess.remove_absolute(_test_save_path)

func after_each() -> void:
	# Remove root early to stop any active scene processing
	if _manager != null and is_instance_valid(_manager):
		await U_SceneTestHelpers.wait_for_transition_idle(_manager)
	if _root_scene != null and is_instance_valid(_root_scene):
		_root_scene.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame

	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

	_manager = null
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_root_scene = null

	# Clean up test save file
	if FileAccess.file_exists(_test_save_path):
		DirAccess.remove_absolute(_test_save_path)

## T071: Test gameplay state modification in gameplay scene
func test_modify_gameplay_state_in_gameplay_scene() -> void:
	# Load gameplay scene
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	# Get initial gameplay state
	var state_before: Dictionary = _store.get_state()
	var gameplay_before: Dictionary = state_before.get("gameplay", {})
	assert_eq(gameplay_before.get("paused"), false, "Should start unpaused")
	assert_eq(gameplay_before.get("move_input"), Vector2.ZERO, "Should start with zero move input")

	# Modify gameplay state
	_store.dispatch(U_GameplayActions.pause_game())
	_store.dispatch(U_GameplayActions.update_move_input(Vector2(1.0, 0.5)))
	await get_tree().physics_frame

	# Verify state was modified
	var state_after: Dictionary = _store.get_state()
	var gameplay_after: Dictionary = state_after.get("gameplay", {})
	assert_eq(gameplay_after.get("paused"), true, "Should be paused after action")
	assert_eq(gameplay_after.get("move_input"), Vector2(1.0, 0.5), "Should have updated move input")

## T072-T074: Test state persistence across scene transitions
func test_gameplay_state_persists_across_scene_transitions() -> void:
	# Load gameplay scene
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	# Modify gameplay state with distinct values
	_store.dispatch(U_GameplayActions.pause_game())
	_store.dispatch(U_GameplayActions.update_move_input(Vector2(0.8, -0.3)))
	_store.dispatch(U_GameplayActions.update_look_input(Vector2(0.2, 0.7)))
	_store.dispatch(U_GameplayActions.set_gravity_scale(1.5))
	await get_tree().physics_frame

	# Capture state before transition
	var state_before: Dictionary = _store.get_state()
	var gameplay_before: Dictionary = state_before.get("gameplay", {})
	assert_eq(gameplay_before.get("paused"), true, "Setup: Should be paused")
	assert_eq(gameplay_before.get("move_input"), Vector2(0.8, -0.3), "Setup: Should have move input")
	assert_eq(gameplay_before.get("look_input"), Vector2(0.2, 0.7), "Setup: Should have look input")
	assert_eq(gameplay_before.get("gravity_scale"), 1.5, "Setup: Should have custom gravity scale")

	# Transition to menu scene (T072)
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	# Verify gameplay state persists while in menu (T073)
	var state_in_menu: Dictionary = _store.get_state()
	var gameplay_in_menu: Dictionary = state_in_menu.get("gameplay", {})
	assert_eq(gameplay_in_menu.get("paused"), true, "Should preserve paused state in menu")
	assert_eq(gameplay_in_menu.get("move_input"), Vector2(0.8, -0.3), "Should preserve move input in menu")
	assert_eq(gameplay_in_menu.get("look_input"), Vector2(0.2, 0.7), "Should preserve look input in menu")
	assert_eq(gameplay_in_menu.get("gravity_scale"), 1.5, "Should preserve gravity scale in menu")

	# Transition back to gameplay scene (T073)
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	# Verify gameplay state still persists (T074)
	var state_back: Dictionary = _store.get_state()
	var gameplay_back: Dictionary = state_back.get("gameplay", {})
	assert_eq(gameplay_back.get("paused"), true, "Should preserve paused state after returning")
	assert_eq(gameplay_back.get("move_input"), Vector2(0.8, -0.3), "Should preserve move input after returning")
	assert_eq(gameplay_back.get("look_input"), Vector2(0.2, 0.7), "Should preserve look input after returning")
	assert_eq(gameplay_back.get("gravity_scale"), 1.5, "Should preserve gravity scale after returning")

## T075-T078: Test save/load cycle preserves gameplay state
func test_save_and_load_preserves_gameplay_state() -> void:
	# Load gameplay scene and modify state
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	# Set distinct gameplay state values
	_store.dispatch(U_GameplayActions.pause_game())
	_store.dispatch(U_GameplayActions.update_move_input(Vector2(-0.6, 0.9)))
	_store.dispatch(U_GameplayActions.update_look_input(Vector2(0.4, -0.2)))
	_store.dispatch(U_GameplayActions.set_gravity_scale(0.75))
	_store.dispatch(U_GameplayActions.set_show_landing_indicator(false))
	await get_tree().physics_frame

	# Capture state before save
	var state_before_save: Dictionary = _store.get_state()
	var gameplay_before_save: Dictionary = state_before_save.get("gameplay", {})
	var scene_before_save: Dictionary = state_before_save.get("scene", {})

	# Save state to disk (T076)
	var save_result: Error = _store.save_state(_test_save_path)
	assert_eq(save_result, OK, "Save should succeed")
	assert_true(FileAccess.file_exists(_test_save_path), "Save file should exist")

	# Modify state after save to verify load actually restores
	_store.dispatch(U_GameplayActions.unpause_game())
	_store.dispatch(U_GameplayActions.update_move_input(Vector2.ZERO))
	_store.dispatch(U_GameplayActions.set_gravity_scale(1.0))
	await get_tree().physics_frame

	var state_modified: Dictionary = _store.get_state()
	var gameplay_modified: Dictionary = state_modified.get("gameplay", {})
	assert_eq(gameplay_modified.get("paused"), false, "Setup: Should be modified after save")
	assert_eq(gameplay_modified.get("move_input"), Vector2.ZERO, "Setup: Should be modified after save")

	# Load state from disk (T077)
	var load_result: Error = _store.load_state(_test_save_path)
	assert_eq(load_result, OK, "Load should succeed")

	# Verify gameplay state was restored correctly (T078)
	var state_after_load: Dictionary = _store.get_state()
	var gameplay_after_load: Dictionary = state_after_load.get("gameplay", {})
	var scene_after_load: Dictionary = state_after_load.get("scene", {})

	# Check gameplay slice restoration
	assert_eq(gameplay_after_load.get("paused"), gameplay_before_save.get("paused"), "Should restore paused state")
	assert_eq(gameplay_after_load.get("move_input"), gameplay_before_save.get("move_input"), "Should restore move input")
	assert_eq(gameplay_after_load.get("look_input"), gameplay_before_save.get("look_input"), "Should restore look input")
	assert_eq(gameplay_after_load.get("gravity_scale"), gameplay_before_save.get("gravity_scale"), "Should restore gravity scale")
	assert_eq(gameplay_after_load.get("show_landing_indicator"), gameplay_before_save.get("show_landing_indicator"), "Should restore landing indicator setting")

	# Check scene slice restoration
	assert_eq(scene_after_load.get("current_scene_id"), scene_before_save.get("current_scene_id"), "Should restore current scene")

## T079: Manual test scenario - comprehensive state persistence flow
## This test simulates the full user journey: play → collect → transition → save → reload → verify
func test_comprehensive_state_persistence_flow() -> void:
	# Start gameplay
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	# Simulate player actions (setting various state flags)
	_store.dispatch(U_GameplayActions.update_move_input(Vector2(1.0, 0.0)))  # Moving right
	_store.dispatch(U_GameplayActions.update_look_input(Vector2(0.3, -0.5)))  # Looking direction
	_store.dispatch(U_GameplayActions.set_jump_pressed(true))  # Jump held
	await get_tree().physics_frame

	# Verify initial state
	var state1: Dictionary = _store.get_state()
	var gameplay1: Dictionary = state1.get("gameplay", {})
	assert_eq(gameplay1.get("move_input"), Vector2(1.0, 0.0), "Player should be moving")
	assert_eq(gameplay1.get("jump_pressed"), true, "Jump should be held")

	# Transition to interior (simulate area transition)
	_manager.transition_to_scene(StringName("scene1"), "instant")
	await wait_physics_frames(2)

	# Verify state persists in new scene
	var state2: Dictionary = _store.get_state()
	var gameplay2: Dictionary = state2.get("gameplay", {})
	assert_eq(gameplay2.get("move_input"), Vector2(1.0, 0.0), "Move input should persist")
	assert_eq(gameplay2.get("jump_pressed"), true, "Jump state should persist")

	# Return to gameplay
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	# Modify state further
	_store.dispatch(U_GameplayActions.pause_game())
	_store.dispatch(U_GameplayActions.set_gravity_scale(2.0))
	await get_tree().physics_frame

	# Save game
	var save_result: Error = _store.save_state(_test_save_path)
	assert_eq(save_result, OK, "Save should succeed")

	# Reset some state to simulate fresh load
	_store.dispatch(U_GameplayActions.unpause_game())
	_store.dispatch(U_GameplayActions.update_move_input(Vector2.ZERO))
	_store.dispatch(U_GameplayActions.set_jump_pressed(false))
	_store.dispatch(U_GameplayActions.set_gravity_scale(1.0))
	await get_tree().physics_frame

	# Load saved game
	var load_result: Error = _store.load_state(_test_save_path)
	assert_eq(load_result, OK, "Load should succeed")

	# Verify all state restored
	var state_final: Dictionary = _store.get_state()
	var gameplay_final: Dictionary = state_final.get("gameplay", {})
	assert_eq(gameplay_final.get("paused"), true, "Paused state should be restored")
	assert_eq(gameplay_final.get("move_input"), Vector2(1.0, 0.0), "Move input should be restored")
	assert_eq(gameplay_final.get("jump_pressed"), true, "Jump state should be restored")
	assert_eq(gameplay_final.get("gravity_scale"), 2.0, "Gravity scale should be restored")
	assert_eq(gameplay_final.get("look_input"), Vector2(0.3, -0.5), "Look input should be restored")

## Test that transient scene fields are NOT saved
func test_transient_scene_fields_excluded_from_save() -> void:
	# Load scene and start transition
	_manager.transition_to_scene(StringName("demo_room"), "fade")
	await get_tree().physics_frame

	# Verify transient fields exist in state during transition
	var state_during: Dictionary = _store.get_state()
	var scene_during: Dictionary = state_during.get("scene", {})
	assert_true(scene_during.has("is_transitioning"), "is_transitioning should exist in state")

	# Save state
	var save_result: Error = _store.save_state(_test_save_path)
	assert_eq(save_result, OK, "Save should succeed")

	# Read the saved file directly
	var file: FileAccess = FileAccess.open(_test_save_path, FileAccess.READ)
	assert_not_null(file, "Should be able to open save file")
	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Dictionary = JSON.parse_string(json_text) as Dictionary
	var saved_scene_slice: Dictionary = parsed.get("scene", {})

	# Verify transient fields are excluded from save file
	assert_false(saved_scene_slice.has("is_transitioning"), "is_transitioning should be excluded from save")
	assert_false(saved_scene_slice.has("transition_type"), "transition_type should be excluded from save")

	# Verify persistent fields ARE saved
	assert_true(saved_scene_slice.has("current_scene_id"), "current_scene_id should be saved")

## Test gameplay slice preservation across multiple transitions
func test_gameplay_state_survives_multiple_transitions() -> void:
	# Set initial state
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	_store.dispatch(U_GameplayActions.update_move_input(Vector2(0.5, 0.5)))
	_store.dispatch(U_GameplayActions.set_gravity_scale(1.25))
	await get_tree().physics_frame

	# Perform multiple transitions
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	_manager.transition_to_scene(StringName("settings_panel"), "instant")
	await wait_physics_frames(2)

	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	# Verify state survived all transitions
	var state_final: Dictionary = _store.get_state()
	var gameplay_final: Dictionary = state_final.get("gameplay", {})
	assert_eq(gameplay_final.get("move_input"), Vector2(0.5, 0.5), "Move input should survive multiple transitions")
	assert_eq(gameplay_final.get("gravity_scale"), 1.25, "Gravity scale should survive multiple transitions")

## Test particle settings persistence
func test_particle_settings_persist() -> void:
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	# Modify particle settings
	_store.dispatch(U_GameplayActions.set_particle_settings({
		"jump_particles_enabled": false,
		"landing_particles_enabled": false
	}))
	await get_tree().physics_frame

	# Transition to menu
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	# Verify particle settings persisted
	var state: Dictionary = _store.get_state()
	var gameplay: Dictionary = state.get("gameplay", {})
	var particle_settings: Dictionary = gameplay.get("particle_settings", {})
	assert_eq(particle_settings.get("jump_particles_enabled"), false, "Jump particles setting should persist")
	assert_eq(particle_settings.get("landing_particles_enabled"), false, "Landing particles setting should persist")

## Test audio settings persistence
func test_audio_settings_persist() -> void:
	_manager.transition_to_scene(StringName("demo_room"), "instant")
	await wait_physics_frames(2)

	# Modify audio settings
	_store.dispatch(U_GameplayActions.set_audio_settings({
		"jump_sound_enabled": false,
		"volume": 0.5,
		"pitch_scale": 1.2
	}))
	await get_tree().physics_frame

	# Save and load
	_store.save_state(_test_save_path)

	# Reset settings
	_store.dispatch(U_GameplayActions.set_audio_settings({
		"jump_sound_enabled": true,
		"volume": 1.0,
		"pitch_scale": 1.0
	}))
	await get_tree().physics_frame

	# Load saved state
	_store.load_state(_test_save_path)

	# Verify audio settings restored
	var state: Dictionary = _store.get_state()
	var gameplay: Dictionary = state.get("gameplay", {})
	var audio_settings: Dictionary = gameplay.get("audio_settings", {})
	assert_eq(audio_settings.get("jump_sound_enabled"), false, "Jump sound setting should be restored")
	assert_almost_eq(audio_settings.get("volume", 0.0), 0.5, 0.01, "Volume should be restored")
	assert_almost_eq(audio_settings.get("pitch_scale", 0.0), 1.2, 0.01, "Pitch scale should be restored")
