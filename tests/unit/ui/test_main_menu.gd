extends GutTest

const MainMenuScene := preload("res://scenes/core/ui/menus/ui_main_menu.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const CFG_GAME_CONFIG := preload("res://resources/core/cfg_game_config.tres")

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null

func after_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null

func test_main_menu_has_enter_exit_motion_assigned() -> void:
	await _create_state_store()
	var menu: Variant = await _create_main_menu()
	var motion_set: Variant = menu.get("motion_set")

	assert_not_null(motion_set, "Main menu should assign a motion set for enter/exit animation")
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
	config.title = 62
	config.bg_base = Color(0.1, 0.2, 0.3, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	var menu := await _create_main_menu()
	var title_label: Label = menu.get_node("%TitleLabel")
	var background_image: TextureRect = menu.get_node_or_null("BackgroundImage")

	assert_eq(
		title_label.get_theme_font_size(&"font_size"),
		62,
		"Title label should use the title size token from the active theme config"
	)
	assert_not_null(
		background_image,
		"Main menu should have a BackgroundImage TextureRect node"
	)
	if background_image != null:
		assert_not_null(
			background_image.texture,
			"BackgroundImage should have a texture assigned"
		)
		assert_eq(
			background_image.stretch_mode,
			TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"BackgroundImage should cover the full screen without letterboxing"
		)

func test_main_panel_visible_by_default() -> void:
	var store := await _create_state_store()
	var menu := await _create_main_menu()
	var main_panel: Control = menu.get_node("CenterContainer/MainPanel")

	assert_not_null(store, "State store should exist for main menu tests")
	assert_true(main_panel.visible, "Main panel should be visible on load")

func test_legacy_settings_panel_id_is_ignored() -> void:
	var store := await _create_state_store()
	var menu := await _create_main_menu()
	var main_panel: Control = menu.get_node("CenterContainer/MainPanel")

	store.dispatch(U_NavigationActions.set_menu_panel(StringName("menu/settings")))
	await wait_process_frames(2)

	assert_true(main_panel.visible, "Main panel should ignore removed embedded settings panel id")

func test_settings_button_navigates_to_settings_panel() -> void:
	var store := await _create_state_store()
	var menu := await _create_main_menu()
	var settings_button: Button = menu.get_node("%SettingsButton")

	settings_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav_slice: Dictionary = store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("shell"), StringName("main_menu"), "Settings stays in the menu shell")
	assert_eq(nav_slice.get("base_scene_id"), StringName("settings_panel"),
		"Settings button should navigate to the settings panel screen")

func test_back_action_keeps_main_panel_visible_without_internal_subpanel() -> void:
	var store := await _create_state_store()
	var menu := await _create_main_menu()
	var main_panel: Control = menu.get_node("CenterContainer/MainPanel")

	menu._on_back_pressed()
	await wait_process_frames(2)

	var nav_slice: Dictionary = store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("active_menu_panel"), StringName("menu/main"),
		"Back action should leave the main panel active")
	assert_true(main_panel.visible, "Main panel should remain visible")

func test_play_button_dispatches_start_game_action() -> void:
	var store := await _create_state_store()
	var menu := await _create_main_menu()
	var new_game_button: Button = menu.get_node("%NewGameButton")

	new_game_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav_slice: Dictionary = store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("shell"), StringName("gameplay"),
		"New Game button should move navigation shell to gameplay")
	assert_eq(nav_slice.get("base_scene_id"), _get_expected_default_gameplay_scene(),
		"New Game button should target the configured retry scene by default")

func test_new_game_prompts_confirmation_when_saves_exist() -> void:
	var store := await _create_state_store()
	await _register_save_manager_with_saves()
	var menu := await _create_main_menu()
	var new_game_button: Button = menu.get_node("%NewGameButton")

	new_game_button.emit_signal("pressed")
	await wait_process_frames(2)

	var nav_slice: Dictionary = store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("shell"), StringName("main_menu"),
		"New Game should not start immediately when saves exist")

	var dialog := menu.get_node_or_null("%NewGameConfirmDialog") as ConfirmationDialog
	assert_not_null(dialog, "NewGameConfirmDialog should exist in scene")
	if dialog == null:
		return
	assert_true(dialog.visible, "NewGameConfirmDialog should be visible when saves exist")

func test_new_game_confirmation_confirm_starts_game() -> void:
	var store := await _create_state_store()
	await _register_save_manager_with_saves()
	var menu := await _create_main_menu()
	var new_game_button: Button = menu.get_node("%NewGameButton")

	new_game_button.emit_signal("pressed")
	await wait_process_frames(2)

	var dialog := menu.get_node_or_null("%NewGameConfirmDialog") as ConfirmationDialog
	assert_not_null(dialog, "NewGameConfirmDialog should exist in scene")
	if dialog == null:
		return

	dialog.emit_signal("confirmed")
	await wait_process_frames(2)

	var nav_slice: Dictionary = store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("shell"), StringName("gameplay"),
		"Confirming New Game should start gameplay shell")
	assert_eq(nav_slice.get("base_scene_id"), _get_expected_default_gameplay_scene(),
		"Confirming New Game should target the configured retry scene by default")

func test_new_game_confirmation_cancel_does_nothing() -> void:
	var store := await _create_state_store()
	await _register_save_manager_with_saves()
	var menu := await _create_main_menu()
	var new_game_button: Button = menu.get_node("%NewGameButton")

	new_game_button.emit_signal("pressed")
	await wait_process_frames(2)

	var dialog := menu.get_node_or_null("%NewGameConfirmDialog") as ConfirmationDialog
	assert_not_null(dialog, "NewGameConfirmDialog should exist in scene")
	if dialog == null:
		return

	dialog.emit_signal("canceled")
	await wait_process_frames(2)

	var nav_slice: Dictionary = store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("shell"), StringName("main_menu"),
		"Canceling New Game confirmation should stay on main menu")

func test_load_game_overlay_hides_main_panel_options() -> void:
	var store := await _create_state_store()
	var menu := await _create_main_menu()
	var main_panel: Control = menu.get_node("CenterContainer/MainPanel")

	assert_true(main_panel.visible, "Main panel should start visible")

	store.dispatch(U_NavigationActions.set_save_load_mode(StringName("load")))
	store.dispatch(U_NavigationActions.open_overlay(StringName("save_load_menu_overlay")))
	await wait_process_frames(2)

	assert_false(main_panel.visible, "Main panel should hide while the save/load overlay is open")

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.scene_initial_state.current_scene_id = StringName("main_menu")
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store

func _create_main_menu() -> Control:
	var menu := MainMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	return menu

func _register_save_manager_with_saves() -> Node:
	var save_manager := MockSaveManager.new()
	add_child_autofree(save_manager)
	save_manager.set_has_any_saves(true)
	await wait_process_frames(2)
	return save_manager

func _get_expected_default_gameplay_scene() -> StringName:
	if CFG_GAME_CONFIG == null:
		return StringName("demo_room")
	return CFG_GAME_CONFIG.get_default_gameplay_scene_id()


## Test main menu ignores non-menu panels (like pause/root from gameplay)
## Reproduces bug: settings panel shows when transitioning to gameplay
func test_ignores_non_menu_panel_ids() -> void:
	var store := await _create_state_store()
	var menu := await _create_main_menu()
	var main_panel: Control = menu.get_node("CenterContainer/MainPanel")

	# Verify initial state: main panel visible
	assert_true(main_panel.visible, "Main panel should be visible initially")

	# Simulate what happens when user clicks Play - navigation state updates to pause/root
	store.dispatch(U_NavigationActions.set_menu_panel(StringName("pause/root")))
	await wait_process_frames(2)

	# Main menu should IGNORE "pause/root" because it's not a menu panel
	assert_true(main_panel.visible, "Main panel should remain visible when non-menu panel is set")

## Regression test: Quit button should be hidden on mobile platforms
func test_quit_button_hidden_on_mobile() -> void:
	# This test can't actually override OS.has_feature() since it's built-in
	# Instead, we verify the button visibility logic exists
	var store := await _create_state_store()
	var menu := await _create_main_menu()
	var quit_button: Button = menu.get_node("%QuitButton")

	assert_not_null(quit_button, "Quit button should exist in scene")

	# On desktop (current test environment), quit button should be visible
	# The actual mobile hiding logic is tested manually or with device-specific tests
	if not OS.has_feature("mobile"):
		assert_true(quit_button.visible, "Quit button should be visible on desktop")
	else:
		assert_false(quit_button.visible, "Quit button should be hidden on mobile")

## Regression test: Quit button should not appear in focus chain when hidden
func test_quit_button_excluded_from_focus_when_hidden() -> void:
	await _create_state_store()
	var menu := await _create_main_menu()
	var quit_button: Button = menu.get_node("%QuitButton")
	var settings_button: Button = menu.get_node("%SettingsButton")

	assert_not_null(quit_button, "Quit button should exist")
	assert_not_null(settings_button, "Settings button should exist")

	# If quit button is hidden, settings button's down neighbor should not be quit button
	if not quit_button.visible:
		var down_neighbor_path := settings_button.focus_neighbor_bottom
		var down_neighbor := settings_button.get_node_or_null(down_neighbor_path) if down_neighbor_path != NodePath() else null
		assert_ne(down_neighbor, quit_button, "Hidden quit button should not be in focus chain")
