extends GutTest

const BUILDER_PATH := "res://scripts/core/ui/helpers/u_settings_tab_builder.gd"
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")

var _dropdown_selected: int = -1
var _toggle_value: bool = false
var _slider_value: float = -1.0
var _pressed_buttons: Array[String] = []


func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	_dropdown_selected = -1
	_toggle_value = false
	_slider_value = -1.0
	_pressed_buttons.clear()


func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null


func test_builder_creates_controls_and_applies_theme_tokens() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 41
	config.section_header = 19
	config.body_small = 13
	config.text_secondary = Color(0.25, 0.5, 0.75, 1.0)
	U_UI_THEME_BUILDER.active_config = config
	var tab := VBoxContainer.new()
	add_child_autofree(tab)

	var options: Array[Dictionary] = [
		{"id": &"low", "label_key": &"settings.display.option.quality.low", "value": &"low"},
		{"id": &"high", "label_key": &"settings.display.option.quality.high", "value": &"high"},
	]
	var builder = builder_script.new(tab)
	var chain_result = builder.set_heading(&"settings.display.title")
	assert_eq(chain_result, builder, "Fluent methods should return the builder")

	var built_tab = builder.begin_section(&"settings.display.section.graphics") \
		.add_dropdown(&"settings.display.label.quality", options, _on_dropdown_selected) \
		.add_toggle(&"settings.display.label.vsync", _on_toggle_changed) \
		.add_slider(&"settings.display.label.ui_scale", 0.8, 1.3, 0.1, _on_slider_changed, &"settings.display.value.percent") \
		.end_section() \
		.add_action_buttons(_on_apply_pressed, _on_cancel_pressed, _on_reset_pressed) \
		.build()

	assert_eq(built_tab, tab, "build should return the parent tab")
	var heading := _find_label(tab, "settings.display.title")
	var section := _find_label(tab, "settings.display.section.graphics")
	var dropdown := _find_first(tab, OptionButton) as OptionButton
	var toggle := _find_first(tab, CheckBox) as CheckBox
	var slider := _find_first(tab, HSlider) as HSlider
	var buttons := _collect_buttons(tab)

	assert_not_null(heading, "Heading label should be created")
	assert_not_null(section, "Section label should be created")
	assert_eq(heading.get_theme_font_size(&"font_size"), config.heading, "Heading should use heading font size")
	assert_eq(section.get_theme_font_size(&"font_size"), config.section_header, "Section should use section font size")
	assert_true(section.get_theme_color(&"font_color").is_equal_approx(config.section_header_color), "Section should use section color")
	assert_eq(dropdown.item_count, 2, "Dropdown should be populated")
	assert_eq(dropdown.get_theme_font_size(&"font_size"), config.section_header, "Dropdown should use section font size")
	assert_eq(toggle.get_theme_font_size(&"font_size"), config.section_header, "Toggle should use section font size")
	assert_eq(slider.min_value, 0.8, "Slider min should match builder input")
	assert_eq(slider.max_value, 1.3, "Slider max should match builder input")
	assert_eq(slider.step, 0.1, "Slider step should match builder input")
	assert_eq(buttons.size(), 3, "Action buttons should be created")


func test_builder_wires_signals_and_focus_chain() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	var options: Array[Dictionary] = [{"id": &"on", "label_key": &"settings.display.option.vsync.enabled"}]

	builder_script.new(tab) \
		.add_dropdown(&"settings.display.label.quality", options, _on_dropdown_selected) \
		.add_toggle(&"settings.display.label.vsync", _on_toggle_changed) \
		.add_slider(&"settings.display.label.ui_scale", 0.8, 1.3, 0.1, _on_slider_changed) \
		.add_action_buttons(_on_apply_pressed, _on_cancel_pressed, _on_reset_pressed) \
		.build()

	var dropdown := _find_first(tab, OptionButton) as OptionButton
	var toggle := _find_first(tab, CheckBox) as CheckBox
	var slider := _find_first(tab, HSlider) as HSlider
	var buttons := _collect_buttons(tab)
	dropdown.item_selected.emit(0)
	toggle.toggled.emit(true)
	slider.value_changed.emit(1.1)
	buttons[0].pressed.emit()
	buttons[1].pressed.emit()
	buttons[2].pressed.emit()

	assert_eq(_dropdown_selected, 0, "Dropdown callback should fire")
	assert_true(_toggle_value, "Toggle callback should fire")
	assert_eq(_slider_value, 1.1, "Slider callback should fire")
	assert_eq(_pressed_buttons, ["apply", "cancel", "reset"], "Action callbacks should fire")
	assert_eq(dropdown.focus_neighbor_bottom, dropdown.get_path_to(toggle), "Focusable controls should use vertical chain")
	assert_eq(toggle.focus_neighbor_bottom, toggle.get_path_to(slider), "Toggle should point to slider")


func test_builder_refreshes_localization_and_theme() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	var builder = builder_script.new(tab).set_heading(&"settings.audio.title")
	builder.build()
	var heading := _find_label(tab, "settings.audio.title")
	assert_not_null(heading, "Heading should be localized through fallback key")

	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 36
	builder.apply_theme_tokens(config)
	builder.localize_labels()
	assert_eq(heading.get_theme_font_size(&"font_size"), 36, "Theme refresh should re-apply heading font")
	assert_eq(heading.text, "settings.audio.title", "Localization refresh should keep fallback key text")


func test_builder_can_bind_existing_controls() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 34
	U_UI_THEME_BUILDER.active_config = config
	var tab := VBoxContainer.new()
	var heading := Label.new()
	var option := OptionButton.new()
	tab.add_child(heading)
	tab.add_child(option)
	add_child_autofree(tab)

	var builder = builder_script.new(tab)
	assert_eq(builder.bind_heading(heading, &"settings.display.title"), builder, "Binding should be fluent")
	builder.bind_field_control(option, _on_dropdown_selected).build()
	option.item_selected.emit(2)

	assert_eq(heading.text, "settings.display.title", "Bound label should localize")
	assert_eq(heading.get_theme_font_size(&"font_size"), 34, "Bound label should theme")
	assert_eq(_dropdown_selected, 2, "Bound control should wire callback")


func _get_builder_script() -> GDScript:
	if not ResourceLoader.exists(BUILDER_PATH):
		assert_true(false, "U_SettingsTabBuilder script should exist")
		return null
	var builder_script := load(BUILDER_PATH) as GDScript
	assert_not_null(builder_script, "U_SettingsTabBuilder script should load")
	return builder_script


func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child in node.get_children():
		var result := _find_label(child, text)
		if result != null:
			return result
	return null


func _find_first(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var result := _find_first(child, type)
		if result != null:
			return result
	return null


func _collect_buttons(node: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if node is Button and not (node is OptionButton or node is CheckBox or node is LinkButton or node is MenuButton or node is TextureButton):
		buttons.append(node as Button)
	for child in node.get_children():
		buttons.append_array(_collect_buttons(child))
	return buttons


func _on_dropdown_selected(index: int) -> void:
	_dropdown_selected = index


func _on_toggle_changed(value: bool) -> void:
	_toggle_value = value


func _on_slider_changed(value: float) -> void:
	_slider_value = value


func _on_apply_pressed() -> void:
	_pressed_buttons.append("apply")


func _on_cancel_pressed() -> void:
	_pressed_buttons.append("cancel")


func _on_reset_pressed() -> void:
	_pressed_buttons.append("reset")


func test_add_dropdown_creates_fully_wired_control() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var options: Array[Dictionary] = [
		{"id": &"low", "label_key": &"settings.display.option.quality.low", "value": &"low"},
		{"id": &"high", "label_key": &"settings.display.option.quality.high", "value": &"high"},
	]
	
	var builder = builder_script.new(tab)
	var built_tab = builder.add_dropdown(&"settings.display.label.quality", options, _on_dropdown_selected).build()
	
	var dropdown := _find_first(tab, OptionButton) as OptionButton
	assert_not_null(dropdown, "Dropdown should be created by add_dropdown")
	assert_eq(dropdown.item_count, 2, "Dropdown should have 2 items")
	assert_true(dropdown.get_parent() is HBoxContainer, "Dropdown should be in a row container")
	
	_dropdown_selected = -1
	dropdown.item_selected.emit(0)
	assert_eq(_dropdown_selected, 0, "Signal should be wired")


func test_add_toggle_creates_fully_wired_control() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = builder_script.new(tab)
	var built_tab = builder.add_toggle(&"settings.display.label.vsync", _on_toggle_changed).build()
	
	var toggle := _find_first(tab, CheckBox) as CheckBox
	assert_not_null(toggle, "Toggle should be created by add_toggle")
	assert_true(toggle.get_parent() is HBoxContainer, "Toggle should be in a row container")
	
	_toggle_value = false
	toggle.toggled.emit(true)
	assert_true(_toggle_value, "Signal should be wired")


func test_add_slider_creates_fully_wired_control_with_value_label() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = builder_script.new(tab)
	var built_tab = builder.add_slider(
		&"settings.display.label.ui_scale",
		0.8, 1.3, 0.1,
		_on_slider_changed,
		&"settings.display.value.percent"
	).build()
	
	var slider := _find_first(tab, HSlider) as HSlider
	var value_label := _find_first(tab, Label) as Label
	assert_not_null(slider, "Slider should be created by add_slider")
	assert_not_null(value_label, "Value label should be created by add_slider")
	assert_true(slider.get_parent() is HBoxContainer, "Slider should be in a row container")
	assert_eq(slider.min_value, 0.8, "Slider min should match builder input")
	assert_eq(slider.max_value, 1.3, "Slider max should match builder input")
	assert_eq(slider.step, 0.1, "Slider step should match builder input")
	
	_slider_value = -1.0
	slider.value_changed.emit(1.1)
	assert_eq(_slider_value, 1.1, "Signal should be wired")


func test_add_dropdown_with_tooltip_sets_tooltip_text() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var options: Array[Dictionary] = [
		{"id": &"low", "label_key": &"settings.display.option.quality.low", "value": &"low"},
	]
	
	var builder = builder_script.new(tab)
	builder.add_dropdown(
		&"settings.display.label.quality",
		options,
		_on_dropdown_selected,
		&"settings.display.tooltip.quality",
		"Quality settings tooltip"
	).build()
	
	var dropdown := _find_first(tab, OptionButton) as OptionButton
	assert_not_null(dropdown, "Dropdown should be created")
	assert_ne(dropdown.tooltip_text, "", "Tooltip should be set when tooltip_key provided")


func test_add_toggle_with_tooltip_sets_tooltip_text() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = builder_script.new(tab)
	builder.add_toggle(
		&"settings.display.label.vsync",
		_on_toggle_changed,
		&"settings.display.tooltip.vsync",
		"VSync tooltip"
	).build()
	
	var toggle := _find_first(tab, CheckBox) as CheckBox
	assert_not_null(toggle, "Toggle should be created")
	assert_ne(toggle.tooltip_text, "", "Tooltip should be set when tooltip_key provided")


func test_add_slider_with_tooltip_sets_tooltip_text() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = builder_script.new(tab)
	builder.add_slider(
		&"settings.display.label.ui_scale",
		0.8, 1.3, 0.1,
		_on_slider_changed,
		&"",
		&"settings.display.tooltip.ui_scale",
		"UI Scale tooltip"
	).build()
	
	var slider := _find_first(tab, HSlider) as HSlider
	assert_not_null(slider, "Slider should be created")
	assert_ne(slider.tooltip_text, "", "Tooltip should be set when tooltip_key provided")


func test_add_button_row_creates_three_buttons() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	
	var builder = builder_script.new(tab)
	builder.add_button_row(
		_on_apply_pressed,
		_on_cancel_pressed,
		_on_reset_pressed
	).build()
	
	var buttons := _collect_buttons(tab)
	assert_eq(buttons.size(), 3, "Should create 3 buttons")
	
	var apply_btn := _find_button_by_name(tab, "ApplyButton")
	var cancel_btn := _find_button_by_name(tab, "CancelButton")
	var reset_btn := _find_button_by_name(tab, "ResetButton")
	
	assert_not_null(apply_btn, "ApplyButton should exist")
	assert_not_null(cancel_btn, "CancelButton should exist")
	assert_not_null(reset_btn, "ResetButton should exist")
	
	_pressed_buttons.clear()
	apply_btn.pressed.emit()
	cancel_btn.pressed.emit()
	reset_btn.pressed.emit()
	assert_eq(_pressed_buttons, ["apply", "cancel", "reset"], "All buttons should be wired")


func test_begin_section_accepts_and_uses_fallback_text() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	var builder = builder_script.new(tab)
	builder.begin_section(&"missing.section.key", "TestSection", "Section Fallback")
	builder.build()
	var section := tab.find_child("TestSection", true, false)
	assert_not_null(section, "Section container should be created")
	var label: Label = null
	for child in section.get_children():
		if child is Label:
			label = child as Label
			break
	assert_not_null(label, "Section should contain a label")
	assert_eq(label.text, "Section Fallback", "begin_section should use fallback text when key missing")


func test_add_dropdown_uses_fallback_text_when_key_missing() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	var options: Array[Dictionary] = [{"id": &"a", "label_key": &"a"}]
	builder_script.new(tab).add_dropdown(&"missing.dropdown.key", options, _on_dropdown_selected, &"", "Dropdown Fallback").build()
	var label := _find_label(tab, "Dropdown Fallback")
	assert_not_null(label, "Dropdown label should use fallback text when key missing")
	assert_true(label.get_parent() is HBoxContainer, "Dropdown label should be in a row")


func test_add_toggle_uses_fallback_text_when_key_missing() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	builder_script.new(tab).add_toggle(&"missing.toggle.key", _on_toggle_changed, &"", "Toggle Fallback").build()
	var label := _find_label(tab, "Toggle Fallback")
	assert_not_null(label, "Toggle label should use fallback text when key missing")
	assert_true(label.get_parent() is HBoxContainer, "Toggle label should be in a row")


func test_add_slider_uses_fallback_text_when_key_missing() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	builder_script.new(tab).add_slider(
		&"missing.slider.key",
		0.0, 1.0, 0.1,
		_on_slider_changed,
		&"",
		&"",
		"Slider Fallback"
	).build()
	var label := _find_label(tab, "Slider Fallback")
	assert_not_null(label, "Slider label should use fallback text when key missing")
	assert_true(label.get_parent() is HBoxContainer, "Slider label should be in a row")


func test_toggle_controls_do_not_expand_to_full_row_width():
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	var builder = builder_script.new(tab)
	builder.add_toggle(&"settings.test.toggle", Callable(), &"", "Toggle", "TestToggle")
	builder.build()

	var toggle := tab.find_child("TestToggle", true, false) as CheckBox
	assert_not_null(toggle, "Builder should create toggle")
	assert_eq(toggle.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "Toggles should keep natural width")


func test_dropdown_controls_use_consistent_field_width():
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var tab := VBoxContainer.new()
	add_child_autofree(tab)
	var builder = builder_script.new(tab)
	var opts: Array[Dictionary] = [{"id": &"one", "label_key": &"one"}]
	builder.add_dropdown(&"settings.test.dropdown", opts, Callable(), &"", "Dropdown", "TestOption")
	builder.build()

	var dropdown := tab.find_child("TestOption", true, false) as OptionButton
	assert_not_null(dropdown, "Builder should create dropdown")
	assert_eq(dropdown.custom_minimum_size.x, 360.0, "Dropdowns should have stable field width")


func _find_button_by_name(node: Node, name: String) -> Button:
	if node is Button and node.name == name:
		return node as Button
	for child in node.get_children():
		var result := _find_button_by_name(child, name)
		if result != null:
			return result
	return null
