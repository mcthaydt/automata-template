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

@export var emulate_mobile_override: bool = false

var _active_tab: int = -1
var _tab_buttons: Dictionary = {}
var _tab_contents: Dictionary = {}
var _last_device_type: int = -1
var _consume_next_nav: bool = false
var _close_button: Button = null

@onready var _tab_bar: HBoxContainer = $CenterContainer/Panel/VBox/TabBar
@onready var _separator: HSeparator = $CenterContainer/Panel/VBox/HSeparator
@onready var _content_container: VBoxContainer = $CenterContainer/Panel/VBox/ContentContainer

func _ready() -> void:
	super._ready()
	_apply_base_theme()
	_create_close_button()
	_build_tab_bar()
	_create_tab_contents()
	_update_tab_visibility()
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
	var first_focusable: Control = _find_first_focusable_in_tab(tab_id)
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
	_close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_button.offset_right = 0
	_close_button.offset_top = 8
	_close_button.offset_left = -44
	_close_button.offset_bottom = 52

func _build_tab_bar() -> void:
	if _tab_bar == null:
		return
	_tab_buttons.clear()
	for tab_key: int in _TAB_LABELS:
		var tab_id: TabId = tab_key as TabId
		var label_info: Dictionary = _TAB_LABELS[tab_id]
		var button := Button.new()
		var localized_text: String = U_LOCALIZATION_UTILS.localize_with_fallback(label_info.key, label_info.fallback)
		button.text = localized_text
		button.name = "TabButton_%d" % tab_id
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_tab_button_pressed.bind(tab_id))
		button.focus_entered.connect(_on_tab_button_focused.bind(tab_id))
		_tab_bar.add_child(button)
		_tab_buttons[tab_id] = {
			"button": button,
			"key": label_info.key,
			"fallback": label_info.fallback,
		}

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
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NAVIGATION_ACTIONS.close_top_overlay())

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
			button.disabled = true
			button.theme_type_variation = "TabActive"
		else:
			button.disabled = false
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
	var priority_order: Array[TabId] = [
		TabId.DISPLAY,
		TabId.AUDIO,
		TabId.VFX,
		TabId.LANGUAGE,
		TabId.GAMEPAD,
		TabId.KEYBOARD_MOUSE,
		TabId.TOUCHSCREEN,
	]
	for tab_id: TabId in priority_order:
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

func _on_slice_updated(_slice_name: StringName, _slice_state: Dictionary) -> void:
	_update_tab_visibility()

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
	var store := get_store()
	if store == null:
		return
	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	elif shell == StringName("main_menu"):
		store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_panel"), "fade", 2))
	else:
		store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_panel")))
