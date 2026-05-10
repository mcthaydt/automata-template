extends RefCounted
class_name U_DisplaySelectors

## Display Selectors (Display Manager Phase 0 - Task 0D.2)
##
## Pure selector functions for reading Display slice state. Provides safe
## defaults when display slice or fields are missing.

static func get_window_size_preset(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return str(display.get("window_size_preset", "1920x1080"))

static func get_window_mode(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return str(display.get("window_mode", "windowed"))

static func get_mobile_window_mode(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	var mode := str(display.get("mobile_window_mode", "fullscreen"))
	if not ["windowed", "fullscreen", "borderless"].has(mode):
		return "fullscreen"
	return mode

static func is_vsync_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("vsync_enabled", true))

static func get_quality_preset(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return str(display.get("quality_preset", "high"))

static func is_post_processing_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("post_processing_enabled", false))

static func get_post_processing_preset(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return str(display.get("post_processing_preset", "medium"))

static func is_film_grain_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("film_grain_enabled", false))

static func get_film_grain_intensity(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("film_grain_intensity", 0.1))

static func is_dither_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("dither_enabled", false))

static func get_dither_intensity(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("dither_intensity", 0.5))

static func get_dither_pattern(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return str(display.get("dither_pattern", "bayer"))

static func get_ui_scale(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("ui_scale", 1.0))

static func get_color_blind_mode(state: Dictionary) -> String:
	var display := _get_display_slice(state)
	return str(display.get("color_blind_mode", "normal"))

static func is_high_contrast_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("high_contrast_enabled", false))

static func is_color_blind_shader_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("color_blind_shader_enabled", false))

static func is_scanlines_enabled(state: Dictionary) -> bool:
	var display := _get_display_slice(state)
	return bool(display.get("scanlines_enabled", false))

static func get_line_mask_intensity(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("line_mask_intensity", 0.0))

static func get_scanline_count(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return float(display.get("scanline_count", 480.0))

static func get_mobile_resolution_scale(state: Dictionary) -> float:
	var display := _get_display_slice(state)
	return clampf(float(display.get("mobile_resolution_scale", 0.35)), 0.25, 1.0)

## Returns the entire display slice for hash-based change detection
## and settings duplication.
static func get_display_settings(state: Dictionary) -> Dictionary:
	return _get_display_slice(state)

static func _get_display_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	# If state has a "display" key, extract the nested slice (full state passed)
	var slice: Variant = state.get("display", null)
	if slice is Dictionary:
		return slice as Dictionary
	# If state has "window_size_preset" key, it's already the display slice (backward compat)
	if state.has("window_size_preset"):
		return state
	return {}
