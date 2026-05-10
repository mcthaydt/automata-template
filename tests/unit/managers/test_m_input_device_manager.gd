extends GutTest


var _store: M_StateStore
var _manager: M_InputDeviceManager
var _dispatched_actions: Array[Dictionary] = []
var _device_events: Array[Dictionary] = []

func before_each() -> void:
	U_StateHandoff.clear_all()
	_dispatched_actions.clear()
	_device_events.clear()

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.settings.enable_history = false
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	_store.navigation_initial_state = RS_NavigationInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_InputDeviceManager.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	_store.action_dispatched.connect(_on_action_dispatched)
	_manager.device_changed.connect(_on_device_changed)

func after_each() -> void:
	U_StateHandoff.clear_all()
	_dispatched_actions.clear()
	_device_events.clear()
	_store = null
	_manager = null

func _on_action_dispatched(action: Dictionary) -> void:
	_dispatched_actions.append(action.duplicate(true))

func _on_device_changed(device_type: int, device_id: int, timestamp: float) -> void:
	_device_events.append({
		"device_type": device_type,
		"device_id": device_id,
		"timestamp": timestamp,
	})

func test_manager_defaults_to_keyboard() -> void:
	var connected: Array = Input.get_connected_joypads()
	var expected_connected: bool = not connected.is_empty()
	assert_eq(_manager.get_active_device(), M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE, "Default device should be keyboard/mouse")
	assert_eq(_manager.get_gamepad_device_id(), -1, "No active gamepad on startup")
	assert_eq(
		_manager.is_gamepad_connected(),
		expected_connected,
		"Gamepad connection flag should mirror actual hardware state"
	)
	if expected_connected:
		assert_eq(
			_manager.get_last_gamepad_device_id(),
			int(connected[connected.size() - 1]),
			"Manager should remember the most recently reported gamepad id"
		)
	else:
		assert_eq(
			_manager.get_last_gamepad_device_id(),
			-1,
			"Manager should have no cached gamepad id when none are connected"
		)
	assert_eq(_manager.process_mode, Node.PROCESS_MODE_ALWAYS, "Manager should process even when tree paused")

func test_initial_keyboard_input_emits_device_changed_event() -> void:
	var key_event: InputEventKey = InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_W
	_manager._input(key_event)
	await get_tree().process_frame

	assert_eq(_device_events.size(), 1, "Initial keyboard input should emit device_changed once")
	var event := _device_events[0]
	assert_eq(event.get("device_type"), M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE)
	assert_eq(event.get("device_id"), -1)
	assert_gt(float(event.get("timestamp", 0.0)), 0.0)

	assert_eq(_dispatched_actions.size(), 1, "Initial keyboard input should dispatch to state store")
	var action: Dictionary = _dispatched_actions[0]
	assert_eq(action.get("type"), U_InputActions.ACTION_DEVICE_CHANGED)
	var payload: Dictionary = action.get("payload", {})
	assert_eq(int(payload.get("device_type", 99)), M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE)
	assert_eq(int(payload.get("device_id", 99)), -1)
	assert_gt(float(payload.get("timestamp", 0.0)), 0.0)

func test_gamepad_event_switches_to_gamepad_and_dispatches_action() -> void:
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.device = 7
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.5
	_manager._input(motion)
	await get_tree().process_frame

	assert_eq(_manager.get_active_device(), M_InputDeviceManager.DeviceType.GAMEPAD)
	assert_eq(_manager.get_gamepad_device_id(), 7)
	assert_true(_manager.is_gamepad_connected(), "Gamepad connection flag should be true after input")

	assert_eq(_device_events.size(), 1, "device_changed should emit once for gamepad switch")
	var event: Dictionary = _device_events[0]
	assert_eq(event.get("device_type"), M_InputDeviceManager.DeviceType.GAMEPAD)
	assert_eq(event.get("device_id"), 7)
	assert_gt(float(event.get("timestamp", 0.0)), 0.0)

	assert_eq(_dispatched_actions.size(), 1, "Store should receive device_changed action")
	var action: Dictionary = _dispatched_actions[0]
	assert_eq(action.get("type"), U_InputActions.ACTION_DEVICE_CHANGED)
	var payload: Dictionary = action.get("payload", {})
	assert_eq(int(payload.get("device_type", -1)), M_InputDeviceManager.DeviceType.GAMEPAD)
	assert_eq(int(payload.get("device_id", -1)), 7)
	var action_timestamp := float(payload.get("timestamp", 0.0))
	assert_gt(action_timestamp, 0.0)
	assert_almost_eq(action_timestamp, float(event.get("timestamp", -1.0)), 0.0001, "Signal timestamp should match dispatched action timestamp")

func test_dispatch_precedes_device_changed_signal() -> void:
	var call_order: Array[String] = []
	var dispatch_callable := func(_action: Dictionary) -> void:
		call_order.append("dispatch")
	var signal_callable := func(_device_type: int, _device_id: int, _timestamp: float) -> void:
		call_order.append("signal")

	_store.action_dispatched.connect(dispatch_callable)
	_manager.device_changed.connect(signal_callable)

	var key_event: InputEventKey = InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_E
	_manager._input(key_event)
	await get_tree().process_frame

	_store.action_dispatched.disconnect(dispatch_callable)
	_manager.device_changed.disconnect(signal_callable)

	assert_eq(call_order.size(), 2, "Should record dispatch and signal order")
	assert_eq(call_order[0], "dispatch", "Redux dispatch must occur before device_changed signal")
	assert_eq(call_order[1], "signal", "device_changed should fire after dispatch completes")

func test_store_state_visible_within_device_changed_signal() -> void:
	var observed: Array[Dictionary] = []
	var capture_callable := func(_device_type: int, _device_id: int, _timestamp: float) -> void:
		var state: Dictionary = _store.get_state()
		var gameplay_slice: Dictionary = state.get("gameplay", {}) as Dictionary
		var input_slice: Dictionary = gameplay_slice.get("input", {}) as Dictionary
		observed.append({
			"active_device": input_slice.get("active_device", -99),
			"gamepad_device_id": input_slice.get("gamepad_device_id", -99),
		})

	_manager.device_changed.connect(capture_callable)

	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.device = 4
	motion.axis = JOY_AXIS_LEFT_Y
	motion.axis_value = 0.9
	_manager._input(motion)
	await get_tree().process_frame

	_manager.device_changed.disconnect(capture_callable)

	assert_eq(observed.size(), 1, "Signal listener should capture single state snapshot")
	var snapshot: Dictionary = observed[0]
	assert_eq(int(snapshot.get("active_device", -1)), M_InputDeviceManager.DeviceType.GAMEPAD, "Store state should already reflect active device inside signal handler")
	assert_eq(int(snapshot.get("gamepad_device_id", -1)), 4, "Store state should expose new active gamepad ID inside signal handler")

func test_keyboard_event_after_gamepad_switches_back_to_keyboard() -> void:
	await _simulate_gamepad_input(4)
	_dispatched_actions.clear()
	_device_events.clear()

	var key_event: InputEventKey = InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_SPACE
	_manager._input(key_event)
	await get_tree().process_frame

	assert_eq(_manager.get_active_device(), M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE)
	assert_eq(_manager.get_gamepad_device_id(), -1, "Keyboard switch should clear active gamepad id")
	assert_true(_manager.is_gamepad_connected(), "Gamepad remains connected even when keyboard becomes active")

	assert_eq(_device_events.size(), 1, "device_changed should emit once for keyboard switch")
	var event: Dictionary = _device_events[0]
	assert_eq(event.get("device_type"), M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE)
	assert_eq(event.get("device_id"), -1)
	assert_gt(float(event.get("timestamp", 0.0)), 0.0)

	assert_eq(_dispatched_actions.size(), 1, "Store should receive device_changed action for keyboard switch")
	var action: Dictionary = _dispatched_actions[0]
	assert_eq(action.get("type"), U_InputActions.ACTION_DEVICE_CHANGED)
	var payload: Dictionary = action.get("payload", {})
	assert_eq(int(payload.get("device_type", 99)), M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE)
	assert_eq(int(payload.get("device_id", 99)), -1)
	assert_gt(float(payload.get("timestamp", 0.0)), 0.0)

func test_touch_event_switches_to_touchscreen_without_gamepad_state() -> void:
	var was_connected: bool = _manager.is_gamepad_connected()
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2.ONE
	_manager._input(touch)
	await get_tree().process_frame

	assert_eq(_manager.get_active_device(), M_InputDeviceManager.DeviceType.TOUCHSCREEN)
	assert_eq(_manager.get_gamepad_device_id(), -1, "Touchscreen input should not set gamepad id")
	if was_connected:
		assert_true(
			_manager.is_gamepad_connected(),
			"Touchscreen input should not disconnect an already connected gamepad"
		)
	else:
		assert_false(
			_manager.is_gamepad_connected(),
			"Touchscreen input should not mark a gamepad connected when none were present"
		)

	assert_eq(_device_events.size(), 1)
	var event: Dictionary = _device_events[0]
	assert_eq(event.get("device_type"), M_InputDeviceManager.DeviceType.TOUCHSCREEN)
	assert_eq(event.get("device_id"), -1)
	assert_gt(float(event.get("timestamp", 0.0)), 0.0)

func test_mobile_emulated_mouse_button_does_not_switch_from_touchscreen() -> void:
	_manager.emulate_mobile_pointer_guard = true
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2.ONE
	_manager._input(touch)
	await get_tree().process_frame
	_dispatched_actions.clear()
	_device_events.clear()

	var mouse_button := InputEventMouseButton.new()
	mouse_button.pressed = true
	mouse_button.button_index = MOUSE_BUTTON_LEFT
	mouse_button.position = Vector2(24.0, 32.0)
	_manager._input(mouse_button)
	await get_tree().process_frame

	assert_eq(
		_manager.get_active_device(),
		M_InputDeviceManager.DeviceType.TOUCHSCREEN,
		"Mobile/web emulated mouse buttons should not switch active device away from touchscreen"
	)
	assert_eq(_device_events.size(), 0, "Ignored emulated mouse button should not emit device_changed")
	assert_eq(_dispatched_actions.size(), 0, "Ignored emulated mouse button should not dispatch device changes")

func test_mobile_emulated_mouse_motion_does_not_switch_from_touchscreen() -> void:
	_manager.emulate_mobile_pointer_guard = true
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2.ONE
	_manager._input(touch)
	await get_tree().process_frame
	_dispatched_actions.clear()
	_device_events.clear()

	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = Vector2(28.0, 36.0)
	mouse_motion.relative = Vector2(4.0, 0.0)
	_manager._input(mouse_motion)
	await get_tree().process_frame

	assert_eq(
		_manager.get_active_device(),
		M_InputDeviceManager.DeviceType.TOUCHSCREEN,
		"Mobile/web emulated mouse motion should not switch active device away from touchscreen"
	)
	assert_eq(_device_events.size(), 0, "Ignored emulated mouse motion should not emit device_changed")
	assert_eq(_dispatched_actions.size(), 0, "Ignored emulated mouse motion should not dispatch device changes")

func test_touch_event_does_not_switch_device_on_input_rebinding_overlay() -> void:
	await _simulate_gamepad_input(6)
	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	_store.dispatch(U_NavigationActions.open_pause())
	_store.dispatch(U_NavigationActions.open_overlay(StringName("settings_panel")))
	_store.dispatch(U_NavigationActions.open_overlay(StringName("input_rebinding")))
	await get_tree().process_frame
	_dispatched_actions.clear()
	_device_events.clear()

	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2.ONE
	_manager._input(touch)
	await get_tree().process_frame

	assert_eq(_manager.get_active_device(), M_InputDeviceManager.DeviceType.GAMEPAD)
	assert_eq(_manager.get_gamepad_device_id(), 6)
	assert_eq(_device_events.size(), 0, "Touch input should not emit device_changed on input rebinding overlay")
	assert_eq(_dispatched_actions.size(), 0, "Touch input should not dispatch device changes on input rebinding overlay")

func test_touch_event_does_not_switch_device_on_settings_panel_base_scene() -> void:
	await _simulate_gamepad_input(9)
	_store.dispatch(U_NavigationActions.return_to_main_menu())
	_store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_panel")))
	await get_tree().process_frame
	_dispatched_actions.clear()
	_device_events.clear()

	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2.ONE
	_manager._input(touch)
	await get_tree().process_frame

	assert_eq(_manager.get_active_device(), M_InputDeviceManager.DeviceType.GAMEPAD)
	assert_eq(_manager.get_gamepad_device_id(), 9)
	assert_eq(_device_events.size(), 0, "Touch input should not emit device_changed on settings panel base scene")
	assert_eq(_dispatched_actions.size(), 0, "Touch input should not dispatch device changes on gamepad settings base scene")

func test_gamepad_disconnect_ignored_when_overlay_active() -> void:
	await _simulate_gamepad_input(5)
	_dispatched_actions.clear()
	_device_events.clear()

	_store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	_store.dispatch(U_NavigationActions.open_pause())
	await get_tree().process_frame
	var dispatched_before: int = _dispatched_actions.size()

	_manager._on_joy_connection_changed(5, false)
	await get_tree().process_frame

	assert_eq(_manager.get_active_device(), M_InputDeviceManager.DeviceType.GAMEPAD, "Active device should remain gamepad when disconnect fires during overlay")
	assert_eq(_manager.get_gamepad_device_id(), 5, "Gamepad id should be preserved during ignored disconnect")
	assert_eq(_device_events.size(), 0, "Ignored disconnect should not emit device_changed")
	assert_eq(_dispatched_actions.size(), dispatched_before + 1, "Ignored disconnect should only dispatch connection state")
	var last_action: Dictionary = _dispatched_actions.back()
	assert_eq(last_action.get("type"), U_InputActions.ACTION_GAMEPAD_DISCONNECTED)

func test_gamepad_disconnect_ignored_with_grace_on_mobile() -> void:
	_manager.emulate_mobile_disconnect_guard = true
	await _simulate_gamepad_input(8)
	_dispatched_actions.clear()
	_device_events.clear()

	_manager._on_joy_connection_changed(8, false)
	await get_tree().process_frame

	assert_eq(_manager.get_active_device(), M_InputDeviceManager.DeviceType.GAMEPAD, "Grace period should keep active device as gamepad")
	assert_eq(_manager.get_gamepad_device_id(), 8)
	assert_eq(_device_events.size(), 0, "Grace-ignored disconnect should not emit device_changed")
	assert_eq(_dispatched_actions.size(), 1, "Grace-ignored disconnect should still dispatch connection state")
	var action: Dictionary = _dispatched_actions.back()
	assert_eq(action.get("type"), U_InputActions.ACTION_GAMEPAD_DISCONNECTED)

func test_redundant_device_events_do_not_reemit() -> void:
	await _simulate_gamepad_input(2)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_F
	_manager._input(key_event)
	await get_tree().process_frame

	var emitted_actions: int = _dispatched_actions.size()
	var emitted_events: int = _device_events.size()

	_manager._input(key_event)
	await get_tree().process_frame

	assert_eq(_dispatched_actions.size(), emitted_actions, "Duplicate keyboard event should not dispatch action again")
	assert_eq(_device_events.size(), emitted_events, "Duplicate keyboard event should not re-emit signal")

func test_duplicate_events_refresh_last_input_time() -> void:
	await _simulate_gamepad_input(6)
	_dispatched_actions.clear()
	_device_events.clear()

	var key_event: InputEventKey = InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_Q
	_manager._input(key_event)
	await get_tree().process_frame
	var first_time: float = _manager.get_last_input_time()

	await get_tree().process_frame
	var key_event_two: InputEventKey = InputEventKey.new()
	key_event_two.pressed = true
	key_event_two.physical_keycode = KEY_W
	_manager._input(key_event_two)
	await get_tree().process_frame

	assert_true(first_time > 0.0)
	assert_gt(_manager.get_last_input_time(), first_time)
	assert_eq(_device_events.size(), 1, "Duplicate keyboard events should not emit additional device_changed signals")
	assert_true(_manager.get_time_since_last_input() >= 0.0, "Time since last input should be non-negative")

func test_small_gamepad_motion_does_not_override_keyboard() -> void:
	var key_event: InputEventKey = InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_W
	_manager._input(key_event)
	await get_tree().process_frame

	_dispatched_actions.clear()
	_device_events.clear()

	var small_motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	small_motion.device = 11
	small_motion.axis = JOY_AXIS_LEFT_X
	small_motion.axis_value = 0.05
	_manager._input(small_motion)
	await get_tree().process_frame

	assert_eq(_manager.get_active_device(), M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE, "Tiny joystick drift should not switch active device")
	assert_eq(_device_events.size(), 0, "No device_changed signal expected for tiny drift")
	assert_eq(_dispatched_actions.size(), 0, "No state dispatch expected for tiny drift")

func _simulate_gamepad_input(device_id: int) -> void:
	_dispatched_actions.clear()
	_device_events.clear()
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.device = device_id
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.25
	_manager._input(motion)
	await get_tree().process_frame
