extends GutTest

const SAFE_AREA_INSETS := preload("res://scripts/core/utils/display/u_safe_area_insets.gd")

func test_fullscreen_case_returns_zero_insets() -> void:
	var window_rect := Rect2(Vector2.ZERO, Vector2(360, 640))
	var usable_rect := Rect2(Vector2.ZERO, Vector2(360, 640))

	var insets: Rect2 = SAFE_AREA_INSETS.compute(usable_rect, window_rect)

	assert_eq(insets.position, Vector2.ZERO)
	assert_eq(insets.size, Vector2.ZERO)

func test_notched_case_returns_top_inset_only() -> void:
	var window_rect := Rect2(Vector2.ZERO, Vector2(360, 640))
	var usable_rect := Rect2(Vector2(0, 32), Vector2(360, 608))

	var insets: Rect2 = SAFE_AREA_INSETS.compute(usable_rect, window_rect)

	assert_eq(insets.position, Vector2(0, 32))
	assert_eq(insets.size, Vector2.ZERO)

func test_all_sides_padded_case_returns_edge_insets() -> void:
	var window_rect := Rect2(Vector2.ZERO, Vector2(400, 800))
	var usable_rect := Rect2(Vector2(12, 24), Vector2(360, 720))

	var insets: Rect2 = SAFE_AREA_INSETS.compute(usable_rect, window_rect)

	assert_eq(insets.position, Vector2(12, 24))
	assert_eq(insets.size, Vector2(28, 56))
