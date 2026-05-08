@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_overlay.gd"
class_name UI_PauseMenu

## Pause Menu - overlay wired into navigation actions
##
## Buttons dispatch navigation actions instead of calling Scene Manager directly.

const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const W_MENU_BUTTON_LIST := preload("res://scripts/core/ui/widgets/w_menu_button_list.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

const OVERLAY_SETTINGS := StringName("settings_panel")
const OVERLAY_SAVE_LOAD := StringName("save_load_menu_overlay")

var _last_device_type: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
var _consume_next_nav: bool = false
var _button_list: W_MENU_BUTTON_LIST = null

@onready var _title_label: Label = %TitleLabel
@onready var _main_panel: PanelContainer = %MainPanel
@onready var _main_panel_padding: MarginContainer = %MainPanelPadding
@onready var _main_panel_content: VBoxContainer = %MainPanelContent

func _ready() -> void:
	super._ready()
	_configure_focus_neighbors()

func _configure_focus_neighbors() -> void:
	if _button_list != null:
		_button_list.configure_vertical_focus(true)

func _on_store_ready(store_ref: M_StateStore) -> void:
	if store_ref != null:
		store_ref.slice_updated.connect(_on_slice_updated)

func _exit_tree() -> void:
	var store := get_store()
	if store != null and store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.disconnect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	var store := get_store()
	if store == null:
		return

	if slice_name == StringName("navigation"):
		var nav_state: Dictionary = store.get_slice(StringName("navigation"))
		var shell: StringName = nav_state.get("shell", StringName())
		if shell != StringName("gameplay"):
			visible = false

		# BUG FIX: Restore focus when overlay closes (in gameplay shell)
		# When save/load menu or settings closes, refocus the pause menu
		var overlay_stack: Array = nav_state.get("overlay_stack", [])
		if shell == StringName("gameplay") and overlay_stack.is_empty() and visible:
			_focus_resume()

	# Preserve analog navigation behavior for gamepad switches
	var state: Dictionary = store.get_state()
	var device_type: int = U_InputSelectors.get_active_device_type(state)
	var previous_type: int = _last_device_type
	_last_device_type = device_type

	# Only consume first input when resuming FROM touch to gamepad.
	if device_type == M_InputDeviceManager.DeviceType.GAMEPAD \
			and previous_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN:
		reset_analog_navigation()
		_consume_next_nav = true
		_focus_resume()

func _navigate_focus(direction: StringName) -> void:
	if _consume_next_nav:
		_consume_next_nav = false
		return

	var viewport: Viewport = get_viewport()
	var _before: Control = null
	if viewport != null:
		_before = viewport.gui_get_focus_owner() as Control

	super._navigate_focus(direction)

func _focus_resume() -> void:
	if _button_list == null or _button_list.get_buttons().is_empty():
		_apply_initial_focus()
		return
	var resume_btn: Button = _button_list.get_buttons()[0]
	if resume_btn != null and resume_btn.is_inside_tree() and resume_btn.visible:
		call_deferred("_deferred_focus_resume")
	else:
		_apply_initial_focus()

func _deferred_focus_resume() -> void:
	if _button_list != null and not _button_list.get_buttons().is_empty():
		var resume_btn: Button = _button_list.get_buttons()[0]
		if resume_btn != null and resume_btn.is_inside_tree() and resume_btn.visible:
			resume_btn.grab_focus()

func _on_panel_ready() -> void:
	# Remove old scene buttons so they do not compete with W_MenuButtonList
	for child in _main_panel_content.get_children().duplicate():
		if child is Button:
			_main_panel_content.remove_child(child)
			child.free()

	_button_list = W_MENU_BUTTON_LIST.new()
	_button_list.add_button(&"menu.pause.resume", "Resume", _on_resume_pressed)
	_button_list.add_button(&"menu.pause.settings", "Settings", _on_settings_pressed)
	_button_list.add_button(&"menu.pause.save", "Save", _on_save_pressed)
	_button_list.add_button(&"menu.pause.load", "Load", _on_load_pressed)
	_button_list.add_button(&"menu.pause.quit", "Quit", _on_quit_pressed)
	_button_list.configure_vertical_focus(true)
	_main_panel_content.add_child(_button_list)
	_localize_labels()
	_apply_theme_tokens()
	play_enter_animation()

func _on_resume_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_dispatch_navigation(U_NavigationActions.close_pause())

func _on_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SETTINGS))

func _on_save_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.set_save_load_mode(StringName("save")))
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SAVE_LOAD))

func _on_load_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.set_save_load_mode(StringName("load")))
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SAVE_LOAD))

func _on_quit_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_dispatch_navigation(U_NavigationActions.return_to_main_menu())

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_dispatch_navigation(U_NavigationActions.close_pause())

func _dispatch_navigation(action: Dictionary) -> void:
	if action.is_empty():
		return
	var store := get_store()
	if store == null:
		return
	store.dispatch(action)

func _localize_labels() -> void:
	if _title_label != null:
		_title_label.text = U_LOCALIZATION_UTILS.localize(&"menu.pause.title")
	if _button_list != null:
		var buttons: Array[Button] = _button_list.get_buttons()
		var labels: Array[StringName] = [
			&"menu.pause.resume",
			&"menu.pause.settings",
			&"menu.pause.save",
			&"menu.pause.load",
			&"menu.pause.quit",
		]
		for i in range(buttons.size()):
			var btn := buttons[i]
			var loc_key: StringName = labels[i] if i < labels.size() else &""
			if loc_key != StringName():
				btn.text = U_LOCALIZATION_UTILS.localize_with_fallback(loc_key, btn.text)

func _apply_theme_tokens() -> void:
	var config: Resource = U_UI_THEME_BUILDER.active_config
	var typed_config := config as RS_UI_THEME_CONFIG
	if typed_config == null:
		return
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", typed_config.heading)
	if _main_panel_content != null:
		_main_panel_content.add_theme_constant_override("separation", typed_config.separation_default)
	if _main_panel_padding != null:
		var margin := typed_config.margin_section
		_main_panel_padding.add_theme_constant_override("margin_left", margin)
		_main_panel_padding.add_theme_constant_override("margin_top", margin)
		_main_panel_padding.add_theme_constant_override("margin_right", margin)
		_main_panel_padding.add_theme_constant_override("margin_bottom", margin)
	var overlay_bg := get_node_or_null("OverlayBackground") as ColorRect
	if overlay_bg != null:
		var dim_color := typed_config.bg_base
		dim_color.a = 0.7
		overlay_bg.color = dim_color

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
