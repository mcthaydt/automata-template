extends RefCounted
class_name U_DisplayReducer

## Display Reducer (Display Manager Phase 0 - Task 0C.2)
##
## Pure reducer functions for Display slice state mutations. Handles window
## settings, post-processing options, UI scale, and accessibility settings with
## validation and clamping.

const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/core/utils/display/u_display_option_catalog.gd")
const RS_DISPLAY_CONFIG_SCRIPT := preload("res://scripts/core/resources/managers/rs_display_config.gd")
const DEFAULT_DISPLAY_CONFIG := preload("res://resources/core/base_settings/display/cfg_display_config_default.tres")

const DEFAULT_DISPLAY_STATE := {
	"window_size_preset": "1920x1080",
	"window_mode": "windowed",
	"vsync_enabled": true,
	"quality_preset": "high",
	"post_processing_enabled": false,
	"post_processing_preset": "medium",
	"film_grain_enabled": false,
	"dither_enabled": false,
	"dither_pattern": "bayer",
	"scanlines_enabled": false,
	"ui_scale": 1.0,
	"color_blind_mode": "normal",
	"high_contrast_enabled": false,
	"color_blind_shader_enabled": false,
	"mobile_window_mode": "fullscreen",
	"mobile_resolution_scale": 0.35,
	# Note: Intensity values are loaded from post_processing_preset in get_default_display_state()
}

const MIN_INTENSITY := 0.0
const MAX_INTENSITY := 1.0

static func get_default_display_state() -> Dictionary:
	var state := DEFAULT_DISPLAY_STATE.duplicate(true)
	# Load intensity values from the default preset (medium)
	var preset: String = state.get("post_processing_preset", "medium")
	var preset_values := U_PostProcessingPresetValues.get_preset_values(preset)
	state["film_grain_intensity"] = preset_values.get("film_grain_intensity", 0.2)
	state["dither_intensity"] = preset_values.get("dither_intensity", 1.0)
	state["line_mask_intensity"] = preset_values.get("line_mask_intensity", 0.0)
	state["scanline_count"] = preset_values.get("scanline_count", 480.0)
	return state

static func reduce(state: Dictionary, action: Dictionary) -> Variant:
	var current := _merge_with_defaults(DEFAULT_DISPLAY_STATE, state)
	var action_type: Variant = action.get("type")

	match action_type:
		U_DisplayActions.ACTION_SET_WINDOW_SIZE_PRESET:
			var payload: Dictionary = action.get("payload", {})
			var preset: String = str(payload.get("preset", ""))
			if not _is_valid_window_preset(preset):
				return null
			return _with_values(current, {"window_size_preset": preset})

		U_DisplayActions.ACTION_SET_WINDOW_MODE:
			var payload: Dictionary = action.get("payload", {})
			var mode: String = str(payload.get("mode", ""))
			if not _is_valid_window_mode(mode):
				return null
			return _with_values(current, {"window_mode": mode})

		U_DisplayActions.ACTION_SET_VSYNC_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", true))
			return _with_values(current, {"vsync_enabled": enabled})

		U_DisplayActions.ACTION_SET_QUALITY_PRESET:
			var payload: Dictionary = action.get("payload", {})
			var preset: String = str(payload.get("preset", ""))
			if not _is_valid_quality_preset(preset):
				return null
			return _with_values(current, {"quality_preset": preset})

		U_DisplayActions.ACTION_SET_POST_PROCESSING_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"post_processing_enabled": enabled})

		U_DisplayActions.ACTION_SET_POST_PROCESSING_PRESET:
			var payload: Dictionary = action.get("payload", {})
			var preset: String = str(payload.get("preset", ""))
			if not _is_valid_post_processing_preset(preset):
				return null
			# Apply preset values to individual intensity settings
			var preset_values := U_PostProcessingPresetValues.get_preset_values(preset)
			return _with_values(current, {
				"post_processing_preset": preset,
				"film_grain_intensity": preset_values.get("film_grain_intensity", current.get("film_grain_intensity", 0.1)),
				"dither_intensity": preset_values.get("dither_intensity", current.get("dither_intensity", 0.5)),
				"line_mask_intensity": preset_values.get("line_mask_intensity", current.get("line_mask_intensity", 0.0)),
				"scanline_count": preset_values.get("scanline_count", current.get("scanline_count", 480.0)),
			})

		U_DisplayActions.ACTION_SET_FILM_GRAIN_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"film_grain_enabled": enabled})

		U_DisplayActions.ACTION_SET_FILM_GRAIN_INTENSITY:
			var payload: Dictionary = action.get("payload", {})
			var raw_intensity: float = float(payload.get("intensity", 0.1))
			var clamped_intensity := clampf(raw_intensity, MIN_INTENSITY, MAX_INTENSITY)
			return _with_values(current, {"film_grain_intensity": clamped_intensity})

		U_DisplayActions.ACTION_SET_DITHER_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"dither_enabled": enabled})

		U_DisplayActions.ACTION_SET_DITHER_INTENSITY:
			var payload: Dictionary = action.get("payload", {})
			var raw_intensity: float = float(payload.get("intensity", 0.5))
			var clamped_intensity := clampf(raw_intensity, MIN_INTENSITY, MAX_INTENSITY)
			return _with_values(current, {"dither_intensity": clamped_intensity})

		U_DisplayActions.ACTION_SET_DITHER_PATTERN:
			var payload: Dictionary = action.get("payload", {})
			var pattern: String = str(payload.get("pattern", ""))
			if not _is_valid_dither_pattern(pattern):
				return null
			return _with_values(current, {"dither_pattern": pattern})

		U_DisplayActions.ACTION_SET_UI_SCALE:
			var payload: Dictionary = action.get("payload", {})
			var raw_scale: float = float(payload.get("scale", 1.0))
			var ui_scale_bounds: Dictionary = _resolve_ui_scale_bounds()
			var clamped_scale := clampf(
				raw_scale,
				float(ui_scale_bounds.get("min_ui_scale", 0.8)),
				float(ui_scale_bounds.get("max_ui_scale", 1.3))
			)
			return _with_values(current, {"ui_scale": clamped_scale})

		U_DisplayActions.ACTION_SET_COLOR_BLIND_MODE:
			var payload: Dictionary = action.get("payload", {})
			var mode: String = str(payload.get("mode", ""))
			if not _is_valid_color_blind_mode(mode):
				return null
			return _with_values(current, {"color_blind_mode": mode})

		U_DisplayActions.ACTION_SET_HIGH_CONTRAST_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"high_contrast_enabled": enabled})

		U_DisplayActions.ACTION_SET_COLOR_BLIND_SHADER_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"color_blind_shader_enabled": enabled})

		U_DisplayActions.ACTION_SET_SCANLINES_ENABLED:
			var payload: Dictionary = action.get("payload", {})
			var enabled := bool(payload.get("enabled", false))
			return _with_values(current, {"scanlines_enabled": enabled})

		U_DisplayActions.ACTION_SET_LINE_MASK_INTENSITY:
			var payload: Dictionary = action.get("payload", {})
			var raw_intensity: float = float(payload.get("intensity", 0.35))
			var clamped_intensity := clampf(raw_intensity, MIN_INTENSITY, MAX_INTENSITY)
			return _with_values(current, {"line_mask_intensity": clamped_intensity})

		U_DisplayActions.ACTION_SET_SCANLINE_COUNT:
			var payload: Dictionary = action.get("payload", {})
			var raw_count: float = float(payload.get("count", 480.0))
			var clamped_count := clampf(raw_count, 60.0, 1080.0)
			return _with_values(current, {"scanline_count": clamped_count})

		U_ColorGradingActions.ACTION_LOAD_SCENE_GRADE:
			var payload: Dictionary = action.get("payload", {})
			var updates := {}
			for key in payload.keys():
				var key_str: String = str(key)
				if key_str.begins_with("color_grading_"):
					updates[key] = payload[key]
			if updates.is_empty():
				return null
			return _with_values(current, updates)

		U_ColorGradingActions.ACTION_SET_PARAMETER:
			var payload: Dictionary = action.get("payload", {})
			var param_name: String = str(payload.get("param_name", ""))
			if param_name.is_empty():
				return null

			# Special handling for filter_preset: convert string to numeric mode
			if param_name == "filter_preset":
				var filter_preset_str: String = str(payload.get("value", "none"))
				var filter_mode := _get_filter_mode_from_preset(filter_preset_str)
				return _with_values(current, {
					"color_grading_filter_mode": filter_mode,
					"color_grading_filter_preset": filter_preset_str
				})

			# Special handling for filter_intensity
			if param_name == "filter_intensity":
				return _with_values(current, {
					"color_grading_filter_intensity": payload.get("value")
				})

			var key := "color_grading_" + param_name
			return _with_values(current, {key: payload.get("value")})

		U_ColorGradingActions.ACTION_RESET_TO_SCENE_DEFAULTS:
			var payload: Dictionary = action.get("payload", {})
			var updates := {}
			for key in payload.keys():
				var key_str: String = str(key)
				if key_str.begins_with("color_grading_"):
					updates[key] = payload[key]
			if updates.is_empty():
				return null
			return _with_values(current, updates)

		_:
			return null

static func _merge_with_defaults(defaults: Dictionary, state: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	if state == null:
		return merged
	for key in state.keys():
		merged[key] = _deep_copy(state[key])
	return merged

static func _with_values(state: Dictionary, updates: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	for key in updates.keys():
		next[key] = _deep_copy(updates[key])
	return next

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

static func _is_valid_window_preset(preset: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_window_size_ids().has(preset)

static func _is_valid_quality_preset(preset: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_quality_ids().has(preset)

static func _is_valid_window_mode(mode: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_window_mode_ids().has(mode)

static func _is_valid_dither_pattern(pattern: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_dither_pattern_ids().has(pattern)

static func _is_valid_color_blind_mode(mode: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_color_blind_mode_ids().has(mode)

static func _resolve_ui_scale_bounds() -> Dictionary:
	var defaults := {
		"min_ui_scale": 0.8,
		"max_ui_scale": 1.3,
	}
	var config_variant: Variant = DEFAULT_DISPLAY_CONFIG
	if config_variant == null or not (config_variant is Resource):
		return defaults

	var config_resource: Resource = config_variant as Resource
	if config_resource.get_script() != RS_DISPLAY_CONFIG_SCRIPT:
		return defaults

	var min_ui_scale: float = maxf(float(config_resource.get("min_ui_scale")), 0.1)
	var max_ui_scale: float = maxf(float(config_resource.get("max_ui_scale")), min_ui_scale)
	return {
		"min_ui_scale": min_ui_scale,
		"max_ui_scale": max_ui_scale,
	}

static func _is_valid_post_processing_preset(preset: String) -> bool:
	return U_DISPLAY_OPTION_CATALOG.get_post_processing_preset_ids().has(preset)

static func _get_filter_mode_from_preset(preset_name: String) -> int:
	# Delegate to RS_SceneColorGrading.FILTER_PRESET_MAP (single source of truth)
	return RS_SceneColorGrading.FILTER_PRESET_MAP.get(preset_name, 0)
