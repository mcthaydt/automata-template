extends RefCounted
class_name U_InputRebindUtils

class ValidationResult extends RefCounted:
	var valid: bool = true
	var error: String = ""
	var conflict_action: StringName = StringName()

static func format_event_label(event: InputEvent) -> String:
	return U_InputEventDisplay.format_event_label(event)

static func format_binding_label(binding_text: String) -> String:
	var trimmed := binding_text.strip_edges()
	if trimmed.begins_with("Key "):
		trimmed = trimmed.substr(4, trimmed.length() - 4)
	return trimmed

static func validate_rebind(
	action: StringName,
	event: InputEvent,
	settings: RS_RebindSettings,
	replace_existing: bool = true,
	profile: RS_InputProfile = null,
	excluded_actions: Array = []
) -> ValidationResult:
	var result := ValidationResult.new()
	if action == StringName():
		result.valid = false
		result.error = "Action name is required."
		return result

	if event == null:
		result.valid = false
		result.error = "Input event is required."
		return result

	if settings == null:
		settings = RS_RebindSettings.new()

	if is_reserved_action(action, settings):
		result.valid = false
		result.error = "Cannot rebind reserved action."
		return result

	var conflict := get_conflicting_action(event, profile, action, excluded_actions)
	if conflict != StringName() and conflict != action:
		if is_reserved_action(conflict, settings):
			result.valid = false
			result.error = "Cannot reassign input from reserved action."
			return result

		if settings.allow_conflicts:
			result.conflict_action = StringName()
		elif settings.require_confirmation:
			result.conflict_action = conflict
		else:
			result.valid = false
			result.error = "Input already bound to %s." % String(conflict)

	if settings.max_events_per_action > 0 and not replace_existing:
		var existing_events := InputMap.action_get_events(action)
		var already_present := false
		for existing in existing_events:
			if _events_match(existing, event):
				already_present = true
				break
		if not already_present and existing_events.size() >= settings.max_events_per_action:
			result.valid = false
			result.error = "Maximum bindings reached for action."
			return result

	return result

static func rebind_action(
	action: StringName,
	event: InputEvent,
	profile: RS_InputProfile = null,
	conflict_action: StringName = StringName(),
	replace_existing: bool = true
) -> bool:
	if action == StringName() or event == null:
		return false

	if not InputMap.has_action(action):
		return false

	var event_copy := event.duplicate(true)

	if conflict_action != StringName() and InputMap.has_action(conflict_action):
		_remove_event_from_action(conflict_action, event_copy)
		if profile:
			var conflict_events := profile.get_events_for_action(conflict_action)
			var filtered: Array[InputEvent] = []
			for existing in conflict_events:
				if not _events_match(existing, event_copy):
					filtered.append(existing.duplicate(true))
			profile.set_events_for_action(conflict_action, filtered)

	if replace_existing:
		InputMap.action_erase_events(action)
	else:
		_remove_event_from_action(action, event_copy)
	InputMap.action_add_event(action, event_copy)

	if profile:
		var new_events: Array[InputEvent] = []
		if not replace_existing:
			for existing_event in profile.get_events_for_action(action):
				if existing_event is InputEvent and not _events_match(existing_event, event_copy):
					new_events.append(existing_event.duplicate(true))
		new_events.append(event_copy.duplicate(true))
		profile.set_events_for_action(action, new_events)

	return true

static func get_conflicting_action(
	event: InputEvent,
	profile: RS_InputProfile = null,
	ignore_action: StringName = StringName(),
	excluded_actions: Array = []
) -> StringName:
	if event == null:
		return StringName()

	var prioritized_matches: Array[StringName] = []
	var fallback_matches: Array[StringName] = []
	var actions := InputMap.get_actions()
	for i in range(actions.size() - 1, -1, -1):
		var action := actions[i]
		var action_name := StringName(action)
		if action_name == ignore_action:
			continue
		# Skip excluded actions (like built-in ui_ actions not shown in rebinding menu)
		var action_str := String(action_name)
		if action_str in excluded_actions:
			continue
		for existing_event in InputMap.action_get_events(action_name):
			if _events_match(existing_event, event):
				if profile != null and profile.has_action(action_name):
					return action_name
				if action_str.begins_with("ui_") or action_str.begins_with("editor"):
					fallback_matches.append(action_name)
				else:
					prioritized_matches.append(action_name)
				break

	if not prioritized_matches.is_empty():
		return prioritized_matches[0]
	if not fallback_matches.is_empty():
		return fallback_matches[0]
	return StringName()

static func is_reserved_action(action: StringName, settings: RS_RebindSettings) -> bool:
	if settings == null:
		return false
	return settings.is_reserved(action)

static func event_to_dict(event: InputEvent) -> Dictionary:
	return U_InputEventSerialization.event_to_dict(event)

static func dict_to_event(data: Dictionary) -> InputEvent:
	return U_InputEventSerialization.dict_to_event(data)

static func _remove_event_from_action(action: StringName, event: InputEvent) -> void:
	var retained: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if not _events_match(existing, event):
			retained.append(existing)

	InputMap.action_erase_events(action)
	for retained_event in retained:
		InputMap.action_add_event(action, retained_event)

static func _events_match(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		var key_a := a as InputEventKey
		var key_b := b as InputEventKey
		# Prefer physical keycode when available since project uses physical-only defaults.
		var phys_a := key_a.physical_keycode
		var phys_b := key_b.physical_keycode
		var code_a := key_a.keycode
		var code_b := key_b.keycode
		if phys_a != 0 or phys_b != 0:
			if phys_a != 0 and phys_b != 0 and phys_a == phys_b:
				return true
			if phys_a != 0 and code_b != 0 and phys_a == code_b:
				return true
			if phys_b != 0 and code_a != 0 and phys_b == code_a:
				return true
		if code_a != 0 and code_b != 0:
			return key_a.keycode == key_b.keycode
	return a.is_match(b) and b.is_match(a)

## Returns a texture icon for the given InputEvent, or null if no icon exists.
## Used by UI components to display visual representations of key bindings.
static func get_texture_for_event(event: InputEvent) -> Texture2D:
	return U_InputEventDisplay.get_texture_for_event(event)
