class_name U_SDDirectiveBuilder
extends RefCounted

const RS_BEAT_DEFINITION := preload("res://scripts/core/resources/scene_director/rs_beat_definition.gd")
const RS_SCENE_DIRECTIVE := preload("res://scripts/core/resources/scene_director/rs_scene_directive.gd")
const RS_EFFECT_PUBLISH_EVENT := preload("res://scripts/core/resources/qb/effects/rs_effect_publish_event.gd")

var _directive_id: StringName = StringName("")
var _target_scene_id: StringName = StringName("")
var _priority: int = 0
var _directive_description: String = ""
var _selection_conditions: Array = []
var _beats: Array = []
var _current: Dictionary = {}


func _init(directive_id: StringName) -> void:
	_directive_id = directive_id


func target(scene_id: StringName) -> U_SDDirectiveBuilder:
	_target_scene_id = scene_id
	return self


func priority(value: int) -> U_SDDirectiveBuilder:
	_priority = value
	return self


func selection(conditions: Array) -> U_SDDirectiveBuilder:
	_selection_conditions = conditions
	return self


func desc(text: String) -> U_SDDirectiveBuilder:
	if _current.is_empty():
		_directive_description = text
	else:
		_current["description"] = text
	return self


func beat(beat_id: StringName) -> U_SDDirectiveBuilder:
	_flush_current()
	_current = _new_beat_state(beat_id)
	return self


func instant() -> U_SDDirectiveBuilder:
	_current["wait_mode"] = RS_BEAT_DEFINITION.WaitMode.INSTANT
	_current["duration"] = 0.0
	return self


func timed(duration: float) -> U_SDDirectiveBuilder:
	_current["wait_mode"] = RS_BEAT_DEFINITION.WaitMode.TIMED
	_current["duration"] = duration
	return self


func on_signal(event: StringName) -> U_SDDirectiveBuilder:
	_current["wait_mode"] = RS_BEAT_DEFINITION.WaitMode.SIGNAL
	_current["wait_event"] = event
	return self


func publish(event_name: StringName, payload: Dictionary = {}, inject_entity_id: bool = false) -> U_SDDirectiveBuilder:
	var effect := RS_EFFECT_PUBLISH_EVENT.new()
	effect.event_name = event_name
	effect.payload = payload.duplicate(true)
	effect.inject_entity_id = inject_entity_id
	(_current["effects"] as Array).append(effect)
	return self


func effect(e: Resource) -> U_SDDirectiveBuilder:
	(_current["effects"] as Array).append(e)
	return self


func precondition(c: Resource) -> U_SDDirectiveBuilder:
	(_current["preconditions"] as Array).append(c)
	return self


func then(beat_id: StringName) -> U_SDDirectiveBuilder:
	_current["next_beat_id"] = beat_id
	return self


func on_failure(beat_id: StringName) -> U_SDDirectiveBuilder:
	_current["next_beat_id_on_failure"] = beat_id
	return self


func parallel(lane_ids: Array, join_beat_id: StringName = StringName("")) -> U_SDDirectiveBuilder:
	_current["parallel_beat_ids"] = lane_ids
	_current["parallel_join_beat_id"] = join_beat_id
	return self


func build() -> RS_SceneDirective:
	_flush_current()

	var d := RS_SCENE_DIRECTIVE.new()
	d.directive_id = _directive_id
	d.target_scene_id = _target_scene_id
	d.priority = _priority
	d.description = _directive_description

	d.set("_selection_conditions", d.call("_sanitize_conditions", _selection_conditions))
	d.set("_beats", d.call("_sanitize_beats", _beats))
	return d


func _flush_current() -> void:
	if _current.is_empty():
		return
	_beats.append(_materialize_beat(_current))
	_current = {}


func _new_beat_state(beat_id: StringName) -> Dictionary:
	return {
		"beat_id": beat_id,
		"wait_mode": RS_BEAT_DEFINITION.WaitMode.INSTANT,
		"duration": 0.0,
		"wait_event": StringName(""),
		"description": "",
		"preconditions": [],
		"effects": [],
		"next_beat_id": StringName(""),
		"next_beat_id_on_failure": StringName(""),
		"parallel_beat_ids": [],
		"parallel_join_beat_id": StringName(""),
	}


func _materialize_beat(data: Dictionary) -> RS_BeatDefinition:
	var b := RS_BEAT_DEFINITION.new()
	b.beat_id = data["beat_id"]
	b.wait_mode = data["wait_mode"]
	b.duration = data["duration"]
	b.wait_event = data["wait_event"]
	b.description = data["description"]
	b.next_beat_id = data["next_beat_id"]
	b.next_beat_id_on_failure = data["next_beat_id_on_failure"]

	var typed_parallel_ids: Array[StringName] = []
	for id in data["parallel_beat_ids"] as Array:
		if id is StringName:
			typed_parallel_ids.append(id as StringName)
	b.set("parallel_beat_ids", typed_parallel_ids)
	b.parallel_join_beat_id = data["parallel_join_beat_id"]

	b.set("_preconditions", b.call("_sanitize_conditions", data["preconditions"]))
	b.set("_effects", b.call("_sanitize_effects", data["effects"]))
	return b
