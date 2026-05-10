extends GutTest

const RS_InputProfile = preload("res://scripts/core/resources/input/rs_input_profile.gd")

const DefaultKeyboardProfile = preload("res://scripts/core/resources/input/profiles/default_keyboard_profile.gd")
const AlternateKeyboardProfile = preload("res://scripts/core/resources/input/profiles/alternate_keyboard_profile.gd")
const AccessibilityKeyboardProfile = preload("res://scripts/core/resources/input/profiles/accessibility_keyboard_profile.gd")
const DefaultGamepadProfile = preload("res://scripts/core/resources/input/profiles/default_gamepad_profile.gd")
const AccessibilityGamepadProfile = preload("res://scripts/core/resources/input/profiles/accessibility_gamepad_profile.gd")
const DefaultTouchscreenProfile = preload("res://scripts/core/resources/input/profiles/default_touchscreen_profile.gd")

func test_defaults_and_setters() -> void:
	var p := RS_InputProfile.new()
	assert_eq(p.profile_name, "Default", "Default profile name")
	assert_eq(p.device_type, 0, "Default device type is Keyboard/Mouse")
	assert_true(p.is_system_profile, "Default is system profile")

	var jump_event := InputEventKey.new()
	jump_event.physical_keycode = KEY_SPACE
	p.set_events_for_action(StringName("jump"), [jump_event])

	var events := p.get_events_for_action(StringName("jump"))
	assert_eq(events.size(), 1, "One jump binding present")
	assert_true(events[0] is InputEventKey, "Jump mapping is key event")

	# Ensure defensive copy (mutating returned array does not affect profile)
	events.clear()
	var events_after := p.get_events_for_action(StringName("jump"))
	assert_eq(events_after.size(), 1, "Internal events are not aliased")

func test_serialize_to_and_from_dictionary() -> void:
	var p := RS_InputProfile.new()
	p.profile_name = "Unit Test Profile"
	p.device_type = 0
	p.description = "Test profile for RS_InputProfile serialization"
	p.is_system_profile = false

	var move_left := InputEventKey.new()
	move_left.physical_keycode = KEY_A
	var move_right := InputEventKey.new()
	move_right.physical_keycode = KEY_D
	var mouse_button := InputEventMouseButton.new()
	mouse_button.button_index = MOUSE_BUTTON_LEFT

	p.set_events_for_action(StringName("move_left"), [move_left])
	p.set_events_for_action(StringName("move_right"), [move_right])
	p.set_events_for_action(StringName("interact"), [mouse_button])

	var data := p.to_dictionary()
	assert_has(data, "action_mappings", "Dictionary contains mappings")

	var p2 := RS_InputProfile.new()
	p2.from_dictionary(data)
	assert_eq(p2.profile_name, p.profile_name, "Profile name round-trip")
	assert_eq(p2.device_type, p.device_type, "Device type round-trip")
	assert_eq(p2.description, p.description, "Description round-trip")
	assert_eq(p2.is_system_profile, p.is_system_profile, "System flag round-trip")

	var ml := p2.get_events_for_action(StringName("move_left"))
	assert_eq(ml.size(), 1, "move_left restored")
	assert_true(ml[0] is InputEventKey, "move_left is key event")

	var intr := p2.get_events_for_action(StringName("interact"))
	assert_eq(intr.size(), 1, "interact restored")
	assert_true(intr[0] is InputEventMouseButton, "interact is mouse button")

func test_touchscreen_fields_serialize_roundtrip() -> void:
	var p := RS_InputProfile.new()
	p.profile_name = "Touchscreen Test Profile"
	p.device_type = 2  # Touchscreen

	# Set touchscreen fields
	p.virtual_joystick_position = Vector2(120, 450)
	p.virtual_buttons = [
		{"action": StringName("jump"), "position": Vector2(800, 450)},
		{"action": StringName("sprint"), "position": Vector2(800, 350)},
		{"action": StringName("interact"), "position": Vector2(700, 450)},
		{"action": StringName("pause"), "position": Vector2(700, 350)}
	]

	# Serialize to dictionary
	var data := p.to_dictionary()
	assert_has(data, "virtual_joystick_position", "Dictionary contains virtual_joystick_position")
	assert_has(data, "virtual_buttons", "Dictionary contains virtual_buttons")

	# Deserialize to new profile
	var p2 := RS_InputProfile.new()
	p2.from_dictionary(data)

	# Verify touchscreen fields were restored
	assert_eq(p2.virtual_joystick_position, Vector2(120, 450), "virtual_joystick_position round-trip")
	assert_eq(p2.virtual_buttons.size(), 4, "virtual_buttons array size restored")

	# Verify button data
	assert_eq(p2.virtual_buttons[0]["action"], StringName("jump"), "Button 0 action restored")
	assert_eq(p2.virtual_buttons[0]["position"], Vector2(800, 450), "Button 0 position restored")
	assert_eq(p2.virtual_buttons[1]["action"], StringName("sprint"), "Button 1 action restored")
	assert_eq(p2.virtual_buttons[1]["position"], Vector2(800, 350), "Button 1 position restored")

func test_touchscreen_profile_loads_with_virtual_buttons() -> void:
	var script := DefaultTouchscreenProfile.new()
	var profile: RS_InputProfile = script.build()
	assert_not_null(profile, "Touchscreen profile should build")
	assert_eq(profile.device_type, 2, "Device type should be touchscreen")
	assert_eq(profile.virtual_buttons.size(), 4, "Should have 4 virtual buttons")
	# Test button structure
	for button in profile.virtual_buttons:
		assert_true(button.has("action"), "Button should have action")
		assert_true(button.has("position"), "Button should have position")

func test_touchscreen_profile_has_joystick_position() -> void:
	var script := DefaultTouchscreenProfile.new()
	var profile: RS_InputProfile = script.build()
	assert_ne(profile.virtual_joystick_position, Vector2(-1, -1), "Should have joystick position")

## Test that default keyboard profiles use physical_keycode (not keycode)
## This ensures keyboard input works correctly with God's input system
func test_default_keyboard_profiles_use_physical_keycode() -> void:
	var profiles := [
		DefaultKeyboardProfile,
		AlternateKeyboardProfile,
		AccessibilityKeyboardProfile
	]

	for profile_script in profiles:
		var instance: Object = profile_script.new()
		var profile: RS_InputProfile = instance.build()
		assert_not_null(profile, "Profile built from script")

		# Check all action mappings
		for action_name in profile.action_mappings.keys():
			var events: Array = profile.get_events_for_action(StringName(action_name))
			for event in events:
				if event is InputEventKey:
					var key_event := event as InputEventKey
					assert_ne(key_event.physical_keycode, 0,
						"Profile %s action '%s' uses physical_keycode (not keycode)" % [profile_script.resource_path, action_name])
					# If keycode is set but physical_keycode is 0, that's the bug we fixed
					if key_event.keycode != 0 and key_event.physical_keycode == 0:
						fail_test("Profile %s action '%s' has keycode=%d but physical_keycode=0 (should use physical_keycode)" %
							[profile_script.resource_path, action_name, key_event.keycode])

func test_keyboard_profiles_bind_ui_focus_actions() -> void:
	var profiles := [
		DefaultKeyboardProfile,
		AlternateKeyboardProfile,
		AccessibilityKeyboardProfile
	]
	for profile_script in profiles:
		var instance: Object = profile_script.new()
		var profile: RS_InputProfile = instance.build()
		assert_not_null(profile, "Profile built from script")
		var next_events := profile.get_events_for_action(StringName("ui_focus_next"))
		assert_true(next_events.size() > 0, "Profile %s should bind ui_focus_next" % profile_script.resource_path)
		var prev_events := profile.get_events_for_action(StringName("ui_focus_prev"))
		assert_true(prev_events.size() > 0, "Profile %s should bind ui_focus_prev" % profile_script.resource_path)

func test_default_keyboard_profile_binds_tab_to_ui_focus_next() -> void:
	var instance: Object = DefaultKeyboardProfile.new()
	var profile: RS_InputProfile = instance.build()
	assert_not_null(profile, "Profile built from script")
	var events := profile.get_events_for_action(StringName("ui_focus_next"))
	var found_tab := false
	for event in events:
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_TAB:
			found_tab = true
			break
	assert_true(found_tab, "Default keyboard profile should bind Tab to ui_focus_next")

func test_default_keyboard_profile_binds_shift_tab_to_ui_focus_prev() -> void:
	var instance: Object = DefaultKeyboardProfile.new()
	var profile: RS_InputProfile = instance.build()
	assert_not_null(profile, "Profile built from script")
	var events := profile.get_events_for_action(StringName("ui_focus_prev"))
	var found_shift_tab := false
	for event in events:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.physical_keycode == KEY_TAB and key_event.shift_pressed:
				found_shift_tab = true
				break
	assert_true(found_shift_tab, "Default keyboard profile should bind Shift+Tab to ui_focus_prev")

func test_gamepad_profiles_bind_ui_focus_actions() -> void:
	var profiles := [
		DefaultGamepadProfile,
		AccessibilityGamepadProfile
	]
	for profile_script in profiles:
		var instance: Object = profile_script.new()
		var profile: RS_InputProfile = instance.build()
		assert_not_null(profile, "Profile built from script")
		var next_events := profile.get_events_for_action(StringName("ui_focus_next"))
		assert_true(next_events.size() > 0, "Profile %s should bind ui_focus_next" % profile_script.resource_path)
		var prev_events := profile.get_events_for_action(StringName("ui_focus_prev"))
		assert_true(prev_events.size() > 0, "Profile %s should bind ui_focus_prev" % profile_script.resource_path)

func test_default_gamepad_profiles_bind_camera_center_to_right_stick() -> void:
	var profiles := [
		DefaultGamepadProfile,
		AccessibilityGamepadProfile
	]
	for profile_script in profiles:
		var instance: Object = profile_script.new()
		var profile: RS_InputProfile = instance.build()
		assert_not_null(profile, "Profile built from script")
		var events := profile.get_events_for_action(StringName("camera_center"))
		var has_r3 := false
		for event in events:
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_STICK:
				has_r3 = true
		assert_true(has_r3, "Profile %s should bind camera_center to R3 by default" % profile_script.resource_path)

func test_default_gamepad_profiles_keep_sprint_on_left_stick() -> void:
	var profiles := [
		DefaultGamepadProfile,
		AccessibilityGamepadProfile
	]
	for profile_script in profiles:
		var instance: Object = profile_script.new()
		var profile: RS_InputProfile = instance.build()
		assert_not_null(profile, "Profile built from script")
		var events := profile.get_events_for_action(StringName("sprint"))
		var has_l3 := false
		for event in events:
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_STICK:
				has_l3 = true
		assert_true(has_l3, "Profile %s should keep sprint on L3 by default" % profile_script.resource_path)

func test_default_gamepad_profiles_bind_look_actions_to_right_stick_axes() -> void:
	var profiles := [
		DefaultGamepadProfile,
		AccessibilityGamepadProfile
	]
	var expected := {
		StringName("look_left"): {"axis": JOY_AXIS_RIGHT_X, "axis_value": -1.0},
		StringName("look_right"): {"axis": JOY_AXIS_RIGHT_X, "axis_value": 1.0},
		StringName("look_up"): {"axis": JOY_AXIS_RIGHT_Y, "axis_value": -1.0},
		StringName("look_down"): {"axis": JOY_AXIS_RIGHT_Y, "axis_value": 1.0},
	}

	for profile_script in profiles:
		var instance: Object = profile_script.new()
		var profile: RS_InputProfile = instance.build()
		assert_not_null(profile, "Profile built from script")
		for action_name in expected.keys():
			var events := profile.get_events_for_action(action_name)
			var action_expectation: Dictionary = expected[action_name]
			var expected_axis: int = int(action_expectation.get("axis", -1))
			var expected_axis_value: float = float(action_expectation.get("axis_value", 0.0))
			var has_expected_axis := false
			for event in events:
				if event is InputEventJoypadMotion:
					var motion := event as InputEventJoypadMotion
					if motion.axis == expected_axis and is_equal_approx(motion.axis_value, expected_axis_value):
						has_expected_axis = true
						break
			assert_true(
				has_expected_axis,
				"Profile %s action %s should use right-stick axis %d @ %.1f" % [
					profile_script.resource_path,
					String(action_name),
					expected_axis,
					expected_axis_value
				]
			)
