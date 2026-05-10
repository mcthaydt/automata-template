extends RefCounted
class_name U_InputProfileBuilder

var _profile: RS_InputProfile

func _init() -> void:
	_profile = RS_InputProfile.new()

func named(value: String) -> U_InputProfileBuilder:
	_profile.profile_name = value
	return self

func with_device_type(value: int) -> U_InputProfileBuilder:
	_profile.device_type = value
	return self

func with_description(value: String) -> U_InputProfileBuilder:
	_profile.description = value
	return self

func with_system_profile(value: bool) -> U_InputProfileBuilder:
	_profile.is_system_profile = value
	return self

func bind_key(action: StringName, physical_keycode: Key = KEY_NONE, keycode: Key = KEY_NONE, shift: bool = false, ctrl: bool = false, alt: bool = false) -> U_InputProfileBuilder:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode

	if keycode != KEY_NONE:
		event.keycode = keycode
	elif physical_keycode != KEY_NONE:
		event.keycode = physical_keycode

	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.alt_pressed = alt

	var existing: Array = _profile.action_mappings.get(action, [])
	existing.append(event)
	_profile.action_mappings[action] = existing
	return self

func bind_joypad_button(action: StringName, button_index: JoyButton) -> U_InputProfileBuilder:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	var existing: Array = _profile.action_mappings.get(action, [])
	existing.append(event)
	_profile.action_mappings[action] = existing
	return self

func bind_joypad_motion(action: StringName, axis: JoyAxis, axis_value: float) -> U_InputProfileBuilder:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	var existing: Array = _profile.action_mappings.get(action, [])
	existing.append(event)
	_profile.action_mappings[action] = existing
	return self

func with_virtual_joystick_position(pos: Vector2) -> U_InputProfileBuilder:
	_profile.virtual_joystick_position = pos
	return self

func with_virtual_button(action: StringName, pos: Vector2) -> U_InputProfileBuilder:
	_profile.virtual_buttons.append({"action": StringName(action), "position": pos})
	return self

func with_accessibility(jump_buffer: float, sprint_toggle: bool, hold_duration: float) -> U_InputProfileBuilder:
	_profile.jump_buffer_time = jump_buffer
	_profile.sprint_toggle_mode = sprint_toggle
	_profile.interact_hold_duration = hold_duration
	return self

func build() -> RS_InputProfile:
	return _profile
