@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/interfaces/i_rebind_overlay.gd"
class_name UI_InputRebindingOverlay

const I_INPUT_PROFILE_MANAGER := preload("res://scripts/core/interfaces/i_input_profile_manager.gd")
const DEFAULT_REBIND_SETTINGS: Resource = preload("res://resources/core/input/rebind_settings/cfg_default_rebind_settings.tres")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_OVERLAY_CLOSE_NAVIGATION := preload("res://scripts/core/ui/helpers/u_overlay_close_navigation.gd")
const U_UI_MENU_BUILDER := preload("res://scripts/core/ui/helpers/u_ui_menu_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const W_RIGHT_STICK_SCROLLER := preload("res://scripts/core/ui/widgets/w_right_stick_scroller.gd")

const TITLE_KEY := &"menu.settings.rebind"
const STATUS_DEFAULT_KEY := &"overlay.input_rebinding.status.default"
const STATUS_PROFILE_SWITCHED_KEY := &"overlay.input_rebinding.status.profile_switched"
const STATUS_BINDINGS_RESET_KEY := &"overlay.input_rebinding.status.bindings_reset"
const STATUS_ACTION_RESET_KEY := &"overlay.input_rebinding.status.action_reset"
const SEARCH_PLACEHOLDER_KEY := &"overlay.input_rebinding.search_placeholder"
const CLOSE_BUTTON_KEY := &"overlay.input_rebinding.close_button"
const RESET_BUTTON_KEY := &"overlay.input_rebinding.reset_button"
const CONFLICT_TITLE_KEY := &"overlay.input_rebinding.dialog.conflict_title"
const RESET_CONFIRM_TITLE_KEY := &"overlay.input_rebinding.dialog.reset_title"
const RESET_CONFIRM_TEXT_KEY := &"overlay.input_rebinding.dialog.reset_text"
const ERROR_TITLE_KEY := &"overlay.input_rebinding.dialog.error_title"
const ERROR_RESET_UNAVAILABLE_KEY := &"overlay.input_rebinding.error.reset_unavailable"
const ERROR_RESET_RESERVED_KEY := &"overlay.input_rebinding.error.reset_reserved"
const ERROR_RESET_ACTION_UNAVAILABLE_KEY := &"overlay.input_rebinding.error.reset_action_unavailable"

@onready var _title_label: Label = %TitleLabel
@onready var _main_panel: PanelContainer = %MainPanel
@onready var _main_panel_padding: MarginContainer = %MainPanelPadding
@onready var _main_panel_content: VBoxContainer = %MainPanelContent
@onready var _action_list: VBoxContainer = %ActionList
@onready var _status_label: Label = %StatusLabel
@onready var _search_box: LineEdit = %SearchBox
@onready var _button_row: HBoxContainer = %ButtonRow
@onready var _close_button: Button = %CloseButton
@onready var _reset_button: Button = %ResetButton
@onready var _scroll: ScrollContainer = %Scroll

# Dialogs: keep as @onready — native popups need scene-tree existence
@onready var _conflict_dialog: ConfirmationDialog = %ConflictDialog
@onready var _reset_confirm_dialog: ConfirmationDialog = %ResetConfirmDialog
@onready var _error_dialog: AcceptDialog = %ErrorDialog

@export var input_profile_manager: Node = null

const INPUT_PROFILE_MANAGER_SERVICE := StringName("input_profile_manager")

var _profile_manager: Node = null
var _rebind_settings: RS_RebindSettings = null
var _is_capturing: bool = false
var _pending_action: StringName = StringName()
var _pending_event: InputEvent = null
var _pending_conflict: StringName = StringName()
var _action_rows: Dictionary = {}  # StringName -> {container: VBoxContainer, name_label: Label, binding_container: HBoxContainer, replace_button: Button, add_button: Button, reset_button: Button, category_header: Label}
@warning_ignore("unused_private_class_variable")
var _capture_mode: String = U_InputActions.REBIND_MODE_REPLACE
var _search_filter: String = ""
@warning_ignore("unused_private_class_variable")
var _focused_action_index: int = -1
var _focusable_actions: Array[StringName] = []
var _capture_guard_active: bool = false
@warning_ignore("unused_private_class_variable")
var _is_on_bottom_row: bool = false
@warning_ignore("unused_private_class_variable")
var _bottom_button_index: int = 0
@warning_ignore("unused_private_class_variable")
var _row_button_index: int = 0
var _builder: RefCounted = null
var _right_stick_scroller: W_RIGHT_STICK_SCROLLER = null

func _on_panel_ready() -> void:
	_setup_builder()
	_apply_theme_tokens()
	_profile_manager = _resolve_input_profile_manager()
	if _profile_manager != null and "store_ref" in _profile_manager:
		var manager_store: Variant = _profile_manager.store_ref
		if manager_store is M_StateStore:
			_store = manager_store
	if _store == null:
		_store = _resolve_preferred_store()
	if _store == null:
		_store = get_store()
	if DEFAULT_REBIND_SETTINGS != null:
		_rebind_settings = DEFAULT_REBIND_SETTINGS.duplicate(true)
	else:
		_rebind_settings = RS_RebindSettings.new()

	_conflict_dialog.confirmed.connect(_on_conflict_confirmed)
	_conflict_dialog.canceled.connect(_on_conflict_canceled)
	_reset_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	_reset_confirm_dialog.canceled.connect(_on_reset_canceled)
	_error_dialog.confirmed.connect(_on_error_dismissed)

	# Connect search box
	if _search_box != null:
		_search_box.text_changed.connect(_on_search_changed)

	_right_stick_scroller = W_RIGHT_STICK_SCROLLER.new()
	_right_stick_scroller.bind_scroll_container(_scroll, 800.0, BaseMenuScreen.STICK_DEADZONE)
	add_child(_right_stick_scroller)

	_connect_profile_signals()
	_localize_static_labels()
	_build_action_rows()
	_update_status(_get_status_default_text())
	_set_reset_button_enabled(_profile_manager != null)
	_connect_bottom_row_focus_handlers()
	play_enter_animation()

func _setup_builder() -> void:
	_builder = U_UI_MENU_BUILDER.new(self)
	_builder.bind_panel(_main_panel, _main_panel_padding, _main_panel_content)
	_builder.bind_title(_title_label, TITLE_KEY, "Rebind Controls")
	_builder.bind_theme_role(self, &"overlay_dim", {"alpha": 0.5, "apply_menu_background": true})
	_builder.bind_theme_role(get_node_or_null("OverlayBackground") as ColorRect, &"overlay_dim", {"alpha": 0.5})
	_builder.bind_theme_role(_status_label, &"section_header")
	_builder.bind_theme_role(_status_label, &"text_secondary")
	_builder.bind_theme_role(_search_box, &"line_edit_search")
	_builder.bind_theme_role(_action_list, &"separation_compact")
	_builder.bind_theme_role(_button_row, &"separation_default")
	_builder.bind_button(_reset_button, RESET_BUTTON_KEY, _on_reset_pressed, "Reset")
	_builder.bind_button(_close_button, CLOSE_BUTTON_KEY, _on_close_pressed, "Close")
	_builder.build()

func _resolve_input_profile_manager() -> Node:
	if input_profile_manager != null and is_instance_valid(input_profile_manager):
		return input_profile_manager

	var manager := U_ServiceLocator.try_get_service(INPUT_PROFILE_MANAGER_SERVICE)
	if manager != null:
		return manager

	return null

func _connect_profile_signals() -> void:
	if _profile_manager == null:
		return
	if _profile_manager.has_signal("profile_switched"):
		_profile_manager.profile_switched.connect(func(_id): _on_profile_switched())
	if _profile_manager.has_signal("bindings_reset"):
		_profile_manager.bindings_reset.connect(_on_bindings_reset)
	if _profile_manager.has_signal("custom_binding_added"):
		_profile_manager.custom_binding_added.connect(func(_action, _event): _refresh_bindings())

func _on_profile_switched() -> void:
	_build_action_rows()
	_update_status(U_LOCALIZATION_UTILS.localize_with_fallback(STATUS_PROFILE_SWITCHED_KEY, "Profile switched. Select an action to rebind."))

func _on_bindings_reset() -> void:
	_refresh_bindings()
	_update_status(U_LOCALIZATION_UTILS.localize_with_fallback(STATUS_BINDINGS_RESET_KEY, "Bindings reset to defaults."))

func _build_action_rows() -> void:
	U_RebindActionListHelper.build_action_rows(
		self,
		_action_list,
		_action_rows,
		_focusable_actions,
		_search_filter
	)

func _get_active_profile() -> RS_InputProfile:
	var typed_manager := _profile_manager as I_INPUT_PROFILE_MANAGER
	if typed_manager != null:
		return typed_manager.get_active_profile()
	if _profile_manager != null and "active_profile" in _profile_manager:
		return _profile_manager.active_profile
	return null

func _refresh_bindings() -> void:
	U_RebindActionListHelper.refresh_bindings(self, _action_rows)

func _begin_capture(action: StringName, mode: String) -> void:
	U_RebindCaptureHandler.begin_capture(self, action, mode)

func _cancel_capture(message: String = "") -> void:
	var status_message: String = message
	if status_message.is_empty():
		status_message = _get_status_default_text()
	message = status_message
	U_RebindCaptureHandler.cancel_capture(self, message)

func _input(event: InputEvent) -> void:
	if not _is_capturing:
		super._input(event)
	U_RebindCaptureHandler.handle_input(self, event)

func _handle_captured_event(event: InputEvent) -> void:
	U_RebindCaptureHandler.handle_captured_event(self, event)

func _apply_binding(event: InputEvent, conflict_action: StringName) -> void:
	await U_RebindCaptureHandler.apply_binding(self, event, conflict_action)

func _resolve_preferred_store() -> I_StateStore:
	var store := U_ServiceLocator.try_get_service(StringName("state_store")) as I_StateStore
	if store != null and is_instance_valid(store):
		if "dispatched_actions" in store:
			return store
		return store
	return null

func _ensure_store_reference() -> void:
	if _store != null and is_instance_valid(_store):
		return
	var resolved := _resolve_preferred_store()
	if resolved != null:
		_store = resolved
		return
	_store = get_store()

func _get_active_device_category() -> String:
	_ensure_store_reference()
	if _store == null:
		return "keyboard"
	var state: Dictionary = _store.get_state()
	var device_type: int = U_InputSelectors.get_active_device_type(state)
	match device_type:
		1:
			return "gamepad"
		_:
			# Treat keyboard + mouse + touchscreen as keyboard-style bindings in this overlay.
			return "keyboard"

func _show_error(message: String) -> void:
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered()

func _on_conflict_confirmed() -> void:
	U_UISoundPlayer.play_confirm()
	if _pending_event == null or _pending_action == StringName():
		_cancel_capture(U_RebindCaptureHandler.get_rebind_cancelled_status())
		return
	var event := _pending_event.duplicate(true)
	var conflict := _pending_conflict
	_pending_event = null
	_pending_conflict = StringName()
	_apply_binding(event, conflict)

func _on_conflict_canceled() -> void:
	U_UISoundPlayer.play_cancel()
	_pending_event = null
	_pending_conflict = StringName()
	_cancel_capture(U_RebindCaptureHandler.get_rebind_cancelled_status())

func _on_error_dismissed() -> void:
	U_UISoundPlayer.play_confirm()
	if not _is_capturing:
		_refresh_bindings()

func _update_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func _on_close_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	if _is_capturing:
		_cancel_capture()
	_ensure_store_reference()
	U_OVERLAY_CLOSE_NAVIGATION.close_or_return_to_settings(self, _store)

func _on_back_pressed() -> void:
	_on_close_pressed()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	if _is_capturing:
		_cancel_capture()
	# Show confirmation dialog before resetting
	if _reset_confirm_dialog != null:
		_reset_confirm_dialog.popup_centered()

func _on_reset_confirmed() -> void:
	U_UISoundPlayer.play_confirm()
	_set_reset_button_enabled(false)
	var typed_manager := _profile_manager as I_INPUT_PROFILE_MANAGER
	if typed_manager != null:
		typed_manager.reset_to_defaults()
		# Note: bindings_reset signal will trigger _refresh_bindings() automatically
	else:
		_show_error(U_LOCALIZATION_UTILS.localize_with_fallback(ERROR_RESET_UNAVAILABLE_KEY, "Reset to defaults unavailable."))
	_set_reset_button_enabled(_profile_manager != null and not _is_capturing)

func _on_reset_canceled() -> void:
	U_UISoundPlayer.play_cancel()
	# User canceled the reset, do nothing
	pass

func _set_reset_button_enabled(enabled: bool) -> void:
	if _reset_button == null:
		return
	var allow_reset := enabled and _profile_manager != null
	_reset_button.disabled = not allow_reset

func _is_reserved(action: StringName) -> bool:
	return U_InputRebindUtils.is_reserved_action(action, _rebind_settings)

func _format_binding_text(events: Array) -> String:
	var labels: Array[String] = []
	for ev in events:
		if ev is InputEvent:
			var event := ev as InputEvent
			labels.append(U_InputRebindUtils.format_event_label(event))
		elif ev is Dictionary:
			var reconstructed := U_InputRebindUtils.dict_to_event(ev)
			if reconstructed is InputEvent:
				labels.append(U_InputRebindUtils.format_event_label(reconstructed as InputEvent))
	return ", ".join(labels)

func _reset_single_action(action: StringName) -> void:
	if _is_reserved(action):
		_show_error(U_LOCALIZATION_UTILS.localize_with_fallback(ERROR_RESET_RESERVED_KEY, "Cannot reset reserved action."))
		return
	var typed_manager := _profile_manager as I_INPUT_PROFILE_MANAGER
	if typed_manager != null:
		typed_manager.reset_action(action)
		_refresh_bindings()
		_update_status(U_LOCALIZATION_UTILS.localize_with_fallback(STATUS_ACTION_RESET_KEY, "Action '{action}' reset to default.").format({
			"action": U_RebindActionListHelper.get_action_display_name(action)
		}))
	else:
		_show_error(U_LOCALIZATION_UTILS.localize_with_fallback(ERROR_RESET_ACTION_UNAVAILABLE_KEY, "Reset action unavailable."))

func _on_locale_changed(_locale: StringName) -> void:
	_localize_static_labels()
	_build_action_rows()
	if _is_capturing and _pending_action != StringName():
		_update_status(U_RebindCaptureHandler.get_capture_prompt(_pending_action))

func _localize_static_labels() -> void:
	if _builder != null:
		_builder.localize_labels()
	if _search_box != null:
		_search_box.placeholder_text = U_LOCALIZATION_UTILS.localize_with_fallback(SEARCH_PLACEHOLDER_KEY, "Search actions...")
	if _conflict_dialog != null:
		_conflict_dialog.title = U_LOCALIZATION_UTILS.localize_with_fallback(CONFLICT_TITLE_KEY, "Conflict Detected")
		var conflict_ok := _conflict_dialog.get_ok_button()
		if conflict_ok != null:
			conflict_ok.text = U_RebindActionListHelper.get_replace_button_text()
		var conflict_cancel := _conflict_dialog.get_cancel_button()
		if conflict_cancel != null:
			conflict_cancel.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.cancel", "Cancel")
	if _reset_confirm_dialog != null:
		_reset_confirm_dialog.title = U_LOCALIZATION_UTILS.localize_with_fallback(RESET_CONFIRM_TITLE_KEY, "Reset All Bindings")
		_reset_confirm_dialog.dialog_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			RESET_CONFIRM_TEXT_KEY,
			"Reset all bindings to defaults? This cannot be undone."
		)
		var reset_ok := _reset_confirm_dialog.get_ok_button()
		if reset_ok != null:
			reset_ok.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.reset", "Reset")
		var reset_cancel := _reset_confirm_dialog.get_cancel_button()
		if reset_cancel != null:
			reset_cancel.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.cancel", "Cancel")
	if _error_dialog != null:
		_error_dialog.title = U_LOCALIZATION_UTILS.localize_with_fallback(ERROR_TITLE_KEY, "Rebind Error")

func _apply_theme_tokens() -> void:
	if _builder != null:
		_builder.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)

func _get_status_default_text() -> String:
	return U_LOCALIZATION_UTILS.localize_with_fallback(STATUS_DEFAULT_KEY, "Select an action to rebind.")

func _on_search_changed(new_text: String) -> void:
	_search_filter = new_text
	_build_action_rows()

func _connect_bottom_row_focus_handlers() -> void:
	if _reset_button != null and not _reset_button.focus_entered.is_connected(_on_reset_button_focus_entered):
		_reset_button.focus_entered.connect(_on_reset_button_focus_entered)
	if _close_button != null and not _close_button.focus_entered.is_connected(_on_close_button_focus_entered):
		_close_button.focus_entered.connect(_on_close_button_focus_entered)

func _on_reset_button_focus_entered() -> void:
	_sync_focus_tracking_from_control(_reset_button)

func _on_close_button_focus_entered() -> void:
	_sync_focus_tracking_from_control(_close_button)

func _sync_focus_tracking_from_control(control: Control) -> void:
	U_RebindFocusNavigation.sync_focus_tracking_from_control(self, control)

func _refresh_action_row_highlight() -> void:
	U_RebindFocusNavigation.refresh_action_row_highlight(self)

func _unhandled_key_input(event: InputEvent) -> void:
	U_RebindFocusNavigation.handle_unhandled_key_input(self, event, _search_box)

func _is_binding_custom(action: StringName) -> bool:
	_ensure_store_reference()
	if _store == null:
		return false
	var state := _store.get_state()
	if state == null:
		return false
	var settings_variant: Variant = state.get("settings", {})
	if not (settings_variant is Dictionary):
		return false
	var input_variant: Variant = (settings_variant as Dictionary).get("input_settings", {})
	if not (input_variant is Dictionary):
		return false
	var bindings_variant: Variant = (input_variant as Dictionary).get("custom_bindings", {})
	if bindings_variant is Dictionary:
		return (bindings_variant as Dictionary).has(action)
	return false

func _configure_focus_neighbors() -> void:
	U_RebindFocusNavigation.configure_focus_neighbors(self)

func _get_first_focusable() -> Control:
	var first := U_RebindFocusNavigation.get_first_focusable(self)
	if first != null:
		return first
	return super._get_first_focusable()

func _unhandled_input(event: InputEvent) -> void:
	# Let default UI navigation (neighbors) handle D-pad and keyboard,
	# so behavior matches other menus.
	super._unhandled_input(event)

func _exit_tree() -> void:
	if _capture_guard_active:
		U_InputCaptureGuard.end_capture()
	_capture_guard_active = false

func _connect_row_focus_handlers(row: Control, add_button: Button, replace_button: Button, reset_button: Button) -> void:
	U_RebindFocusNavigation.connect_row_focus_handlers(self, row, add_button, replace_button, reset_button)

func _navigate_focus(direction: StringName) -> void:
	# Defer to BaseMenuScreen neighbor-based navigation for analog sticks
	# so movement feels consistent with other menus.
	super._navigate_focus(direction)

# Public interface methods (delegate to private implementations)
# Phase 9: Duck Typing Cleanup - Added to implement I_RebindOverlay interface

func begin_capture(action: StringName, mode: String) -> void:
	_begin_capture(action, mode)

func reset_single_action(action: StringName) -> void:
	_reset_single_action(action)

func connect_row_focus_handlers(row: Control, add_button: Button, replace_button: Button, reset_button: Button) -> void:
	_connect_row_focus_handlers(row, add_button, replace_button, reset_button)

func is_reserved(action: StringName) -> bool:
	return _is_reserved(action)

func refresh_bindings() -> void:
	_refresh_bindings()

func set_reset_button_enabled(enabled: bool) -> void:
	_set_reset_button_enabled(enabled)

func configure_focus_neighbors() -> void:
	_configure_focus_neighbors()

func apply_focus() -> void:
	U_RebindFocusNavigation.apply_focus(self)

func get_active_device_category() -> String:
	return _get_active_device_category()

func is_binding_custom(action: StringName) -> bool:
	return _is_binding_custom(action)

func get_active_profile() -> RS_InputProfile:
	return _get_active_profile()

func get_profile_for_device_category(category: String) -> RS_InputProfile:
	if _profile_manager == null:
		return null
	if not ("available_profiles" in _profile_manager):
		return null
	var profiles: Dictionary = _profile_manager.available_profiles
	var target_device_type: int = 1 if category == "gamepad" else 0
	for key in profiles.keys():
		var profile := profiles[key] as RS_InputProfile
		if profile != null and profile.device_type == target_device_type:
			return profile
	return null
