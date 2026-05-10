class_name U_SDResourceBuilder
extends RefCounted

const RS_BEAT_DEFINITION := preload("res://scripts/core/resources/scene_director/rs_beat_definition.gd")
const RS_SCENE_DIRECTIVE := preload("res://scripts/core/resources/scene_director/rs_scene_directive.gd")
const RS_EFFECT_PUBLISH_EVENT := preload("res://scripts/core/resources/qb/effects/rs_effect_publish_event.gd")


static func beat(
	beat_id: StringName,
	wait_mode: int = RS_BEAT_DEFINITION.WaitMode.INSTANT,
	duration: float = 0.0,
	wait_event: StringName = StringName(""),
	preconditions: Array = [],
	effects: Array = [],
	next_beat_id: StringName = StringName(""),
	next_beat_id_on_failure: StringName = StringName(""),
	parallel_beat_ids: Array = [],
	parallel_join_beat_id: StringName = StringName("")
) -> RS_BeatDefinition:
	var b := RS_BEAT_DEFINITION.new()
	b.beat_id = beat_id
	b.wait_mode = wait_mode if wait_mode in [RS_BEAT_DEFINITION.WaitMode.INSTANT, RS_BEAT_DEFINITION.WaitMode.TIMED, RS_BEAT_DEFINITION.WaitMode.SIGNAL] else RS_BEAT_DEFINITION.WaitMode.INSTANT
	b.duration = duration
	b.wait_event = wait_event
	b.next_beat_id = next_beat_id
	b.next_beat_id_on_failure = next_beat_id_on_failure

	var typed_parallel_ids: Array[StringName] = []
	for id in parallel_beat_ids:
		if id is StringName:
			typed_parallel_ids.append(id as StringName)
	b.set("parallel_beat_ids", typed_parallel_ids)
	b.parallel_join_beat_id = parallel_join_beat_id

	var sanitized_preconditions: Variant = b.call("_sanitize_conditions", preconditions)
	b.set("_preconditions", sanitized_preconditions)
	var sanitized_effects: Variant = b.call("_sanitize_effects", effects)
	b.set("_effects", sanitized_effects)

	return b


static func publish_event(event_name: StringName, payload: Dictionary = {}, inject_entity_id: bool = false) -> RS_EffectPublishEvent:
	var effect := RS_EFFECT_PUBLISH_EVENT.new()
	effect.event_name = event_name
	effect.payload = payload.duplicate(true)
	effect.inject_entity_id = inject_entity_id
	return effect


static func directive(
	directive_id: StringName,
	target_scene_id: StringName,
	priority: int = 0,
	selection_conditions: Array = [],
	beats: Array = [],
	description: String = ""
) -> RS_SceneDirective:
	var d := RS_SCENE_DIRECTIVE.new()
	d.directive_id = directive_id
	d.target_scene_id = target_scene_id
	d.priority = priority
	d.description = description

	var sanitized_conditions: Variant = d.call("_sanitize_conditions", selection_conditions)
	d.set("_selection_conditions", sanitized_conditions)

	var sanitized_beats: Variant = d.call("_sanitize_beats", beats)
	d.set("_beats", sanitized_beats)

	return d
