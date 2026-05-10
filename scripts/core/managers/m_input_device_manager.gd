@icon("res://assets/core/editor_icons/icn_manager.svg")
extends "res://scripts/core/interfaces/i_input_device_manager.gd"
class_name M_InputDeviceManager

const U_NAVIGATION_SELECTORS := preload("res://scripts/core/state/selectors/u_navigation_selectors.gd")


signal device_changed(device_type: int, device_id: int, timestamp: float)

# Use centralized DeviceType enum
const DeviceType := U_DeviceTypeConstants.DeviceType

var _active_device: int = DeviceType.KEYBOARD_MOUSE
var _active_gamepad_id: int = -1
var _last_gamepad_device_id: int = -1
var _gamepad_connected: bool = false
var _last_input_time: float = 0.0
var _state_store: I_StateStore = null
var _joy_connection_bound: bool = false
var _has_dispatched_initial_state: bool = false
var _pending_device_events: Array[Dictionary] = []
var _last_gamepad_signal_time: float = 0.0
var _mobile_controls: Node = null

# Input sources
var _keyboard_mouse_source: KeyboardMouseSource = null
var _gamepad_source: GamepadSource = null
var _touchscreen_source: TouchscreenSource = null
var _input_sources: Array[I_InputSource] = []

@export var emulate_mobile_disconnect_guard: bool = false
@export var emulate_mobile_pointer_guard: bool = false

const DEVICE_SWITCH_DEADZONE := 0.25
const DISCONNECT_GRACE_SECONDS := 1.0
const SETTINGS_PANEL_SCREEN_ID := StringName("settings_panel")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_register_input_sources()
	_register_existing_gamepads()
	_connect_joypad_signals()
	await _bind_state_store()

func _register_input_sources() -> void:
	# Create input sources
	_keyboard_mouse_source = KeyboardMouseSource.new()
	_gamepad_source = GamepadSource.new()
	_touchscreen_source = TouchscreenSource.new()

	# Register sources in priority order (highest priority first)
	_input_sources = [
		_touchscreen_source,  # Priority 3
		_gamepad_source,      # Priority 2
		_keyboard_mouse_source, # Priority 1
	]

func _exit_tree() -> void:
	_disconnect_joypad_signals()
	_state_store = null
	_mobile_controls = null

func register_mobile_controls(controls: Node) -> void:
	if controls == null:
		return
	_mobile_controls = controls

func unregister_mobile_controls(controls: Node = null) -> void:
	if controls == null or controls == _mobile_controls:
		_mobile_controls = null

func get_mobile_controls() -> Node:
	if _mobile_controls != null and is_instance_valid(_mobile_controls):
		return _mobile_controls
	_mobile_controls = null
	return null

func _input(event: InputEvent) -> void:
	if event == null:
		return
	if event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		if not joy_button.pressed:
			return
		# Delegate to gamepad source
		if _gamepad_source:
			_gamepad_source.handle_button_event(joy_button.button_index, joy_button.pressed)
		_handle_gamepad_input(joy_button.device)
	elif event is InputEventJoypadMotion:
		var joy_motion := event as InputEventJoypadMotion
		if joy_motion.device >= 0:
			_gamepad_connected = true
			_last_gamepad_device_id = joy_motion.device
		# Delegate to gamepad source
		if _gamepad_source:
			_gamepad_source.handle_motion_event(joy_motion.axis, joy_motion.axis_value)
		if abs(joy_motion.axis_value) < DEVICE_SWITCH_DEADZONE:
			return
		_handle_gamepad_input(joy_motion.device)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.echo:
			return
		_handle_keyboard_mouse_input(key_event)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed:
			return
		# CRITICAL FIX: Ignore mouse events emulated from touch on mobile
		# Godot automatically converts touch to mouse for compatibility, but we handle
		# touch separately. This prevents device type from flickering 2→0→2 on touch.
		if _is_mobile_context():
			return
		_handle_keyboard_mouse_input(mouse_button)
	elif event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if mouse_motion.relative.length_squared() <= 0.0:
			return
		# CRITICAL FIX: Ignore mouse motion emulated from touch on mobile
		if _is_mobile_context():
			return
		# Delegate to keyboard/mouse source
		if _keyboard_mouse_source:
			_keyboard_mouse_source.set_mouse_delta(mouse_motion.relative)
		_handle_keyboard_mouse_input(mouse_motion)
	elif event is InputEventScreenTouch:
		var screen_touch := event as InputEventScreenTouch
		if not screen_touch.pressed:
			return
		# Delegate to touchscreen source
		if _touchscreen_source:
			_touchscreen_source.handle_touch_event()
		_handle_touch_input()
	elif event is InputEventScreenDrag:
		# Delegate to touchscreen source
		if _touchscreen_source:
			_touchscreen_source.handle_touch_event()
		_handle_touch_input()

func get_active_device() -> int:
	return _active_device

func get_gamepad_device_id() -> int:
	return _active_gamepad_id

func get_last_gamepad_device_id() -> int:
	return _last_gamepad_device_id

func is_gamepad_connected() -> bool:
	return _gamepad_connected

func _handle_gamepad_input(device_id: int) -> void:
	if device_id >= 0:
		_gamepad_connected = true
		_last_gamepad_device_id = device_id
		_last_gamepad_signal_time = U_ECSUtils.get_current_time()
	_switch_device(DeviceType.GAMEPAD, device_id)

func _handle_keyboard_mouse_input(_event: InputEvent = null) -> void:
	_switch_device(DeviceType.KEYBOARD_MOUSE, -1)

func _handle_touch_input() -> void:
	if _has_overlay_active() or _is_settings_panel_active():
		return
	_switch_device(DeviceType.TOUCHSCREEN, -1)

func _switch_device(device_type: int, device_id: int) -> void:
	var normalized_device_id := device_id
	if device_type == DeviceType.GAMEPAD:
		if normalized_device_id < 0:
			normalized_device_id = _last_gamepad_device_id
		if normalized_device_id < 0:
			return
	var has_device_changed := true
	if _active_device == device_type:
		if not _has_dispatched_initial_state:
			has_device_changed = true
		elif device_type == DeviceType.GAMEPAD and normalized_device_id != _active_gamepad_id and normalized_device_id >= 0:
			has_device_changed = true
		else:
			has_device_changed = false
	var switch_timestamp := U_ECSUtils.get_current_time()
	_last_input_time = switch_timestamp

	if not has_device_changed:
		return

	_active_device = device_type
	if device_type == DeviceType.GAMEPAD:
		_active_gamepad_id = normalized_device_id
	else:
		_active_gamepad_id = -1

	var device_id_for_emit: int = -1
	if device_type == DeviceType.GAMEPAD:
		device_id_for_emit = _active_gamepad_id

	_dispatch_device_changed(device_type, device_id_for_emit, switch_timestamp)

func _dispatch_device_changed(device_type: int, device_id: int, timestamp: float) -> void:
	var event_payload := {
		"device_type": device_type,
		"device_id": device_id,
		"timestamp": timestamp,
	}
	if _state_store == null or not is_instance_valid(_state_store):
		_pending_device_events.append(event_payload)
		return
	_process_device_event(event_payload)

func _process_device_event(event_payload: Dictionary) -> void:
	if _state_store != null and is_instance_valid(_state_store):
		_state_store.dispatch(
			U_InputActions.device_changed(
				int(event_payload.get("device_type", DeviceType.KEYBOARD_MOUSE)),
				int(event_payload.get("device_id", -1)),
				float(event_payload.get("timestamp", 0.0))
			)
		)
	device_changed.emit(
		int(event_payload.get("device_type", DeviceType.KEYBOARD_MOUSE)),
		int(event_payload.get("device_id", -1)),
		float(event_payload.get("timestamp", 0.0))
	)
	_has_dispatched_initial_state = true

func _register_existing_gamepads() -> void:
	var connected := Input.get_connected_joypads()
	if connected.is_empty():
		return
	_gamepad_connected = true
	_last_gamepad_device_id = int(connected[0])
	# Initialize gamepad source with first connected device
	if _gamepad_source:
		_gamepad_source.set_device_id(_last_gamepad_device_id)
		_gamepad_source.set_connected(true)

func get_active_input_source() -> I_InputSource:
	# Return the highest priority active source
	for source in _input_sources:
		if source and source.is_active():
			return source
	# Default to keyboard/mouse if no source is active
	return _keyboard_mouse_source

func get_input_source_for_device(device_type: int) -> I_InputSource:
	match device_type:
		DeviceType.KEYBOARD_MOUSE:
			return _keyboard_mouse_source
		DeviceType.GAMEPAD:
			return _gamepad_source
		DeviceType.TOUCHSCREEN:
			return _touchscreen_source
		_:
			return _keyboard_mouse_source

func _connect_joypad_signals() -> void:
	if _joy_connection_bound:
		return
	var callable := Callable(self, "_on_joy_connection_changed")
	Input.joy_connection_changed.connect(callable)
	_joy_connection_bound = true

func _disconnect_joypad_signals() -> void:
	if not _joy_connection_bound:
		return
	var callable := Callable(self, "_on_joy_connection_changed")
	if Input.joy_connection_changed.is_connected(callable):
		Input.joy_connection_changed.disconnect(callable)
	_joy_connection_bound = false

func _bind_state_store() -> void:
	if _state_store != null and is_instance_valid(_state_store):
		_flush_pending_device_events()
		return
	var store := await U_StateUtils.await_store_ready(self)
	if store == null:
		push_error("M_InputDeviceManager: Timed out waiting for M_StateStore readiness")
		return
	_state_store = store
	_flush_pending_device_events()

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		_gamepad_connected = true
		_last_gamepad_device_id = device_id
		_last_gamepad_signal_time = U_ECSUtils.get_current_time()
		# Update gamepad source
		if _gamepad_source:
			_gamepad_source.set_device_id(device_id)
			_gamepad_source.set_connected(true)
		_dispatch_connection_state(true, device_id)
	else:
		if device_id == _last_gamepad_device_id:
			_last_gamepad_device_id = -1
		var should_switch := device_id == _active_gamepad_id
		if should_switch and _should_ignore_gamepad_disconnect():
			should_switch = false
		elif should_switch and _should_guard_disconnect_by_grace_period():
			should_switch = false
		if should_switch and device_id == _active_gamepad_id:
			_switch_device(DeviceType.KEYBOARD_MOUSE, -1)
		_gamepad_connected = _evaluate_gamepad_connections()
		# Update gamepad source
		if _gamepad_source and not _gamepad_connected:
			_gamepad_source.set_connected(false)
		_dispatch_connection_state(false, device_id)

func _evaluate_gamepad_connections() -> bool:
	var connected := Input.get_connected_joypads()
	return not connected.is_empty()

func get_last_input_time() -> float:
	return _last_input_time

func get_time_since_last_input() -> float:
	if _last_input_time <= 0.0:
		return -1.0
	var current_time := U_ECSUtils.get_current_time()
	return max(current_time - _last_input_time, 0.0)

func _dispatch_connection_state(connected: bool, device_id: int) -> void:
	if _state_store == null or not is_instance_valid(_state_store):
		return
	if connected:
		_state_store.dispatch(U_InputActions.gamepad_connected(device_id))
	else:
		_state_store.dispatch(U_InputActions.gamepad_disconnected(device_id))

func _flush_pending_device_events() -> void:
	if _pending_device_events.is_empty():
		return
	for event_payload in _pending_device_events:
		_process_device_event(event_payload)
	_pending_device_events.clear()

func _should_ignore_gamepad_disconnect() -> bool:
	if _active_device != DeviceType.GAMEPAD:
		return false
	if get_tree().paused:
		return true
	return _has_overlay_active()

func _has_overlay_active() -> bool:
	if _state_store == null or not is_instance_valid(_state_store):
		return false
	var state: Dictionary = _state_store.get_state()
	return not U_NAVIGATION_SELECTORS.get_overlay_stack(state).is_empty()

func _is_settings_panel_active() -> bool:
	if _state_store == null or not is_instance_valid(_state_store):
		return false
	var state: Dictionary = _state_store.get_state()
	if U_NAVIGATION_SELECTORS.get_top_overlay_id(state) == SETTINGS_PANEL_SCREEN_ID:
		return true
	if U_NAVIGATION_SELECTORS.get_overlay_stack(state).has(SETTINGS_PANEL_SCREEN_ID):
		return true
	return U_NAVIGATION_SELECTORS.get_base_scene_id(state) == SETTINGS_PANEL_SCREEN_ID

func _should_guard_disconnect_by_grace_period() -> bool:
	if not _is_mobile_context():
		return false
	if _active_device != DeviceType.GAMEPAD:
		return false
	var now := U_ECSUtils.get_current_time()
	if _last_gamepad_signal_time <= 0.0:
		return false
	return (now - _last_gamepad_signal_time) <= DISCONNECT_GRACE_SECONDS

func _is_mobile_context() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		return true
	return emulate_mobile_disconnect_guard or emulate_mobile_pointer_guard
