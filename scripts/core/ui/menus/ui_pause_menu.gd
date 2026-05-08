@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_overlay.gd"
class_name UI_PauseMenu

## Pause Menu - overlay wired into navigation actions
##
## Buttons dispatch navigation actions instead of calling Scene Manager directly.

const W_MENU_BUTTON_LIST := preload("res://scripts/core/ui/widgets/w_menu_button_list.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_MENU_BUILDER := preload("res://scripts/core/ui/helpers/u_ui_menu_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")

const OVERLAY_SETTINGS := StringName("settings_panel")
const OVERLAY_SAVE_LOAD := StringName("save_load_menu_overlay")

@onready var _title_label: Label = %TitleLabel
@onready var _main_panel: PanelContainer = %MainPanel
@onready var _main_panel_padding: MarginContainer = %MainPanelPadding
@onready var _main_panel_content: VBoxContainer = %MainPanelContent
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _quit_button: Button = %QuitButton

var _button_list: W_MENU_BUTTON_LIST = null
var _menu_builder: RefCounted = null
var _last_device_type: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
var _consume_next_nav: bool = false

func _ready() -> void:
	super._ready()

func _on_panel_ready() -> void:
	_setup_menu_builder()
	_button_list = W_MENU_BUTTON_LIST.new()
	_button_list.name = "MenuButtonList"
	add_child(_button_list)
	_button_list.add_existing_button(_resume_button,  &"menu.pause.resume", "Resume", _on_resume_pressed)
	_button_list.add_existing_button(_settings_button, &"menu.pause.settings", "Settings", _on_settings_pressed)
	_button_list.add_existing_button(_save_button,     &"menu.pause.save",     "Save", _on_save_pressed)
	_button_list.add_existing_button(_load_button,     &"menu.pause.load",     "Load", _on_load_pressed)
	_button_list.add_existing_button(_quit_button,     &"menu.pause.quit",     "Quit", _on_quit_pressed)
	_button_list.configure_vertical_focus(true)
	_button_list.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
	_button_list.localize_labels()

	# Hide quit on mobile; remove from focus chain
	var quit_btn := _quit_button
	if quit_btn != null:
		quit_btn.visible = not U_MobilePlatformDetector.is_mobile()
		if not quit_btn.visible:
			quit_btn.focus_mode = Control.FOCUS_NONE

	play_enter_animation()

func _setup_menu_builder() -> void:
	_menu_builder = U_UI_MENU_BUILDER.new(self)
	_menu_builder.bind_panel(_main_panel, _main_panel_padding, _main_panel_content)
	_menu_builder.bind_title(_title_label, &"menu.pause.title", "Paused")
	_menu_builder.bind_theme_role(self, &"overlay_dim", {"alpha": 0.7, "apply_menu_background": true})
	_menu_builder.bind_theme_role(get_node_or_null("OverlayBackground") as ColorRect, &"overlay_dim", {"alpha": 0.7})
	_menu_builder.build()

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

func _on_store_ready(store_ref: M_StateStore) -> void:
	if store_ref != null:
		store_ref.slice_updated.connect(_on_slice_updated)

func _exit_tree() -> void:
	var store := get_store()
	if store != null and store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.disconnect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name != StringName("navigation"):
		return
	var store := get_store()
	if store == null:
		return
	var nav_state: Dictionary = store.get_slice(StringName("navigation"))
	var shell: StringName = nav_state.get("shell", StringName())
	if shell != StringName("gameplay"):
		visible = false
	var overlay_stack: Array = nav_state.get("overlay_stack", [])
	if shell == StringName("gameplay") and overlay_stack.is_empty() and visible:
		_focus_resume()
	var state: Dictionary = store.get_state()
	var device_type: int = U_InputSelectors.get_active_device_type(state)
	var previous_type: int = _last_device_type
	_last_device_type = device_type
	if device_type == M_InputDeviceManager.DeviceType.GAMEPAD \
			and previous_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN:
		reset_analog_navigation()
		_consume_next_nav = true
		_focus_resume()

func _navigate_focus(direction: StringName) -> void:
	if _consume_next_nav:
		_consume_next_nav = false
		return
	super._navigate_focus(direction)

func _focus_resume() -> void:
	var first_button := _button_list.get_buttons()[0] if _button_list != null and not _button_list.get_buttons().is_empty() else null
	if first_button == null or not first_button.is_inside_tree() or not first_button.visible:
		_apply_initial_focus()
		return
	call_deferred("_deferred_focus_resume")

func _deferred_focus_resume() -> void:
	var first_button := _button_list.get_buttons()[0] if _button_list != null and not _button_list.get_buttons().is_empty() else null
	if first_button != null and first_button.is_inside_tree() and first_button.visible:
		first_button.grab_focus()

func _localize_labels() -> void:
	if _button_list != null:
		_button_list.localize_labels()
	if _title_label != null:
		_title_label.text = U_LOCALIZATION_UTILS.localize(&"menu.pause.title")

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
