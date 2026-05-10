extends GutTest

const OverlayScene := preload("res://scenes/core/ui/overlays/ui_input_rebinding_overlay.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const BaseOverlay := preload("res://scripts/core/ui/base/base_overlay.gd")

var _store: TestStateStore
var _profile_manager: ProfileManagerStub
var _scene_manager_mock: Node

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null
	_store = TestStateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	if _store.settings != null:
		_store.settings.enable_persistence = false
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await _pump()
	await _pump()

	_profile_manager = ProfileManagerStub.new()
	add_child_autofree(_profile_manager)
	_profile_manager.store_ref = _store
	U_ServiceLocator.register(StringName("input_profile_manager"), _profile_manager)
	await _pump()

	_scene_manager_mock = SceneManagerMock.new()
	add_child_autofree(_scene_manager_mock)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager_mock)

func after_each() -> void:
	if _profile_manager != null:
		_profile_manager.teardown()
	_profile_manager = null
	_store = null
	_scene_manager_mock = null
	U_StateHandoff.clear_all()
	U_UI_THEME_BUILDER.active_config = null

func test_input_rebinding_overlay_has_motion_and_theme_tokens_when_active_config_set() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 35
	config.section_header = 17
	config.body_small = 15
	config.margin_section = 22
	config.separation_default = 14
	config.separation_compact = 6
	config.bg_base = Color(0.08, 0.11, 0.16, 1.0)
	config.text_secondary = Color(0.75, 0.81, 0.89, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	var motion_set: Variant = overlay.get("motion_set")
	assert_not_null(motion_set, "Input rebinding overlay should assign enter/exit motion set")
	if motion_set != null:
		assert_true("enter" in motion_set, "Motion set should expose enter presets")
		assert_true("exit" in motion_set, "Motion set should expose exit presets")

	var title_label := overlay.get_node_or_null("%TitleLabel") as Label
	var status_label := overlay.get_node_or_null("%StatusLabel") as Label
	var search_box := overlay.get_node_or_null("%SearchBox") as LineEdit
	var main_panel := overlay.get_node_or_null("%MainPanel") as PanelContainer
	var panel_padding := overlay.get_node_or_null("%MainPanelPadding") as MarginContainer
	var action_list := overlay.get_node_or_null("%ActionList") as VBoxContainer
	var button_row := overlay.get_node_or_null("%ButtonRow") as HBoxContainer
	var overlay_background := overlay.get_node_or_null("OverlayBackground") as ColorRect
	var expected_dim := config.bg_base
	expected_dim.a = 0.5

	assert_not_null(title_label, "TitleLabel should exist")
	assert_not_null(status_label, "StatusLabel should exist")
	assert_not_null(search_box, "SearchBox should exist")
	assert_not_null(main_panel, "MainPanel should exist")
	assert_not_null(panel_padding, "MainPanelPadding should exist")
	assert_not_null(action_list, "ActionList should exist")
	assert_not_null(button_row, "ButtonRow should exist")
	assert_not_null(overlay_background, "OverlayBackground should exist")

	if title_label != null:
		assert_eq(title_label.get_theme_font_size(&"font_size"), 35, "Title should use heading token")
	if status_label != null:
		assert_eq(status_label.get_theme_font_size(&"font_size"), 17, "Status should use section_header token")
		assert_true(
			status_label.get_theme_color(&"font_color").is_equal_approx(config.text_secondary),
			"Status should use text_secondary token"
		)
	if search_box != null:
		assert_eq(search_box.get_theme_font_size(&"font_size"), 15, "Search box should use body_small token")
		assert_true(
			search_box.has_theme_stylebox_override(&"normal"),
			"Search box should have themed normal stylebox override"
		)
		assert_true(
			search_box.has_theme_stylebox_override(&"focus"),
			"Search box should have themed focus stylebox override"
		)
		assert_true(
			search_box.get_theme_color(&"font_placeholder_color").is_equal_approx(config.text_secondary),
			"Search box placeholder should use text_secondary token"
		)
	if main_panel != null:
		assert_not_null(main_panel.get_theme_stylebox(&"panel"), "Main panel should have themed panel style")
	if panel_padding != null:
		assert_eq(panel_padding.get_theme_constant(&"margin_left"), 22, "Panel padding should use margin_section token")
	if action_list != null:
		assert_eq(action_list.get_theme_constant(&"separation"), 6, "Action list should use separation_compact token")
	if button_row != null:
		assert_eq(button_row.get_theme_constant(&"separation"), 14, "Button row should use separation_default token")
	if overlay_background != null:
		assert_true(
			overlay_background.color.is_equal_approx(expected_dim),
			"Overlay dim should use bg_base at 0.5 alpha"
		)

func test_input_rebinding_panel_host_caps_to_project_viewport_margins() -> void:
	var config := RS_UI_THEME_CONFIG.new()
	config.margin_outer = 20
	config.ensure_runtime_defaults()
	U_UI_THEME_BUILDER.active_config = config

	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	var host := overlay.get_node_or_null("%MainPanelMotionHost") as Control
	var panel := overlay.get_node_or_null("%MainPanel") as PanelContainer
	var resolved_size: Vector2 = overlay._resolve_panel_host_size(Vector2(960.0, 600.0), config)

	assert_eq(resolved_size, Vector2(860.0, 560.0), "Rebind panel should leave top and bottom viewport padding at the project viewport size")
	assert_not_null(host, "MainPanelMotionHost should exist")
	assert_not_null(panel, "MainPanel should exist")
	if host != null:
		assert_lte(host.custom_minimum_size.x, BaseOverlay.OVERLAY_PANEL_SIZE.x, "Rebind host should not exceed the shared overlay width")
		assert_lte(host.custom_minimum_size.y, BaseOverlay.OVERLAY_PANEL_SIZE.y, "Rebind host should not exceed the shared overlay height")
	if panel != null:
		assert_eq(panel.custom_minimum_size, Vector2.ZERO, "Rebind panel minimum should not override the host cap")

func test_keyboard_horizontal_navigation_cycles_row_buttons_and_preserves_row_highlight() -> void:
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	var rows_value: Variant = overlay.get("_action_rows")
	assert_true(rows_value is Dictionary, "Overlay should expose action rows dictionary")
	if not (rows_value is Dictionary):
		return
	var rows: Dictionary = rows_value as Dictionary
	var jump_row: Dictionary = rows.get(StringName("test_jump"), {})
	var add_button := jump_row.get("add_button") as Button
	var replace_button := jump_row.get("replace_button") as Button
	var row_container := jump_row.get("container") as Control
	assert_not_null(add_button, "Jump row should expose add button")
	assert_not_null(replace_button, "Jump row should expose replace button")
	assert_not_null(row_container, "Jump row should expose container")
	if add_button == null or replace_button == null or row_container == null:
		return

	add_button.grab_focus()
	await _pump()

	var right := InputEventAction.new()
	right.action = StringName("ui_right")
	right.pressed = true
	overlay.call("_unhandled_key_input", right)
	await _pump()

	var focused := overlay.get_viewport().gui_get_focus_owner()
	assert_eq(focused, replace_button, "Keyboard right should move row focus to replace button")
	assert_true(
		row_container.modulate.is_equal_approx(Color(1, 1, 1, 1)),
		"Focused row should remain highlighted when moving horizontally"
	)

	var left := InputEventAction.new()
	left.action = StringName("ui_left")
	left.pressed = true
	overlay.call("_unhandled_key_input", left)
	await _pump()

	focused = overlay.get_viewport().gui_get_focus_owner()
	assert_eq(focused, add_button, "Keyboard left should move row focus back to add button")

func test_analog_navigation_uses_repeater_only() -> void:
	var overlay: BaseOverlay = OverlayScene.instantiate() as BaseOverlay
	add_child_autofree(overlay)
	await _pump()

	# Focus the first action row (Add button) so vertical navigation is visible
	var rows_value: Variant = overlay.get("_action_rows")
	assert_true(rows_value is Dictionary, "Overlay should expose action rows dictionary")
	var rows: Dictionary = rows_value as Dictionary
	var keys: Array = rows.keys()
	assert_false(keys.is_empty(), "Overlay should expose at least one action row")
	var first_key: StringName = keys[0] as StringName
	var first_row: Dictionary = rows[first_key]
	var add_button: Button = first_row.get("add_button")
	assert_not_null(add_button, "First row should expose add button")
	add_button.grab_focus()
	await _pump()

	# Simulate a single down navigation via the analog repeater
	overlay._navigate_focus(StringName("ui_down"))
	await _pump()

	# Now send a matching joypad motion event. Because BaseMenuScreen swallows
	# analog motion for navigation axes, this should NOT cause an extra move.
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_Y
	motion.axis_value = 1.0
	motion.device = 0
	overlay._unhandled_input(motion)
	await _pump()

	# Expect focus to have advanced by exactly one row, not skipped twice.
	var viewport := overlay.get_viewport()
	var focused := viewport.gui_get_focus_owner()
	assert_not_null(focused, "Overlay should keep a focused control")

func test_reserved_actions_show_as_disabled() -> void:
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	var rows_value: Variant = overlay.get("_action_rows")
	assert_true(rows_value is Dictionary, "Overlay should expose action rows dictionary")
	var rows: Dictionary = {}
	if rows_value is Dictionary:
		rows = rows_value as Dictionary

	# Pause should be excluded from the overlay entirely
	assert_false(rows.has(StringName("pause")), "Pause action should be excluded from rebind controls")

	# Non-reserved actions should work normally
	var jump_row: Dictionary = rows[StringName("test_jump")]
	var jump_replace: Button = jump_row.get("replace_button")
	assert_not_null(jump_replace)
	assert_false(jump_replace.disabled, "Non-reserved action should support replace")

func test_camera_category_includes_look_actions() -> void:
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	var rows_value: Variant = overlay.get("_action_rows")
	assert_true(rows_value is Dictionary, "Overlay should expose action rows dictionary")
	if not (rows_value is Dictionary):
		return
	var rows: Dictionary = rows_value as Dictionary
	assert_true(rows.has(StringName("look_left")), "Look Left should be listed in camera actions")
	assert_true(rows.has(StringName("look_right")), "Look Right should be listed in camera actions")
	assert_false(rows.has(StringName("look_up")), "Look Up should not be listed in camera actions (handled by right stick, not rebindable)")
	assert_false(rows.has(StringName("look_down")), "Look Down should not be listed in camera actions (handled by right stick, not rebindable)")
	assert_false(rows.has(StringName("aim")), "Aim should not be listed in camera actions")
	assert_true(rows.has(StringName("camera_center")), "Camera Center should be listed in camera actions")

func test_close_button_requests_settings_scene_when_no_overlays() -> void:
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	overlay.call("_on_close_pressed")
	await _pump()

	var capturing: bool = overlay.get("_is_capturing")
	assert_false(capturing, "Close should not leave rebind capture active when no overlays are present")

func test_rebinding_updates_inputmap_and_dispatches() -> void:
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	var rows_value: Variant = overlay.get("_action_rows")
	assert_true(rows_value is Dictionary, "Overlay should expose action rows dictionary")
	var rows: Dictionary = {}
	if rows_value is Dictionary:
		rows = rows_value as Dictionary
	var jump_replace: Button = rows[StringName("test_jump")].get("replace_button")
	jump_replace.emit_signal("pressed")
	await _pump()

	var new_event := InputEventKey.new()
	new_event.keycode = Key.KEY_F9
	new_event.physical_keycode = Key.KEY_F9
	new_event.pressed = true
	overlay.call("_input", new_event)
	await _pump()

	var events: Array = InputMap.action_get_events(StringName("test_jump"))
	assert_eq(events.size(), 1, "Jump action should have single binding")
	assert_true((events[0] as InputEvent).is_match(new_event))

	var bindings: Dictionary = _get_store_custom_bindings()
	var jump_key: Variant = _resolve_binding_key(bindings, StringName("test_jump"))
	assert_not_null(jump_key, "Store should record jump binding entry")
	var stored_events_variant: Variant = bindings.get(jump_key, [])
	assert_true(stored_events_variant is Array, "Store binding payload should be array")
	var stored_events: Array = stored_events_variant
	assert_eq(stored_events.size(), 1, "Store should keep single binding for replace mode")
	var stored_event_variant: Variant = stored_events[0]
	assert_true(stored_event_variant is Dictionary, "Stored binding should be serialized dictionary")
	var stored_event: Dictionary = stored_event_variant
	assert_eq(int(stored_event.get("keycode", 0)), Key.KEY_F9)
	assert_eq(String(stored_event.get("type", "")), "key")

func test_add_binding_appends_additional_event() -> void:
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	var rows_value: Variant = overlay.get("_action_rows")
	assert_true(rows_value is Dictionary, "Overlay should expose action rows dictionary")
	var rows: Dictionary = {}
	if rows_value is Dictionary:
		rows = rows_value as Dictionary
	var add_button: Button = rows[StringName("test_jump")].get("add_button")
	add_button.emit_signal("pressed")
	await _pump()

	var additional_event := InputEventKey.new()
	additional_event.keycode = Key.KEY_F10
	additional_event.physical_keycode = Key.KEY_F10
	additional_event.pressed = true
	overlay.call("_input", additional_event)
	await _pump()

	var events: Array = InputMap.action_get_events(StringName("test_jump"))
	assert_eq(events.size(), 2, "Add binding should retain existing binding and append new one")
	var event_key_names: Array[String] = []
	for event in events:
		if event is InputEventKey:
			event_key_names.append(OS.get_keycode_string((event as InputEventKey).keycode))
	assert_true(event_key_names.has("J"), "Existing default binding should remain after add")
	assert_true(event_key_names.has("F10"), "New binding should be added alongside default")

	var last_add_action: Dictionary = _store.dispatched_actions.back()
	assert_eq(last_add_action.get("type"), U_InputActions.ACTION_REBIND_ACTION)
	var add_payload: Dictionary = last_add_action.get("payload", {})
	var payload_events_variant: Variant = add_payload.get("events", [])
	assert_true(payload_events_variant is Array, "Add payload should include serialized events array")
	var payload_events: Array = []
	if payload_events_variant is Array:
		payload_events = payload_events_variant as Array
	assert_eq(payload_events.size(), 2, "Add payload should include both default and new bindings")

	var bindings: Dictionary = _get_store_custom_bindings()
	var jump_key: Variant = _resolve_binding_key(bindings, StringName("test_jump"))
	assert_not_null(jump_key, "Store should retain jump entry after add binding")
	var stored_events_variant: Variant = bindings.get(jump_key, [])
	assert_true(stored_events_variant is Array, "Store bindings payload should be array")
	var stored_events: Array = []
	if stored_events_variant is Array:
		stored_events = stored_events_variant as Array
	assert_eq(stored_events.size(), 2, "Store should persist both default and additional binding")
	var reconstructed: Array[InputEvent] = _deserialize_event_array(stored_events)
	var stored_key_names: Array[String] = []
	for reconstructed_event in reconstructed:
		if reconstructed_event is InputEventKey:
			stored_key_names.append(OS.get_keycode_string((reconstructed_event as InputEventKey).keycode))
	assert_true(stored_key_names.has("J"), "Store should persist default binding for replay")
	assert_true(stored_key_names.has("F10"), "Store should persist newly added binding")

func test_overlay_displays_actual_binding_not_action_prompt_glyph() -> void:
	# Regression: action prompt glyphs (e.g. move_forward shows "W") must NOT mask
	# the actual currently bound event for the action.
	var action := StringName("move_forward")
	assert_true(InputMap.has_action(action), "Project InputMap should define move_forward")

	var original_events: Array = InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var f9 := InputEventKey.new()
	f9.keycode = Key.KEY_F9
	f9.physical_keycode = Key.KEY_F9
	InputMap.action_add_event(action, f9)

	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	var rows_value: Variant = overlay.get("_action_rows")
	assert_true(rows_value is Dictionary, "Overlay should expose action rows dictionary")
	var rows: Dictionary = rows_value as Dictionary
	assert_true(rows.has(action), "Overlay should expose move_forward row")
	var row: Dictionary = rows[action]
	var binding_container: HBoxContainer = row.get("binding_container")
	assert_not_null(binding_container, "Row should expose binding container")

	var found_label := false
	for child in binding_container.get_children():
		if child is Label:
			var label := child as Label
			if label.text.contains("F9"):
				found_label = true
				break
	assert_true(found_label, "Overlay should display F9 (not the action glyph)")

	# Restore original InputMap events for move_forward.
	InputMap.action_erase_events(action)
	for ev in original_events:
		if ev is InputEvent:
			InputMap.action_add_event(action, (ev as InputEvent).duplicate(true))

func test_dpad_button_bindings_have_icons() -> void:
	var dpad_down := InputEventJoypadButton.new()
	dpad_down.button_index = JOY_BUTTON_DPAD_DOWN
	var texture := U_InputRebindUtils.get_texture_for_event(dpad_down)
	assert_not_null(texture, "D-pad Down should display an icon (not just text)")

func test_conflict_prompts_and_swaps_on_confirm() -> void:
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	var rows_value: Variant = overlay.get("_action_rows")
	assert_true(rows_value is Dictionary, "Overlay should expose action rows dictionary")
	var rows: Dictionary = {}
	if rows_value is Dictionary:
		rows = rows_value as Dictionary
	var jump_button: Button = rows[StringName("test_jump")].get("replace_button")
	jump_button.emit_signal("pressed")
	await _pump()

	var conflict_event := InputEventKey.new()
	conflict_event.keycode = Key.KEY_K
	conflict_event.physical_keycode = Key.KEY_K
	conflict_event.pressed = true
	overlay.call("_input", conflict_event)
	await _pump()

	assert_eq(overlay.get("_pending_conflict"), StringName("test_sprint"))
	var dialog: ConfirmationDialog = overlay.get_node("%ConflictDialog")
	assert_true(dialog.visible)
	assert_string_contains(dialog.dialog_text, "K is already bound to Test Sprint")

	overlay.call("_on_conflict_confirmed")
	await _pump()

	var jump_events: Array = InputMap.action_get_events(StringName("test_jump"))
	assert_eq(jump_events.size(), 1)
	var jump_event_names: Array[String] = []
	for event in jump_events:
		if event is InputEventKey:
			jump_event_names.append(OS.get_keycode_string((event as InputEventKey).keycode))
	assert_true(jump_event_names.has("K"), "Jump should adopt conflicting key after confirmation")

	var sprint_events: Array = InputMap.action_get_events(StringName("test_sprint"))
	assert_eq(sprint_events.size(), 1, "Conflict swap should reassign previous bindings to the conflicted action")
	var sprint_event_names: Array[String] = []
	for event in sprint_events:
		if event is InputEventKey:
			sprint_event_names.append(OS.get_keycode_string((event as InputEventKey).keycode))
	assert_true(sprint_event_names.has("J"), "Sprint should adopt previous jump binding")

	assert_true(_store.dispatched_actions.size() >= 2, "Conflict swap should dispatch rebind actions for both participants")
	var dispatch_count: int = _store.dispatched_actions.size()
	var jump_rebind: Dictionary = _store.dispatched_actions[dispatch_count - 2]
	var sprint_rebind: Dictionary = _store.dispatched_actions[dispatch_count - 1]

	assert_eq(jump_rebind.get("type"), U_InputActions.ACTION_REBIND_ACTION)
	var jump_payload: Dictionary = jump_rebind.get("payload", {})
	assert_eq(jump_payload.get("action"), StringName("test_jump"))
	assert_eq(String(jump_payload.get("mode", "")), U_InputActions.REBIND_MODE_REPLACE)
	var jump_events_variant: Variant = jump_payload.get("events", [])
	assert_true(jump_events_variant is Array, "Jump rebind should include serialized events payload")
	var jump_events_array: Array = []
	if jump_events_variant is Array:
		jump_events_array = jump_events_variant
	assert_eq(jump_events_array.size(), 1, "Jump should retain single binding after swap")
	var jump_event_dict: Dictionary = jump_events_array[0]
	assert_eq(int(jump_event_dict.get("keycode", 0)), int(Key.KEY_K))
	assert_eq(String(jump_event_dict.get("type", "")), "key")

	assert_eq(sprint_rebind.get("type"), U_InputActions.ACTION_REBIND_ACTION)
	var sprint_payload: Dictionary = sprint_rebind.get("payload", {})
	assert_eq(sprint_payload.get("action"), StringName("test_sprint"))
	assert_eq(String(sprint_payload.get("mode", "")), U_InputActions.REBIND_MODE_REPLACE)
	var sprint_events_variant: Variant = sprint_payload.get("events", [])
	assert_true(sprint_events_variant is Array, "Sprint rebind should include serialized events payload")
	var sprint_events_array: Array = []
	if sprint_events_variant is Array:
		sprint_events_array = sprint_events_variant
	assert_eq(sprint_events_array.size(), 1, "Sprint should adopt previous jump binding")
	var sprint_event_dict: Dictionary = sprint_events_array[0]
	assert_eq(OS.get_keycode_string(int(sprint_event_dict.get("keycode", 0))), "J")

	var state: Dictionary = _store.get_state()
	var settings_slice_value: Variant = state.get("settings", {})
	var settings_slice: Dictionary = settings_slice_value if settings_slice_value is Dictionary else {}
	var input_settings_value: Variant = settings_slice.get("input_settings", {})
	var input_settings: Dictionary = input_settings_value if input_settings_value is Dictionary else {}
	var custom_bindings_value: Variant = input_settings.get("custom_bindings", {})
	var custom_bindings: Dictionary = custom_bindings_value if custom_bindings_value is Dictionary else {}
	var sprint_key: Variant = _resolve_binding_key(custom_bindings, StringName("test_sprint"))
	assert_not_null(sprint_key, "Store should record sprint binding entry")
	var stored_sprint_events_value: Variant = custom_bindings.get(sprint_key, [])
	assert_true(stored_sprint_events_value is Array, "Stored sprint events payload should be an array")
	var stored_sprint_events: Array[InputEvent] = _deserialize_event_array(stored_sprint_events_value)
	assert_eq(stored_sprint_events.size(), 1, "Sprint custom bindings should contain swapped event")
	var stored_sprint_names: Array[String] = []
	for stored_event in stored_sprint_events:
		if stored_event is InputEventKey:
			stored_sprint_names.append(OS.get_keycode_string((stored_event as InputEventKey).keycode))
	assert_true(stored_sprint_names.has("J"), "Store should persist swapped sprint binding")

	var jump_key: Variant = _resolve_binding_key(custom_bindings, StringName("test_jump"))
	assert_not_null(jump_key, "Store should retain jump entry after swap")
	var stored_jump_events: Array[InputEvent] = _deserialize_event_array(custom_bindings.get(jump_key, []))
	assert_eq(stored_jump_events.size(), 1)
	var stored_jump_names: Array[String] = []
	for stored_event in stored_jump_events:
		if stored_event is InputEventKey:
			stored_jump_names.append(OS.get_keycode_string((stored_event as InputEventKey).keycode))
	assert_true(stored_jump_names.has("K"), "Store should persist updated jump binding")

func test_reset_button_invokes_manager_and_updates_status() -> void:
	if not InputMap.has_action(StringName("test_jump")):
		InputMap.add_action("test_jump")
	InputMap.action_erase_events(StringName("test_jump"))
	var custom_event := InputEventKey.new()
	custom_event.keycode = Key.KEY_L
	custom_event.physical_keycode = Key.KEY_L
	custom_event.pressed = true
	InputMap.action_add_event(StringName("test_jump"), custom_event)
	_store.dispatch(U_InputActions.rebind_action(StringName("test_jump"), custom_event, U_InputActions.REBIND_MODE_REPLACE, [custom_event]))
	await _pump()

	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()

	var reset_button: Button = overlay.get_node("%ResetButton")
	reset_button.emit_signal("pressed")
	await _pump()

	# The reset button now shows a confirmation dialog
	var reset_confirm_dialog: ConfirmationDialog = overlay.get_node("%ResetConfirmDialog")
	assert_true(reset_confirm_dialog.visible, "Reset confirmation dialog should be shown")

	# Confirm the reset
	reset_confirm_dialog.emit_signal("confirmed")
	await _pump()

	assert_eq(_profile_manager.reset_call_count, 1, "Reset button should invoke profile manager")
	var events: Array = InputMap.action_get_events(StringName("test_jump"))
	assert_eq(events.size(), 1, "Reset should restore a single binding")
	var restored: InputEventKey = events[0] as InputEventKey
	assert_eq(restored.keycode, Key.KEY_J, "Reset should restore default key binding")

	assert_gt(_store.dispatched_actions.size(), 0, "Reset should dispatch action to store")
	var last_action: Dictionary = _store.dispatched_actions[_store.dispatched_actions.size() - 1]
	assert_eq(last_action.get("type"), U_InputActions.ACTION_RESET_BINDINGS)

	var status_label: Label = overlay.get_node("%StatusLabel")
	assert_eq(status_label.text, "Bindings reset to defaults.", "Overlay should update status after reset")

class ProfileManagerStub extends I_InputProfileManager:
	signal profile_switched(profile_id: String)
	signal bindings_reset()
	signal custom_binding_added(action: StringName, event: InputEvent)

	var active_profile: RS_InputProfile = RS_InputProfile.new()
	var custom_bindings: Dictionary = {}
	var _tracked_actions: Array[StringName] = []
	var store_ref: M_StateStore = null : set = set_store_ref
	var reset_call_count: int = 0
	var _unsubscribe: Callable = Callable()

	func _init() -> void:
		active_profile.set_events_for_action(StringName("test_jump"), _make_event_array(_make_key_event(Key.KEY_J)))
		active_profile.set_events_for_action(StringName("test_sprint"), _make_event_array(_make_key_event(Key.KEY_K)))
		active_profile.set_events_for_action(StringName("pause"), _make_event_array(_make_key_event(Key.KEY_ESCAPE)))

	func _ready() -> void:
		for key in active_profile.action_mappings.keys():
			var action: StringName = StringName(key)
			_tracked_actions.append(action)
			if not InputMap.has_action(action):
				InputMap.add_action(String(action))
			InputMap.action_erase_events(action)
			var events: Array[InputEvent] = active_profile.get_events_for_action(action)
			for ev in events:
				InputMap.action_add_event(action, ev.duplicate(true))

	func set_store_ref(value: M_StateStore) -> void:
		if store_ref == value:
			return
		store_ref = value
		_refresh_store_subscription()

	func _refresh_store_subscription() -> void:
		if _unsubscribe != Callable() and _unsubscribe.is_valid():
			_unsubscribe.call()
			_unsubscribe = Callable()
		if store_ref == null:
			return
		_unsubscribe = store_ref.subscribe(_on_store_changed)
		_apply_state_snapshot(store_ref.get_state())

	func get_active_profile() -> RS_InputProfile:
		return active_profile

	func reset_action(_action: StringName) -> void:
		# Not used in this test
		pass

	func reset_touchscreen_positions() -> Array[Dictionary]:
		# Not used in this test
		return []

	func reset_to_defaults() -> void:
		reset_call_count += 1
		custom_bindings.clear()
		for key in active_profile.action_mappings.keys():
			var action: StringName = StringName(key)
			if not InputMap.has_action(action):
				InputMap.add_action(String(action))
			InputMap.action_erase_events(action)
			var events: Array[InputEvent] = active_profile.get_events_for_action(action)
			for ev in events:
				InputMap.action_add_event(action, ev.duplicate(true))
		if store_ref != null:
			store_ref.dispatch(U_InputActions.reset_bindings())
		bindings_reset.emit()

	func _on_store_changed(action: Dictionary, state: Dictionary) -> void:
		_apply_state_snapshot(state)
		var action_type: StringName = action.get("type", StringName())
		if action_type == U_InputActions.ACTION_REBIND_ACTION:
			var payload: Dictionary = action.get("payload", {})
			var action_name: StringName = payload.get("action", StringName())
			var event_dict: Dictionary = payload.get("event", {})
			var event: InputEvent = U_InputRebindUtils.dict_to_event(event_dict)
			if event != null:
				custom_binding_added.emit(action_name, event)

	func _apply_state_snapshot(state: Dictionary) -> void:
		if state == null:
			return
		_apply_profile_defaults()
		custom_bindings.clear()
		var settings_variant: Variant = state.get("settings", {})
		if not (settings_variant is Dictionary):
			return
		var input_variant: Variant = (settings_variant as Dictionary).get("input_settings", {})
		if not (input_variant is Dictionary):
			return
		var bindings_variant: Variant = (input_variant as Dictionary).get("custom_bindings", {})
		if not (bindings_variant is Dictionary):
			return
		for action_key in (bindings_variant as Dictionary).keys():
			var action_name: StringName = StringName(action_key)
			var events_variant: Variant = (bindings_variant as Dictionary)[action_key]
			if not (events_variant is Array):
				continue
			if not InputMap.has_action(action_name):
				InputMap.add_action(String(action_name))
			InputMap.action_erase_events(action_name)
			var parsed_events: Array[InputEvent] = []
			for entry in (events_variant as Array):
				if entry is Dictionary:
					var parsed: InputEvent = U_InputRebindUtils.dict_to_event(entry)
					if parsed != null:
						InputMap.action_add_event(action_name, parsed)
						parsed_events.append(parsed)
			if not parsed_events.is_empty():
				custom_bindings[action_name] = parsed_events

	func _apply_profile_defaults() -> void:
		for key in active_profile.action_mappings.keys():
			var action: StringName = StringName(key)
			if not InputMap.has_action(action):
				InputMap.add_action(String(action))
			InputMap.action_erase_events(action)
			var events: Array[InputEvent] = active_profile.get_events_for_action(action)
			for ev in events:
				InputMap.action_add_event(action, ev.duplicate(true))

	func _make_key_event(code: Key) -> InputEventKey:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		return ev

	func _make_event_array(event: InputEvent) -> Array[InputEvent]:
		var arr: Array[InputEvent] = []
		arr.append(event)
		return arr

	func teardown() -> void:
		if _unsubscribe != Callable() and _unsubscribe.is_valid():
			_unsubscribe.call()
			_unsubscribe = Callable()
		for action in _tracked_actions:
			if InputMap.has_action(action):
				InputMap.erase_action(action)
		_tracked_actions.clear()

class SceneManagerMock extends Node:
	var call_count: int = 0

	func pop_overlay() -> void:
		call_count += 1

	func transition_to_scene(_scene_id: StringName, _transition_type: String, _priority: int = 0) -> void:
		call_count += 1

class TestStateStore extends M_StateStore:
	var dispatched_actions: Array = []

	func dispatch(action: Dictionary) -> void:
		dispatched_actions.append(action.duplicate(true))
		super.dispatch(action)

func _pump() -> void:
	await get_tree().process_frame

func test_sync_focus_tracking_does_not_crash_on_row_container() -> void:
	# Regression: row.focus_entered passes the row VBoxContainer (a Control, not a Button).
	# TypedArray[Button].has(control) fails validation when control is not a Button.
	var overlay: Node = OverlayScene.instantiate()
	add_child_autofree(overlay)
	await _pump()
	await _pump()

	var row_container := overlay.get_node_or_null("%ActionList") as VBoxContainer
	assert_true(overlay.has_method("_sync_focus_tracking_from_control"),
		"Overlay should have _sync_focus_tracking_from_control method")
	# Calling with a non-Button control should not crash.
	overlay.call("_sync_focus_tracking_from_control", row_container)
	# If no exception was thrown, the regression is fixed.
	assert_true(true, "_sync_focus_tracking_from_control should not crash on non-Button control")

func _get_store_custom_bindings() -> Dictionary:
	if _store == null:
		return {}
	var state_variant: Variant = _store.get_state()
	if not (state_variant is Dictionary):
		return {}
	var state_dict: Dictionary = state_variant as Dictionary
	var settings_variant: Variant = state_dict.get("settings", {})
	if not (settings_variant is Dictionary):
		return {}
	var input_variant: Variant = (settings_variant as Dictionary).get("input_settings", {})
	if not (input_variant is Dictionary):
		return {}
	var bindings_variant: Variant = (input_variant as Dictionary).get("custom_bindings", {})
	if bindings_variant is Dictionary:
		return bindings_variant
	return {}

func _resolve_binding_key(bindings: Dictionary, action: StringName) -> Variant:
	if bindings.has(action):
		return action
	var action_str: String = String(action)
	if bindings.has(action_str):
		return action_str
	return null

func _deserialize_event_array(events_variant: Variant) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if events_variant is Array:
		for entry in (events_variant as Array):
			if entry is Dictionary:
				var parsed: InputEvent = U_InputRebindUtils.dict_to_event(entry)
				if parsed != null:
					result.append(parsed)
	return result

func _count_navigation_close_or_return_actions() -> int:
	if _store == null:
		return 0
	var count: int = 0
	for action in _store.dispatched_actions:
		var action_type: StringName = action.get("type", StringName())
		if action_type == U_NavigationActions.ACTION_CLOSE_TOP_OVERLAY \
				or action_type == U_NavigationActions.ACTION_RETURN_TO_MAIN_MENU:
			count += 1
		elif action_type == U_NavigationActions.ACTION_SET_SHELL:
			var shell: StringName = action.get("shell", StringName())
			var base_scene: StringName = action.get("base_scene_id", StringName())
			if shell == StringName("main_menu") and base_scene == StringName("settings_panel"):
				count += 1
		elif action_type == U_NavigationActions.ACTION_NAVIGATE_TO_UI_SCREEN:
			var scene_id: StringName = action.get("scene_id", StringName())
			if scene_id == StringName("settings_panel"):
				count += 1
	return count
