extends BaseTest

const SettingsResource := preload("res://scripts/core/resources/ecs/rs_sprite_direction_settings.gd")
const ComponentScript := preload("res://scripts/core/ecs/components/c_sprite_direction_component.gd")
const DirectionComponentClass := preload("res://scripts/core/ecs/components/c_sprite_direction_component.gd")

func test_component_type_is_correct() -> void:
	var c := ComponentScript.new()
	autofree(c)
	assert_eq(c.component_type, StringName("C_SpriteDirectionComponent"))

func test_default_direction_index_is_zero() -> void:
	var c := ComponentScript.new()
	autofree(c)
	assert_eq(c.current_direction_index, 0)

func test_default_direction_name_is_down() -> void:
	var c := ComponentScript.new()
	autofree(c)
	assert_eq(c.current_direction_name, "down")

func test_get_target_node_returns_null_when_path_empty() -> void:
	var c := ComponentScript.new()
	c.set(&"settings", SettingsResource.new())
	add_child(c)
	autofree(c)
	await get_tree().process_frame
	assert_null(c.get_target_node())

func test_validate_required_settings_false_when_null() -> void:
	var c := ComponentScript.new()
	autofree(c)
	assert_false(c._validate_required_settings())
	assert_push_error("C_SpriteDirectionComponent missing settings; assign an RS_SpriteDirectionSettings resource.")

func test_validate_required_settings_true_when_assigned() -> void:
	var c := ComponentScript.new()
	autofree(c)
	c.set(&"settings", SettingsResource.new())
	assert_true(c._validate_required_settings())

func test_direction_mode_enum_has_three_values() -> void:
	assert_eq(DirectionComponentClass.DirectionMode.AUTO, 0)
	assert_eq(DirectionComponentClass.DirectionMode.SPRITE3D, 1)
	assert_eq(DirectionComponentClass.DirectionMode.ANIMATED_SPRITE3D, 2)

func test_frame_layout_enum_has_two_values() -> void:
	assert_eq(DirectionComponentClass.FrameLayout.SOUTH_FIRST, 0)
	assert_eq(DirectionComponentClass.FrameLayout.NORTH_FIRST, 1)
