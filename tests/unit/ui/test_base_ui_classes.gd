extends GutTest

const OverlayStub := preload("res://tests/test_doubles/ui/overlay_stub.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const RS_UI_MOTION_SET := preload("res://scripts/core/resources/ui/rs_ui_motion_set.gd")
const RS_UI_MOTION_PRESET := preload("res://scripts/core/resources/ui/rs_ui_motion_preset.gd")
const MENU_FULLSCREEN_SHADER := preload("res://assets/core/shaders/sh_menu_fullscreen_shader.gdshader")


var _mock_audio_manager: MockAudioManager


func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_mock_audio_manager = MockAudioManager.new()
	add_child_autofree(_mock_audio_manager)
	U_SERVICE_LOCATOR.register(StringName("audio_manager"), _mock_audio_manager)


func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_mock_audio_manager = null

func test_base_panel_focuses_first_focusable_child() -> void:
	var store := await _create_state_store()
	assert_not_null(store, "State store should be available for BasePanel tests")

	var panel := BasePanel.new()
	var unfocusable_button := Button.new()
	unfocusable_button.focus_mode = Control.FOCUS_NONE
	panel.add_child(unfocusable_button)

	var focus_button := Button.new()
	focus_button.name = "SecondButton"
	focus_button.focus_mode = Control.FOCUS_ALL
	panel.add_child(focus_button)

	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_true(focus_button.has_focus(),
		"BasePanel should automatically focus the first focusable descendant control")

func test_base_panel_does_not_play_focus_sound_when_applying_initial_focus() -> void:
	await _create_state_store()
	var panel := BasePanel.new()
	var focus_button := Button.new()
	focus_button.focus_mode = Control.FOCUS_ALL
	panel.add_child(focus_button)
	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_eq(_mock_audio_manager.played, [],
		"Initial/programmatic focus should not trigger a focus sound")

func test_base_panel_plays_focus_sound_only_when_armed_by_navigation_action() -> void:
	await _create_state_store()
	var panel := BasePanel.new()

	var button_a := Button.new()
	button_a.name = "ButtonA"
	button_a.focus_mode = Control.FOCUS_ALL
	panel.add_child(button_a)

	var button_b := Button.new()
	button_b.name = "ButtonB"
	button_b.focus_mode = Control.FOCUS_ALL
	panel.add_child(button_b)

	add_child_autofree(panel)
	await wait_process_frames(3)
	assert_true(button_a.has_focus(), "Initial focus should be on ButtonA")

	_mock_audio_manager.played.clear()

	var down_event := InputEventAction.new()
	down_event.action = "ui_down"
	down_event.pressed = true
	panel._input(down_event)

	button_b.grab_focus()
	await wait_process_frames(1)

	assert_eq(_mock_audio_manager.played, [StringName("ui_focus")],
		"Focus sound should play only after a navigation input moves focus")

func test_base_panel_does_not_arm_focus_sound_for_joypad_motion_events() -> void:
	await _create_state_store()
	var panel := BasePanel.new()

	var button_a := Button.new()
	button_a.focus_mode = Control.FOCUS_ALL
	panel.add_child(button_a)

	var button_b := Button.new()
	button_b.focus_mode = Control.FOCUS_ALL
	panel.add_child(button_b)

	add_child_autofree(panel)
	await wait_process_frames(3)
	assert_true(button_a.has_focus(), "Initial focus should be on the first button")

	_mock_audio_manager.played.clear()

	var motion_event := InputEventJoypadMotion.new()
	motion_event.axis = JOY_AXIS_LEFT_Y
	motion_event.axis_value = 1.0
	panel._input(motion_event)

	button_b.grab_focus()
	await wait_process_frames(1)

	assert_eq(_mock_audio_manager.played, [],
		"Joypad motion should not arm focus sounds (analog navigation arms at grab_focus)")

func test_base_menu_screen_plays_focus_sound_on_analog_navigation() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()

	var button_a := Button.new()
	button_a.name = "ButtonA"
	button_a.focus_mode = Control.FOCUS_ALL
	screen.add_child(button_a)

	var button_b := Button.new()
	button_b.name = "ButtonB"
	button_b.focus_mode = Control.FOCUS_ALL
	screen.add_child(button_b)

	button_a.focus_neighbor_bottom = button_a.get_path_to(button_b)
	button_b.focus_neighbor_top = button_b.get_path_to(button_a)

	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_true(button_a.has_focus(), "Initial focus should be on ButtonA")

	_mock_audio_manager.played.clear()

	screen._navigate_focus(StringName("ui_down"))
	await wait_process_frames(1)

	assert_true(button_b.has_focus(), "Analog navigation should move focus to ButtonB")
	assert_eq(_mock_audio_manager.played, [StringName("ui_focus")],
		"Analog navigation focus moves should trigger focus sound")

func test_base_overlay_handles_ui_cancel_back_action() -> void:
	await _create_state_store()
	var overlay := OverlayStub.new()
	var button := Button.new()
	overlay.add_child(button)
	add_child_autofree(overlay)
	await wait_process_frames(3)

	assert_eq(overlay.process_mode, Node.PROCESS_MODE_ALWAYS,
		"BaseOverlay should process even when the tree is paused")

	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	overlay._unhandled_input(cancel_event)

	assert_true(overlay.back_pressed,
		"BaseOverlay should call _on_back_pressed() when ui_cancel is pressed")

func test_base_panel_exposes_state_store_reference() -> void:
	var store := await _create_state_store()
	var panel := BasePanel.new()
	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_is(panel.get_store(), M_StateStore,
		"BasePanel should store an M_StateStore reference after ready")
	assert_eq(panel.get_store(), store,
		"BasePanel should resolve the same store instance in the scene tree")

func test_base_panel_null_motion_set_no_bind() -> void:
	await _create_state_store()
	var panel := BasePanel.new()
	panel.motion_set = null

	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	panel.add_child(button)

	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_eq(button.mouse_entered.get_connections().size(), 0,
		"Null motion_set should not bind hover-in signal")
	assert_eq(button.mouse_exited.get_connections().size(), 0,
		"Null motion_set should not bind hover-out signal")
	assert_eq(button.focus_entered.get_connections().size(), 0,
		"Null motion_set should not bind focus-in signal")
	assert_eq(button.focus_exited.get_connections().size(), 0,
		"Null motion_set should not bind focus-out signal")

func test_base_panel_motion_set_binds_focusable_children() -> void:
	await _create_state_store()
	var panel := BasePanel.new()
	panel.motion_set = _make_interactive_motion_set()

	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	panel.add_child(button)

	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_gt(button.mouse_entered.get_connections().size(), 0,
		"Motion set should bind hover-in signal for focusable children")
	assert_gt(button.mouse_exited.get_connections().size(), 0,
		"Motion set should bind hover-out signal for focusable children")

func test_base_menu_screen_play_enter_with_motion_set() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()
	screen.motion_set = _make_enter_motion_set(0.12)
	add_child_autofree(screen)
	await wait_process_frames(3)

	var tween: Tween = screen.play_enter_animation()
	assert_not_null(tween, "play_enter_animation should return a Tween when motion_set.enter is defined")
	await wait_process_frames(1)
	assert_true(screen.modulate.a < 0.99, "Enter animation should apply the from alpha near start")

	await wait_seconds(0.08)
	assert_true(screen.modulate.a > 0.01,
		"Enter animation should modify screen alpha while tween is in progress")

func test_base_menu_screen_play_enter_without_motion_set_returns_null() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()
	screen.motion_set = null
	add_child_autofree(screen)
	await wait_process_frames(3)

	var tween: Tween = screen.play_enter_animation()
	assert_null(tween, "play_enter_animation should return null when motion_set is missing")

func test_base_menu_screen_targets_center_container_when_backdrop_and_panel_exist() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()
	screen.motion_set = _make_enter_motion_set(0.12)

	var background := ColorRect.new()
	background.name = "Background"
	screen.add_child(background)

	var center_container := CenterContainer.new()
	center_container.name = "CenterContainer"
	screen.add_child(center_container)

	var panel := PanelContainer.new()
	panel.name = "MainPanel"
	center_container.add_child(panel)

	add_child_autofree(screen)
	await wait_process_frames(3)

	var tween: Tween = screen.play_enter_animation()
	assert_not_null(tween, "play_enter_animation should return a Tween when backdrop + centered panel is present")
	assert_almost_eq(screen.modulate.a, 1.0, 0.01,
		"Screen root should not animate when centered panel targeting is active")
	await wait_process_frames(1)
	assert_true(center_container.modulate.a < 0.99,
		"Center container should receive enter animation while root remains static")

	await wait_seconds(0.08)
	assert_true(center_container.modulate.a > 0.01,
		"Center container should animate alpha during enter tween")

func test_base_menu_screen_auto_provisions_background_image_instead_of_shader() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()
	screen.background_shader_preset = "retro_grid"

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.2, 0.15, 0.3, 1.0)
	screen.add_child(background)

	add_child_autofree(screen)
	await wait_process_frames(3)

	var bg_image := screen.get_node_or_null("BackgroundImage") as TextureRect
	assert_not_null(bg_image, "Preset should auto-provision BackgroundImage instead of shader")
	if bg_image == null:
		return
	assert_ne(bg_image.texture, null, "Auto-provisioned BackgroundImage should have texture loaded")
	assert_eq(
		bg_image.stretch_mode,
		TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"Auto-provisioned BackgroundImage should cover the full screen without letterboxing"
	)
	assert_null(screen.get("_background_shader_material"), "Should not create shader material when BackgroundImage is auto-provisioned")

func test_base_menu_screen_background_shader_noop_when_preset_none_or_background_missing() -> void:
	await _create_state_store()

	var none_screen := BaseMenuScreen.new()
	none_screen.background_shader_preset = "none"
	var none_background := ColorRect.new()
	none_background.name = "Background"
	none_screen.add_child(none_background)
	add_child_autofree(none_screen)

	var missing_background_screen := BaseMenuScreen.new()
	missing_background_screen.background_shader_preset = "retro_grid"
	add_child_autofree(missing_background_screen)

	await wait_process_frames(3)

	assert_null(none_background.material, "Preset none should leave Background material untouched")
	assert_not_null(
		missing_background_screen.get_node_or_null("BackgroundImage"),
		"Missing Background node with valid preset should auto-provision BackgroundImage"
	)

func test_base_menu_screen_background_shader_preset_mode_mapping() -> void:
	assert_eq(BaseMenuScreen.BACKGROUND_SHADER_PRESET_MODE_BY_ID["retro_grid"], 0, "retro_grid should map to mode 0")
	assert_eq(BaseMenuScreen.BACKGROUND_SHADER_PRESET_MODE_BY_ID["scanline_drift"], 1, "scanline_drift should map to mode 1")
	assert_eq(BaseMenuScreen.BACKGROUND_SHADER_PRESET_MODE_BY_ID["arcade_noise"], 2, "arcade_noise should map to mode 2")

func test_background_image_skips_shader_setup() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()
	var bg_image := TextureRect.new()
	bg_image.name = "BackgroundImage"
	bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.add_child(bg_image)
	screen.background_shader_preset = "retro_grid"
	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_eq(
		bg_image.stretch_mode,
		TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"Existing BackgroundImage should be configured to cover the full screen"
	)
	assert_null(screen.get("_background_shader_material"), "Should skip shader when BackgroundImage present")
	assert_null(screen.get("_background_rect"), "Should not set _background_rect when BackgroundImage present")

func test_background_image_takes_priority_over_color_rect() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()
	var color_rect := ColorRect.new()
	color_rect.name = "Background"
	screen.add_child(color_rect)
	var bg_image := TextureRect.new()
	bg_image.name = "BackgroundImage"
	screen.add_child(bg_image)
	screen.background_shader_preset = "retro_grid"
	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_null(screen.get("_background_shader_material"), "BackgroundImage should take priority over ColorRect")

func test_base_overlay_animates_dim_on_enter() -> void:
	await _create_state_store()
	var overlay := OverlayStub.new()
	overlay.motion_set = _make_enter_motion_set(0.12)
	overlay.background_color = Color(0, 0, 0, 0.7)
	add_child_autofree(overlay)
	await wait_process_frames(3)

	var background := overlay.get_node_or_null("OverlayBackground") as ColorRect
	assert_not_null(background, "Overlay should create a background dim panel")

	var tween: Tween = overlay.play_enter_animation()
	assert_not_null(tween, "Overlay enter animation should return content tween when motion set exists")
	assert_almost_eq(background.modulate.a, 0.0, 0.01,
		"Background dim should start transparent before fade-in")

	await wait_seconds(0.08)
	assert_true(background.modulate.a > 0.05,
		"Background dim alpha should increase during enter animation")

func test_auto_provision_background_image_from_preset() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()
	var color_rect := ColorRect.new()
	color_rect.name = "Background"
	screen.add_child(color_rect)
	screen.background_shader_preset = "retro_grid"
	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_not_null(screen.get("_background_image"), "Should auto-create BackgroundImage for retro_grid preset")
	var bg_image := screen.get("_background_image") as TextureRect
	assert_ne(bg_image.texture, null, "Auto-provisioned BackgroundImage should have texture loaded")
	assert_eq(bg_image.name, "BackgroundImage", "Auto-provisioned should be named BackgroundImage")

func test_auto_provision_skipped_when_no_preset_mapping() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()
	var color_rect := ColorRect.new()
	color_rect.name = "Background"
	screen.add_child(color_rect)
	screen.background_shader_preset = "none"
	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_null(screen.get("_background_image"), "Should not auto-provision when preset is none")

func test_no_background_image_no_color_rect_preset_none() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()
	screen.background_shader_preset = "none"
	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_null(screen.get("_background_image"), "Should not auto-provision when no nodes and preset is none")
	assert_null(screen.get("_background_shader_material"), "Should not set up shader when preset is none")
	assert_null(screen.get("_background_rect"), "Should not set _background_rect when no ColorRect exists")

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store

func _make_enter_motion_set(duration_sec: float) -> Resource:
	var motion_set := RS_UI_MOTION_SET.new()
	var enter_preset := RS_UI_MOTION_PRESET.new()
	enter_preset.property_path = "modulate:a"
	enter_preset.from_value = 0.0
	enter_preset.to_value = 1.0
	enter_preset.duration_sec = duration_sec
	motion_set.enter = [enter_preset]
	return motion_set

func _make_interactive_motion_set() -> Resource:
	var motion_set := RS_UI_MOTION_SET.new()

	var hover_in := RS_UI_MOTION_PRESET.new()
	hover_in.property_path = "modulate:a"
	hover_in.from_value = 0.8
	hover_in.to_value = 1.0
	hover_in.duration_sec = 0.08

	var hover_out := RS_UI_MOTION_PRESET.new()
	hover_out.property_path = "modulate:a"
	hover_out.from_value = 1.0
	hover_out.to_value = 0.8
	hover_out.duration_sec = 0.08

	var focus_in := RS_UI_MOTION_PRESET.new()
	focus_in.property_path = "scale:x"
	focus_in.from_value = 1.0
	focus_in.to_value = 1.05
	focus_in.duration_sec = 0.08

	var focus_out := RS_UI_MOTION_PRESET.new()
	focus_out.property_path = "scale:x"
	focus_out.from_value = 1.05
	focus_out.to_value = 1.0
	focus_out.duration_sec = 0.08

	motion_set.hover_in = [hover_in]
	motion_set.hover_out = [hover_out]
	motion_set.focus_in = [focus_in]
	motion_set.focus_out = [focus_out]
	return motion_set
