class_name W_BackgroundShader

## Static helper for applying the menu fullscreen shader to a ColorRect.
## The caller retains ownership of the rect and material instances.

const MENU_FULLSCREEN_SHADER := preload("res://assets/core/shaders/sh_menu_fullscreen_shader.gdshader")

const SHADER_PARAM_PRESET_MODE := StringName("preset_mode")
const SHADER_PARAM_EFFECT_INTENSITY := StringName("effect_intensity")
const SHADER_PARAM_EFFECT_SPEED := StringName("effect_speed")

static func get_preset_mode(preset: String) -> int:
	match preset:
		"retro_grid":     return 0
		"scanline_drift": return 1
		"arcade_noise":   return 2
	return -1

## Creates or re-uses a ShaderMaterial on the given ColorRect and applies uniforms.
## Returns the material so the caller can cache it, or null on failure.
static func setup_material(rect: ColorRect, preset: String, intensity: float, speed: float) -> ShaderMaterial:
	if rect == null or preset == "none":
		return null
	var mode := get_preset_mode(preset)
	if mode < 0:
		return null

	var material := rect.material as ShaderMaterial
	if material == null or material.shader != MENU_FULLSCREEN_SHADER:
		material = ShaderMaterial.new()
		material.shader = MENU_FULLSCREEN_SHADER
		rect.material = material

	_apply_uniforms(material, mode, intensity, speed)
	return material

## Re-applies uniforms to an existing material.  Safe to call every frame.
static func update_uniforms(material: ShaderMaterial, preset: String, intensity: float, speed: float) -> void:
	if material == null:
		return
	var mode := get_preset_mode(preset)
	if mode < 0:
		return
	_apply_uniforms(material, mode, intensity, speed)

static func _apply_uniforms(material: ShaderMaterial, mode: int, intensity: float, speed: float) -> void:
	material.set_shader_parameter(SHADER_PARAM_PRESET_MODE, mode)
	material.set_shader_parameter(SHADER_PARAM_EFFECT_INTENSITY, clampf(intensity, 0.0, 1.0))
	material.set_shader_parameter(SHADER_PARAM_EFFECT_SPEED, clampf(speed, 0.0, 5.0))

