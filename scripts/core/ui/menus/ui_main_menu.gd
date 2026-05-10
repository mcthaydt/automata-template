@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_menu_screen.gd"
class_name UI_MainMenu

## Main Menu UI Controller (state-driven)
##
## Responds to navigation slice updates to show the correct panel
## and dispatches navigation actions for play/settings flows.


const W_MENU_BUTTON_LIST := preload("res://scripts/core/ui/widgets/w_menu_button_list.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_MENU_BUILDER := preload("res://scripts/core/ui/helpers/u_ui_menu_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const U_UI_THEME_DEBUG := preload("res://scripts/core/ui/utils/u_ui_theme_debug.gd")
const U_DEBUG_SELECTORS := preload("res://scripts/core/state/selectors/u_debug_selectors.gd")
const U_DEBUG_ACTIONS := preload("res://scripts/core/state/actions/u_debug_actions.gd")
const CFG_GAME_CONFIG := preload("res://resources/core/cfg_game_config.tres")

const PANEL_MAIN := StringName("menu/main")
const U_NAVIGATION_ACTIONS := preload("res://scripts/core/state/actions/u_navigation_actions.gd")
const OVERLAY_SETTINGS := StringName("settings_panel")
const OVERLAY_SAVE_LOAD := StringName("save_load_menu_overlay")

@onready var _title_label: Label = %TitleLabel
@onready var _main_panel: Control = %MainPanel

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _new_game_confirm_dialog: ConfirmationDialog = %NewGameConfirmDialog

var _save_manager: Node = null  # M_SaveManager
var _new_game_confirmation_pending: bool = false
var _menu_builder: RefCounted = null
var _button_list: W_MENU_BUTTON_LIST = null

var _store_unsubscribe: Callable = Callable()
var _active_panel: StringName = StringName()

func _on_panel_ready() -> void:
	_setup_menu_builder()
	_setup_widget_focus()
	_apply_theme_tokens()
	call_deferred("_debug_log_theme_snapshot")
	_discover_save_manager()
	_update_button_visibility()
	if _try_debug_skip_main_menu():
		return
	_localize_labels()
	var store := get_store()
	if store == null:
		return
	if _store_unsubscribe == Callable() or not _store_unsubscribe.is_valid():
		_store_unsubscribe = store.subscribe(_on_state_changed)
	_on_state_changed({}, store.get_state())
	play_enter_animation()

func _setup_menu_builder() -> void:
	_menu_builder = U_UI_MENU_BUILDER.new(self)
	_menu_builder.bind_title(_title_label, &"menu.main.title", "Main Menu")
	_menu_builder.bind_theme_role(_title_label, &"title")
	_menu_builder.build()
	if _new_game_confirm_dialog != null:
		if not _new_game_confirm_dialog.confirmed.is_connected(_on_new_game_confirmed):
			_new_game_confirm_dialog.confirmed.connect(_on_new_game_confirmed)
		if not _new_game_confirm_dialog.canceled.is_connected(_on_new_game_canceled):
			_new_game_confirm_dialog.canceled.connect(_on_new_game_canceled)

func _setup_widget_focus() -> void:
	_button_list = W_MENU_BUTTON_LIST.new()
	_button_list.name = "MenuButtonList"
	add_child(_button_list)
	_button_list.add_existing_button(_continue_button, &"menu.main.continue", "Continue", _on_continue_pressed)
	_button_list.add_existing_button(_new_game_button,   &"menu.main.new_game",   "New Game",   _on_new_game_pressed)
	_button_list.add_existing_button(_load_game_button,  &"menu.main.load_game",  "Load Game",  _on_load_game_pressed)
	_button_list.add_existing_button(_settings_button,   &"menu.main.settings",   "Settings",   _on_settings_pressed)
	_button_list.add_existing_button(_quit_button,       &"menu.main.quit",       "Quit",       _on_quit_pressed)
	_button_list.configure_vertical_focus(true)

func _apply_theme_tokens() -> void:
	if _menu_builder != null:
		_menu_builder.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
	_button_list.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)

func _discover_save_manager() -> void:
	_save_manager = U_ServiceLocator.try_get_service(StringName("save_manager"))

func _update_button_visibility() -> void:
	# Show Continue button only if saves exist
	var has_saves: bool = false
	var typed_save_manager := _save_manager as I_SaveManager
	if typed_save_manager != null:
		has_saves = typed_save_manager.has_any_saves()

	if _continue_button != null:
		_continue_button.visible = has_saves
		if not has_saves:
			_continue_button.focus_mode = Control.FOCUS_NONE

	# Hide Quit button on mobile (mobile apps should use OS close mechanisms)
	if _quit_button != null:
		_quit_button.visible = not OS.has_feature("mobile")
		if not _quit_button.visible:
			_quit_button.focus_mode = Control.FOCUS_NONE

func _process(delta: float) -> void:
	# Only run analog stick navigation from the main panel.
	if _active_panel != PANEL_MAIN:
		return
	super._process(delta)

func _exit_tree() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
		_store_unsubscribe = Callable()

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	var navigation_slice: Dictionary = state.get("navigation", {})
	var desired_panel: StringName = U_NavigationSelectors.get_active_menu_panel(navigation_slice)
	_update_panel_state(desired_panel)

	# Restore main panel visibility and focus when overlay closes (in main_menu shell)
	var shell: StringName = navigation_slice.get("shell", StringName(""))
	var overlay_stack: Array = navigation_slice.get("overlay_stack", [])
	if shell == StringName("main_menu") and not overlay_stack.is_empty():
		# Hide main menu options while overlays are open (e.g., Save/Load).
		if _main_panel != null:
			_main_panel.visible = false
	elif shell == StringName("main_menu") and overlay_stack.is_empty():
		# Restore visibility if panel was hidden
		if _main_panel != null and not _main_panel.visible and _active_panel == PANEL_MAIN:
			_main_panel.visible = true
		# BUG FIX: Always restore focus when returning from overlay, even if panel stayed visible
		if _active_panel == PANEL_MAIN:
			_focus_active_panel()

func _update_panel_state(panel_id: StringName) -> void:
	var resolved_panel: StringName = panel_id
	if resolved_panel == StringName(""):
		resolved_panel = PANEL_MAIN

	# Only respond to main menu panels (menu/*)
	# Ignore panels from other contexts (like pause/root from gameplay)
	if not _is_main_menu_panel(resolved_panel):
		return

	if resolved_panel == _active_panel:
		return
	_active_panel = resolved_panel
	_set_panel_visibility(resolved_panel == PANEL_MAIN)
	_focus_active_panel()

## Check if a panel ID belongs to the main menu
func _is_main_menu_panel(panel_id: StringName) -> bool:
	return panel_id == PANEL_MAIN

func _set_panel_visibility(show_main: bool) -> void:
	if _main_panel != null:
		_main_panel.visible = show_main

func _focus_active_panel() -> void:
	call_deferred("_apply_focus_after_layout")

func _apply_focus_after_layout() -> void:
	var focus_target: Control = _get_first_focusable()
	if focus_target != null and focus_target.is_inside_tree():
		focus_target.grab_focus()

func _get_first_focusable() -> Control:
	if _button_list != null:
		for btn in _button_list.get_buttons():
			if btn != null and btn.visible and btn.focus_mode != Control.FOCUS_NONE:
				return btn
	return null

func _on_continue_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	# Load the most recent save
	if _save_manager == null:
		push_error("UI_MainMenu: Save manager not available for Continue")
		return

	var most_recent_slot: StringName = _save_manager.get_most_recent_save_slot()
	if most_recent_slot == StringName(""):
		push_warning("UI_MainMenu: No saves found for Continue")
		return

	# Hide main menu content immediately for loading feedback
	if _main_panel != null:
		_main_panel.visible = false

	# Load the save (scene transition will close main menu)
	var result: Error = _save_manager.load_from_slot(most_recent_slot)

	# If load failed, restore visibility
	if result != OK:
		if _main_panel != null:
			_main_panel.visible = true
		push_error("UI_MainMenu: Failed to load save (error %d)" % result)

func _on_new_game_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	var store := get_store()
	if store == null:
		return

	# ConfirmationDialog is a native OS Window; popup_centered() inside a SubViewport
	# without gui_embed_subwindows does not render or receive touch on mobile.
	if not OS.has_feature("mobile") and _should_confirm_new_game():
		_show_new_game_confirmation()
		return

	store.dispatch(U_NavigationActions.start_game(_get_default_gameplay_scene()))

func _should_confirm_new_game() -> bool:
	var typed_save_manager := _save_manager as I_SaveManager
	if typed_save_manager == null:
		return false
	return typed_save_manager.has_any_saves()

func _show_new_game_confirmation() -> void:
	_new_game_confirmation_pending = true
	if _new_game_confirm_dialog == null:
		return
	_new_game_confirm_dialog.popup_centered()

func _on_new_game_confirmed() -> void:
	U_UISoundPlayer.play_confirm()

	_new_game_confirmation_pending = false
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.start_game(_get_default_gameplay_scene()))

func _on_new_game_canceled() -> void:
	U_UISoundPlayer.play_cancel()
	_new_game_confirmation_pending = false

func _on_load_game_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	var store := get_store()
	if store == null:
		return

	# Hide main panel while overlay is open
	if _main_panel != null:
		_main_panel.visible = false

	# Set mode to "load" and open the save/load overlay
	store.dispatch(U_NavigationActions.set_save_load_mode(StringName("load")))
	store.dispatch(U_NavigationActions.open_overlay(OVERLAY_SAVE_LOAD))

func _on_settings_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.navigate_to_ui_screen(OVERLAY_SETTINGS, "fade", 2))

func _on_quit_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	# Quit the game
	get_tree().quit()

func _try_debug_skip_main_menu() -> bool:
	var store := get_store()
	if store == null:
		return false
	var state: Dictionary = store.get_state()
	if not U_DEBUG_SELECTORS.should_skip_main_menu(state):
		return false
	if U_DEBUG_SELECTORS.are_boot_skips_consumed(state):
		return false
	store.dispatch(U_DEBUG_ACTIONS.set_boot_skips_consumed(true))
	var typed_save_manager := _save_manager as I_SaveManager
	if typed_save_manager != null and typed_save_manager.has_any_saves():
		var most_recent_slot: StringName = _save_manager.get_most_recent_save_slot()
		if most_recent_slot != StringName(""):
			if _can_debug_skip_via_save_slot(most_recent_slot):
				if _main_panel != null:
					_main_panel.visible = false
				var result: Error = typed_save_manager.load_from_slot(most_recent_slot)
				if result == OK:
					return true
	store.dispatch(U_NavigationActions.start_game(_get_default_gameplay_scene()))
	return true

func _get_default_gameplay_scene() -> StringName:
	return CFG_GAME_CONFIG.get_default_gameplay_scene_id()

func _can_debug_skip_via_save_slot(slot_id: StringName) -> bool:
	var concrete_save_manager := _save_manager as M_SaveManager
	if concrete_save_manager == null:
		return true
	var metadata: Dictionary = concrete_save_manager.get_slot_metadata(slot_id)
	if metadata.is_empty():
		return false
	var scene_id: String = str(metadata.get("current_scene_id", ""))
	return not scene_id.is_empty()

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	if _active_panel != PANEL_MAIN:
		var store := get_store()
		if store != null:
			store.dispatch(U_NavigationActions.set_menu_panel(PANEL_MAIN))

func _localize_labels() -> void:
	if _button_list != null:
		_button_list.localize_labels()
	if _title_label != null:
		_title_label.text = U_LOCALIZATION_UTILS.localize(&"menu.main.title")
	if _new_game_confirm_dialog != null:
		_new_game_confirm_dialog.dialog_text = U_LOCALIZATION_UTILS.localize(&"menu.main.new_game_confirm")

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()

func _debug_log_theme_snapshot() -> void:
	if not U_UI_THEME_DEBUG.is_enabled():
		return
	var root_theme: Theme = theme
	var button_theme := _new_game_button.get_theme() if _new_game_button != null else null
	var has_root_button_style := false
	var has_root_panel_style := false
	var has_button_effective_style := false
	if root_theme != null:
		has_root_button_style = root_theme.has_stylebox(&"normal", &"Button")
		has_root_panel_style = root_theme.has_stylebox(&"panel", &"PanelContainer")
	if _new_game_button != null:
		var stylebox: StyleBox = _new_game_button.get_theme_stylebox(&"normal")
		has_button_effective_style = stylebox != null
	_theme_debug_log(
		"theme snapshot: root_theme=%s root_has_button_style=%s root_has_panel_style=%s " % [
			str(root_theme != null),
			str(has_root_button_style),
			str(has_root_panel_style),
		] +
		"button_theme=%s button_effective_style=%s" % [
			str(button_theme != null),
			str(has_button_effective_style),
		]
	)

func _theme_debug_log(message: String) -> void:
	U_UI_THEME_DEBUG.log("UI_MainMenu", message)
