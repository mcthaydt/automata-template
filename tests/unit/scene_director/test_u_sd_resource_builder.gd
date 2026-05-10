extends GutTest

const SD_RESOURCE_BUILDER := preload("res://scripts/core/utils/scene_director/u_sd_resource_builder.gd")
const RS_BEAT_DEFINITION := preload("res://scripts/core/resources/scene_director/rs_beat_definition.gd")
const RS_SCENE_DIRECTIVE := preload("res://scripts/core/resources/scene_director/rs_scene_directive.gd")
const RS_EFFECT_PUBLISH_EVENT := preload("res://scripts/core/resources/qb/effects/rs_effect_publish_event.gd")
const I_CONDITION := preload("res://scripts/core/interfaces/i_condition.gd")


func test_beat_creates_with_minimal_args() -> void:
	var beat: Resource = SD_RESOURCE_BUILDER.beat(&"test_beat")
	assert_eq(beat.beat_id, &"test_beat")
	assert_eq(beat.wait_mode, RS_BEAT_DEFINITION.WaitMode.INSTANT)
	assert_eq(beat.duration, 0.0)


func test_beat_sets_timed_mode_with_duration() -> void:
	var beat: Resource = SD_RESOURCE_BUILDER.beat(
		&"timed_beat",
		RS_BEAT_DEFINITION.WaitMode.TIMED,
		2.5
	)
	assert_eq(beat.beat_id, &"timed_beat")
	assert_eq(beat.wait_mode, RS_BEAT_DEFINITION.WaitMode.TIMED)
	assert_eq(beat.duration, 2.5)


func test_beat_sets_signal_mode_with_wait_event() -> void:
	var beat: Resource = SD_RESOURCE_BUILDER.beat(
		&"signal_beat",
		RS_BEAT_DEFINITION.WaitMode.SIGNAL,
		0.0,
		&"dialogue_done"
	)
	assert_eq(beat.beat_id, &"signal_beat")
	assert_eq(beat.wait_mode, RS_BEAT_DEFINITION.WaitMode.SIGNAL)
	assert_eq(beat.wait_event, &"dialogue_done")


func test_beat_wires_effects() -> void:
	var effect := RS_EFFECT_PUBLISH_EVENT.new()
	var typed_effects: Array = [effect]
	var beat: Resource = SD_RESOURCE_BUILDER.beat(
		&"beat_with_effects",
		RS_BEAT_DEFINITION.WaitMode.INSTANT,
		0.0,
		&"",
		[],
		typed_effects
	)
	assert_eq(beat.beat_id, &"beat_with_effects")
	assert_eq(beat.effects.size(), 1)
	assert_eq(beat.effects[0], effect)


func test_beat_wires_preconditions() -> void:
	var condition := ConditionStub.new(1.0)
	var typed_conditions: Array = [condition]
	var beat: Resource = SD_RESOURCE_BUILDER.beat(
		&"beat_with_preconds",
		RS_BEAT_DEFINITION.WaitMode.INSTANT,
		0.0,
		&"",
		typed_conditions,
		[]
	)
	assert_eq(beat.beat_id, &"beat_with_preconds")
	assert_eq(beat.preconditions.size(), 1)
	assert_eq(beat.preconditions[0], condition)


func test_beat_sets_branching_ids() -> void:
	var beat: Resource = SD_RESOURCE_BUILDER.beat(
		&"branch_beat",
		RS_BEAT_DEFINITION.WaitMode.INSTANT,
		0.0,
		&"",
		[],
		[],
		&"beat_end",
		&"beat_fail",
		[],
		&""
	)
	assert_eq(beat.next_beat_id, &"beat_end")
	assert_eq(beat.next_beat_id_on_failure, &"beat_fail")


func test_beat_sets_parallel_ids() -> void:
	var lanes: Array = [&"lane_a", &"lane_b"]
	var beat: Resource = SD_RESOURCE_BUILDER.beat(
		&"fork_beat",
		RS_BEAT_DEFINITION.WaitMode.INSTANT,
		0.0,
		&"",
		[],
		[],
		&"",
		&"",
		lanes,
		&"beat_join"
	)
	assert_eq(beat.parallel_beat_ids.size(), 2)
	assert_eq(beat.parallel_beat_ids[0], &"lane_a")
	assert_eq(beat.parallel_beat_ids[1], &"lane_b")
	assert_eq(beat.parallel_join_beat_id, &"beat_join")


func test_publish_event_creates_with_name_and_payload() -> void:
	var payload := {"beat_id": "intro_beat_1"}
	var effect: Resource = SD_RESOURCE_BUILDER.publish_event(&"scene_director_intro", payload, false)
	assert_eq(effect.event_name, &"scene_director_intro")
	assert_eq(effect.payload.get("beat_id", ""), "intro_beat_1")
	assert_false(effect.inject_entity_id)


func test_directive_creates_minimal() -> void:
	var directive: Resource = SD_RESOURCE_BUILDER.directive(&"gameplay_base_intro", &"demo_room")
	assert_eq(directive.directive_id, &"gameplay_base_intro")
	assert_eq(directive.target_scene_id, &"demo_room")
	assert_eq(directive.priority, 0)
	assert_eq(directive.beats.size(), 0)


func test_directive_wires_beats_and_priority() -> void:
	var beat1: Resource = SD_RESOURCE_BUILDER.beat(&"beat_1")
	var beat2: Resource = SD_RESOURCE_BUILDER.beat(&"beat_2")
	var beats: Array = [beat1, beat2]
	var directive: Resource = SD_RESOURCE_BUILDER.directive(
		&"dir_full",
		&"demo_room",
		10,
		[],
		beats,
		"Default introductory directive for demo_room."
	)
	assert_eq(directive.directive_id, &"dir_full")
	assert_eq(directive.priority, 10)
	assert_eq(directive.beats.size(), 2)
	assert_eq(directive.description, "Default introductory directive for demo_room.")


class ConditionStub extends I_CONDITION:
	var response_value: float = 1.0

	func _init(initial_value: float = 1.0) -> void:
		response_value = initial_value

	func evaluate(_context: Dictionary) -> float:
		return response_value
