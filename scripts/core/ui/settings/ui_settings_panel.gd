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
const TEX_BUTTON_LB := preload("res://assets/core/button_prompts/gamepad/button_lb.png")
const TEX_BUTTON_RB := preload("res://assets/core/button_prompts/gamepad/button_rb.png")

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
var _tab_buttons: Dictionary = {}
var _tab_contents: Dictionary = {}
var _last_device_type: int = -1
var _consume_next_nav: bool = false
var _close_button: Button = null
var _current_palette: Resource = null
var _tab_button_group: ButtonGroup = ButtonGroup.new()
var _menu_background: TextureRect = null
var _panel_chrome: HBoxContainer = null
var _tab_header_spacer: Control = null
var _close_button_margin: MarginContainer = null

@onready var _tab_bar: HBoxContainer = $CenterContainer/Panel/VBox/TabBar
@onready var _separator: HSeparator = $CenterContainer/Panel/VBox/HSeparator
@onready var _content_container: VBoxContainer = $CenterContainer/Panel/VBox/ContentContainer

func _ready() -> void:
	super._ready()
	_apply_base_theme()
	_create_menu_background()
	_create_close_button()
	_create_panel_chrome()
	_attach_close_button_to_chrome()
	_build_tab_bar()
	_create_shoulder_prompts()
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
	_update_tab_button_states()
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

func _create_close_button() -> void:
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.flat = true
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.custom_minimum_size = Vector2(44, 44)
	_close_button.pressed.connect(_on_close_pressed)
	U_UIMotion.bind_interactive(_close_button, CFG_MOTION_BUTTON_DEFAULT)
	add_child(_close_button)

func _create_panel_chrome() -> void:
	var vbox := get_node_or_null("CenterContainer/Panel/VBox") as VBoxContainer
	if vbox == null:
		return
	_panel_chrome = HBoxContainer.new()
	_panel_chrome.name = "PanelChrome"
	_panel_chrome.alignment = BoxContainer.ALIGNMENT_BEGIN
	_panel_chrome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_chrome)
	vbox.move_child(_panel_chrome, 0)

	_tab_header_spacer = Control.new()
	_tab_header_spacer.name = "TabHeaderSpacer"
	_tab_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _attach_close_button_to_chrome() -> void:
	if _panel_chrome == null or _close_button == null:
		return
	if _close_button_margin == null:
		_close_button_margin = MarginContainer.new()
		_close_button_margin.name = "CloseButtonMargin"
		_close_button_margin.size_flags_horizontal = Control.SIZE_SHRINK_END
	if _close_button_margin.get_parent() != _panel_chrome:
		_panel_chrome.add_child(_close_button_margin)
	if _close_button.get_parent() != _close_button_margin:
		_close_button.reparent(_close_button_margin)
	_close_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_close_button.offset_left = 0.0
	_close_button.offset_top = 0.0
	_close_button.offset_right = 0.0
	_close_button.offset_bottom = 0.0
	_panel_chrome.move_child(_close_button_margin, _panel_chrome.get_child_count() - 1)

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

func _build_tab_bar() -> void:
	if _tab_bar == null:
		return
	if _panel_chrome != null and _tab_bar.get_parent() != _panel_chrome:
		_tab_bar.reparent(_panel_chrome)
		_panel_chrome.move_child(_tab_bar, 0)
		if _tab_header_spacer != null and _tab_header_spacer.get_parent() == null:
			_panel_chrome.add_child(_tab_header_spacer)
		if _close_button_margin != null and _close_button_margin.get_parent() == _panel_chrome:
			_panel_chrome.move_child(_close_button_margin, _panel_chrome.get_child_count() - 1)
	_tab_buttons.clear()
	_tab_button_group.allow_unpress = false
	for tab_id: TabId in _TAB_ORDER:
		var label_info: Dictionary = _TAB_LABELS[tab_id]
		var button := Button.new()
		var localized_text: String = U_LOCALIZATION_UTILS.localize_with_fallback(label_info.key, label_info.fallback)
		button.text = localized_text
		button.name = "TabButton_%d" % tab_id
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.button_group = _tab_button_group
		button.pressed.connect(_on_tab_button_pressed.bind(tab_id))
		button.focus_entered.connect(_on_tab_button_focused.bind(tab_id))
		_tab_bar.add_child(button)
		_tab_buttons[tab_id] = {
			"button": button,
			"key": label_info.key,
			"fallback": label_info.fallback,
		}

func _create_shoulder_prompts() -> void:
	if _panel_chrome == null:
		return
	var prompt_row := HBoxContainer.new()
	prompt_row.name = "ShoulderPromptRow"
	prompt_row.alignment = BoxContainer.ALIGNMENT_END
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_panel_chrome.add_child(prompt_row)
	if _close_button_margin != null and _close_button_margin.get_parent() == _panel_chrome:
		_panel_chrome.move_child(_close_button_margin, _panel_chrome.get_child_count() - 1)

	var lb_icon := _create_prompt_icon("ShoulderPromptLBIcon", TEX_BUTTON_LB)
	var label := Label.new()
	label.name = "ShoulderPromptLabel"
	label.text = "Tabs"
	var rb_icon := _create_prompt_icon("ShoulderPromptRBIcon", TEX_BUTTON_RB)
	prompt_row.add_child(lb_icon)
	prompt_row.add_child(label)
	prompt_row.add_child(rb_icon)

func _create_prompt_icon(node_name: String, texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = texture
	icon.custom_minimum_size = Vector2(44, 26)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

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

func _on_tab_button_focused(tab_id: TabId) -> void:
	switch_to_tab(tab_id)

func _on_tab_button_pressed(tab_id: TabId) -> void:
	U_UISoundPlayer.play_confirm()
	switch_to_tab(tab_id)

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

func _update_tab_button_states() -> void:
	for tab_key: int in _tab_buttons:
		var tab_id: TabId = tab_key as TabId
		var entry: Dictionary = _tab_buttons[tab_id]
		var button: Button = entry.button as Button
		if button == null:
			continue
		if tab_id == _active_tab:
			button.button_pressed = true
			button.theme_type_variation = "TabActive"
		else:
			button.button_pressed = false
			button.theme_type_variation = "TabInactive"

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

	_set_tab_visible(TabId.GAMEPAD, has_gamepad and device_type != M_InputDeviceManager.DeviceType.TOUCHSCREEN)
	_set_tab_visible(TabId.TOUCHSCREEN, is_mobile_context and not is_gamepad_active)
	_set_tab_visible(TabId.KEYBOARD_MOUSE, not is_mobile_context)

	if _active_tab < 0 or _is_tab_hidden(_active_tab as TabId):
		_snap_to_first_visible_tab()
	_configure_focus_neighbors()
	_apply_context_background()

func _bind_tab_bar_motion() -> void:
	for tab_key: int in _tab_buttons:
		var entry: Dictionary = _tab_buttons[tab_key]
		var button: Button = entry.button as Button
		if button != null:
			U_UIMotion.bind_interactive(button, CFG_MOTION_BUTTON_DEFAULT)

func _configure_focus_neighbors() -> void:
	var visible_buttons: Array[Control] = []
	for tab_key: int in _tab_buttons:
		var entry: Dictionary = _tab_buttons[tab_key]
		var button: Button = entry.button as Button
		if button == null:
			continue
		if button.is_visible_in_tree():
			visible_buttons.append(button)
	if visible_buttons.is_empty():
		return
	U_FocusConfigurator.configure_horizontal_focus(visible_buttons)

func _set_tab_visible(tab_id: TabId, visible: bool) -> void:
	var entry: Dictionary = _tab_buttons.get(tab_id, {})
	var button: Button = entry.get("button") as Button
	if button != null:
		button.visible = visible
	var content: Control = _tab_contents.get(tab_id) as Control
	if content != null:
		content.visible = visible and tab_id == _active_tab

func _is_tab_hidden(tab_id: TabId) -> bool:
	var entry: Dictionary = _tab_buttons.get(tab_id, {})
	var button: Button = entry.get("button") as Button
	if button == null:
		return true
	return not button.visible

func _snap_to_first_visible_tab() -> void:
	for tab_id: TabId in _TAB_ORDER:
		if not _is_tab_hidden(tab_id):
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
	if event.is_action_pressed("ui_focus_next"):
		_switch_visible_tab(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_focus_prev"):
		_switch_visible_tab(-1)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _switch_visible_tab(step: int) -> void:
	var visible_tabs := _get_visible_tab_ids()
	if visible_tabs.is_empty():
		return
	var current_index := visible_tabs.find(_active_tab)
	if current_index < 0:
		current_index = 0
	var next_index := wrapi(current_index + step, 0, visible_tabs.size())
	switch_to_tab(visible_tabs[next_index] as TabId)

func _get_visible_tab_ids() -> Array[int]:
	var result: Array[int] = []
	for tab_id: TabId in _TAB_ORDER:
		if not _is_tab_hidden(tab_id):
			result.append(tab_id)
	return result

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
	for tab_key: int in _tab_buttons:
		var tab_id: TabId = tab_key as TabId
		var entry: Dictionary = _tab_buttons[tab_id]
		var button: Button = entry.button as Button
		if button == null:
			continue
		var loc_key: StringName = entry.key
		var fallback: String = entry.fallback
		button.text = U_LOCALIZATION_UTILS.localize_with_fallback(loc_key, fallback)

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
	if _panel_chrome != null:
		_panel_chrome.add_theme_constant_override("separation", typed_config.separation_default)
	if _content_container != null:
		_content_container.add_theme_constant_override("separation", typed_config.separation_default)
	var prompt_row := find_child("ShoulderPromptRow", true, false) as HBoxContainer
	if prompt_row != null:
		prompt_row.add_theme_constant_override("separation", typed_config.separation_compact)
	var prompt_label := find_child("ShoulderPromptLabel", true, false) as Label
	if prompt_label != null:
		prompt_label.add_theme_font_size_override("font_size", typed_config.body_small)
		prompt_label.add_theme_color_override("font_color", typed_config.text_secondary)
	if _close_button_margin != null:
		var margin := typed_config.margin_inner
		_close_button_margin.add_theme_constant_override("margin_left", margin)
		_close_button_margin.add_theme_constant_override("margin_top", margin)
		_close_button_margin.add_theme_constant_override("margin_right", margin)
		_close_button_margin.add_theme_constant_override("margin_bottom", margin)
