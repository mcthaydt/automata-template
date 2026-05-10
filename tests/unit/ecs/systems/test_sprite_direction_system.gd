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
