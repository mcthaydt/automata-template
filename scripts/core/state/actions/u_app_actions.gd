extends RefCounted
class_name U_AppActions

## App lifecycle action creators.
##
## These actions represent OS/app focus and background state. Side effects
## should be handled by subscribers, not by the reducer.

const ACTION_APP_BACKGROUNDED := StringName("app/backgrounded")
const ACTION_APP_FOREGROUNDED := StringName("app/foregrounded")
const ACTION_APP_FOCUS_LOST := StringName("app/focus_lost")
const ACTION_APP_FOCUS_GAINED := StringName("app/focus_gained")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_APP_BACKGROUNDED)
	U_ActionRegistry.register_action(ACTION_APP_FOREGROUNDED)
	U_ActionRegistry.register_action(ACTION_APP_FOCUS_LOST)
	U_ActionRegistry.register_action(ACTION_APP_FOCUS_GAINED)

static func app_backgrounded() -> Dictionary:
	return {"type": ACTION_APP_BACKGROUNDED}

static func app_foregrounded() -> Dictionary:
	return {"type": ACTION_APP_FOREGROUNDED}

static func app_focus_lost() -> Dictionary:
	return {"type": ACTION_APP_FOCUS_LOST}

static func app_focus_gained() -> Dictionary:
	return {"type": ACTION_APP_FOCUS_GAINED}
