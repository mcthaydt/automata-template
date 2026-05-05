extends RefCounted
class_name U_DustSpawner

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_VFX_SELECTORS := preload("res://scripts/core/state/selectors/u_vfx_selectors.gd")
const I_VFX_MANAGER := preload("res://scripts/core/interfaces/i_vfx_manager.gd")

const STORE_SERVICE := StringName("state_store")
const DUST_PUFF_TEXTURE := preload("res://assets/core/textures/tex_dust_puff.png")
const DUST_PUFF_NAME_PREFIX := "DustPuff_"

static var _default_material: StandardMaterial3D = null

class DustConfig:
	var count: int = 10
	var lifetime: float = 0.5
	var scale: float = 0.3
	var spread: float = 0.4
	var drift: Vector3 = Vector3.UP
	var spawn_offset: Vector3 = Vector3.ZERO
	var vertical_spread_scale: float = 1.0

	func _init(
		p_count: int = 10,
		p_lifetime: float = 0.5,
		p_scale: float = 0.3,
		p_spread: float = 0.4,
		p_drift: Vector3 = Vector3.UP,
		p_spawn_offset: Vector3 = Vector3.ZERO,
		p_vertical_spread_scale: float = 1.0
	) -> void:
		count = p_count
		lifetime = p_lifetime
		scale = p_scale
		spread = p_spread
		drift = p_drift
		spawn_offset = p_spawn_offset
		vertical_spread_scale = maxf(p_vertical_spread_scale, 0.0)

static func _get_default_material() -> StandardMaterial3D:
	if _default_material != null:
		return _default_material
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	_default_material = material
	return _default_material

func spawn_dust(position: Vector3, container: Node3D, config: DustConfig) -> void:
	if container == null or config == null:
		return

	if not is_dust_enabled(container.get_tree()):
		return

	var material := _get_default_material()

	for i in range(config.count):
		var puff := Sprite3D.new()
		puff.name = DUST_PUFF_NAME_PREFIX + str(i)
		puff.texture = DUST_PUFF_TEXTURE
		puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.material_override = material
		puff.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		puff.scale = Vector3.ZERO
		container.add_child(puff)
		puff.global_position = position + config.spawn_offset + Vector3(
			(randf() - 0.5) * 2 * config.spread,
			(randf() - 0.5) * 2 * config.spread * config.vertical_spread_scale,
			(randf() - 0.5) * 2 * config.spread
		)
		_animate_puff(puff, config)

func _animate_puff(puff: Sprite3D, config: DustConfig) -> void:
	var tween := puff.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var scale_vec := Vector3(config.scale, config.scale, config.scale)
	var phase1_dur := config.lifetime * 0.3
	var phase2_dur := config.lifetime * 0.2
	var phase3_dur := config.lifetime * 0.5
	tween.tween_property(puff, "scale", scale_vec, phase1_dur)
	tween.tween_interval(phase2_dur)
	tween.parallel().tween_property(puff, "modulate:a", 0.0, phase3_dur)
	tween.parallel().tween_property(puff, "position", puff.position + config.drift * config.lifetime, phase3_dur)
	tween.tween_callback(puff.queue_free)

static func get_or_create_effects_container(tree: SceneTree) -> Node3D:
	if tree == null:
		if OS.is_debug_build():
			push_warning("U_DustSpawner: Cannot get effects container - tree is null")
		return null

	if not is_dust_enabled(tree):
		return null

	var manager := U_SERVICE_LOCATOR.try_get_service(StringName("vfx_manager")) as I_VFXManager
	if manager != null:
		var registered_container := manager.get_effects_container() as Node3D
		if registered_container != null and is_instance_valid(registered_container):
			return registered_container

	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return null

	var container := Node3D.new()
	container.name = "EffectsContainer"
	current_scene.add_child(container)
	if manager != null:
		manager.set_effects_container(container)
	return container

static func is_dust_enabled(tree: SceneTree) -> bool:
	if tree == null:
		return true

	var store := U_SERVICE_LOCATOR.try_get_service(STORE_SERVICE) as I_StateStore
	if store == null or not is_instance_valid(store):
		return true

	if not store.is_ready():
		return true

	var state: Dictionary = store.get_state()
	return U_VFX_SELECTORS.is_particles_enabled(state)
