@icon("res://assets/core/editor_icons/icn_utility.svg")
extends Resource
class_name RS_JumpParticlesSettings

@export_group("General")
@export var enabled: bool = false

@export_group("Dust Properties")
@export var count: int = 5
@export var lifetime: float = 0.3
@export var scale: float = 0.1
@export var spread: float = 0.25
@export var drift_strength: float = 0.8
@export var spawn_offset: Vector3 = Vector3(0, -0.5, 0)
@export var drift_direction: Vector3 = Vector3(0, -0.25, 0)
