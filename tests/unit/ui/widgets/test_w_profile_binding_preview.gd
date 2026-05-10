extends GutTest

const W_ProfileBindingPreview := preload("res://scripts/core/ui/widgets/w_profile_binding_preview.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

func test_render_creates_grouped_and_single_binding_rows() -> void:
	var container := VBoxContainer.new()
	var profile := RS_InputProfile.new()
	profile.set_events_for_action(&"move_forward", [_key(Key.KEY_W)])
	profile.set_events_for_action(&"jump", [_key(Key.KEY_SPACE)])
	add_child_autofree(container)

	W_ProfileBindingPreview.render(container, profile, null)

	assert_eq(container.get_child_count(), 2, "Preview should render movement group and single action rows")
	assert_eq((container.get_child(0).get_child(0) as Label).text, "Move:", "First row should be the movement group")
	assert_eq((container.get_child(1).get_child(0) as Label).text, "Jump:", "Second row should be the jump action")

func test_render_clears_existing_rows() -> void:
	var container := VBoxContainer.new()
	container.add_child(Label.new())
	var profile := RS_InputProfile.new()
	profile.set_events_for_action(&"jump", [_key(Key.KEY_SPACE)])
	add_child_autofree(container)

	W_ProfileBindingPreview.render(container, profile, null)

	assert_eq(container.get_child_count(), 1, "Render should clear previous preview rows")

func test_render_applies_theme_tokens_to_rows() -> void:
	var container := VBoxContainer.new()
	var profile := RS_InputProfile.new()
	var config := RS_UI_THEME_CONFIG.new()
	config.separation_compact = 5
	config.body_small = 14
	config.text_secondary = Color(0.2, 0.4, 0.6, 1.0)
	profile.set_events_for_action(&"jump", [_key(Key.KEY_SPACE)])
	add_child_autofree(container)

	W_ProfileBindingPreview.render(container, profile, config)

	var row := container.get_child(0) as HBoxContainer
	var label := row.get_child(0) as Label
	assert_eq(row.get_theme_constant(&"separation"), 5)
	assert_eq(label.get_theme_font_size(&"font_size"), 14)
	assert_true(label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary))

func _key(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	return event
