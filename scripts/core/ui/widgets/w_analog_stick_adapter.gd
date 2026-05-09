class_name W_AnalogStickAdapter

## Static helper for analog stick detection and input-event swallowing.
##
## Extracted from BaseMenuScreen to centralize joystick/deadzone logic.

const STICK_DEADZONE: float = 0.25

static func is_pressed(direction: StringName) -> bool:
	match direction:
		"ui_up":
			return _is_axis_pressed(JOY_AXIS_LEFT_Y, -1.0)
		"ui_down":
			return _is_axis_pressed(JOY_AXIS_LEFT_Y, 1.0)
		"ui_left":
			return _is_axis_pressed(JOY_AXIS_LEFT_X, -1.0)
		"ui_right":
			return _is_axis_pressed(JOY_AXIS_LEFT_X, 1.0)
	return false

static func _is_axis_pressed(axis: int, sign: float) -> bool:
	for device in Input.get_connected_joypads():
		var value: float = Input.get_joy_axis(device, axis)
		if sign > 0.0 and value > STICK_DEADZONE:
			return true
		if sign < 0.0 and value < -STICK_DEADZONE:
			return true
	return false

## Returns true if the event should be swallowed (handled) to prevent
## Godot built-in ui_* focus navigation from double-firing.
static func should_swallow(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_Y and abs(motion.axis_value) > STICK_DEADZONE:
			return true
		if motion.axis == JOY_AXIS_LEFT_X and abs(motion.axis_value) > STICK_DEADZONE:
			return true
	elif event is InputEventJoypadButton:
		var button: InputEventJoypadButton = event as InputEventJoypadButton
		if (
			button.is_action_pressed("ui_up")
			or button.is_action_pressed("ui_down")
			or button.is_action_pressed("ui_left")
			or button.is_action_pressed("ui_right")
		):
			return true
	return false
