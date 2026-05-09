@icon("res://assets/core/editor_icons/icn_utility.svg")
extends VBoxContainer
class_name UI_GamepadSettingsTab

const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_SETTINGS_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_settings_tab_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_INPUT_ACTIONS := preload("res://scripts/core/state/actions/u_input_actions.gd")
const U_INPUT_SELECTORS := preload("res://scripts/core/state/selectors/u_input_selectors.gd")
const RS_GAMEPAD_SETTINGS := preload("res://scripts/core/resources/input/rs_gamepad_settings.gd")
const W_SETTINGS_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/widgets/w_settings_focus_configurator.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/core/state/actions/u_navigation_actions.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/core/state/selectors/u_navigation_selectors.gd")

const TITLE_KEY := &"settings.gamepad.title"
const LABEL_LEFT_DEADZONE_KEY := &"settings.gamepad.label.left_deadzone"
const LABEL_RIGHT_DEADZONE_KEY := &"settings.gamepad.label.right_deadzone"
const LABEL_ROTATE_SENSITIVITY_KEY := &"settings.gamepad.label.rotate_sensitivity"
const LABEL_VIBRATION_ENABLED_KEY := &"settings.gamepad.label.vibration_enabled"
const LABEL_VIBRATION_INTENSITY_KEY := &"settings.gamepad.label.vibration_intensity"
const BUTTON_RESET_DEFAULTS_KEY := &"settings.gamepad.button.reset_defaults"
const BUTTON_INPUT_PROFILES_KEY := &"settings.gamepad.button.input_profiles"
const BUTTON_REBIND_CONTROLS_KEY := &"settings.gamepad.button.rebind_controls"
const PREVIEW_ENTER_PROMPT_KEY := &"settings.gamepad.preview.enter"
const PREVIEW_EXIT_PROMPT_KEY := &"settings.gamepad.preview.exit"

const TOOLTIP_LEFT_DEADZONE_KEY := &"settings.gamepad.tooltip.left_deadzone"
const TOOLTIP_RIGHT_DEADZONE_KEY := &"settings.gamepad.tooltip.right_deadzone"
const TOOLTIP_ROTATE_SENSITIVITY_KEY := &"settings.gamepad.tooltip.rotate_sensitivity"
const TOOLTIP_VIBRATION_ENABLED_KEY := &"settings.gamepad.tooltip.vibration_enabled"
const TOOLTIP_VIBRATION_INTENSITY_KEY := &"settings.gamepad.tooltip.vibration_intensity"
const TOOLTIP_PREVIEW_KEY := &"settings.gamepad.tooltip.preview"

var _state_store: I_StateStore = null
var _unsubscribe: Callable = Callable()
var _updating_from_state: bool = false
var _builder: RefCounted = null
var _current_device_id: int = -1
var _preview_active: bool = false

var _left_deadzone_slider: HSlider
var _left_deadzone_value_label: Label
var _right_deadzone_slider: HSlider
var _right_deadzone_value_label: Label
var _sensitivity_slider: HSlider
var _sensitivity_value_label: Label
var _vibration_toggle: CheckBox
var _vibration_slider: HSlider
var _vibration_value_label: Label
var _stick_preview: UI_GamepadStickPreview
var _reset_button: Button
var _input_profiles_button: Button
var _rebind_controls_button: Button

var _left_stick_raw: Vector2 = Vector2.ZERO
var _right_stick_raw: Vector2 = Vector2.ZERO
var _left_stick_processed: Vector2 = Vector2.ZERO
var _right_stick_processed: Vector2 = Vector2.ZERO

func _ready() -> void:
	_setup_builder()
	if _builder != null:
		_builder.build()
	_capture_control_references()
	_configure_focus_neighbors()
	_configure_tooltips()
	_setup_stick_preview()
	set_meta(&"settings_builder", true)

	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		push_error("UI_GamepadSettingsTab: StateStore not found")
		return

	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

	visibility_changed.connect(_on_visibility_changed)

func _setup_builder() -> void:
	_builder = U_SETTINGS_TAB_BUILDER.new(self)
	_builder.bind_theme_role(self, &"separation_default")
	_builder.set_heading(TITLE_KEY)
	_builder.add_slider(LABEL_LEFT_DEADZONE_KEY, 0.0, 0.95, 0.01, _on_left_deadzone_changed, &"", TOOLTIP_LEFT_DEADZONE_KEY, "Adjust deadzone for left stick movement.", "LeftDeadzoneSlider")
	_builder.add_slider(LABEL_RIGHT_DEADZONE_KEY, 0.0, 0.95, 0.01, _on_right_deadzone_changed, &"", TOOLTIP_RIGHT_DEADZONE_KEY, "Adjust deadzone for right stick camera/look.", "RightDeadzoneSlider")
	_builder.add_slider(LABEL_ROTATE_SENSITIVITY_KEY, 0.1, 5.0, 0.1, _on_sensitivity_changed, &"", TOOLTIP_ROTATE_SENSITIVITY_KEY, "Adjust right-stick camera rotation sensitivity.", "RightSensitivitySlider")
	_builder.add_toggle(LABEL_VIBRATION_ENABLED_KEY, _on_vibration_toggled, TOOLTIP_VIBRATION_ENABLED_KEY, "Enable or disable gamepad vibration feedback.", "VibrationToggle")
	_builder.add_slider(LABEL_VIBRATION_INTENSITY_KEY, 0.0, 1.0, 0.05, _on_vibration_intensity_changed, &"", TOOLTIP_VIBRATION_INTENSITY_KEY, "Adjust vibration strength.", "VibrationSlider")
	_builder.add_button_row(Callable(), Callable(), _on_reset_pressed, &"", &"", BUTTON_RESET_DEFAULTS_KEY, "", "", "Reset to Defaults")

func _capture_control_references() -> void:
	_left_deadzone_slider = _find_child_by_name(self, "LeftDeadzoneSlider") as HSlider
	_left_deadzone_value_label = _find_child_by_name(self, "LeftDeadzoneSliderValue") as Label
	_right_deadzone_slider = _find_child_by_name(self, "RightDeadzoneSlider") as HSlider
	_right_deadzone_value_label = _find_child_by_name(self, "RightDeadzoneSliderValue") as Label
	_sensitivity_slider = _find_child_by_name(self, "RightSensitivitySlider") as HSlider
	_sensitivity_value_label = _find_child_by_name(self, "RightSensitivitySliderValue") as Label
	_vibration_toggle = _find_child_by_name(self, "VibrationToggle") as CheckBox
	_vibration_slider = _find_child_by_name(self, "VibrationSlider") as HSlider
	_vibration_value_label = _find_child_by_name(self, "VibrationSliderValue") as Label
	_reset_button = _find_child_by_name(self, "ResetButton") as Button

func _setup_stick_preview() -> void:
	var preview := UI_GamepadStickPreview.new()
	preview.name = "StickPreview"
	preview.custom_minimum_size = Vector2(300, 160)
	add_child(preview)
	_stick_preview = preview

	if _builder != null:
		_builder.bind_theme_role(preview, &"default_row")
	_builder.bind_theme_role(preview, &"field_control")
	preview.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_PREVIEW_KEY, "Focus and press confirm to test stick input.")

	_input_profiles_button = Button.new()
	_input_profiles_button.name = "InputProfilesButton"
	_input_profiles_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(BUTTON_INPUT_PROFILES_KEY, "Input Profiles")
	_input_profiles_button.pressed.connect(_on_input_profiles_pressed)
	add_child(_input_profiles_button)

	_rebind_controls_button = Button.new()
	_rebind_controls_button.name = "RebindControlsButton"
	_rebind_controls_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(BUTTON_REBIND_CONTROLS_KEY, "Rebind Controls")
	_rebind_controls_button.pressed.connect(_on_rebind_controls_pressed)
	add_child(_rebind_controls_button)

	_configure_sub_overlay_focus()

func _find_child_by_name(parent: Node, name: String) -> Node:
	for child in parent.get_children():
		if child.name == name:
			return child
		var result := _find_child_by_name(child, name)
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
	if not is_visible_in_tree():
		_preview_active = false
		if _stick_preview != null:
			_stick_preview.set_active(false)
		set_process(false)
	else:
		set_process(true)

func _configure_focus_neighbors() -> void:
	W_SETTINGS_FOCUS_CONFIGURATOR.configure_vertical(self, [
		func() -> Control: return _left_deadzone_slider,
		func() -> Control: return _right_deadzone_slider,
		func() -> Control: return _sensitivity_slider,
		func() -> Control: return _vibration_toggle,
		func() -> Control: return _vibration_slider,
		func() -> Control: return _stick_preview,
	], false)

	# Connect last vertical control to reset button
	var last_control: Control = null
	for ctrl in [_left_deadzone_slider, _right_deadzone_slider, _sensitivity_slider, _vibration_toggle, _vibration_slider, _stick_preview]:
		if ctrl != null and ctrl.focus_mode != Control.FOCUS_NONE and ctrl.visible:
			last_control = ctrl
	if last_control != null and _reset_button != null:
		last_control.focus_neighbor_bottom = last_control.get_path_to(_reset_button)
		_reset_button.focus_neighbor_top = _reset_button.get_path_to(last_control)
		_reset_button.focus_neighbor_bottom = _reset_button.get_path_to(last_control)

func _configure_sub_overlay_focus() -> void:
	var sub_buttons: Array[Control] = []
	if _input_profiles_button != null:
		sub_buttons.append(_input_profiles_button)
	if _rebind_controls_button != null:
		sub_buttons.append(_rebind_controls_button)

	W_SETTINGS_FOCUS_CONFIGURATOR.configure_vertical(self, [
		func() -> Control: return _input_profiles_button,
		func() -> Control: return _rebind_controls_button,
	], false)

	if _reset_button != null and _input_profiles_button != null:
		_reset_button.focus_neighbor_bottom = _reset_button.get_path_to(_input_profiles_button)
		_input_profiles_button.focus_neighbor_top = _input_profiles_button.get_path_to(_reset_button)

	if _input_profiles_button != null and _rebind_controls_button != null:
		_input_profiles_button.focus_neighbor_bottom = _input_profiles_button.get_path_to(_rebind_controls_button)
		_rebind_controls_button.focus_neighbor_top = _rebind_controls_button.get_path_to(_input_profiles_button)

	if _rebind_controls_button != null and _stick_preview != null:
		_rebind_controls_button.focus_neighbor_bottom = _rebind_controls_button.get_path_to(_stick_preview)

func _configure_tooltips() -> void:
	if _left_deadzone_slider != null:
		_left_deadzone_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_LEFT_DEADZONE_KEY, "Adjust deadzone for left stick movement.")
	if _right_deadzone_slider != null:
		_right_deadzone_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_RIGHT_DEADZONE_KEY, "Adjust deadzone for right stick camera/look.")
	if _sensitivity_slider != null:
		_sensitivity_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_ROTATE_SENSITIVITY_KEY, "Adjust right-stick camera rotation sensitivity.")
	if _vibration_toggle != null:
		_vibration_toggle.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_VIBRATION_ENABLED_KEY, "Enable or disable gamepad vibration feedback.")
	if _vibration_slider != null:
		_vibration_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(TOOLTIP_VIBRATION_INTENSITY_KEY, "Adjust vibration strength.")

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return

	var settings := U_InputSelectors.get_gamepad_settings(state)

	_updating_from_state = true
	if not settings.is_empty():
		if _left_deadzone_slider != null:
			_left_deadzone_slider.set_block_signals(true)
			_left_deadzone_slider.value = float(settings.get("left_stick_deadzone", _left_deadzone_slider.value))
			_left_deadzone_slider.set_block_signals(false)
		if _right_deadzone_slider != null:
			_right_deadzone_slider.set_block_signals(true)
			_right_deadzone_slider.value = float(settings.get("right_stick_deadzone", _right_deadzone_slider.value))
			_right_deadzone_slider.set_block_signals(false)
		if _sensitivity_slider != null:
			_sensitivity_slider.set_block_signals(true)
			_sensitivity_slider.value = float(settings.get("right_stick_sensitivity", _sensitivity_slider.value))
			_sensitivity_slider.set_block_signals(false)
		if _vibration_toggle != null:
			_vibration_toggle.set_block_signals(true)
			_vibration_toggle.button_pressed = bool(settings.get("vibration_enabled", true))
			_vibration_toggle.set_block_signals(false)
		if _vibration_slider != null:
			_vibration_slider.set_block_signals(true)
			_vibration_slider.value = float(settings.get("vibration_intensity", _vibration_slider.value))
			_vibration_slider.set_block_signals(false)

	_update_slider_label(_left_deadzone_value_label, _left_deadzone_slider.value if _left_deadzone_slider != null else 0.0)
	_update_slider_label(_right_deadzone_value_label, _right_deadzone_slider.value if _right_deadzone_slider != null else 0.0)
	_update_slider_label(_sensitivity_value_label, _sensitivity_slider.value if _sensitivity_slider != null else 0.0)
	_update_slider_label(_vibration_value_label, _vibration_slider.value if _vibration_slider != null else 0.0)
	_updating_from_state = false

	if U_InputSelectors.is_gamepad_connected(state):
		_current_device_id = U_InputSelectors.get_active_gamepad_id(state)
	else:
		_current_device_id = -1

func _on_left_deadzone_changed(value: float) -> void:
	_update_slider_label(_left_deadzone_value_label, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_gamepad_deadzone("left", value))

func _on_right_deadzone_changed(value: float) -> void:
	_update_slider_label(_right_deadzone_value_label, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_gamepad_deadzone("right", value))

func _on_sensitivity_changed(value: float) -> void:
	_update_slider_label(_sensitivity_value_label, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_gamepad_sensitivity(value))

func _on_vibration_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	if pressed and _current_device_id >= 0:
		var intensity := _vibration_slider.value if _vibration_slider != null else 0.5
		Input.start_joy_vibration(_current_device_id, 0.5 * intensity, 0.3 * intensity, 0.3)
	if _state_store != null:
		_state_store.dispatch(U_InputActions.toggle_vibration(pressed))

func _on_vibration_intensity_changed(value: float) -> void:
	_update_slider_label(_vibration_value_label, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.set_vibration_intensity(value))

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var defaults := RS_GamepadSettings.new()

	_updating_from_state = true
	if _left_deadzone_slider != null:
		_left_deadzone_slider.set_block_signals(true)
		_left_deadzone_slider.value = defaults.left_stick_deadzone
		_left_deadzone_slider.set_block_signals(false)
	if _right_deadzone_slider != null:
		_right_deadzone_slider.set_block_signals(true)
		_right_deadzone_slider.value = defaults.right_stick_deadzone
		_right_deadzone_slider.set_block_signals(false)
	if _sensitivity_slider != null:
		_sensitivity_slider.set_block_signals(true)
		_sensitivity_slider.value = defaults.right_stick_sensitivity
		_sensitivity_slider.set_block_signals(false)
	if _vibration_toggle != null:
		_vibration_toggle.set_block_signals(true)
		_vibration_toggle.button_pressed = defaults.vibration_enabled
		_vibration_toggle.set_block_signals(false)
	if _vibration_slider != null:
		_vibration_slider.set_block_signals(true)
		_vibration_slider.value = defaults.vibration_intensity
		_vibration_slider.set_block_signals(false)
	_update_slider_label(_left_deadzone_value_label, defaults.left_stick_deadzone)
	_update_slider_label(_right_deadzone_value_label, defaults.right_stick_deadzone)
	_update_slider_label(_sensitivity_value_label, defaults.right_stick_sensitivity)
	_update_slider_label(_vibration_value_label, defaults.vibration_intensity)
	_updating_from_state = false

	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_gamepad_deadzone("left", defaults.left_stick_deadzone))
		_state_store.dispatch(U_InputActions.update_gamepad_deadzone("right", defaults.right_stick_deadzone))
		_state_store.dispatch(U_InputActions.update_gamepad_sensitivity(defaults.right_stick_sensitivity))
		_state_store.dispatch(U_InputActions.toggle_vibration(defaults.vibration_enabled))
		_state_store.dispatch(U_InputActions.set_vibration_intensity(defaults.vibration_intensity))

func _on_input_profiles_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	if _state_store == null:
		return
	var nav_slice: Dictionary = _state_store.get_state().get("navigation", {})
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	if shell == StringName("gameplay") and not overlay_stack.is_empty():
		_state_store.dispatch(U_NavigationActions.open_overlay(StringName("input_profile_selector")))
		return
	_state_store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("input_profile_selector"), "fade", 2))

func _on_rebind_controls_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	if _state_store == null:
		return
	var nav_slice: Dictionary = _state_store.get_state().get("navigation", {})
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	if shell == StringName("gameplay") and not overlay_stack.is_empty():
		_state_store.dispatch(U_NavigationActions.open_overlay(StringName("input_rebinding")))
		return
	_state_store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("input_rebinding"), "fade", 2))

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_update_preview_vectors()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _stick_preview != null and _stick_preview.has_focus():
		if event.is_action_pressed("ui_accept"):
			_preview_active = true
			_stick_preview.set_active(true)
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if _preview_active and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_pause")):
			_preview_active = false
			_stick_preview.set_active(false)
			var viewport_cancel := get_viewport()
			if viewport_cancel != null:
				viewport_cancel.set_input_as_handled()
			return

func _update_preview_vectors() -> void:
	if _stick_preview == null:
		return
	if not _preview_active or not _stick_preview.has_focus() or _current_device_id < 0:
		_stick_preview.update_vectors(Vector2.ZERO, Vector2.ZERO)
		_left_stick_raw = Vector2.ZERO
		_right_stick_raw = Vector2.ZERO
		_left_stick_processed = Vector2.ZERO
		_right_stick_processed = Vector2.ZERO
		return

	_left_stick_raw = Vector2(
		Input.get_joy_axis(_current_device_id, JOY_AXIS_LEFT_X),
		-Input.get_joy_axis(_current_device_id, JOY_AXIS_LEFT_Y)
	)
	_right_stick_raw = Vector2(
		Input.get_joy_axis(_current_device_id, JOY_AXIS_RIGHT_X),
		-Input.get_joy_axis(_current_device_id, JOY_AXIS_RIGHT_Y)
	)

	_left_stick_processed = RS_GamepadSettings.apply_deadzone(
		_left_stick_raw,
		_left_deadzone_slider.value if _left_deadzone_slider != null else 0.0,
		RS_GamepadSettings.DeadzoneCurve.LINEAR
	)
	_right_stick_processed = RS_GamepadSettings.apply_deadzone(
		_right_stick_raw,
		_right_deadzone_slider.value if _right_deadzone_slider != null else 0.0,
		RS_GamepadSettings.DeadzoneCurve.LINEAR
	)

	_stick_preview.update_vectors(_left_stick_processed, _right_stick_processed, _left_stick_raw, _right_stick_raw)

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
	if _input_profiles_button != null:
		_input_profiles_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(BUTTON_INPUT_PROFILES_KEY, "Input Profiles")
	if _rebind_controls_button != null:
		_rebind_controls_button.text = U_LOCALIZATION_UTILS.localize_with_fallback(BUTTON_REBIND_CONTROLS_KEY, "Rebind Controls")