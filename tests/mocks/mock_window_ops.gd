extends I_WindowOps
class_name MockWindowOps

## Functional mock for window operations.
##
## Records method calls and maintains an internal window state for assertions.

var os_name: String = "test"
var backend_name: String = "mock"
var screen_size: Vector2i = Vector2i(1920, 1080)
var usable_rect: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(1920, 1080))
var current_screen: int = 0

var window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
var borderless: bool = false
var window_size: Vector2i = Vector2i(1920, 1080)
var window_position: Vector2i = Vector2i.ZERO
var vsync_mode: int = DisplayServer.VSYNC_ENABLED

var calls: Array[Dictionary] = []

func is_real_window_backend() -> bool:
	return false

func is_available() -> bool:
	return true

func get_backend_name() -> String:
	return backend_name

func get_os_name() -> String:
	return os_name

func get_call_count(method: String) -> int:
	var count := 0
	for call in calls:
		if String(call.get("method", "")) == method:
			count += 1
	return count

func window_get_mode() -> int:
	calls.append({"method": "window_get_mode"})
	return window_mode

func window_set_mode(mode: int) -> void:
	calls.append({"method": "window_set_mode", "mode": mode})
	window_mode = mode

func window_get_flag(flag: int) -> bool:
	calls.append({"method": "window_get_flag", "flag": flag})
	if flag == DisplayServer.WINDOW_FLAG_BORDERLESS:
		return borderless
	return false

func window_set_flag(flag: int, enabled: bool) -> void:
	calls.append({"method": "window_set_flag", "flag": flag, "enabled": enabled})
	if flag == DisplayServer.WINDOW_FLAG_BORDERLESS:
		borderless = enabled

func window_get_size() -> Vector2i:
	calls.append({"method": "window_get_size"})
	return window_size

func window_set_size(size: Vector2i) -> void:
	calls.append({"method": "window_set_size", "size": size})
	window_size = size

func window_set_position(position: Vector2i) -> void:
	calls.append({"method": "window_set_position", "position": position})
	window_position = position

func screen_get_size(_screen: int = -1) -> Vector2i:
	calls.append({"method": "screen_get_size"})
	return screen_size

var orientation: int = 0

func screen_set_orientation(orientation_value: int) -> void:
	calls.append({"method": "screen_set_orientation", "orientation": orientation_value})
	orientation = orientation_value

func window_get_vsync_mode() -> int:
	calls.append({"method": "window_get_vsync_mode"})
	return vsync_mode

func window_set_vsync_mode(mode: int) -> void:
	calls.append({"method": "window_set_vsync_mode", "mode": mode})
	vsync_mode = mode

func window_get_current_screen() -> int:
	calls.append({"method": "window_get_current_screen"})
	return current_screen

func screen_get_usable_rect(_screen: int) -> Rect2i:
	calls.append({"method": "screen_get_usable_rect"})
	return usable_rect

