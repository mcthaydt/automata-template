@icon("res://assets/core/editor_icons/icn_utility.svg")
extends VBoxContainer
class_name UI_KeyboardMouseSettingsTab

const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_SETTINGS_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_settings_tab_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_INPUT_ACTIONS := preload("res://scripts/core/state/actions/u_input_actions.gd")
const U_INPUT_SELECTORS := preload("res://scripts/core/state/selectors/u_input_selectors.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/core/state/actions/u_navigation_actions.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/core/state/selectors/u_navigation_selectors.gd")
const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")

const TITLE_KEY := &"settings.keyboard_mouse.title"
const LABEL_MOUSE_SENSITIVITY_KEY := &"settings.keyboard_mouse.label.mouse_sensitivity"
const LABEL_KEYBOARD_LOOK_ENABLED_KEY := &"settings.keyboard_mouse.label.keyboard_look_enabled"
const LABEL_KEYBOARD_LOOK_SPEED_KEY := &"settings.keyboard_mouse.label.keyboard_look_speed"
const BUTTON_RESET_DEFAULTS_KEY := &"settings.keyboard_mouse.button.reset_defaults"
const BUTTON_REBIND_LOOK_KEY := &"settings.keyboard_mouse.button.rebind_look"

const TOOLTIP_MOUSE_SENSITIVITY_KEY := &"settings.keyboard_mouse.tooltip.mouse_sensitivity"
const TOOLTIP_KEYBOARD_LOOK_ENABLED_KEY := &"settings.keyboard_mouse.tooltip.keyboard_look_enabled"
const TOOLTIP_KEYBOARD_LOOK_SPEED_KEY := &"settings.keyboard_mouse.tooltip.keyboard_look_speed"

const DEFAULT_MOUSE_SENSITIVITY: float = 0.6
const MIN_MOUSE_SENSITIVITY: float = 0.1
const MAX_MOUSE_SENSITIVITY: float = 5.0
const DEFAULT_KEYBOARD_LOOK_ENABLED: bool = true
const DEFAULT_KEYBOARD_LOOK_SPEED: float = 2.0
const MIN_KEYBOARD_LOOK_SPEED: float = 0.1
const MAX_KEYBOARD_LOOK_SPEED: float = 10.0

var _state_store: I_StateStore = null
var _unsubscribe: Callable = Callable()
var _updating_from_state: bool = false
var _builder: RefCounted = null

var _mouse_sensitivity_slider: HSlider
var _mouse_sensitivity_value_label: Label
var _keyboard_look_enabled_check: CheckButton
var _keyboard_look_speed_slider: HSlider
var _keyboard_look_speed_value_label: Label
var _reset_button: Button
var _rebind_button: Button

func _ready() -> void:
	_setup_builder()
	if _builder != null:
		_builder.build()
	_capture_control_references()
	_configure_focus_neighbors()
	_configure_tooltips()
	set_meta(&"settings_builder", true)

	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		push_error("UI_KeyboardMouseSettingsTab: StateStore not found")
		return

	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

func _setup_builder() -> void:
	_builder = U_SETTINGS_TAB_BUILDER.new(self)
	_builder.bind_theme_role(self, &"separation_default")
	_builder.set_heading(TITLE_KEY)
	_builder.add_slider(LABEL_MOUSE_SENSITIVITY_KEY, MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY, 0.1, _on_mouse_sensitivity_changed, &"", TOOLTIP_MOUSE_SENSITIVITY_KEY, "Adjust camera rotation sensitivity for mouse look input.", "MouseSensitivitySlider")
	_builder.add_toggle(LABEL_KEYBOARD_LOOK_ENABLED_KEY, _on_keyboard_look_enabled_toggled, TOOLTIP_KEYBOARD_LOOK_ENABLED_KEY, "Allow keyboard keys to rotate the camera.", "KeyboardLookEnabledCheck")
	_builder.add_slider(LABEL_KEYBOARD_LOOK_SPEED_KEY, MIN_KEYBOARD_LOOK_SPEED, MAX_KEYBOARD_LOOK_SPEED, 0.1, _on_keyboard_look_speed_changed, &"", TOOLTIP_KEYBOARD_LOOK_SPEED_KEY, "Adjust camera rotation speed for keyboard look input.", "KeyboardLookSpeedSlider")
	_builder.add_button_row(Callable(), Callable(), _on_reset_pressed, &"", &"", BUTTON_RESET_DEFAULTS_KEY, "", "", "Reset to Defaults")
	_add_rebind_button_to_action_row()

func _add_rebind_button_to_action_row() -> void:
	var action_row := _find_child_by_name(self, "ActionButtons") as HBoxContainer
	if action_row == null:
		return
	var rebind_button := Button.new()
	rebind_button.name = "RebindButton"
	action_row.add_child(rebind_button)
	_builder.bind_action_button(rebind_button, BUTTON_REBIND_LOOK_KEY, _on_rebind_pressed, "Rebind")

func _capture_control_references() -> void:
	_mouse_sensitivity_slider = _find_child_by_name(self, "MouseSensitivitySlider") as HSlider
	_mouse_sensitivity_value_label = _find_child_by_name(self, "MouseSensitivitySliderValue") as Label
	_keyboard_look_enabled_check = _find_child_by_name(self, "KeyboardLookEnabledCheck") as CheckButton
	_keyboard_look_speed_slider = _find_child_by_name(self, "KeyboardLookSpeedSlider") as HSlider
	_keyboard_look_speed_value_label = _find_child_by_name(self, "KeyboardLookSpeedSliderValue") as Label
	_reset_button = _find_child_by_name(self, "ResetButton") as Button
	_rebind_button = _find_child_by_name(self, "RebindButton") as Button

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

func _configure_focus_neighbors() -> void:
	var vertical_controls: Array[Control] = []
	if _mouse_sensitivity_slider != null:
		vertical_controls.append(_mouse_sensitivity_slider)
	if _keyboard_look_enabled_check != null:
		vertical_controls.append(_keyboard_look_enabled_check)
	if _keyboard_look_speed_slider != null:
		vertical_controls.append(_keyboard_look_speed_slider)
	if _reset_button != null:
		vertical_controls.append(_reset_button)
	if _rebind_button != null:
		vertical_controls.append(_rebind_button)

	var visible_controls: Array[Control] = []
	for control: Control in vertical_controls:
		if control != null and control.focus_mode != Control.FOCUS_NONE and control.visible:
			visible_controls.append(control)

	if not visible_controls.is_empty():
		U_FOCUS_CONFIGURATOR.configure_vertical_focus(visible_controls)

	if _reset_button != null and _rebind_button != null:
		_reset_button.focus_neighbor_right = _reset_button.get_path_to(_rebind_button)
		_rebind_button.focus_neighbor_left = _rebind_button.get_path_to(_reset_button)

func _configure_tooltips() -> void:
	if _mouse_sensitivity_slider != null:
		_mouse_sensitivity_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_MOUSE_SENSITIVITY_KEY,
			"Adjust camera rotation sensitivity for mouse look input."
		)
	if _keyboard_look_enabled_check != null:
		_keyboard_look_enabled_check.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_KEYBOARD_LOOK_ENABLED_KEY,
			"Allow keyboard keys to rotate the camera."
		)
	if _keyboard_look_speed_slider != null:
		_keyboard_look_speed_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_KEYBOARD_LOOK_SPEED_KEY,
			"Adjust camera rotation speed for keyboard look input."
		)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return

	var mouse_settings := U_InputSelectors.get_mouse_settings(state)
	_updating_from_state = true
	if not mouse_settings.is_empty():
		if _mouse_sensitivity_slider != null:
			_mouse_sensitivity_slider.set_block_signals(true)
			_mouse_sensitivity_slider.value = clampf(
				float(mouse_settings.get("sensitivity", DEFAULT_MOUSE_SENSITIVITY)),
				MIN_MOUSE_SENSITIVITY,
				MAX_MOUSE_SENSITIVITY
			)
			_mouse_sensitivity_slider.set_block_signals(false)
		if _keyboard_look_enabled_check != null:
			_keyboard_look_enabled_check.set_block_signals(true)
			_keyboard_look_enabled_check.button_pressed = bool(mouse_settings.get("keyboard_look_enabled", DEFAULT_KEYBOARD_LOOK_ENABLED))
			_keyboard_look_enabled_check.set_block_signals(false)
		if _keyboard_look_speed_slider != null:
			_keyboard_look_speed_slider.set_block_signals(true)
			_keyboard_look_speed_slider.value = clampf(
				float(mouse_settings.get("keyboard_look_speed", DEFAULT_KEYBOARD_LOOK_SPEED)),
				MIN_KEYBOARD_LOOK_SPEED,
				MAX_KEYBOARD_LOOK_SPEED
			)
			_keyboard_look_speed_slider.set_block_signals(false)

	_update_slider_label(_mouse_sensitivity_value_label, _mouse_sensitivity_slider.value if _mouse_sensitivity_slider != null else 0.0)
	_update_slider_label(_keyboard_look_speed_value_label, _keyboard_look_speed_slider.value if _keyboard_look_speed_slider != null else 0.0)
	_apply_keyboard_look_enabled_state(_keyboard_look_enabled_check.button_pressed if _keyboard_look_enabled_check != null else DEFAULT_KEYBOARD_LOOK_ENABLED)
	_updating_from_state = false

func _on_mouse_sensitivity_changed(value: float) -> void:
	_update_slider_label(_mouse_sensitivity_value_label, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_mouse_sensitivity(value))

func _on_keyboard_look_enabled_toggled(enabled: bool) -> void:
	_apply_keyboard_look_enabled_state(enabled)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.set_keyboard_look_enabled(enabled))

func _on_keyboard_look_speed_changed(value: float) -> void:
	_update_slider_label(_keyboard_look_speed_value_label, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_InputActions.set_keyboard_look_speed(value))

func _apply_keyboard_look_enabled_state(enabled: bool) -> void:
	if _keyboard_look_speed_slider != null:
		_keyboard_look_speed_slider.editable = enabled
		_keyboard_look_speed_slider.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		_keyboard_look_speed_slider.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(0.7, 0.7, 0.7, 1.0)

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	_updating_from_state = true
	if _mouse_sensitivity_slider != null:
		_mouse_sensitivity_slider.set_block_signals(true)
		_mouse_sensitivity_slider.value = DEFAULT_MOUSE_SENSITIVITY
		_mouse_sensitivity_slider.set_block_signals(false)
	if _keyboard_look_enabled_check != null:
		_keyboard_look_enabled_check.set_block_signals(true)
		_keyboard_look_enabled_check.button_pressed = DEFAULT_KEYBOARD_LOOK_ENABLED
		_keyboard_look_enabled_check.set_block_signals(false)
	if _keyboard_look_speed_slider != null:
		_keyboard_look_speed_slider.set_block_signals(true)
		_keyboard_look_speed_slider.value = DEFAULT_KEYBOARD_LOOK_SPEED
		_keyboard_look_speed_slider.set_block_signals(false)
	_update_slider_label(_mouse_sensitivity_value_label, DEFAULT_MOUSE_SENSITIVITY)
	_update_slider_label(_keyboard_look_speed_value_label, DEFAULT_KEYBOARD_LOOK_SPEED)
	_apply_keyboard_look_enabled_state(DEFAULT_KEYBOARD_LOOK_ENABLED)
	_updating_from_state = false

	if _state_store != null:
		_state_store.dispatch(U_InputActions.update_mouse_sensitivity(DEFAULT_MOUSE_SENSITIVITY))
		_state_store.dispatch(U_InputActions.set_keyboard_look_enabled(DEFAULT_KEYBOARD_LOOK_ENABLED))
		_state_store.dispatch(U_InputActions.set_keyboard_look_speed(DEFAULT_KEYBOARD_LOOK_SPEED))

func _on_rebind_pressed() -> void:
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
