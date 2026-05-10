@icon("res://assets/core/editor_icons/icn_manager.svg")
extends "res://scripts/core/interfaces/i_display_manager.gd"
class_name M_DisplayManager

## Display Manager - applies display settings from Redux display slice.
## Phase 1B: Scaffolding for store subscription + preview mode.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/core/state/selectors/u_display_selectors.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/core/state/selectors/u_localization_selectors.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/core/state/selectors/u_navigation_selectors.gd")
const U_SCENE_SELECTORS := preload("res://scripts/core/state/selectors/u_scene_selectors.gd")
const U_PALETTE_MANAGER := preload("res://scripts/core/managers/helpers/u_palette_manager.gd")
const U_DISPLAY_SERVER_WINDOW_OPS := preload("res://scripts/core/utils/display/u_display_server_window_ops.gd")
const U_DISPLAY_WINDOW_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_window_applier.gd")
const U_DISPLAY_QUALITY_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_quality_applier.gd")
const U_DISPLAY_POST_PROCESS_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_post_process_applier.gd")
const U_DISPLAY_UI_SCALE_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_ui_scale_applier.gd")
const U_DISPLAY_UI_THEME_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_ui_theme_applier.gd")
const U_DISPLAY_COLOR_GRADING_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_color_grading_applier.gd")
const U_POST_PROCESS_PIPELINE := preload("res://scripts/core/managers/helpers/display/u_post_process_pipeline.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const U_UI_THEME_DEBUG := preload("res://scripts/core/ui/utils/u_ui_theme_debug.gd")
const U_SCENE_REGISTRY := preload("res://scripts/core/scene_management/u_scene_registry.gd")
const U_PERF_PROBE := preload("res://scripts/core/utils/debug/u_perf_probe.gd")
const RS_DISPLAY_CONFIG_SCRIPT := preload("res://scripts/core/resources/managers/rs_display_config.gd")
const DEFAULT_DISPLAY_CONFIG := preload("res://resources/core/base_settings/display/cfg_display_config_default.tres")

const SERVICE_NAME := StringName("display_manager")
const DISPLAY_SLICE_NAME := StringName("display")
const LOCALIZATION_SLICE_NAME := StringName("localization")
const NAVIGATION_SLICE_NAME := StringName("navigation")
const SCENE_SLICE_NAME := StringName("scene")
const SHELL_GAMEPLAY := StringName("gameplay")

## Injected dependency (tests)
@export var state_store: I_StateStore = null
@export var display_config: Resource = null
var window_ops: I_WindowOps = null

var _state_store: I_StateStore = null
var _window_ops: I_WindowOps = null
var _last_display_hash: int = 0
var _last_localization_hash: int = 0
var _last_window_hash: int = 0
var _display_settings_preview_active: bool = false
var _preview_settings: Dictionary = {}
var _palette_manager: RefCounted = null

var _window_applier: RefCounted = null  # U_DisplayWindowApplier
var _quality_applier: RefCounted = null  # U_DisplayQualityApplier
var _post_process_applier: RefCounted = null  # U_DisplayPostProcessApplier
var _ui_scale_applier: RefCounted = null  # U_DisplayUIScaleApplier
var _ui_theme_applier: RefCounted = null  # U_DisplayUIThemeApplier
var _color_grading_applier: RefCounted = null  # U_DisplayColorGradingApplier
var _pipeline: RefCounted = null  # U_PostProcessPipeline

# Cached values for inspection/tests (Phase 1B)
var _last_applied_settings: Dictionary = {}
var _apply_count: int = 0
var _perf_probe: U_PerfProbe = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	U_SERVICE_LOCATOR.register(SERVICE_NAME, self)
	_ensure_appliers()
	_perf_probe = U_PerfProbe.create("FilmGrain", false)

	await _initialize_store_async()

func _exit_tree() -> void:
	if _pipeline != null:
		(_pipeline as U_PostProcessPipeline).clear()
	if _color_grading_applier != null:
		_color_grading_applier.cleanup()
	if _ui_theme_applier != null:
		_ui_theme_applier.clear_active_palette()
	if _state_store != null and _state_store.has_signal("slice_updated"):
		if _state_store.slice_updated.is_connected(_on_slice_updated):
			_state_store.slice_updated.disconnect(_on_slice_updated)
	_state_store = null

func _initialize_store_async() -> void:
	_theme_debug_log("initialize_store_async: awaiting store")
	var store := await _await_store_ready_soft()
	if store == null:
		_theme_debug_log("initialize_store_async: store not found")
		print_verbose("M_DisplayManager: StateStore not found. Display settings will not be applied.")
		return

	_state_store = store
	_theme_debug_log("initialize_store_async: store resolved")
	if _state_store.has_signal("slice_updated"):
		_state_store.slice_updated.connect(_on_slice_updated)


	_ensure_appliers()
	if _color_grading_applier != null:
		_color_grading_applier.initialize(self, _state_store)

	var state := _state_store.get_state()
	_apply_display_settings(state)
	_last_display_hash = _get_display_hash(state)
	_last_localization_hash = _get_localization_hash(state)
	_update_overlay_visibility()

func _process(___delta: float) -> void:
	if _pipeline == null:
		return
	_perf_probe.start()
	(_pipeline as U_PostProcessPipeline).update_per_frame()
	_perf_probe.stop()

func _await_store_ready_soft(max_frames: int = 60) -> I_StateStore:
	var tree := get_tree()
	if tree == null:
		return null

	var frames_waited := 0
	while frames_waited <= max_frames:
		var store := U_DependencyResolution.resolve_state_store(null, null, self)
		if store != null:
			if store.is_ready():
				return store
			if store.has_signal("store_ready"):
				if _is_gut_running():
					return null
				await store.store_ready
				if is_instance_valid(store) and store.is_ready():
					return store
		elif _is_gut_running():
			return null
		await tree.process_frame
		frames_waited += 1

	return null

func _is_gut_running() -> bool:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	return tree.root.find_child("GutRunner", true, false) != null

func _on_slice_updated(slice_name: StringName, ___slice_data: Dictionary) -> void:
	if _state_store == null:
		return

	if (slice_name == DISPLAY_SLICE_NAME or slice_name == LOCALIZATION_SLICE_NAME) and not _display_settings_preview_active:
		var state := _state_store.get_state()
		var display_hash := _get_display_hash(state)
		var localization_hash := _get_localization_hash(state)
		if display_hash != _last_display_hash or localization_hash != _last_localization_hash:
			_apply_display_settings(state)
			_last_display_hash = display_hash
			_last_localization_hash = localization_hash

	if slice_name == NAVIGATION_SLICE_NAME:
		_update_overlay_visibility()

func set_display_settings_preview(settings: Dictionary) -> void:
	_preview_settings = settings.duplicate(true)
	_display_settings_preview_active = true
	var state: Dictionary = {}
	if _state_store != null:
		state = _state_store.get_state()
	_apply_display_settings(state)

## Override: I_DisplayManager.clear_display_settings_preview
func clear_display_settings_preview() -> void:
	_preview_settings.clear()
	_display_settings_preview_active = false
	if _state_store == null:
		_last_applied_settings = {}
		return
	var state := _state_store.get_state()
	_apply_display_settings(state)
	_last_display_hash = _get_display_hash(state)
	_last_localization_hash = _get_localization_hash(state)

## Override: I_DisplayManager.get_active_palette
func get_active_palette() -> Resource:
	if _palette_manager == null:
		return null
	return _palette_manager.get_active_palette()

func _apply_display_settings(state: Dictionary) -> void:
	var effective_settings := _build_effective_settings(state)
	_last_applied_settings = effective_settings
	_apply_count += 1

	var window_hash := _get_window_hash(effective_settings)
	if window_hash != _last_window_hash:
		_apply_window_settings(effective_settings)
		_last_window_hash = window_hash

	_apply_quality_settings(effective_settings)
	_apply_post_process_settings(effective_settings)
	_apply_color_grading_settings(effective_settings)
	_apply_ui_scale_settings(effective_settings)
	_apply_accessibility_settings(effective_settings)
	_sync_pipeline_visibility(effective_settings, state)

func _build_effective_settings(state: Dictionary) -> Dictionary:
	var settings: Dictionary = U_DISPLAY_SELECTORS.get_display_settings(state).duplicate(true)
	if _display_settings_preview_active:
		for key in _preview_settings.keys():
			settings[key] = _preview_settings[key]

	var display_state := {"display": settings}
	var base_ui_scale := U_DISPLAY_SELECTORS.get_ui_scale(display_state)
	var localization_scale := 1.0
	if state != null:
		localization_scale = U_LOCALIZATION_SELECTORS.get_ui_scale_override(state)
	settings["ui_scale"] = base_ui_scale * localization_scale
	return settings

func _apply_window_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _window_applier == null:
		return
	_window_applier.set_window_ops(_get_window_ops())
	_window_applier.apply_settings(display_settings)

func _apply_quality_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _quality_applier == null:
		return
	_quality_applier.apply_settings(display_settings)

func _apply_ui_scale_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _ui_scale_applier == null:
		return
	var state := {"display": display_settings}
	var scale := U_DISPLAY_SELECTORS.get_ui_scale(state)
	_ui_scale_applier.set_ui_scale(scale)

func _apply_accessibility_settings(display_settings: Dictionary) -> void:
	if _palette_manager == null:
		_palette_manager = U_PALETTE_MANAGER.new()
	var state := {"display": display_settings}
	var mode := U_DISPLAY_SELECTORS.get_color_blind_mode(state)
	var high_contrast := U_DISPLAY_SELECTORS.is_high_contrast_enabled(state)
	_palette_manager.set_color_blind_mode(mode, high_contrast)
	var palette: Resource = _palette_manager.get_active_palette()
	_theme_debug_log(
		"apply_accessibility_settings mode=%s high_contrast=%s palette_id=%s active_config=%s" % [
			mode,
			str(high_contrast),
			_get_palette_id_text(palette),
			str(U_UI_THEME_BUILDER.active_config != null),
		]
	)
	_ensure_appliers()
	if _ui_theme_applier != null:
		_ui_theme_applier.apply_theme_from_palette(palette)
		_rebuild_ui_theme_roots()

func _apply_post_process_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _post_process_applier == null:
		return
	_post_process_applier.apply_settings(display_settings)

func _apply_color_grading_settings(display_settings: Dictionary) -> void:
	_ensure_appliers()
	if _color_grading_applier == null:
		return
	_color_grading_applier.apply_settings(display_settings)

func set_ui_scale(scale: float) -> void:
	_ensure_appliers()
	if _ui_scale_applier == null:
		return
	_ui_scale_applier.set_ui_scale(scale)

func apply_window_size_preset(preset: String) -> void:
	_ensure_appliers()
	if _window_applier == null:
		return
	_window_applier.set_window_ops(_get_window_ops())
	_window_applier.apply_window_size_preset(preset)

func set_window_mode(mode: String) -> void:
	_ensure_appliers()
	if _window_applier == null:
		return
	_window_applier.set_window_ops(_get_window_ops())
	_window_applier.set_window_mode(mode)

func set_vsync_enabled(enabled: bool) -> void:
	_ensure_appliers()
	if _window_applier == null:
		return
	_window_applier.set_window_ops(_get_window_ops())
	_window_applier.set_vsync_enabled(enabled)

func apply_quality_preset(preset: String) -> void:
	_ensure_appliers()
	if _quality_applier == null:
		return
	_quality_applier.apply_quality_preset(preset)

func _get_display_hash(state: Dictionary) -> int:
	if state == null:
		return 0
	return U_DISPLAY_SELECTORS.get_display_settings(state).hash()

func _get_localization_hash(state: Dictionary) -> int:
	if state == null:
		return 0
	return U_LOCALIZATION_SELECTORS.get_localization_settings(state).hash()

func _get_window_hash(display_settings: Dictionary) -> int:
	if display_settings == null:
		return 0
	var preset: Variant = display_settings.get("window_size_preset", "")
	var mode: Variant = display_settings.get("window_mode", "")
	var vsync: Variant = display_settings.get("vsync_enabled", true)
	var mobile_mode: Variant = display_settings.get("mobile_window_mode", "")
	var mobile_scale: Variant = display_settings.get("mobile_resolution_scale", 0.35)
	return [preset, mode, vsync, mobile_mode, mobile_scale].hash()

func _get_window_ops() -> I_WindowOps:
	if window_ops != null:
		return window_ops
	if _window_ops == null:
		_window_ops = U_DISPLAY_SERVER_WINDOW_OPS.new()
	return _window_ops

func _is_display_server_available() -> bool:
	_ensure_appliers()
	if _window_applier == null:
		return false
	_window_applier.set_window_ops(_get_window_ops())
	return _window_applier.is_display_server_available()

func _ensure_appliers() -> void:
	if _pipeline == null:
		_pipeline = U_POST_PROCESS_PIPELINE.new()
	if _window_applier == null:
		_window_applier = U_DISPLAY_WINDOW_APPLIER.new()
		_window_applier.initialize(self)
	if _quality_applier == null:
		_quality_applier = U_DISPLAY_QUALITY_APPLIER.new()
		_quality_applier.initialize(self)
	if _post_process_applier == null:
		_post_process_applier = U_DISPLAY_POST_PROCESS_APPLIER.new()
		_post_process_applier.initialize(self)
		_post_process_applier.set_pipeline(_pipeline as U_PostProcessPipeline)
	if _ui_scale_applier == null:
		var config: Dictionary = _resolve_display_config_values()
		_ui_scale_applier = U_DISPLAY_UI_SCALE_APPLIER.new()
		_ui_scale_applier.initialize(
			float(config.get("min_ui_scale", 0.8)),
			float(config.get("max_ui_scale", 1.3))
		)
	if _ui_theme_applier == null:
		_ui_theme_applier = U_DISPLAY_UI_THEME_APPLIER.new()
	if _color_grading_applier == null:
		_color_grading_applier = U_DISPLAY_COLOR_GRADING_APPLIER.new()
		_color_grading_applier.set_pipeline(_pipeline as U_PostProcessPipeline)


func _resolve_display_config_values() -> Dictionary:
	var defaults := {
		"min_ui_scale": 0.8,
		"max_ui_scale": 1.3,
		"min_mobile_resolution_scale": 0.35,
	}
	var config_variant: Variant = display_config
	if config_variant == null:
		config_variant = DEFAULT_DISPLAY_CONFIG
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
		"min_mobile_resolution_scale": clampf(
			float(config_resource.get("min_mobile_resolution_scale")),
			0.1,
			1.0
		),
	}

func register_ui_scale_root(node: Node) -> void:
	_ensure_appliers()
	if _ui_scale_applier != null:
		_ui_scale_applier.register_ui_scale_root(node)
	var palette: Resource = _palette_manager.get_active_palette() if _palette_manager != null else null
	var node_name: String = "<null>"
	if node != null:
		node_name = str(node.name)
	_theme_debug_log(
		"register_ui_scale_root '%s' active_config=%s palette_id=%s" % [
			node_name,
			str(U_UI_THEME_BUILDER.active_config != null),
			_get_palette_id_text(palette),
		]
	)
	if _ui_theme_applier != null:
		_rebuild_ui_theme_node(node)

func unregister_ui_scale_root(node: Node) -> void:
	_ensure_appliers()
	if _ui_scale_applier == null:
		return
	_ui_scale_applier.unregister_ui_scale_root(node)

func _rebuild_ui_theme_roots() -> void:
	if _ui_theme_applier == null or _ui_scale_applier == null:
		return
	_ui_theme_applier.apply_theme_to_roots(_ui_scale_applier.get_roots())

func _rebuild_ui_theme_node(node: Node) -> void:
	if _ui_theme_applier == null:
		return
	var node_name: String = "<null>"
	if node != null:
		node_name = str(node.name)
	_theme_debug_log("rebuild_ui_theme_node '%s'" % node_name)
	_ui_theme_applier.apply_theme_to_node(node)

func _update_overlay_visibility() -> void:
	if _state_store == null:
		return
	_ensure_appliers()

	var state := _state_store.get_state()
	var shell := U_NAVIGATION_SELECTORS.get_shell(state)
	var should_show := shell == SHELL_GAMEPLAY

	if _post_process_applier != null:
		_post_process_applier.update_overlay_visibility(should_show)

	var effective_settings := _build_effective_settings(state)
	_sync_pipeline_visibility(effective_settings, state)

func _sync_pipeline_visibility(display_settings: Dictionary, state: Dictionary) -> void:
	if _pipeline == null:
		return
	var state_wrap := {"display": display_settings}
	var pp_enabled := U_DISPLAY_SELECTORS.is_post_processing_enabled(state_wrap)
	var fg_enabled := U_DISPLAY_SELECTORS.is_film_grain_enabled(state_wrap)
	var dither_enabled := U_DISPLAY_SELECTORS.is_dither_enabled(state_wrap)
	var scanlines_enabled := U_DISPLAY_SELECTORS.is_scanlines_enabled(state_wrap)
	var shell := U_NAVIGATION_SELECTORS.get_shell(state)
	(_pipeline as U_PostProcessPipeline).apply_settings({
		"grain_dither_enabled": pp_enabled and (fg_enabled or dither_enabled or scanlines_enabled),
		"color_grading_enabled": shell == SHELL_GAMEPLAY,
	})

func _get_palette_id_text(palette: Resource) -> String:
	if palette == null:
		return "null"
	if palette.has_method("get"):
		var palette_id: Variant = palette.get("palette_id")
		return str(palette_id)
	return "<no-palette-id>"

func _theme_debug_log(message: String) -> void:
	U_UI_THEME_DEBUG.log("M_DisplayManager", message)
