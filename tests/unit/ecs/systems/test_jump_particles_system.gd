extends BaseTest

const ECS_MANAGER := preload("res://scripts/core/managers/m_ecs_manager.gd")
const PARTICLE_SYSTEM := preload("res://scripts/core/ecs/systems/s_jump_particles_system.gd")
const SETTINGS := preload("res://scripts/core/resources/ecs/rs_jump_particles_settings.gd")
const EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")

const EVENT_NAME := StringName("entity_jumped")

func before_each() -> void:
	EVENT_BUS.reset()

func _pump() -> void:
	await get_tree().process_frame

func _spawn_manager() -> M_ECSManager:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	return manager

func _create_system_with_settings(enabled: bool = true) -> Dictionary:
	var manager := _spawn_manager()
	await _pump()

	var system := PARTICLE_SYSTEM.new()
	var settings := SETTINGS.new()
	settings.enabled = enabled
	system.settings = settings
	manager.add_child(system)
	autofree(system)
	await _pump()

	return {
		"manager": manager,
		"system": system,
		"settings": settings,
	}

func test_system_subscribes_to_entity_jumped_event_on_ready() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	var payload := {"position": Vector3.ZERO}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 1, "System should queue spawn request after event")

func test_system_clears_spawn_requests_when_disabled() -> void:
	var context := await _create_system_with_settings(false)
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	system.spawn_requests.append({"position": Vector3.ZERO})

	system.process_tick(0.016)

	assert_eq(system.spawn_requests.size(), 0, "Disabled system should clear spawn requests")

func test_system_clears_spawn_requests_when_settings_null() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := PARTICLE_SYSTEM.new()
	system.settings = null
	manager.add_child(system)
	autofree(system)
	await _pump()

	system.spawn_requests.append({"position": Vector3.ZERO})

	system.process_tick(0.016)

	assert_eq(system.spawn_requests.size(), 0, "System with null settings should clear spawn requests")

func test_system_unsubscribes_on_exit_tree() -> void:
	var context := await _create_system_with_settings()
	var system: S_JumpParticlesSystem = context["system"]

	system.get_parent().remove_child(system)
	autofree_context(context)
	autofree(system)

	var payload := {"position": Vector3.ZERO}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 0, "Removed system should not receive events")

func test_spawn_request_contains_correct_data() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	var payload := {
		"position": Vector3(1, 2, 3),
		"velocity": Vector3(4, 5, 6),
		"jump_force": 15.0,
	}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 1)
	var request: Dictionary = system.spawn_requests[0]
	assert_eq(request.get("position"), Vector3(1, 2, 3))
	assert_eq(request.get("velocity"), Vector3(4, 5, 6))
	assert_eq(request.get("jump_force"), 15.0)
	assert_true(request.has("timestamp"), "Request should have timestamp")

func test_process_tick_clears_spawn_requests_after_processing() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	var payload := {"position": Vector3(0, 5, 0)}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 1, "Request should be queued")

	system.process_tick(0.016)

	assert_eq(system.spawn_requests.size(), 0, "Requests should be cleared after processing")

func test_default_spawn_offset_is_down() -> void:
	var settings = SETTINGS.new()
	assert_eq(settings.spawn_offset, Vector3(0, -0.5, 0), "Default spawn_offset should be Vector3(0, -0.5, 0)")

func test_multiple_spawn_requests_all_queued() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(0, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(5, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(10, 0, 0)})

	assert_eq(system.spawn_requests.size(), 3, "All requests should be queued")

func test_multiple_spawn_requests_all_cleared_after_processing() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_JumpParticlesSystem = context["system"]

	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(0, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(5, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(10, 0, 0)})

	assert_eq(system.spawn_requests.size(), 3, "All requests should be queued")

	system.process_tick(0.016)

	assert_eq(system.spawn_requests.size(), 0, "All requests should be cleared")

func test_settings_count_configurable() -> void:
	var settings := SETTINGS.new()
	settings.count = 50
	assert_eq(settings.count, 50, "Count should be configurable")

func test_settings_lifetime_configurable() -> void:
	var settings := SETTINGS.new()
	settings.lifetime = 2.0
	assert_eq(settings.lifetime, 2.0, "Lifetime should be configurable")

func test_settings_scale_configurable() -> void:
	var settings := SETTINGS.new()
	settings.scale = 0.8
	assert_eq(settings.scale, 0.8, "Scale should be configurable")

func test_settings_spread_configurable() -> void:
	var settings := SETTINGS.new()
	settings.spread = 1.2
	assert_eq(settings.spread, 1.2, "Spread should be configurable")

func test_settings_drift_strength_configurable() -> void:
	var settings := SETTINGS.new()
	settings.drift_strength = 7.5
	assert_eq(settings.drift_strength, 7.5, "Drift strength should be configurable")

func test_settings_drift_direction_configurable() -> void:
	var settings := SETTINGS.new()
	settings.drift_direction = Vector3(1, 0, 0)
	assert_eq(settings.drift_direction, Vector3(1, 0, 0), "Drift direction should be configurable")

func test_default_jump_dust_is_low_and_horizontal() -> void:
	var settings := SETTINGS.new()
	assert_false(settings.enabled, "Jump takeoff dust should be disabled by default; landing dust carries the feedback")
	assert_true(settings.count <= 6, "Jump dust should be a small single puff, not a dense burst")
	assert_true(settings.lifetime <= 0.35, "Jump dust should dissipate quickly")
	assert_true(settings.spread <= 0.3, "Jump dust should stay close to the feet")
	assert_true(settings.drift_strength <= 1.2, "Jump dust should not shoot upward")
	assert_true(settings.drift_direction.y <= 0.0, "Jump dust should drift along/down from the ground, not upward")
