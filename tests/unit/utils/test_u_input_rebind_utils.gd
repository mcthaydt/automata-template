extends GutTest


var _created_actions: Array[StringName] = []

func before_each() -> void:
	_created_actions.clear()
	_setup_action(StringName("test_jump"), _make_key_event(Key.KEY_J))
	_setup_action(StringName("test_sprint"), _make_key_event(Key.KEY_K))

func after_each() -> void:
	for action in _created_actions:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	_created_actions.clear()

func test_validate_rebind_blocks_reserved_action() -> void:
	var settings := RS_RebindSettings.new()
	settings.reserved_actions = [StringName("test_jump")]
	var result := U_InputRebindUtils.validate_rebind(StringName("test_jump"), _make_key_event(Key.KEY_P), settings)
	assert_false(result.valid)
	assert_string_contains(result.error, "reserved")

func test_validate_rebind_detects_conflict() -> void:
	var settings := RS_RebindSettings.new()
	var event := _make_key_event(Key.KEY_K)
	var result := U_InputRebindUtils.validate_rebind(StringName("test_jump"), event, settings)
	assert_true(result.valid)
	assert_eq(result.conflict_action, StringName("test_sprint"))

func test_validate_rebind_blocks_conflict_with_reserved_action() -> void:
	var settings := RS_RebindSettings.new()
	settings.reserved_actions = [StringName("test_reserved")]
	_setup_action(StringName("test_reserved"), _make_key_event(Key.KEY_P))
	var result := U_InputRebindUtils.validate_rebind(StringName("test_jump"), _make_key_event(Key.KEY_P), settings)
	assert_false(result.valid)
	assert_string_contains(result.error.to_lower(), "reserved")

func test_rebind_action_updates_inputmap_and_profile() -> void:
	var profile := RS_InputProfile.new()
	profile.set_events_for_action(StringName("test_jump"), [_make_key_event(Key.KEY_J)])
	var new_event := _make_key_event(Key.KEY_L)

	var success := U_InputRebindUtils.rebind_action(StringName("test_jump"), new_event, profile)

	assert_true(success)
	var input_map_events := InputMap.action_get_events(StringName("test_jump"))
	assert_eq(input_map_events.size(), 1)
	assert_true(input_map_events[0].is_match(new_event))

	var profile_events := profile.get_events_for_action(StringName("test_jump"))
	assert_eq(profile_events.size(), 1)
	assert_true(profile_events[0].is_match(new_event))

func test_rebind_action_removes_conflicting_binding() -> void:
	var profile := RS_InputProfile.new()
	profile.set_events_for_action(StringName("test_jump"), [_make_key_event(Key.KEY_J)])
	profile.set_events_for_action(StringName("test_sprint"), [_make_key_event(Key.KEY_K)])
	var shared_event := _make_key_event(Key.KEY_K)

	var success := U_InputRebindUtils.rebind_action(StringName("test_jump"), shared_event, profile, StringName("test_sprint"))

	assert_true(success)
	var sprint_events := InputMap.action_get_events(StringName("test_sprint"))
	assert_true(sprint_events.is_empty())
	var profile_sprint_events := profile.get_events_for_action(StringName("test_sprint"))
	assert_true(profile_sprint_events.is_empty())

func test_rebind_action_add_mode_appends_event_without_duplicates() -> void:
	var profile := RS_InputProfile.new()
	var default_event := _make_key_event(Key.KEY_J)
	profile.set_events_for_action(StringName("test_jump"), [default_event])
	var new_event := _make_key_event(Key.KEY_L)

	var success := U_InputRebindUtils.rebind_action(
		StringName("test_jump"),
		new_event,
		profile,
		StringName(),
		false
	)
	assert_true(success)

	var events := InputMap.action_get_events(StringName("test_jump"))
	assert_eq(events.size(), 2)
	var has_default := false
	var has_new := false
	for event in events:
		if event.is_match(default_event):
			has_default = true
		if event.is_match(new_event):
			has_new = true
	assert_true(has_default, "Default binding should remain after add mode")
	assert_true(has_new, "New binding should be added when using add mode")

	var profile_events := profile.get_events_for_action(StringName("test_jump"))
	assert_eq(profile_events.size(), 2, "Profile should track both default and new bindings")

	# Adding the same event again should not create duplicates.
	success = U_InputRebindUtils.rebind_action(
		StringName("test_jump"),
		new_event,
		profile,
		StringName(),
		false
	)
	assert_true(success)
	events = InputMap.action_get_events(StringName("test_jump"))
	assert_eq(events.size(), 2, "Duplicate add should not increase binding count")

func test_rebind_action_returns_false_when_action_missing() -> void:
	var result := U_InputRebindUtils.rebind_action(StringName("does_not_exist"), _make_key_event(Key.KEY_B))
	assert_false(result)

func test_event_serialization_round_trip() -> void:
	var key_event := _make_key_event(Key.KEY_V)
	var key_dict := U_InputRebindUtils.event_to_dict(key_event)
	assert_eq(key_dict.get("type"), "key")
	var restored_key := U_InputRebindUtils.dict_to_event(key_dict)
	assert_true(restored_key is InputEventKey)
	assert_eq(restored_key.keycode, key_event.keycode)

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MouseButton.MOUSE_BUTTON_RIGHT
	var mouse_dict := U_InputRebindUtils.event_to_dict(mouse_event)
	assert_eq(mouse_dict.get("type"), "mouse_button")
	var restored_mouse := U_InputRebindUtils.dict_to_event(mouse_dict)
	assert_true(restored_mouse is InputEventMouseButton)
	assert_eq(restored_mouse.button_index, mouse_event.button_index)

	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = JoyButton.JOY_BUTTON_A
	var joy_dict := U_InputRebindUtils.event_to_dict(joy_event)
	assert_eq(joy_dict.get("type"), "joypad_button")
	var restored_joy := U_InputRebindUtils.dict_to_event(joy_dict)
	assert_true(restored_joy is InputEventJoypadButton)
	assert_eq(restored_joy.button_index, joy_event.button_index)

func test_format_binding_label_trims_key_prefix() -> void:
	assert_eq(U_InputRebindUtils.format_binding_label(" Key Space "), "Space")
	assert_eq(U_InputRebindUtils.format_binding_label("Mouse Left"), "Mouse Left")

func _setup_action(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(String(action))
		_created_actions.append(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event.duplicate(true))

func _make_key_event(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.unicode = 0
	return event

func test_validate_rebind_blocks_when_max_bindings_reached() -> void:
	var settings := RS_RebindSettings.new()
	settings.max_events_per_action = 1
	var action := StringName("test_jump")
	_setup_action(action, _make_key_event(Key.KEY_J))
	var result := U_InputRebindUtils.validate_rebind(action, _make_key_event(Key.KEY_L), settings, false)
	assert_false(result.valid)
	assert_string_contains(result.error.to_lower(), "maximum")

func test_conflict_detection_handles_physical_only_bindings() -> void:
	var action_a := StringName("test_forward")
	var action_b := StringName("test_jump")
	_setup_action(action_a, _make_key_event(Key.KEY_W))
	_setup_action(action_b, _make_key_event(Key.KEY_SPACE))

	var incoming := _make_key_event(Key.KEY_W)
	incoming.physical_keycode = 0
	var settings := RS_RebindSettings.new()
	var result := U_InputRebindUtils.validate_rebind(action_b, incoming, settings)
	var debug_actions: Array = []
	for existing_action in InputMap.get_actions():
		debug_actions.append(String(existing_action))
	var action_a_events := InputMap.action_get_events(action_a)
	var action_b_events := InputMap.action_get_events(action_b)
	assert_true(debug_actions.has(String(action_a)), "InputMap should contain action_a during conflict detection")
	assert_true(debug_actions.has(String(action_b)), "InputMap should contain action_b during conflict detection")
	assert_eq(action_a_events.size(), 1, "Action A should keep its original binding")
	assert_eq(action_b_events.size(), 1, "Action B should keep its original binding")
	assert_true(result.valid)
	assert_eq(result.conflict_action, action_a)

func test_rebind_action_conflict_removes_physical_only_binding() -> void:
	var conflict_action := StringName("conflict_action")
	var target_action := StringName("target_action")
	if not InputMap.has_action(conflict_action):
		InputMap.add_action(conflict_action)
	if not InputMap.has_action(target_action):
		InputMap.add_action(target_action)
	var conflict_event := InputEventKey.new()
	conflict_event.physical_keycode = Key.KEY_W
	conflict_event.keycode = 0
	InputMap.action_erase_events(conflict_action)
	InputMap.action_add_event(conflict_action, conflict_event)

	var new_event := InputEventKey.new()
	new_event.keycode = Key.KEY_W
	new_event.physical_keycode = 0

	var success := U_InputRebindUtils.rebind_action(
		target_action,
		new_event,
		null,
		conflict_action,
		true
	)
	assert_true(success, "Rebind should succeed with conflict removal")
	var remaining := InputMap.action_get_events(conflict_action)
	assert_true(remaining.is_empty(), "Conflict action should have its binding removed after swap")

## Test for Issue #1: Conflict detection should skip excluded actions
func test_validate_rebind_ignores_excluded_actions() -> void:
	# Set up built-in UI action that would conflict
	var ui_action := StringName("ui_cut")
	if not InputMap.has_action(ui_action):
		InputMap.add_action(ui_action)
	InputMap.action_erase_events(ui_action)
	InputMap.action_add_event(ui_action, _make_key_event(Key.KEY_X))

	# Set up our custom action
	var custom_action := StringName("test_action")
	_setup_action(custom_action, _make_key_event(Key.KEY_A))

	var settings := RS_RebindSettings.new()
	settings.require_confirmation = true

	# Try to rebind custom action to X (which conflicts with ui_cut)
	# WITHOUT excluded_actions - should detect conflict
	var result_without_exclusion := U_InputRebindUtils.validate_rebind(
		custom_action,
		_make_key_event(Key.KEY_X),
		settings,
		true,
		null,
		[]  # No excluded actions
	)
	assert_true(result_without_exclusion.valid, "Should be valid but require confirmation")
	assert_eq(result_without_exclusion.conflict_action, ui_action, "Should detect conflict with ui_cut")

	# WITH excluded_actions - should NOT detect conflict
	var excluded := ["ui_cut", "ui_copy", "ui_paste"]
	var result_with_exclusion := U_InputRebindUtils.validate_rebind(
		custom_action,
		_make_key_event(Key.KEY_X),
		settings,
		true,
		null,
		excluded
	)
	assert_true(result_with_exclusion.valid, "Should be valid")
	assert_eq(result_with_exclusion.conflict_action, StringName(), "Should NOT detect conflict when ui_cut is excluded")

func test_get_conflicting_action_respects_excluded_list() -> void:
	# Set up multiple potential conflicts
	var conflict_key := Key.KEY_ENTER
	_setup_action(StringName("ui_accept"), _make_key_event(conflict_key))
	_setup_action(StringName("ui_cancel"), _make_key_event(Key.KEY_ESCAPE))
	_setup_action(StringName("custom_confirm"), _make_key_event(Key.KEY_SPACE))

	var event := _make_key_event(conflict_key)

	# Without exclusions - should find ui_accept
	var conflict_no_exclusion := U_InputRebindUtils.get_conflicting_action(
		event,
		null,
		StringName(),
		[]
	)
	assert_true(conflict_no_exclusion != StringName(), "Should detect at least one conflict without exclusions")
	assert_true(
		U_RebindActionListHelper.EXCLUDED_ACTIONS.has(String(conflict_no_exclusion)),
		"Detected conflict should be one of the excluded overlay actions"
	)

	# With exclusions - should skip ui_accept
	var excluded: Array[String] = []
	excluded.assign(U_RebindActionListHelper.EXCLUDED_ACTIONS)
	var conflict_with_exclusion := U_InputRebindUtils.get_conflicting_action(
		event,
		null,
		StringName(),
		excluded
	)
	assert_eq(conflict_with_exclusion, StringName(), "Should not find conflict when ui_accept is excluded")
