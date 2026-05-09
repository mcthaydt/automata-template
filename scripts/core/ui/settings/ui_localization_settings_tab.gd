@icon("res://assets/core/editor_icons/icn_utility.svg")
extends VBoxContainer
class_name UI_LocalizationSettingsTab

const U_LOCALIZATION_ACTIONS := preload("res://scripts/core/state/actions/u_localization_actions.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/core/state/selectors/u_localization_selectors.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/core/state/actions/u_navigation_actions.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/core/state/selectors/u_navigation_selectors.gd")
const W_SETTINGS_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/widgets/w_settings_focus_configurator.gd")
const U_SETTINGS_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_settings_tab_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const U_UI_SETTINGS_CATALOG := preload("res://scripts/core/ui/helpers/u_ui_settings_catalog.gd")
const DEFAULT_LOCALIZATION_INITIAL_STATE: Resource = preload("res://resources/core/base_settings/state/cfg_localization_initial_state.tres")

const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]
const LOCALE_LABEL_KEYS: Array[StringName] = [
	&"locale.name.en",
	&"locale.name.es",
	&"locale.name.pt",
	&"locale.name.zh_cn",
	&"locale.name.ja",
]
const LANGUAGE_CONFIRM_SECONDS := 10

var _state_store: I_StateStore = null
var _localization_manager: Node = null
var _unsubscribe: Callable = Callable()
var _updating_from_state: bool = false
var _has_local_edits: bool = false

var _language_confirm_active: bool = false
var _language_confirm_seconds_left: int = 0
var _pending_locale: StringName = &""
var _pre_change_locale: StringName = &""
var _pre_change_dyslexia: bool = false
var _builder: RefCounted = null

func _get_control_by_name(name: String) -> Control:
	return find_child(name, true, false) as Control

func _get_node_by_name(name: String) -> Node:
	return find_child(name, true, false)

func _get_language_option() -> OptionButton:
	return _get_control_by_name("LanguageOptionButton") as OptionButton

func _get_dyslexia_toggle() -> CheckBox:
	return _get_control_by_name("DyslexiaCheckButton") as CheckBox

func _get_apply_button() -> Button:
	return _get_control_by_name("ApplyButton") as Button

func _get_cancel_button() -> Button:
	return _get_control_by_name("CancelButton") as Button

func _get_reset_button() -> Button:
	return _get_control_by_name("ResetButton") as Button

func _get_language_confirm_dialog() -> Node:
	return _get_node_by_name("LanguageConfirmDialog")

func _get_language_confirm_timer() -> Node:
	return _get_control_by_name("LanguageConfirmTimer")

func _ready() -> void:
	_setup_builder()
	if _builder != null:
		_builder.build()
	_apply_theme_tokens()
	_populate_language_option()
	_connect_signals()
	_configure_focus_neighbors()
	_localize_labels()

	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		push_error("UI_LocalizationSettingsTab: StateStore not found")
		return

	_localization_manager = U_ServiceLocator.try_get_service(StringName("localization_manager"))

	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

func _setup_builder() -> void:
	_builder = U_UI_SETTINGS_CATALOG.create_localization_builder(
		self,
		_on_language_selected,
		_on_dyslexia_toggled,
		_on_apply_pressed,
		_on_cancel_pressed,
		_on_reset_pressed
	)
	if _builder != null:
		_builder.bind_theme_role(self, &"separation_default")

func _apply_theme_tokens() -> void:
	if _builder != null:
		_builder.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)

func _exit_tree() -> void:
	_stop_language_confirm_timer()
	_language_confirm_active = false
	_clear_localization_preview()
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()

func _enter_tree() -> void:
	if not is_node_ready():
		return
	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		return
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		return
	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

func _populate_language_option() -> void:
	if _get_language_option() == null:
		return
	var selected_index: int = _get_language_option().selected
	_get_language_option().set_block_signals(true)
	_get_language_option().clear()
	for i: int in SUPPORTED_LOCALES.size():
		var locale_label_key: StringName = LOCALE_LABEL_KEYS[i] if i < LOCALE_LABEL_KEYS.size() else StringName("")
		var display_name: String = str(SUPPORTED_LOCALES[i])
		if not locale_label_key.is_empty():
			display_name = U_LOCALIZATION_UTILS.localize(locale_label_key)
		_get_language_option().add_item(display_name)
	if selected_index >= 0 and selected_index < _get_language_option().item_count:
		_get_language_option().selected = selected_index
	_get_language_option().set_block_signals(false)

func _connect_signals() -> void:
	if _get_language_option() != null and not _get_language_option().item_selected.is_connected(_on_language_selected):
		_get_language_option().item_selected.connect(_on_language_selected)
	if _get_dyslexia_toggle() != null and not _get_dyslexia_toggle().toggled.is_connected(_on_dyslexia_toggled):
		_get_dyslexia_toggle().toggled.connect(_on_dyslexia_toggled)

	var confirm_dialog := _get_language_confirm_dialog()
	if confirm_dialog != null:
		_configure_language_confirm_dialog()
		if not confirm_dialog.confirmed.is_connected(_on_language_confirm_keep):
			confirm_dialog.confirmed.connect(_on_language_confirm_keep)
		if not confirm_dialog.canceled.is_connected(_on_language_confirm_revert):
			confirm_dialog.canceled.connect(_on_language_confirm_revert)
		if confirm_dialog.has_signal("close_requested"):
			if not confirm_dialog.close_requested.is_connected(_on_language_confirm_revert):
				confirm_dialog.close_requested.connect(_on_language_confirm_revert)
	var confirm_timer := _get_language_confirm_timer()
	if confirm_timer != null and not confirm_timer.timeout.is_connected(_on_language_confirm_timer_timeout):
		confirm_timer.timeout.connect(_on_language_confirm_timer_timeout)

	_setup_option_button_popup_focus(_get_language_option())

func _configure_focus_neighbors() -> void:
	var focusables: Array[Control] = []
	if _get_language_option() != null:
		focusables.append(_get_language_option())
	if _get_dyslexia_toggle() != null:
		focusables.append(_get_dyslexia_toggle())

	var buttons: Array[Control] = []
	if _get_cancel_button() != null:
		buttons.append(_get_cancel_button())
	if _get_reset_button() != null:
		buttons.append(_get_reset_button())
	if _get_apply_button() != null:
		buttons.append(_get_apply_button())

	# Combine all focusables for vertical wrapping
	for button: Control in buttons:
		focusables.append(button)

	W_SETTINGS_FOCUS_CONFIGURATOR.configure_vertical(self, [
		func() -> Control: return _get_language_option(),
		func() -> Control: return _get_dyslexia_toggle(),
		func() -> Control: return _get_cancel_button(),
		func() -> Control: return _get_reset_button(),
		func() -> Control: return _get_apply_button(),
	])

	W_SETTINGS_FOCUS_CONFIGURATOR.configure_horizontal(self, buttons, true)

func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return

	var action_type: StringName = StringName("")
	if action != null and action.has("type"):
		action_type = action.get("type", StringName(""))

	if (_has_local_edits or _language_confirm_active) and action_type != StringName(""):
		return

	_updating_from_state = true

	var locale: StringName = U_LOCALIZATION_SELECTORS.get_locale(state)
	var locale_index: int = SUPPORTED_LOCALES.find(locale)
	if locale_index < 0:
		locale_index = 0
	if _get_language_option() != null:
		_get_language_option().set_block_signals(true)
		_get_language_option().selected = locale_index
		_get_language_option().set_block_signals(false)

	var dyslexia: bool = U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state)
	_set_toggle_value_silently(_get_dyslexia_toggle(), dyslexia)

	_updating_from_state = false
	_has_local_edits = false

func _on_language_selected(_index: int) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_localization_preview_from_ui()

func _on_dyslexia_toggled(_pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_localization_preview_from_ui()

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	if _state_store == null:
		_clear_localization_preview()
		_close_overlay()
		return

	var locale := _get_selected_locale()
	var dyslexia := _get_dyslexia_value()
	var state := _state_store.get_state()
	var current_locale: StringName = U_LOCALIZATION_SELECTORS.get_locale(state)
	var current_dyslexia: bool = U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state)

	if locale != current_locale:
		_begin_language_confirm(locale, dyslexia, current_locale, current_dyslexia)
		return

	_has_local_edits = false
	_dispatch_localization_settings(locale, dyslexia)
	_clear_localization_preview()
	_close_overlay()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_has_local_edits = false
	_clear_localization_preview()
	_close_overlay()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var defaults := _get_default_localization_state()
	var default_locale := StringName(str(defaults.get("current_locale", &"en")))
	var default_dyslexia := bool(defaults.get("dyslexia_font_enabled", false))

	_updating_from_state = true
	var locale_index: int = SUPPORTED_LOCALES.find(default_locale)
	if locale_index < 0:
		locale_index = 0
	if _get_language_option() != null:
		_get_language_option().set_block_signals(true)
		_get_language_option().selected = locale_index
		_get_language_option().set_block_signals(false)
	_set_toggle_value_silently(_get_dyslexia_toggle(), default_dyslexia)
	_updating_from_state = false

	_has_local_edits = false
	_dispatch_localization_settings(default_locale, default_dyslexia)
	_clear_localization_preview()

# --- Language confirm dialog ---

func _begin_language_confirm(
	locale: StringName,
	dyslexia: bool,
	pre_locale: StringName,
	pre_dyslexia: bool
) -> void:
	_pending_locale = locale
	_pre_change_locale = pre_locale
	_pre_change_dyslexia = pre_dyslexia
	_language_confirm_active = true
	_language_confirm_seconds_left = LANGUAGE_CONFIRM_SECONDS
	_has_local_edits = false
	_update_localization_preview_from_ui()
	_dispatch_localization_settings(locale, dyslexia)
	_show_language_confirm_dialog()

func _show_language_confirm_dialog() -> void:
	var confirm_dialog := _get_language_confirm_dialog()
	if confirm_dialog == null:
		return
	_refresh_language_confirm_dialog_localization(true)
	confirm_dialog.popup_centered()
	_start_language_confirm_timer()
	var ok_button := _get_language_confirm_ok_button()
	if ok_button != null:
		ok_button.grab_focus()

func _start_language_confirm_timer() -> void:
	var confirm_timer := _get_language_confirm_timer()
	if confirm_timer == null:
		return
	confirm_timer.stop()
	confirm_timer.start()

func _stop_language_confirm_timer() -> void:
	var confirm_timer := _get_language_confirm_timer()
	if confirm_timer == null:
		return
	confirm_timer.stop()

func _update_language_confirm_text() -> void:
	var confirm_dialog := _get_language_confirm_dialog()
	if confirm_dialog == null:
		return
	var text_template: String = U_LOCALIZATION_UTILS.localize(&"settings.localization.confirm_text")
	confirm_dialog.dialog_text = text_template % _language_confirm_seconds_left

func _configure_language_confirm_dialog() -> void:
	var confirm_dialog := _get_language_confirm_dialog()
	if confirm_dialog == null:
		return
	var ok_button := _get_language_confirm_ok_button()
	if ok_button != null:
		ok_button.text = U_LOCALIZATION_UTILS.localize(&"common.keep")
	var cancel_button := _get_language_confirm_cancel_button()
	if cancel_button != null:
		cancel_button.text = U_LOCALIZATION_UTILS.localize(&"common.revert")

func _refresh_language_confirm_dialog_localization(update_countdown_text: bool) -> void:
	var confirm_dialog := _get_language_confirm_dialog()
	if confirm_dialog == null:
		return
	confirm_dialog.title = U_LOCALIZATION_UTILS.localize(&"settings.localization.confirm_title")
	_configure_language_confirm_dialog()
	if update_countdown_text:
		_update_language_confirm_text()

func _get_language_confirm_ok_button() -> Button:
	var dialog := _get_language_confirm_dialog()
	if dialog == null:
		return null
	if not dialog.has_method("get_ok_button"):
		return null
	return dialog.get_ok_button()

func _get_language_confirm_cancel_button() -> Button:
	var dialog := _get_language_confirm_dialog()
	if dialog == null:
		return null
	if not dialog.has_method("get_cancel_button"):
		return null
	return dialog.get_cancel_button()

func _on_language_confirm_timer_timeout() -> void:
	if not _language_confirm_active:
		return
	_language_confirm_seconds_left -= 1
	if _language_confirm_seconds_left <= 0:
		_on_language_confirm_revert()
		return
	_update_language_confirm_text()

func _on_language_confirm_keep() -> void:
	U_UISoundPlayer.play_confirm()
	_finalize_language_confirm(true)

func _on_language_confirm_revert() -> void:
	U_UISoundPlayer.play_cancel()
	_finalize_language_confirm(false)

func _finalize_language_confirm(keep_changes: bool) -> void:
	_stop_language_confirm_timer()
	_language_confirm_active = false
	var confirm_dialog := _get_language_confirm_dialog()
	if confirm_dialog != null and confirm_dialog.visible:
		confirm_dialog.hide()
	if keep_changes:
		_pending_locale = &""
		_clear_localization_preview()
		_close_overlay()
		return

	# Revert to pre-change locale
	_pending_locale = &""
	_clear_localization_preview()
	if _state_store != null:
		_dispatch_localization_settings(_pre_change_locale, _pre_change_dyslexia)
		_on_state_changed({}, _state_store.get_state())

# --- Preview mode ---

func _update_localization_preview_from_ui() -> void:
	if _localization_manager == null:
		_localization_manager = U_ServiceLocator.try_get_service(StringName("localization_manager"))
	if _localization_manager == null:
		return
	_localization_manager.set_localization_preview({
		"locale": _get_selected_locale(),
		"dyslexia_font_enabled": _get_dyslexia_value(),
	})

func _clear_localization_preview() -> void:
	if _localization_manager == null:
		_localization_manager = U_ServiceLocator.try_get_service(StringName("localization_manager"))
	if _localization_manager == null:
		return
	_localization_manager.clear_localization_preview()

# --- Dispatch ---

func _dispatch_localization_settings(locale: StringName, dyslexia: bool) -> void:
	if _state_store == null:
		return
	_state_store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(locale))
	_state_store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(dyslexia))

# --- Helpers ---

func _get_selected_locale() -> StringName:
	if _get_language_option() == null:
		return &"en"
	var idx := _get_language_option().selected
	if idx < 0 or idx >= SUPPORTED_LOCALES.size():
		return &"en"
	return SUPPORTED_LOCALES[idx]

func _get_dyslexia_value() -> bool:
	if _get_dyslexia_toggle() == null:
		return false
	return _get_dyslexia_toggle().button_pressed

func _set_toggle_value_silently(toggle: BaseButton, pressed: bool) -> void:
	if toggle == null:
		return
	toggle.set_block_signals(true)
	toggle.button_pressed = pressed
	toggle.set_block_signals(false)

func _close_overlay() -> void:
	if _state_store == null:
		return

	var nav_slice: Dictionary = _state_store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NAVIGATION_SELECTORS.get_overlay_stack(nav_slice)

	if not overlay_stack.is_empty():
		_state_store.dispatch(U_NAVIGATION_ACTIONS.close_top_overlay())
	else:
		_state_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(StringName("main_menu"), StringName("settings_panel")))

func _get_default_localization_state() -> Dictionary:
	if DEFAULT_LOCALIZATION_INITIAL_STATE != null:
		var instance := DEFAULT_LOCALIZATION_INITIAL_STATE.duplicate(true)
		if instance is RS_LocalizationInitialState:
			return (instance as RS_LocalizationInitialState).to_dictionary()
	return RS_LocalizationInitialState.new().to_dictionary()

func _setup_option_button_popup_focus(option_button: OptionButton) -> void:
	if option_button == null:
		return
	var popup := option_button.get_popup()
	if popup == null:
		return
	if not popup.about_to_popup.is_connected(_on_option_button_popup_about_to_show.bind(popup)):
		popup.about_to_popup.connect(_on_option_button_popup_about_to_show.bind(popup))

func _on_option_button_popup_about_to_show(popup: PopupMenu) -> void:
	if popup == null:
		return
	await get_tree().process_frame
	popup.grab_focus()

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
	if _state_store != null and not _has_local_edits and not _language_confirm_active:
		_on_state_changed({}, _state_store.get_state())

func _localize_labels() -> void:
	_populate_language_option()
	if _builder != null:
		_builder.localize_labels()
	_refresh_language_confirm_dialog_localization(_language_confirm_active)
