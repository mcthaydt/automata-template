extends GutTest

const TAB_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_display_settings_tab.tscn")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_UI_SETTINGS_CATALOG := preload("res://scripts/core/ui/helpers/u_ui_settings_catalog.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _store: M_StateStore
var _tab: UI_DisplaySettingsTab


func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()

	_store = M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	test_settings.enable_global_settings_persistence = false
	test_settings.enable_debug_logging = false
	test_settings.enable_debug_overlay = false
	_store.settings = test_settings
	_store.display_initial_state = RS_DisplayInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)


func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null
	_tab = null


func test_display_settings_tab_is_builder_backed() -> void:
	_instantiate_tab()

	assert_true(_tab.has_meta(&"settings_builder"), "Display tab should mark builder-backed runtime UI")
	assert_not_null(_tab.find_child("WindowSizeOption", true, false), "Window size control should be built")
	assert_not_null(_tab.find_child("PostProcessPresetOption", true, false), "Post-processing preset control should be built")
	assert_not_null(_tab.find_child("HighContrastToggle", true, false), "High contrast control should be built")


func test_display_options_come_from_ui_settings_catalog() -> void:
	_instantiate_tab()

	var size_option := _tab.find_child("WindowSizeOption", true, false) as OptionButton
	var mode_option := _tab.find_child("WindowModeOption", true, false) as OptionButton
	var quality_option := _tab.find_child("QualityPresetOption", true, false) as OptionButton
	assert_eq(size_option.item_count, U_UI_SETTINGS_CATALOG.get_window_sizes().size(), "Window sizes should use catalog")
	assert_eq(mode_option.item_count, U_UI_SETTINGS_CATALOG.get_window_modes().size(), "Window modes should use catalog")
	assert_eq(quality_option.item_count, U_UI_SETTINGS_CATALOG.get_quality_presets().size(), "Quality presets should use catalog")


func test_display_builder_wires_signals_and_focus() -> void:
	_instantiate_tab()

	var quality_option := _tab.find_child("QualityPresetOption", true, false) as OptionButton
	var post_process_toggle := _tab.find_child("PostProcessingToggle", true, false) as CheckBox
	var apply_button := _tab.find_child("ApplyButton", true, false) as Button
	quality_option.select(0)
	quality_option.item_selected.emit(0)
	post_process_toggle.button_pressed = true
	post_process_toggle.toggled.emit(true)
	apply_button.pressed.emit()
	await get_tree().process_frame

	var display_state: Dictionary = _store.get_state().get("display", {})
	assert_eq(display_state.get("quality_preset"), "low", "Quality callback should dispatch selected catalog value")
	assert_true(display_state.get("post_processing_enabled"), "Toggle callback should dispatch selected state")
	assert_ne(quality_option.focus_neighbor_bottom, NodePath(), "Builder should configure vertical focus")


func test_display_builder_applies_theme_tokens() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 39
	config.section_header = 17
	config.body_small = 16
	config.text_secondary = Color(0.79, 0.77, 0.66, 1.0)
	U_UI_THEME_BUILDER.active_config = config
	_instantiate_tab()

	var heading_label := _tab.find_child("HeadingLabel", true, false) as Label
	var graphics_header := _tab.find_child("GraphicsHeader", true, false) as Label
	var window_size_label := _tab.find_child("WindowSizeLabel", true, false) as Label
	
	assert_eq(heading_label.get_theme_font_size(&"font_size"), config.heading, "Heading should use builder theme token")
	assert_eq(graphics_header.get_theme_font_size(&"font_size"), config.section_header, "Section should use builder theme token")
	assert_eq(window_size_label.get_theme_font_size(&"font_size"), config.body_small, "Field labels should use builder theme token")
	assert_true(window_size_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary), "Field labels should use secondary color")


func test_display_tab_uses_compact_natural_toggles():
	_instantiate_tab()

	var vsync := _tab.find_child("VSyncToggle", true, false) as CheckBox
	var post_processing := _tab.find_child("PostProcessingToggle", true, false) as CheckBox
	var high_contrast := _tab.find_child("HighContrastToggle", true, false) as CheckBox

	assert_eq(vsync.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "VSync toggle should not stretch as a full-width bar")
	assert_eq(post_processing.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "Post-processing toggle should not stretch as a full-width bar")
	assert_eq(high_contrast.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "High contrast toggle should not stretch as a full-width bar")


func test_display_tab_field_controls_have_consistent_widths():
	_instantiate_tab()

	var window_size := _tab.find_child("WindowSizeOption", true, false) as OptionButton
	var window_mode := _tab.find_child("WindowModeOption", true, false) as OptionButton
	var quality := _tab.find_child("QualityPresetOption", true, false) as OptionButton
	var color_blind := _tab.find_child("ColorBlindModeOption", true, false) as OptionButton

	assert_eq(window_size.custom_minimum_size.x, window_mode.custom_minimum_size.x, "Display dropdown widths should match")
	assert_eq(quality.custom_minimum_size.x, color_blind.custom_minimum_size.x, "Display dropdown widths should match")
	assert_eq(window_size.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Inline display dropdowns should expand to share available space")


func _instantiate_tab() -> void:
	_tab = TAB_SCENE.instantiate() as UI_DisplaySettingsTab
	add_child_autofree(_tab)
	await get_tree().process_frame
