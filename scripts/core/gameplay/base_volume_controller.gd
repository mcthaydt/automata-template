@icon("res://assets/core/editor_icons/icn_entities.svg")
extends "res://scripts/core/ecs/base_ecs_entity.gd"
class_name BaseVolumeController

const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/core/resources/ecs/rs_scene_trigger_settings.gd")

signal trigger_area_ready(area: Area3D)

@export var settings: RS_SceneTriggerSettings:
	get:
		return _settings
	set(value):
		var resolved := _ensure_settings_unique(value)
		if _settings == resolved:
			return
		# Setting changed: reset cache and reapply configuration.
		_settings = resolved
		_cached_settings = null
		if _is_initialized:
			_apply_settings_to_area()
			_apply_enabled_state(_pending_enabled)

@export_node_path("Area3D") var area_path: NodePath = NodePath("")

@export var visual_paths: Array[NodePath]:
	get:
		return _visual_path_storage.duplicate()
	set(value):
		_visual_path_storage = value.duplicate()
		if is_inside_tree():
			_collect_visual_nodes()

var _settings: RS_SceneTriggerSettings
var _cached_settings: RS_SceneTriggerSettings
var _visual_path_storage: Array[NodePath] = []

var _trigger_area: Area3D
var _collision_shape: CollisionShape3D
var _visual_nodes: Array[Node] = []

var _is_initialized: bool = false
var _pending_enabled: bool = true
var _is_enabled: bool = true
var _has_user_enabled_override: bool = false

func _ready() -> void:
	super._ready()
	_collect_visual_nodes()
	call_deferred("_initialize_volume")

func _exit_tree() -> void:
	_visual_nodes.clear()
	_trigger_area = null
	_collision_shape = null
	_is_initialized = false

func get_trigger_area() -> Area3D:
	return _trigger_area

func is_enabled() -> bool:
	return _is_enabled

func set_enabled(enabled: bool) -> void:
	_pending_enabled = enabled
	_has_user_enabled_override = true
	if not _is_initialized:
		return
	if _is_enabled == enabled:
		return
	_apply_enabled_state(enabled)

func _initialize_volume() -> void:
	_trigger_area = _resolve_or_create_area()
	if _trigger_area == null:
		push_error("BaseVolumeController: Unable to resolve or create trigger Area3D.")
		return

	_collision_shape = _ensure_collision_shape(_trigger_area)
	_apply_settings_to_area()

	_is_initialized = true

	_apply_enabled_state(_pending_enabled)
	_collect_visual_nodes()
	trigger_area_ready.emit(_trigger_area)

func _collect_visual_nodes() -> void:
	_visual_nodes.clear()
	if _visual_path_storage.is_empty():
		return
	for path in _visual_path_storage:
		if path.is_empty():
			continue
		var node := get_node_or_null(path)
		if node == null:
			continue
		if _visual_nodes.has(node):
			continue
		_visual_nodes.append(node)
	if _is_initialized and _get_settings().toggle_visuals_on_enable:
		_apply_visual_visibility(_is_enabled)

func _resolve_or_create_area() -> Area3D:
	var resolved: Area3D = null
	if not area_path.is_empty():
		resolved = get_node_or_null(area_path) as Area3D
		if resolved != null:
			return resolved

	for child in get_children():
		if child is Area3D:
			return child as Area3D

	var area := Area3D.new()
	area.name = "TriggerArea"
	area.collision_layer = 0
	area.monitoring = true
	area.monitorable = true
	add_child(area)
	return area

func _ensure_collision_shape(area: Area3D) -> CollisionShape3D:
	if area == null:
		return null
	for child in area.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	area.add_child(shape)
	return shape

func _apply_settings_to_area() -> void:
	if _trigger_area == null or _collision_shape == null:
		return

	var resolved_settings := _get_settings()
	_trigger_area.collision_layer = 0
	_trigger_area.collision_mask = max(1, resolved_settings.player_mask)
	_trigger_area.monitoring = true
	_trigger_area.monitorable = true

	_collision_shape.position = resolved_settings.local_offset

	match resolved_settings.shape_type:
		RS_SCENE_TRIGGER_SETTINGS.ShapeType.CYLINDER:
			_collision_shape.shape = _build_cylinder_shape(resolved_settings)
		RS_SCENE_TRIGGER_SETTINGS.ShapeType.BOX:
			_collision_shape.shape = _build_box_shape(resolved_settings)
		_:
			_collision_shape.shape = _build_cylinder_shape(resolved_settings)

	if not _has_user_enabled_override:
		_pending_enabled = resolved_settings.enable_on_ready

func _build_cylinder_shape(settings_resource: RS_SceneTriggerSettings) -> CylinderShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = max(0.001, settings_resource.cyl_radius)
	shape.height = max(0.001, settings_resource.cyl_height)
	return shape

func _build_box_shape(settings_resource: RS_SceneTriggerSettings) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = settings_resource.box_size
	return shape

func _apply_enabled_state(enabled: bool) -> void:
	_pending_enabled = enabled
	_is_enabled = enabled
	if _trigger_area != null:
		_trigger_area.monitoring = enabled
		_trigger_area.monitorable = enabled
	if _get_settings().toggle_visuals_on_enable:
		_apply_visual_visibility(enabled)
	_on_enabled_state_changed(enabled)

func _apply_visual_visibility(enabled: bool) -> void:
	for node in _visual_nodes:
		if node == null:
			continue
		if node is CanvasItem:
			(node as CanvasItem).visible = enabled
		elif node is Node3D:
			(node as Node3D).visible = enabled

func _get_settings() -> RS_SceneTriggerSettings:
	if _cached_settings != null:
		return _cached_settings
	if _settings == null:
		_settings = RS_SCENE_TRIGGER_SETTINGS.new()
		_settings.resource_local_to_scene = true
	_cached_settings = _settings
	return _cached_settings

func refresh_volume_from_settings() -> void:
	_cached_settings = null
	if not _is_initialized:
		return
	_apply_settings_to_area()
	_apply_enabled_state(_pending_enabled)

func refresh_visual_nodes() -> void:
	_collect_visual_nodes()

func _on_enabled_state_changed(_enabled: bool) -> void:
	# Hook for subclasses to respond when the enabled state toggles.
	pass

func _ensure_settings_unique(value: RS_SceneTriggerSettings) -> RS_SceneTriggerSettings:
	if value == null:
		return null
	if value.resource_local_to_scene:
		return value
	if value.resource_path != "":
		var duplicated := value.duplicate(true) as RS_SceneTriggerSettings
		if duplicated != null:
			duplicated.resource_local_to_scene = true
			return duplicated
	value.resource_local_to_scene = true
	return value
