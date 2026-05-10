extends Resource
class_name RS_RebindSettings

## Rebinding rules and validation toggles.

@export var reserved_actions: Array[StringName] = [
	StringName("pause"),
	StringName("ui_focus_next"),
	StringName("ui_focus_prev"),
]
@export var allow_conflicts: bool = false
@export var require_confirmation: bool = true
@export_range(1, 10) var max_events_per_action: int = 3
@export var warn_on_reserved: bool = true
@export var warning_actions: Array[StringName] = [
	StringName("toggle_debug_overlay"),
	StringName("toggle_color_grading_debug")
]

func is_reserved(action: StringName) -> bool:
	return action in reserved_actions

func should_warn(action: StringName) -> bool:
	return action in warning_actions
