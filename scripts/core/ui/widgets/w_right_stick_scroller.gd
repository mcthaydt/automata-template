## Right-stick analog scrolling for ScrollContainer nodes.
## Attaches to a Control and polls JOY_AXIS_RIGHT_X / JOY_AXIS_RIGHT_Y.
## Auto-disable when the target ScrollContainer is freed.

extends Node
class_name W_RightStickScroller

var _scroll_target: ScrollContainer = null
var _speed: float = 800.0
var _deadzone: float = 0.3

func bind_scroll_container(scroll: ScrollContainer, speed: float = 800.0, deadzone: float = 0.3) -> void:
	_scroll_target = scroll
	_speed = speed
	_deadzone = deadzone
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _scroll_target == null or not is_instance_valid(_scroll_target):
		process_mode = Node.PROCESS_MODE_INHERIT
		return

	var axis_x: float = 0.0
	var axis_y: float = 0.0
	var found_device: bool = false

	for device in Input.get_connected_joypads():
		axis_x = Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
		axis_y = Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		if absf(axis_x) > _deadzone or absf(axis_y) > _deadzone:
			found_device = true
			break

	if not found_device:
		return

	var new_h: float = float(_scroll_target.scroll_horizontal) + axis_x * _speed * delta
	var new_v: float = float(_scroll_target.scroll_vertical) + axis_y * _speed * delta
	_scroll_target.scroll_horizontal = int(new_h)
	_scroll_target.scroll_vertical = int(new_v)
