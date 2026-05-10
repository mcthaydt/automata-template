extends GutTest

const U_DISPLAY_WINDOW_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_window_applier.gd")
const MOBILE_PLATFORM_DETECTOR := preload("res://scripts/core/utils/display/u_mobile_platform_detector.gd")

class ResizeGuardWindowOps:
	extends MockWindowOps

	var ignore_next_resize_if_borderless: bool = false

	func window_set_size(size: Vector2i) -> void:
		if ignore_next_resize_if_borderless and borderless:
			calls.append({"method": "window_set_size", "size": size, "ignored": true})
			ignore_next_resize_if_borderless = false
			return
		super.window_set_size(size)

func before_each() -> void:
	MOBILE_PLATFORM_DETECTOR.set_testing(true)
	MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)
	MOBILE_PLATFORM_DETECTOR.set_scaling_suppressed(false)

func after_each() -> void:
	MOBILE_PLATFORM_DETECTOR.set_testing(false)
	MOBILE_PLATFORM_DETECTOR.set_mobile_override(-1)
	MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)
	MOBILE_PLATFORM_DETECTOR.set_scaling_suppressed(false)

func _await_frames(frames: int = 2) -> void:
	for _i in range(frames):
		await get_tree().process_frame

func test_mobile_apply_settings_uses_fullscreen_and_resolution_scale() -> void:
	MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	var applier := U_DISPLAY_WINDOW_APPLIER.new()
	var window_ops := MockWindowOps.new()
	applier.set_window_ops(window_ops)

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "windowed",
		"mobile_resolution_scale": 0.5,
		"vsync_enabled": true,
	})

	assert_eq(
		window_ops.window_mode,
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		"Mobile should use fullscreen presentation"
	)
	assert_almost_eq(
		MOBILE_PLATFORM_DETECTOR.get_viewport_scale_factor(),
		0.5,
		0.001,
		"Mobile display settings should drive mobile resolution scale"
	)

func test_desktop_apply_settings_ignores_mobile_resolution_scale() -> void:
	var applier := U_DISPLAY_WINDOW_APPLIER.new()
	var window_ops := MockWindowOps.new()
	applier.set_window_ops(window_ops)

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "windowed",
		"mobile_resolution_scale": 0.5,
		"vsync_enabled": true,
	})

	assert_eq(
		window_ops.window_mode,
		DisplayServer.WINDOW_MODE_WINDOWED,
		"Desktop should keep the normal window_mode"
	)
	assert_almost_eq(
		MOBILE_PLATFORM_DETECTOR.get_viewport_scale_factor(),
		1.0,
		0.001,
		"Desktop should not apply mobile resolution scale"
	)

func test_windowed_restore_reapplies_size_after_borderless_fullscreen() -> void:
	var applier := U_DISPLAY_WINDOW_APPLIER.new()
	var owner := Node.new()
	add_child_autofree(owner)
	applier.initialize(owner)

	var window_ops := ResizeGuardWindowOps.new()
	window_ops.screen_size = Vector2i(1920, 1080)
	applier.set_window_ops(window_ops)

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "windowed",
		"vsync_enabled": true,
	})
	await _await_frames()

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "borderless",
		"vsync_enabled": true,
	})
	await _await_frames()

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "fullscreen",
		"vsync_enabled": true,
	})
	await _await_frames()

	window_ops.ignore_next_resize_if_borderless = true
	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "windowed",
		"vsync_enabled": true,
	})
	await _await_frames(3)

	assert_eq(
		window_ops.window_size,
		Vector2i(1280, 720),
		"Windowed restore should reapply preset size after mode settles"
	)

func test_mobile_fullscreen_sets_orientation_to_sensor() -> void:
	MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	var applier := U_DISPLAY_WINDOW_APPLIER.new()
	var window_ops := MockWindowOps.new()
	applier.set_window_ops(window_ops)

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "windowed",
		"mobile_resolution_scale": 0.5,
		"vsync_enabled": true,
	})

	assert_eq(
		window_ops.orientation,
		U_DISPLAY_WINDOW_APPLIER.SCREEN_ORIENTATION_SENSOR_LANDSCAPE,
		"Mobile fullscreen should set orientation to SENSOR_LANDSCAPE for rotation responsiveness"
	)

func test_desktop_window_mode_does_not_change_orientation() -> void:
	var applier := U_DISPLAY_WINDOW_APPLIER.new()
	var window_ops := MockWindowOps.new()
	applier.set_window_ops(window_ops)

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "windowed",
		"vsync_enabled": true,
	})

	assert_eq(
		window_ops.get_call_count("screen_set_orientation"),
		0,
		"Desktop windowed mode should not override screen orientation"
	)

func test_mobile_apply_settings_skips_desktop_window_resize() -> void:
	MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	var applier := U_DISPLAY_WINDOW_APPLIER.new()
	var owner := Node.new()
	add_child_autofree(owner)
	applier.initialize(owner)

	var window_ops := MockWindowOps.new()
	window_ops.window_mode = DisplayServer.WINDOW_MODE_WINDOWED
	window_ops.window_size = Vector2i(900, 700)
	applier.set_window_ops(window_ops)

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "windowed",
		"vsync_enabled": true,
		"mobile_resolution_scale": 0.5,
	})
	await _await_frames()

	assert_eq(
		window_ops.window_mode,
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		"Mobile presentation should force fullscreen through Display Manager window ops"
	)
	assert_eq(
		window_ops.window_size,
		Vector2i(900, 700),
		"Mobile fullscreen should not apply desktop window-size presets"
	)
