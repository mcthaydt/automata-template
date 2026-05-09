@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_overlay.gd"
class_name UI_SaveLoadMenu

## Save/Load Menu - Combined overlay for saving and loading game slots
##
## Modes:
## - "save": Show save actions (Save/Overwrite, Delete)
## - "load": Show load actions (Load, Delete)
##
## Mode is determined by navigation.save_load_mode in Redux state.

const PLACEHOLDER_TEXTURE_PATH: String = "res://resources/core/ui/tex_save_slot_placeholder.png"
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_MENU_BUILDER := preload("res://scripts/core/ui/helpers/u_ui_menu_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const U_SAVE_ACTIONS := preload("res://scripts/core/state/actions/u_save_actions.gd")
const W_SAVE_SLOT_GRID := preload("res://scripts/core/ui/widgets/w_save_slot_grid.gd")
const OPERATION_SAVE := &"save"
const OPERATION_LOAD := &"load"
const OPERATION_DELETE := &"delete"

const LOADING_LABEL_KEY := &"overlay.save_load.loading"
const DIALOG_CONFIRM_TITLE_KEY := &"overlay.save_load.dialog.confirm_title"
const ERROR_UNKNOWN_KEY := &"overlay.save_load.error.unknown"
const ERROR_SAVE_FAILED_KEY := &"overlay.save_load.error.save_failed"
const ERROR_LOAD_FAILED_KEY := &"overlay.save_load.error.load_failed"
const ERROR_DELETE_FAILED_KEY := &"overlay.save_load.error.delete_failed"

## Current mode: "save" or "load"
var _mode: StringName = StringName("")

## Reference to M_SaveManager
var _save_manager: Node = null # M_SaveManager

## Cached slot metadata
var _cached_metadata: Array[Dictionary] = []

var _placeholder_texture: Texture2D = null
var _slot_grid: Control = null


## Confirmation dialog state
var _pending_action: Dictionary = {} # {action: "save"|"delete", slot_id: StringName}
var _builder: RefCounted = null

## UI References (set via @onready once scene is created)
@onready var _mode_label: Label = %ModeLabel
@onready var _main_panel: PanelContainer = %MainPanel
@onready var _main_panel_padding: MarginContainer = %MainPanelPadding
@onready var _main_panel_content: VBoxContainer = %MainPanelContent
@onready var _slot_list_container: VBoxContainer = %SlotListContainer
@onready var _back_button: Button = %BackButton
@onready var _confirmation_dialog: ConfirmationDialog = %ConfirmationDialog
@onready var _loading_spinner: Control = %LoadingSpinner
@onready var _spinner_label: Label = %SpinnerLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _loading_label: Label = %LoadingLabel

func _ready() -> void:
	_ensure_placeholder_texture_loaded()
	super._ready()
	_setup_slot_grid()
	_discover_save_manager()
	_refresh_ui()

func _ensure_placeholder_texture_loaded() -> void:
	if _placeholder_texture != null:
		return

	var loaded_resource: Resource = load(PLACEHOLDER_TEXTURE_PATH)
	if loaded_resource is Texture2D:
		_placeholder_texture = loaded_resource as Texture2D
		return

	if not FileAccess.file_exists(PLACEHOLDER_TEXTURE_PATH):
		return

	var image := Image.new()
	var load_error: Error = image.load(PLACEHOLDER_TEXTURE_PATH)
	if load_error == OK:
		_placeholder_texture = ImageTexture.create_from_image(image)

func _get_placeholder_texture() -> Texture2D:
	return _placeholder_texture

func _setup_slot_grid() -> void:
	_slot_grid = W_SAVE_SLOT_GRID.new()
	_slot_grid.name = "SaveSlotGrid"
	_slot_grid.visible = false
	add_child(_slot_grid)
	_slot_grid.bind_slot_container(_slot_list_container)
	_slot_grid.set_placeholder_texture(_get_placeholder_texture())
	_slot_grid.slot_pressed.connect(_on_slot_item_pressed)
	_slot_grid.delete_pressed.connect(_on_delete_button_pressed)

func _discover_save_manager() -> void:
	_save_manager = U_ServiceLocator.try_get_service(StringName("save_manager"))
	if _save_manager == null:
		push_error("UI_SaveLoadMenu: M_SaveManager not found in ServiceLocator")

func _exit_tree() -> void:
	# Disconnect from Redux action_dispatched
	var store := get_store()
	if store != null and store.has_signal("action_dispatched"):
		if store.action_dispatched.is_connected(_on_action_dispatched):
			store.action_dispatched.disconnect(_on_action_dispatched)

	# Disconnect from store
	if store != null and store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.disconnect(_on_slice_updated)

	if _slot_grid != null:
		_slot_grid.clear()

func _on_store_ready(store_ref: M_StateStore) -> void:
	if store_ref != null:
		# Save/load actions arrive via Redux dispatch; store wiring waits for
		# BasePanel's deferred store resolution.
		store_ref.slice_updated.connect(_on_slice_updated)
		if store_ref.has_signal("action_dispatched") and not store_ref.action_dispatched.is_connected(_on_action_dispatched):
			store_ref.action_dispatched.connect(_on_action_dispatched)
		_read_mode_from_state()

func _on_slice_updated(slice_name: StringName, __slice_state: Dictionary) -> void:
	if slice_name == StringName("navigation"):
		_read_mode_from_state()

func _read_mode_from_state() -> void:
	var store := get_store()
	if store == null:
		return

	var state: Dictionary = store.get_state()
	var nav_slice: Dictionary = state.get("navigation", {})
	var new_mode: StringName = nav_slice.get("save_load_mode", StringName(""))

	if new_mode != _mode:
		_mode = new_mode
		_refresh_ui()

func _refresh_ui() -> void:
	if not is_inside_tree():
		return

	# Update mode label
	_update_mode_label()

	# Refresh slot list
	_refresh_slot_list()

func _update_mode_label() -> void:
	if _mode_label == null:
		return

	if _mode == StringName("save"):
		_mode_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"overlay.save_load.title_save", "Save Game")
	elif _mode == StringName("load"):
		_mode_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"overlay.save_load.title_load", "Load Game")
	else:
		_mode_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"overlay.save_load.title_default", "Save / Load")

func _refresh_slot_list() -> void:
	if _save_manager == null or _slot_list_container == null:
		return

	# Store which slot index had focus before refresh
	var focused_slot_index: int = _slot_grid.get_focused_slot_index() if _slot_grid != null else -1

	# Get all slot metadata from M_SaveManager
	_cached_metadata = _save_manager.get_all_slot_metadata()

	if _slot_grid != null:
		_slot_grid.set_slots(_cached_metadata, _mode, U_UI_THEME_BUILDER.active_config)

	# Configure focus chain
	_configure_slot_focus()

	# Restore focus to the same slot (or first available if previous was deleted)
	if _slot_grid != null:
		_slot_grid.restore_focus(focused_slot_index)

func _configure_slot_focus() -> void:
	if _slot_grid != null:
		_slot_grid.configure_focus(_back_button)

func _on_slot_item_pressed(slot_id: StringName, exists: bool) -> void:
	U_UISoundPlayer.play_confirm()
	if _mode == StringName("save"):
		if exists:
			# Show overwrite confirmation
			_show_confirmation(
				U_LOCALIZATION_UTILS.localize_with_fallback(&"overlay.save_load.confirm_overwrite", "Overwrite existing save?"),
				{"action": "save", "slot_id": slot_id}
			)
		else:
			# Save directly to empty slot
			_perform_save(slot_id)
	elif _mode == StringName("load"):
		if exists:
			# Load from slot
			_perform_load(slot_id)
		# Empty slots are disabled in load mode, so this shouldn't happen

func _on_delete_button_pressed(slot_id: StringName) -> void:
	U_UISoundPlayer.play_confirm()
	# Show delete confirmation
	_show_confirmation(
		U_LOCALIZATION_UTILS.localize_with_fallback(&"overlay.save_load.confirm_delete", "Delete this save file?"),
		{"action": "delete", "slot_id": slot_id}
	)

func _show_confirmation(message: String, action_data: Dictionary) -> void:
	if _confirmation_dialog == null:
		return

	_pending_action = action_data
	_confirmation_dialog.dialog_text = message
	_confirmation_dialog.popup_centered()

func _on_confirmation_ok() -> void:
	U_UISoundPlayer.play_confirm()
	var action: String = _pending_action.get("action", "")
	var slot_id: StringName = _pending_action.get("slot_id", StringName(""))

	match action:
		"save":
			_perform_save(slot_id)
		"delete":
			_perform_delete(slot_id)

	_pending_action = {}

func _on_confirmation_cancel() -> void:
	U_UISoundPlayer.play_cancel()
	_pending_action = {}

func _perform_save(slot_id: StringName) -> void:
	if _save_manager == null:
		push_error("UI_SaveLoadMenu: Cannot save, M_SaveManager not found")
		return

	_clear_error_message()
	var result: Error = _save_manager.save_to_slot(slot_id)

	if result != OK:
		_show_error_message(_format_operation_error(OPERATION_SAVE, result))
		return

	call_deferred("_refresh_slot_list")

func _perform_load(slot_id: StringName) -> void:
	if _save_manager == null:
		push_error("UI_SaveLoadMenu: Cannot load, M_SaveManager not found")
		return

	_clear_error_message()
	# Perform the load (scene transition + loading screen handled by M_SceneManager)
	var result: Error = _save_manager.load_from_slot(slot_id)

	if result != OK:
		_show_error_message(_format_operation_error(OPERATION_LOAD, result))
		return

	# Close the save/load menu only after load_from_slot() starts successfully.
	# Immediate failures should remain visible in the menu.
	var store := get_store()
	if store != null:
		store.dispatch(U_NavigationActions.close_top_overlay())

func _perform_delete(slot_id: StringName) -> void:
	if _save_manager == null:
		push_error("UI_SaveLoadMenu: Cannot delete, M_SaveManager not found")
		return

	_clear_error_message()
	var result: Error = _save_manager.delete_slot(slot_id)

	if result != OK:
		_show_error_message(_format_operation_error(OPERATION_DELETE, result))
		return

	# Refresh UI to remove deleted slot
	_refresh_slot_list()

## Channel taxonomy: save actions arrive via Redux dispatch (managers dispatch to Redux)

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))

	if action_type == U_SAVE_ACTIONS.ACTION_SAVE_STARTED:
		_clear_error_message()
	elif action_type == U_SAVE_ACTIONS.ACTION_SAVE_COMPLETED:
		call_deferred("_refresh_slot_list")
	elif action_type == U_SAVE_ACTIONS.ACTION_SAVE_FAILED:
		var error_code: int = action.get("error_code", 0)
		_show_error_message(_format_operation_error(OPERATION_SAVE, error_code))
	elif action_type == U_SAVE_ACTIONS.ACTION_LOAD_STARTED:
		_clear_error_message()
		_show_loading_spinner()
		_set_buttons_enabled(false)
	elif action_type == U_SAVE_ACTIONS.ACTION_LOAD_COMPLETED:
		_hide_loading_spinner()
		_set_buttons_enabled(true)
	elif action_type == U_SAVE_ACTIONS.ACTION_LOAD_FAILED:
		_hide_loading_spinner()
		_set_buttons_enabled(true)
		var error_code: int = action.get("error_code", 0)
		_show_error_message(_format_operation_error(OPERATION_LOAD, error_code))

func _clear_error_message() -> void:
	if _error_label == null:
		return

	_error_label.visible = false
	_error_label.text = ""

func _show_error_message(message: String) -> void:
	if _error_label == null:
		return

	_error_label.text = message
	_error_label.visible = true

func _format_operation_error(operation: StringName, error_code: int) -> String:
	var readable: String = error_string(error_code)
	if readable.is_empty():
		readable = U_LOCALIZATION_UTILS.localize_with_fallback(ERROR_UNKNOWN_KEY, "Unknown error")

	var template_key: StringName = ERROR_LOAD_FAILED_KEY
	var fallback: String = "Load failed: {error}"
	match operation:
		OPERATION_SAVE:
			template_key = ERROR_SAVE_FAILED_KEY
			fallback = "Save failed: {error}"
		OPERATION_DELETE:
			template_key = ERROR_DELETE_FAILED_KEY
			fallback = "Delete failed: {error}"

	var template: String = U_LOCALIZATION_UTILS.localize_with_fallback(template_key, fallback)
	return template.format({"error": readable})

## Helper methods for spinner and button state

func _show_loading_spinner() -> void:
	if _loading_spinner != null:
		_loading_spinner.visible = true

func _hide_loading_spinner() -> void:
	if _loading_spinner != null:
		_loading_spinner.visible = false

func _set_buttons_enabled(enabled: bool) -> void:
	# Disable/enable back button
	if _back_button != null:
		_back_button.disabled = not enabled

	# Disable/enable all slot buttons
	if _slot_grid != null:
		_slot_grid.set_buttons_enabled(enabled)

func _on_panel_ready() -> void:
	_setup_builder()
	_apply_theme_tokens()
	_connect_buttons()
	_localize_static_ui()
	_read_mode_from_state()
	play_enter_animation()

func _setup_builder() -> void:
	_builder = U_UI_MENU_BUILDER.new(self)
	_builder.bind_panel(_main_panel, _main_panel_padding, _main_panel_content)
	_builder.bind_theme_role(self, &"overlay_dim", {"alpha": 0.7, "apply_menu_background": true})
	_builder.bind_theme_role(get_node_or_null("OverlayBackground") as ColorRect, &"overlay_dim", {"alpha": 0.7})
	_builder.bind_theme_role(_slot_list_container, &"separation_compact")
	_builder.bind_theme_role(_mode_label, &"subheading")
	_builder.bind_theme_role(_spinner_label, &"subheading")
	_builder.bind_theme_role(_error_label, &"section_header")
	_builder.bind_theme_role(_error_label, &"danger")
	_builder.bind_button(_back_button, &"common.back", _on_back_pressed_button, "Back")
	_builder.build()

func _connect_buttons() -> void:
	if _confirmation_dialog != null:
		if not _confirmation_dialog.confirmed.is_connected(_on_confirmation_ok):
			_confirmation_dialog.confirmed.connect(_on_confirmation_ok)
		if not _confirmation_dialog.canceled.is_connected(_on_confirmation_cancel):
			_confirmation_dialog.canceled.connect(_on_confirmation_cancel)

func _on_back_pressed_button() -> void:
	_on_back_pressed()

func _on_locale_changed(_locale: StringName) -> void:
	_localize_static_ui()
	_refresh_ui()

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	# Close this overlay and return to pause menu
	var store := get_store()
	if store != null:
		store.dispatch(U_NavigationActions.close_top_overlay())

func _localize_static_ui() -> void:
	if _builder != null:
		_builder.localize_labels()
	if _loading_label != null:
		_loading_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(LOADING_LABEL_KEY, "Loading...")
	if _confirmation_dialog != null:
		_confirmation_dialog.title = U_LOCALIZATION_UTILS.localize_with_fallback(DIALOG_CONFIRM_TITLE_KEY, "Confirm")
		var ok_button := _confirmation_dialog.get_ok_button()
		if ok_button != null:
			ok_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.confirm", "Confirm")
		var cancel_button := _confirmation_dialog.get_cancel_button()
		if cancel_button != null:
			cancel_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.cancel", "Cancel")



func _apply_theme_tokens() -> void:
	if _builder != null:
		_builder.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
