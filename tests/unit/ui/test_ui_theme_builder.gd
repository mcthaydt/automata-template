extends GutTest

const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const RS_UI_COLOR_PALETTE := preload("res://scripts/core/resources/ui/rs_ui_color_palette.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const U_DISPLAY_UI_THEME_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_ui_theme_applier.gd")
const U_LOCALIZATION_FONT_APPLIER := preload("res://scripts/core/managers/helpers/localization/u_localization_font_applier.gd")
const UI_THEME_CONFIG_DEFAULT := preload("res://resources/core/ui/cfg_ui_theme_default.tres")

var _config: Resource = null

func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_DISPLAY_UI_THEME_APPLIER.clear_active_palette()
	_config = RS_UI_THEME_CONFIG.new()

func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_DISPLAY_UI_THEME_APPLIER.clear_active_palette()
	_config = null

func test_build_theme_returns_theme_with_font_sizes() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)

	assert_not_null(theme, "Theme should be created for valid config")
	assert_eq(theme.get_font_size(&"font_size", &"Label"), _config.body,
		"Label font_size should map to config.body")

func test_build_theme_applies_button_styleboxes() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)
	var normal := theme.get_stylebox(&"normal", &"Button")

	assert_true(normal is StyleBoxFlat, "Button normal stylebox should be StyleBoxFlat")
	assert_true(
		(normal as StyleBoxFlat).bg_color.is_equal_approx(_config.button_normal.bg_color),
		"Button normal stylebox color should match config"
	)

func test_build_theme_applies_progress_bar_styles() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)
	var fill := theme.get_stylebox(&"fill", &"ProgressBar")

	assert_true(fill is StyleBoxFlat, "ProgressBar fill stylebox should be StyleBoxFlat")

func test_build_theme_applies_slider_styles() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)
	var slider := theme.get_stylebox(&"slider", &"HSlider")

	assert_true(slider is StyleBoxFlat, "HSlider slider stylebox should be StyleBoxFlat")

func test_build_theme_applies_scrollbar_styles() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)
	var scroll_track := theme.get_stylebox(&"scroll", &"VScrollBar")
	var grabber := theme.get_stylebox(&"grabber", &"VScrollBar")
	var grabber_highlight := theme.get_stylebox(&"grabber_highlight", &"VScrollBar")

	assert_true(scroll_track is StyleBoxFlat, "VScrollBar track should use themed StyleBoxFlat")
	assert_true(grabber is StyleBoxFlat, "VScrollBar grabber should use themed StyleBoxFlat")
	assert_true(grabber_highlight is StyleBoxFlat, "VScrollBar hover grabber should use themed StyleBoxFlat")
	assert_true(
		(grabber as StyleBoxFlat).bg_color.is_equal_approx(_config.accent_primary),
		"VScrollBar grabber should use the primary accent color"
	)

func test_build_theme_applies_panel_styles() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)
	var panel := theme.get_stylebox(&"panel", &"PanelContainer")

	assert_true(panel is StyleBoxFlat, "PanelContainer panel stylebox should be StyleBoxFlat")
	if panel is StyleBoxFlat:
		assert_almost_eq(
			(panel as StyleBoxFlat).bg_color.a,
			_config.panel_section_opacity,
			0.001,
			"PanelContainer panel should honor configurable section translucency"
		)

func test_build_theme_applies_dialog_window_panel_styles() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)
	var accept_dialog_panel := theme.get_stylebox(&"panel", &"AcceptDialog")
	var confirmation_dialog_panel := theme.get_stylebox(&"panel", &"ConfirmationDialog")
	var window_panel := theme.get_stylebox(&"panel", &"Window")
	var window_border := theme.get_stylebox(&"embedded_border", &"Window")
	var window_unfocused_border := theme.get_stylebox(&"embedded_unfocused_border", &"Window")

	assert_true(accept_dialog_panel is StyleBoxFlat, "AcceptDialog panel stylebox should be StyleBoxFlat")
	assert_true(
		(accept_dialog_panel as StyleBoxFlat).bg_color.is_equal_approx(_config.panel_section.bg_color),
		"AcceptDialog panel color should match config panel_section"
	)
	assert_true(
		confirmation_dialog_panel is StyleBoxFlat,
		"ConfirmationDialog panel stylebox should be StyleBoxFlat"
	)
	assert_true(
		(confirmation_dialog_panel as StyleBoxFlat).bg_color.is_equal_approx(_config.panel_section.bg_color),
		"ConfirmationDialog panel color should match config panel_section"
	)
	assert_true(window_panel is StyleBoxFlat, "Window panel stylebox should be StyleBoxFlat")
	assert_true(
		(window_panel as StyleBoxFlat).bg_color.is_equal_approx(_config.panel_section.bg_color),
		"Window panel color should match config panel_section"
	)
	assert_true(window_border is StyleBoxFlat, "Window embedded border stylebox should be StyleBoxFlat")
	assert_true(
		(window_border as StyleBoxFlat).bg_color.is_equal_approx(_config.panel_section.bg_color),
		"Window embedded border color should match config panel_section"
	)
	assert_true(
		window_unfocused_border is StyleBoxFlat,
		"Window embedded unfocused border stylebox should be StyleBoxFlat"
	)
	assert_true(
		(window_unfocused_border as StyleBoxFlat).bg_color.is_equal_approx(_config.panel_section.bg_color),
		"Window embedded unfocused border color should match config panel_section"
	)
	assert_true(
		theme.get_color(&"title_color", &"Window").is_equal_approx(_config.text_primary),
		"Window title color should match config text_primary"
	)
	assert_true(
		theme.get_color(&"title_outline_modulate", &"Window").is_equal_approx(Color(0.0, 0.0, 0.0, 0.0)),
		"Window title outline should be transparent"
	)

func test_build_theme_applies_separator_style() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)
	var separator := theme.get_stylebox(&"separator", &"HSeparator")

	assert_true(separator is StyleBoxFlat, "HSeparator separator stylebox should be StyleBoxFlat")

func test_build_theme_applies_label_colors() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)
	var label_color := theme.get_color(&"font_color", &"Label")

	assert_true(
		label_color.is_equal_approx(_config.text_primary),
		"Label font color should match config text_primary"
	)

func test_build_theme_merges_onto_font_theme() -> void:
	var default_font := FontFile.new()
	var dyslexia_font := FontFile.new()
	var cjk_font := FontFile.new()
	var font_applier := U_LOCALIZATION_FONT_APPLIER.new()
	font_applier.set_fonts(default_font, dyslexia_font, cjk_font)

	var font_theme := font_applier.build_theme(&"en", false)
	var merged_theme := U_UI_THEME_BUILDER.build_theme(_config, font_theme)

	assert_not_null(merged_theme.get_font(&"font", &"Label"),
		"Merged theme should preserve base font assignments")
	assert_true(
		merged_theme.get_stylebox(&"normal", &"Button") is StyleBoxFlat,
		"Merged theme should include button styleboxes"
	)

func test_build_theme_standalone_without_font_theme() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config, null)

	assert_not_null(theme, "Theme should be created without a base font theme")
	assert_true(
		theme.get_stylebox(&"panel", &"PanelContainer") is StyleBoxFlat,
		"Theme should still include panel styleboxes without base font theme"
	)

func test_build_theme_null_config_returns_null() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(null)
	assert_null(theme, "Null config should produce null theme")

func test_build_theme_spacing_constants() -> void:
	var theme := U_UI_THEME_BUILDER.build_theme(_config)
	assert_eq(theme.get_constant(&"separation", &"VBoxContainer"), _config.separation_default,
		"VBoxContainer separation should map to default separation token")

func test_build_theme_merges_palette_colors() -> void:
	var palette := RS_UI_COLOR_PALETTE.new()
	palette.text = Color(0.25, 0.9, 0.4, 1.0)
	var theme := U_UI_THEME_BUILDER.build_theme(_config, null, palette)

	assert_true(
		theme.get_color(&"font_color", &"Label").is_equal_approx(palette.text),
		"Palette text color should override theme text color"
	)

func test_build_theme_without_palette_preserves_font_theme() -> void:
	var base_theme := Theme.new()
	var base_color := Color(0.9, 0.2, 0.5, 1.0)
	base_theme.set_color(&"font_color", &"Label", base_color)

	var merged_theme := U_UI_THEME_BUILDER.build_theme(_config, base_theme, null)

	assert_true(
		merged_theme.get_color(&"font_color", &"Label").is_equal_approx(base_color),
		"Builder should keep base font theme colors when palette is not provided"
	)

func test_build_theme_without_palette_falls_back_to_config_colors_when_base_missing() -> void:
	var base_theme := Theme.new()
	var merged_theme := U_UI_THEME_BUILDER.build_theme(_config, base_theme, null)

	assert_true(
		merged_theme.get_color(&"font_color", &"Label").is_equal_approx(_config.text_primary),
		"Builder should apply config text colors when base theme has no font colors and palette is missing"
	)

func test_font_applier_uses_theme_builder_when_config_set() -> void:
	U_UI_THEME_BUILDER.active_config = _config

	var applier: Variant = _make_font_applier()
	var root := Control.new()
	add_child_autofree(root)

	var theme: Theme = applier.build_theme(&"en", false)
	applier.apply_theme_to_root(root, theme)

	assert_not_null(root.theme.get_font(&"font", &"Label"),
		"Unified theme should preserve localization font assignment")
	assert_true(
		root.theme.get_stylebox(&"normal", &"Button") is StyleBoxFlat,
		"Unified theme should include styleboxes from UI theme config"
	)

func test_font_applier_unchanged_when_no_config_set() -> void:
	var applier: Variant = _make_font_applier()
	var root := Control.new()
	add_child_autofree(root)

	var theme: Theme = applier.build_theme(&"en", false)
	applier.apply_theme_to_root(root, theme)

	assert_not_null(root.theme.get_font(&"font", &"Label"),
		"Font-only theme should still be applied when no UI theme config is active")
	assert_false(root.theme.has_stylebox(&"normal", &"Button"),
		"Font-only behavior should not inject button styleboxes when no config is active")

func test_palette_change_triggers_theme_rebuild() -> void:
	U_UI_THEME_BUILDER.active_config = _config
	var applier: Variant = _make_font_applier()
	var display_theme_applier := U_DISPLAY_UI_THEME_APPLIER.new()
	var root := Control.new()
	add_child_autofree(root)

	var palette_a := RS_UI_COLOR_PALETTE.new()
	palette_a.palette_id = StringName("palette_a")
	palette_a.text = Color(1.0, 0.2, 0.2, 1.0)
	display_theme_applier.apply_theme_from_palette(palette_a)
	applier.apply_theme_to_root(root, applier.build_theme(&"en", false))

	assert_true(
		root.theme.get_color(&"font_color", &"Label").is_equal_approx(palette_a.text),
		"Initial palette text color should be applied through unified theme build"
	)

	var palette_b := RS_UI_COLOR_PALETTE.new()
	palette_b.palette_id = StringName("palette_b")
	palette_b.text = Color(0.2, 0.4, 1.0, 1.0)
	display_theme_applier.apply_theme_from_palette(palette_b)
	applier.apply_theme_to_root(root, applier.build_theme(&"en", false))

	assert_true(
		root.theme.get_color(&"font_color", &"Label").is_equal_approx(palette_b.text),
		"Changing palette should rebuild theme with updated text color"
	)
	assert_true(
		root.theme.get_stylebox(&"normal", &"Button") is StyleBoxFlat,
		"Rebuilt theme should keep styleboxes while palette changes"
	)

func test_build_theme_hydrates_runtime_style_defaults_for_loaded_config_resource() -> void:
	var loaded_config := UI_THEME_CONFIG_DEFAULT.duplicate(true)
	assert_true(loaded_config is RS_UI_THEME_CONFIG, "Default config resource should load as RS_UIThemeConfig")
	var typed_config := loaded_config as RS_UI_THEME_CONFIG
	typed_config.button_normal = null
	typed_config.panel_section = null

	var theme := U_UI_THEME_BUILDER.build_theme(typed_config)

	assert_not_null(typed_config.button_normal, "Builder should hydrate missing button style defaults")
	assert_not_null(typed_config.panel_section, "Builder should hydrate missing panel style defaults")
	assert_true(theme.has_stylebox(&"normal", &"Button"), "Built theme should include button stylebox")
	assert_true(theme.has_stylebox(&"panel", &"PanelContainer"), "Built theme should include panel stylebox")

func _make_font_applier():
	var applier: Variant = U_LOCALIZATION_FONT_APPLIER.new()
	applier.set_fonts(FontFile.new(), FontFile.new(), FontFile.new())
	return applier
