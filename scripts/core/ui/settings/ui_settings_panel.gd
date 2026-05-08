@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_overlay.gd"
class_name UI_SettingsPanel

const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_INPUT_SELECTORS := preload("res://scripts/core/state/selectors/u_input_selectors.gd")
const M_INPUT_DEVICE_MANAGER := preload("res://scripts/core/managers/m_input_device_manager.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/core/state/actions/u_navigation_actions.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/core/state/selectors/u_navigation_selectors.gd")
const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")
const UI_DisplaySettingsTab := preload("res://scripts/core/ui/settings/ui_display_settings_tab.gd")
const UI_AudioSettingsTab := preload("res://scripts/core/ui/settings/ui_audio_settings_tab.gd")
const UI_VFXSettingsTab := preload("res://scripts/core/ui/settings/ui_vfx_settings_tab.gd")
const UI_LocalizationSettingsTab := preload("res://scripts/core/ui/settings/ui_localization_settings_tab.gd")
const UI_GamepadSettingsTab := preload("res://scripts/core/ui/settings/ui_gamepad_settings_tab.gd")
const UI_KeyboardMouseSettingsTab := preload("res://scripts/core/ui/settings/ui_keyboard_mouse_settings_tab.gd")
const UI_TouchscreenSettingsTab := preload("res://scripts/core/ui/settings/ui_touchscreen_settings_tab.gd")
const CFG_MOTION_BUTTON_DEFAULT := preload("res://resources/core/ui/motions/cfg_motion_button_default.tres")
const CFG_MOTION_FADE_SLIDE := preload("res://resources/core/ui/motions/cfg_motion_fade_slide.tres")
const U_UI_PALETTE_RESOLVER := preload("res://scripts/core/ui/utils/u_ui_palette_resolver.gd")
const U_SETTINGS_SELECTORS := preload("res://scripts/core/state/selectors/u_settings_selectors.gd")
const TEX_MENU_BACKGROUND := preload("res://assets/core/textures/tex_bg_menu_main.png")
const W_TAB_STRIP := preload("res://scripts/core/ui/widgets/w_tab_strip.gd")
const W_OVERLAY_CHROME := preload("res://scripts/core/ui/widgets/w_overlay_chrome.gd")

enum TabId {
	DISPLAY,
	AUDIO,
	VFX,
	LANGUAGE,
	GAMEPAD,
	KEYBOARD_MOUSE,
	TOUCHSCREEN,
}

const TAB_DISPLAY := TabId.DISPLAY
const TAB_AUDIO := TabId.AUDIO
const TAB_VFX := TabId.VFX
const TAB_LANGUAGE := TabId.LANGUAGE
const TAB_GAMEPAD := TabId.GAMEPAD
const TAB_KEYBOARD_MOUSE := TabId.KEYBOARD_MOUSE
const TAB_TOUCHSCREEN := TabId.TOUCHSCREEN

const _TAB_LABELS: Dictionary = {
	TabId.DISPLAY: {"key": StringName("settings_tab_display"), "fallback": "Display"},
	TabId.AUDIO: {"key": StringName("settings_tab_audio"), "fallback": "Audio"},
	TabId.VFX: {"key": StringName("settings_tab_vfx"), "fallback": "VFX"},
	TabId.LANGUAGE: {"key": StringName("settings_tab_language"), "fallback": "Language"},
	TabId.GAMEPAD: {"key": StringName("settings_tab_gamepad"), "fallback": "Gamepad"},
	TabId.KEYBOARD_MOUSE: {"key": StringName("settings_tab_keyboard_mouse"), "fallback": "Keyboard & Mouse"},
	TabId.TOUCHSCREEN: {"key": StringName("settings_tab_touchscreen"), "fallback": "Touchscreen"},
}

const _TAB_ORDER: Array[TabId] = [
	TabId.DISPLAY,
	TabId.AUDIO,
	TabId.VFX,
	TabId.LANGUAGE,
	TabId.GAMEPAD,
	TabId.KEYBOARD_MOUSE,
	TabId.TOUCHSCREEN,
]

const _SETTINGS_SCENE_ID := StringName("settings_panel")
const _MAIN_MENU_SCENE_ID := StringName("main_menu")

@export var emulate_mobile_override: bool = false

var _active_tab: int = -1
var _tab_contents: Dictionary = {}
var _last_device_type: int = -1
var _consume_next_nav: bool = false
var _chrome: W_OverlayChrome = null
var _current_palette: Resource = null
var _menu_background: TextureRect = null
var _tab_header_spacer: Control = null
var _content_scroll: ScrollContainer = null
var _shoulder_hint_lb: PanelContainer = null
var _shoulder_hint_rb: PanelContainer = null
var _shoulder_hint_row: HBoxContainer = null
var _tab_strip: W_TAB_STRIP = null

@onready var _tab_bar: HBoxContainer = $CenterContainer/Panel/VBox/TabBar
@onready var _separator: HSeparator = $CenterContainer/Panel/VBox/HSeparator
@onready var _content_container: VBoxContainer = $CenterContainer/Panel/VBox/ContentContainer

func _ready() -> void:
	super._ready()
	_apply_base_theme()
	_create_menu_background()
	_create_chrome_widget()
	_create_tab_strip()
	_create_shoulder_prompts()
	_wrap_content_in_scroll()
	_create_tab_contents()
	_apply_layout_tokens()
	_update_tab_visibility()
	_apply_context_background()
	switch_to_tab(TabId.DISPLAY)
	_bind_tab_bar_motion()

func get_active_tab_id() -> TabId:
	return _active_tab as TabId

func switch_to_tab(tab_id: TabId) -> void:
	var current_content := _tab_contents.get(tab_id) as Control
	if _active_tab == tab_id and current_content != null and current_content.visible:
		return
	if _active_tab >= 0:
		_hide_tab_content(_active_tab as TabId)
	_active_tab = tab_id
	_show_tab_content(tab_id)
	if _tab_strip != null:
		_tab_strip.switch_to_tab(tab_id)
	_configure_focus_neighbors()
	call_deferred("_focus_active_tab_first_control")

func _focus_active_tab_first_control() -> void:
	if not is_inside_tree():
		return
	var first_focusable: Control = _find_first_focusable_in_tab(_active_tab as TabId)
	if first_focusable != null:
		first_focusable.grab_focus()

func _apply_base_theme() -> void:
	var config: Resource = U_UI_THEME_BUILDER.active_config
	if not (config is RS_UI_THEME_CONFIG):
		return
	var typed_config := config as RS_UI_THEME_CONFIG
	typed_config.ensure_runtime_defaults()
	self.theme = U_UI_THEME_BUILDER.build_theme(typed_config)
	motion_set = CFG_MOTION_FADE_SLIDE

func _create_chrome_widget() -> void:
	_chrome = W_OVERLAY_CHROME.new()
	_chrome.name = "OverlayChrome"
	var vbox := get_node_or_null("CenterContainer/Panel/VBox") as VBoxContainer
	if vbox != null:
		vbox.add_child(_chrome)
		vbox.move_child(_chrome, 0)
	_chrome.close_pressed.connect(_on_chrome_close_pressed)

	_tab_header_spacer = Control.new()
	_tab_header_spacer.name = "TabHeaderSpacer"
	_tab_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _on_chrome_close_pressed() -> void:
	_on_close_pressed()

func _create_tab_strip() -> void:
	if _tab_bar == null:
		return
	if _chrome != null:
		var chrome_row := _chrome.get_chrome_row()
		if chrome_row != null and _tab_bar.get_parent() != chrome_row:
			_tab_bar.reparent(chrome_row)
			chrome_row.move_child(_tab_bar, 0)
			if _tab_header_spacer != null and _tab_header_spacer.get_parent() == null:
				chrome_row.add_child(_tab_header_spacer)
			var close_margin := _chrome.get_close_button_margin()
			if close_margin != null and close_margin.get_parent() == chrome_row:
				chrome_row.move_child(close_margin, chrome_row.get_child_count() - 1)
	_tab_strip = W_TAB_STRIP.new()
	_tab_bar.add_child(_tab_strip)
	for tab_id: TabId in _TAB_ORDER:
		var label_info: Dictionary = _TAB_LABELS[tab_id]
		var button := Button.new()
		var localized_text: String = U_LOCALIZATION_UTILS.localize_with_fallback(label_info.key, label_info.fallback)
		button.text = localized_text
		button.name = "TabButton_%d" % tab_id
		button.focus_mode = Control.FOCUS_ALL
		_tab_strip.add_tab(tab_id, button, label_info.key, label_info.fallback, "TabActive", "TabInactive")
	_tab_strip.tab_switched.connect(_on_tab_switched)

func _on_tab_switched(tab_id: int) -> void:
	U_UISoundPlayer.play_confirm()
	switch_to_tab(tab_id as TabId)

func _create_menu_background() -> void:
	_menu_background = TextureRect.new()
	_menu_background.name = "MenuBackground"
	_menu_background.texture = TEX_MENU_BACKGROUND
	_menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_background.visible = false
	add_child(_menu_background)
	move_child(_menu_background, 0)
	_menu_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_background.offset_left = 0.0
	_menu_background.offset_top = 0.0
	_menu_background.offset_right = 0.0
	_menu_background.offset_bottom = 0.0

func _create_shoulder_prompts() -> void:
	if _chrome == null:
		return
	var chrome_row := _chrome.get_chrome_row()
	if chrome_row == null:
		return
	_shoulder_hint_row = HBoxContainer.new()
	_shoulder_hint_row.name = "ShoulderHintRow"
	_shoulder_hint_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_shoulder_hint_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shoulder_hint_lb = _create_shoulder_hint("ShoulderHintLB", "LB")
	_shoulder_hint_rb = _create_shoulder_hint("ShoulderHintRB", "RB")
	_shoulder_hint_row.add_child(_shoulder_hint_lb)
	var label := Label.new()
	label.name = "ShoulderHintLabel"
	label.text = "Tabs"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shoulder_hint_row.add_child(label)
	_shoulder_hint_row.add_child(_shoulder_hint_rb)
	var close_margin := _chrome.get_close_button_margin()
	var close_index := close_margin.get_index() if close_margin != null else chrome_row.get_child_count()
	chrome_row.add_child(_shoulder_hint_row)
	chrome_row.move_child(_shoulder_hint_row, close_index)

func _create_shoulder_hint(node_name: String, label_text: String) -> PanelContainer:
	var hint := PanelContainer.new()
	hint.name = node_name
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.custom_minimum_size = Vector2(48, 30)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(label)
	return hint

func _wrap_content_in_scroll() -> void:
	if _content_container == null:
		return
	var vbox := _content_container.get_parent() as VBoxContainer
	if vbox == null:
		return
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "ContentScroll"
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var insertion_index := _content_container.get_index()
	vbox.add_child(_content_scroll)
	vbox.move_child(_content_scroll, insertion_index)
	_content_container.reparent(_content_scroll)
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _create_tab_contents() -> void:
	var tab_classes := {
		TabId.DISPLAY: UI_DisplaySettingsTab,
		TabId.AUDIO: UI_AudioSettingsTab,
		TabId.VFX: UI_VFXSettingsTab,
		TabId.LANGUAGE: UI_LocalizationSettingsTab,
		TabId.GAMEPAD: UI_GamepadSettingsTab,
		TabId.KEYBOARD_MOUSE: UI_KeyboardMouseSettingsTab,
		TabId.TOUCHSCREEN: UI_TouchscreenSettingsTab,
	}
	var tab_names := {
		TabId.DISPLAY: "DisplayTabContent",
		TabId.AUDIO: "AudioTabContent",
		TabId.VFX: "VFXTabContent",
		TabId.LANGUAGE: "LanguageTabContent",
		TabId.GAMEPAD: "GamepadTabContent",
		TabId.KEYBOARD_MOUSE: "KeyboardMouseTabContent",
		TabId.TOUCHSCREEN: "TouchscreenTabContent",
	}
	for id in tab_classes:
		var klass: GDScript = tab_classes[id]
		var instance := klass.new() as Control
		instance.name = tab_names[id]
		instance.visible = false
		instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content_container.add_child(instance)
		_tab_contents[id] = instance

func _on_close_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_settings_panel()

func _show_tab_content(tab_id: TabId) -> void:
	var content: Control = _tab_contents.get(tab_id) as Control
	if content == null:
		return
	content.visible = true
	content.set_process(true)
	content.set_process_input(true)

func _hide_tab_content(tab_id: TabId) -> void:
	var content: Control = _tab_contents.get(tab_id) as Control
	if content == null:
		return
	content.visible = false
	content.set_process(false)
	content.set_process_input(false)

func _update_tab_visibility(state: Dictionary = {}) -> void:
	if state.is_empty():
		var store := get_store()
		if store != null:
			state = store.get_state()
	var has_gamepad: bool = U_InputSelectors.is_gamepad_connected(state)
	var device_type: int = U_InputSelectors.get_active_device_type(state)
	var is_mobile_context: bool = _is_mobile_context()
	var is_gamepad_active: bool = device_type == M_InputDeviceManager.DeviceType.GAMEPAD

	if device_type != _last_device_type:
		var previous_type: int = _last_device_type
		_last_device_type = device_type
		if device_type == M_InputDeviceManager.DeviceType.GAMEPAD \
				and previous_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN:
			reset_analog_navigation()
			_consume_next_nav = true

	if _tab_strip != null:
		_tab_strip.set_tab_visible(TabId.GAMEPAD, has_gamepad and device_type != M_InputDeviceManager.DeviceType.TOUCHSCREEN)
		_tab_strip.set_tab_visible(TabId.TOUCHSCREEN, is_mobile_context and not is_gamepad_active)
		_tab_strip.set_tab_visible(TabId.KEYBOARD_MOUSE, not is_mobile_context)

	if _active_tab < 0 or _tab_strip == null or not _tab_strip.get_tab_button(_active_tab).visible:
		_snap_to_first_visible_tab()
	_configure_focus_neighbors()
	_apply_context_background()

func _bind_tab_bar_motion() -> void:
	if _tab_strip == null:
		return
	for tab_id: int in _tab_strip.get_visible_tab_ids():
		var btn: Button = _tab_strip.get_tab_button(tab_id)
		if btn != null:
			U_UIMotion.bind_interactive(btn, CFG_MOTION_BUTTON_DEFAULT)

func _configure_focus_neighbors() -> void:
	if _tab_strip == null:
		return
	var visible_buttons: Array[Control] = []
	for tab_id: int in _tab_strip.get_visible_tab_ids():
		var btn: Button = _tab_strip.get_tab_button(tab_id)
		if btn != null:
			visible_buttons.append(btn)
	if visible_buttons.is_empty():
		return
	U_FocusConfigurator.configure_horizontal_focus(visible_buttons)
	_configure_tab_key_focus_paths()

func _configure_tab_key_focus_paths() -> void:
	if _active_tab < 0 or _tab_strip == null:
		return
	var visible_tabs := _tab_strip.get_visible_tab_ids()
	var current_index := visible_tabs.find(_active_tab)
	if current_index < 0:
		return
	var next_tab: TabId = visible_tabs[wrapi(current_index + 1, 0, visible_tabs.size())] as TabId
	var previous_tab: TabId = visible_tabs[wrapi(current_index - 1, 0, visible_tabs.size())] as TabId
	var next_button := _tab_strip.get_tab_button(next_tab)
	var previous_button := _tab_strip.get_tab_button(previous_tab)
	if next_button == null or previous_button == null:
		return
	var focusable := _get_focusable_descendants(_tab_contents.get(_active_tab) as Node)
	for control: Control in focusable:
		control.focus_next = control.get_path_to(next_button)
		control.focus_previous = control.get_path_to(previous_button)

func _snap_to_first_visible_tab() -> void:
	if _tab_strip == null:
		switch_to_tab(TabId.DISPLAY)
		return
	for tab_id: TabId in _TAB_ORDER:
		var btn: Button = _tab_strip.get_tab_button(tab_id)
		if btn != null and btn.visible:
			switch_to_tab(tab_id)
			return
	switch_to_tab(TabId.DISPLAY)

func _is_mobile_context() -> bool:
	if emulate_mobile_override:
		return true
	if OS.has_feature("mobile"):
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has("--emulate-mobile")

func _navigate_focus(direction: StringName) -> void:
	if _consume_next_nav:
		_consume_next_nav = false
		return
	super._navigate_focus(direction)

func _unhandled_input(event: InputEvent) -> void:
	if _tab_strip == null:
		super._unhandled_input(event)
		return
	if event.is_action_pressed("ui_focus_next"):
		_tab_strip.handle_shoulder_input(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_focus_prev"):
		_tab_strip.handle_shoulder_input(-1)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _find_first_focusable_in_tab(tab_id: TabId) -> Control:
	var content: Control = _tab_contents.get(tab_id) as Control
	if content == null:
		return null
	var focusable: Array[Control] = _get_focusable_descendants(content)
	if focusable.is_empty():
		return null
	return focusable[0]

func _get_focusable_descendants(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node == null:
		return result
	for child in node.get_children():
		if not (child is Node):
			continue
		if child is Control:
			var control := child as Control
			if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
				result.append(control)
		result.append_array(_get_focusable_descendants(child))
	return result

func _on_store_ready(store: M_StateStore) -> void:
	super._on_store_ready(store)
	if store == null:
		return
	store.slice_updated.connect(_on_slice_updated)
	_update_tab_visibility()

func _rebuild_theme_from_state() -> void:
	var store := get_store()
	if store == null:
		return
	var state: Dictionary = store.get_state()
	var accessibility: Dictionary = U_SETTINGS_SELECTORS.get_accessibility_settings(state)
	var color_blind_mode: String = accessibility.get("color_blind_mode", "normal")
	var high_contrast: bool = accessibility.get("high_contrast", false)
	var palette := U_UI_PALETTE_RESOLVER.resolve_palette(color_blind_mode, high_contrast)
	_current_palette = palette
	_rebuild_theme(palette)

func _rebuild_theme(palette: Resource) -> void:
	var config: Resource = U_UI_THEME_BUILDER.active_config
	if not (config is RS_UI_THEME_CONFIG):
		return
	var typed_config := config as RS_UI_THEME_CONFIG
	typed_config.ensure_runtime_defaults()
	self.theme = U_UI_THEME_BUILDER.build_theme(typed_config, null, palette)

func _on_slice_updated(_slice_name: StringName, _slice_state: Dictionary) -> void:
	_update_tab_visibility()
	if _slice_name == StringName("accessibility"):
		_rebuild_theme_from_state()

func _on_locale_changed(_locale: StringName) -> void:
	_localize_tab_buttons()

func _localize_tab_buttons() -> void:
	if _tab_strip == null:
		return
	for tab_id: int in _TAB_ORDER:
		var label_info: Dictionary = _TAB_LABELS.get(tab_id, {})
		var loc_key: StringName = label_info.get("key", StringName())
		var fallback: String = label_info.get("fallback", "")
		var btn: Button = _tab_strip.get_tab_button(tab_id)
		if btn != null and loc_key != StringName():
			btn.text = U_LOCALIZATION_UTILS.localize_with_fallback(loc_key, fallback)

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_settings_panel()

func _close_settings_panel() -> void:
	var store := get_store()
	if store == null:
		return
	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	elif shell == StringName("main_menu"):
		store.dispatch(U_NavigationActions.navigate_to_ui_screen(_MAIN_MENU_SCENE_ID, "fade", 2))
	else:
		store.dispatch(U_NavigationActions.set_shell(_MAIN_MENU_SCENE_ID, _MAIN_MENU_SCENE_ID))

func _apply_context_background() -> void:
	var store := get_store()
	var nav_slice: Dictionary = store.get_state().get("navigation", {}) if store != null else {}
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	var base_scene_id: StringName = U_NavigationSelectors.get_base_scene_id(nav_slice)
	var standalone_main_menu := shell == _MAIN_MENU_SCENE_ID \
			and base_scene_id == _SETTINGS_SCENE_ID \
			and overlay_stack.is_empty()
	var overlay_bg := get_node_or_null("OverlayBackground") as ColorRect
	if overlay_bg != null:
		overlay_bg.visible = not standalone_main_menu
	if _menu_background != null:
		_menu_background.visible = standalone_main_menu

func _apply_layout_tokens() -> void:
	var config: Resource = U_UI_THEME_BUILDER.active_config
	var typed_config := config as RS_UI_THEME_CONFIG
	if typed_config == null:
		typed_config = RS_UI_THEME_CONFIG.new()
	typed_config.ensure_runtime_defaults()
	var center := get_node_or_null("CenterContainer") as CenterContainer
	if center != null:
		var outer := float(typed_config.margin_outer)
		center.offset_left = outer
		center.offset_top = outer
		center.offset_right = -outer
		center.offset_bottom = -outer
	var panel := get_node_or_null("CenterContainer/Panel") as PanelContainer
	if panel != null:
		var panel_style := typed_config.panel_section.duplicate() as StyleBoxFlat
		panel_style.content_margin_left = float(typed_config.margin_section)
		panel_style.content_margin_right = float(typed_config.margin_section)
		panel_style.content_margin_top = float(typed_config.margin_section)
		panel_style.content_margin_bottom = float(typed_config.margin_section)
		var panel_bg := panel_style.bg_color
		panel_bg.a = maxf(panel_bg.a, 0.94)
		panel_style.bg_color = panel_bg
		panel.add_theme_stylebox_override("panel", panel_style)
	var vbox := get_node_or_null("CenterContainer/Panel/VBox") as VBoxContainer
	if vbox != null:
		vbox.add_theme_constant_override("separation", typed_config.separation_default)
	if _tab_bar != null:
		_tab_bar.add_theme_constant_override("separation", typed_config.separation_compact)
	if _chrome != null:
		var chrome_row := _chrome.get_chrome_row()
		if chrome_row != null:
			chrome_row.add_theme_constant_override("separation", typed_config.separation_default)
	if _shoulder_hint_row != null:
		_shoulder_hint_row.add_theme_constant_override("separation", typed_config.separation_compact)
	if _content_container != null:
		_content_container.add_theme_constant_override("separation", typed_config.separation_default)
	_style_shoulder_hint(_shoulder_hint_lb, typed_config)
	_style_shoulder_hint(_shoulder_hint_rb, typed_config)
	_style_shoulder_hint_label(typed_config)
	if _chrome != null:
		var close_margin := _chrome.get_close_button_margin()
		if close_margin != null:
			var margin := typed_config.margin_inner
			close_margin.add_theme_constant_override("margin_left", margin)
			close_margin.add_theme_constant_override("margin_top", margin)
			close_margin.add_theme_constant_override("margin_right", margin)
			close_margin.add_theme_constant_override("margin_bottom", margin)

func _style_shoulder_hint(hint: PanelContainer, config: RS_UI_THEME_CONFIG) -> void:
	if hint == null or config == null:
		return
	if config.panel_button_prompt != null:
			hint.add_theme_stylebox_override("panel", config.panel_button_prompt.duplicate())
	var label := hint.get_node_or_null("Label") as Label
	if label != null:
		label.add_theme_font_size_override("font_size", config.caption)
		label.add_theme_color_override("font_color", config.text_primary)

func _style_shoulder_hint_label(config: RS_UI_THEME_CONFIG) -> void:
	if _shoulder_hint_row == null or config == null:
		return
	var label := _shoulder_hint_row.get_node_or_null("ShoulderHintLabel") as Label
	if label != null:
		label.add_theme_font_size_override("font_size", config.body_small)
		label.add_theme_color_override("font_color", config.text_secondary)
