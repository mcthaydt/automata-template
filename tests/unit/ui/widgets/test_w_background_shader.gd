extends GutTest

const W_BackgroundShader := preload("res://scripts/core/ui/widgets/w_background_shader.gd")

func test_get_preset_mode_maps_known_presets() -> void:
	assert_eq(W_BackgroundShader.get_preset_mode("retro_grid"), 0, "retro_grid should map to 0")
	assert_eq(W_BackgroundShader.get_preset_mode("scanline_drift"), 1, "scanline_drift should map to 1")
	assert_eq(W_BackgroundShader.get_preset_mode("arcade_noise"), 2, "arcade_noise should map to 2")

func test_get_preset_mode_returns_negative_for_unknown() -> void:
	assert_eq(W_BackgroundShader.get_preset_mode("none"), -1, "none should return -1")
	assert_eq(W_BackgroundShader.get_preset_mode("invalid"), -1, "invalid should return -1")

func test_setup_material_returns_null_for_none_preset() -> void:
	var rect := ColorRect.new()
	add_child_autofree(rect)
	await wait_process_frames(1)
	var material := W_BackgroundShader.setup_material(rect, "none", 0.5, 1.0)
	assert_null(material, "Should return null for 'none' preset")

func test_setup_material_returns_null_for_unknown_preset() -> void:
	var rect := ColorRect.new()
	add_child_autofree(rect)
	await wait_process_frames(1)
	var material := W_BackgroundShader.setup_material(rect, "unknown", 0.5, 1.0)
	assert_null(material, "Should return null for unknown preset")

func test_setup_material_creates_shader_material() -> void:
	var rect := ColorRect.new()
	add_child_autofree(rect)
	await wait_process_frames(1)
	var material := W_BackgroundShader.setup_material(rect, "retro_grid", 0.5, 1.0)
	assert_not_null(material, "Should create ShaderMaterial for valid preset")
	assert_eq(rect.material, material, "Should assign material to rect")

func test_update_uniforms_safe_with_null_material() -> void:
	# Should not crash
	W_BackgroundShader.update_uniforms(null, "retro_grid", 0.5, 1.0)
	pass_test("update_uniforms handles null material safely")
