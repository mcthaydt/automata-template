@icon("res://assets/core/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_SpawnParticlesSystem

const DUST_SPAWNER := preload("res://scripts/core/utils/u_dust_spawner.gd")
const U_SPAWN_ACTIONS := preload("res://scripts/core/state/actions/u_spawn_actions.gd")

@export var enabled: bool = true
@export var count: int = 20
@export var lifetime: float = 0.8
@export var scale: float = 0.3
@export var spread: float = 0.4
@export var drift_strength: float = 3.0
@export var drift_direction: Vector3 = Vector3.UP
@export var spawn_offset: Vector3 = Vector3(0, 0.5, 0)

var requests: Array = []
var _store: Node = null

func _ready() -> void:
	super._ready()
	_subscribe_to_actions()

func _exit_tree() -> void:
	_unsubscribe_from_actions()
	requests.clear()

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.VFX

func _subscribe_to_actions() -> void:
	_unsubscribe_from_actions()
	var store_variant: Variant = U_ServiceLocator.try_get_service(StringName("state_store"))
	if store_variant == null:
		return
	var store: Node = store_variant as Node
	if store == null or not store.has_signal("action_dispatched"):
		return
	_store = store
	_store.action_dispatched.connect(_on_action_dispatched)

func _unsubscribe_from_actions() -> void:
	if _store != null and is_instance_valid(_store) and _store.has_signal("action_dispatched"):
		_store.action_dispatched.disconnect(_on_action_dispatched)
	_store = null

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))
	if action_type != U_SPAWN_ACTIONS.ACTION_PLAYER_SPAWNED:
		return
	var request: Dictionary = {
		"position": action.get("position", Vector3.ZERO),
		"spawn_point_id": action.get("spawn_point_id", StringName("")),
	}
	if not request.has("timestamp"):
		request["timestamp"] = 0.0
	requests.append(request.duplicate(true))

func process_tick(__delta: float) -> void:
	if not enabled:
		requests.clear()
		return

	if requests.size() == 0:
		return

	var container := DUST_SPAWNER.get_or_create_effects_container(get_tree())
	if container == null:
		requests.clear()
		return

	var spawner := DUST_SPAWNER.new()
	var config := _create_dust_config()

	for request in requests:
		var position: Vector3 = request.get("position", Vector3.ZERO)
		spawner.spawn_dust(position, container, config)

	requests.clear()

func _create_dust_config() -> DUST_SPAWNER.DustConfig:
	return DUST_SPAWNER.DustConfig.new(
		count,
		lifetime,
		scale,
		spread,
		drift_direction * drift_strength,
		spawn_offset
	)