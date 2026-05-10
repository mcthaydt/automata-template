extends GutTest

const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/core/utils/display/u_mobile_platform_detector.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/core/state/selectors/u_display_selectors.gd")

var _original_mobile_feature: bool = false

func before_each() -> void:
	_original_mobile_feature = OS.has_feature("mobile")

func after_each() -> void:
	# Restore original state
	U_MOBILE_PLATFORM_DETECTOR.set_testing(false)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(-1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)
	U_MOBILE_PLATFORM_DETECTOR.set_scaling_suppressed(false)

func test_is_mobile_returns_os_feature_by_default() -> void:
	# Without override, should match OS feature
	U_MOBILE_PLATFORM_DETECTOR.set_testing(false)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(-1)
	var expected := OS.has_feature("mobile")
	assert_eq(U_MOBILE_PLATFORM_DETECTOR.is_mobile(), expected,
		"is_mobile() should match OS.has_feature('mobile') when no override is set")

func test_is_mobile_override_true() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	assert_true(U_MOBILE_PLATFORM_DETECTOR.is_mobile(),
		"is_mobile() should return true when override is set to 1")

func test_is_mobile_override_false() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	assert_false(U_MOBILE_PLATFORM_DETECTOR.is_mobile(),
		"is_mobile() should return false when override is set to 0")

func test_is_mobile_override_clear_restores_os() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	# Clear override
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(-1)
	var expected := OS.has_feature("mobile")
	assert_eq(U_MOBILE_PLATFORM_DETECTOR.is_mobile(), expected,
		"is_mobile() should fall back to OS feature when override is cleared")

func test_get_viewport_scale_factor_desktop() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	assert_eq(U_MOBILE_PLATFORM_DETECTOR.get_viewport_scale_factor(), 1.0,
		"Viewport scale factor should be 1.0 on desktop")

func test_get_viewport_scale_factor_mobile() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	assert_eq(U_MOBILE_PLATFORM_DETECTOR.get_viewport_scale_factor(), U_MOBILE_PLATFORM_DETECTOR.MOBILE_SCALE_FACTOR,
		"Viewport scale factor should be MOBILE_SCALE_FACTOR on mobile")

func test_mobile_resolution_scale_selector_clamps_to_safe_range() -> void:
	assert_almost_eq(
		U_DISPLAY_SELECTORS.get_mobile_resolution_scale({"display": {"mobile_resolution_scale": 0.1}}),
		0.25,
		0.001,
		"Selector should clamp mobile scale to minimum safe value"
	)
	assert_almost_eq(
		U_DISPLAY_SELECTORS.get_mobile_resolution_scale({"display": {"mobile_resolution_scale": 1.5}}),
		1.0,
		0.001,
		"Selector should clamp mobile scale to maximum native scale"
	)

func test_get_viewport_scale_factor_uses_display_state_on_mobile() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)

	assert_almost_eq(
		U_MOBILE_PLATFORM_DETECTOR.get_viewport_scale_factor({"display": {"mobile_resolution_scale": 0.5}}),
		0.5,
		0.001,
		"Mobile viewport scale should use display state when provided"
	)

func test_scale_viewport_size_desktop_no_change() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	var result := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(Vector2i(1920, 1080))
	assert_eq(result, Vector2i(1920, 1080),
		"Desktop viewport size should not be scaled")

func test_scale_viewport_size_mobile_scales_by_default_factor() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	var result := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(Vector2i(1080, 2400))
	var factor: float = U_MOBILE_PLATFORM_DETECTOR.MOBILE_SCALE_FACTOR
	var expected := Vector2i(
		maxi(int(1080 * factor), U_MOBILE_PLATFORM_DETECTOR.MOBILE_MIN_VIEWPORT_WIDTH),
		maxi(int(2400 * factor), U_MOBILE_PLATFORM_DETECTOR.MOBILE_MIN_VIEWPORT_HEIGHT)
	)
	assert_eq(result, expected,
		"Mobile viewport size should be scaled by MOBILE_SCALE_FACTOR")

func test_scale_viewport_size_respects_minimum() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	# Very small input should still meet minimum bounds
	var result := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(Vector2i(500, 400))
	assert_true(result.x >= U_MOBILE_PLATFORM_DETECTOR.MOBILE_MIN_VIEWPORT_WIDTH,
		"Scaled width should meet minimum viewport width")
	assert_true(result.y >= U_MOBILE_PLATFORM_DETECTOR.MOBILE_MIN_VIEWPORT_HEIGHT,
		"Scaled height should meet minimum viewport height")

func test_scale_viewport_size_with_custom_scale() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(0.75)
	var result := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(Vector2i(1200, 1600))
	# 0.75 of 1200 = 900, 0.75 of 1600 = 1200
	assert_eq(result, Vector2i(900, 1200),
		"Custom scale override should be applied")

func test_scale_viewport_size_clear_scale_override_restores_default() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(0.75)
	# Clear override
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)
	var result := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(Vector2i(1080, 2400))
	var factor: float = U_MOBILE_PLATFORM_DETECTOR.MOBILE_SCALE_FACTOR
	var expected := Vector2i(
		maxi(int(1080 * factor), U_MOBILE_PLATFORM_DETECTOR.MOBILE_MIN_VIEWPORT_WIDTH),
		maxi(int(2400 * factor), U_MOBILE_PLATFORM_DETECTOR.MOBILE_MIN_VIEWPORT_HEIGHT)
	)
	assert_eq(result, expected,
		"Should fall back to MOBILE_SCALE_FACTOR when scale override is cleared")

# --- scale_viewport_size with design_size parameter ---

func test_scale_viewport_size_with_design_size_scales_from_design() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	# Container is DPI-inflated (2249x945) but design is 960x600.
	# Should scale the DESIGN size, not the container.
	var result := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(
		Vector2i(2249, 945), Vector2i(960, 600)
	)
	# 960*factor and 600*factor are clamped by minimum viewport bounds.
	assert_eq(result, Vector2i(480, 320),
		"Should scale design_size on mobile, not DPI-inflated container_size")

func test_scale_viewport_size_without_design_size_uses_container() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	# Without design_size, should fall back to scaling container_size (old behavior)
	var result := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(Vector2i(1080, 2400))
	var factor: float = U_MOBILE_PLATFORM_DETECTOR.MOBILE_SCALE_FACTOR
	var expected := Vector2i(
		maxi(int(1080 * factor), U_MOBILE_PLATFORM_DETECTOR.MOBILE_MIN_VIEWPORT_WIDTH),
		maxi(int(2400 * factor), U_MOBILE_PLATFORM_DETECTOR.MOBILE_MIN_VIEWPORT_HEIGHT)
	)
	assert_eq(result, expected,
		"Without design_size, should scale container_size as before")

func test_scale_viewport_size_design_size_desktop_unchanged() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	var result := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(
		Vector2i(2249, 945), Vector2i(960, 600)
	)
	# On desktop (scale_factor=1.0), design_size * 1.0 = design_size
	assert_eq(result, Vector2i(960, 600),
		"Desktop with design_size should return design_size (1.0 * design_size)")
