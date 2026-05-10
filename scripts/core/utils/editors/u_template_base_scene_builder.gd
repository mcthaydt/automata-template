class_name U_TemplateBaseSceneBuilder
extends RefCounted

const ROOM_SIZE := 5.0
const WALL_HEIGHT := 3.0
const HALF_ROOM := ROOM_SIZE / 2.0
const HALF_WALL_HEIGHT := WALL_HEIGHT / 2.0
const THIN := 0.01

const PREFAB_PLAYER := preload("res://scenes/core/prefabs/prefab_player.tscn")
const PREFAB_CAMERA := preload("res://scenes/core/templates/tmpl_camera.tscn")
const GRID_TEXTURE := preload("res://assets/core/textures/prototype_grids/tex_texture_01.png")
const WALL_MATERIAL := preload("res://assets/core/materials/mat_wall_cutout.tres")
const WALL_CUTOUT_CONFIG := preload("res://resources/core/base_settings/gameplay/cfg_wall_cutout_config_default.tres")
const JUMP_PARTICLES_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_jump_particles_default.tres")
const LANDING_PARTICLES_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_landing_particles_default.tres")
const SCENE_DIRECTOR_BUILDER := preload("res://scripts/core/utils/scene_director/u_scene_director_builder.gd")

const MARKER_SCENE_OBJECTS := preload("res://scripts/core/scene_structure/marker_scene_objects_group.gd")
const MARKER_ENVIRONMENT := preload("res://scripts/core/scene_structure/marker_environment_group.gd")
const MARKER_SYSTEMS := preload("res://scripts/core/scene_structure/marker_systems_group.gd")
const MARKER_SYSTEMS_CORE := preload("res://scripts/core/scene_structure/marker_systems_core_group.gd")
const MARKER_SYSTEMS_PHYSICS := preload("res://scripts/core/scene_structure/marker_systems_physics_group.gd")
const MARKER_SYSTEMS_MOVEMENT := preload("res://scripts/core/scene_structure/marker_systems_movement_group.gd")
const MARKER_SYSTEMS_FEEDBACK := preload("res://scripts/core/scene_structure/marker_systems_feedback_group.gd")
const MARKER_MANAGERS := preload("res://scripts/core/scene_structure/marker_managers_group.gd")
const MARKER_ENTITIES := preload("res://scripts/core/scene_structure/marker_entities_group.gd")
const MARKER_SPAWN_POINTS := preload("res://scripts/core/scene_structure/marker_spawn_points_group.gd")

const BASE_ECS_ENTITY_SCRIPT := preload("res://scripts/core/ecs/base_ecs_entity.gd")

const ROOT_GAME_SCRIPT := preload("res://scripts/core/root.gd")

var _root: Node3D = null

func create_root() -> U_TemplateBaseSceneBuilder:
	var node := Node3D.new()
	node.name = "GameplayRoot"
	node.set_script(ROOT_GAME_SCRIPT)
	_root = node
	return self

func build_scene_objects() -> U_TemplateBaseSceneBuilder:
	var group := Node3D.new()
	group.name = "SceneObjects"
	group.set_script(MARKER_SCENE_OBJECTS)
	_root.add_child(group)

	_add_floor(group)
	_add_ceiling(group)
	_add_wall(group, "SO_Wall_West", Vector3(-HALF_ROOM, HALF_WALL_HEIGHT, 0), Vector3(THIN, WALL_HEIGHT, ROOM_SIZE), &"wall_west")
	_add_wall(group, "SO_Wall_East", Vector3(HALF_ROOM, HALF_WALL_HEIGHT, 0), Vector3(THIN, WALL_HEIGHT, ROOM_SIZE), &"wall_east")
	_add_wall(group, "SO_Wall_North", Vector3(0, HALF_WALL_HEIGHT, -HALF_ROOM), Vector3(ROOM_SIZE, WALL_HEIGHT, THIN), &"wall_north")
	_add_wall(group, "SO_Wall_South", Vector3(0, HALF_WALL_HEIGHT, HALF_ROOM), Vector3(ROOM_SIZE, WALL_HEIGHT, THIN), &"wall_south")
	return self

func build_environment() -> U_TemplateBaseSceneBuilder:
	var group := Node.new()
	group.name = "Environment"
	group.set_script(MARKER_ENVIRONMENT)
	_root.add_child(group)

	var world_env := WorldEnvironment.new()
	world_env.name = "Env_WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	world_env.environment = env
	group.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.name = "Env_DirectionalLight3D"
	light.light_color = Color(0.56078434, 0.827451, 1, 1)
	light.light_energy = 1.5
	light.light_indirect_energy = 0.0
	group.add_child(light)
	return self

func build_systems() -> U_TemplateBaseSceneBuilder:
	var group := Node.new()
	group.name = "Systems"
	group.set_script(MARKER_SYSTEMS)
	_root.add_child(group)

	_add_core_systems(group)
	_add_physics_systems(group)
	_add_movement_systems(group)
	_add_feedback_systems(group)
	return self

func build_managers() -> U_TemplateBaseSceneBuilder:
	var group := Node.new()
	group.name = "Managers"
	group.set_script(MARKER_MANAGERS)
	_root.add_child(group)

	var ecs_manager := Node.new()
	ecs_manager.name = "M_ECSManager"
	const ECS_MANAGER_SCRIPT := preload("res://scripts/core/managers/m_ecs_manager.gd")
	ecs_manager.set_script(ECS_MANAGER_SCRIPT)
	group.add_child(ecs_manager)

	var sd_builder := SCENE_DIRECTOR_BUILDER.new()
	sd_builder.create_root()
	var sd_node: Node = sd_builder.build()
	group.add_child(sd_node)
	sd_node.set_owner(_root)
	return self


func add_scene_director_directive(directive: Resource) -> U_TemplateBaseSceneBuilder:
	if _root == null:
		push_error("U_TemplateBaseSceneBuilder: add_scene_director_directive() called before create_root()")
		return self
	var sd_node: Node = _root.get_node_or_null("Managers/M_SceneDirectorManager")
	if sd_node == null:
		push_error("U_TemplateBaseSceneBuilder: add_scene_director_directive() requires build_managers() first")
		return self
	var current: Array[Resource] = sd_node.directives
	current.append(directive)
	sd_node.directives = current
	return self

func build_entities() -> U_TemplateBaseSceneBuilder:
	var group := Node.new()
	group.name = "Entities"
	group.set_script(MARKER_ENTITIES)
	_root.add_child(group)

	var player := PREFAB_PLAYER.instantiate()
	player.name = "E_Player"
	player.set_scene_file_path("res://scenes/core/prefabs/prefab_player.tscn")
	group.add_child(player)

	var camera := PREFAB_CAMERA.instantiate()
	camera.name = "E_CameraRoot"
	camera.set_scene_file_path("res://scenes/core/templates/tmpl_camera.tscn")
	group.add_child(camera)

	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	spawn_points.set_script(MARKER_SPAWN_POINTS)
	group.add_child(spawn_points)
	return self

func save(path: String) -> bool:
	if _root == null:
		push_error("U_TemplateBaseSceneBuilder: save() called before create_root()")
		return false
	_set_owner_recursive(_root, _root)
	var packed := PackedScene.new()
	var pack_result := packed.pack(_root)
	if pack_result != OK:
		push_error("U_TemplateBaseSceneBuilder: pack() failed with code %d" % pack_result)
		return false
	var save_result := ResourceSaver.save(packed, path)
	if save_result != OK:
		push_error("U_TemplateBaseSceneBuilder: ResourceSaver.save() failed with code %d" % save_result)
		return false
	return true

func build() -> Node3D:
	if _root == null:
		push_error("U_TemplateBaseSceneBuilder: build() called before create_root()")
		return null
	return _root

func _add_floor(parent: Node3D) -> void:
	var box := CSGBox3D.new()
	box.name = "SO_Floor"
	box.use_collision = true
	box.size = Vector3(ROOM_SIZE, THIN, ROOM_SIZE)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = GRID_TEXTURE
	box.material = mat
	parent.add_child(box)

func _add_ceiling(parent: Node3D) -> void:
	var box := CSGBox3D.new()
	box.name = "SO_Ceiling"
	box.position = Vector3(0, WALL_HEIGHT, 0)
	box.use_collision = true
	box.size = Vector3(ROOM_SIZE, THIN, ROOM_SIZE)
	box.material = WALL_MATERIAL
	parent.add_child(box)

func _add_wall(parent: Node3D, name_: String, position: Vector3, size: Vector3, entity_id: StringName) -> void:
	var box := CSGBox3D.new()
	box.name = name_
	box.position = position
	box.use_collision = true
	box.size = size
	box.material = WALL_MATERIAL
	box.set_script(BASE_ECS_ENTITY_SCRIPT)
	box.entity_id = entity_id
	parent.add_child(box)

func _add_core_systems(parent: Node) -> void:
	var core := Node.new()
	core.name = "Core"
	core.set_script(MARKER_SYSTEMS_CORE)
	parent.add_child(core)

	var input_sys := Node.new()
	input_sys.name = "S_InputSystem"
	const INPUT_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_input_system.gd")
	input_sys.set_script(INPUT_SYSTEM_SCRIPT)
	core.add_child(input_sys)

	var touchscreen_sys := Node.new()
	touchscreen_sys.name = "S_TouchscreenSystem"
	const TOUCHSCREEN_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_touchscreen_system.gd")
	touchscreen_sys.set_script(TOUCHSCREEN_SYSTEM_SCRIPT)
	core.add_child(touchscreen_sys)

	var vcam_sys := Node.new()
	vcam_sys.name = "S_VCamSystem"
	const VCAM_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_vcam_system.gd")
	vcam_sys.set_script(VCAM_SYSTEM_SCRIPT)
	vcam_sys.execution_priority = 100
	core.add_child(vcam_sys)

	var wall_sys := Node.new()
	wall_sys.name = "S_WallCutoutSystem"
	const WALL_CUTOUT_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_wall_cutout_system.gd")
	wall_sys.set_script(WALL_CUTOUT_SYSTEM_SCRIPT)
	wall_sys.wall_cutout_config = WALL_CUTOUT_CONFIG
	core.add_child(wall_sys)

func _add_physics_systems(parent: Node) -> void:
	var physics := Node.new()
	physics.name = "Physics"
	physics.set_script(MARKER_SYSTEMS_PHYSICS)
	parent.add_child(physics)

	var grav := Node.new()
	grav.name = "S_GravitySystem"
	const GRAVITY_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_gravity_system.gd")
	grav.set_script(GRAVITY_SYSTEM_SCRIPT)
	grav.execution_priority = 60
	physics.add_child(grav)

	var jump := Node.new()
	jump.name = "S_JumpSystem"
	const JUMP_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_jump_system.gd")
	jump.set_script(JUMP_SYSTEM_SCRIPT)
	jump.execution_priority = 75
	physics.add_child(jump)

func _add_movement_systems(parent: Node) -> void:
	var movement := Node.new()
	movement.name = "Movement"
	movement.set_script(MARKER_SYSTEMS_MOVEMENT)
	parent.add_child(movement)

	_add_system_node(movement, "S_MovementSystem", preload("res://scripts/core/ecs/systems/s_movement_system.gd"), 50)
	_add_system_node(movement, "S_FloatingSystem", preload("res://scripts/core/ecs/systems/s_floating_system.gd"), 70)
	_add_system_node(movement, "S_SpawnRecoverySystem", preload("res://scripts/core/ecs/systems/s_spawn_recovery_system.gd"), 75)
	_add_system_node(movement, "S_RotateToInputSystem", preload("res://scripts/core/ecs/systems/s_rotate_to_input_system.gd"), 80)
	_add_system_node(movement, "S_AlignWithSurfaceSystem", preload("res://scripts/core/ecs/systems/s_align_with_surface_system.gd"), 90)

func _add_feedback_systems(parent: Node) -> void:
	var feedback := Node.new()
	feedback.name = "Feedback"
	feedback.set_script(MARKER_SYSTEMS_FEEDBACK)
	parent.add_child(feedback)

	_add_system_node(feedback, "S_LandingIndicatorSystem", preload("res://scripts/core/ecs/systems/s_landing_indicator_system.gd"), 110)

	var jump_parts := Node.new()
	jump_parts.name = "S_JumpParticlesSystem"
	const JUMP_PARTICLES_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_jump_particles_system.gd")
	jump_parts.set_script(JUMP_PARTICLES_SYSTEM_SCRIPT)
	jump_parts.settings = JUMP_PARTICLES_SETTINGS
	jump_parts.execution_priority = 120
	feedback.add_child(jump_parts)

	_add_system_node(feedback, "S_JumpSoundSystem", preload("res://scripts/core/ecs/systems/s_jump_sound_system.gd"), 121)

	var land_parts := Node.new()
	land_parts.name = "S_LandingParticlesSystem"
	const LANDING_PARTICLES_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_landing_particles_system.gd")
	land_parts.set_script(LANDING_PARTICLES_SYSTEM_SCRIPT)
	land_parts.settings = LANDING_PARTICLES_SETTINGS
	feedback.add_child(land_parts)

	_add_system_node(feedback, "S_GamepadVibrationSystem", preload("res://scripts/core/ecs/systems/s_gamepad_vibration_system.gd"), 122)

func _add_system_node(parent: Node, name_: String, script: Script, priority: int) -> void:
	var node := Node.new()
	node.name = name_
	node.set_script(script)
	node.execution_priority = priority
	parent.add_child(node)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.set_owner(owner)
	var scene_path: String = node.get_scene_file_path()
	if not scene_path.is_empty():
		return
	for child in node.get_children():
		_set_owner_recursive(child, owner)
