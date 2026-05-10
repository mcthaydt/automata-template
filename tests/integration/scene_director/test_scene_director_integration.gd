extends GutTest

const M_SCENE_DIRECTOR := preload("res://scripts/core/managers/m_scene_director_manager.gd")
const M_STATE_STORE := preload("res://scripts/core/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const BR_DEMO_INTRO_DIRECTIVE := preload("res://scripts/core/utils/scene_director/br_demo_intro_directive.gd")
const RS_SCENE_DIRECTIVE := preload("res://scripts/core/resources/scene_director/rs_scene_directive.gd")
const RS_BEAT_DEFINITION := preload("res://scripts/core/resources/scene_director/rs_beat_definition.gd")
const EFFECT_PUBLISH_EVENT := preload("res://scripts/core/resources/qb/effects/rs_effect_publish_event.gd")
const U_SCENE_ACTIONS := preload("res://scripts/core/state/actions/u_scene_actions.gd")
const U_SCENE_DIRECTOR_ACTIONS := preload("res://scripts/core/state/actions/u_scene_director_actions.gd")
const U_SCENE_DIRECTOR_SELECTORS := preload("res://scripts/core/state/selectors/u_scene_director_selectors.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")

const EVENT_BEAT_ONE := StringName("scene_director_intro_beat_1")
const EVENT_BEAT_TWO := StringName("scene_director_intro_beat_2")
const EVENT_SIGNPOST_MESSAGE := StringName("signpost_message")
const EVENT_BRANCH_START := StringName("test_branch_start")
const EVENT_BRANCH_SKIPPED := StringName("test_branch_skipped")
const EVENT_LANE_A := StringName("test_lane_a")
const EVENT_LANE_B := StringName("test_lane_b")
const EVENT_JOIN := StringName("test_join")

var _root: Node
var _state_store: M_STATE_STORE
var _scene_director: M_SCENE_DIRECTOR

func before_each() -> void:
	U_ServiceLocator.clear()
	U_ECS_EVENT_BUS.reset()

	_root = Node.new()
	_root.name = "Root"
	add_child_autofree(_root)

	_state_store = M_STATE_STORE.new()
	_state_store.settings = RS_STATE_STORE_SETTINGS.new()
	_state_store.settings.enable_persistence = false
	_root.add_child(_state_store)
	U_ServiceLocator.register(StringName("state_store"), _state_store)

	_scene_director = M_SCENE_DIRECTOR.new()
	_scene_director.state_store = _state_store
	var directive_resource: Resource = BR_DEMO_INTRO_DIRECTIVE.new().build()
	var directives: Array[Resource] = [directive_resource]
	_scene_director.directives = directives
	_root.add_child(_scene_director)
	U_ServiceLocator.register(StringName("scene_director"), _scene_director)

	await get_tree().process_frame
	await wait_physics_frames(1)

func after_each() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame

	U_ServiceLocator.clear()
	U_ECS_EVENT_BUS.reset()

	_root = null
	_state_store = null
	_scene_director = null

func test_scene_transition_starts_directive_and_completes_beats_in_order() -> void:
	var started_directive_ids: Array[StringName] = []
	var completed_directive_ids: Array[StringName] = []
	var beat_event_order: Array[StringName] = []
	var beat_index_advances: Array[int] = []
	var signpost_messages: Array[String] = []

	# Channel taxonomy: observe directive lifecycle via Redux action_dispatched
	_state_store.action_dispatched.connect(func(action: Dictionary) -> void:
		var action_type: StringName = action.get("type", StringName(""))
		if action_type == U_SCENE_DIRECTOR_ACTIONS.ACTION_START_DIRECTIVE:
			started_directive_ids.append(action.get("payload", StringName("")))
		elif action_type == U_SCENE_DIRECTOR_ACTIONS.ACTION_COMPLETE_DIRECTIVE:
			# Directive ID stays in active_directive_id after completion
			completed_directive_ids.append(
				U_SCENE_DIRECTOR_SELECTORS.get_active_directive_id(_state_store.get_state())
			)
		elif action_type == U_SCENE_DIRECTOR_ACTIONS.ACTION_SET_BEAT_INDEX:
			var index: int = int(action.get("payload", -1))
			if index > 0:
				beat_index_advances.append(index)
	)

	var unsub_beat_one: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_BEAT_ONE,
		func(_event: Dictionary) -> void:
			beat_event_order.append(EVENT_BEAT_ONE)
	)
	var unsub_beat_two: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_BEAT_TWO,
		func(_event: Dictionary) -> void:
			beat_event_order.append(EVENT_BEAT_TWO)
	)
	var unsub_signpost: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_SIGNPOST_MESSAGE,
		func(event: Dictionary) -> void:
			var payload: Dictionary = _extract_payload(event)
			signpost_messages.append(String(payload.get("message", "")))
	)

	_state_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
	await _wait_for_directive_completion(completed_directive_ids, 90)

	assert_eq(started_directive_ids.size(), 1, "Expected one start_directive action")
	assert_eq(completed_directive_ids.size(), 1, "Expected one complete_directive action")
	if started_directive_ids.size() > 0:
		assert_eq(started_directive_ids[0], StringName("demo_intro"))
	if completed_directive_ids.size() > 0:
		assert_eq(completed_directive_ids[0], StringName("demo_intro"))

	var expected_beat_events: Array[StringName] = [EVENT_BEAT_ONE, EVENT_BEAT_TWO]
	assert_eq(beat_event_order, expected_beat_events)
	var expected_advance_indices: Array[int] = [1, 2]
	assert_eq(beat_index_advances, expected_advance_indices)
	assert_eq(
		signpost_messages,
		["hud.scene_director_intro_beat_1", "hud.scene_director_intro_beat_2"],
		"Intro beats should publish user-facing signpost messages"
	)

	var state: Dictionary = _state_store.get_state()
	assert_eq(U_SCENE_DIRECTOR_SELECTORS.get_director_state(state), "completed")
	assert_eq(
		U_SCENE_DIRECTOR_SELECTORS.get_active_directive_id(state),
		StringName("demo_intro")
	)

	if unsub_beat_one.is_valid():
		unsub_beat_one.call()
	if unsub_beat_two.is_valid():
		unsub_beat_two.call()
	if unsub_signpost.is_valid():
		unsub_signpost.call()

func test_branching_and_parallel_directive_executes_expected_beats() -> void:
	var directive: Resource = _build_branch_parallel_directive()
	_scene_director.directives = [directive]

	var completed_directive_ids: Array[StringName] = []
	var observed_events: Array[StringName] = []
	var saw_parallel_state: bool = false

	# Channel taxonomy: observe directive completion via Redux action_dispatched
	_state_store.action_dispatched.connect(func(action: Dictionary) -> void:
		if action.get("type", StringName("")) == U_SCENE_DIRECTOR_ACTIONS.ACTION_COMPLETE_DIRECTIVE:
			completed_directive_ids.append(
				U_SCENE_DIRECTOR_SELECTORS.get_active_directive_id(_state_store.get_state())
			)
	)

	var unsub_branch_start: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_BRANCH_START,
		func(_event: Dictionary) -> void:
			observed_events.append(EVENT_BRANCH_START)
	)
	var unsub_branch_skipped: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_BRANCH_SKIPPED,
		func(_event: Dictionary) -> void:
			observed_events.append(EVENT_BRANCH_SKIPPED)
	)
	var unsub_lane_a: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_LANE_A,
		func(_event: Dictionary) -> void:
			observed_events.append(EVENT_LANE_A)
	)
	var unsub_lane_b: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_LANE_B,
		func(_event: Dictionary) -> void:
			observed_events.append(EVENT_LANE_B)
	)
	var unsub_join: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_JOIN,
		func(_event: Dictionary) -> void:
			observed_events.append(EVENT_JOIN)
	)

	_state_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("demo_room")))
	var frames: int = 0
	while completed_directive_ids.is_empty() and frames < 120:
		await wait_physics_frames(1)
		if U_SCENE_DIRECTOR_SELECTORS.is_parallel(_state_store.get_state()):
			saw_parallel_state = true
		frames += 1

	assert_eq(completed_directive_ids.size(), 1)
	assert_true(saw_parallel_state, "Expected to observe parallel lane state while directive was active")
	assert_true(observed_events.has(EVENT_BRANCH_START))
	assert_false(observed_events.has(EVENT_BRANCH_SKIPPED))
	assert_true(observed_events.has(EVENT_LANE_A))
	assert_true(observed_events.has(EVENT_LANE_B))
	assert_true(observed_events.has(EVENT_JOIN))
	assert_eq(U_SCENE_DIRECTOR_SELECTORS.get_director_state(_state_store.get_state()), "completed")
	assert_false(U_SCENE_DIRECTOR_SELECTORS.is_parallel(_state_store.get_state()))

	if unsub_branch_start.is_valid():
		unsub_branch_start.call()
	if unsub_branch_skipped.is_valid():
		unsub_branch_skipped.call()
	if unsub_lane_a.is_valid():
		unsub_lane_a.call()
	if unsub_lane_b.is_valid():
		unsub_lane_b.call()
	if unsub_join.is_valid():
		unsub_join.call()

func _extract_payload(event: Dictionary) -> Dictionary:
	var payload_variant: Variant = event.get("payload", {})
	if payload_variant is Dictionary:
		return payload_variant as Dictionary
	return {}

func _wait_for_directive_completion(completed_directive_ids: Array[StringName], max_frames: int) -> void:
	var frames: int = 0
	while completed_directive_ids.is_empty() and frames < max_frames:
		await wait_physics_frames(1)
		frames += 1

func _build_branch_parallel_directive() -> Resource:
	var branch_start := _beat(StringName("beat_start"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""))
	var branch_start_effects: Array[I_Effect] = [_make_publish_effect(EVENT_BRANCH_START)]
	branch_start.effects = branch_start_effects
	branch_start.next_beat_id = StringName("beat_fork")

	var branch_skipped := _beat(StringName("beat_skipped"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""))
	var branch_skip_effects: Array[I_Effect] = [_make_publish_effect(EVENT_BRANCH_SKIPPED)]
	branch_skipped.effects = branch_skip_effects

	var fork := _beat(StringName("beat_fork"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""))
	var lane_ids: Array[StringName] = [StringName("lane_a"), StringName("lane_b")]
	fork.parallel_beat_ids = lane_ids
	fork.parallel_join_beat_id = StringName("beat_join")

	var lane_a := _beat(StringName("lane_a"), RS_BEAT_DEFINITION.WaitMode.TIMED, 0.02, StringName(""))
	var lane_a_effects: Array[I_Effect] = [_make_publish_effect(EVENT_LANE_A)]
	lane_a.effects = lane_a_effects
	var lane_b := _beat(StringName("lane_b"), RS_BEAT_DEFINITION.WaitMode.TIMED, 0.02, StringName(""))
	var lane_b_effects: Array[I_Effect] = [_make_publish_effect(EVENT_LANE_B)]
	lane_b.effects = lane_b_effects

	var join := _beat(StringName("beat_join"), RS_BEAT_DEFINITION.WaitMode.INSTANT, 0.0, StringName(""))
	var join_effects: Array[I_Effect] = [_make_publish_effect(EVENT_JOIN)]
	join.effects = join_effects

	var directive: Resource = RS_SCENE_DIRECTIVE.new()
	directive.directive_id = StringName("branch_parallel_directive")
	directive.target_scene_id = StringName("demo_room")
	directive.priority = 100
	var selection_conditions: Array[I_Condition] = []
	directive.selection_conditions = selection_conditions
	var beats: Array[RS_BeatDefinition] = [branch_start, branch_skipped, fork, lane_a, lane_b, join]
	directive.beats = beats
	return directive

func _beat(
	beat_id: StringName,
	wait_mode: int,
	duration: float,
	wait_event: StringName
) -> Resource:
	var beat: Resource = RS_BEAT_DEFINITION.new()
	beat.beat_id = beat_id
	beat.wait_mode = wait_mode
	beat.duration = duration
	beat.wait_event = wait_event
	var preconditions: Array[I_Condition] = []
	var effects: Array[I_Effect] = []
	beat.preconditions = preconditions
	beat.effects = effects
	beat.next_beat_id = StringName("")
	beat.next_beat_id_on_failure = StringName("")
	var lane_ids: Array[StringName] = []
	beat.parallel_beat_ids = lane_ids
	beat.parallel_join_beat_id = StringName("")
	return beat

func _make_publish_effect(event_name: StringName) -> Resource:
	var effect: Resource = EFFECT_PUBLISH_EVENT.new()
	effect.event_name = event_name
	effect.payload = {}
	effect.inject_entity_id = false
	return effect