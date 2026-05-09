extends RefCounted
class_name W_ProfileBindingPreview

const ACTION_LABEL_KEYS := {
	&"move": &"input.action.move",
	&"jump": &"input.action.jump",
	&"sprint": &"input.action.sprint",
	&"interact": &"input.action.interact",
	&"pause": &"input.action.pause",
}
const SINGLE_ACTIONS := [&"jump", &"sprint", &"interact", &"pause"]
const MOVE_ACTIONS := [&"move_forward", &"move_backward", &"move_left", &"move_right"]

static func render(container: VBoxContainer, profile: RS_InputProfile, theme_config: RS_UIThemeConfig) -> void:
	clear(container)
	if container == null or profile == null:
		return
	_add_group_row(container, _localized_action_label(&"move"), MOVE_ACTIONS, profile, theme_config)
	for action in SINGLE_ACTIONS:
		_add_action_row(container, _localized_action_label(action), action, profile, theme_config)

static func clear(container: VBoxContainer) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.free()

static func _add_group_row(container: VBoxContainer, group_label: String, actions: Array, profile: RS_InputProfile, config: RS_UIThemeConfig) -> void:
	var has_any_binding := false
	for action_name in actions:
		if not profile.get_events_for_action(action_name).is_empty():
			has_any_binding = true
			break
	if not has_any_binding:
		return
	var row := _create_row(group_label, config)
	var icons_container := row.get_child(1) as HBoxContainer
	for action_name in actions:
		_add_binding_icons_for_action(icons_container, action_name, profile, config)
	container.add_child(row)

static func _add_action_row(container: VBoxContainer, action_label: String, action_name: StringName, profile: RS_InputProfile, config: RS_UIThemeConfig) -> void:
	if profile.get_events_for_action(action_name).is_empty():
		return
	var row := _create_row(action_label, config)
	_add_binding_icons_for_action(row.get_child(1) as HBoxContainer, action_name, profile, config)
	container.add_child(row)

static func _create_row(label_text: String, config: RS_UIThemeConfig) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var label := Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(100, 0)
	row.add_child(label)
	var icons_container := HBoxContainer.new()
	icons_container.add_theme_constant_override(&"separation", 4)
	row.add_child(icons_container)
	_apply_row_theme(row, label, icons_container, config)
	return row

static func _add_binding_icons_for_action(container: HBoxContainer, action: StringName, profile: RS_InputProfile, config: RS_UIThemeConfig) -> void:
	var events := profile.get_events_for_action(action)
	for i in range(events.size()):
		var event: InputEvent = events[i]
		if event == null:
			continue
		var texture: Texture2D = U_InputRebindUtils.get_texture_for_event(event)
		if texture != null:
			container.add_child(_texture_rect(texture))
		else:
			container.add_child(_event_label(event, config))
		if i < events.size() - 1:
			container.add_child(_separator_label(config))

static func _texture_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(24, 24)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect

static func _event_label(event: InputEvent, config: RS_UIThemeConfig) -> Label:
	var label := Label.new()
	label.text = U_InputRebindUtils.format_binding_label(U_InputRebindUtils.format_event_label(event))
	_apply_event_label_theme(label, config, false)
	return label

static func _separator_label(config: RS_UIThemeConfig) -> Label:
	var label := Label.new()
	label.text = ", "
	_apply_event_label_theme(label, config, true)
	return label

static func _apply_row_theme(row: HBoxContainer, label: Label, icons_container: HBoxContainer, config: RS_UIThemeConfig) -> void:
	if config == null:
		return
	row.add_theme_constant_override(&"separation", config.separation_compact)
	icons_container.add_theme_constant_override(&"separation", config.separation_compact)
	label.add_theme_font_size_override(&"font_size", config.body_small)
	label.add_theme_color_override(&"font_color", config.text_secondary)

static func _apply_event_label_theme(label: Label, config: RS_UIThemeConfig, separator: bool) -> void:
	if config == null:
		return
	label.add_theme_color_override(&"font_color", config.text_disabled if separator else config.text_secondary)
	if config.caption > 0:
		label.add_theme_font_size_override(&"font_size", config.caption)

static func _localized_action_label(action_name: StringName) -> String:
	var key: StringName = ACTION_LABEL_KEYS.get(action_name, StringName())
	if key == StringName():
		return String(action_name).capitalize()
	var localized := U_LocalizationUtils.localize(key)
	if localized == String(key):
		return String(action_name).capitalize()
	return localized
