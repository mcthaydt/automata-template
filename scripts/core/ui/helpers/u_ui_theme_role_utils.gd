extends RefCounted
class_name U_UIThemeRoleUtils

const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

static func apply_menu_role(entry: Dictionary, control: Control, config: RS_UI_THEME_CONFIG, menu: Control) -> void:
	match entry.get("role", &""):
		&"heading":
			control.add_theme_font_size_override(&"font_size", config.heading)
		&"button":
			control.add_theme_font_size_override(&"font_size", config.section_header)
		&"button_column":
			control.add_theme_constant_override(&"separation", config.separation_default)
		&"main_panel":
			if config.panel_section != null:
				control.add_theme_stylebox_override(&"panel", config.panel_section)
		&"panel_padding":
			control.add_theme_constant_override(&"margin_left", config.margin_section)
			control.add_theme_constant_override(&"margin_top", config.margin_section)
			control.add_theme_constant_override(&"margin_right", config.margin_section)
			control.add_theme_constant_override(&"margin_bottom", config.margin_section)
		&"content_vbox":
			control.add_theme_constant_override(&"separation", config.separation_default)
		&"background_color":
			(control as ColorRect).color = config.bg_base
		&"title":
			control.add_theme_font_size_override(&"font_size", config.title)
		&"subheading":
			control.add_theme_font_size_override(&"font_size", config.subheading)
		&"section_header":
			control.add_theme_font_size_override(&"font_size", config.section_header)
		&"body_small":
			control.add_theme_font_size_override(&"font_size", config.body_small)
		&"text_secondary":
			control.add_theme_color_override(&"font_color", config.text_secondary)
		&"danger":
			control.add_theme_color_override(&"font_color", config.danger)
		&"separation_default":
			control.add_theme_constant_override(&"separation", config.separation_default)
		&"separation_compact":
			control.add_theme_constant_override(&"separation", config.separation_compact)
		&"h_separation_compact":
			control.add_theme_constant_override(&"h_separation", config.separation_compact)
		&"v_separation_compact":
			control.add_theme_constant_override(&"v_separation", config.separation_compact)
		&"overlay_dim":
			var dim_color := config.bg_base
			dim_color.a = float(entry.get("alpha", 0.5))
			if entry.get("apply_menu_background", false) and menu != null:
				menu.set("background_color", dim_color)
			if control is ColorRect:
				(control as ColorRect).color = dim_color
		&"line_edit_search":
			_apply_line_edit_search_role(control, config)
		&"background":
			pass

static func apply_settings_role(entry: Dictionary, control: Control, config: RS_UI_THEME_CONFIG, tab: Control) -> bool:
	var role: StringName = entry.get("role", &"")
	if role == &"overlay_dim":
		var dim_color := config.bg_base
		dim_color.a = float(entry.get("alpha", 0.5))
		if tab != null:
			tab.set("background_color", dim_color)
		if control is ColorRect:
			(control as ColorRect).color = dim_color
		return true
	match role:
		&"heading":
			control.add_theme_font_size_override(&"font_size", config.heading)
		&"section_header":
			control.add_theme_font_size_override(&"font_size", config.section_header)
			control.add_theme_color_override(&"font_color", config.section_header_color)
		&"field_label":
			control.add_theme_font_size_override(&"font_size", config.body_small)
			control.add_theme_color_override(&"font_color", config.text_secondary)
		&"field_control", &"action":
			control.add_theme_font_size_override(&"font_size", config.section_header)
		&"value_label":
			control.add_theme_font_size_override(&"font_size", config.body_small)
			control.add_theme_color_override(&"font_color", config.text_secondary)
		&"subheading":
			control.add_theme_font_size_override(&"font_size", config.subheading)
		&"body_small":
			control.add_theme_font_size_override(&"font_size", config.body_small)
		&"text_secondary":
			control.add_theme_color_override(&"font_color", config.text_secondary)
		&"danger":
			control.add_theme_color_override(&"font_color", config.danger)
		&"separation_default":
			control.add_theme_constant_override(&"separation", config.separation_default)
		&"separation_compact":
			control.add_theme_constant_override(&"separation", config.separation_compact)
		&"default_row":
			control.add_theme_constant_override(&"separation", config.separation_default)
		&"compact_row":
			control.add_theme_constant_override(&"separation", config.separation_compact)
		&"action_row":
			control.add_theme_constant_override(&"separation", config.separation_default)
		&"main_panel":
			if config.panel_section != null:
				control.add_theme_stylebox_override(&"panel", config.panel_section)
		&"content_vbox":
			control.add_theme_constant_override(&"separation", config.separation_default)
		&"panel_padding":
			control.add_theme_constant_override(&"margin_left", config.margin_section)
			control.add_theme_constant_override(&"margin_top", config.margin_section)
			control.add_theme_constant_override(&"margin_right", config.margin_section)
			control.add_theme_constant_override(&"margin_bottom", config.margin_section)
	return false

static func _apply_line_edit_search_role(control: Control, config: RS_UI_THEME_CONFIG) -> void:
	if not (control is LineEdit):
		return
	var search := control as LineEdit
	search.add_theme_font_size_override(&"font_size", config.body_small)
	var normal := StyleBoxFlat.new()
	normal.bg_color = config.bg_surface
	normal.border_color = config.bg_panel_light
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var focus := normal.duplicate(true) as StyleBoxFlat
	focus.border_color = config.accent_focus
	focus.set_border_width_all(2)
	search.add_theme_stylebox_override(&"normal", normal)
	search.add_theme_stylebox_override(&"focus", focus)
	search.add_theme_stylebox_override(&"read_only", normal.duplicate(true))
	search.add_theme_color_override(&"font_placeholder_color", config.text_secondary)
