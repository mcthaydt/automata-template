@icon("res://assets/core/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_SpriteDirectionSystem

const DIRECTION_TYPE := StringName("C_SpriteDirectionComponent")
const MOVEMENT_TYPE := StringName("C_MovementComponent")

const DIRECTION_NAMES: Array[String] = [
	"down", "down_right", "right", "up_right",
	"up", "up_left", "left", "down_left",
]

var _logged_errors: Dictionary = {}

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.VFX

func process_tick(_delta: float) -> void:
	var manager := get_manager()
	if manager == null:
		return
	var camera: Camera3D = ECS_UTILS.get_active_camera(self)
	var entities: Array = manager.query_entities([DIRECTION_TYPE, MOVEMENT_TYPE])
	for entity_query in entities:
		var direction_component: C_SpriteDirectionComponent = entity_query.get_component(DIRECTION_TYPE)
		var movement_component: C_MovementComponent = entity_query.get_component(MOVEMENT_TYPE)
		if direction_component == null or movement_component == null:
			continue
		_process_entity(direction_component, movement_component, camera)

func _process_entity(
	component: C_SpriteDirectionComponent,
	movement: C_MovementComponent,
	camera: Camera3D
) -> void:
	var target := component.get_target_node()
	if target == null:
		_log_error_once(component, "target_node_path is missing or invalid")
		return

	if camera == null:
		return

	var facing_dir: Vector3 = _resolve_facing(component, movement)
	if facing_dir.length_squared() < 0.0001:
		return
	facing_dir = facing_dir.normalized()

	var new_index: int = _compute_direction_index(facing_dir, camera)

	if new_index == component.current_direction_index:
		return

	component.current_direction_index = new_index
	component.current_direction_name = DIRECTION_NAMES[new_index]
	_drive_sprite(component, target)

func _compute_direction_index(facing_dir: Vector3, camera: Camera3D) -> int:
	var cam_fwd: Vector3 = -camera.global_transform.basis.z
	cam_fwd.y = 0.0

	if cam_fwd.length_squared() < 0.0001:
		return _angle_to_index(atan2(facing_dir.x, -facing_dir.z))

	cam_fwd = cam_fwd.normalized()
	var cam_right: Vector3 = camera.global_transform.basis.x
	cam_right.y = 0.0
	if cam_right.length_squared() < 0.0001:
		cam_right = cam_fwd.cross(Vector3.UP)
	cam_right = cam_right.normalized()

	var rel_x: float = facing_dir.dot(cam_right)
	var rel_z: float = facing_dir.dot(cam_fwd)
	return _angle_to_index(atan2(rel_x, -rel_z))

func _angle_to_index(angle: float) -> int:
	var step: float = TAU / 8.0
	var normalized: float = fposmod(angle + step / 2.0, TAU)
	return int(normalized / step) % 8

func _resolve_facing(component: C_SpriteDirectionComponent, movement: C_MovementComponent) -> Vector3:
	if component.facing_override.length_squared() > 0.0001:
		return component.facing_override

	var body: CharacterBody3D = movement.get_character_body()
	if body == null:
		return Vector3.ZERO

	var threshold: float = 0.1
	if component.settings != null:
		threshold = component.settings.move_threshold

	var vel := body.velocity
	var horizontal := Vector3(vel.x, 0.0, vel.z)
	if horizontal.length() > threshold:
		return horizontal

	var yaw: float = body.global_rotation.y
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func _drive_sprite(component: C_SpriteDirectionComponent, target: Node3D) -> void:
	var mode := component.direction_mode
	if mode == C_SpriteDirectionComponent.DirectionMode.AUTO:
		if target is AnimatedSprite3D:
			mode = C_SpriteDirectionComponent.DirectionMode.ANIMATED_SPRITE3D
		else:
			mode = C_SpriteDirectionComponent.DirectionMode.SPRITE3D

	if mode == C_SpriteDirectionComponent.DirectionMode.ANIMATED_SPRITE3D:
		var anim_sprite := target as AnimatedSprite3D
		if anim_sprite == null:
			_log_error_once(component, "direction_mode is ANIMATED_SPRITE3D but target is not AnimatedSprite3D")
			return
		var clip_name: String
		if component.animation_prefix.is_empty():
			clip_name = component.current_direction_name
		else:
			clip_name = component.animation_prefix + "_" + component.current_direction_name
		if anim_sprite.sprite_frames == null or not anim_sprite.sprite_frames.has_animation(clip_name):
			push_warning("S_SpriteDirectionSystem: animation '%s' not found on AnimatedSprite3D" % clip_name)
			return
		anim_sprite.play(clip_name)
	else:
		var sprite := target as Sprite3D
		if sprite == null:
			_log_error_once(component, "direction_mode is SPRITE3D but target is not Sprite3D")
			return
		var frame_count: int = sprite.hframes * sprite.vframes
		if frame_count < 8:
			push_warning("S_SpriteDirectionSystem: Sprite3D has %d frames but 8 are required" % frame_count)
		var frame_index: int = component.current_direction_index
		if component.frame_layout == C_SpriteDirectionComponent.FrameLayout.NORTH_FIRST:
			frame_index = (frame_index + 4) % 8
		sprite.frame = clamp(frame_index, 0, max(frame_count - 1, 0))

func _log_error_once(component: C_SpriteDirectionComponent, message: String) -> void:
	var key: int = component.get_instance_id()
	if _logged_errors.has(key):
		return
	_logged_errors[key] = true
	push_error("S_SpriteDirectionSystem [%s]: %s" % [component.name, message])
