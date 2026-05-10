extends RefCounted
class_name U_AppReducer

## Pure reducer for app lifecycle state.

const APP_ACTIONS := preload("res://scripts/core/state/actions/u_app_actions.gd")
const ACTION_APP_BACKGROUNDED := APP_ACTIONS.ACTION_APP_BACKGROUNDED
const ACTION_APP_FOREGROUNDED := APP_ACTIONS.ACTION_APP_FOREGROUNDED
const ACTION_APP_FOCUS_LOST := APP_ACTIONS.ACTION_APP_FOCUS_LOST
const ACTION_APP_FOCUS_GAINED := APP_ACTIONS.ACTION_APP_FOCUS_GAINED

const DEFAULT_APP_STATE := {
	"is_backgrounded": false,
	"is_focused": true,
}

static func get_default_app_state() -> Dictionary:
	return DEFAULT_APP_STATE.duplicate(true)

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: StringName = action.get("type", StringName())

	match action_type:
		ACTION_APP_BACKGROUNDED:
			return _with_values(state, {"is_backgrounded": true})
		ACTION_APP_FOREGROUNDED:
			return _with_values(state, {"is_backgrounded": false})
		ACTION_APP_FOCUS_LOST:
			return _with_values(state, {"is_focused": false})
		ACTION_APP_FOCUS_GAINED:
			return _with_values(state, {"is_focused": true})
		_:
			return state

static func _with_values(state: Dictionary, updates: Dictionary) -> Dictionary:
	var next := _merge_with_defaults(state)
	for key in updates.keys():
		next[key] = updates[key]
	return next

static func _merge_with_defaults(state: Dictionary) -> Dictionary:
	var merged := get_default_app_state()
	for key in state.keys():
		merged[key] = _deep_copy(state[key])
	return merged

static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
