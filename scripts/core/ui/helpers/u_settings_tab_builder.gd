extends RefCounted
class_name U_SettingsTabBuilder
const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_THEME_ROLE_UTILS := preload("res://scripts/core/ui/helpers/u_ui_theme_role_utils.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const CFG_MOTION_BUTTON_DEFAULT := preload("res://resources/core/ui/motions/cfg_motion_button_default.tres")
var _tab: Control = null
var _current_parent: Control = null
var _label_keys: Dictionary = {}
var _label_fallbacks: Dictionary = {}
var _theme_map: Array[Dictionary] = []
var _focusable_controls: Array[Control] = []
var _inline_group_row: HBoxContainer = null
var _inline_group_item_count: int = 0
func _init(tab: Control) -> void:
	_tab = tab
	_current_parent = tab
func set_heading(key: StringName) -> U_SettingsTabBuilder:
	var label := _add_label(key, _tab)
	label.name = "HeadingLabel"
	_theme_map.append({"control": label, "role": &"heading"})
	return self
func bind_heading(label: Label, key: StringName, fallback: String = "") -> U_SettingsTabBuilder:
	_bind_label(label, key, &"heading", fallback)
	return self
func bind_section_header(label: Label, key: StringName, fallback: String = "") -> U_SettingsTabBuilder:
	_bind_label(label, key, &"section_header", fallback)
	return self
func bind_field_label(label: Label, key: StringName, fallback: String = "") -> U_SettingsTabBuilder:
	_bind_label(label, key, &"field_label", fallback)
	return self
func bind_value_label(label: Label, key: StringName = &"", fallback: String = "") -> U_SettingsTabBuilder:
	_bind_label(label, key, &"value_label", fallback)
	return self
func bind_row(row: Control, compact: bool = false) -> U_SettingsTabBuilder:
	if row != null:
		_theme_map.append({"control": row, "role": &"compact_row" if compact else &"default_row"})
	return self
func bind_field_control(control: Control, callback: Callable = Callable()) -> U_SettingsTabBuilder:
	if control == null:
		return self
	_theme_map.append({"control": control, "role": &"field_control"})
	_focusable_controls.append(control)
	_wire_control_callback(control, callback)
	return self

func bind_action_button(button: Button, key: StringName, callback: Callable = Callable(), fallback: String = "") -> U_SettingsTabBuilder:
	if button == null:
		return self
	_label_keys[button] = key
	if fallback != "":
		_label_fallbacks[button] = fallback
	_theme_map.append({"control": button, "role": &"action"})
	_focusable_controls.append(button)
	_connect(button.pressed, callback)
	return self
func begin_section(key: StringName, section_name: String = "Section", fallback: String = "") -> U_SettingsTabBuilder:
	var section := VBoxContainer.new()
	section.name = section_name + "Section" if section_name.ends_with("Header") else section_name
	_tab.add_child(section)
	_current_parent = section
	var label := _add_label(key, section, fallback)
	label.name = section_name if section_name.ends_with("Header") else "SectionHeader"
	_theme_map.append({"control": label, "role": &"section_header"})
	return self
func end_section() -> U_SettingsTabBuilder:
	_current_parent = _tab
	return self

func begin_inline_group(group_name: String = "") -> U_SettingsTabBuilder:
	var row := HBoxContainer.new()
	row.name = group_name + "Row" if group_name != "" else "InlineGroupRow"
	_current_parent.add_child(row)
	_theme_map.append({"control": row, "role": &"default_row"})
	_inline_group_row = row
	_inline_group_item_count = 0
	return self
func end_inline_group() -> U_SettingsTabBuilder:
	_inline_group_row = null
	_inline_group_item_count = 0
	return self

func add_dropdown(key: StringName, options: Array[Dictionary], callback: Callable, tooltip_key: StringName = &"", fallback: String = "", custom_name: String = "") -> U_SettingsTabBuilder:
	var is_inline: bool = _inline_group_row != null
	var row: HBoxContainer = _inline_group_row if is_inline else _add_row()
	var label := _add_label(key, row, fallback)
	if custom_name != "":
		var label_name := custom_name.replace("Option", "Label")
		label.name = label_name if label_name != custom_name else custom_name + "Label"
	label.custom_minimum_size = Vector2(0, 0) if (is_inline and _inline_group_item_count > 0) else Vector2(180, 0)
	var dropdown := OptionButton.new()
	dropdown.name = custom_name if custom_name != "" else key.capitalize().replace(" ", "") + "Option"
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dropdown)
	for option in options:
		dropdown.add_item(_localize(option.get("label_key", key), str(option.get("id", ""))))
	_connect(dropdown.item_selected, callback)
	_register_field(label, dropdown)
	_apply_tooltip(dropdown, tooltip_key)
	if is_inline:
		_inline_group_item_count += 1
	return self

func add_toggle(key: StringName, callback: Callable, tooltip_key: StringName = &"", fallback: String = "", custom_name: String = "") -> U_SettingsTabBuilder:
	var is_inline: bool = _inline_group_row != null
	var row: HBoxContainer = _inline_group_row if is_inline else _add_row()
	var label := _add_label(key, row, fallback)
	if custom_name != "":
		var label_name := custom_name.replace("Toggle", "Label").replace("CheckButton", "Label")
		label.name = label_name if label_name != custom_name else custom_name + "Label"
	label.custom_minimum_size = Vector2(0, 0) if (is_inline and _inline_group_item_count > 0) else Vector2(180, 0)
	var toggle := CheckBox.new()
	toggle.name = custom_name if custom_name != "" else key.capitalize().replace(" ", "") + "Toggle"
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(toggle)
	_connect(toggle.toggled, callback)
	_register_field(label, toggle)
	_apply_tooltip(toggle, tooltip_key)
	if is_inline:
		_inline_group_item_count += 1
	return self

func add_slider(key: StringName, min_val: float, max_val: float, step: float, callback: Callable, _value_label_key: StringName = &"", tooltip_key: StringName = &"", fallback: String = "", custom_name: String = "") -> U_SettingsTabBuilder:
	var is_inline: bool = _inline_group_row != null
	var row: HBoxContainer = _inline_group_row if is_inline else _add_row()
	var label := _add_label(key, row, fallback)
	if custom_name != "":
		var label_name := custom_name.replace("Slider", "Label")
		label.name = label_name if label_name != custom_name else custom_name + "Label"
	label.custom_minimum_size = Vector2(0, 0) if (is_inline and _inline_group_item_count > 0) else Vector2(180, 0)
	var slider := HSlider.new()
	slider.name = custom_name if custom_name != "" else key.capitalize().replace(" ", "") + "Slider"
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := _create_slider_value_label(key, custom_name)
	row.add_child(value_label)
	var update_label := func(value: float) -> void: value_label.text = str(value)
	_connect(slider.value_changed, callback)
	slider.value_changed.connect(update_label)
	_register_field(label, slider)
	_theme_map.append({"control": value_label, "role": &"value_label"})
	_apply_tooltip(slider, tooltip_key)
	if is_inline:
		_inline_group_item_count += 1
	return self

func _create_slider_value_label(key: StringName, custom_name: String = "") -> Label:
	var label := Label.new()
	var base_name := custom_name if custom_name != "" else key.capitalize().replace(" ", "")
	label.name = base_name + "Value"
	return label

func _apply_tooltip(control: Control, tooltip_key: StringName) -> void:
	if tooltip_key != &"":
		control.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(tooltip_key, str(tooltip_key))
func set_tooltip(key: StringName, tooltip_text: String) -> U_SettingsTabBuilder:
	for entry in _theme_map:
		if entry.get("role") == &"field_control":
			var control := entry.get("control") as Control
			if control != null and control.name.to_lower().contains(key.to_lower().replace(".", "").replace("_", "")):
					control.tooltip_text = tooltip_text
	return self
func hide_control_by_key(key: StringName) -> U_SettingsTabBuilder:
	for entry in _theme_map:
		if entry.get("role") == &"field_control":
			var control := entry.get("control") as Control
			if control != null and control.name.to_lower().contains(key.to_lower().replace(".", "").replace("_", "")):
				var row := control.get_parent()
				if row is Control:
					(row as Control).visible = false
	return self
func add_action_buttons(
	apply_callback: Callable, cancel_callback: Callable, reset_callback: Callable,
	apply_fallback: String = "Apply", cancel_fallback: String = "Cancel", reset_fallback: String = "Reset"
) -> U_SettingsTabBuilder:
	return add_button_row(
		apply_callback, cancel_callback, reset_callback, &"common.apply", &"common.cancel", &"common.reset",
		apply_fallback, cancel_fallback, reset_fallback
	)
func add_button_row(
	apply_callback: Callable,
	cancel_callback: Callable,
	reset_callback: Callable,
	apply_key: StringName = &"common.apply",
	cancel_key: StringName = &"common.cancel",
	reset_key: StringName = &"common.reset",
	apply_fallback: String = "Apply",
	cancel_fallback: String = "Cancel",
	reset_fallback: String = "Reset"
) -> U_SettingsTabBuilder:
	var row := HBoxContainer.new()
	row.name = "ActionButtons"
	_current_parent.add_child(row)
	_theme_map.append({"control": row, "role": &"compact_row"})
	_add_optional_button(row, apply_key, apply_callback, apply_fallback, "ApplyButton")
	_add_optional_button(row, cancel_key, cancel_callback, cancel_fallback, "CancelButton")
	_add_optional_button(row, reset_key, reset_callback, reset_fallback, "ResetButton")
	return self
func build() -> Control:
	apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
	localize_labels()
	if not _focusable_controls.is_empty():
		U_FOCUS_CONFIGURATOR.configure_vertical_focus(_focusable_controls, true)
		for control: Control in _focusable_controls:
			U_UIMotion.bind_interactive(control, CFG_MOTION_BUTTON_DEFAULT)
	return _tab
func localize_labels() -> void:
	for control in _label_keys.keys():
		var fallback: String = _label_fallbacks.get(control, str(_label_keys[control]))
		if control is Label:
			(control as Label).text = _localize(_label_keys[control], fallback)
		elif control is Button:
			(control as Button).text = _localize(_label_keys[control], fallback)
func apply_theme_tokens(config: Resource) -> void:
	if not (config is RS_UI_THEME_CONFIG):
		return
	var theme_config := config as RS_UI_THEME_CONFIG
	for entry in _theme_map:
		_apply_theme_entry(entry, theme_config)
func _add_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SettingRow"
	_current_parent.add_child(row)
	_theme_map.append({"control": row, "role": &"default_row"})
	return row

func _add_label(key: StringName, parent: Control, fallback: String = "") -> Label:
	var label := Label.new()
	var fb: String = fallback if fallback != "" else str(key)
	label.text = _localize(key, fb)
	parent.add_child(label)
	_label_keys[label] = key
	if fallback != "":
		_label_fallbacks[label] = fallback
	return label

func _add_button(parent: Control, key: StringName, callback: Callable, fallback: String = "") -> Button:
	var button := Button.new()
	var fb: String = fallback if fallback != "" else str(key)
	button.text = _localize(key, fb)
	parent.add_child(button)
	_label_keys[button] = key
	if fallback != "":
		_label_fallbacks[button] = fallback
	_theme_map.append({"control": button, "role": &"action"})
	_focusable_controls.append(button)
	_connect(button.pressed, callback)
	return button

func _add_optional_button(parent: Control, key: StringName, callback: Callable, fallback: String, button_name: String) -> Button:
	if key == &"" and fallback == "" and not callback.is_valid():
		return null
	var button := _add_button(parent, key, callback, fallback)
	button.name = button_name
	return button

func _register_field(label: Label, control: Control) -> void:
	_theme_map.append({"control": label, "role": &"field_label"})
	_theme_map.append({"control": control, "role": &"field_control"})
	_focusable_controls.append(control)

func _bind_label(label: Label, key: StringName, role: StringName, fallback: String = "") -> void:
	if label == null:
		return
	_label_keys[label] = key
	if fallback != "":
		_label_fallbacks[label] = fallback
	_theme_map.append({"control": label, "role": role})

func bind_panel(panel: PanelContainer, content_vbox: VBoxContainer = null, padding: MarginContainer = null) -> U_SettingsTabBuilder:
	if panel != null:
		_theme_map.append({"control": panel, "role": &"main_panel"})
	if content_vbox != null:
		_theme_map.append({"control": content_vbox, "role": &"content_vbox"})
	if padding != null:
		_theme_map.append({"control": padding, "role": &"panel_padding"})
	return self

func bind_overlay_background(alpha: float, overlay_background: ColorRect = null) -> U_SettingsTabBuilder:
	_theme_map.append({"control": overlay_background, "role": &"overlay_dim", "alpha": alpha})
	return self

func bind_theme_role(control: Control, role: StringName, extras: Dictionary = {}) -> U_SettingsTabBuilder:
	if control == null:
		return self
	var entry: Dictionary = {"control": control, "role": role}
	for key in extras.keys():
		entry[key] = extras[key]
	_theme_map.append(entry)
	return self

func _wire_control_callback(control: Control, callback: Callable) -> void:
	if callback == Callable():
		return
	if control is OptionButton:
		_connect((control as OptionButton).item_selected, callback)
	elif control is BaseButton:
		_connect((control as BaseButton).toggled, callback)
	elif control is Range:
		_connect((control as Range).value_changed, callback)

func _connect(signal_ref: Signal, callback: Callable) -> void:
	if callback.is_valid() and not signal_ref.is_connected(callback):
		signal_ref.connect(callback)

func _localize(key: Variant, fallback: String) -> String:
	if key is StringName:
		return U_LOCALIZATION_UTILS.localize_with_fallback(key, fallback)
	return fallback

func _apply_theme_entry(entry: Dictionary, config: RS_UI_THEME_CONFIG) -> void:
	var control := entry.get("control") as Control
	if control == null:
		return
	U_UI_THEME_ROLE_UTILS.apply_settings_role(entry, control, config, _tab)