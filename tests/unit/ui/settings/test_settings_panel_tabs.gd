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

func test_tab_key_focus_path_targets_next_visible_tab_button():
	var panel := await _create_panel()
	panel._update_tab_visibility({"input": {"gamepad_connected": false, "active_device_type": M_INPUT_DEVICE_MANAGER.DeviceType.KEYBOARD_MOUSE}})
	panel.switch_to_tab(UI_SettingsPanel.TAB_DISPLAY)
	await get_tree().process_frame

	var first_focusable := panel._find_first_focusable_in_tab(UI_SettingsPanel.TAB_DISPLAY)
	var audio_button := _get_tab_button(panel, UI_SettingsPanel.TAB_AUDIO)

	assert_not_null(first_focusable, "Display tab should have a focusable control")
	assert_eq(first_focusable.focus_next, first_focusable.get_path_to(audio_button), "Native Tab focus should move to the next settings tab button")
	panel.queue_free()

func test_shift_tab_focus_path_targets_previous_visible_tab_button():
	var panel := await _create_panel()
	panel._update_tab_visibility({"input": {"gamepad_connected": false, "active_device_type": M_INPUT_DEVICE_MANAGER.DeviceType.KEYBOARD_MOUSE}})
	panel.switch_to_tab(UI_SettingsPanel.TAB_DISPLAY)
	await get_tree().process_frame

	var first_focusable := panel._find_first_focusable_in_tab(UI_SettingsPanel.TAB_DISPLAY)
	var keyboard_button := _get_tab_button(panel, UI_SettingsPanel.TAB_KEYBOARD_MOUSE)

	assert_not_null(first_focusable, "Display tab should have a focusable control")
	assert_eq(first_focusable.focus_previous, first_focusable.get_path_to(keyboard_button), "Native Shift+Tab focus should move to the previous settings tab button")
	panel.queue_free()

func test_shoulder_hints_show_lb_rb_text_labels():
	var panel := await _create_panel()
	var lb_hint := panel.find_child("ShoulderHintLB", true, false) as PanelContainer
	var rb_hint := panel.find_child("ShoulderHintRB", true, false) as PanelContainer

	assert_not_null(lb_hint, "Settings panel should show LB shoulder hint")
	assert_not_null(rb_hint, "Settings panel should show RB shoulder hint")
	var lb_label := lb_hint.get_node_or_null("Label") as Label
	var rb_label := rb_hint.get_node_or_null("Label") as Label
	assert_not_null(lb_label, "LB hint should contain a label")
	assert_not_null(rb_label, "RB hint should contain a label")
	assert_eq(lb_label.text, "LB", "LB hint should display 'LB'")
	assert_eq(rb_label.text, "RB", "RB hint should display 'RB'")
	panel.queue_free()

func test_shoulder_hints_flank_tab_buttons_in_tab_bar():
	var panel := await _create_panel()
	var tab_bar := panel.find_child("TabBar", true, false) as HBoxContainer
	var hint_row := panel.find_child("ShoulderHintRow", true, false) as HBoxContainer
	var lb_hint := panel.find_child("ShoulderHintLB", true, false) as PanelContainer
	var rb_hint := panel.find_child("ShoulderHintRB", true, false) as PanelContainer

	assert_not_null(hint_row, "Settings panel should group shoulder hints in a header row")
	assert_eq(hint_row.get_parent().name, "PanelChrome", "Shoulder hint row should live in panel chrome")
	assert_eq(lb_hint.get_parent(), hint_row, "LB hint should live inside the shoulder hint row")
	assert_eq(rb_hint.get_parent(), hint_row, "RB hint should live inside the shoulder hint row")
	assert_ne(lb_hint.get_parent(), tab_bar, "LB hint should not be mixed into tab buttons")
	assert_ne(rb_hint.get_parent(), tab_bar, "RB hint should not be mixed into tab buttons")
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
	var shell := _get_panel_shell(panel)
	var vbox := shell.get_node("VBox") as VBoxContainer
	var stylebox := shell.get_theme_stylebox("panel") as StyleBoxFlat

	assert_not_null(stylebox, "Settings panel should apply a panel shell stylebox")
	assert_eq(stylebox.content_margin_left, 18.0, "Panel shell should own left padding")
	assert_eq(stylebox.content_margin_right, 18.0, "Panel shell should own right padding")
	assert_false(vbox.has_theme_constant_override("margin_left"), "Inner VBox should not own outer panel margin")
	assert_false(vbox.has_theme_constant_override("margin_top"), "Inner VBox should not own outer panel margin")
	panel.queue_free()
	U_UIThemeBuilder.active_config = null

func test_content_scroll_is_inset_from_panel_edge():
	var config := RS_UIThemeConfig.new()
	config.margin_inner = 14
	config.ensure_runtime_defaults()
	U_UIThemeBuilder.active_config = config

	var panel := await _create_panel()
	panel._apply_layout_tokens()
	var scroll_margin := panel.find_child("ContentScrollMargin", true, false) as MarginContainer
	var content_margin := panel.find_child("ContentScrollContentMargin", true, false) as MarginContainer
	var content_scroll := panel.find_child("ContentScroll", true, false) as ScrollContainer
	var content_container := panel.find_child("ContentContainer", true, false) as VBoxContainer

	assert_not_null(scroll_margin, "Settings content scroll should have a margin wrapper")
	assert_not_null(content_margin, "Settings content should have internal spacing from the scrollbar")
	assert_not_null(content_scroll, "Settings content should still use a ScrollContainer")
	assert_eq(content_scroll.get_parent(), scroll_margin, "ContentScroll should sit inside the inset wrapper")
	assert_eq(content_margin.get_parent(), content_scroll, "Content margin should be the direct scroll child")
	assert_eq(content_container.get_parent(), content_margin, "Settings content should sit inside the scroll content margin")
	assert_eq(scroll_margin.get_theme_constant("margin_right"), 14, "Scroll bar should be inset from the panel edge")
	assert_eq(content_margin.get_theme_constant("margin_right"), 28, "Content should leave extra space before the scrollbar")
	assert_eq(scroll_margin.get_theme_constant("margin_bottom"), 14, "Scroll content should leave breathing room above the button edge")
	panel.queue_free()
	U_UIThemeBuilder.active_config = null

func test_settings_panel_vertical_minimum_keeps_viewport_padding_available():
	var panel := await _create_panel()
	var shell := _get_panel_shell(panel)

	assert_lte(
		shell.get_combined_minimum_size().y,
		BaseOverlay.OVERLAY_PANEL_SIZE.y,
		"Settings panel content should not force the modal taller than the shared overlay size"
	)
	panel.queue_free()

func test_settings_panel_uses_fixed_viewport_host_for_panel_size():
	var panel := await _create_panel()
	var shell := _get_panel_shell(panel)
	var viewport_host := panel.find_child("PanelViewport", true, false) as Control

	assert_not_null(viewport_host, "Settings panel should wrap the shell in a fixed-size viewport host")
	assert_eq(shell.get_parent(), viewport_host, "Settings panel shell should fill the viewport host")
	assert_lte(viewport_host.custom_minimum_size.x, BaseOverlay.OVERLAY_PANEL_SIZE.x, "Panel viewport host should not exceed the shared overlay width")
	assert_lte(viewport_host.custom_minimum_size.y, BaseOverlay.OVERLAY_PANEL_SIZE.y, "Panel viewport host should not exceed the shared overlay height")
	assert_eq(shell.anchor_left, 0.0, "Panel shell should fill the viewport host from the left")
	assert_eq(shell.anchor_top, 0.0, "Panel shell should fill the viewport host from the top")
	assert_eq(shell.anchor_right, 1.0, "Panel shell should fill the viewport host to the right")
	assert_eq(shell.anchor_bottom, 1.0, "Panel shell should fill the viewport host to the bottom")
	assert_eq(shell.custom_minimum_size, Vector2.ZERO, "Panel shell minimum should not override the viewport host cap")
	panel.queue_free()

func test_settings_panel_caps_host_height_to_project_viewport_margins():
	var config := RS_UIThemeConfig.new()
	config.margin_outer = 20
	config.ensure_runtime_defaults()
	U_UIThemeBuilder.active_config = config

	var panel := await _create_panel()
	var resolved_size: Vector2 = panel._resolve_panel_viewport_size(Vector2(960.0, 600.0), config)

	assert_eq(resolved_size, Vector2(860.0, 560.0), "Settings panel should leave top and bottom viewport padding at the project viewport size")
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
	await get_tree().process_frame
	var center := panel.get_node("CenterContainer") as CenterContainer
	var close_button := panel.find_child("CloseButton", true, false) as Button
	var close_button_margin := panel.find_child("CloseButtonMargin", true, false) as MarginContainer

	assert_eq(center.offset_left, 32.0, "Settings modal should have left viewport margin")
	assert_eq(center.offset_top, 32.0, "Settings modal should have top viewport margin")
	assert_eq(center.offset_right, -32.0, "Settings modal should have right viewport margin")
	assert_eq(center.offset_bottom, -32.0, "Settings modal should have bottom viewport margin")
	assert_not_null(close_button_margin, "Close button should have a container-aware margin wrapper")
	if close_button_margin == null:
		panel.queue_free()
		U_UIThemeBuilder.active_config = null
		return
	assert_true(close_button_margin.get_parent().name == "PanelChrome", "Close button wrapper should live inside panel chrome")
	assert_eq(close_button.get_parent(), close_button_margin, "Close button should live inside its margin wrapper")
	assert_eq(close_button_margin.get_theme_constant("margin_left"), 12, "Close wrapper should use inner left padding")
	assert_eq(close_button_margin.get_theme_constant("margin_top"), 12, "Close wrapper should use inner top padding")
	assert_eq(close_button_margin.get_theme_constant("margin_right"), 12, "Close wrapper should use inner right padding")
	assert_eq(close_button_margin.get_theme_constant("margin_bottom"), 12, "Close wrapper should use inner bottom padding")
	assert_eq(close_button_margin.size_flags_horizontal, Control.SIZE_SHRINK_END, "Close wrapper should stay compact at the right side")
	panel.queue_free()
	U_UIThemeBuilder.active_config = null

func test_tab_bar_is_inside_panel_chrome():
	var panel := await _create_panel()
	var header := panel.find_child("PanelChrome", true, false) as Control
	var tab_bar := panel.find_child("TabBar", true, false) as HBoxContainer

	assert_not_null(header, "Settings panel should create a header chrome row")
	assert_eq(tab_bar.get_parent(), header, "Tab bar should be inside header chrome")
	panel.queue_free()

func test_tab_header_spacer_separates_tabs_from_close_button():
	var panel := await _create_panel()
	var chrome := panel.find_child("PanelChrome", true, false) as HBoxContainer
	var spacer := panel.find_child("TabHeaderSpacer", true, false) as Control
	var tab_bar := panel.find_child("TabBar", true, false) as HBoxContainer
	var hint_row := panel.find_child("ShoulderHintRow", true, false) as HBoxContainer
	var close_margin := panel.find_child("CloseButtonMargin", true, false) as MarginContainer

	assert_not_null(spacer, "TabHeaderSpacer should exist in the scene tree")
	assert_eq(spacer.get_parent(), chrome, "TabHeaderSpacer should be a direct child of PanelChrome")
	assert_eq(spacer.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "TabHeaderSpacer should fill remaining space to push close button right")
	assert_true(tab_bar.get_index() < spacer.get_index(), "Spacer should come after the tab bar")
	assert_true(spacer.get_index() < hint_row.get_index(), "Spacer should come before the shoulder hint row")
	assert_true(hint_row.get_index() < close_margin.get_index(), "Shoulder hint row should come before the close button")
	panel.queue_free()

func test_panel_surface_alpha_is_boosted_to_readable_floor():
	var config := RS_UIThemeConfig.new()
	config.panel_section_opacity = 0.78
	config.ensure_runtime_defaults()
	U_UIThemeBuilder.active_config = config

	var panel := await _create_panel()
	panel._apply_layout_tokens()
	var shell := _get_panel_shell(panel)
	var stylebox := shell.get_theme_stylebox("panel") as StyleBoxFlat

	assert_true(stylebox.bg_color.a >= 0.92, "Settings panel surface should be opaque enough for readable forms")
	panel.queue_free()
	U_UIThemeBuilder.active_config = null

func _create_panel() -> UI_SettingsPanel:
	var scene := load(SCENE_PATH) as PackedScene
	var panel := scene.instantiate() as UI_SettingsPanel
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel

func _get_tab_button(panel: UI_SettingsPanel, tab_id: int) -> Button:
	return panel.find_child("TabButton_%d" % tab_id, true, false) as Button

func _get_panel_shell(panel: UI_SettingsPanel) -> PanelContainer:
	return panel.find_child("Panel", true, false) as PanelContainer

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
