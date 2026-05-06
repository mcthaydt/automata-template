extends "res://tests/base_test.gd"

const UI_SettingsPanel := preload("res://scripts/core/ui/settings/ui_settings_panel.gd")
const SCENE_PATH := "res://scenes/core/ui/settings/ui_settings_panel.tscn"
const M_INPUT_DEVICE_MANAGER := preload("res://scripts/core/managers/m_input_device_manager.gd")

var _store: M_StateStore = null

func before_each() -> void:
	super.before_each()
	_store = _create_state_store()

func after_each() -> void:
	_store = null
	super.after_each()

func test_settings_panel_has_tab_bar():
	var panel := await _create_panel()
	var tab_bar := panel.find_child("TabBar", true, false) as HBoxContainer
	assert_not_null(tab_bar, "Settings panel should have a TabBar HBoxContainer")
	panel.queue_free()

func test_settings_panel_has_content_container():
	var panel := await _create_panel()
	var content := panel.find_child("ContentContainer", true, false) as VBoxContainer
	assert_not_null(content, "Settings panel should have a ContentContainer VBoxContainer")
	panel.queue_free()

func test_settings_panel_default_tab_is_display():
	var panel := await _create_panel()
	assert_eq(panel.get_active_tab_id(), UI_SettingsPanel.TAB_DISPLAY, "Default active tab should be Display")
	var display_content := panel._tab_contents.get(UI_SettingsPanel.TAB_DISPLAY) as Control
	assert_not_null(display_content, "Display tab content should exist")
	assert_true(display_content.visible, "Display tab content should be visible by default")
	panel.queue_free()

func test_switch_tab_updates_active_id():
	var panel := await _create_panel()
	panel.switch_to_tab(UI_SettingsPanel.TAB_AUDIO)
	assert_eq(panel.get_active_tab_id(), UI_SettingsPanel.TAB_AUDIO, "Active tab should be Audio after switch")
	panel.queue_free()

func test_switch_tab_shows_content_hides_others():
	var panel := await _create_panel()
	panel.switch_to_tab(UI_SettingsPanel.TAB_AUDIO)
	await get_tree().process_frame
	var audio_content := panel._tab_contents.get(UI_SettingsPanel.TAB_AUDIO) as Control
	var display_content := panel._tab_contents.get(UI_SettingsPanel.TAB_DISPLAY) as Control
	assert_not_null(audio_content, "Audio tab content should exist")
	assert_not_null(display_content, "Display tab content should exist")
	assert_true(audio_content.visible, "Audio content should be visible when active")
	assert_false(display_content.visible, "Display content should be hidden when inactive")
	panel.queue_free()

func test_focus_next_switches_to_next_visible_tab():
	var panel := await _create_panel()
	panel._update_tab_visibility({"input": {"gamepad_connected": false, "active_device_type": M_INPUT_DEVICE_MANAGER.DeviceType.KEYBOARD_MOUSE}})
	panel.switch_to_tab(UI_SettingsPanel.TAB_LANGUAGE)

	var event := InputEventAction.new()
	event.action = "ui_focus_next"
	event.pressed = true
	panel._unhandled_input(event)
	await get_tree().process_frame

	assert_eq(panel.get_active_tab_id(), UI_SettingsPanel.TAB_KEYBOARD_MOUSE, "RB should skip hidden Gamepad tab and focus Keyboard/Mouse")
	panel.queue_free()

func test_focus_prev_switches_to_previous_visible_tab():
	var panel := await _create_panel()
	panel._update_tab_visibility({"input": {"gamepad_connected": false, "active_device_type": M_INPUT_DEVICE_MANAGER.DeviceType.KEYBOARD_MOUSE}})
	panel.switch_to_tab(UI_SettingsPanel.TAB_DISPLAY)

	var event := InputEventAction.new()
	event.action = "ui_focus_prev"
	event.pressed = true
	panel._unhandled_input(event)
	await get_tree().process_frame

	assert_eq(panel.get_active_tab_id(), UI_SettingsPanel.TAB_KEYBOARD_MOUSE, "LB should wrap to last visible tab and skip hidden tabs")
	panel.queue_free()

func test_shoulder_prompt_icons_use_existing_lb_rb_assets():
	var panel := await _create_panel()
	var lb_icon := panel.find_child("ShoulderPromptLBIcon", true, false) as TextureRect
	var rb_icon := panel.find_child("ShoulderPromptRBIcon", true, false) as TextureRect
	var label := panel.find_child("ShoulderPromptLabel", true, false) as Label

	assert_not_null(lb_icon, "Settings panel should show LB prompt icon")
	assert_not_null(rb_icon, "Settings panel should show RB prompt icon")
	assert_not_null(label, "Settings panel should label shoulder prompts")
	assert_eq(lb_icon.texture.resource_path, "res://assets/core/button_prompts/gamepad/button_lb.png", "LB icon should use existing prompt art")
	assert_eq(rb_icon.texture.resource_path, "res://assets/core/button_prompts/gamepad/button_rb.png", "RB icon should use existing prompt art")
	panel.queue_free()

func test_close_in_gameplay_overlay_closes_top_overlay():
	var panel := await _create_panel()
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	_store.dispatch(U_NavigationActions.open_pause())
	_store.dispatch(U_NavigationActions.open_overlay(StringName("settings_panel")))
	await get_tree().process_frame

	panel._on_close_pressed()
	await get_tree().process_frame

	var nav_slice := _store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("overlay_stack"), [StringName("pause_menu")], "Close button should close settings overlay back to pause")
	panel.queue_free()

func test_cancel_in_main_menu_standalone_returns_to_main_menu():
	var panel := await _create_panel()
	_store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_panel")))
	await get_tree().process_frame

	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	panel._unhandled_input(event)
	await get_tree().process_frame

	var nav_slice := _store.get_slice(StringName("navigation"))
	assert_eq(nav_slice.get("base_scene_id"), StringName("main_menu"), "Cancel should navigate standalone settings back to main_menu")
	panel.queue_free()

func test_background_is_context_aware_for_overlay_and_standalone():
	var panel := await _create_panel()
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	_store.dispatch(U_NavigationActions.open_overlay(StringName("settings_panel")))
	panel._apply_context_background()
	var overlay_bg := panel.find_child("OverlayBackground", true, false) as ColorRect
	var menu_bg := panel.find_child("MenuBackground", true, false) as Control
	assert_true(overlay_bg.visible, "Gameplay overlay settings should keep dim background visible")
	assert_false(menu_bg.visible, "Gameplay overlay settings should hide menu background")

	_store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_panel")))
	panel._apply_context_background()
	assert_false(overlay_bg.visible, "Standalone main-menu settings should hide dim overlay")
	assert_true(menu_bg.visible, "Standalone main-menu settings should show menu background")
	panel.queue_free()

func test_panel_spacing_tokens_apply_to_outer_panel_not_inner_vbox():
	var config := RS_UIThemeConfig.new()
	config.margin_section = 18
	config.margin_outer = 28
	config.ensure_runtime_defaults()
	U_UIThemeBuilder.active_config = config

	var panel := await _create_panel()
	panel._apply_layout_tokens()
	var shell := panel.get_node("CenterContainer/Panel") as PanelContainer
	var vbox := panel.get_node("CenterContainer/Panel/VBox") as VBoxContainer
	var stylebox := shell.get_theme_stylebox("panel") as StyleBoxFlat

	assert_not_null(stylebox, "Settings panel should apply a panel shell stylebox")
	assert_eq(stylebox.content_margin_left, 18.0, "Panel shell should own left padding")
	assert_eq(stylebox.content_margin_right, 18.0, "Panel shell should own right padding")
	assert_false(vbox.has_theme_constant_override("margin_left"), "Inner VBox should not own outer panel margin")
	assert_false(vbox.has_theme_constant_override("margin_top"), "Inner VBox should not own outer panel margin")
	panel.queue_free()
	U_UIThemeBuilder.active_config = null

func test_panel_shell_has_viewport_margin_and_close_inside_panel_chrome():
	var config := RS_UIThemeConfig.new()
	config.margin_outer = 32
	config.margin_section = 24
	config.margin_inner = 12
	config.ensure_runtime_defaults()
	U_UIThemeBuilder.active_config = config

	var panel := await _create_panel()
	panel._apply_layout_tokens()
	var center := panel.get_node("CenterContainer") as CenterContainer
	var close_button := panel.find_child("CloseButton", true, false) as Button

	assert_eq(center.offset_left, 32.0, "Settings modal should have left viewport margin")
	assert_eq(center.offset_top, 32.0, "Settings modal should have top viewport margin")
	assert_eq(center.offset_right, -32.0, "Settings modal should have right viewport margin")
	assert_eq(center.offset_bottom, -32.0, "Settings modal should have bottom viewport margin")
	assert_true(close_button.get_parent().name == "PanelChrome", "Close button should live inside panel chrome")
	assert_eq(close_button.offset_right, -12.0, "Close button should use inner panel padding")
	panel.queue_free()
	U_UIThemeBuilder.active_config = null

func test_shoulder_prompts_are_inline_with_tab_bar():
	var panel := await _create_panel()
	var header := panel.find_child("PanelChrome", true, false) as Control
	var tab_bar := panel.find_child("TabBar", true, false) as HBoxContainer
	var prompt_row := panel.find_child("ShoulderPromptRow", true, false) as HBoxContainer

	assert_not_null(header, "Settings panel should create a header chrome row")
	assert_eq(tab_bar.get_parent(), header, "Tab bar should be inside header chrome")
	assert_eq(prompt_row.get_parent(), header, "Shoulder prompts should be inline in header chrome")
	assert_true(prompt_row.size_flags_horizontal == Control.SIZE_SHRINK_END, "Prompt row should stay compact at the right side")
	panel.queue_free()

func _create_panel() -> UI_SettingsPanel:
	var scene := load(SCENE_PATH) as PackedScene
	var panel := scene.instantiate() as UI_SettingsPanel
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	test_settings.enable_global_settings_persistence = false
	test_settings.enable_debug_logging = false
	test_settings.enable_debug_overlay = false
	store.settings = test_settings
	store.audio_initial_state = RS_AudioInitialState.new()
	store.display_initial_state = RS_DisplayInitialState.new()
	store.localization_initial_state = RS_LocalizationInitialState.new()
	store.vfx_initial_state = RS_VFXInitialState.new()
	add_child_autofree(store)
	U_ServiceLocator.register(StringName("state_store"), store)
	return store
