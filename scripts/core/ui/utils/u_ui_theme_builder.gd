extends RefCounted
class_name U_UIThemeBuilder

const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const RS_UI_COLOR_PALETTE := preload("res://scripts/core/resources/ui/rs_ui_color_palette.gd")
const U_UI_THEME_DEBUG := preload("res://scripts/core/ui/utils/u_ui_theme_debug.gd")

const _TEXT_COLOR_TYPES: Array[StringName] = [
	&"Control", &"Label", &"Button", &"CheckBox", &"CheckButton",
	&"OptionButton", &"LineEdit", &"TextEdit", &"RichTextLabel",
]

static var active_config: Resource = null
static var _did_log_build_summary: bool = false

static func build_theme(
	config: Resource,
	base_font_theme: Theme = null,
	palette: Resource = null
) -> Theme:
	if config == null:
		_debug_log("build_theme: config=null")
		return null
	if not (config is RS_UI_THEME_CONFIG):
		_debug_log("build_theme: config type mismatch (%s)" % config.get_class())
		return null
	var typed_config := config as RS_UI_THEME_CONFIG
	typed_config.ensure_runtime_defaults()

	var theme := _duplicate_theme_or_new(base_font_theme)

	_apply_font_sizes(theme, typed_config)
	_apply_spacing(theme, typed_config)
	_apply_button_styles(theme, typed_config)
	_apply_panel_styles(theme, typed_config)
	_apply_bar_styles(theme, typed_config)
	_apply_separator_style(theme, typed_config)
	_apply_text_colors(theme, typed_config, palette, base_font_theme != null)
	_apply_type_variations(theme, typed_config)
	_log_build_summary_once(theme, typed_config, palette, base_font_theme)
	return theme

static func _apply_type_variations(theme: Theme, config) -> void:
	theme.set_type_variation(&"TabActive", &"Button")
	theme.set_stylebox(&"normal", &"TabActive", _create_tab_active_normal(config))
	theme.set_stylebox(&"focus", &"TabActive", _create_tab_active_focus(config))
	theme.set_color(&"font_color", &"TabActive", config.text_primary)

	theme.set_type_variation(&"TabInactive", &"Button")
	theme.set_stylebox(&"normal", &"TabInactive", _create_tab_inactive_normal(config))
	theme.set_stylebox(&"hover", &"TabInactive", _create_tab_inactive_hover(config))
	theme.set_stylebox(&"focus", &"TabInactive", config.focus_stylebox)
	theme.set_color(&"font_color", &"TabInactive", config.text_secondary)

static func _create_tab_active_normal(config) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = config.bg_panel_light
	style.border_color = config.bg_panel_light
	style.set_border_width_all(0)
	style.border_width_bottom = 2
	style.border_color = config.accent_primary
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

static func _create_tab_active_focus(config) -> StyleBoxFlat:
	var style := _create_tab_active_normal(config)
	style.border_color = config.accent_focus
	style.set_border_width_all(2)
	return style

static func _create_tab_inactive_normal(config) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

static func _create_tab_inactive_hover(config) -> StyleBoxFlat:
	var style := _create_tab_inactive_normal(config)
	style.bg_color = Color(config.bg_panel_light.r, config.bg_panel_light.g, config.bg_panel_light.b, 0.4)
	return style

static func _duplicate_theme_or_new(base_theme: Theme) -> Theme:
	if base_theme == null:
		return Theme.new()
	var duplicated: Variant = base_theme.duplicate(true)
	if duplicated is Theme:
		return duplicated as Theme
	return Theme.new()

static func _apply_font_sizes(theme: Theme, config) -> void:
	theme.set_font_size(&"font_size", &"Label", config.body)
	theme.set_font_size(&"font_size", &"Button", config.body_small)
	theme.set_font_size(&"font_size", &"LineEdit", config.body_small)
	theme.set_font_size(&"font_size", &"TextEdit", config.body_small)
	theme.set_font_size(&"font_size", &"RichTextLabel", config.body_small)
	theme.set_font_size(&"font_size", &"CheckBox", config.body_small)
	theme.set_font_size(&"font_size", &"CheckButton", config.body_small)
	theme.set_font_size(&"font_size", &"OptionButton", config.body_small)
	theme.set_font_size(&"font_size", &"Tree", config.caption)
	theme.set_font_size(&"font_size", &"ItemList", config.caption)

static func _apply_spacing(theme: Theme, config) -> void:
	theme.set_constant(&"separation", &"VBoxContainer", config.separation_default)
	theme.set_constant(&"separation", &"HBoxContainer", config.separation_default)
	theme.set_constant(&"h_separation", &"GridContainer", config.separation_default)
	theme.set_constant(&"v_separation", &"GridContainer", config.separation_default)
	theme.set_constant(&"margin_left", &"MarginContainer", config.margin_outer)
	theme.set_constant(&"margin_top", &"MarginContainer", config.margin_outer)
	theme.set_constant(&"margin_right", &"MarginContainer", config.margin_outer)
	theme.set_constant(&"margin_bottom", &"MarginContainer", config.margin_outer)

static func _apply_button_styles(theme: Theme, config) -> void:
	_set_stylebox(theme, &"normal", &"Button", config.button_normal)
	_set_stylebox(theme, &"hover", &"Button", config.button_hover)
	_set_stylebox(theme, &"pressed", &"Button", config.button_pressed)
	_set_stylebox(theme, &"focus", &"Button", config.button_focus)
	_set_stylebox(theme, &"disabled", &"Button", config.button_disabled)
	_set_stylebox(theme, &"focus", &"Control", config.focus_stylebox)

static func _apply_panel_styles(theme: Theme, config) -> void:
	_set_stylebox(theme, &"panel", &"PanelContainer", config.panel_section)
	_set_stylebox(theme, &"panel", &"AcceptDialog", config.panel_section)
	_set_stylebox(theme, &"panel", &"ConfirmationDialog", config.panel_section)
	_set_stylebox(theme, &"panel", &"Window", config.panel_section)
	_set_stylebox(theme, &"embedded_border", &"Window", config.panel_section)
	_set_stylebox(theme, &"embedded_unfocused_border", &"Window", config.panel_section)
	theme.set_color(&"title_color", &"Window", config.text_primary)
	theme.set_color(&"title_outline_modulate", &"Window", Color(0.0, 0.0, 0.0, 0.0))

static func _apply_bar_styles(theme: Theme, config) -> void:
	_set_stylebox(theme, &"background", &"ProgressBar", config.progress_bar_bg)
	_set_stylebox(theme, &"fill", &"ProgressBar", config.progress_bar_fill)

	_set_stylebox(theme, &"slider", &"HSlider", config.slider_bg)
	_set_stylebox(theme, &"grabber_area", &"HSlider", config.slider_bg)
	_set_stylebox(theme, &"grabber_area_highlight", &"HSlider", config.slider_fill)
	_set_stylebox(theme, &"grabber", &"HSlider", config.slider_grabber)
	_set_stylebox(theme, &"grabber_highlight", &"HSlider", config.slider_grabber_highlight)

	_set_stylebox(theme, &"slider", &"VSlider", config.slider_bg)
	_set_stylebox(theme, &"grabber_area", &"VSlider", config.slider_bg)
	_set_stylebox(theme, &"grabber_area_highlight", &"VSlider", config.slider_fill)
	_set_stylebox(theme, &"grabber", &"VSlider", config.slider_grabber)
	_set_stylebox(theme, &"grabber_highlight", &"VSlider", config.slider_grabber_highlight)

static func _apply_separator_style(theme: Theme, config) -> void:
	_set_stylebox(theme, &"separator", &"HSeparator", config.separator_style)
	_set_stylebox(theme, &"separator", &"VSeparator", config.separator_style)

static func _apply_text_colors(
	theme: Theme,
	config,
	palette: Resource,
	preserve_base_colors: bool
) -> void:
	var has_palette: bool = palette is RS_UI_COLOR_PALETTE
	var preserve_existing: bool = preserve_base_colors and not has_palette

	var text_color: Color = config.text_primary
	var accent_primary: Color = config.accent_primary
	var accent_hover: Color = config.accent_hover
	var accent_focus: Color = config.accent_focus
	var success_color: Color = config.success
	var warning_color: Color = config.warning
	var danger_color: Color = config.danger
	var slider_fill: Color = config.slider_fill_color
	var section_header_col: Color = config.section_header_color
	var bg_base: Color = config.bg_base

	if has_palette:
		var typed_palette := palette as RS_UI_COLOR_PALETTE
		text_color = typed_palette.text
		accent_primary = typed_palette.primary
		accent_hover = typed_palette.secondary
		accent_focus = typed_palette.primary
		slider_fill = typed_palette.primary
		section_header_col = typed_palette.info
		success_color = typed_palette.success
		warning_color = typed_palette.warning
		danger_color = typed_palette.danger
		bg_base = typed_palette.background

	for type_name: StringName in _TEXT_COLOR_TYPES:
		if preserve_existing and theme.has_color(&"font_color", type_name):
			continue
		theme.set_color(&"font_color", type_name, text_color)

	_set_color_if_allowed(theme, &"font_disabled_color", &"Button", config.text_disabled, preserve_existing)
	_set_color_if_allowed(theme, &"font_pressed_color", &"Button", text_color, preserve_existing)
	_set_color_if_allowed(theme, &"font_hover_color", &"Button", text_color, preserve_existing)
	_set_color_if_allowed(theme, &"font_focus_color", &"Button", text_color, preserve_existing)

	if has_palette:
		theme.set_color(&"font_color", &"Button", text_color)
		theme.set_color(&"font_color", &"Label", text_color)

static func _set_stylebox(theme: Theme, name: StringName, type_name: StringName, stylebox: StyleBox) -> void:
	if stylebox == null:
		return
	var duplicated: Variant = stylebox.duplicate(true)
	if duplicated is StyleBox:
		theme.set_stylebox(name, type_name, duplicated as StyleBox)
		return
	theme.set_stylebox(name, type_name, stylebox)

static func _set_color_if_allowed(
	theme: Theme,
	color_name: StringName,
	type_name: StringName,
	color: Color,
	preserve_existing: bool
) -> void:
	if preserve_existing and theme.has_color(color_name, type_name):
		return
	theme.set_color(color_name, type_name, color)

static func _log_build_summary_once(
	theme: Theme,
	config: Resource,
	palette: Resource,
	base_font_theme: Theme
) -> void:
	if _did_log_build_summary:
		return
	if not U_UI_THEME_DEBUG.is_enabled():
		return
	_did_log_build_summary = true
	var typed_config := config as RS_UI_THEME_CONFIG
	var palette_id := "null"
	if palette is RS_UI_COLOR_PALETTE:
		palette_id = str((palette as RS_UI_COLOR_PALETTE).palette_id)
	_debug_log(
		"build summary: cfg_ok=true cfg_class=%s base_theme=%s palette=%s " % [
			config.get_class(),
			str(base_font_theme != null),
			palette_id,
		] +
		"button_normal_null=%s panel_section_null=%s " % [
			str(typed_config.button_normal == null),
			str(typed_config.panel_section == null),
		] +
		"has_button_style=%s has_panel_style=%s has_label_color=%s" % [
			str(theme.has_stylebox(&"normal", &"Button")),
			str(theme.has_stylebox(&"panel", &"PanelContainer")),
			str(theme.has_color(&"font_color", &"Label")),
		]
	)

static func _debug_log(message: String) -> void:
	U_UI_THEME_DEBUG.log("U_UIThemeBuilder", message)
