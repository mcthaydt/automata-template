extends SceneTree

const U_SPARKLE_ANIMATOR := preload("res://scripts/core/gameplay/helpers/u_sparkle_animator.gd")

func _init() -> void:
	print("Rebuilding scenes...")
	_rebuild_prefab_player_body()
	_rebuild_prefab_player()
	_rebuild_prefab_goal_zone()
	_rebuild_gameplay_demo_room()
	_rebuild_tmpl_base_scene()
	_rebuild_test_exterior()
	_rebuild_resources()
	print("Done. Scenes rebuilt.")
	quit()

func _rebuild_prefab_player_body() -> void:
	print("Building prefab_player_body...")
	var tex: Texture2D = load("res://assets/core/textures/characters/tex_player_sprite_sheet.png") as Texture2D
	if tex == null:
		push_error("Sprite texture not found")
		return

	var builder := U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "PlayerBodyVisualRoot")

	var sprite := Sprite3D.new()
	sprite.name = "DirectionalSprite"
	sprite.pixel_size = 0.01
	sprite.hframes = 3
	sprite.vframes = 3
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = Vector3(0, 0.64, 0)

	builder.add_child_to(".", sprite)

	var ground := Sprite3D.new()
	ground.name = "GroundIndicator"
	ground.texture = preload("res://assets/core/textures/tex_shadow_blob.png")
	ground.modulate = Color(1, 1, 1, 0.49803922)
	ground.position = Vector3(0, -0.01, 0)
	ground.rotation_degrees = Vector3(-90, 0, 0)
	ground.scale = Vector3(0.08, 0.08, 0.08)
	builder.add_child_to(".", ground)

	builder.save("res://scenes/core/prefabs/prefab_player_body.tscn")

func _rebuild_prefab_player() -> void:
	print("Building prefab_player...")
	var builder := U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.override_property(".", "name", "E_PlayerRoot")
	builder.override_property(".", "entity_id", &"player")
	builder.override_property(".", "tags", [&"player", &"character"])
	builder.add_child_scene_to("Player_Body", "res://scenes/core/prefabs/prefab_player_body.tscn", "Body_Mesh")

	var _capsule_class := CapsuleShape3D
	var capsule: CapsuleShape3D = _capsule_class.new()
	capsule.radius = 0.512
	capsule.height = 1.408
	builder.override_property("Player_Body/CollisionShape3D", "shape", capsule)
	builder.override_property("Player_Body/CollisionShape3D", "transform", Transform3D.IDENTITY.translated(Vector3(0, 0.64, 0)))
	builder.override_property("Player_Body/CameraFollowAnchor", "position", Vector3(0, 0.64, 0))

	builder.add_ecs_component(preload("res://scripts/core/ecs/components/c_input_component.gd"))

	var gamepad_component := Node.new()
	gamepad_component.name = "C_GamepadComponent"
	gamepad_component.set_script(preload("res://scripts/core/ecs/components/c_gamepad_component.gd"))
	gamepad_component.settings = preload("res://resources/core/input/gamepad_settings/cfg_default_gamepad_settings.tres")
	builder.add_child_to("Components", gamepad_component)

	builder.add_ecs_component(preload("res://scripts/core/ecs/components/c_player_tag_component.gd"))

	var surface_component := Node.new()
	surface_component.name = "C_SurfaceDetectorComponent"
	surface_component.set_script(preload("res://scripts/core/ecs/components/c_surface_detector_component.gd"))
	surface_component.character_body_path = NodePath("../../Player_Body")
	builder.add_child_to("Components", surface_component)

	var spawn_recovery_component := Node.new()
	spawn_recovery_component.name = "C_SpawnRecoveryComponent"
	spawn_recovery_component.set_script(preload("res://scripts/core/ecs/components/c_spawn_recovery_component.gd"))
	spawn_recovery_component.settings = preload("res://resources/core/base_settings/gameplay/cfg_spawn_recovery_player_default.tres")
	builder.add_child_to("Components", spawn_recovery_component)

	builder.save("res://scenes/core/prefabs/prefab_player.tscn")

func _rebuild_gameplay_demo_room() -> void:
	print("Building gameplay_demo_room...")
	var builder := U_TemplateBaseSceneBuilder.new()
	builder.create_root()
	builder.build_scene_objects()
	builder.build_environment()
	builder.build_systems()
	builder.build_managers()
	var demo_directive: Resource = preload("res://scripts/demo/helpers/br_demo_intro_directive.gd").new().build()
	builder.add_scene_director_directive(demo_directive)
	builder.build_entities()

	var root: Node3D = builder.build()
	_build_lighting(root)
	var spawn_points: Node = root.get_node_or_null("Entities/SpawnPoints")
	if spawn_points != null:
		var spawn := Marker3D.new()
		spawn.name = "sp_default"
		spawn.position = Vector3(0, 0.0, 0)
		spawn_points.add_child(spawn)

	builder.save("res://scenes/demo/gameplay/gameplay_demo_room.tscn")

func _build_lighting(root: Node3D) -> void:
	var lighting := Node.new()
	lighting.name = "Lighting"
	const MARKER_LIGHTING_GROUP := preload("res://scripts/core/scene_structure/marker_lighting_group.gd")
	lighting.set_script(MARKER_LIGHTING_GROUP)
	root.add_child(lighting)

	var global_zone := Node3D.new()
	global_zone.name = "L_GlobalZone"
	const L_GLOBAL_ZONE_SCRIPT := preload("res://scripts/core/gameplay/l_global_zone.gd")
	global_zone.set_script(L_GLOBAL_ZONE_SCRIPT)
	const PROFILE_DEMO_DEFAULT := preload("res://resources/demo/lighting/profiles/cfg_character_lighting_profile_demo_default.tres")
	global_zone.profile = PROFILE_DEMO_DEFAULT
	lighting.add_child(global_zone)

func _rebuild_tmpl_base_scene() -> void:
	print("Building tmpl_base_scene...")
	var builder := U_TemplateBaseSceneBuilder.new()
	builder.create_root()
	builder.build_scene_objects()
	builder.build_environment()
	builder.build_systems()
	builder.build_managers()
	builder.build_entities()
	builder.save("res://scenes/core/templates/tmpl_base_scene.tscn")

func _rebuild_prefab_goal_zone() -> void:
	print("Building prefab_goal_zone...")
	var builder := U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "E_GoalZone")
	builder.override_property(".", "script", preload("res://scripts/core/gameplay/inter_victory_zone.gd"))
	builder.override_property(".", "config", preload("res://resources/core/interactions/victory/cfg_victory_default.tres"))
	builder.override_property(".", "entity_id", &"goalzone")
	builder.override_property(".", "tags", [&"objective", &"goal"])

	var fade_material: Material = load("res://assets/core/materials/mat_fade_goal.tres")
	builder.add_csg_cylinder("Visual", 0.7910156, 2.0715332, Color.GREEN)
	builder.override_property("Visual", "material", fade_material)

	var sparkle_parent := Node3D.new()
	sparkle_parent.name = "Sparkles"
	sparkle_parent.set_script(U_SPARKLE_ANIMATOR)
	builder.add_child_to(".", sparkle_parent)

	var sparkle_mat := _create_sparkle_material()
	for i in 3:
		var sprite := Sprite3D.new()
		sprite.name = "Sparkle_%d" % i
		sprite.texture = preload("res://assets/core/textures/tex_dust_puff.png")
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.material_override = sparkle_mat
		sprite.visible = false
		sprite.scale = Vector3.ONE * 0.04
		sprite.position = Vector3(
			[-0.2, 0.0, 0.2][i],
			[0.4, 0.9, 0.6][i],
			[-0.15, 0.1, 0.1][i]
		)
		builder.add_child_to("Sparkles", sprite)

	builder.override_property(".", "visual_paths", [NodePath("Visual"), NodePath("Sparkles")])
	builder.save("res://scenes/core/prefabs/prefab_goal_zone.tscn")

func _create_sparkle_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = 2
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.albedo_color = Color(0.97, 0.85, 0.24, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat

func _rebuild_test_exterior() -> void:
	print("Rebuilding test_exterior Sparkles...")
	var packed: PackedScene = load("res://tests/scenes/test_exterior.tscn") as PackedScene
	if packed == null:
		push_error("Failed to load test_exterior.tscn")
		return
	var instance := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	if instance == null:
		push_error("Failed to instantiate test_exterior.tscn")
		return

	var goal := instance.get_node_or_null("Entities/E_FinalGoal") as Node3D
	if goal == null:
		push_error("E_FinalGoal not found in test_exterior")
		instance.free()
		return

	var old_sparkles := goal.get_node_or_null("Sparkles")
	if old_sparkles != null:
		old_sparkles.get_parent().remove_child(old_sparkles)
		old_sparkles.queue_free()

	var sparkle_parent := Node3D.new()
	sparkle_parent.name = "Sparkles"
	sparkle_parent.set_script(U_SPARKLE_ANIMATOR)
	goal.add_child(sparkle_parent)

	var sparkle_mat := _create_sparkle_material()
	for i in 3:
		var sprite := Sprite3D.new()
		sprite.name = "Sparkle_%d" % i
		sprite.texture = preload("res://assets/core/textures/tex_dust_puff.png")
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.material_override = sparkle_mat
		sprite.visible = false
		sprite.scale = Vector3.ONE * 0.04
		sprite.position = Vector3(
			[-0.2, 0.0, 0.2][i],
			[0.4, 0.9, 0.6][i],
			[-0.15, 0.1, 0.1][i]
		)
		sparkle_parent.add_child(sprite)

	_set_owner_recursive(sparkle_parent, instance)

	_set_owner_recursive(instance, instance)
	var new_packed := PackedScene.new()
	var pack_result := new_packed.pack(instance)
	if pack_result != OK:
		push_error("Failed to pack test_exterior: %d" % pack_result)
		instance.free()
		return
	var save_result := ResourceSaver.save(new_packed, "res://tests/scenes/test_exterior.tscn")
	if save_result != OK:
		push_error("Failed to save test_exterior: %d" % save_result)
	else:
		print("test_exterior Sparkles replaced successfully.")
	instance.free()

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if not node.get_scene_file_path().is_empty():
		return
	for child in node.get_children():
		_set_owner_recursive(child, owner)


func _rebuild_resources() -> void:
	print("Rebuilding scene director resources...")
	var br := preload("res://scripts/demo/helpers/br_demo_intro_directive.gd").new()
	var directive := br.build()
	var save_path := "res://resources/core/scene_director/directives/cfg_directive_demo_intro.tres"
	var save_result := ResourceSaver.save(directive, save_path)
	if save_result != OK:
		push_error("Failed to save directive .tres at '%s' (error %d)" % [save_path, save_result])
	else:
		print("  Saved: %s" % save_path)



