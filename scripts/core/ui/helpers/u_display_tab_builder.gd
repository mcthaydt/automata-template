extends "res://scripts/core/ui/helpers/u_settings_tab_builder.gd"
class_name U_DisplayTabBuilder

const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/core/utils/display/u_display_option_catalog.gd")

var _on_window_size_selected: Callable
var _on_window_mode_selected: Callable
var _on_vsync_toggled: Callable
var _on_quality_preset_selected: Callable
var _on_post_processing_toggled: Callable
var _on_post_processing_preset_selected: Callable
var _on_ui_scale_changed: Callable
var _on_color_blind_mode_selected: Callable
var _on_high_contrast_toggled: Callable
var _on_apply_pressed: Callable
var _on_cancel_pressed: Callable
var _on_reset_pressed: Callable

func _init(tab: Control) -> void:
	super._init(tab)

func set_callbacks(
	window_size: Callable,
	window_mode: Callable,
	vsync: Callable,
	quality: Callable,
	post_processing: Callable,
	post_processing_preset: Callable,
	ui_scale: Callable,
	color_blind: Callable,
	high_contrast: Callable,
	apply: Callable,
	cancel: Callable,
	reset: Callable
) -> U_DisplayTabBuilder:
	_on_window_size_selected = window_size
	_on_window_mode_selected = window_mode
	_on_vsync_toggled = vsync
	_on_quality_preset_selected = quality
	_on_post_processing_toggled = post_processing
	_on_post_processing_preset_selected = post_processing_preset
	_on_ui_scale_changed = ui_scale
	_on_color_blind_mode_selected = color_blind
	_on_high_contrast_toggled = high_contrast
	_on_apply_pressed = apply
	_on_cancel_pressed = cancel
	_on_reset_pressed = reset
	return self

func build() -> Control:
	var U_UI_SETTINGS_CATALOG := load("res://scripts/core/ui/helpers/u_ui_settings_catalog.gd")
	
	set_heading(&"settings.display.title")
	
	begin_section(&"settings.display.section.graphics", "GraphicsHeader")
	begin_inline_group("WindowSize")
	add_dropdown(
		&"settings.display.label.window_size",
		U_UI_SETTINGS_CATALOG.get_window_sizes(),
		_on_window_size_selected,
		&"settings.display.tooltip.window_size",
		"",
		"WindowSizeOption"
	)
	add_dropdown(
		&"settings.display.label.window_mode",
		U_UI_SETTINGS_CATALOG.get_window_modes(),
		_on_window_mode_selected,
		&"settings.display.tooltip.window_mode",
		"",
		"WindowModeOption"
	)
	end_inline_group()
	begin_inline_group("VSync")
	add_toggle(
		&"settings.display.label.vsync",
		_on_vsync_toggled,
		&"",
		"",
		"VSyncToggle"
	)
	add_dropdown(
		&"settings.display.label.quality_preset",
		U_UI_SETTINGS_CATALOG.get_quality_presets(),
		_on_quality_preset_selected,
		&"",
		"",
		"QualityPresetOption"
	)
	end_inline_group()
	end_section()
	
	begin_section(&"settings.display.section.post_processing", "PostProcessingHeader")
	begin_inline_group("PostProcessing")
	add_toggle(
		&"settings.display.label.enabled",
		_on_post_processing_toggled,
		&"",
		"",
		"PostProcessingToggle"
	)
	add_dropdown(
		&"settings.display.label.post_processing_preset",
		U_DISPLAY_OPTION_CATALOG.get_post_processing_preset_option_entries(),
		_on_post_processing_preset_selected,
		&"settings.display.tooltip.post_processing_preset",
		"",
		"PostProcessPresetOption"
	)
	end_inline_group()
	end_section()
	
	begin_section(&"settings.display.section.ui", "UIHeader")
	var ui_scale: Dictionary = U_UI_SETTINGS_CATALOG.get_ui_scale_range()
	add_slider(
		&"settings.display.label.ui_scale",
		ui_scale.min,
		ui_scale.max,
		ui_scale.step,
		_on_ui_scale_changed,
		&"settings.display.value.percent",
		&"settings.display.tooltip.ui_scale",
		"",
		"UIScaleSlider"
	)
	end_section()
	
	begin_section(&"settings.display.section.accessibility", "AccessibilityHeader")
	add_dropdown(
		&"settings.display.label.color_blind_mode",
		U_DISPLAY_OPTION_CATALOG.get_color_blind_mode_option_entries(),
		_on_color_blind_mode_selected,
		&"",
		"",
		"ColorBlindModeOption"
	)
	add_toggle(
		&"settings.display.label.high_contrast",
		_on_high_contrast_toggled,
		&"",
		"",
		"HighContrastToggle"
	)
	end_section()
	
	add_button_row(_on_apply_pressed, _on_cancel_pressed, _on_reset_pressed)
	
	return super.build()
