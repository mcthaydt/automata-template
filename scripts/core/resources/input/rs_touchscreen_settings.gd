@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_TouchscreenSettings

## Tunables for touchscreen/mobile input handling.
##
## Stores virtual joystick and button sizing, opacity, and deadzone settings.
## Used by S_TouchscreenSystem when processing touch input and rendering
## mobile controls overlay.

@export_range(0.5, 2.0, 0.1) var virtual_joystick_size: float = 0.8
@export_range(0.0, 1.0, 0.01) var joystick_deadzone: float = 0.15
@export_range(0.0, 1.0, 0.05) var virtual_joystick_opacity: float = 0.7
@export_range(0.5, 2.0, 0.1) var button_size: float = 1.0
@export_range(0.0, 1.0, 0.05) var button_opacity: float = 0.8
@export_range(0.1, 5.0, 0.1) var look_drag_sensitivity: float = 1.0

## Applies a circular deadzone to a 2D touch/joystick vector.
## Rescales input from deadzone threshold to 1.0 into a 0.0-1.0 range.
static func apply_touch_deadzone(touch_vector: Vector2, deadzone: float) -> Vector2:
	if touch_vector.is_zero_approx():
		return Vector2.ZERO

	var clamped_deadzone := clampf(deadzone, 0.0, 0.95)
	var magnitude := clampf(touch_vector.length(), 0.0, 1.0)

	if magnitude <= clamped_deadzone:
		return Vector2.ZERO

	# Rescale from [deadzone, 1.0] to [0.0, 1.0]
	var rescaled := 0.0
	if clamped_deadzone >= 0.95:
		rescaled = 0.0
	else:
		rescaled = (magnitude - clamped_deadzone) / max(1.0 - clamped_deadzone, 0.0001)

	return touch_vector.normalized() * clampf(rescaled, 0.0, 1.0)
