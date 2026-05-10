class_name I_WindowOps
extends RefCounted

## Minimal interface for window operations used by M_DisplayManager.
##
## Implementations:
## - U_DisplayServerWindowOps (production)
## - MockWindowOps (testing)

## True if this implementation manipulates the host OS window (e.g., DisplayServer).
func is_real_window_backend() -> bool:
	return false

## True if window operations are supported in the current runtime.
func is_available() -> bool:
	return true

## Name of the backing window system (for debugging).
func get_backend_name() -> String:
	return "unknown"

## OS name for platform-specific behavior (e.g., "macOS").
func get_os_name() -> String:
	return OS.get_name()

func window_get_mode() -> int:
	push_error("I_WindowOps.window_get_mode not implemented")
	return 0

func window_set_mode(_mode: int) -> void:
	push_error("I_WindowOps.window_set_mode not implemented")

func window_get_flag(_flag: int) -> bool:
	push_error("I_WindowOps.window_get_flag not implemented")
	return false

func window_set_flag(_flag: int, _enabled: bool) -> void:
	push_error("I_WindowOps.window_set_flag not implemented")

func window_get_size() -> Vector2i:
	push_error("I_WindowOps.window_get_size not implemented")
	return Vector2i.ZERO

func window_set_size(_size: Vector2i) -> void:
	push_error("I_WindowOps.window_set_size not implemented")

func window_set_position(_position: Vector2i) -> void:
	push_error("I_WindowOps.window_set_position not implemented")

func screen_get_size(_screen: int = -1) -> Vector2i:
	push_error("I_WindowOps.screen_get_size not implemented")
	return Vector2i.ZERO

func window_get_vsync_mode() -> int:
	push_error("I_WindowOps.window_get_vsync_mode not implemented")
	return 0

func window_set_vsync_mode(_mode: int) -> void:
	push_error("I_WindowOps.window_set_vsync_mode not implemented")

func window_get_current_screen() -> int:
	push_error("I_WindowOps.window_get_current_screen not implemented")
	return 0

func screen_get_usable_rect(_screen: int) -> Rect2i:
	push_error("I_WindowOps.screen_get_usable_rect not implemented")
	return Rect2i()

func screen_set_orientation(_orientation: int) -> void:
	push_error("I_WindowOps.screen_set_orientation not implemented")

