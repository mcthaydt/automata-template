@icon("res://assets/core/editor_icons/icn_utility.svg")
extends Control
class_name UI_LoadingScreen

const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_TWEEN_MANAGER := preload("res://scripts/core/scene_management/u_tween_manager.gd")
const CFG_GAME_CONFIG := preload("res://resources/core/cfg_game_config.tres")
const MENU_FULLSCREEN_SHADER := preload("res://assets/core/shaders/sh_menu_fullscreen_shader.gdshader")
const W_BACKGROUND_IMAGE := preload("res://scripts/core/ui/widgets/w_background_image.gd")
const W_BACKGROUND_SHADER := preload("res://scripts/core/ui/widgets/w_background_shader.gd")

const BACKGROUND_SHADER_PRESET_NONE := "none"
const BACKGROUND_SHADER_PRESET_RETRO_GRID := "retro_grid"
const BACKGROUND_SHADER_PRESET_SCANLINE_DRIFT := "scanline_drift"
const BACKGROUND_SHADER_PRESET_ARCADE_NOISE := "arcade_noise"

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
	var bg_image := W_BACKGROUND_IMAGE.setup_from_preset(preset)
	if bg_image == null:
		return false
	add_child(bg_image)
	move_child(bg_image, 0)
	_background_image = bg_image
	return true

func _setup_background_shader() -> void:
	var existing := get_node_or_null("BackgroundImage") as TextureRect
	if existing != null:
		W_BACKGROUND_IMAGE.configure_existing(existing)
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

	_background_shader_material = W_BACKGROUND_SHADER.setup_material(
		_background, background_shader_preset, background_shader_intensity, background_shader_speed
	)
