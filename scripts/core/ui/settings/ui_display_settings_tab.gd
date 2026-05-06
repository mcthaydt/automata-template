@icon("res://assets/core/editor_icons/icn_utility.svg")
extends VBoxContainer
class_name UI_DisplaySettingsTab

const DEFAULT_DISPLAY_INITIAL_STATE: Resource = preload("res://resources/core/base_settings/state/cfg_display_initial_state.tres")
const WINDOW_CONFIRM_SECONDS := 10
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_SETTINGS_CATALOG := preload("res://scripts/core/ui/helpers/u_ui_settings_catalog.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")

const TITLE_KEY := &"settings.display.title"
const SECTION_GRAPHICS_KEY := &"settings.display.section.graphics"
const SECTION_POST_PROCESSING_KEY := &"settings.display.section.post_processing"
const SECTION_UI_KEY := &"settings.display.section.ui"
const SECTION_ACCESSIBILITY_KEY := &"settings.display.section.accessibility"

const LABEL_WINDOW_SIZE_KEY := &"settings.display.label.window_size"
const LABEL_WINDOW_MODE_KEY := &"settings.display.label.window_mode"
const LABEL_VSYNC_KEY := &"settings.display.label.vsync"
const LABEL_QUALITY_PRESET_KEY := &"settings.display.label.quality_preset"
const LABEL_POST_PROCESSING_KEY := &"settings.display.label.post_processing"
const LABEL_POST_PROCESSING_PRESET_KEY := &"settings.display.label.post_processing_preset"
const LABEL_UI_SCALE_KEY := &"settings.display.label.ui_scale"
const LABEL_COLOR_BLIND_MODE_KEY := &"settings.display.label.color_blind_mode"
const LABEL_HIGH_CONTRAST_KEY := &"settings.display.label.high_contrast"

const TOOLTIP_WINDOW_SIZE_KEY := &"settings.display.tooltip.window_size"
const TOOLTIP_WINDOW_MODE_KEY := &"settings.display.tooltip.window_mode"
const TOOLTIP_POST_PROCESSING_PRESET_KEY := &"settings.display.tooltip.post_processing_preset"
const TOOLTIP_UI_SCALE_KEY := &"settings.display.tooltip.ui_scale"

const DIALOG_WINDOW_CONFIRM_TITLE_KEY := &"settings.display.dialog.confirm_title"
const DIALOG_WINDOW_CONFIRM_TEXT_KEY := &"settings.display.dialog.confirm_text"

const ENABLED_ROW_MODULATE := Color(1, 1, 1, 1)
const DISABLED_ROW_MODULATE := Color(1, 1, 1, 0.45)

var _state_store: I_StateStore = null
var _display_manager: I_DisplayManager = null
var _unsubscribe: Callable = Callable()
var _updating_from_state: bool = false
var _has_local_edits: bool = false
var _window_confirm_active: bool = false
var _window_confirm_seconds_left: int = 0
var _pending_window_settings: Dictionary = {}
var _builder: RefCounted = null

var _window_size_values: Array[String] = []
var _window_mode_values: Array[String] = []
var _quality_preset_values: Array[String] = []
var _post_processing_preset_values: Array[String] = []
var _color_blind_mode_values: Array[String] = []

func _get_control_by_name(name: String) -> Control:
	return find_child(name, true, false) as Control

func _get_node_by_name(name: String) -> Node:
	return find_child(name, true, false)

func _get_window_size_option() -> OptionButton:
	return _get_control_by_name("WindowSizeOption") as OptionButton

func _get_window_mode_option() -> OptionButton:
	return _get_control_by_name("WindowModeOption") as OptionButton

func _get_vsync_toggle() -> CheckBox:
	return _get_control_by_name("VSyncToggle") as CheckBox

func _get_quality_preset_option() -> OptionButton:
	return _get_control_by_name("QualityPresetOption") as OptionButton

func _get_post_processing_toggle() -> CheckBox:
	return _get_control_by_name("PostProcessingToggle") as CheckBox

func _get_post_processing_preset_option() -> OptionButton:
	return _get_control_by_name("PostProcessPresetOption") as OptionButton

func _get_ui_scale_slider() -> HSlider:
	return _get_control_by_name("UIScaleSlider") as HSlider

func _get_ui_scale_value() -> Label:
	return _get_control_by_name("UIScaleSliderValue") as Label

func _get_color_blind_mode_option() -> OptionButton:
	return _get_control_by_name("ColorBlindModeOption") as OptionButton

func _get_high_contrast_toggle() -> CheckBox:
	return _get_control_by_name("HighContrastToggle") as CheckBox

func _get_cancel_button() -> Button:
	return _get_control_by_name("CancelButton") as Button

func _get_reset_button() -> Button:
	return _get_control_by_name("ResetButton") as Button

func _get_apply_button() -> Button:
	return _get_control_by_name("ApplyButton") as Button

func _get_window_confirm_dialog() -> Node:
	return _get_node_by_name("WindowConfirmDialog")

func _get_window_confirm_timer():
	return _get_control_by_name("WindowConfirmTimer")

func _get_heading_label() -> Label:
	return _get_control_by_name("HeadingLabel") as Label

func _get_content_margin() -> MarginContainer:
	var scroll := find_child("Scroll", true, false) as ScrollContainer
	if scroll != null:
		return scroll.find_child("ContentMargin", true, false) as MarginContainer
	return null

func _get_graphics_header() -> Label:
	return _get_control_by_name("GraphicsHeader") as Label

func _get_post_processing_header() -> Label:
	return _get_control_by_name("PostProcessingHeader") as Label

func _get_ui_header() -> Label:
	return _get_control_by_name("UIHeader") as Label

func _get_accessibility_header() -> Label:
	return _get_control_by_name("AccessibilityHeader") as Label

func _ready() -> void:
	_setup_builder()
	_hide_desktop_only_controls_on_mobile()
	if _builder != null:
		_builder.build()
	_configure_focus_neighbors()
	set_meta(&"settings_builder", true)

	_state_store = U_StateUtils.get_store(self)
	if _state_store == null:
		push_error("UI_DisplaySettingsTab: StateStore not found")
		return

	_display_manager = U_DisplayUtils.get_display_manager()

	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())
	_connect_window_confirm_signals()

func _setup_builder() -> void:
	_display_manager = U_DisplayUtils.get_display_manager()
	
	_builder = U_UI_SETTINGS_CATALOG.create_display_builder(
		self,
		_on_window_size_selected,
		_on_window_mode_selected,
		_on_vsync_toggled,
		_on_quality_preset_selected,
		_on_post_processing_toggled,
		_on_post_processing_preset_selected,
		_on_ui_scale_changed,
		_on_color_blind_mode_selected,
		_on_high_contrast_toggled,
		_on_apply_pressed,
		_on_cancel_pressed,
		_on_reset_pressed
	)
	
	_populate_value_arrays()
	_configure_tooltips_via_builder()
	_apply_builder_margin_tokens()

func _exit_tree() -> void:
	_stop_window_confirm_timer()
	_window_confirm_active = false
	_clear_display_settings_preview()
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()

func _enter_tree() -> void:
	if not is_node_ready():
		return
	_state_store = U_StateUtils.get_store(self)
	if _state_store == null:
		return
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		return
	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

func _connect_window_confirm_signals() -> void:
	var window_confirm_dialog: ConfirmationDialog = _get_window_confirm_dialog()
	if window_confirm_dialog != null:
		_configure_window_confirm_dialog()
		if not window_confirm_dialog.confirmed.is_connected(_on_window_confirm_keep):
			window_confirm_dialog.confirmed.connect(_on_window_confirm_keep)
		if not window_confirm_dialog.canceled.is_connected(_on_window_confirm_revert):
			window_confirm_dialog.canceled.connect(_on_window_confirm_revert)
		if window_confirm_dialog.has_signal("close_requested"):
			if not window_confirm_dialog.close_requested.is_connected(_on_window_confirm_revert):
				window_confirm_dialog.close_requested.connect(_on_window_confirm_revert)
	var window_confirm_timer: Timer = _get_window_confirm_timer()
	if window_confirm_timer != null and not window_confirm_timer.timeout.is_connected(_on_window_confirm_timer_timeout):
		window_confirm_timer.timeout.connect(_on_window_confirm_timer_timeout)

func _populate_value_arrays() -> void:
	for option in U_UI_SETTINGS_CATALOG.get_window_sizes():
		_window_size_values.append(str(option.get("id", "")))
	for option in U_UI_SETTINGS_CATALOG.get_window_modes():
		_window_mode_values.append(str(option.get("id", "")))
	for option in U_UI_SETTINGS_CATALOG.get_quality_presets():
		_quality_preset_values.append(str(option.get("id", "")))
	for option in U_DisplayOptionCatalog.get_post_processing_preset_option_entries():
		_post_processing_preset_values.append(str(option.get("id", "")))
	for option in U_DisplayOptionCatalog.get_color_blind_mode_option_entries():
		_color_blind_mode_values.append(str(option.get("id", "")))

func _populate_option_buttons() -> void:
	_populate_option_button(
		_get_window_size_option(),
		U_UI_SETTINGS_CATALOG.get_window_sizes(),
		_window_size_values
	)
	_populate_option_button(
		_get_window_mode_option(),
		U_UI_SETTINGS_CATALOG.get_window_modes(),
		_window_mode_values
	)
	_populate_option_button(
		_get_quality_preset_option(),
		U_UI_SETTINGS_CATALOG.get_quality_presets(),
		_quality_preset_values
	)
	_populate_option_button(
		_get_post_processing_preset_option(),
		U_DisplayOptionCatalog.get_post_processing_preset_option_entries(),
		_post_processing_preset_values
	)
	_populate_option_button(
		_get_color_blind_mode_option(),
		U_DisplayOptionCatalog.get_color_blind_mode_option_entries(),
		_color_blind_mode_values
	)

func _populate_option_button(button: OptionButton, options: Array, values: Array[String]) -> void:
	if button == null:
		return
	button.clear()
	values.clear()
	for option in options:
		if option is Dictionary:
			var entry := option as Dictionary
			var fallback: String = str(entry.get("label", str(entry.get("id", ""))))
			var label := U_LOCALIZATION_UTILS.localize_with_fallback(entry.get("label_key", &""), fallback)
			var value := str(entry.get("id", ""))
			if label.is_empty():
				label = value
			button.add_item(label)
			values.append(value)

func _configure_tooltips_via_builder() -> void:
	if _builder == null:
		return
	_builder.set_tooltip(
		&"settings.display.label.window_size",
		U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_WINDOW_SIZE_KEY, "Available only in Windowed mode.")
	)
	_builder.set_tooltip(
		&"settings.display.label.window_mode",
		U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_WINDOW_MODE_KEY, "Borderless fills the screen without changing display mode.")
	)
	_builder.set_tooltip(
		&"settings.display.label.post_processing_preset",
		U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_POST_PROCESSING_PRESET_KEY, "Intensity level for post-processing effects (Film Grain, Dither).")
	)
	_builder.set_tooltip(
		&"settings.display.label.ui_scale",
		U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_UI_SCALE_KEY, "Scales the UI size.")
	)

func _apply_builder_margin_tokens() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if not (config_resource is RS_UI_THEME_CONFIG):
		return
	var config := config_resource as RS_UI_THEME_CONFIG
	var content_margin := _get_content_margin()
	if content_margin == null:
		return
	content_margin.add_theme_constant_override(&"margin_left", config.margin_section)
	content_margin.add_theme_constant_override(&"margin_top", config.margin_section)
	content_margin.add_theme_constant_override(&"margin_right", config.margin_section)
	content_margin.add_theme_constant_override(&"margin_bottom", config.margin_section)

func _hide_desktop_only_controls_on_mobile() -> void:
	if not OS.has_feature("mobile"):
		return
	if _builder == null:
		return
	_builder.hide_control_by_key(&"settings.display.label.window_size")
	_builder.hide_control_by_key(&"settings.display.label.window_mode")
	_builder.hide_control_by_key(&"settings.display.label.vsync")

func _update_dependent_controls() -> void:
	var defaults := _get_default_display_state()
	var window_mode := _get_selected_value(_get_window_mode_option(), _window_mode_values, defaults.window_mode)
	var windowed := window_mode == "windowed"
	_set_control_group_enabled(_get_window_size_option(), windowed)

	var post_processing_enabled := _get_toggle_value(_get_post_processing_toggle(), defaults.post_processing_enabled)
	_set_control_group_enabled(_get_post_processing_preset_option(), post_processing_enabled)

func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return

	var action_type: StringName = StringName("")
	if action != null and action.has("type"):
		action_type = action.get("type", StringName(""))

	# Preserve local edits (Apply/Cancel pattern). Only reconcile from state when
	# the user is not actively editing.
	if (_has_local_edits or _window_confirm_active) and action_type != StringName(""):
		return

	_updating_from_state = true

	_select_option_value(_get_window_size_option(), _window_size_values, U_DisplaySelectors.get_window_size_preset(state))
	_select_option_value(_get_window_mode_option(), _window_mode_values, U_DisplaySelectors.get_window_mode(state))
	_set_toggle_value_silently(_get_vsync_toggle(), U_DisplaySelectors.is_vsync_enabled(state))
	_select_option_value(_get_quality_preset_option(), _quality_preset_values, U_DisplaySelectors.get_quality_preset(state))

	_set_toggle_value_silently(_get_post_processing_toggle(), U_DisplaySelectors.is_post_processing_enabled(state))
	_select_option_value(_get_post_processing_preset_option(), _post_processing_preset_values, U_DisplaySelectors.get_post_processing_preset(state))

	var ui_scale := U_DisplaySelectors.get_ui_scale(state)
	_set_slider_value_silently(_get_ui_scale_slider(), ui_scale)
	_update_scale_label(_get_ui_scale_value(), ui_scale)

	_select_option_value(_get_color_blind_mode_option(), _color_blind_mode_values, U_DisplaySelectors.get_color_blind_mode(state))
	_set_toggle_value_silently(_get_high_contrast_toggle(), U_DisplaySelectors.is_high_contrast_enabled(state))

	_updating_from_state = false
	_update_dependent_controls()
	_has_local_edits = false

func _on_window_size_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _window_size_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_window_mode_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _window_mode_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_vsync_toggled(_pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_quality_preset_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _quality_preset_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_post_processing_toggled(_pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_post_processing_preset_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _post_processing_preset_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_ui_scale_changed(value: float) -> void:
	_update_scale_label(_get_ui_scale_value(), value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_color_blind_mode_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _color_blind_mode_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_high_contrast_toggled(_pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var defaults := _get_default_display_state()

	_updating_from_state = true
	_select_option_value(_get_window_size_option(), _window_size_values, defaults.window_size_preset)
	_select_option_value(_get_window_mode_option(), _window_mode_values, defaults.window_mode)
	_set_toggle_value_silently(_get_vsync_toggle(), defaults.vsync_enabled)
	_select_option_value(_get_quality_preset_option(), _quality_preset_values, defaults.quality_preset)

	_set_toggle_value_silently(_get_post_processing_toggle(), defaults.post_processing_enabled)
	_select_option_value(_get_post_processing_preset_option(), _post_processing_preset_values, defaults.post_processing_preset)

	_set_slider_value_silently(_get_ui_scale_slider(), defaults.ui_scale)
	_update_scale_label(_get_ui_scale_value(), defaults.ui_scale)

	_select_option_value(_get_color_blind_mode_option(), _color_blind_mode_values, defaults.color_blind_mode)
	_set_toggle_value_silently(_get_high_contrast_toggle(), defaults.high_contrast_enabled)

	_updating_from_state = false
	_update_dependent_controls()

	_has_local_edits = false
	_dispatch_display_settings(defaults)
	_clear_display_settings_preview()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_has_local_edits = false
	_clear_display_settings_preview()
	_close_overlay()

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var settings := _get_display_settings_from_ui()
	if _state_store == null:
		return
	var state := _state_store.get_state()
	if _requires_window_confirmation(settings, state):
		_begin_window_confirm(settings)
		return
	_has_local_edits = false
	_dispatch_display_settings(settings)
	_clear_display_settings_preview()
	_close_overlay()

func _close_overlay() -> void:
	if _state_store == null:
		return

	var nav_slice: Dictionary = _state_store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)

	if not overlay_stack.is_empty():
		_state_store.dispatch(U_NavigationActions.close_top_overlay())
	else:
			_state_store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_panel")))

func _update_display_settings_preview_from_ui() -> void:
	_update_dependent_controls()
	if _display_manager == null:
		_display_manager = U_DisplayUtils.get_display_manager()
	if _display_manager == null:
		return
	_display_manager.set_display_settings_preview(_get_display_settings_from_ui())

func _clear_display_settings_preview() -> void:
	if _display_manager == null:
		_display_manager = U_DisplayUtils.get_display_manager()
	if _display_manager == null:
		return
	_display_manager.clear_display_settings_preview()

func _dispatch_display_settings(settings: Variant, skip_window_actions: bool = false) -> void:
	if _state_store == null:
		return
	var values: Dictionary = {}
	if settings is RS_DisplayInitialState:
		values = (settings as RS_DisplayInitialState).to_dictionary()
	elif settings is Dictionary:
		values = settings as Dictionary
	else:
		return

	if not skip_window_actions:
		_state_store.dispatch(U_DisplayActions.set_window_size_preset(str(values.get("window_size_preset", ""))))
		_state_store.dispatch(U_DisplayActions.set_window_mode(str(values.get("window_mode", ""))))
	_state_store.dispatch(U_DisplayActions.set_vsync_enabled(bool(values.get("vsync_enabled", true))))
	_state_store.dispatch(U_DisplayActions.set_quality_preset(str(values.get("quality_preset", ""))))
	_state_store.dispatch(U_DisplayActions.set_post_processing_enabled(bool(values.get("post_processing_enabled", false))))
	_state_store.dispatch(U_DisplayActions.set_post_processing_preset(str(values.get("post_processing_preset", ""))))
	_state_store.dispatch(U_DisplayActions.set_ui_scale(float(values.get("ui_scale", 1.0))))
	_state_store.dispatch(U_DisplayActions.set_color_blind_mode(str(values.get("color_blind_mode", ""))))
	_state_store.dispatch(U_DisplayActions.set_high_contrast_enabled(bool(values.get("high_contrast_enabled", false))))

func _dispatch_window_settings(values: Dictionary) -> void:
	if _state_store == null:
		return
	_state_store.dispatch(U_DisplayActions.set_window_size_preset(str(values.get("window_size_preset", ""))))
	_state_store.dispatch(U_DisplayActions.set_window_mode(str(values.get("window_mode", ""))))

func _requires_window_confirmation(settings: Dictionary, state: Dictionary) -> bool:
	if state == null:
		return false
	var current_size := U_DisplaySelectors.get_window_size_preset(state)
	var current_mode := U_DisplaySelectors.get_window_mode(state)
	var next_size := str(settings.get("window_size_preset", ""))
	var next_mode := str(settings.get("window_mode", ""))
	return next_size != current_size or next_mode != current_mode

func _begin_window_confirm(settings: Dictionary) -> void:
	_pending_window_settings = {
		"window_size_preset": str(settings.get("window_size_preset", "")),
		"window_mode": str(settings.get("window_mode", "")),
	}
	_window_confirm_active = true
	_window_confirm_seconds_left = WINDOW_CONFIRM_SECONDS
	_has_local_edits = false
	_dispatch_display_settings(settings, true)
	_show_window_confirm_dialog()

func _show_window_confirm_dialog() -> void:
	var window_confirm_dialog: ConfirmationDialog = _get_window_confirm_dialog()
	if window_confirm_dialog == null:
		return
	_update_window_confirm_text()
	window_confirm_dialog.popup_centered()
	_start_window_confirm_timer()
	var ok_button: Button = _get_window_confirm_ok_button()
	if ok_button != null:
		ok_button.grab_focus()

func _start_window_confirm_timer() -> void:
	var window_confirm_timer: Timer = _get_window_confirm_timer()
	if window_confirm_timer == null:
		return
	window_confirm_timer.stop()
	window_confirm_timer.start()

func _stop_window_confirm_timer() -> void:
	var window_confirm_timer: Timer = _get_window_confirm_timer()
	if window_confirm_timer == null:
		return
	window_confirm_timer.stop()

func _update_window_confirm_text() -> void:
	var window_confirm_dialog: ConfirmationDialog = _get_window_confirm_dialog()
	if window_confirm_dialog == null:
		return
	var confirm_template := U_LOCALIZATION_UTILS.localize_with_fallback(
		DIALOG_WINDOW_CONFIRM_TEXT_KEY,
		"Keep these display changes? Reverting in %ds."
	)
	window_confirm_dialog.dialog_text = confirm_template % _window_confirm_seconds_left

func _configure_window_confirm_dialog() -> void:
	var window_confirm_dialog: ConfirmationDialog = _get_window_confirm_dialog()
	if window_confirm_dialog == null:
		return
	window_confirm_dialog.title = U_LOCALIZATION_UTILS.localize_with_fallback(DIALOG_WINDOW_CONFIRM_TITLE_KEY, "Confirm Display Changes")
	var ok_button: Button = _get_window_confirm_ok_button()
	if ok_button != null:
		ok_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.keep", "Keep")
	var cancel_button: Button = _get_window_confirm_cancel_button()
	if cancel_button != null:
		cancel_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.revert", "Revert")

func _get_window_confirm_ok_button() -> Button:
	var window_confirm_dialog: ConfirmationDialog = _get_window_confirm_dialog()
	if window_confirm_dialog == null:
		return null
	if not window_confirm_dialog.has_method("get_ok_button"):
		return null
	return window_confirm_dialog.get_ok_button()

func _get_window_confirm_cancel_button() -> Button:
	var window_confirm_dialog: ConfirmationDialog = _get_window_confirm_dialog()
	if window_confirm_dialog == null:
		return null
	if not window_confirm_dialog.has_method("get_cancel_button"):
		return null
	return window_confirm_dialog.get_cancel_button()

func _on_window_confirm_timer_timeout() -> void:
	if not _window_confirm_active:
		return
	_window_confirm_seconds_left -= 1
	if _window_confirm_seconds_left <= 0:
		_on_window_confirm_revert()
		return
	_update_window_confirm_text()

func _on_window_confirm_keep() -> void:
	U_UISoundPlayer.play_confirm()
	_finalize_window_confirm(true)

func _on_window_confirm_revert() -> void:
	U_UISoundPlayer.play_cancel()
	_finalize_window_confirm(false)

func _finalize_window_confirm(keep_changes: bool) -> void:
	_stop_window_confirm_timer()
	_window_confirm_active = false
	var window_confirm_dialog: ConfirmationDialog = _get_window_confirm_dialog()
	if window_confirm_dialog != null and window_confirm_dialog.visible:
		window_confirm_dialog.hide()
	if keep_changes:
		_dispatch_window_settings(_pending_window_settings)
		_pending_window_settings.clear()
		_clear_display_settings_preview()
		_close_overlay()
		return

	_pending_window_settings.clear()
	_clear_display_settings_preview()
	if _state_store != null:
		_on_state_changed({}, _state_store.get_state())

func _get_display_settings_from_ui() -> Dictionary:
	var defaults: Dictionary = _get_default_display_state()
	return {
		"window_size_preset": _get_selected_value(_get_window_size_option(), _window_size_values, defaults.get("window_size_preset", "1920x1080")),
		"window_mode": _get_selected_value(_get_window_mode_option(), _window_mode_values, defaults.get("window_mode", "windowed")),
		"vsync_enabled": _get_toggle_value(_get_vsync_toggle(), defaults.get("vsync_enabled", true)),
		"quality_preset": _get_selected_value(_get_quality_preset_option(), _quality_preset_values, defaults.get("quality_preset", "high")),
		"post_processing_enabled": _get_toggle_value(_get_post_processing_toggle(), defaults.get("post_processing_enabled", false)),
		"post_processing_preset": _get_selected_value(_get_post_processing_preset_option(), _post_processing_preset_values, defaults.get("post_processing_preset", "medium")),
		"ui_scale": _get_slider_value(_get_ui_scale_slider(), defaults.get("ui_scale", 1.0)),
		"color_blind_mode": _get_selected_value(_get_color_blind_mode_option(), _color_blind_mode_values, defaults.get("color_blind_mode", "normal")),
		"high_contrast_enabled": _get_toggle_value(_get_high_contrast_toggle(), defaults.get("high_contrast_enabled", false)),
	}

func _get_selected_value(button: OptionButton, values: Array[String], fallback: String) -> String:
	if values.is_empty():
		return fallback
	if button == null:
		return fallback if not fallback.is_empty() else values[0]
	var idx := button.selected
	if idx < 0 or idx >= values.size():
		idx = 0
	return values[idx]

func _get_slider_value(slider: HSlider, fallback: float) -> float:
	if slider == null:
		return fallback
	return slider.value

func _get_toggle_value(toggle: BaseButton, fallback: bool) -> bool:
	if toggle == null:
		return fallback
	return toggle.button_pressed

func _set_slider_value_silently(slider: HSlider, value: float) -> void:
	if slider == null:
		return
	slider.set_block_signals(true)
	slider.value = value
	slider.set_block_signals(false)

func _set_toggle_value_silently(toggle: BaseButton, pressed: bool) -> void:
	if toggle == null:
		return
	toggle.set_block_signals(true)
	toggle.button_pressed = pressed
	toggle.set_block_signals(false)

func _set_control_group_enabled(control: Control, enabled: bool) -> void:
	if control == null:
		return
	if "disabled" in control:
		control.disabled = not enabled
	control.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	var row := control.get_parent()
	if row is Control:
		(row as Control).modulate = ENABLED_ROW_MODULATE if enabled else DISABLED_ROW_MODULATE

func _select_option_value(button: OptionButton, values: Array[String], value: String) -> void:
	if button == null:
		return
	var idx := values.find(value)
	if idx < 0:
		idx = 0
	button.set_block_signals(true)
	button.select(idx)
	button.set_block_signals(false)

func _update_scale_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%d%%" % int(value * 100.0)

func _get_default_display_state() -> Dictionary:
	if DEFAULT_DISPLAY_INITIAL_STATE != null:
		var instance := DEFAULT_DISPLAY_INITIAL_STATE.duplicate(true)
		if instance is RS_DisplayInitialState:
			return (instance as RS_DisplayInitialState).to_dictionary()
	return RS_DisplayInitialState.new().to_dictionary()

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
	if _state_store != null and not _has_local_edits and not _window_confirm_active:
		_on_state_changed({}, _state_store.get_state())

func _localize_labels() -> void:
	_relocalize_option_buttons()
	_configure_tooltips_via_builder()
	if _builder != null:
		_builder.localize_labels()

	var cancel_button := _get_cancel_button()
	if cancel_button != null:
		cancel_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.cancel", "Cancel")
	var reset_button := _get_reset_button()
	if reset_button != null:
		reset_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.reset", "Reset")
	var apply_button := _get_apply_button()
	if apply_button != null:
		apply_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.apply", "Apply")

	var window_confirm_dialog: ConfirmationDialog = _get_window_confirm_dialog()
	if window_confirm_dialog != null:
		window_confirm_dialog.title = U_LOCALIZATION_UTILS.localize_with_fallback(DIALOG_WINDOW_CONFIRM_TITLE_KEY, "Confirm Display Changes")
		_configure_window_confirm_dialog()
		if _window_confirm_active:
			_update_window_confirm_text()

func _relocalize_option_buttons() -> void:
	var defaults := _get_default_display_state()
	var window_size_value: String = _get_selected_value(
		_get_window_size_option(),
		_window_size_values,
		str(defaults.get("window_size_preset", "1920x1080"))
	)
	var window_mode_value: String = _get_selected_value(
		_get_window_mode_option(),
		_window_mode_values,
		str(defaults.get("window_mode", "windowed"))
	)
	var quality_value: String = _get_selected_value(
		_get_quality_preset_option(),
		_quality_preset_values,
		str(defaults.get("quality_preset", "high"))
	)
	var post_processing_value: String = _get_selected_value(
		_get_post_processing_preset_option(),
		_post_processing_preset_values,
		str(defaults.get("post_processing_preset", "medium"))
	)
	var color_blind_value: String = _get_selected_value(
		_get_color_blind_mode_option(),
		_color_blind_mode_values,
		str(defaults.get("color_blind_mode", "normal"))
	)

	_populate_option_buttons()
	_select_option_value(_get_window_size_option(), _window_size_values, window_size_value)
	_select_option_value(_get_window_mode_option(), _window_mode_values, window_mode_value)
	_select_option_value(_get_quality_preset_option(), _quality_preset_values, quality_value)
	_select_option_value(_get_post_processing_preset_option(), _post_processing_preset_values, post_processing_value)
	_select_option_value(_get_color_blind_mode_option(), _color_blind_mode_values, color_blind_value)

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

func _configure_focus_neighbors() -> void:
	var vertical_controls: Array[Control] = [
		_get_window_size_option(),
		_get_window_mode_option(),
		_get_vsync_toggle(),
		_get_quality_preset_option(),
		_get_post_processing_toggle(),
		_get_post_processing_preset_option(),
		_get_ui_scale_slider(),
		_get_color_blind_mode_option(),
		_get_high_contrast_toggle(),
		_get_cancel_button(),
		_get_apply_button(),
		_get_reset_button(),
	]
	var visible_controls: Array[Control] = []
	for control: Control in vertical_controls:
		if control != null and control.focus_mode != Control.FOCUS_NONE and control.visible:
			visible_controls.append(control)
	if not visible_controls.is_empty():
		U_FOCUS_CONFIGURATOR.configure_vertical_focus(visible_controls)

	var pairs: Array = [
		[_get_window_size_option(), _get_window_mode_option()],
		[_get_vsync_toggle(), _get_quality_preset_option()],
		[_get_post_processing_toggle(), _get_post_processing_preset_option()],
	]
	for pair in pairs:
		var left: Control = pair[0]
		var right: Control = pair[1]
		if left != null and right != null:
			left.focus_neighbor_right = left.get_path_to(right)
			right.focus_neighbor_left = right.get_path_to(left)
