extends BaseTest

const ECS_MANAGER := preload("res://scripts/core/managers/m_ecs_manager.gd")
const PARTICLE_SYSTEM := preload("res://scripts/core/ecs/systems/s_landing_particles_system.gd")
const SETTINGS := preload("res://scripts/core/resources/ecs/rs_landing_particles_settings.gd")
const EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")

const EVENT_NAME := StringName("entity_landed")

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

func test_system_subscribes_to_entity_landed_event_on_ready() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_LandingParticlesSystem = context["system"]

	var payload := {"position": Vector3.ZERO}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 1, "System should queue spawn request after event")

func test_system_clears_spawn_requests_when_disabled() -> void:
	var context := await _create_system_with_settings(false)
	autofree_context(context)
	var system: S_LandingParticlesSystem = context["system"]

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
	var system: S_LandingParticlesSystem = context["system"]

	system.get_parent().remove_child(system)
	autofree_context(context)
	autofree(system)

	var payload := {"position": Vector3.ZERO}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 0, "Removed system should not receive events")

func test_spawn_request_contains_correct_data() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_LandingParticlesSystem = context["system"]

	var payload := {
		"position": Vector3(1, 2, 3),
		"velocity": Vector3(4, 5, 6),
		"vertical_velocity": -5.5,
	}
	EVENT_BUS.publish(EVENT_NAME, payload)

	assert_eq(system.spawn_requests.size(), 1)
	var request: Dictionary = system.spawn_requests[0]
	assert_eq(request.get("position"), Vector3(1, 2, 3))
	assert_eq(request.get("velocity"), Vector3(4, 5, 6))
	assert_eq(request.get("vertical_velocity"), -5.5)
	assert_true(request.has("timestamp"), "Request should have timestamp")

func test_process_tick_clears_spawn_requests_after_processing() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_LandingParticlesSystem = context["system"]

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
	var system: S_LandingParticlesSystem = context["system"]

	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(0, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(5, 0, 0)})
	EVENT_BUS.publish(EVENT_NAME, {"position": Vector3(10, 0, 0)})

	assert_eq(system.spawn_requests.size(), 3, "All requests should be queued")

func test_multiple_spawn_requests_all_cleared_after_processing() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_LandingParticlesSystem = context["system"]

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

func test_default_landing_dust_does_not_drift_upward() -> void:
	var settings := SETTINGS.new()
	assert_true(settings.drift_direction.y <= 0.0, "Landing dust should spread along/down from the ground, not upward")

func test_landing_dust_config_is_ground_hugging() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_LandingParticlesSystem = context["system"]

	var config := system._create_dust_config()

	assert_true(config.vertical_spread_scale <= 0.1, "Landing dust should use mostly horizontal scatter")

func test_settings_use_cloud_animation_default() -> void:
	var settings := SETTINGS.new()
	assert_eq(settings.use_cloud_animation, true, "use_cloud_animation should default to true")

func test_settings_cloud_frame_count_default() -> void:
	var settings := SETTINGS.new()
	assert_eq(settings.cloud_frame_count, 4, "cloud_frame_count should default to 4")

func test_settings_use_cloud_animation_configurable() -> void:
	var settings := SETTINGS.new()
	settings.use_cloud_animation = false
	assert_eq(settings.use_cloud_animation, false, "use_cloud_animation should be configurable")

func test_settings_cloud_frame_count_configurable() -> void:
	var settings := SETTINGS.new()
	settings.cloud_frame_count = 8
	assert_eq(settings.cloud_frame_count, 8, "cloud_frame_count should be configurable")

func test_landing_dust_config_includes_cloud_settings() -> void:
	var context := await _create_system_with_settings()
	autofree_context(context)
	var system: S_LandingParticlesSystem = context["system"]
	var settings: RS_LandingParticlesSettings = context["settings"]
	settings.use_cloud_animation = true
	settings.cloud_frame_count = 4

	var config := system._create_dust_config()
	assert_eq(config.sprite_sheet_frames, 4, "Config should include cloud_frame_count")
	assert_not_null(config.sprite_sheet_texture, "Config should include sprite sheet texture when use_cloud_animation is true")
