@icon("res://assets/core/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_SpriteDirectionComponent

const COMPONENT_TYPE := StringName("C_SpriteDirectionComponent")
const SettingsClass := preload("res://scripts/core/resources/ecs/rs_sprite_direction_settings.gd")

enum DirectionMode { AUTO, SPRITE3D, ANIMATED_SPRITE3D }
enum FrameLayout { SOUTH_FIRST, NORTH_FIRST }

@export var settings: Resource
@export_node_path("Node3D") var target_node_path: NodePath
@export var direction_mode: DirectionMode = DirectionMode.AUTO
@export var frame_layout: FrameLayout = FrameLayout.SOUTH_FIRST
@export var animation_prefix: String = ""
@export var facing_override: Vector3 = Vector3.ZERO

var current_direction_index: int = 0
var current_direction_name: String = "down"
var last_world_facing: Vector3 = Vector3(0.0, 0.0, -1.0)

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_SpriteDirectionComponent missing settings; assign an RS_SpriteDirectionSettings resource.")
		return false
	return true

func get_target_node() -> Node3D:
	if target_node_path.is_empty():
		return null
	return get_node_or_null(target_node_path) as Node3D
