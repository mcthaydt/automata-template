extends GutTest

const MobileControlsScene := preload("res://scenes/core/ui/hud/ui_mobile_controls.tscn")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_touchscreen_flow_updates_state_and_component() -> void:
	var ctx := await _setup_environment()
	var store: M_StateStore = ctx["store"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_frames(1)

	var joystick: UI_VirtualJoystick = ctx["joystick"]
	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))

	var jump_button: UI_VirtualButton = ctx["jump_button"]
	_press_button(jump_button)

	var manager: M_ECSManager = ctx["ecs_manager"]
	manager._physics_process(0.016)

	var component: C_InputComponent = ctx["component"]
	assert_almost_eq(component.move_vector.x, 1.0, 0.01,
		"Joystick drag should set move_vector.x to full right")
	assert_true(component.jump_pressed, "Jump button press should set jump_pressed on component")
	assert_eq(component.device_type, M_InputDeviceManager.DeviceType.TOUCHSCREEN,
		"Component should record touchscreen device type")

	var state := store.get_state()
	var move_input: Vector2 = U_InputSelectors.get_move_input(state)
	assert_almost_eq(move_input.x, 1.0, 0.01, "Store should capture move input from touchscreen controls")
	assert_true(U_InputSelectors.is_jump_pressed(state), "Store should capture jump state from touchscreen controls")

func test_controls_hide_and_processing_stops_on_device_change_and_transition() -> void:
	var ctx := await _setup_environment()
	var store: M_StateStore = ctx["store"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_state_update(store)

	var joystick: UI_VirtualJoystick = ctx["joystick"]
	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))

	var manager: M_ECSManager = ctx["ecs_manager"]
	manager._physics_process(0.016)

	var component: C_InputComponent = ctx["component"]
	var prior_vector: Vector2 = component.move_vector

	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.GAMEPAD, 0))
	await _await_state_update(store)

	var controls: UI_MobileControls = ctx["controls"]
	assert_false(controls.visible, "MobileControls should hide when active device is not touchscreen")

	_press_joystick(joystick, Vector2.ZERO, Vector2(0.0, -joystick.joystick_radius))
	manager._physics_process(0.016)
	assert_vector_almost_eq(component.move_vector, prior_vector, 0.001,
		"Touchscreen input should not update component when device is gamepad")

	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_state_update(store)
	assert_true(controls.visible, "MobileControls should reappear when touchscreen becomes active")

	store.dispatch(U_SceneActions.transition_started(StringName("demo_room"), "fade"))
	await _await_state_update(store)
	assert_false(controls.visible, "MobileControls should hide during scene transitions")

	store.dispatch(U_SceneActions.transition_completed(StringName("demo_room")))
	await _await_state_update(store)
	assert_true(controls.visible, "MobileControls should show after transition completes")

func test_reset_progress_after_victory_preserves_device_state_fields() -> void:
	var input_state := U_InputReducer.get_default_gameplay_input_state()
	input_state["active_device"] = M_InputDeviceManager.DeviceType.TOUCHSCREEN
	input_state["gamepad_connected"] = true
	input_state["gamepad_device_id"] = 4
	input_state["touchscreen_enabled"] = true
	input_state["last_input_time"] = 42.5
	input_state["move_input"] = Vector2.RIGHT
	input_state["look_input"] = Vector2(3.0, -2.0)
	input_state["jump_pressed"] = true
	input_state["jump_just_pressed"] = true
	input_state["sprint_pressed"] = true
	var state := {
		"input": input_state,
		"game_completed": true,
		"last_victory_objective": StringName("finale"),
		"player_max_health": 100.0,
		"player_health": 1.0,
	}

	var result: Dictionary = U_GameplayReducer.reduce(state, U_GameplayActions.reset_progress())
	var reset_input: Dictionary = result.get("input", {})

	assert_false(result.get("game_completed", true), "Reset progress should clear victory completion")
	assert_eq(reset_input.get("active_device"), M_InputDeviceManager.DeviceType.TOUCHSCREEN)
	assert_true(reset_input.get("gamepad_connected", false), "Reset progress should preserve gamepad connection state")
	assert_eq(reset_input.get("gamepad_device_id"), 4, "Reset progress should preserve gamepad device id")
	assert_true(reset_input.get("touchscreen_enabled", false), "Reset progress should preserve touchscreen_enabled")
	assert_almost_eq(float(reset_input.get("last_input_time", 0.0)), 42.5, 0.001,
		"Reset progress should preserve last input time")
	assert_vector_almost_eq(reset_input.get("move_input", Vector2.RIGHT), Vector2.ZERO, 0.001,
		"Reset progress should clear transient move input")
	assert_vector_almost_eq(reset_input.get("look_input", Vector2.ONE), Vector2.ZERO, 0.001,
		"Reset progress should clear transient look input")
	assert_false(reset_input.get("jump_pressed", true), "Reset progress should clear held jump")
	assert_false(reset_input.get("jump_just_pressed", true), "Reset progress should clear just-pressed jump")
	assert_false(reset_input.get("sprint_pressed", true), "Reset progress should clear sprint")

func test_gamepad_input_takes_over_on_mobile_and_touch_reappears_on_real_touch() -> void:
	var ctx := await _setup_environment()
	var store: M_StateStore = ctx["store"]
	var controls: UI_MobileControls = ctx["controls"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_state_update(store)
	assert_true(controls.visible, "Controls should start visible for active touchscreen gameplay")

	var input_manager := await _create_input_device_manager()
	input_manager.emulate_mobile_pointer_guard = true

	var motion := InputEventJoypadMotion.new()
	motion.device = 2
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.75
	input_manager._input(motion)
	await _await_state_update(store)

	assert_eq(U_InputSelectors.get_active_device_type(store.get_state()), M_InputDeviceManager.DeviceType.GAMEPAD,
		"Gamepad input should take over active device on mobile")
	assert_false(controls.visible, "Touch controls should hide after gamepad takeover")

	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2(16.0, 16.0)
	input_manager._input(touch)
	await _await_state_update(store)

	assert_eq(U_InputSelectors.get_active_device_type(store.get_state()), M_InputDeviceManager.DeviceType.TOUCHSCREEN,
		"A real touch event should switch active device back to touchscreen")
	assert_true(controls.visible, "Touch controls should reappear after real touch input")

func test_touchscreen_system_does_not_dispatch_or_process_when_navigation_blocks_gameplay() -> void:
	var ctx := await _setup_environment()
	var store: M_StateStore = ctx["store"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_state_update(store)

	var joystick: UI_VirtualJoystick = ctx["joystick"]
	var manager: M_ECSManager = ctx["ecs_manager"]
	var component: C_InputComponent = ctx["component"]

	store.dispatch(U_NavigationActions.open_pause())
	await _await_state_update(store)
	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))
	manager._physics_process(0.016)
	assert_vector_almost_eq(U_InputSelectors.get_move_input(store.get_state()), Vector2.ZERO, 0.001,
		"TouchscreenSystem should not dispatch move input while overlays block gameplay")
	assert_vector_almost_eq(component.move_vector, Vector2.ZERO, 0.001,
		"TouchscreenSystem should not update components while overlays block gameplay")

	store.dispatch(U_NavigationActions.close_pause())
	store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("main_menu")))
	await _await_state_update(store)
	_press_joystick(joystick, Vector2.ZERO, Vector2(0.0, -joystick.joystick_radius))
	manager._physics_process(0.016)
	assert_vector_almost_eq(U_InputSelectors.get_move_input(store.get_state()), Vector2.ZERO, 0.001,
		"TouchscreenSystem should not dispatch move input outside gameplay shell")
	assert_vector_almost_eq(component.move_vector, Vector2.ZERO, 0.001,
		"TouchscreenSystem should not update components outside gameplay shell")

	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	store.dispatch(U_SceneActions.transition_started(StringName("demo_room"), "fade"))
	await _await_state_update(store)
	_press_joystick(joystick, Vector2.ZERO, Vector2(-joystick.joystick_radius, 0.0))
	manager._physics_process(0.016)
	assert_vector_almost_eq(U_InputSelectors.get_move_input(store.get_state()), Vector2.ZERO, 0.001,
		"TouchscreenSystem should not dispatch move input during scene transitions")
	assert_vector_almost_eq(component.move_vector, Vector2.ZERO, 0.001,
		"TouchscreenSystem should not update components during scene transitions")

func test_virtual_control_positions_persist_via_state_handoff() -> void:
	var store: M_StateStore = await _create_state_store()
	var controls: UI_MobileControls = await _create_controls()
	var joystick: UI_VirtualJoystick = controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick
	assert_not_null(joystick)
	var jump_button: UI_VirtualButton = _find_button(controls.get_buttons(), StringName("jump"))
	assert_not_null(jump_button)

	var custom_joystick := Vector2(180, 320)
	var custom_jump := Vector2(640, 410)

	store.dispatch(U_InputActions.save_virtual_control_position("virtual_joystick", custom_joystick))
	store.dispatch(U_InputActions.save_virtual_control_position("jump", custom_jump))
	await _await_frames(1)

	var saved_settings: Dictionary = U_InputSelectors.get_touchscreen_settings(store.get_state())
	var saved_custom_positions: Dictionary = saved_settings.get("custom_button_positions", {})
	assert_vector_almost_eq(saved_settings.get("custom_joystick_position", Vector2.ZERO), custom_joystick, 0.01,
		"Custom joystick position should persist in state before handoff")
	var saved_jump_position: Variant = saved_custom_positions.get("jump")
	assert_true(saved_jump_position is Vector2, "Jump button position should be stored as Vector2 in state")
	assert_vector_almost_eq(saved_jump_position, custom_jump, 0.01,
		"Jump button position should persist in state before handoff")

	store.call("_preserve_to_handoff")
	await _await_frames(1)

	controls.queue_free()
	store.queue_free()
	await _await_frames(2)

	await _create_state_store()
	var restored_controls: UI_MobileControls = await _create_controls()
	var restored_joystick: UI_VirtualJoystick = restored_controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick
	var restored_jump: UI_VirtualButton = _find_button(restored_controls.get_buttons(), StringName("jump"))
	var viewport_size: Vector2 = restored_controls.get_viewport().get_visible_rect().size

	assert_not_null(restored_joystick, "Restored MobileControls should have a joystick instance")
	assert_not_null(restored_jump, "Restored MobileControls should rebuild jump button")
	var clamped_restored_joystick := _expected_clamped_position(custom_joystick, restored_joystick, viewport_size)
	var clamped_restored_jump := _expected_clamped_position(custom_jump, restored_jump, viewport_size)
	assert_vector_almost_eq(restored_joystick.position, clamped_restored_joystick, 0.01,
		"Joystick position should restore from saved touchscreen settings (clamped to viewport)")
	assert_vector_almost_eq(restored_jump.position, clamped_restored_jump, 0.01,
		"Button position should restore from saved touchscreen settings (clamped to viewport)")

func test_custom_control_positions_clamp_inside_portrait_viewport() -> void:
	var store: M_StateStore = await _create_state_store()
	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	await _await_state_update(store)

	var controls: UI_MobileControls = await _create_controls()
	var joystick: UI_VirtualJoystick = controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick
	var jump_button: UI_VirtualButton = _find_button(controls.get_buttons(), StringName("jump"))
	assert_not_null(joystick)
	assert_not_null(jump_button)

	var portrait_size := Vector2(360, 640)
	var oversized_joystick := Vector2(500, 800)
	var oversized_jump := Vector2(480, 760)

	store.dispatch(U_InputActions.save_virtual_control_position("virtual_joystick", oversized_joystick))
	store.dispatch(U_InputActions.save_virtual_control_position("jump", oversized_jump))
	await _await_state_update(store)
	controls.force_apply_positions(store.get_state(), false)
	controls.call("_clamp_all_controls_to_rect", Rect2(Vector2.ZERO, portrait_size))

	assert_vector_almost_eq(
		joystick.position,
		_expected_clamped_position(oversized_joystick, joystick, portrait_size),
		0.01,
		"Joystick should clamp into portrait viewport bounds"
	)
	assert_vector_almost_eq(
		jump_button.position,
		_expected_clamped_position(oversized_jump, jump_button, portrait_size),
		0.01,
		"Jump button should clamp into portrait viewport bounds"
	)

func test_default_control_positions_do_not_overlap_in_portrait_viewport() -> void:
	var store: M_StateStore = await _create_state_store()
	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	await _await_state_update(store)

	var controls: UI_MobileControls = await _create_controls()
	var portrait_size := Vector2(360, 640)
	controls.force_apply_positions(store.get_state(), false)
	controls.call("_clamp_all_controls_to_rect", Rect2(Vector2.ZERO, portrait_size))

	var joystick: UI_VirtualJoystick = controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick
	assert_not_null(joystick, "Portrait controls should include the joystick")
	var positioned_controls: Array[Control] = [joystick]
	for button in controls.get_buttons():
		if button is Control:
			positioned_controls.append(button as Control)

	for control in positioned_controls:
		assert_lte(control.position.x + (control.size.x * control.scale.x), portrait_size.x + 0.01,
			"%s should fit horizontally in portrait" % control.name)
		assert_lte(control.position.y + (control.size.y * control.scale.y), portrait_size.y + 0.01,
			"%s should fit vertically in portrait" % control.name)

	for i in positioned_controls.size():
		for j in range(i + 1, positioned_controls.size()):
			assert_false(
				positioned_controls[i].get_global_rect().intersects(positioned_controls[j].get_global_rect()),
				"%s and %s should not overlap in portrait" % [positioned_controls[i].name, positioned_controls[j].name]
			)

func test_controls_stay_hidden_during_overlays_and_non_gameplay_shells() -> void:
	var ctx := await _setup_environment()
	var store: M_StateStore = ctx["store"]
	var controls: UI_MobileControls = ctx["controls"]

	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_state_update(store)
	assert_true(controls.visible, "Controls should be visible during touchscreen gameplay")

	store.dispatch(U_NavigationActions.open_pause())
	await _await_state_update(store)
	assert_false(controls.visible, "Controls should hide while gameplay overlays are open")

	store.dispatch(U_NavigationActions.close_pause())
	await _await_state_update(store)
	assert_true(controls.visible, "Controls should reappear after gameplay overlay closes")

	store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("main_menu")))
	await _await_state_update(store)
	assert_false(controls.visible, "Controls should stay hidden in non-gameplay shells")

func _setup_environment() -> Dictionary:
	var store := await _create_state_store()
	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	await _await_state_update(store)

	var ecs_manager := M_ECSManager.new()
	add_child_autofree(ecs_manager)
	await _await_frames(2)

	var entity := Node3D.new()
	entity.name = "E_TouchscreenIntegration"
	ecs_manager.add_child(entity)
	autofree(entity)
	await _await_frames(1)

	var component := C_InputComponent.new()
	entity.add_child(component)
	await _await_frames(1)

	var system := S_TouchscreenSystem.new()
	system.force_enable = true
	ecs_manager.add_child(system)
	await _await_frames(2)

	var controls := await _create_controls()
	var joystick := controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick
	var buttons: Array = controls.get_buttons()
	var jump_button := _find_button(buttons, StringName("jump"))

	return {
		"store": store,
		"ecs_manager": ecs_manager,
		"component": component,
		"system": system,
		"controls": controls,
		"joystick": joystick,
		"jump_button": jump_button,
	}

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.scene_initial_state.current_scene_id = StringName("demo_room")
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.debug_initial_state = RS_DebugInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	add_child_autofree(store)
	await _await_frames(2)
	return store

func _create_controls() -> UI_MobileControls:
	var controls := MobileControlsScene.instantiate() as UI_MobileControls
	controls.force_enable = true
	add_child_autofree(controls)
	await _await_frames(2)
	return controls

func _create_input_device_manager() -> M_InputDeviceManager:
	var input_manager := M_InputDeviceManager.new()
	add_child_autofree(input_manager)
	await _await_frames(2)
	return input_manager

func _press_joystick(joystick: UI_VirtualJoystick, start: Vector2, end: Vector2) -> void:
	if joystick == null:
		return
	
	var direction := (end - start).normalized()
	joystick.simulate_input(direction)
	await joystick.get_tree().process_frame

func _press_button(button: UI_VirtualButton) -> void:
	if button == null:
		return
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = button.get_global_rect().position + (button.get_global_rect().size * 0.5)
	button._input(touch)

func _find_button(buttons: Array, action: StringName) -> UI_VirtualButton:
	for button in buttons:
		if button is UI_VirtualButton and (button as UI_VirtualButton).action == action:
			return button as UI_VirtualButton
	return null

func assert_vector_almost_eq(a: Vector2, b: Vector2, tolerance: float, message: String = "") -> void:
	assert_almost_eq(a.x, b.x, tolerance, message + " (x)")
	assert_almost_eq(a.y, b.y, tolerance, message + " (y)")

func _expected_clamped_position(target: Vector2, control: Control, viewport_size: Vector2) -> Vector2:
	if control == null:
		return target
	var scaled_size: Vector2 = control.size * control.scale
	return Vector2(
		clampf(target.x, 0.0, max(viewport_size.x - scaled_size.x, 0.0)),
		clampf(target.y, 0.0, max(viewport_size.y - scaled_size.y, 0.0))
	)

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _await_state_update(_store: M_StateStore) -> void:
	# Subscriptions fire synchronously during dispatch, so just wait one frame for rendering
	await get_tree().process_frame
