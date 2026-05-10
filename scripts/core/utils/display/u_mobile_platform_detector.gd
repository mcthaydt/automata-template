extends RefCounted
class_name U_MobilePlatformDetector

## Detects mobile platform and provides mobile-specific rendering parameters.
##
## Centralizes mobile detection so callers don't need to repeat OS.has_feature()
## checks. Supports test overrides for deterministic unit testing.

const U_DISPLAY_SELECTORS := preload("res://scripts/core/state/selectors/u_display_selectors.gd")

## Default resolution scale factor on mobile (35% of native resolution).
const MOBILE_SCALE_FACTOR: float = 0.35

## Minimum viewport dimensions to avoid rendering artifacts on very small screens.
const MOBILE_MIN_VIEWPORT_WIDTH: int = 480
const MOBILE_MIN_VIEWPORT_HEIGHT: int = 320

## Test override: 1 = force mobile, 0 = force desktop, -1 = use OS detection.
static var _mobile_override: int = -1

## Test override: custom scale factor, < 0 = use MOBILE_SCALE_FACTOR.
static var _scale_override: float = -1.0

## Runtime override: when true, get_viewport_scale_factor() returns 1.0
## regardless of platform. Used to disable mobile scaling for full-screen
## menus so they render at native resolution instead of 35% scaled.
static var _scaling_suppressed: bool = false

## Set to true during tests to enable override behavior.
static var _testing: bool = false

static func set_testing(enabled: bool) -> void:
	_testing = enabled

static func set_mobile_override(value: int) -> void:
	_mobile_override = value

static func set_scale_override(value: float) -> void:
	_scale_override = value

## Runtime toggle for suppressing mobile resolution scaling.
## Set to true when displaying full-screen menus so UI renders at native resolution.
static func set_scaling_suppressed(suppressed: bool) -> void:
	_scaling_suppressed = suppressed

## Returns true if scaling is actively suppressed (non-gameplay scenes).
static func is_scaling_suppressed() -> bool:
	return _scaling_suppressed

## Returns true if running on a mobile device (Android/iOS).
## In tests, uses the override value when set.
static func is_mobile() -> bool:
	if _testing:
		if _mobile_override >= 0:
			return _mobile_override == 1
	if OS.has_feature("headless") or OS.has_feature("server"):
		return false
	return OS.has_feature("mobile")

## Returns the viewport resolution scale factor.
## 1.0 on desktop, MOBILE_SCALE_FACTOR on mobile unless a custom override is set
## or scaling is suppressed.
static func get_viewport_scale_factor(state: Dictionary = {}) -> float:
	if _scaling_suppressed:
		return 1.0
	if _scale_override >= 0.0:
		return _scale_override
	if is_mobile():
		if not state.is_empty():
			return U_DISPLAY_SELECTORS.get_mobile_resolution_scale(state)
		return MOBILE_SCALE_FACTOR
	return 1.0

## Scales a viewport size by the current scale factor, clamped to minimums.
static func scale_viewport_size(container_size: Vector2i, design_size: Vector2i = Vector2i.ZERO) -> Vector2i:
	var scale := get_viewport_scale_factor()
	var base: Vector2i = design_size if design_size.x > 0 else container_size
	var scaled := Vector2i(
		maxi(int(base.x * scale), MOBILE_MIN_VIEWPORT_WIDTH),
		maxi(int(base.y * scale), MOBILE_MIN_VIEWPORT_HEIGHT)
	)
	return scaled
