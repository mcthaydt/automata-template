@icon("res://assets/core/editor_icons/icn_utility.svg")
extends Resource
class_name RS_LandingParticlesSettings

@export_group("General")
@export var enabled: bool = true

@export_group("Dust Properties")
@export var count: int = 15
@export var lifetime: float = 0.6
@export var scale: float = 0.12
@export var spread: float = 0.5
@export var drift_strength: float = 2.5
@export var spawn_offset: Vector3 = Vector3(0, -0.5, 0)
@export var drift_direction: Vector3 = Vector3(0, -0.2, 0)
