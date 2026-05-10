extends Node
class_name U_AppLifecycleObserver

## Thin bridge from Godot app/window lifecycle notifications into app actions.
##
## This node owns no lifecycle side effects. Managers react to Redux state or
## input events emitted by this observer.

const APP_ACTIONS := preload("res://scripts/core/state/actions/u_app_actions.gd")
const STATE_UTILS := preload("res://scripts/core/state/utils/u_state_utils.gd")

var _state_dispatcher: Callable = Callable()
var _input_dispatcher: Callable = Callable()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _state_dispatcher.is_valid():
		call_deferred("_bind_state_store_dispatcher")

func set_state_dispatcher(dispatcher: Callable) -> void:
	_state_dispatcher = dispatcher

func set_input_dispatcher(dispatcher: Callable) -> void:
	_input_dispatcher = dispatcher

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_dispatch_action(APP_ACTIONS.app_backgrounded())
		NOTIFICATION_APPLICATION_RESUMED:
			_dispatch_action(APP_ACTIONS.app_foregrounded())
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_dispatch_action(APP_ACTIONS.app_focus_lost())
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_dispatch_action(APP_ACTIONS.app_focus_gained())
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_emit_ui_cancel()

func _bind_state_store_dispatcher() -> void:
	if _state_dispatcher.is_valid():
		return
	var store := STATE_UTILS.try_get_store(self)
	if store != null and is_instance_valid(store):
		_state_dispatcher = Callable(store, "dispatch")

func _dispatch_action(action: Dictionary) -> void:
	if not _state_dispatcher.is_valid():
		_bind_state_store_dispatcher()
	if _state_dispatcher.is_valid():
		_state_dispatcher.call(action)

func _emit_ui_cancel() -> void:
	var event := InputEventAction.new()
	event.action = StringName("ui_cancel")
	event.pressed = true
	if _input_dispatcher.is_valid():
		_input_dispatcher.call(event)
		return
	Input.parse_input_event(event)
