class_name U_SparkleAnimator
extends Node3D

var _sparkles: Array[Sprite3D] = []
var _tweens: Array[Tween] = []
var _started := false

const PULSE_DURATION := 1.2
const PULSE_SCALE_MIN := 0.04
const PULSE_SCALE_MAX := 0.12

func _ready() -> void:
	_collect_sparkles()
	_start_pulsing()
	_started = true

func _collect_sparkles() -> void:
	_sparkles.clear()
	for child in get_children():
		if child is Sprite3D:
			_sparkles.append(child as Sprite3D)

func _start_pulsing() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	for i in _sparkles.size():
		var sprite := _sparkles[i]
		sprite.visible = true
		var tween := create_tween()
		tween.set_loops(0)
		var delay := i * (PULSE_DURATION / _sparkles.size())
		tween.tween_property(sprite, "scale", Vector3.ONE * PULSE_SCALE_MAX, PULSE_DURATION * 0.5).set_delay(delay).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector3.ONE * PULSE_SCALE_MIN, PULSE_DURATION * 0.5).set_ease(Tween.EASE_IN)
		_tweens.append(tween)

func _exit_tree() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()