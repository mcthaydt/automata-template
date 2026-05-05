@icon("res://assets/core/editor_icons/icn_utility.svg")
extends Resource
class_name RS_JumpParticlesSettings

@export_group("General")
@export var enabled: bool = true

@export_group("Dust Properties")
@export var count: int = 10
@export var lifetime: float = 0.5
@export var scale: float = 0.1
@export var spread: float = 0.4
@export var drift_strength: float = 3.0
@export var spawn_offset: Vector3 = Vector3(0, -0.5, 0)
@export var drift_direction: Vector3 = Vector3.UP