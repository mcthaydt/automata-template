@icon("res://assets/core/editor_icons/icn_system.svg")
extends BaseEventVFXSystem
class_name S_LandingParticlesSystem

const SETTINGS_TYPE := preload("res://scripts/core/resources/ecs/rs_landing_particles_settings.gd")
const DUST_SPAWNER := preload("res://scripts/core/utils/u_dust_spawner.gd")

@export var settings: SETTINGS_TYPE

var spawn_requests: Array:
	get:
		return requests

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.VFX

func get_event_name() -> StringName:
	return StringName("entity_landed")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"position": payload.get("position", Vector3.ZERO),
		"velocity": payload.get("velocity", Vector3.ZERO),
		"vertical_velocity": payload.get("vertical_velocity", 0.0),
	}

func process_tick(__delta: float) -> void:
	if settings == null or not settings.enabled:
		requests.clear()
		return

	if requests.size() == 0:
		return

	var container := DUST_SPAWNER.get_or_create_effects_container(get_tree())
	if container == null:
		requests.clear()
		return

	var spawner := DUST_SPAWNER.new()
	var config := _create_dust_config()

	for request in requests:
		var position: Vector3 = request.get("position", Vector3.ZERO)
		spawner.spawn_dust(position, container, config)

	requests.clear()

func _create_dust_config() -> DUST_SPAWNER.DustConfig:
	return DUST_SPAWNER.DustConfig.new(
		settings.count,
		settings.lifetime,
		settings.scale,
		settings.spread,
		settings.drift_direction * settings.drift_strength,
		settings.spawn_offset
	)