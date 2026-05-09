@icon("res://assets/core/editor_icons/icn_utility.svg")
extends VBoxContainer
class_name UI_TouchscreenSettingsTab

const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_SETTINGS_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_settings_tab_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_INPUT_ACTIONS := preload("res://scripts/core/state/actions/u_input_actions.gd")
const U_INPUT_SELECTORS := preload("res://scripts/core/state/selectors/u_input_selectors.gd")
const RS_TOUCHSCREEN_SETTINGS := preload("res://scripts/core/resources/input/rs_touchscreen_settings.gd")
const W_SETTINGS_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/widgets/w_settings_focus_configurator.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/core/state/actions/u_navigation_actions.gd")
const I_INPUT_PROFILE_MANAGER := preload("res://scripts/core/interfaces/i_input_profile_manager.gd")
const U_TOUCHSCREEN_PREVIEW_HELPER := preload("res://scripts/core/ui/helpers/u_touchscreen_preview_helper.gd")
const VirtualJoystickScene := preload("res://scenes/core/ui/widgets/ui_virtual_joystick.tscn")
const VirtualButtonScene := preload("res://scenes/core/ui/widgets/ui_virtual_button.tscn")

const TITLE_KEY := &"settings.touchscreen.title"
const LABEL_JOYSTICK_SIZE_KEY := &"settings.touchscreen.label.joystick_size"
const LABEL_BUTTON_SIZE_KEY := &"settings.touchscreen.label.button_size"
const LABEL_JOYSTICK_OPACITY_KEY := &"settings.touchscreen.label.joystick_opacity"
const LABEL_BUTTON_OPACITY_KEY := &"settings.touchscreen.label.button_opacity"
const LABEL_JOYSTICK_DEADZONE_KEY := &"settings.touchscreen.label.joystick_deadzone"
const LABEL_LOOK_SENSITIVITY_KEY := &"settings.touchscreen.label.look_sensitivity"
const BUTTON_EDIT_LAYOUT_KEY := &"settings.touchscreen.button.edit_layout"
const BUTTON_RESET_DEFAULTS_KEY := &"settings.touchscreen.button.reset_defaults"

const TOOLTIP_JOYSTICK_SIZE_KEY := &"settings.touchscreen.tooltip.joystick_size"
const TOOLTIP_BUTTON_SIZE_KEY := &"settings.touchscreen.tooltip.button_size"
const TOOLTIP_JOYSTICK_OPACITY_KEY := &"settings.touchscreen.tooltip.joystick_opacity"
const TOOLTIP_BUTTON_OPACITY_KEY := &"settings.touchscreen.tooltip.button_opacity"
const TOOLTIP_JOYSTICK_DEADZONE_KEY := &"settings.touchscreen.tooltip.joystick_deadzone"
const TOOLTIP_LOOK_SENSITIVITY_KEY := &"settings.touchscreen.tooltip.look_sensitivity"
const TOOLTIP_PREVIEW_KEY := &"settings.touchscreen.tooltip.preview"
const TOOLTIP_EDIT_LAYOUT_KEY := &"settings.touchscreen.tooltip.edit_layout"

const INPUT_PROFILE_MANAGER_SERVICE := StringName("input_profile_manager")

const DEFAULTS := preload("res://resources/core/input/touchscreen_settings/cfg_default_touchscreen_settings.tres")

var _state_store: I_StateStore = null
var _unsubscribe: Callable = Callable()
var _updating_from_state: bool = false
var _builder: RefCounted = null
var _profile_manager: Node = null
var _preview_builder := U_TouchscreenPreviewHelper.new()
var _preview_joystick: Control = null
var _preview_buttons: Array[Control] = []

var _joystick_size_slider: HSlider
var _joystick_size_value_label: Label
var _button_size_slider: HSlider
var _button_size_value_label: Label
var _joystick_opacity_slider: HSlider
var _joystick_opacity_value_label: Label
var _button_opacity_slider: HSlider
var _button_opacity_value_label: Label
var _joystick_deadzone_slider: HSlider
var _joystick_deadzone_value_label: Label
var _look_sensitivity_slider: HSlider
var _look_sensitivity_value_label: Label
var _reset_button: Button
var _edit_layout_button: Button
var _preview_container: Control

func _ready() -> void:
	_setup_builder()
	if _builder != null:
		_builder.build()
	_capture_control_references()
	_configure_focus_neighbors()
	_configure_tooltips()
	_build_preview()
	_connect_signals()
	set_meta(&"settings_builder", true)

	_profile_manager = _resolve_input_profile_manager()

	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		push_error("UI_TouchscreenSettingsTab: StateStore not found")
		return

	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

	_update_edit_layout_visibility()
	visibility_changed.connect(_on_visibility_changed)

func _setup_builder() -> void:
	_builder = U_SETTINGS_TAB_BUILDER.new(self)
	_builder.bind_theme_role(self, &"separation_default")
	_builder.set_heading(TITLE_KEY)
	_builder.add_slider(LABEL_JOYSTICK_SIZE_KEY, 0.5, 2.0, 0.1, _on_joystick_size_changed, &"", TOOLTIP_JOYSTICK_SIZE_KEY, "Adjust virtual joystick size.", "JoystickSizeSlider")
	_builder.add_slider(LABEL_BUTTON_SIZE_KEY, 0.5, 2.0, 0.1, _on_button_size_changed, &"", TOOLTIP_BUTTON_SIZE_KEY, "Adjust touch button size.", "ButtonSizeSlider")
	_builder.add_slider(LABEL_JOYSTICK_OPACITY_KEY, 0.0, 1.0, 0.05, _on_joystick_opacity_changed, &"", TOOLTIP_JOYSTICK_OPACITY_KEY, "Adjust virtual joystick opacity.", "JoystickOpacitySlider")
	_builder.add_slider(LABEL_BUTTON_OPACITY_KEY, 0.0, 1.0, 0.05, _on_button_opacity_changed, &"", TOOLTIP_BUTTON_OPACITY_KEY, "Adjust touch button opacity.", "ButtonOpacitySlider")
	_builder.add_slider(LABEL_JOYSTICK_DEADZONE_KEY, 0.0, 0.95, 0.01, _on_joystick_deadzone_changed, &"", TOOLTIP_JOYSTICK_DEADZONE_KEY, "Adjust joystick deadzone before input registers.", "JoystickDeadzoneSlider")
	_builder.add_slider(LABEL_LOOK_SENSITIVITY_KEY, 0.1, 5.0, 0.1, _on_look_sensitivity_changed, &"", TOOLTIP_LOOK_SENSITIVITY_KEY, "Adjust drag sensitivity for touchscreen camera look.", "LookSensitivitySlider")
	_builder.add_button_row(Callable(), Callable(), _on_reset_pressed, &"", &"", BUTTON_RESET_DEFAULTS_KEY, "", "", "Reset to Defaults")

func _capture_control_references() -> void:
	_joystick_size_slider = _find_child_by_name(self, "JoystickSizeSlider") as HSlider
	_joystick_size_value_label = _find_child_by_name(self, "JoystickSizeSliderValue") as Label
	_button_size_slider = _find_child_by_name(self, "ButtonSizeSlider") as HSlider
	_button_size_value_label = _find_child_by_name(self, "ButtonSizeSliderValue") as Label
	_joystick_opacity_slider = _find_child_by_name(self, "JoystickOpacitySlider") as HSlider
	_joystick_opacity_value_label = _find_child_by_name(self, "JoystickOpacitySliderValue") as Label
	_button_opacity_slider = _find_child_by_name(self, "ButtonOpacitySlider") as HSlider
	_button_opacity_value_label = _find_child_by_name(self, "ButtonOpacitySliderValue") as Label
	_joystick_deadzone_slider = _find_child_by_name(self, "JoystickDeadzoneSlider") as HSlider
	_joystick_deadzone_value_label = _find_child_by_name(self, "JoystickDeadzoneSliderValue") as Label
	_look_sensitivity_slider = _find_child_by_name(self, "LookSensitivitySlider") as HSlider
	_look_sensitivity_value_label = _find_child_by_name(self, "LookSensitivitySliderValue") as Label
	_reset_button = _find_child_by_name(self, "ResetButton") as Button

func _find_child_by_name(parent: Node, node_name: String) -> Node:
	for child in parent.get_children():
		if child.name == node_name:
			return child
		var result := _find_child_by_name(child, node_name)
		if result != null:
			return result
	return null

func _exit_tree() -> void:
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

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_update_edit_layout_visibility()

func _resolve_input_profile_manager() -> Node:
	var manager := U_ServiceLocator.try_get_service(INPUT_PROFILE_MANAGER_SERVICE)
	if manager != null:
		return manager
	return null

func _build_preview() -> void:
	if not ClassDB.class_exists("VirtualJoystick"):
		return
	_preview_container = Control.new()
	_preview_container.name = "PreviewContainer"
	_preview_container.custom_minimum_size = Vector2(200, 120)
	add_child(_preview_container)

	_preview_container.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
		TOOLTIP_PREVIEW_KEY,
		"Preview current touchscreen control settings."
	)

	var joystick_out: Array = []
	var buttons_out: Array = []
	_preview_builder.build_preview(
		_preview_container,
		VirtualJoystickScene,
		VirtualButtonScene,
		joystick_out,
		buttons_out
	)

	_preview_joystick = null
	if not joystick_out.is_empty():
		var first_joystick: Control = joystick_out[0] as Control
		if first_joystick != null:
			_preview_joystick = first_joystick

	_preview_buttons.clear()
	for entry in buttons_out:
		if entry is Control:
			_preview_buttons.append(entry)

	_edit_layout_button = Button.new()
	_edit_layout_button.name = "EditLayoutButton"
	_edit_layout_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(BUTTON_EDIT_LAYOUT_KEY, "Edit Layout")
	_edit_layout_button.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
		TOOLTIP_EDIT_LAYOUT_KEY,
		"Open layout editor to reposition controls."
	)
	_edit_layout_button.pressed.connect(_on_edit_layout_pressed)
	add_child(_edit_layout_button)

	_configure_sub_overlay_focus()

func _configure_focus_neighbors() -> void:
	W_SETTINGS_FOCUS_CONFIGURATOR.configure_vertical(self, [
		func() -> Control: return _joystick_size_slider,
		func() -> Control: return _button_size_slider,
		func() -> Control: return _joystick_opacity_slider,
		func() -> Control: return _button_opacity_slider,
		func() -> Control: return _joystick_deadzone_slider,
		func() -> Control: return _look_sensitivity_slider,
	])

	# Connect last vertical control to reset button
	var last_control: Control = null
	for ctrl in [_joystick_size_slider, _button_size_slider, _joystick_opacity_slider, _button_opacity_slider, _joystick_deadzone_slider, _look_sensitivity_slider]:
		if ctrl != null and ctrl.focus_mode != Control.FOCUS_NONE and ctrl.visible:
			last_control = ctrl
	if last_control != null and _reset_button != null:
		last_control.focus_neighbor_bottom = last_control.get_path_to(_reset_button)
		_reset_button.focus_neighbor_top = _reset_button.get_path_to(last_control)
		_reset_button.focus_neighbor_bottom = _reset_button.get_path_to(last_control)

func _configure_sub_overlay_focus() -> void:
	if _edit_layout_button != null and _reset_button != null:
		_reset_button.focus_neighbor_bottom = _reset_button.get_path_to(_edit_layout_button)
		_edit_layout_button.focus_neighbor_top = _edit_layout_button.get_path_to(_reset_button)
		_edit_layout_button.focus_neighbor_bottom = _edit_layout_button.get_path_to(_reset_button)

func _configure_tooltips() -> void:
	if _joystick_size_slider != null:
		_joystick_size_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_JOYSTICK_SIZE_KEY,
			"Adjust virtual joystick size."
		)
	if _button_size_slider != null:
		_button_size_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_BUTTON_SIZE_KEY,
			"Adjust touch button size."
		)
	if _joystick_opacity_slider != null:
		_joystick_opacity_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_JOYSTICK_OPACITY_KEY,
			"Adjust virtual joystick opacity."
		)
	if _button_opacity_slider != null:
		_button_opacity_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_BUTTON_OPACITY_KEY,
			"Adjust touch button opacity."
		)
	if _joystick_deadzone_slider != null:
		_joystick_deadzone_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_JOYSTICK_DEADZONE_KEY,
			"Adjust joystick deadzone before input registers."
		)
	if _look_sensitivity_slider != null:
		_look_sensitivity_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_LOOK_SENSITIVITY_KEY,
			"Adjust drag sensitivity for touchscreen camera look."
		)

func _connect_signals() -> void:
	_connect_if_needed(_joystick_size_slider.value_changed, _on_joystick_size_changed)
	_connect_if_needed(_button_size_slider.value_changed, _on_button_size_changed)
	_connect_if_needed(_joystick_opacity_slider.value_changed, _on_joystick_opacity_changed)
	_connect_if_needed(_button_opacity_slider.value_changed, _on_button_opacity_changed)
	_connect_if_needed(_joystick_deadzone_slider.value_changed, _on_joystick_deadzone_changed)
	_connect_if_needed(_look_sensitivity_slider.value_changed, _on_look_sensitivity_changed)

func _connect_if_needed(signal_ref: Signal, callback: Callable) -> void:
	if callback.is_valid() and not signal_ref.is_connected(callback):
		signal_ref.connect(callback)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return

	var settings := U_InputSelectors.get_touchscreen_settings(state)

	_updating_from_state = true
	if not settings.is_empty():
		if _joystick_size_slider != null:
			_joystick_size_slider.set_block_signals(true)
			_joystick_size_slider.value = float(settings.get("virtual_joystick_size", _joystick_size_slider.value))
			_joystick_size_slider.set_block_signals(false)
		if _button_size_slider != null:
			_button_size_slider.set_block_signals(true)
			_button_size_slider.value = float(settings.get("button_size", _button_size_slider.value))
			_button_size_slider.set_block_signals(false)
		if _joystick_opacity_slider != null:
			_joystick_opacity_slider.set_block_signals(true)
			_joystick_opacity_slider.value = float(settings.get("virtual_joystick_opacity", _joystick_opacity_slider.value))
			_joystick_opacity_slider.set_block_signals(false)
		if _button_opacity_slider != null:
			_button_opacity_slider.set_block_signals(true)
			_button_opacity_slider.value = float(settings.get("button_opacity", _button_opacity_slider.value))
			_button_opacity_slider.set_block_signals(false)
		if _joystick_deadzone_slider != null:
			_joystick_deadzone_slider.set_block_signals(true)
			_joystick_deadzone_slider.value = float(settings.get("joystick_deadzone", _joystick_deadzone_slider.value))
			_joystick_deadzone_slider.set_block_signals(false)
		if _look_sensitivity_slider != null:
			_look_sensitivity_slider.set_block_signals(true)
			_look_sensitivity_slider.value = float(settings.get("look_drag_sensitivity", _look_sensitivity_slider.value))
			_look_sensitivity_slider.set_block_signals(false)

	_update_slider_label(_joystick_size_value_label, _joystick_size_slider.value if _joystick_size_slider != null else 0.0)
	_update_slider_label(_button_size_value_label, _button_size_slider.value if _button_size_slider != null else 0.0)
	_update_slider_label(_joystick_opacity_value_label, _joystick_opacity_slider.value if _joystick_opacity_slider != null else 0.0)
	_update_slider_label(_button_opacity_value_label, _button_opacity_slider.value if _button_opacity_slider != null else 0.0)
	_update_slider_label(_joystick_deadzone_value_label, _joystick_deadzone_slider.value if _joystick_deadzone_slider != null else 0.0)
	_update_slider_label(_look_sensitivity_value_label, _look_sensitivity_slider.value if _look_sensitivity_slider != null else 0.0)
	_updating_from_state = false

	_apply_preview_size_limits()
	_update_preview_from_sliders()

func _on_joystick_size_changed(value: float) -> void:
	_update_slider_label(_joystick_size_value_label, value)
	_update_preview_from_sliders()
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_touchscreen_settings({"virtual_joystick_size": value}))

func _on_button_size_changed(value: float) -> void:
	_update_slider_label(_button_size_value_label, value)
	_update_preview_from_sliders()
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_touchscreen_settings({"button_size": value}))

func _on_joystick_opacity_changed(value: float) -> void:
	_update_slider_label(_joystick_opacity_value_label, value)
	_update_preview_from_sliders()
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_touchscreen_settings({"virtual_joystick_opacity": value}))

func _on_button_opacity_changed(value: float) -> void:
	_update_slider_label(_button_opacity_value_label, value)
	_update_preview_from_sliders()
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_touchscreen_settings({"button_opacity": value}))

func _on_joystick_deadzone_changed(value: float) -> void:
	_update_slider_label(_joystick_deadzone_value_label, value)
	_update_preview_from_sliders()
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_touchscreen_settings({"joystick_deadzone": value}))

func _on_look_sensitivity_changed(value: float) -> void:
	_update_slider_label(_look_sensitivity_value_label, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_touchscreen_settings({"look_drag_sensitivity": value}))

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var defaults: RS_TouchscreenSettings = DEFAULTS

	_updating_from_state = true
	if _joystick_size_slider != null:
		_joystick_size_slider.set_block_signals(true)
		_joystick_size_slider.value = defaults.virtual_joystick_size
		_joystick_size_slider.set_block_signals(false)
	if _button_size_slider != null:
		_button_size_slider.set_block_signals(true)
		_button_size_slider.value = defaults.button_size
		_button_size_slider.set_block_signals(false)
	if _joystick_opacity_slider != null:
		_joystick_opacity_slider.set_block_signals(true)
		_joystick_opacity_slider.value = defaults.virtual_joystick_opacity
		_joystick_opacity_slider.set_block_signals(false)
	if _button_opacity_slider != null:
		_button_opacity_slider.set_block_signals(true)
		_button_opacity_slider.value = defaults.button_opacity
		_button_opacity_slider.set_block_signals(false)
	if _joystick_deadzone_slider != null:
		_joystick_deadzone_slider.set_block_signals(true)
		_joystick_deadzone_slider.value = defaults.joystick_deadzone
		_joystick_deadzone_slider.set_block_signals(false)
	if _look_sensitivity_slider != null:
		_look_sensitivity_slider.set_block_signals(true)
		_look_sensitivity_slider.value = defaults.look_drag_sensitivity
		_look_sensitivity_slider.set_block_signals(false)
	_update_slider_label(_joystick_size_value_label, defaults.virtual_joystick_size)
	_update_slider_label(_button_size_value_label, defaults.button_size)
	_update_slider_label(_joystick_opacity_value_label, defaults.virtual_joystick_opacity)
	_update_slider_label(_button_opacity_value_label, defaults.button_opacity)
	_update_slider_label(_joystick_deadzone_value_label, defaults.joystick_deadzone)
	_update_slider_label(_look_sensitivity_value_label, defaults.look_drag_sensitivity)
	_updating_from_state = false

	_update_preview_from_sliders()

	var typed_manager := _profile_manager as I_INPUT_PROFILE_MANAGER
	if typed_manager != null:
		typed_manager.reset_touchscreen_positions()

	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_touchscreen_settings({
			"virtual_joystick_size": defaults.virtual_joystick_size,
			"button_size": defaults.button_size,
			"virtual_joystick_opacity": defaults.virtual_joystick_opacity,
			"button_opacity": defaults.button_opacity,
			"joystick_deadzone": defaults.joystick_deadzone,
			"look_drag_sensitivity": defaults.look_drag_sensitivity,
		}))

func _on_edit_layout_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	if _state_store == null:
		return
	_state_store.dispatch(U_NavigationActions.open_overlay(StringName("edit_touch_controls")))

func _update_edit_layout_visibility() -> void:
	if _edit_layout_button == null:
		return
	_edit_layout_button.visible = true
	_configure_sub_overlay_focus()

func _apply_preview_size_limits() -> void:
	if _preview_container == null:
		return
	if _joystick_size_slider == null or _button_size_slider == null:
		return
	var max_scales: Dictionary = _preview_builder.get_max_preview_scales(
		_preview_container,
		_preview_joystick,
		_preview_buttons
	)
	var joystick_max: float = max(
		float(max_scales.get("joystick", _joystick_size_slider.max_value)),
		_joystick_size_slider.min_value
	)
	var button_max: float = max(
		float(max_scales.get("button", _button_size_slider.max_value)),
		_button_size_slider.min_value
	)

	_joystick_size_slider.max_value = joystick_max
	_button_size_slider.max_value = button_max
	_joystick_size_slider.set_value_no_signal(min(_joystick_size_slider.value, joystick_max))
	_button_size_slider.set_value_no_signal(min(_button_size_slider.value, button_max))

func _update_preview_from_sliders() -> void:
	if _preview_container == null:
		return
	if _joystick_size_slider == null or _button_size_slider == null:
		return

	var joystick_size: float = float(_joystick_size_slider.value)
	var button_size: float = float(_button_size_slider.value)
	var joystick_opacity: float = float(_joystick_opacity_slider.value if _joystick_opacity_slider != null else 0.0)
	var button_opacity: float = float(_button_opacity_slider.value if _button_opacity_slider != null else 0.0)
	var joystick_deadzone: float = float(_joystick_deadzone_slider.value if _joystick_deadzone_slider != null else 0.0)

	_preview_builder.update_preview_from_sliders(
		_preview_container,
		_preview_joystick,
		_preview_buttons,
		joystick_size,
		button_size,
		joystick_opacity,
		button_opacity,
		joystick_deadzone
	)

func _update_slider_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%.2f" % value

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
	_configure_tooltips()

func _localize_labels() -> void:
	if _builder != null:
		_builder.localize_labels()
	if _edit_layout_button != null:
		_edit_layout_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(BUTTON_EDIT_LAYOUT_KEY, "Edit Layout")
