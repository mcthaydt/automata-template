@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_panel.gd"
class_name BaseMenuScreen

## Base class for full-screen UI scenes such as main menu, game over, and victory.
##
## Inherits the common store / focus / back handling from BasePanel and provides
## a dedicated hook for menu-specific setup.
##
## Implements manual analog stick navigation with repeat/echo behavior to work around
## Godot quirk where InputEventJoypadMotion.is_action() incorrectly matches both
## directions simultaneously and doesn't provide echo/repeat like keyboard input.

const ANALOG_STICK_REPEATER_PATH := "res://scripts/core/ui/utils/u_analog_stick_repeater.gd"
const MENU_FULLSCREEN_SHADER := preload("res://assets/core/shaders/sh_menu_fullscreen_shader.gdshader")
const W_BACKGROUND_IMAGE := preload("res://scripts/core/ui/widgets/w_background_image.gd")
const W_ANALOG_STICK_ADAPTER := preload("res://scripts/core/ui/widgets/w_analog_stick_adapter.gd")
const W_MOTION_TARGET_RESOLVER := preload("res://scripts/core/ui/widgets/w_motion_target_resolver.gd")
const W_BACKGROUND_SHADER := preload("res://scripts/core/ui/widgets/w_background_shader.gd")

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

const STICK_DEADZONE: float = 0.25 # Must match project.godot ui_* action deadzone

var _stick_repeater: RefCounted = null
var _background_image: TextureRect = null
var _background_rect: ColorRect = null
var _background_shader_material: ShaderMaterial = null

@export var motion_target_path: NodePath = NodePath()
@export_enum("none", "retro_grid", "scanline_drift", "arcade_noise") var background_shader_preset: String = BACKGROUND_SHADER_PRESET_NONE
@export_range(0.0, 1.0, 0.01) var background_shader_intensity: float = 0.5
@export_range(0.0, 5.0, 0.01) var background_shader_speed: float = 1.0

func _ready() -> void:
	super._ready()
	_setup_background_shader()

	# Initialize analog stick repeater
	var repeater_script: Script = load(ANALOG_STICK_REPEATER_PATH)
	if repeater_script != null:
		_stick_repeater = repeater_script.new()
		if _stick_repeater != null:
			_stick_repeater.on_navigate = _navigate_focus

func _process(delta: float) -> void:
	if _background_image == null:
		_update_background_shader_state()

	# Update analog stick repeater ONLY for analog input (not keyboard/D-pad)
	# This prevents double-firing since keyboard/D-pad have built-in repeat
	if _stick_repeater:
		_stick_repeater.update("ui_up",    W_ANALOG_STICK_ADAPTER.is_pressed("ui_up"),    delta)
		_stick_repeater.update("ui_down",  W_ANALOG_STICK_ADAPTER.is_pressed("ui_down"),  delta)
		_stick_repeater.update("ui_left",  W_ANALOG_STICK_ADAPTER.is_pressed("ui_left"),  delta)
		_stick_repeater.update("ui_right", W_ANALOG_STICK_ADAPTER.is_pressed("ui_right"), delta)

func _unhandled_input(event: InputEvent) -> void:
	# Swallow analog stick motion events used for navigation so Godot's built-in
	# ui_up/down/left/right handling does not also move focus. This ensures the
	# U_AnalogStickRepeater is the single source of analog navigation and prevents
	# double-skips when changing direction after a held repeat.
	if W_ANALOG_STICK_ADAPTER.should_swallow(event):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
	super._unhandled_input(event)

func _navigate_focus(direction: StringName) -> void:
	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner() if viewport != null else null
	if focused == null:
		return
	if not is_ancestor_of(focused):
		return

	var next_control: Control = null
	match direction:
		"ui_up":
			if focused.focus_neighbor_top != NodePath():
				next_control = focused.get_node_or_null(focused.focus_neighbor_top) as Control
		"ui_down":
			if focused.focus_neighbor_bottom != NodePath():
				next_control = focused.get_node_or_null(focused.focus_neighbor_bottom) as Control
		"ui_left":
			if focused.focus_neighbor_left != NodePath():
				next_control = focused.get_node_or_null(focused.focus_neighbor_left) as Control
		"ui_right":
			if focused.focus_neighbor_right != NodePath():
				next_control = focused.get_node_or_null(focused.focus_neighbor_right) as Control

	if next_control != null and next_control.is_visible_in_tree():
		_arm_focus_sound(focused)
		next_control.grab_focus()

func reset_analog_navigation() -> void:
	if _stick_repeater:
		_stick_repeater.reset()

func play_enter_animation() -> Tween:
	return U_UI_MOTION.play_enter(W_MOTION_TARGET_RESOLVER.resolve(self, motion_target_path), motion_set)

func play_exit_animation() -> Tween:
	return U_UI_MOTION.play_exit(W_MOTION_TARGET_RESOLVER.resolve(self, motion_target_path), motion_set)

func _resolve_background() -> Control:
	var bg_image := get_node_or_null("BackgroundImage") as TextureRect
	if bg_image != null:
		return bg_image
	var background := get_node_or_null("Background") as ColorRect
	if background != null:
		return background
	var overlay_background := get_node_or_null("OverlayBackground") as ColorRect
	if overlay_background != null:
		return overlay_background
	return get_node_or_null("ColorRect") as ColorRect

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
		_background_rect = null
		return

	if background_shader_preset != BACKGROUND_SHADER_PRESET_NONE:
		if _setup_background_image(background_shader_preset):
			return

	_background_rect = _resolve_background() as ColorRect
	if _background_rect == null:
		return

	_background_shader_material = W_BACKGROUND_SHADER.setup_material(
		_background_rect, background_shader_preset, background_shader_intensity, background_shader_speed
	)

func _update_background_shader_state() -> void:
	if _background_image != null:
		return
	if background_shader_preset == BACKGROUND_SHADER_PRESET_NONE:
		return
	if _background_rect == null or not is_instance_valid(_background_rect):
		_setup_background_shader()
		return
	W_BACKGROUND_SHADER.update_uniforms(
		_background_shader_material, background_shader_preset, background_shader_intensity, background_shader_speed
	)

func _get_background_shader_mode(preset: String) -> int:
	if BACKGROUND_SHADER_PRESET_MODE_BY_ID.has(preset):
		return int(BACKGROUND_SHADER_PRESET_MODE_BY_ID[preset])
	return -1
