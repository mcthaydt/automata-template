extends GutTest

# Test suite for M_AudioManager scaffolding, bus layout, and music (Audio Phases 1-2)

const M_AUDIO_MANAGER := preload("res://scripts/core/managers/m_audio_manager.gd")
const M_STATE_STORE := preload("res://scripts/core/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const RS_SETTINGS_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_settings_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_navigation_initial_state.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_audio_initial_state.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AUDIO_SERIALIZATION := preload("res://scripts/core/utils/u_audio_serialization.gd")
const U_AUDIO_ACTIONS := preload("res://scripts/core/state/actions/u_audio_actions.gd")
const U_APP_ACTIONS := preload("res://scripts/core/state/actions/u_app_actions.gd")
const U_SCENE_ACTIONS := preload("res://scripts/core/state/actions/u_scene_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/core/state/actions/u_navigation_actions.gd")
const U_SFX_SPAWNER := preload("res://scripts/core/managers/helpers/u_sfx_spawner.gd")
const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")

const STREAM_MAIN_MENU := preload("res://assets/core/audio/music/mus_main_menu.mp3")
const STREAM_ALLEYWAY := preload("res://assets/demo/audio/music/mus_alleyway.mp3")
const STREAM_PAUSE := preload("res://assets/core/audio/music/mus_pause.mp3")
const STREAM_CREDITS := preload("res://assets/core/audio/music/mus_credits.mp3")

var _manager: Node
var _store: Node

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_reset_audio_buses()
	_manager = null
	_store = null

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_reset_audio_buses()
	_manager = null
	_store = null

func test_manager_extends_node() -> void:
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)

	assert_true(_manager is Node, "M_AudioManager should extend Node")

func test_manager_sets_process_mode_always() -> void:
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	assert_eq(_manager.process_mode, Node.PROCESS_MODE_ALWAYS, "M_AudioManager should process even when tree paused")

func test_manager_registers_with_service_locator() -> void:
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var service := U_SERVICE_LOCATOR.get_service(StringName("audio_manager"))
	assert_not_null(service, "M_AudioManager should register with ServiceLocator")
	assert_eq(service, _manager, "ServiceLocator should return the Audio manager instance")

func test_manager_validates_audio_bus_layout() -> void:
	# Test helper creates required bus layout before manager initialization
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Verify all required buses exist
	assert_eq(AudioServer.bus_count, 6, "Audio bus count should be 6 (Master + 5)")
	assert_eq(AudioServer.get_bus_name(0), "Master", "Bus 0 should be Master")
	assert_eq(AudioServer.get_bus_name(1), "Music", "Bus 1 should be Music")
	assert_eq(AudioServer.get_bus_name(2), "SFX", "Bus 2 should be SFX")
	assert_eq(AudioServer.get_bus_name(3), "UI", "Bus 3 should be UI")
	assert_eq(AudioServer.get_bus_name(4), "Footsteps", "Bus 4 should be Footsteps")
	assert_eq(AudioServer.get_bus_name(5), "Ambient", "Bus 5 should be Ambient")

	# Parent/child relationships
	assert_eq(AudioServer.get_bus_send(1), "Master", "Music should send to Master")
	assert_eq(AudioServer.get_bus_send(2), "Master", "SFX should send to Master")
	assert_eq(AudioServer.get_bus_send(3), "SFX", "UI should send to SFX")
	assert_eq(AudioServer.get_bus_send(4), "SFX", "Footsteps should send to SFX")
	assert_eq(AudioServer.get_bus_send(5), "Master", "Ambient should send to Master")

func test_manager_validates_successfully_with_extra_buses() -> void:
	# Add an extra bus beyond the required ones
	AudioServer.add_bus()
	AudioServer.set_bus_name(6, "Extra")
	assert_eq(AudioServer.bus_count, 7, "Precondition: Extra bus added")

	# Manager should validate successfully (all required buses still present)
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Verify manager initialized without errors (bus layout is valid)
	assert_not_null(_manager, "Manager should initialize successfully")
	assert_eq(AudioServer.bus_count, 7, "Extra bus should remain after validation")

# ============================================================================
# Phase 1 - Volume conversion and application tests (Tasks 1.3/1.4)
# ============================================================================

func test_linear_to_db_conversion() -> void:
	assert_almost_eq(M_AUDIO_MANAGER._linear_to_db(0.0), -80.0, 0.001, "0.0 should map to -80dB")
	assert_almost_eq(M_AUDIO_MANAGER._linear_to_db(1.0), 0.0, 0.001, "1.0 should map to 0dB")
	assert_almost_eq(M_AUDIO_MANAGER._linear_to_db(0.5), -6.0206, 0.05, "0.5 should map to ~-6dB")

func test_volume_and_mute_apply_to_buses_via_state_store() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var ambient_idx := AudioServer.get_bus_index("Ambient")

	# Set volumes
	_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(0.5))
	_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(0.25))
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_volume(0.75))
	_store.dispatch(U_AUDIO_ACTIONS.set_ambient_volume(0.0))

	assert_almost_eq(AudioServer.get_bus_volume_db(master_idx), -6.0206, 0.05)
	assert_almost_eq(AudioServer.get_bus_volume_db(music_idx), -12.0412, 0.05)
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx_idx), -2.4988, 0.05)
	assert_almost_eq(AudioServer.get_bus_volume_db(ambient_idx), -80.0, 0.001)

	# Mutes (independent of volume)
	_store.dispatch(U_AUDIO_ACTIONS.set_music_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_muted(true))

	assert_false(AudioServer.is_bus_mute(master_idx))
	assert_true(AudioServer.is_bus_mute(music_idx))
	assert_true(AudioServer.is_bus_mute(sfx_idx))
	assert_false(AudioServer.is_bus_mute(ambient_idx))

	# Volume remains unchanged when muted
	assert_almost_eq(AudioServer.get_bus_volume_db(music_idx), -12.0412, 0.05)
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx_idx), -2.4988, 0.05)

func test_spatial_audio_setting_updates_sfx_spawner() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	assert_true(U_SFX_SPAWNER.is_spatial_audio_enabled(), "Precondition: spatial audio enabled by default")

	_store.dispatch(U_AUDIO_ACTIONS.set_spatial_audio_enabled(false))

	assert_false(U_SFX_SPAWNER.is_spatial_audio_enabled(), "Spatial audio toggle should update U_SFXSpawner")

func test_app_focus_loss_mutes_master_and_focus_gain_restores_previous_mute() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var master_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, false)

	_store.dispatch(U_APP_ACTIONS.app_focus_lost())
	await get_tree().process_frame
	assert_true(AudioServer.is_bus_mute(master_idx), "Focus loss should mute master bus")

	_store.dispatch(U_APP_ACTIONS.app_focus_gained())
	await get_tree().process_frame
	assert_false(AudioServer.is_bus_mute(master_idx), "Focus gain should restore previous master mute state")

func test_app_focus_gain_preserves_user_master_mute_when_previously_muted() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var master_idx := AudioServer.get_bus_index("Master")
	_store.dispatch(U_AUDIO_ACTIONS.set_master_muted(true))
	await get_tree().process_frame
	assert_true(AudioServer.is_bus_mute(master_idx), "Precondition: user master mute should be applied")

	_store.dispatch(U_APP_ACTIONS.app_focus_lost())
	await get_tree().process_frame
	assert_true(AudioServer.is_bus_mute(master_idx), "Focus loss should keep master muted")

	_store.dispatch(U_APP_ACTIONS.app_focus_gained())
	await get_tree().process_frame
	assert_true(AudioServer.is_bus_mute(master_idx), "Focus gain should preserve prior user mute")

func _make_store_with_audio_slice() -> Node:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_history = false
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	store.settings_initial_state = RS_SETTINGS_INITIAL_STATE.new()
	store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	store.audio_initial_state = RS_AUDIO_INITIAL_STATE.new()
	return store

func _reset_audio_buses() -> void:
	U_AUDIO_TEST_HELPERS.reset_audio_buses()

# ============================================================================
# Phase 2 - Music system tests (Tasks 2.2-2.5)
# ============================================================================

func test_music_players_initialized_and_use_music_bus() -> void:
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var player_a := _manager.get_node_or_null("MusicPlayerA") as AudioStreamPlayer
	var player_b := _manager.get_node_or_null("MusicPlayerB") as AudioStreamPlayer

	assert_not_null(player_a, "MusicPlayerA should exist")
	assert_not_null(player_b, "MusicPlayerB should exist")
	assert_eq(player_a.bus, "Music", "MusicPlayerA should use Music bus")
	assert_eq(player_b.bus, "Music", "MusicPlayerB should use Music bus")

func test_play_music_starts_requested_track() -> void:
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	_manager.play_music(StringName("main_menu"), 0.1)
	await get_tree().process_frame

	assert_true(_is_stream_playing(_manager, STREAM_MAIN_MENU), "Should be playing main_menu placeholder track")

func test_scene_transition_completed_plays_music_for_scene() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	await get_tree().process_frame

	assert_true(_is_stream_playing(_manager, STREAM_MAIN_MENU), "main_menu transition should start main_menu track")

func test_pause_actions_switch_to_pause_track_and_restore() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	_store.dispatch(U_NAVIGATION_ACTIONS.start_game(StringName("demo_room")))
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
	await get_tree().process_frame

	assert_true(_is_stream_playing(_manager, STREAM_ALLEYWAY), "Should be playing demo room track before pausing")

	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame

	assert_true(_is_stream_playing(_manager, STREAM_PAUSE), "open_pause should crossfade to pause track")

	_store.dispatch(U_NAVIGATION_ACTIONS.close_pause())
	await get_tree().process_frame

	assert_true(_is_stream_playing(_manager, STREAM_ALLEYWAY), "close_pause should restore previous track")

func _is_stream_playing(manager: Node, stream: AudioStream) -> bool:
	var player_a := manager.get_node_or_null("MusicPlayerA") as AudioStreamPlayer
	var player_b := manager.get_node_or_null("MusicPlayerB") as AudioStreamPlayer

	if player_a != null and player_a.playing and player_a.stream == stream:
		return true
	if player_b != null and player_b.playing and player_b.stream == stream:
		return true
	return false

# ============================================================================
# Regression tests for music system bugs
# ============================================================================

func test_scene_transition_to_demo_room_plays_demo_room_music() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
	await get_tree().process_frame

	assert_true(_is_stream_playing(_manager, STREAM_ALLEYWAY), "demo_room scene should play demo room music")

func test_scene_transition_to_credits_plays_credits_music() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("credits")))
	await get_tree().process_frame

	assert_true(_is_stream_playing(_manager, STREAM_CREDITS), "credits scene should play credits music")

func test_transition_between_main_menu_and_demo_room() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Start in main menu
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_MAIN_MENU), "Should play main menu music")

	# Go to demo room
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_ALLEYWAY), "Should crossfade to demo room music")

	# Return to main menu
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_MAIN_MENU), "Should crossfade back to main menu music")

func test_return_to_main_menu_from_pause_clears_pause_state() -> void:
	# Regression test for bug: pausing in gameplay, then returning to main menu
	# would leave pause music playing forever
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Start in demo room
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_ALLEYWAY), "Should start with demo room music")

	# Pause
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_PAUSE), "Should play pause music")

	# Return to main menu (from pause overlay)
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_MAIN_MENU), "Should play main menu music, not pause music")

	# Continue to demo room again
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_ALLEYWAY), "Should play demo room music")

	# Pause again
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_PAUSE), "Should play pause music again (not skip)")

func test_unregistered_scene_keeps_current_music() -> void:
	# Scenes without registered music should keep current track playing
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Start with main menu music
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_MAIN_MENU), "Should play main menu music")

	# Transition to unregistered scene (e.g., settings, which has no music)
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("settings_screen")))
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_MAIN_MENU), "Should keep main menu music playing")

func test_playing_same_track_skips_crossfade() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Play main menu music
	_manager.play_music(StringName("main_menu"), 0.1)
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_MAIN_MENU), "Should play main menu music")

	var player_a := _manager.get_node_or_null("MusicPlayerA") as AudioStreamPlayer
	var player_b := _manager.get_node_or_null("MusicPlayerB") as AudioStreamPlayer
	var active_player_before: AudioStreamPlayer = null
	if player_a.playing:
		active_player_before = player_a
	else:
		active_player_before = player_b

	# Try to play same track again
	_manager.play_music(StringName("main_menu"), 0.1)
	await get_tree().process_frame

	# Should not swap players (skip crossfade)
	var active_player_after: AudioStreamPlayer = null
	if player_a.playing:
		active_player_after = player_a
	else:
		active_player_after = player_b

	assert_eq(active_player_before, active_player_after, "Should not swap players when playing same track")

func test_pause_while_paused_updates_return_track() -> void:
	# If transitioning scenes while paused, should update the return-to track
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Start in demo room
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
	await get_tree().process_frame

	# Pause
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_PAUSE), "Should play pause music")

	# Scene transitions to credits while paused (shouldn't happen often, but edge case)
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("credits")))
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_PAUSE), "Should still play pause music")

	# Unpause
	_store.dispatch(U_NAVIGATION_ACTIONS.close_pause())
	await get_tree().process_frame
	assert_true(_is_stream_playing(_manager, STREAM_CREDITS), "Should restore to updated return track")


## Phase 9: Hash-based optimization tests

func test_hash_based_change_detection_skips_redundant_updates() -> void:
	# Given: Manager with initial audio settings
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var initial_master_volume := AudioServer.get_bus_volume_db(0)

	# When: Dispatching non-audio action (doesn't change audio slice)
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
	await get_tree().process_frame

	# Then: Audio settings should not be re-applied (hash unchanged)
	var master_volume_after := AudioServer.get_bus_volume_db(0)
	assert_eq(master_volume_after, initial_master_volume, "Master volume should remain unchanged")


func test_hash_based_change_detection_applies_when_audio_slice_changes() -> void:
	# Given: Manager with initial audio settings (master_volume = 1.0 by default → 0dB)
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var initial_master_volume := AudioServer.get_bus_volume_db(0)

	# When: Changing master volume to a very different value (changes audio slice hash)
	_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(0.1))
	await get_tree().process_frame

	# Then: Audio settings should be re-applied (0.1 linear ≈ -20dB, much lower than 0dB)
	var master_volume_after := AudioServer.get_bus_volume_db(0)
	assert_lt(master_volume_after, initial_master_volume - 10.0, "Master volume should decrease significantly when audio slice changes")


func test_multiple_redundant_updates_only_apply_once() -> void:
	# Given: Manager with initial audio settings
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Set initial volume
	_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(0.7))
	await get_tree().process_frame
	var volume_after_first := AudioServer.get_bus_volume_db(0)

	# When: Dispatching multiple non-audio actions
	for i in range(5):
		_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
		await get_tree().process_frame

	# Then: Volume should remain the same (no redundant updates)
	var volume_after_multiple := AudioServer.get_bus_volume_db(0)
	assert_eq(volume_after_multiple, volume_after_first, "Volume should remain unchanged after redundant updates")
