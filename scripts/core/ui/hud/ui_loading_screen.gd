@icon("res://assets/core/editor_icons/icn_utility.svg")
extends Control
class_name UI_LoadingScreen

const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_TWEEN_MANAGER := preload("res://scripts/core/scene_management/u_tween_manager.gd")
const CFG_GAME_CONFIG := preload("res://resources/core/cfg_game_config.tres")
const MENU_FULLSCREEN_SHADER := preload("res://assets/core/shaders/sh_menu_fullscreen_shader.gdshader")

const BACKGROUND_SHADER_PRESET_NONE := "none"
const BACKGROUND_SHADER_PRESET_RETRO_GRID := "retro_grid"
const BACKGROUND_SHADER_PRESET_SCANLINE_DRIFT := "scanline_drift"
const BACKGROUND_SHADER_PRESET_ARCADE_NOISE := "arcade_noise"

const SHADER_PARAM_PRESET_MODE := StringName("preset_mode")
const SHADER_PARAM_EFFECT_INTENSITY := StringName("effect_intensity")
const SHADER_PARAM_EFFECT_SPEED := StringName("effect_speed")

const BACKGROUND_SHADER_PRESET_MODE_BY_ID := {
	BACKGROUND_SHADER_PRESET_RETRO_GRID: 0,
	BACKGROUND_SHADER_PRESET_SCANLINE_DRIFT: 1,
	BACKGROUND_SHADER_PRESET_ARCADE_NOISE: 2,
}

const BACKGROUND_IMAGE_BY_PRESET := {
	BACKGROUND_SHADER_PRESET_RETRO_GRID: "res://assets/core/textures/bg_menu_main.png",
	BACKGROUND_SHADER_PRESET_SCANLINE_DRIFT: "res://assets/core/textures/bg_menu_pause.png",
	BACKGROUND_SHADER_PRESET_ARCADE_NOISE: "res://assets/core/textures/bg_game_over.png",
}

@export var background_path: NodePath = NodePath()
@export var content_path: NodePath = NodePath("CenterContainer/VBoxContainer")
@export var logo_label_path: NodePath = NodePath("CenterContainer/VBoxContainer/LogoLabel")
@export var spinner_label_path: NodePath = NodePath("CenterContainer/VBoxContainer/SpinnerLabel")
@export var status_label_path: NodePath = NodePath("CenterContainer/VBoxContainer/StatusLabel")
@export var tip_label_path: NodePath = NodePath("CenterContainer/VBoxContainer/TipLabel")
@export var fade_in_duration_sec: float = 0.18
@export_enum("none", "retro_grid", "scanline_drift", "arcade_noise") var background_shader_preset: String = BACKGROUND_SHADER_PRESET_NONE
@export_range(0.0, 1.0, 0.01) var background_shader_intensity: float = 0.5
@export_range(0.0, 5.0, 0.01) var background_shader_speed: float = 1.0

var _background: ColorRect = null
var _background_image: TextureRect = null
var _content: VBoxContainer = null
var _logo_label: Label = null
var _spinner_label: Label = null
var _status_label: Label = null
var _tip_label: Label = null
var _fade_tween: Tween = null
var _background_shader_material: ShaderMaterial = null

func _ready() -> void:
	_cache_nodes()
	_populate_logo_label()
	_apply_theme_tokens()
	_setup_background_shader()
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _populate_logo_label() -> void:
	if _logo_label != null:
		_logo_label.text = CFG_GAME_CONFIG.game_name

func _exit_tree() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null

func _cache_nodes() -> void:
	_background = get_node_or_null(background_path) as ColorRect
	_content = get_node_or_null(content_path) as VBoxContainer
	_logo_label = get_node_or_null(logo_label_path) as Label
	_spinner_label = get_node_or_null(spinner_label_path) as Label
	_status_label = get_node_or_null(status_label_path) as Label
	_tip_label = get_node_or_null(tip_label_path) as Label

func _apply_theme_tokens() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if not (config_resource is RS_UI_THEME_CONFIG):
		return
	var config := config_resource as RS_UI_THEME_CONFIG

	if _background != null:
		_background.color = config.bg_base
	if _content != null:
		_content.add_theme_constant_override(&"separation", config.margin_outer)
	if _logo_label != null:
		_logo_label.add_theme_font_size_override(&"font_size", config.title)
	if _spinner_label != null:
		_spinner_label.add_theme_font_size_override(&"font_size", config.heading)
	if _status_label != null:
		_status_label.add_theme_font_size_override(&"font_size", config.body_small)
	if _tip_label != null:
		_tip_label.add_theme_font_size_override(&"font_size", config.section_header)

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = null
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 0.0
	if fade_in_duration_sec <= 0.0:
		modulate.a = 1.0
		return
	_fade_tween = U_TWEEN_MANAGER.create_transition_tween(self)
	if _fade_tween == null:
		modulate.a = 1.0
		return
	_fade_tween.tween_property(self, "modulate:a", 1.0, fade_in_duration_sec).from(0.0)
	_fade_tween.finished.connect(_on_fade_finished)

func _on_fade_finished() -> void:
	_fade_tween = null

func _resolve_background() -> Control:
	var bg_image := get_node_or_null("BackgroundImage") as TextureRect
	if bg_image != null:
		return bg_image
	if _background != null:
		return _background
	return null

func _setup_background_image(preset: String) -> bool:
	if not BACKGROUND_IMAGE_BY_PRESET.has(preset):
		return false
	var texture_path: String = BACKGROUND_IMAGE_BY_PRESET[preset]
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return false
	var bg_image := TextureRect.new()
	bg_image.name = "BackgroundImage"
	bg_image.texture = texture
	_configure_background_image(bg_image)
	add_child(bg_image)
	move_child(bg_image, 0)
	_background_image = bg_image
	return true

func _setup_background_shader() -> void:
	var existing := get_node_or_null("BackgroundImage") as TextureRect
	if existing != null:
		_configure_background_image(existing)
		_background_image = existing
		return

	if background_shader_preset != BACKGROUND_SHADER_PRESET_NONE:
		if _setup_background_image(background_shader_preset):
			return

	var bg := _resolve_background()
	if bg == null:
		return

	if bg is TextureRect:
		_background_image = bg
		return

	if background_shader_preset == BACKGROUND_SHADER_PRESET_NONE:
		return

	var preset_mode := _get_background_shader_mode(background_shader_preset)
	if preset_mode < 0:
		return

	var shader_material := _background.material as ShaderMaterial
	if shader_material == null or shader_material.shader != MENU_FULLSCREEN_SHADER:
		shader_material = ShaderMaterial.new()
		shader_material.shader = MENU_FULLSCREEN_SHADER
		_background.material = shader_material

	_background_shader_material = shader_material
	_apply_background_shader_uniforms(preset_mode)

func _apply_background_shader_uniforms(preset_mode: int) -> void:
	if _background_image != null:
		return
	if _background_shader_material == null:
		return
	_background_shader_material.set_shader_parameter(SHADER_PARAM_PRESET_MODE, preset_mode)
	_background_shader_material.set_shader_parameter(
		SHADER_PARAM_EFFECT_INTENSITY,
		clampf(background_shader_intensity, 0.0, 1.0)
	)
	_background_shader_material.set_shader_parameter(
		SHADER_PARAM_EFFECT_SPEED,
		clampf(background_shader_speed, 0.0, 5.0)
	)

func _get_background_shader_mode(preset: String) -> int:
	if BACKGROUND_SHADER_PRESET_MODE_BY_ID.has(preset):
		return int(BACKGROUND_SHADER_PRESET_MODE_BY_ID[preset])
	return -1

func _configure_background_image(bg_image: TextureRect) -> void:
	bg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_image.z_index = -1
	bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
