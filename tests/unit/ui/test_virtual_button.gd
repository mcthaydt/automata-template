extends GutTest

const VirtualButtonScriptPath := "res://scripts/core/ui/hud/ui_virtual_button.gd"
const ACTION_TYPE_TAP := 0
const ACTION_TYPE_HOLD := 1

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_press_and_release_toggle_state_and_signals() -> void:
	var button := await _create_button()
	var pressed_count: Array = [0]
	var released_count: Array = [0]
	button.button_pressed.connect(func(_action: StringName) -> void:
		pressed_count[0] += 1
	)
	button.button_released.connect(func(_action: StringName) -> void:
		released_count[0] += 1
	)

	var press_event := _make_touch_event(0, _point_inside(button), true)
	button._input(press_event)
	assert_true(button.is_pressed(), "Button should be pressed after touch inside bounds")
	assert_eq(pressed_count[0], 1, "Hold mode should emit press signal immediately")

	var release_event := _make_touch_event(0, press_event.position, false)
	button._input(release_event)
	assert_false(button.is_pressed(), "Button should reset after release")
	assert_eq(released_count[0], 1, "Release signal should fire once")

func test_default_touch_target_is_large_enough_for_mobile() -> void:
	var button := await _create_button()
	assert_true(button.size.x >= 80.0, "Virtual button touch target should be visibly larger than the old 72px default")
	assert_true(button.size.y >= 80.0, "Virtual button touch target should be visibly larger than the old 72px default")

func test_release_requires_matching_touch_id() -> void:
	var button := await _create_button()
	var release_calls: Array = [0]
	button.button_released.connect(func(_action: StringName) -> void:
		release_calls[0] += 1
	)

	button._input(_make_touch_event(1, _point_inside(button), true))
	assert_true(button.is_pressed(), "Primary touch should press the button")

	var wrong_release := _make_touch_event(2, Vector2.ZERO, false)
	button._input(wrong_release)
	assert_true(button.is_pressed(), "Mismatched touch ID should not release the button")
	assert_eq(release_calls[0], 0, "No release signal for mismatched touch ID")

	var correct_release := _make_touch_event(1, wrong_release.position, false)
	button._input(correct_release)
	assert_false(button.is_pressed(), "Matching touch ID should release the button")
	assert_eq(release_calls[0], 1, "Release signal should fire once for matching ID")

func test_drag_outside_cancels_press_and_emits_release() -> void:
	var button := await _create_button()
	var release_calls: Array = [0]
	button.button_released.connect(func(_action: StringName) -> void:
		release_calls[0] += 1
	)

	var press_event := _make_touch_event(3, _point_inside(button), true)
	button._input(press_event)
	assert_true(button.is_pressed(), "Button should start pressed")

	var drag := _make_drag_event(3, _point_outside(button))
	button._input(drag)
	assert_false(button.is_pressed(), "Drag outside bounds should cancel the press")
	assert_eq(release_calls[0], 1, "Drag-out should emit release signal")

func test_returning_inside_after_drag_outside_requires_new_press() -> void:
	var button := await _create_button()
	var press_event := _make_touch_event(4, _point_inside(button), true)
	button._input(press_event)
	assert_true(button.is_pressed())

	var drag_out := _make_drag_event(4, _point_outside(button))
	button._input(drag_out)
	assert_false(button.is_pressed(), "Drag-out should cancel the press")

	var drag_back := _make_drag_event(4, _point_inside(button))
	button._input(drag_back)
	assert_false(button.is_pressed(), "Returning inside without lifting should not re-press the button")

func test_tap_mode_emits_press_on_release_only() -> void:
	var button := await _create_button(func(instance: Control) -> void:
		instance.set("action_type", ACTION_TYPE_TAP)
	)
	var press_calls: Array = [0]
	var release_calls: Array = [0]
	button.button_pressed.connect(func(_action: StringName) -> void:
		press_calls[0] += 1
	)
	button.button_released.connect(func(_action: StringName) -> void:
		release_calls[0] += 1
	)

	var press_event := _make_touch_event(6, _point_inside(button), true)
	button._input(press_event)
	assert_true(button.is_pressed(), "Tap mode should still track pressed state")
	assert_eq(press_calls[0], 0, "Tap mode should not emit pressed signal until release")

	var release_event := _make_touch_event(6, press_event.position, false)
	button._input(release_event)
	assert_false(button.is_pressed())
	assert_eq(press_calls[0], 1, "Tap mode should emit pressed signal on release")
	assert_eq(release_calls[0], 1, "Release signal should still fire once")

func test_hold_mode_emits_press_on_touch_and_release_on_lift() -> void:
	var button := await _create_button()
	button.set("action_type", ACTION_TYPE_HOLD)

	var press_calls: Array = [0]
	var release_calls: Array = [0]
	button.button_pressed.connect(func(_action: StringName) -> void:
		press_calls[0] += 1
	)
	button.button_released.connect(func(_action: StringName) -> void:
		release_calls[0] += 1
	)

	var press_event := _make_touch_event(7, _point_inside(button), true)
	button._input(press_event)
	assert_true(button.is_pressed())
	assert_eq(press_calls[0], 1, "Hold mode should emit pressed signal immediately")

	var release_event := _make_touch_event(7, press_event.position, false)
	button._input(release_event)
	assert_false(button.is_pressed())
	assert_eq(release_calls[0], 1, "Hold mode releases exactly once")

func test_second_touch_is_ignored_while_primary_active() -> void:
	var button := await _create_button()
	var press_calls: Array = [0]
	button.button_pressed.connect(func(_action: StringName) -> void:
		press_calls[0] += 1
	)

	var primary := _make_touch_event(8, _point_inside(button), true)
	button._input(primary)
	assert_true(button.is_pressed())
	assert_eq(press_calls[0], 1, "Primary press should fire once")

	var secondary := _make_touch_event(9, _point_inside(button), true)
	button._input(secondary)
	assert_eq(press_calls[0], 1, "Secondary press should be ignored while first is active")

	var secondary_release := _make_touch_event(9, secondary.position, false)
	button._input(secondary_release)
	assert_true(button.is_pressed(), "Releasing ignored touch should not affect button state")

	var primary_release := _make_touch_event(8, primary.position, false)
	button._input(primary_release)
	assert_false(button.is_pressed(), "Primary release should deactivate button")

func test_touch_id_resets_after_release() -> void:
	var button := await _create_button()
	var press_calls: Array = [0]
	button.button_pressed.connect(func(_action: StringName) -> void:
		press_calls[0] += 1
	)

	var first_press := _make_touch_event(10, _point_inside(button), true)
	button._input(first_press)
	var first_release := _make_touch_event(10, first_press.position, false)
	button._input(first_release)
	assert_false(button.is_pressed())
	assert_eq(press_calls[0], 1, "First tap should emit once")

	var second_press := _make_touch_event(10, _point_inside(button), true)
	button._input(second_press)
	assert_true(button.is_pressed(), "Button should accept the same touch ID after release")
	assert_eq(press_calls[0], 2, "Second press should emit again")

func test_reposition_mode_updates_position_and_dispatches_save() -> void:
	var store := await _create_state_store()
	var button := await _create_button(func(instance: Control) -> void:
		instance.set("can_reposition", true)
		instance.set("control_name", StringName("btn_jump"))
		instance.position = Vector2(10, 10)
	)

	var press := _make_touch_event(11, _point_inside(button), true)
	button._input(press)
	assert_false(button.is_pressed(), "Reposition mode should not trigger pressed state")

	var drag := _make_drag_event(11, _point_inside(button) + Vector2(80, 60))
	button._input(drag)
	assert_false(button.position.is_equal_approx(Vector2(10, 10)), "Position should change while dragging in reposition mode")

	var release := _make_touch_event(11, drag.position, false)
	button._input(release)
	assert_eq(store.dispatched_actions.size(), 1, "Reposition release should dispatch save action")
	var action: Dictionary = store.dispatched_actions[0]
	assert_eq(StringName(action.get("type", StringName())), StringName("input/save_virtual_control_position"))
	var payload: Dictionary = action.get("payload", {})
	assert_eq(payload.get("control_name", ""), "btn_jump")
	assert_vector_almost_eq(payload.get("position", Vector2.ZERO), button.position, 0.001,
		"Saved position should match button position after drag")

func test_reposition_mode_ignores_press_signals() -> void:
	var button := await _create_button(func(instance: Control) -> void:
		instance.set("can_reposition", true)
	)
	var press_calls: Array = [0]
	var release_calls: Array = [0]
	button.button_pressed.connect(func(_action: StringName) -> void:
		press_calls[0] += 1
	)
	button.button_released.connect(func(_action: StringName) -> void:
		release_calls[0] += 1
	)

	var press := _make_touch_event(12, _point_inside(button), true)
	button._input(press)
	assert_false(button.is_pressed(), "Reposition press should not mark button as pressed")

	var drag := _make_drag_event(12, _point_inside(button) + Vector2(40, 40))
	button._input(drag)

	var release := _make_touch_event(12, drag.position, false)
	button._input(release)
	assert_eq(press_calls[0], 0, "Repositioning should not emit pressed signal")
	assert_eq(release_calls[0], 0, "Repositioning should not emit released signal")

func test_visual_feedback_updates_on_press_and_release() -> void:
	var button := await _create_button()
	var default_modulate := button.modulate
	var default_scale := button.scale

	var press := _make_touch_event(13, _point_inside(button), true)
	button._input(press)
	assert_false(button.modulate.is_equal_approx(default_modulate), "Press should change modulate")
	assert_false(button.scale.is_equal_approx(default_scale), "Press should change scale")

	var release := _make_touch_event(13, press.position, false)
	button._input(release)
	assert_color_eq(button.modulate, Color(1, 1, 1, 1), "Release should restore default modulate")
	assert_vector_almost_eq(button.scale, Vector2.ONE, 0.001, "Release should restore default scale")

func test_visual_feedback_preserves_configured_scale_after_release() -> void:
	var button := await _create_button()
	button.scale = Vector2.ONE * 1.3
	var configured_scale := button.scale

	var press := _make_touch_event(14, _point_inside(button), true)
	button._input(press)
	assert_false(button.scale.is_equal_approx(configured_scale), "Press should still provide scale feedback")

	var release := _make_touch_event(14, press.position, false)
	button._input(release)
	assert_vector_almost_eq(button.scale, configured_scale, 0.001, "Release should restore configured control size")

func test_pause_button_toggles_navigation_pause() -> void:
	var store := await _create_state_store()
	store.dispatch(U_NavigationActions.start_game(StringName("demo_room")))
	var button := await _create_button(func(instance: Control) -> void:
		instance.set("action", StringName("pause"))
	)

	button.call("_bridge_pause_pressed")
	await _await_frames(1)
	var nav := store.get_slice(StringName("navigation"))
	assert_true(U_NavigationSelectors.is_paused(nav), "Pause button should open pause overlay")

	button.call("_bridge_pause_pressed")
	await _await_frames(1)
	nav = store.get_slice(StringName("navigation"))
	assert_false(U_NavigationSelectors.is_paused(nav), "Second press should close pause overlay")

func _create_button(configure: Callable = Callable()) -> Control:
	var script: GDScript = load(VirtualButtonScriptPath) as GDScript
	assert_not_null(script, "VirtualButton script should load")
	var button: Control = script.new() as Control
	assert_not_null(button, "VirtualButton should extend Control")
	if configure != Callable() and configure.is_valid():
		configure.call(button)
	add_child_autofree(button)
	await _await_frames(1)
	var control := button as Control
	if control.size.is_zero_approx():
		control.custom_minimum_size = Vector2(72, 72)
		control.size = Vector2(72, 72)
	return control

func _make_touch_event(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event

func _make_drag_event(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event

func _point_inside(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func _point_outside(control: Control) -> Vector2:
	var rect := control.get_global_rect()
	return rect.position - Vector2(10, 10)

func assert_vector_almost_eq(a: Vector2, b: Vector2, tolerance: float, message: String = "") -> void:
	assert_almost_eq(a.x, b.x, tolerance, message + " (x)")
	assert_almost_eq(a.y, b.y, tolerance, message + " (y)")

func assert_color_eq(a: Color, b: Color, message: String = "") -> void:
	assert_almost_eq(a.r, b.r, 0.001, message + " (r)")
	assert_almost_eq(a.g, b.g, 0.001, message + " (g)")
	assert_almost_eq(a.b, b.b, 0.001, message + " (b)")
	assert_almost_eq(a.a, b.a, 0.001, message + " (a)")

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_state_store() -> TestStateStore:
	var store := TestStateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	var nav_initial := RS_NavigationInitialState.new()
	nav_initial.shell = StringName("gameplay")
	nav_initial.base_scene_id = StringName("")
	store.navigation_initial_state = nav_initial
	add_child_autofree(store)
	await _await_frames(2)
	return store

class TestStateStore extends M_StateStore:
	var dispatched_actions: Array = []

	func dispatch(action: Dictionary) -> void:
		dispatched_actions.append(action.duplicate(true))
		super.dispatch(action)
