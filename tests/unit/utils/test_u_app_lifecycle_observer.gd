extends GutTest

const OBSERVER_SCRIPT := preload("res://scripts/core/utils/lifecycle/u_app_lifecycle_observer.gd")
const APP_ACTIONS := preload("res://scripts/core/state/actions/u_app_actions.gd")

var _observer: Node
var _dispatched_actions: Array[Dictionary] = []
var _input_events: Array[InputEvent] = []

func before_each() -> void:
	_dispatched_actions.clear()
	_input_events.clear()
	_observer = OBSERVER_SCRIPT.new()
	_observer.set_state_dispatcher(_capture_action)
	_observer.set_input_dispatcher(_capture_input_event)
	add_child_autofree(_observer)

func after_each() -> void:
	_dispatched_actions.clear()
	_input_events.clear()
	_observer = null

func test_application_paused_dispatches_backgrounded() -> void:
	_observer._notification(NOTIFICATION_APPLICATION_PAUSED)

	assert_eq(_dispatched_actions.size(), 1)
	assert_eq(_dispatched_actions[0].get("type"), APP_ACTIONS.ACTION_APP_BACKGROUNDED)
	assert_eq(_input_events.size(), 0)

func test_application_resumed_dispatches_foregrounded() -> void:
	_observer._notification(NOTIFICATION_APPLICATION_RESUMED)

	assert_eq(_dispatched_actions.size(), 1)
	assert_eq(_dispatched_actions[0].get("type"), APP_ACTIONS.ACTION_APP_FOREGROUNDED)
	assert_eq(_input_events.size(), 0)

func test_focus_out_dispatches_focus_lost() -> void:
	_observer._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)

	assert_eq(_dispatched_actions.size(), 1)
	assert_eq(_dispatched_actions[0].get("type"), APP_ACTIONS.ACTION_APP_FOCUS_LOST)
	assert_eq(_input_events.size(), 0)

func test_focus_in_dispatches_focus_gained() -> void:
	_observer._notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)

	assert_eq(_dispatched_actions.size(), 1)
	assert_eq(_dispatched_actions[0].get("type"), APP_ACTIONS.ACTION_APP_FOCUS_GAINED)
	assert_eq(_input_events.size(), 0)

func test_back_request_emits_ui_cancel_input_action() -> void:
	_observer._notification(NOTIFICATION_WM_GO_BACK_REQUEST)

	assert_eq(_dispatched_actions.size(), 0)
	assert_eq(_input_events.size(), 1)
	var event := _input_events[0] as InputEventAction
	assert_not_null(event)
	assert_eq(event.action, StringName("ui_cancel"))
	assert_true(event.pressed)

func test_unrelated_notification_does_not_dispatch() -> void:
	_observer._notification(NOTIFICATION_READY)

	assert_eq(_dispatched_actions.size(), 0)
	assert_eq(_input_events.size(), 0)

func _capture_action(action: Dictionary) -> void:
	_dispatched_actions.append(action.duplicate(true))

func _capture_input_event(event: InputEvent) -> void:
	_input_events.append(event)
