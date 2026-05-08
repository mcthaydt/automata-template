extends GutTest

const PauseMenuScene := preload("res://scenes/core/ui/menus/ui_pause_menu.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null

func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null

func test_pause_menu_has_enter_exit_motion_assigned() -> void:
	await _create_state_store()
	var pause_menu: Variant = await _instantiate_pause_menu()
	var motion_set: Variant = pause_menu.get("motion_set")

	assert_not_null(motion_set, "Pause menu should assign a motion set for enter/exit animation")
	if motion_set == null:
		return
	assert_true("enter" in motion_set, "Motion set should expose enter presets")
	assert_true("exit" in motion_set, "Motion set should expose exit presets")
	var enter_presets: Array = motion_set.enter
	var exit_presets: Array = motion_set.exit
	assert_gt(enter_presets.size(), 0, "Motion set enter presets should not be empty")
	assert_gt(exit_presets.size(), 0, "Motion set exit presets should not be empty")

func test_applies_theme_tokens_when_active_config_present() -> void:
	await _create_state_store()
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 44
	config.bg_base = Color(0.2, 0.3, 0.4, 1.0)
	config.separation_default = 18
	config.margin_section = 22
	U_UI_THEME_BUILDER.active_config = config

	var pause_menu := await _instantiate_pause_menu()
	var title_label: Label = pause_menu.get_node("%TitleLabel")
	var content_vbox: VBoxContainer = pause_menu.get_node("%MainPanelContent")
	var panel_padding: MarginContainer = pause_menu.get_node("%MainPanelPadding")
	var overlay_background := pause_menu.get_node_or_null("OverlayBackground") as ColorRect
	var expected_dim := config.bg_base
	expected_dim.a = 0.7

	assert_eq(
		title_label.get_theme_font_size(&"font_size"),
		44,
		"Paused title should use the heading token from the active theme config"
	)
	assert_eq(
		content_vbox.get_theme_constant(&"separation"),
		18,
		"Pause content separation should use separation_default from theme config"
	)
	assert_eq(
		panel_padding.get_theme_constant(&"margin_left"),
		22,
		"Pause panel padding should use margin_section from theme config"
	)
	assert_not_null(overlay_background, "Pause menu should create an overlay background panel")
	if overlay_background != null:
		assert_true(
			overlay_background.color.is_equal_approx(expected_dim),
			"Pause menu dim should use bg_base with 0.7 alpha from theme config"
		)

func test_enter_animation_keeps_overlay_root_position_static() -> void:
	await _create_state_store()
	var pause_menu := await _instantiate_pause_menu()
	await wait_process_frames(1)

	assert_almost_eq(
		pause_menu.position.y,
		0.0,
		0.01,
		"Pause menu root should not slide during enter animation"
	)

func test_pause_menu_panel_stays_vertically_centered_after_enter_animation() -> void:
	await _create_state_store()
	var pause_menu := await _instantiate_pause_menu()
	await wait_process_frames(24)

	var center_container: CenterContainer = pause_menu.get_node("CenterContainer")
	var panel_host: Control = pause_menu.get_node("%MainPanelMotionHost")
	var container_center_y: float = center_container.global_position.y + (center_container.size.y * 0.5)
	var panel_center_y: float = panel_host.global_position.y + (panel_host.size.y * 0.5)

	assert_almost_eq(
		panel_center_y,
		container_center_y,
		1.0,
		"Pause menu panel should remain vertically centered after enter animation completes"
	)

func test_resume_button_closes_pause_overlay() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	var resume_button: Button = pause_menu.get_node("%ResumeButton")
	resume_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav_slice := store.get_slice(StringName("navigation"))
	assert_true(nav_slice.get("overlay_stack", []).is_empty(),
		"Resume button should clear overlay stack")

func test_settings_button_opens_settings_overlay() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	var settings_button: Button = pause_menu.get_node("%SettingsButton")
	settings_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav_slice := store.get_slice(StringName("navigation"))
	var stack: Array = nav_slice.get("overlay_stack", [])
	assert_eq(stack.back(), StringName("settings_panel"),
		"Settings button should push the settings panel overlay")

func test_quit_button_returns_to_main_menu() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	var quit_button: Button = pause_menu.get_node("%QuitButton")
	quit_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav_slice := store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("shell"), StringName("main_menu"),
		"Quit should return to main menu shell")
	assert_eq(nav_slice.get("base_scene_id"), StringName("main_menu"),
		"Quit should target main_menu scene")

func test_back_action_matches_resume() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	pause_menu._unhandled_input(event)
	await wait_process_frames(2)

	var nav_slice := store.get_slice(StringName("navigation"))
	assert_true(nav_slice.get("overlay_stack", []).is_empty(),
		"ui_cancel should close pause overlay via navigation action")

func test_pause_menu_hidden_when_transitioning_to_main_menu() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	# Pause menu should be visible during gameplay pause
	assert_true(pause_menu.visible, "Pause menu should be visible when paused in gameplay")

	# Simulate clicking "Quit to Main Menu" - this clears overlays AND changes shell
	store.dispatch(U_NavigationActions.return_to_main_menu())
	await wait_physics_frames(2)

	# Pause menu should be hidden because we're transitioning to main menu shell
	assert_false(pause_menu.visible, "Pause menu should be hidden when transitioning to main menu")

func test_switching_to_gamepad_focuses_resume_button() -> void:
	var store := await _create_state_store()
	_prepare_paused_state(store)
	var pause_menu := await _instantiate_pause_menu()

	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.GAMEPAD, 0, 0.0))
	await wait_process_frames(2)

	var viewport := pause_menu.get_viewport()
	var focused := viewport.gui_get_focus_owner()
	assert_not_null(focused, "Pause menu should have a focused control after switching to gamepad")
	var resume_button: Button = pause_menu.get_node("%ResumeButton")
	assert_eq(focused, resume_button, "Resume button should be focused after switching to gamepad")

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store

func _prepare_paused_state(store: M_StateStore) -> void:
	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	store.dispatch(U_NavigationActions.open_pause())

func _instantiate_pause_menu() -> Control:
	var pause_menu := PauseMenuScene.instantiate()
	add_child_autofree(pause_menu)
	await wait_process_frames(2)
	return pause_menu
