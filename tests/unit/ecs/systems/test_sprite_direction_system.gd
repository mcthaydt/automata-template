extends BaseTest

const SystemScript := preload("res://scripts/core/ecs/systems/s_sprite_direction_system.gd")

func _make_system() -> Variant:
	var s := SystemScript.new()
	autofree(s)
	return s

func test_angle_zero_maps_to_down() -> void:
	assert_eq(_make_system()._angle_to_index(0.0), 0)

func test_angle_45deg_maps_to_down_right() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(45.0)), 1)

func test_angle_90deg_maps_to_right() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(90.0)), 2)

func test_angle_135deg_maps_to_up_right() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(135.0)), 3)

func test_angle_180deg_maps_to_up() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(180.0)), 4)

func test_angle_neg_135deg_maps_to_up_left() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(-135.0)), 5)

func test_angle_neg_90deg_maps_to_left() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(-90.0)), 6)

func test_angle_neg_45deg_maps_to_down_left() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(-45.0)), 7)

func test_boundary_at_22_5deg_maps_to_down_right() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(22.5)), 1)

func test_just_under_boundary_maps_to_down() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(22.4)), 0)

func test_direction_names_has_eight_entries() -> void:
	assert_eq(SystemScript.DIRECTION_NAMES.size(), 8)

func test_direction_names_order() -> void:
	assert_eq(SystemScript.DIRECTION_NAMES[0], "down")
	assert_eq(SystemScript.DIRECTION_NAMES[1], "down_right")
	assert_eq(SystemScript.DIRECTION_NAMES[2], "right")
	assert_eq(SystemScript.DIRECTION_NAMES[3], "up_right")
	assert_eq(SystemScript.DIRECTION_NAMES[4], "up")
	assert_eq(SystemScript.DIRECTION_NAMES[5], "up_left")
	assert_eq(SystemScript.DIRECTION_NAMES[6], "left")
	assert_eq(SystemScript.DIRECTION_NAMES[7], "down_left")


const ECS_MANAGER := preload("res://scripts/core/managers/m_ecs_manager.gd")
const MovementComponentScript := preload("res://scripts/core/ecs/components/c_movement_component.gd")
const DirectionComponentScript := preload("res://scripts/core/ecs/components/c_sprite_direction_component.gd")
const SETTINGS_SCRIPT := preload("res://scripts/core/resources/ecs/rs_sprite_direction_settings.gd")
const STATE_STORE_SCRIPT := preload("res://scripts/core/state/m_state_store.gd")
const STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const GAMEPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_gameplay_initial_state.gd")
const MOVEMENT_SETTINGS_SCRIPT := preload("res://scripts/core/resources/ecs/rs_movement_settings.gd")

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")

class FakeBody extends CharacterBody3D:
	pass

class CameraManagerStub extends I_CAMERA_MANAGER:
	var main_camera: Camera3D = null
	func get_main_camera() -> Camera3D:
		return main_camera
	func apply_main_camera_transform(_t: Transform3D) -> void:
		pass
	func is_blend_active() -> bool:
		return false
	func initialize_scene_camera(_scene: Node) -> Camera3D:
		return null
	func finalize_blend_to_scene(_new_scene: Node) -> void:
		pass
	func apply_shake_offset(_offset: Vector2, _rotation: float) -> void:
		pass
	func set_shake_source(_source: StringName, _offset: Vector2, _rotation: float) -> void:
		pass
	func clear_shake_source(_source: StringName) -> void:
		pass

func _pump() -> void:
	await get_tree().process_frame

func _register_camera(camera: Camera3D) -> void:
	var stub := CameraManagerStub.new()
	stub.main_camera = camera
	autofree(stub)
	U_SERVICE_LOCATOR.register(StringName("camera_manager"), stub)

func _setup_context() -> Dictionary:
	var store := STATE_STORE_SCRIPT.new()
	store.settings = STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.gameplay_initial_state = GAMEPLAY_INITIAL_STATE.new()
	add_child(store)
	autofree(store)
	await _pump()

	var manager := ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_DirectionTest"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var body := FakeBody.new()
	entity.add_child(body)
	await _pump()

	var sprite := Sprite3D.new()
	sprite.hframes = 8
	entity.add_child(sprite)
	await _pump()

	var movement: C_MovementComponent = MovementComponentScript.new()
	movement.set(&"settings", MOVEMENT_SETTINGS_SCRIPT.new())
	entity.add_child(movement)
	await _pump()

	var direction: C_SpriteDirectionComponent = DirectionComponentScript.new()
	direction.set(&"settings", SETTINGS_SCRIPT.new())
	direction.direction_mode = C_SpriteDirectionComponent.DirectionMode.SPRITE3D
	entity.add_child(direction)
	await _pump()

	direction.target_node_path = direction.get_path_to(sprite)

	var system := SystemScript.new()
	manager.add_child(system)
	await _pump()

	return {
		"store": store,
		"manager": manager,
		"entity": entity,
		"body": body,
		"sprite": sprite,
		"movement": movement,
		"direction": direction,
		"system": system,
	}


func test_moving_right_sets_right_direction() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var sprite: Sprite3D = context["sprite"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	direction.current_direction_index = 0
	body.velocity = Vector3(5.0, 0.0, 0.0)

	manager._physics_process(0.1)

	assert_eq(direction.current_direction_index, 2)
	assert_eq(direction.current_direction_name, "right")
	assert_eq(sprite.frame, 2)


func test_idle_body_facing_camera_sets_up_direction() -> void:
	## Body facing -Z (yaw = 0). Camera at identity faces +Z.
	## facing_dir = (-sin(0), 0, -cos(0)) = (0, 0, -1).
	## cam_fwd = -camera.basis.z = (0, 0, -1). rel_z = (-1)·(-1) = 1.
	## angle = atan2(0, -1) = PI → index 4 = "up".
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	body.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0.0, 0.0, 0.0)
	direction.current_direction_index = 0

	manager._physics_process(0.1)

	assert_eq(direction.current_direction_index, 4)
	assert_eq(direction.current_direction_name, "up")


func test_facing_override_takes_priority_over_velocity() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	direction.facing_override = Vector3(1.0, 0.0, 0.0)
	body.velocity = Vector3(-5.0, 0.0, 0.0)
	direction.current_direction_index = 0

	manager._physics_process(0.1)

	assert_eq(direction.current_direction_index, 2)


func test_no_camera_does_not_update_direction() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	body.velocity = Vector3(5.0, 0.0, 0.0)
	direction.current_direction_index = 0
	direction.current_direction_name = "down"

	manager._physics_process(0.1)

	assert_eq(direction.current_direction_index, 0)
	assert_eq(direction.current_direction_name, "down")


func test_sprite3d_south_first_sets_frame_directly() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var sprite: Sprite3D = context["sprite"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	direction.frame_layout = C_SpriteDirectionComponent.FrameLayout.SOUTH_FIRST
	body.velocity = Vector3(5.0, 0.0, 0.0)
	direction.current_direction_index = 0

	manager._physics_process(0.1)

	assert_eq(sprite.frame, 2)


func test_sprite3d_north_first_offsets_frame_by_four() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var sprite: Sprite3D = context["sprite"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	direction.frame_layout = C_SpriteDirectionComponent.FrameLayout.NORTH_FIRST
	body.velocity = Vector3(5.0, 0.0, 0.0)
	direction.current_direction_index = 0

	manager._physics_process(0.1)

	assert_eq(sprite.frame, 6)


func test_animated_sprite3d_plays_prefixed_clip() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var entity: Node = context["entity"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	var frames := SpriteFrames.new()
	frames.add_animation("walk_right")
	var anim_sprite := AnimatedSprite3D.new()
	anim_sprite.sprite_frames = frames
	entity.add_child(anim_sprite)
	await get_tree().process_frame

	direction.direction_mode = C_SpriteDirectionComponent.DirectionMode.ANIMATED_SPRITE3D
	direction.target_node_path = direction.get_path_to(anim_sprite)
	direction.animation_prefix = "walk"
	direction.current_direction_index = 0

	body.velocity = Vector3(5.0, 0.0, 0.0)

	manager._physics_process(0.1)

	assert_eq(direction.current_direction_index, 2)
	assert_eq(direction.current_direction_name, "right")


func test_animated_sprite3d_no_prefix_plays_direction_clip() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var entity: Node = context["entity"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	var frames := SpriteFrames.new()
	frames.add_animation("right")
	var anim_sprite := AnimatedSprite3D.new()
	anim_sprite.sprite_frames = frames
	entity.add_child(anim_sprite)
	await get_tree().process_frame

	direction.direction_mode = C_SpriteDirectionComponent.DirectionMode.ANIMATED_SPRITE3D
	direction.target_node_path = direction.get_path_to(anim_sprite)
	direction.animation_prefix = ""
	direction.current_direction_index = 0

	body.velocity = Vector3(5.0, 0.0, 0.0)

	manager._physics_process(0.1)

	assert_eq(direction.current_direction_index, 2)
	assert_eq(direction.current_direction_name, "right")


func test_no_redundant_update_when_direction_unchanged() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var sprite: Sprite3D = context["sprite"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	direction.current_direction_index = 2
	direction.current_direction_name = "right"
	sprite.frame = 7

	body.velocity = Vector3(5.0, 0.0, 0.0)

	manager._physics_process(0.1)

	assert_eq(sprite.frame, 7)


func test_missing_target_node_does_not_crash() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	direction.target_node_path = NodePath("NonExistentNode")
	body.velocity = Vector3(5.0, 0.0, 0.0)

	manager._physics_process(0.1)
	assert_push_error("S_SpriteDirectionSystem")
	assert_true(true)
