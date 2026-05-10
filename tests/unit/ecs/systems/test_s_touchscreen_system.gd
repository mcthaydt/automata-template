extends BaseTest

const MobileControlsScene := preload("res://scenes/core/ui/hud/ui_mobile_controls.tscn")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_updates_component_from_virtual_controls() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_frames(1)

	var joystick: UI_VirtualJoystick = context["joystick"]
	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))

	var jump_button: UI_VirtualButton = context["jump_button"]
	_press_button(jump_button)

	var manager: M_ECSManager = context["manager"]
	manager._physics_process(0.016)

	var component: C_InputComponent = context["component"]
	assert_almost_eq(component.move_vector.x, 1.0, 0.01, "Joystick drag should set move_vector")
	assert_true(component.jump_pressed, "Jump button press should set jump_pressed")

	var gameplay_slice := store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var move_input: Vector2 = input_slice.get("move_input", Vector2.ZERO)
	assert_almost_eq(move_input.x, 1.0, 0.01, "Store should receive move input from touchscreen system")
	assert_true(input_slice.get("jump_pressed", false), "Store should receive jump state from touchscreen system")

func test_skips_processing_when_device_not_touchscreen() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.GAMEPAD, 1))
	await _await_frames(1)

	var joystick: UI_VirtualJoystick = context["joystick"]
	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))

	var manager: M_ECSManager = context["manager"]
	manager._physics_process(0.016)

	var component: C_InputComponent = context["component"]
	assert_true(component.move_vector.is_zero_approx(), "Non-touch device should skip touchscreen processing")

	var gameplay_slice := store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var move_input: Vector2 = input_slice.get("move_input", Vector2(5, 5))
	assert_true(move_input.is_zero_approx(), "Store move_input should remain unchanged when inactive device")

func test_emergency_disable_flag_blocks_processing() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	store.dispatch(U_DebugActions.set_disable_touchscreen(true))
	await _await_frames(1)

	var joystick: UI_VirtualJoystick = context["joystick"]
	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))

	var manager: M_ECSManager = context["manager"]
	manager._physics_process(0.016)

	var component: C_InputComponent = context["component"]
	assert_true(component.move_vector.is_zero_approx(), "Emergency flag should prevent touchscreen updates")

	var debug_state := U_DebugSelectors.get_debug_settings(store.get_state())
	assert_true(debug_state.get("disable_touchscreen", false), "Debug flag should be readable from selectors")

func test_double_tap_empty_space_dispatches_one_shot_camera_center() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	var controls: UI_MobileControls = context["controls"]
	var manager: M_ECSManager = context["manager"]

	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_frames(2)

	var tap_position := _get_empty_space_tap_position(controls)
	_tap_mobile_controls(controls, 20, tap_position)
	_tap_mobile_controls(controls, 21, tap_position + Vector2(10.0, 5.0))

	manager._physics_process(0.016)
	var gameplay_slice := store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	assert_true(
		bool(input_slice.get("camera_center_just_pressed", false)),
		"Touchscreen double-tap should dispatch camera_center_just_pressed for one frame"
	)

	manager._physics_process(0.016)
	gameplay_slice = store.get_slice(StringName("gameplay"))
	input_slice = gameplay_slice.get("input", {})
	assert_false(
		bool(input_slice.get("camera_center_just_pressed", false)),
		"camera_center_just_pressed should reset after the consume frame"
	)

func test_drag_look_dispatches_look_input_and_active_flag() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	var controls: UI_MobileControls = context["controls"]
	var manager: M_ECSManager = context["manager"]

	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_frames(2)

	var start := _get_empty_space_tap_position(controls)
	var finish := start + Vector2(18.0, -7.0)
	_drag_mobile_controls(controls, 30, start, finish)

	manager._physics_process(0.016)
	var gameplay_slice := store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var look_input: Vector2 = input_slice.get("look_input", Vector2.ZERO)
	assert_almost_eq(look_input.x, 18.0, 0.001, "Touch drag should dispatch look input X")
	assert_almost_eq(look_input.y, -7.0, 0.001, "Touch drag should dispatch look input Y")
	assert_true(bool(gameplay_slice.get("touch_look_active", false)), "Drag look should set touch_look_active")

	_release_mobile_touch(controls, 30, finish)
	manager._physics_process(0.016)
	gameplay_slice = store.get_slice(StringName("gameplay"))
	assert_false(bool(gameplay_slice.get("touch_look_active", false)), "Touch look flag should reset on release")

func test_drag_look_applies_touchscreen_sensitivity() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	var controls: UI_MobileControls = context["controls"]
	var manager: M_ECSManager = context["manager"]

	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	store.dispatch(U_InputActions.update_touchscreen_settings({
		"look_drag_sensitivity": 1.5,
	}))
	await _await_frames(2)

	var start := _get_empty_space_tap_position(controls)
	var finish := start + Vector2(10.0, 6.0)
	_drag_mobile_controls(controls, 31, start, finish)

	manager._physics_process(0.016)
	var gameplay_slice := store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var look_input: Vector2 = input_slice.get("look_input", Vector2.ZERO)
	assert_almost_eq(look_input.x, 15.0, 0.001, "Sensitivity should scale touch look X")
	assert_almost_eq(look_input.y, 9.0, 0.001, "Sensitivity should scale touch look Y")

func test_drag_look_delta_is_one_shot_per_tick() -> void:
	var context := await _setup_touchscreen_scene()
	autofree_context(context)
	var store: M_StateStore = context["store"]
	var controls: UI_MobileControls = context["controls"]
	var manager: M_ECSManager = context["manager"]

	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	store.dispatch(U_InputActions.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_frames(2)

	var start := _get_empty_space_tap_position(controls)
	var finish := start + Vector2(14.0, 3.0)
	_drag_mobile_controls(controls, 32, start, finish)

	manager._physics_process(0.016)
	var gameplay_slice := store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var first_look: Vector2 = input_slice.get("look_input", Vector2.ZERO)
	assert_false(first_look.is_zero_approx(), "First tick should consume drag look delta")

	manager._physics_process(0.016)
	gameplay_slice = store.get_slice(StringName("gameplay"))
	input_slice = gameplay_slice.get("input", {})
	var second_look: Vector2 = input_slice.get("look_input", Vector2.ONE)
	assert_true(second_look.is_zero_approx(), "Second tick should clear drag look delta")

func _setup_touchscreen_scene() -> Dictionary:
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
	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	await _await_frames(1)

	var manager := M_ECSManager.new()
	add_child_autofree(manager)
	await _await_frames(2)

	var entity := Node3D.new()
	entity.name = "E_TouchscreenPlayer"
	manager.add_child(entity)
	autofree(entity)
	await _await_frames(1)

	var component := C_InputComponent.new()
	entity.add_child(component)
	await _await_frames(1)

	var system := S_TouchscreenSystem.new()
	system.force_enable = true
	manager.add_child(system)
	await _await_frames(2)

	var controls := MobileControlsScene.instantiate()
	controls.force_enable = true
	add_child_autofree(controls)
	await _await_frames(2)

	var joystick := controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick
	var buttons: Array = controls.get_buttons()
	var jump_button := _find_button(buttons, StringName("jump"))

	return {
		"store": store,
		"manager": manager,
		"component": component,
		"system": system,
		"controls": controls,
		"joystick": joystick,
		"jump_button": jump_button,
	}

func _find_button(buttons: Array, action: StringName) -> UI_VirtualButton:
	for button in buttons:
		if button is UI_VirtualButton and (button as UI_VirtualButton).action == action:
			return button as UI_VirtualButton
	return null

func _press_joystick(joystick: UI_VirtualJoystick, start: Vector2, end: Vector2) -> void:
	var vector := (end - start) / joystick.joystick_radius
	joystick.simulate_input(vector.limit_length(1.0))

func _press_button(button: UI_VirtualButton) -> void:
	if button == null:
		return
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = button.get_global_rect().position + (button.get_global_rect().size * 0.5)
	button._input(touch)

func _tap_mobile_controls(controls: UI_MobileControls, touch_id: int, position: Vector2) -> void:
	if controls == null:
		return
	var pressed := InputEventScreenTouch.new()
	pressed.index = touch_id
	pressed.pressed = true
	pressed.position = position
	controls._input(pressed)

	var released := InputEventScreenTouch.new()
	released.index = touch_id
	released.pressed = false
	released.position = position
	controls._input(released)

func _drag_mobile_controls(controls: UI_MobileControls, touch_id: int, start: Vector2, finish: Vector2) -> void:
	if controls == null:
		return
	var pressed := InputEventScreenTouch.new()
	pressed.index = touch_id
	pressed.pressed = true
	pressed.position = start
	controls._input(pressed)

	var drag := InputEventScreenDrag.new()
	drag.index = touch_id
	drag.position = finish
	controls._input(drag)

func _release_mobile_touch(controls: UI_MobileControls, touch_id: int, position: Vector2) -> void:
	if controls == null:
		return
	var released := InputEventScreenTouch.new()
	released.index = touch_id
	released.pressed = false
	released.position = position
	controls._input(released)

func _get_empty_space_tap_position(controls: UI_MobileControls) -> Vector2:
	var viewport_size := controls.get_viewport().get_visible_rect().size
	var candidates := [
		Vector2(viewport_size.x * 0.5, viewport_size.y * 0.2),
		Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5),
		Vector2(viewport_size.x * 0.5, viewport_size.y * 0.75)
	]
	for candidate in candidates:
		if not _is_position_over_controls(controls, candidate):
			return candidate
	return candidates[0]

func _is_position_over_controls(controls: UI_MobileControls, position: Vector2) -> bool:
	var joystick := controls.get_node_or_null("Controls/VirtualJoystick") as Control
	if joystick != null and joystick.get_global_rect().has_point(position):
		return true
	for button in controls.get_buttons():
		var control := button as Control
		if control != null and control.get_global_rect().has_point(position):
			return true
	return false

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
