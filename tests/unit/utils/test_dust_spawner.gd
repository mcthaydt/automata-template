extends GutTest

const DUST_SPAWNER := preload("res://scripts/core/utils/u_dust_spawner.gd")

func test_dust_config_defaults() -> void:
	var config := DUST_SPAWNER.DustConfig.new()
	assert_eq(config.count, 10)
	assert_eq(config.lifetime, 0.5)
	assert_eq(config.scale, 0.3)
	assert_eq(config.spread, 0.4)
	assert_eq(config.drift, Vector3.UP)
	assert_eq(config.spawn_offset, Vector3.ZERO)

func test_dust_config_custom_values() -> void:
	var config := DUST_SPAWNER.DustConfig.new(
		20, 1.0, 0.5, 0.8, Vector3(1, 2, 3), Vector3(0, -1, 0)
	)
	assert_eq(config.count, 20)
	assert_eq(config.lifetime, 1.0)
	assert_eq(config.scale, 0.5)
	assert_eq(config.spread, 0.8)
	assert_eq(config.drift, Vector3(1, 2, 3))
	assert_eq(config.spawn_offset, Vector3(0, -1, 0))

func test_spawn_dust_creates_sprite3d_nodes() -> void:
	var spawner := DUST_SPAWNER.new()
	var config := DUST_SPAWNER.DustConfig.new(5, 0.5, 0.3)
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	spawner.spawn_dust(Vector3.ZERO, container, config)

	assert_eq(container.get_child_count(), 5, "Should create 5 Sprite3D puffs")
	for child in container.get_children():
		assert_true(child is Sprite3D, "Each child should be Sprite3D")

func test_spawn_dust_puff_has_billboard_material() -> void:
	var spawner := DUST_SPAWNER.new()
	var config := DUST_SPAWNER.DustConfig.new(1, 0.5, 0.3)
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	spawner.spawn_dust(Vector3.ZERO, container, config)

	var puff := container.get_child(0) as Sprite3D
	assert_not_null(puff, "Puff should exist")
	assert_eq(puff.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "Should have billboard enabled mode")
	var mat := puff.material_override as StandardMaterial3D
	assert_not_null(mat, "Should have StandardMaterial3D override")
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)

func test_spawn_dust_null_container_returns_early() -> void:
	var spawner := DUST_SPAWNER.new()
	var config := DUST_SPAWNER.DustConfig.new()
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	spawner.spawn_dust(Vector3.ZERO, null, config)
	assert_eq(container.get_child_count(), 0, "Should not spawn with null container")

func test_spawn_dust_null_config_returns_early() -> void:
	var spawner := DUST_SPAWNER.new()
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	spawner.spawn_dust(Vector3.ZERO, container, null)
	assert_eq(container.get_child_count(), 0, "Should not spawn with null config")

func test_is_dust_enabled_returns_true_when_no_store() -> void:
	var result := DUST_SPAWNER.is_dust_enabled(null)
	assert_true(result, "Should return true when tree is null")

func test_puff_names_have_prefix() -> void:
	var spawner := DUST_SPAWNER.new()
	var config := DUST_SPAWNER.DustConfig.new(3, 0.5, 0.3)
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	spawner.spawn_dust(Vector3.ZERO, container, config)

	for i in range(3):
		var child := container.get_child(i)
		assert_true(child.name.begins_with("DustPuff_"), "Puff name should have DustPuff_ prefix")