extends GutTest

const LOADING_SCREEN_SCENE := preload("res://scenes/core/ui/hud/ui_loading_screen.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _loading_screen: Control = null

func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null

func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	_loading_screen = null

func test_loading_screen_applies_theme_tokens_when_active_config_set() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.bg_base = Color(0.08, 0.09, 0.13, 1.0)
	config.margin_outer = 22
	config.title = 52
	config.heading = 34
	config.body_small = 19
	config.section_header = 13
	config.health_bg = Color(0.18, 0.24, 0.41, 1.0)
	config.success = Color(0.45, 0.75, 0.30, 1.0)
	config.progress_bar_bg = null
	config.progress_bar_fill = null
	U_UI_THEME_BUILDER.active_config = config

	_loading_screen = LOADING_SCREEN_SCENE.instantiate() as Control
	_loading_screen.theme = U_UI_THEME_BUILDER.build_theme(config)
	add_child_autofree(_loading_screen)
	await get_tree().process_frame

	var background_image := _loading_screen.get_node_or_null("BackgroundImage") as TextureRect
	var content := _loading_screen.get_node_or_null("CenterContainer/VBoxContainer") as VBoxContainer
	var logo_label := _loading_screen.get_node_or_null("CenterContainer/VBoxContainer/LogoLabel") as Label
	var spinner_label := _loading_screen.get_node_or_null("CenterContainer/VBoxContainer/SpinnerLabel") as Label
	var status_label := _loading_screen.get_node_or_null("CenterContainer/VBoxContainer/StatusLabel") as Label
	var tip_label := _loading_screen.get_node_or_null("CenterContainer/VBoxContainer/TipLabel") as Label
	var progress_bar := _loading_screen.get_node_or_null("CenterContainer/VBoxContainer/ProgressBar") as ProgressBar

	assert_not_null(background_image, "Loading screen should have a BackgroundImage node")
	assert_not_null(content, "Loading screen content container should exist")
	assert_not_null(logo_label, "Logo label should exist")
	assert_not_null(spinner_label, "Spinner label should exist")
	assert_not_null(status_label, "Status label should exist")
	assert_not_null(tip_label, "Tip label should exist")
	assert_not_null(progress_bar, "Progress bar should exist")

	if background_image != null:
		assert_not_null(
			background_image.texture,
			"BackgroundImage should have a texture assigned"
		)
		assert_eq(
			background_image.stretch_mode,
			TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"BackgroundImage should cover the full screen without letterboxing"
		)
	if content != null:
		assert_eq(
			content.get_theme_constant(&"separation"),
			config.margin_outer,
			"Content separation should use margin_outer token"
		)
	if logo_label != null:
		assert_eq(
			logo_label.get_theme_font_size(&"font_size"),
			config.title,
			"Logo label should use title token"
		)
	if spinner_label != null:
		assert_eq(
			spinner_label.get_theme_font_size(&"font_size"),
			config.heading,
			"Spinner label should use heading token"
		)
	if status_label != null:
		assert_eq(
			status_label.get_theme_font_size(&"font_size"),
			config.body_small,
			"Status label should use body_small token"
		)
	if tip_label != null:
		assert_eq(
			tip_label.get_theme_font_size(&"font_size"),
			config.section_header,
			"Tip label should use section_header token"
		)
	if progress_bar != null:
		assert_false(
			progress_bar.has_theme_stylebox_override(&"background"),
			"Progress bar background should come from theme styles"
		)
		assert_false(
			progress_bar.has_theme_stylebox_override(&"fill"),
			"Progress bar fill should come from theme styles"
		)
		var background_style := progress_bar.get_theme_stylebox(&"background")
		var fill_style := progress_bar.get_theme_stylebox(&"fill")
		assert_true(background_style is StyleBoxFlat, "Progress background should be a stylebox from theme")
		assert_true(fill_style is StyleBoxFlat, "Progress fill should be a stylebox from theme")
		if background_style is StyleBoxFlat:
			assert_true(
				(background_style as StyleBoxFlat).bg_color.is_equal_approx(config.health_bg),
				"Progress background color should come from health_bg token"
			)
		if fill_style is StyleBoxFlat:
			assert_true(
				(fill_style as StyleBoxFlat).bg_color.is_equal_approx(config.success),
				"Progress fill color should come from success token"
			)

func test_loading_screen_scene_has_no_inline_theme_overrides() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/core/ui/hud/ui_loading_screen.tscn")
	assert_ne(scene_text, "", "Scene file should load as text")
	assert_eq(
		scene_text.find("theme_override_"),
		-1,
		"Loading screen scene should not keep inline theme_override entries"
	)
