# 8-Directional Sprite Direction System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `C_SpriteDirectionComponent` + `S_SpriteDirectionSystem` that drives 8-directional sprite frame/animation selection on `Sprite3D` or `AnimatedSprite3D` nodes, adapted to the current camera yaw.

**Architecture:** New ECS component holds per-entity config (target node, prefix, mode, layout, facing override). A new VFX-phase system queries all entities with the component + `C_MovementComponent`, computes a camera-relative direction index each tick, and drives the sprite — selecting frames on `Sprite3D` or playing named clips on `AnimatedSprite3D`.

**Tech Stack:** Godot 4.7, GDScript, GUT test framework (`extends BaseTest`).

**Spec:** `docs/superpowers/specs/2026-05-10-8dir-sprite-direction-design.md`

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `scripts/core/resources/ecs/rs_sprite_direction_settings.gd` | Create | Move-threshold config resource |
| `scripts/core/ecs/components/c_sprite_direction_component.gd` | Create | Per-entity direction component |
| `scripts/core/ecs/systems/s_sprite_direction_system.gd` | Create | Direction computation + sprite driving |
| `tests/unit/ecs/components/test_sprite_direction_component.gd` | Create | Component unit tests |
| `tests/unit/ecs/systems/test_sprite_direction_system.gd` | Create | System unit + integration tests |

---

## Task 1: Settings Resource

**Files:**
- Create: `scripts/core/resources/ecs/rs_sprite_direction_settings.gd`

- [ ] **Step 1.1: Create the settings resource**

```gdscript
@icon("res://assets/core/editor_icons/icn_utility.svg")
extends Resource
class_name RS_SpriteDirectionSettings

@export var move_threshold: float = 0.1
```

- [ ] **Step 1.2: Commit**

```bash
git add scripts/core/resources/ecs/rs_sprite_direction_settings.gd
git commit -m "feat(2.5d): add RS_SpriteDirectionSettings resource (RED)"
```

---

## Task 2: Component + Component Tests

**Files:**
- Create: `scripts/core/ecs/components/c_sprite_direction_component.gd`
- Create: `tests/unit/ecs/components/test_sprite_direction_component.gd`

- [ ] **Step 2.1: Write the failing component tests**

```gdscript
# tests/unit/ecs/components/test_sprite_direction_component.gd
extends BaseTest

const ComponentScript := preload("res://scripts/core/ecs/components/c_sprite_direction_component.gd")

func test_component_type_is_correct() -> void:
	var c := ComponentScript.new()
	autofree(c)
	assert_eq(c.component_type, StringName("C_SpriteDirectionComponent"))

func test_default_direction_index_is_zero() -> void:
	var c := ComponentScript.new()
	autofree(c)
	assert_eq(c.current_direction_index, 0)

func test_default_direction_name_is_down() -> void:
	var c := ComponentScript.new()
	autofree(c)
	assert_eq(c.current_direction_name, "down")

func test_get_target_node_returns_null_when_path_empty() -> void:
	var c := ComponentScript.new()
	add_child(c)
	autofree(c)
	await get_tree().process_frame
	assert_null(c.get_target_node())

func test_validate_required_settings_false_when_null() -> void:
	var c := ComponentScript.new()
	autofree(c)
	assert_false(c._validate_required_settings())

func test_validate_required_settings_true_when_assigned() -> void:
	var c := ComponentScript.new()
	autofree(c)
	c.settings = RS_SpriteDirectionSettings.new()
	assert_true(c._validate_required_settings())

func test_direction_mode_enum_has_three_values() -> void:
	assert_eq(C_SpriteDirectionComponent.DirectionMode.AUTO, 0)
	assert_eq(C_SpriteDirectionComponent.DirectionMode.SPRITE3D, 1)
	assert_eq(C_SpriteDirectionComponent.DirectionMode.ANIMATED_SPRITE3D, 2)

func test_frame_layout_enum_has_two_values() -> void:
	assert_eq(C_SpriteDirectionComponent.FrameLayout.SOUTH_FIRST, 0)
	assert_eq(C_SpriteDirectionComponent.FrameLayout.NORTH_FIRST, 1)
```

- [ ] **Step 2.2: Run tests to verify they fail**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_sprite_direction_component.gd
```

Expected: FAIL — `ComponentScript` preload fails, class not defined.

- [ ] **Step 2.3: Create the component**

```gdscript
# scripts/core/ecs/components/c_sprite_direction_component.gd
@icon("res://assets/core/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_SpriteDirectionComponent

const COMPONENT_TYPE := StringName("C_SpriteDirectionComponent")

enum DirectionMode { AUTO, SPRITE3D, ANIMATED_SPRITE3D }
enum FrameLayout { SOUTH_FIRST, NORTH_FIRST }

@export var settings: RS_SpriteDirectionSettings
@export_node_path("Node3D") var target_node_path: NodePath
@export var direction_mode: DirectionMode = DirectionMode.AUTO
@export var frame_layout: FrameLayout = FrameLayout.SOUTH_FIRST
@export var animation_prefix: String = ""
@export var facing_override: Vector3 = Vector3.ZERO

var current_direction_index: int = 0
var current_direction_name: String = "down"

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
```

- [ ] **Step 2.4: Run tests to verify they pass**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_sprite_direction_component.gd
```

Expected: All PASS.

- [ ] **Step 2.5: Commit**

```bash
git add scripts/core/ecs/components/c_sprite_direction_component.gd \
        tests/unit/ecs/components/test_sprite_direction_component.gd
git commit -m "feat(2.5d): add C_SpriteDirectionComponent with tests (GREEN)"
```

---

## Task 3: System Skeleton + Direction Quantization Tests

**Files:**
- Create: `scripts/core/ecs/systems/s_sprite_direction_system.gd`
- Create: `tests/unit/ecs/systems/test_sprite_direction_system.gd` (quantization tests only)

- [ ] **Step 3.1: Write failing direction quantization tests**

```gdscript
# tests/unit/ecs/systems/test_sprite_direction_system.gd
extends BaseTest

const SystemScript := preload("res://scripts/core/ecs/systems/s_sprite_direction_system.gd")

## Pure math tests — no ECS setup needed, instantiate system directly.
func _make_system() -> S_SpriteDirectionSystem:
	var s := SystemScript.new()
	autofree(s)
	return s

func test_angle_zero_maps_to_down() -> void:
	assert_eq(_make_system()._angle_to_index(0.0), 0)

func test_angle_45deg_maps_to_down_right() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(45.0)), 1)

func test_angle_90deg_maps_to_right() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(90.0)), 2)

func test_angle_135deg_maps_to_up_right() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(135.0)), 3)

func test_angle_180deg_maps_to_up() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(180.0)), 4)

func test_angle_neg_135deg_maps_to_up_left() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(-135.0)), 5)

func test_angle_neg_90deg_maps_to_left() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(-90.0)), 6)

func test_angle_neg_45deg_maps_to_down_left() -> void:
	assert_eq(_make_system()._angle_to_index(deg_to_rad(-45.0)), 7)

func test_boundary_at_22_5deg_maps_to_down_right() -> void:
	## Exactly at boundary: 22.5° is the first value that maps to index 1.
	assert_eq(_make_system()._angle_to_index(deg_to_rad(22.5)), 1)

func test_just_under_boundary_maps_to_down() -> void:
	## 22.4° is just inside the "down" bucket.
	assert_eq(_make_system()._angle_to_index(deg_to_rad(22.4)), 0)

func test_direction_names_has_eight_entries() -> void:
	assert_eq(S_SpriteDirectionSystem.DIRECTION_NAMES.size(), 8)

func test_direction_names_order() -> void:
	assert_eq(S_SpriteDirectionSystem.DIRECTION_NAMES[0], "down")
	assert_eq(S_SpriteDirectionSystem.DIRECTION_NAMES[1], "down_right")
	assert_eq(S_SpriteDirectionSystem.DIRECTION_NAMES[2], "right")
	assert_eq(S_SpriteDirectionSystem.DIRECTION_NAMES[3], "up_right")
	assert_eq(S_SpriteDirectionSystem.DIRECTION_NAMES[4], "up")
	assert_eq(S_SpriteDirectionSystem.DIRECTION_NAMES[5], "up_left")
	assert_eq(S_SpriteDirectionSystem.DIRECTION_NAMES[6], "left")
	assert_eq(S_SpriteDirectionSystem.DIRECTION_NAMES[7], "down_left")
```

- [ ] **Step 3.2: Run to verify failure**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_sprite_direction_system.gd
```

Expected: FAIL — `SystemScript` preload fails, class not defined.

- [ ] **Step 3.3: Create the system with quantization logic only (no full pipeline yet)**

```gdscript
# scripts/core/ecs/systems/s_sprite_direction_system.gd
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
```

- [ ] **Step 3.4: Run quantization tests to verify they pass**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_sprite_direction_system.gd
```

Expected: All quantization tests PASS.

- [ ] **Step 3.5: Commit**

```bash
git add scripts/core/ecs/systems/s_sprite_direction_system.gd \
        tests/unit/ecs/systems/test_sprite_direction_system.gd
git commit -m "feat(2.5d): add S_SpriteDirectionSystem with quantization tests (GREEN)"
```

---

## Task 4: System Integration Tests (Full Pipeline)

**Files:**
- Modify: `tests/unit/ecs/systems/test_sprite_direction_system.gd`

- [ ] **Step 4.1: Add failing integration tests to the existing test file**

Append these functions after the existing quantization tests:

```gdscript
## ─── Integration helpers ────────────────────────────────────────────────────

const ECS_MANAGER := preload("res://scripts/core/managers/m_ecs_manager.gd")
const MovementComponentScript := preload("res://scripts/core/ecs/components/c_movement_component.gd")
const DirectionComponentScript := preload("res://scripts/core/ecs/components/c_sprite_direction_component.gd")

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")

class FakeBody extends CharacterBody3D:
	pass

class CameraManagerStub extends I_CAMERA_MANAGER:
	var main_camera: Camera3D = null
	func get_main_camera() -> Camera3D:
		return main_camera
	func apply_main_camera_transform(_t: Transform3D) -> void:
		pass
	func is_blend_active() -> bool:
		return false
	func initialize_scene_camera(_scene: Node) -> Camera3D:
		return null
	func finalize_blend_to_scene(_new_scene: Node) -> void:
		pass
	func apply_shake_offset(_offset: Vector2, _rotation: float) -> void:
		pass
	func set_shake_source(_source: StringName, _offset: Vector2, _rotation: float) -> void:
		pass
	func clear_shake_source(_source: StringName) -> void:
		pass

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()

func _pump() -> void:
	await get_tree().process_frame

func _register_camera(camera: Camera3D) -> void:
	var stub := CameraManagerStub.new()
	stub.main_camera = camera
	autofree(stub)
	U_SERVICE_LOCATOR.register(StringName("camera_manager"), stub)

func _setup_context() -> Dictionary:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(store)
	autofree(store)
	await _pump()

	var manager := ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_DirectionTest"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var body := FakeBody.new()
	entity.add_child(body)
	await _pump()

	var sprite := Sprite3D.new()
	sprite.hframes = 8
	entity.add_child(sprite)
	await _pump()

	var movement: C_MovementComponent = MovementComponentScript.new()
	movement.settings = RS_MovementSettings.new()
	entity.add_child(movement)
	await _pump()

	var direction: C_SpriteDirectionComponent = DirectionComponentScript.new()
	direction.settings = RS_SpriteDirectionSettings.new()
	direction.direction_mode = C_SpriteDirectionComponent.DirectionMode.SPRITE3D
	entity.add_child(direction)
	await _pump()

	direction.target_node_path = direction.get_path_to(sprite)

	var system := SystemScript.new()
	manager.add_child(system)
	await _pump()

	return {
		"store": store,
		"manager": manager,
		"entity": entity,
		"body": body,
		"sprite": sprite,
		"movement": movement,
		"direction": direction,
		"system": system,
	}

## ─── Integration tests ───────────────────────────────────────────────────────

func test_moving_right_sets_right_direction() -> void:
	## Camera faces +Z (south). Moving along +cam_right (east) → "right" (index 2).
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var sprite: Sprite3D = context["sprite"]

	## Camera looking along +Z. cam_fwd = +Z (projected, normalized).
	## cam_right = +X. Moving along +X → rel_x=1, rel_z=0 → angle=90° → index 2.
	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	## Force a direction change from default 0 by starting there, then changing.
	direction.current_direction_index = 0
	body.velocity = Vector3(5.0, 0.0, 0.0)

	manager._physics_process(0.1)

	assert_eq(direction.current_direction_index, 2)
	assert_eq(direction.current_direction_name, "right")
	assert_eq(sprite.frame, 2)

func test_idle_body_facing_away_sets_up_direction() -> void:
	## Body facing +Z (yaw = 0) → facing_dir = -sin(0), -cos(0) = (0, 0, -1).
	## With camera at identity (facing +Z), cam_fwd = +Z.
	## rel_x = 0, rel_z = (-1)·(+1) = -1 → angle = atan2(0, 1) = 0 → "down"?
	## Wait — facing_dir = (0, 0, -1) (forward in Godot = -Z).
	## rel_z = (-Z)·(cam_fwd=+Z) = -1. angle = atan2(0, -(-1)) = atan2(0,1) = 0 → index 0 = "down".
	## For "up" (index 4), body yaw = PI → facing = (0, 0, 1) → rel_z = 1 → angle = atan2(0,-1) = PI → index 4.
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	body.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0.0, PI, 0.0)
	## Start index at a different value so a change is detected.
	direction.current_direction_index = 0

	manager._physics_process(0.1)

	assert_eq(direction.current_direction_index, 4)
	assert_eq(direction.current_direction_name, "up")

func test_facing_override_takes_priority_over_velocity() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	## Override: face right (+X). Velocity: face left (-X). Override wins.
	direction.facing_override = Vector3(1.0, 0.0, 0.0)
	body.velocity = Vector3(-5.0, 0.0, 0.0)
	direction.current_direction_index = 0

	manager._physics_process(0.1)

	## +X with camera at identity → index 2 = "right"
	assert_eq(direction.current_direction_index, 2)

func test_no_camera_does_not_update_direction() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	## No camera registered — ServiceLocator has no camera_manager stub.
	body.velocity = Vector3(5.0, 0.0, 0.0)
	direction.current_direction_index = 0
	direction.current_direction_name = "down"

	manager._physics_process(0.1)

	## Direction unchanged.
	assert_eq(direction.current_direction_index, 0)
	assert_eq(direction.current_direction_name, "down")

func test_sprite3d_south_first_sets_frame_directly() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var sprite: Sprite3D = context["sprite"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	direction.frame_layout = C_SpriteDirectionComponent.FrameLayout.SOUTH_FIRST
	body.velocity = Vector3(5.0, 0.0, 0.0)
	direction.current_direction_index = 0

	manager._physics_process(0.1)

	## Moving +X → index 2. SOUTH_FIRST: frame = 2.
	assert_eq(sprite.frame, 2)

func test_sprite3d_north_first_offsets_frame_by_four() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var sprite: Sprite3D = context["sprite"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	direction.frame_layout = C_SpriteDirectionComponent.FrameLayout.NORTH_FIRST
	body.velocity = Vector3(5.0, 0.0, 0.0)
	direction.current_direction_index = 0

	manager._physics_process(0.1)

	## Moving +X → index 2. NORTH_FIRST: frame = (2+4)%8 = 6.
	assert_eq(sprite.frame, 6)

func test_animated_sprite3d_plays_prefixed_clip() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var entity: Node = context["entity"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	## Set up AnimatedSprite3D with "walk_right" animation.
	var frames := SpriteFrames.new()
	frames.add_animation("walk_right")
	var anim_sprite := AnimatedSprite3D.new()
	anim_sprite.sprite_frames = frames
	entity.add_child(anim_sprite)
	await get_tree().process_frame

	direction.direction_mode = C_SpriteDirectionComponent.DirectionMode.ANIMATED_SPRITE3D
	direction.target_node_path = direction.get_path_to(anim_sprite)
	direction.animation_prefix = "walk"
	direction.current_direction_index = 0

	body.velocity = Vector3(5.0, 0.0, 0.0)

	manager._physics_process(0.1)

	## Moving +X → "right". Clip: "walk_right".
	assert_eq(anim_sprite.current_animation, "walk_right")

func test_animated_sprite3d_plays_bare_direction_when_no_prefix() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var entity: Node = context["entity"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	var frames := SpriteFrames.new()
	frames.add_animation("right")
	var anim_sprite := AnimatedSprite3D.new()
	anim_sprite.sprite_frames = frames
	entity.add_child(anim_sprite)
	await get_tree().process_frame

	direction.direction_mode = C_SpriteDirectionComponent.DirectionMode.ANIMATED_SPRITE3D
	direction.target_node_path = direction.get_path_to(anim_sprite)
	direction.animation_prefix = ""
	direction.current_direction_index = 0

	body.velocity = Vector3(5.0, 0.0, 0.0)

	manager._physics_process(0.1)

	assert_eq(anim_sprite.current_animation, "right")

func test_no_redundant_update_when_direction_unchanged() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var sprite: Sprite3D = context["sprite"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	## Pre-set direction and frame to "right" (index 2, frame 2).
	direction.current_direction_index = 2
	direction.current_direction_name = "right"
	sprite.frame = 99  ## Sentinel — should NOT be overwritten if direction unchanged.

	body.velocity = Vector3(5.0, 0.0, 0.0)

	manager._physics_process(0.1)

	## Direction unchanged → sprite.frame not touched.
	assert_eq(sprite.frame, 99)

func test_missing_target_node_does_not_crash() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var direction: C_SpriteDirectionComponent = context["direction"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY
	add_child(camera)
	autofree(camera)
	_register_camera(camera)

	## Point target_node_path to a nonexistent node.
	direction.target_node_path = NodePath("NonExistentNode")
	body.velocity = Vector3(5.0, 0.0, 0.0)

	## Should not throw.
	manager._physics_process(0.1)
	assert_true(true)  ## Reached here = no crash.
```

- [ ] **Step 4.2: Run to verify failures**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_sprite_direction_system.gd
```

Expected: All integration tests FAIL. The quantization tests should still PASS.

- [ ] **Step 4.3: Verify system already passes (it was already complete in Task 3)**

The system implementation from Task 3 is already complete. Run tests again:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_sprite_direction_system.gd
```

Expected: All tests PASS. If any fail, diagnose using the error and fix only the failing assertion — do not change test assertions to match incorrect behavior.

- [ ] **Step 4.4: Commit**

```bash
git add tests/unit/ecs/systems/test_sprite_direction_system.gd
git commit -m "test(2.5d): add S_SpriteDirectionSystem integration tests (GREEN)"
```

---

## Task 5: Style Guard

- [ ] **Step 5.1: Run style enforcement**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: PASS. If it fails, the output will name the file and rule that violates the style guide. Fix the named issue (file naming, class naming, or prefix mismatch) and re-run before proceeding.

- [ ] **Step 5.2: Commit if style fixes were needed**

Only commit if Step 5.1 required file changes:

```bash
git add <any fixed files>
git commit -m "fix(style): correct naming issues flagged by style enforcement"
```

---

## Task 6: Final Commit

- [ ] **Step 6.1: Run full test suite one last time**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_sprite_direction_component.gd && \
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_sprite_direction_system.gd
```

Expected: All PASS.

- [ ] **Step 6.2: Final commit**

```bash
git add \
  scripts/core/resources/ecs/rs_sprite_direction_settings.gd \
  scripts/core/ecs/components/c_sprite_direction_component.gd \
  scripts/core/ecs/systems/s_sprite_direction_system.gd \
  tests/unit/ecs/components/test_sprite_direction_component.gd \
  tests/unit/ecs/systems/test_sprite_direction_system.gd
git commit -m "feat(2.5d): 8-directional camera-relative sprite direction system"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|---|---|
| `C_SpriteDirectionComponent` with all fields | Task 2 |
| `S_SpriteDirectionSystem` VFX phase | Task 3 step 3.3 (`get_phase`) |
| Facing priority: override → velocity → body rotation | Task 3 `_resolve_facing` + Task 4 tests |
| Camera yaw projection, degenerate fallback | Task 3 `_compute_direction_index` |
| 8-direction quantization with half-step offset | Task 3 `_angle_to_index` + Task 3 tests |
| No redundant sprite update when direction unchanged | Task 3 + Task 4 `test_no_redundant_update` |
| `Sprite3D` frame driving (SOUTH/NORTH layouts) | Task 3 `_drive_sprite` + Task 4 tests |
| `AnimatedSprite3D` clip driving with/without prefix | Task 3 `_drive_sprite` + Task 4 tests |
| Missing target: log once, no crash | Task 3 `_log_error_once` + Task 4 test |
| No camera: direction not updated, no crash | Task 3 `_process_entity` + Task 4 test |
| NPC compatible (no C_InputComponent required) | Task 3 query (only requires DIRECTION + MOVEMENT) |
| No state store dispatch | Task 3 (no dispatch code present) |

**No placeholders found.**

**Type consistency verified:** `C_SpriteDirectionComponent`, `S_SpriteDirectionSystem`, `RS_SpriteDirectionSettings` — names consistent throughout all tasks.
