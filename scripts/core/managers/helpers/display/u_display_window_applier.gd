extends RefCounted
class_name U_DisplayWindowApplier

## Applies window mode/size/vsync settings with platform guards.

## Value matches DisplayServer.SCREEN_SENSOR (Godot 4.7+).
## Allows all four orientations (landscape, reverse-landscape, portrait, reverse-portrait).
## Defined as a compat constant because the headless test runner (Godot 4.6)
## does not expose ScreenOrientation enum values in its DisplayServer class.
const SCREEN_ORIENTATION_SENSOR: int = 6

const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/core/utils/display/u_display_option_catalog.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/core/state/selectors/u_display_selectors.gd")
const U_DISPLAY_SERVER_WINDOW_OPS := preload("res://scripts/core/utils/display/u_display_server_window_ops.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/core/utils/display/u_mobile_platform_detector.gd")

var _owner: Node = null
var _window_ops: I_WindowOps = null
var _window_mode_retry_frame: int = -1
var _last_window_size_preset: String = ""

func initialize(owner: Node) -> void:
	_owner = owner

func set_window_ops(ops: I_WindowOps) -> void:
	_window_ops = ops

func apply_settings(display_settings: Dictionary) -> void:
	var state := {"display": display_settings}
	var window_preset := U_DISPLAY_SELECTORS.get_window_size_preset(state)
	var window_mode := U_DISPLAY_SELECTORS.get_window_mode(state)
	var vsync_enabled := U_DISPLAY_SELECTORS.is_vsync_enabled(state)
	var is_mobile := U_MOBILE_PLATFORM_DETECTOR.is_mobile()

	if is_mobile:
		window_mode = U_DISPLAY_SELECTORS.get_mobile_window_mode(state)
		U_MOBILE_PLATFORM_DETECTOR.set_scale_override(
			U_DISPLAY_SELECTORS.get_mobile_resolution_scale(state)
		)
		_set_orientation(SCREEN_ORIENTATION_SENSOR)
	else:
		U_MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)

	_last_window_size_preset = window_preset
	set_window_mode(window_mode)
	if window_mode == "windowed" and not is_mobile:
		apply_window_size_preset(window_preset)
	set_vsync_enabled(vsync_enabled)

func apply_window_size_preset(preset: String) -> void:
	var preset_resource: Resource = U_DISPLAY_OPTION_CATALOG.get_window_size_preset_by_id(preset)
	if preset_resource == null:
		return
	_last_window_size_preset = preset
	if not is_display_server_available():
		return
	if _should_defer():
		call_deferred("_apply_window_size_preset_now", preset)
	else:
		_apply_window_size_preset_now(preset)

func set_window_mode(mode: String) -> void:
	if not is_display_server_available():
		return
	if _should_defer():
		call_deferred("_set_window_mode_now", mode)
	else:
		_set_window_mode_now(mode)

func set_vsync_enabled(enabled: bool) -> void:
	if not is_display_server_available():
		return
	if _should_defer():
		call_deferred("_set_vsync_enabled_now", enabled)
	else:
		_set_vsync_enabled_now(enabled)

func is_display_server_available() -> bool:
	var ops := _get_window_ops()
	if ops == null or not ops.is_available():
		return false

	if ops.is_real_window_backend() and Engine.is_editor_hint():
		# Window operations mutate the host window. In editor/GUT-in-editor runs this
		# targets the editor window and can crash on macOS.
		return false
	if ops.is_real_window_backend() and ops.get_os_name() == "macOS" and _is_gut_running():
		# GUT runs inside the editor binary; window style changes during tests can
		# crash macOS (NSWindow styleMask exceptions).
		return false

	return true

func _apply_window_size_preset_now(preset: String) -> void:
	var preset_resource: Resource = U_DISPLAY_OPTION_CATALOG.get_window_size_preset_by_id(preset)
	if preset_resource == null:
		return
	var size: Vector2i = Vector2i(0, 0)
	var size_value: Variant = preset_resource.get("size")
	if size_value is Vector2i:
		size = size_value
	if size == Vector2i.ZERO:
		return
	var ops := _get_window_ops()
	if ops == null:
		return
	ops.window_set_size(size)

	# Use usable rect instead of full screen to avoid positioning behind taskbar/dock
	var current_screen := ops.window_get_current_screen()
	var usable_rect := ops.screen_get_usable_rect(current_screen)
	var window_pos := usable_rect.position + Vector2i((usable_rect.size - size) / 2.0)
	ops.window_set_position(window_pos)

func _set_window_mode_now(mode: String, attempt: int = 0) -> void:
	# macOS can abort if we attempt to change window style masks (borderless) while
	# fullscreen or while a fullscreen transition is still in progress.
	#
	# To avoid this, we:
	# - never toggle WINDOW_FLAG_BORDERLESS while already fullscreen
	# - when leaving fullscreen, we exit fullscreen first, then retry on a later frame
	#   before toggling style flags.
	if attempt > 8:
		push_warning("U_DisplayWindowApplier: Window mode '%s' did not settle after retries" % mode)
		return

	var ops := _get_window_ops()
	if ops == null:
		return
	var current_mode := ops.window_get_mode()
	var is_fullscreen := current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	var is_macos := ops.get_os_name() == "macOS"
	var is_borderless := ops.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)

	match mode:
		"fullscreen":
			# Enter fullscreen without touching style masks; macOS can crash on styleMask changes.
			if is_fullscreen:
				return
			ops.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			# Exit fullscreen first, then apply style flags on a later frame.
			if is_fullscreen:
				ops.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				call_deferred("_set_window_mode_now", mode, attempt + 1)
				return
			# Even after leaving fullscreen, macOS can still be mid-transition.
			# Give it an extra frame before touching the style mask.
			if is_macos and attempt == 1:
				_schedule_window_mode_retry_next_frame(mode, attempt + 1)
				return

			ops.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Avoid redundant style-mask changes; these can crash on macOS in some states.
			if not is_borderless:
				ops.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size := ops.screen_get_size()
			ops.window_set_size(screen_size)
			ops.window_set_position(Vector2i.ZERO)
		"windowed":
			# Exit fullscreen first, then apply style flags on a later frame.
			if is_fullscreen:
				ops.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				call_deferred("_set_window_mode_now", mode, attempt + 1)
				return
			# Even after leaving fullscreen, macOS can still be mid-transition.
			# Give it an extra frame before touching the style mask.
			if is_macos and attempt == 1:
				_schedule_window_mode_retry_next_frame(mode, attempt + 1)
				return

			ops.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Avoid redundant style-mask changes; these can crash on macOS in some states.
			if is_borderless:
				ops.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			if is_borderless or attempt > 0:
				_reapply_windowed_size()
		_:
			push_warning("U_DisplayWindowApplier: Invalid window mode '%s'" % mode)

func _schedule_window_mode_retry_next_frame(mode: String, attempt: int) -> void:
	_window_mode_retry_frame = Engine.get_process_frames()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var timer := (main_loop as SceneTree).create_timer(0.0)
		timer.timeout.connect(_on_window_mode_retry.bind(mode, attempt))
		return
	call_deferred("_set_window_mode_now", mode, attempt)

func _on_window_mode_retry(mode: String, attempt: int) -> void:
	if Engine.get_process_frames() <= _window_mode_retry_frame:
		_schedule_window_mode_retry_next_frame(mode, attempt)
		return
	_set_window_mode_now(mode, attempt)

func _set_vsync_enabled_now(enabled: bool) -> void:
	var ops := _get_window_ops()
	if ops == null:
		return
	if enabled:
		ops.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		ops.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _is_gut_running() -> bool:
	var tree := U_DisplayApplierUtils.get_tree_safe(_owner)
	if tree == null or tree.root == null:
		return false
	return tree.root.find_child("GutRunner", true, false) != null

func _reapply_windowed_size() -> void:
	if _last_window_size_preset == "":
		return
	if _should_defer():
		call_deferred("_apply_window_size_preset_now", _last_window_size_preset)
	else:
		_apply_window_size_preset_now(_last_window_size_preset)

func _get_window_ops() -> I_WindowOps:
	if _window_ops != null:
		return _window_ops
	_window_ops = U_DISPLAY_SERVER_WINDOW_OPS.new()
	return _window_ops

func _set_orientation(orientation: int) -> void:
	var ops := _get_window_ops()
	if ops != null:
		ops.screen_set_orientation(orientation)

func _should_defer() -> bool:
	return _owner != null and _owner.is_inside_tree()
