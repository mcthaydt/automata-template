extends GutTest


func test_defaults_match_spec() -> void:
	var settings := RS_TouchscreenSettings.new()
	assert_almost_eq(settings.virtual_joystick_size, 0.8, 0.0001, "Default joystick size should be 0.8")
	assert_almost_eq(settings.joystick_deadzone, 0.15, 0.0001, "Default joystick deadzone should be 0.15")
	assert_almost_eq(settings.virtual_joystick_opacity, 0.7, 0.0001, "Default joystick opacity should be 0.7")
	assert_almost_eq(settings.button_size, 1.0, 0.0001, "Default button size should be 1.0")
	assert_almost_eq(settings.button_opacity, 0.8, 0.0001, "Default button opacity should be 0.8")
	assert_almost_eq(settings.look_drag_sensitivity, 1.0, 0.0001, "Default look drag sensitivity should be 1.0")

func test_apply_touch_deadzone_zeroes_values_below_threshold() -> void:
	var result := RS_TouchscreenSettings.apply_touch_deadzone(Vector2(0.05, 0.05), 0.15)
	assert_true(result.is_zero_approx(), "Touch input under deadzone should be filtered to zero")

func test_apply_touch_deadzone_returns_normalized_values_above_threshold() -> void:
	var input := Vector2(0.8, 0.0)
	var result := RS_TouchscreenSettings.apply_touch_deadzone(input, 0.15)
	assert_true(result.x > 0.0, "Touch input above deadzone should pass through")
	assert_true(result.x <= 1.0, "Result should be normalized to [0, 1]")
	assert_almost_eq(result.y, 0.0, 0.0001)

func test_apply_touch_deadzone_normalizes_to_full_range() -> void:
	# Input at the deadzone edge should map to ~0
	var edge_input := Vector2(0.15, 0.0)
	var edge_result := RS_TouchscreenSettings.apply_touch_deadzone(edge_input, 0.15)
	assert_true(edge_result.is_zero_approx() or edge_result.x < 0.1, "Edge of deadzone should be near zero")

	# Input at maximum should map to 1.0
	var max_input := Vector2(1.0, 0.0)
	var max_result := RS_TouchscreenSettings.apply_touch_deadzone(max_input, 0.15)
	assert_almost_eq(max_result.x, 1.0, 0.0001, "Maximum input should normalize to 1.0")
