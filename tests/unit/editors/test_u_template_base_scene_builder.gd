extends GutTest

const BUILDER_PATH := "res://scripts/core/utils/editors/u_template_base_scene_builder.gd"

func _new_builder() -> Object:
	assert_true(FileAccess.file_exists(BUILDER_PATH), "Builder script must exist: %s" % BUILDER_PATH)
	if not FileAccess.file_exists(BUILDER_PATH):
		return null
	var script: Variant = load(BUILDER_PATH)
	assert_not_null(script, "Builder script must load")
	if script == null or not (script is Script):
		return null
	var v: Variant = (script as Script).new()
	if v == null or not (v is Object):
		return null
	return v as Object

func after_each() -> void:
	var cleanup_paths := [
		"res://tests/unit/editors/_test_tmpl_base_scene.tscn",
	]
	for path in cleanup_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func test_builder_script_exists_and_loads() -> void:
	var builder: Object = _new_builder()
	assert_not_null(builder, "U_TemplateBaseSceneBuilder must instantiate")

func test_create_root_produces_gameplay_root() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	var root: Variant = builder.call("build")
	autofree(root as Node)
	assert_not_null(root, "build() must return root")
	assert_true(root is Node3D, "Root must be Node3D")
	assert_eq((root as Node).name, "GameplayRoot", "Root must be named GameplayRoot")
	assert_not_null((root as Node).script, "Root must have script attached")

func test_scene_objects_contains_walls_floor_ceiling() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	var root: Node = builder.call("build") as Node
	autofree(root)
	var so: Node = root.get_node_or_null("SceneObjects")
	assert_not_null(so, "SceneObjects group must exist")
	assert_not_null(so.get_node_or_null("SO_Floor"), "Floor must exist")
	assert_not_null(so.get_node_or_null("SO_Ceiling"), "Ceiling must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_West"), "West wall must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_East"), "East wall must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_North"), "North wall must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_South"), "South wall must exist")

func test_scene_objects_follow_2_5d_units_and_scale_contract() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	var root: Node = builder.call("build") as Node
	autofree(root)
	var so: Node = root.get_node_or_null("SceneObjects")
	assert_not_null(so, "SceneObjects group must exist")
	if so == null:
		return

	var floor_node := so.get_node_or_null("SO_Floor") as CSGBox3D
	var ceiling_node := so.get_node_or_null("SO_Ceiling") as CSGBox3D
	var west_wall := so.get_node_or_null("SO_Wall_West") as CSGBox3D
	var north_wall := so.get_node_or_null("SO_Wall_North") as CSGBox3D
	assert_not_null(floor_node, "Floor must exist")
	assert_not_null(ceiling_node, "Ceiling must exist")
	assert_not_null(west_wall, "West wall must exist")
	assert_not_null(north_wall, "North wall must exist")
	if floor_node == null or ceiling_node == null or west_wall == null or north_wall == null:
		return

	assert_eq(floor_node.size, Vector3(5.0, 0.01, 5.0),
		"Default 2.5D base scene floor must be 5 x 5 tiles")
	assert_eq(ceiling_node.position, Vector3(0.0, 3.0, 0.0),
		"Default ceiling must sit at the standard 3-tile wall height")
	assert_eq(west_wall.position, Vector3(-2.5, 1.5, 0.0),
		"West wall must be centered on the 5-tile room edge")
	assert_eq(west_wall.size, Vector3(0.01, 3.0, 5.0),
		"Wall dimensions must use 3-tile height and 5-tile room depth")
	assert_eq(north_wall.position, Vector3(0.0, 1.5, -2.5),
		"North wall must be centered on the 5-tile room edge")
	assert_eq(north_wall.size, Vector3(5.0, 3.0, 0.01),
		"Wall dimensions must use 3-tile height and 5-tile room width")

func test_environment_has_world_environment_and_light() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_environment")
	var root: Node = builder.call("build") as Node
	autofree(root)
	var env: Node = root.get_node_or_null("Environment")
	assert_not_null(env, "Environment group must exist")
	var we: Node = env.get_node_or_null("Env_WorldEnvironment")
	assert_not_null(we, "WorldEnvironment must exist")
	assert_true(we is WorldEnvironment, "Must be WorldEnvironment type")
	assert_not_null((we as WorldEnvironment).environment, "Environment resource must be set")
	var light: Node = env.get_node_or_null("Env_DirectionalLight3D")
	assert_not_null(light, "DirectionalLight3D must exist")
	assert_true(light is DirectionalLight3D, "Must be DirectionalLight3D type")

func test_systems_have_all_four_groups() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_systems")
	var root: Node = builder.call("build") as Node
	autofree(root)
	var systems: Node = root.get_node_or_null("Systems")
	assert_not_null(systems, "Systems group must exist")
	assert_not_null(systems.get_node_or_null("Core"), "Core systems must exist")
	assert_not_null(systems.get_node_or_null("Physics"), "Physics systems must exist")
	assert_not_null(systems.get_node_or_null("Movement"), "Movement systems must exist")
	assert_not_null(systems.get_node_or_null("Feedback"), "Feedback systems must exist")

func test_core_systems_contain_input_vcam_wallcutout() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_systems")
	var root: Node = builder.call("build") as Node
	autofree(root)
	var core: Node = root.get_node_or_null("Systems/Core")
	assert_not_null(core, "Core systems must exist")
	assert_not_null(core.get_node_or_null("S_InputSystem"), "InputSystem must exist")
	assert_not_null(core.get_node_or_null("S_TouchscreenSystem"), "TouchscreenSystem must exist")
	assert_not_null(core.get_node_or_null("S_VCamSystem"), "VCamSystem must exist")
	assert_not_null(core.get_node_or_null("S_WallCutoutSystem"), "WallCutoutSystem must exist")

func test_movement_systems_contain_all_five() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_systems")
	var root: Node = builder.call("build") as Node
	autofree(root)
	var movement: Node = root.get_node_or_null("Systems/Movement")
	assert_not_null(movement, "Movement systems must exist")
	assert_not_null(movement.get_node_or_null("S_MovementSystem"), "MovementSystem must exist")
	assert_not_null(movement.get_node_or_null("S_FloatingSystem"), "FloatingSystem must exist")
	assert_not_null(movement.get_node_or_null("S_SpawnRecoverySystem"), "SpawnRecoverySystem must exist")
	assert_not_null(movement.get_node_or_null("S_RotateToInputSystem"), "RotateToInputSystem must exist")
	assert_not_null(movement.get_node_or_null("S_AlignWithSurfaceSystem"), "AlignWithSurfaceSystem must exist")

func test_managers_contain_ecs_manager() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_managers")
	var root: Node = builder.call("build") as Node
	autofree(root)
	var managers: Node = root.get_node_or_null("Managers")
	assert_not_null(managers, "Managers group must exist")
	assert_not_null(managers.get_node_or_null("M_ECSManager"), "ECSManager must exist")

func test_entities_contain_player_camera_and_spawn_points() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_entities")
	var root: Node = builder.call("build") as Node
	autofree(root)
	var entities: Node = root.get_node_or_null("Entities")
	assert_not_null(entities, "Entities group must exist")
	assert_not_null(entities.get_node_or_null("E_Player"), "Player entity must exist")
	assert_not_null(entities.get_node_or_null("E_CameraRoot"), "Camera entity must exist")
	var spawn_points: Node = entities.get_node_or_null("SpawnPoints")
	assert_not_null(spawn_points, "SpawnPoints must exist")

func test_save_writes_tscn_file() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	builder.call("build_environment")
	builder.call("build_systems")
	builder.call("build_managers")
	builder.call("build_entities")
	autofree(builder.call("build") as Node)
	var save_path: String = "res://tests/unit/editors/_test_tmpl_base_scene.tscn"
	var result: Variant = builder.call("save", save_path)
	assert_true(result, "save() must return true")
	assert_true(FileAccess.file_exists(save_path), "save() must write .tscn file")
	var packed: PackedScene = load(save_path) as PackedScene
	assert_not_null(packed, "Saved file must load as PackedScene")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
