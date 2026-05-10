extends RefCounted
class_name U_AppSelectors

## Pure selectors for app lifecycle state.

static func is_backgrounded(state: Dictionary) -> bool:
	var app := _get_app_slice(state)
	return bool(app.get("is_backgrounded", false))

static func is_focused(state: Dictionary) -> bool:
	var app := _get_app_slice(state)
	return bool(app.get("is_focused", true))

static func _get_app_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var slice: Variant = state.get("app", null)
	if slice is Dictionary:
		return slice as Dictionary
	if state.has("is_backgrounded") or state.has("is_focused"):
		return state
	return {}
