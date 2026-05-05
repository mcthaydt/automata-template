# Task H: GPU Particles → Billboarded Sprite Dust — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace GPUParticles3D with individually animated Sprite3D dust puffs, eliminating the GPU init bug workaround and per-frame shader cost.

**Architecture:** New `U_DustSpawner` class creates N `Sprite3D` puffs per call, each animated via `Tween` (scale up → fade out → auto-cleanup). Three ECS systems and two settings resources get new field names. Goal zone sparkles become Sprite3D puffs on a timer. Scene manager particle-pause logic is simplified.

**Tech Stack:** Godot 4.7 (GDScript), GUT test framework, Sprite3D + Tween

---

## Task 1: Create U_DustSpawner with DustConfig

**Files:**
- Create: `scripts/core/utils/u_dust_spawner.gd`
- Create: `tests/unit/utils/test_dust_spawner.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/utils/test_dust_spawner.gd`:

```gdscript
extends GutTest

const DUST_SPAWNER := preload("res://scripts/core/utils/u_dust_spawner.gd")

func test_dust_config_defaults() -> void:
	var config := DUST_SPAWNER.DustConfig.new()
	assert_eq(config.count, 10)
	assert_eq(config.lifetime, 0.5)
	assert_eq(config.scale, 0.3)
	assert_eq(config.spread, 0.4)
	assert_eq(config.drift, Vector3.UP)
	assert_eq(config.spawn_offset, Vector3.ZERO)

func test_dust_config_custom_values() -> void:
	var config := DUST_SPAWNER.DustConfig.new(
		20,
		1.0,
		0.5,
		0.8,
		Vector3(1, 2, 3),
		Vector3(0, -1, 0)
	)
	assert_eq(config.count, 20)
	assert_eq(config.lifetime, 1.0)
	assert_eq(config.scale, 0.5)
	assert_eq(config.spread, 0.8)
	assert_eq(config.drift, Vector3(1, 2, 3))
	assert_eq(config.spawn_offset, Vector3(0, -1, 0))

func test_spawn_dust_creates_sprite3d_nodes() -> void:
	var spawner := DUST_SPAWNER.new()
	var config := DUST_SPAWNER.DustConfig.new(5, 0.5, 0.3)
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	spawner.spawn_dust(Vector3.ZERO, container, config)

	assert_eq(container.get_child_count(), 5, "Should create 5 Sprite3D puffs")
	for child in container.get_children():
		assert_true(child is Sprite3D, "Each child should be Sprite3D")

func test_spawn_dust_puff_has_billboard_material() -> void:
	var spawner := DUST_SPAWNER.new()
	var config := DUST_SPAWNER.DustConfig.new(1, 0.5, 0.3)
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	spawner.spawn_dust(Vector3.ZERO, container, config)

	var puff := container.get_child(0) as Sprite3D
	assert_not_null(puff, "Puff should exist")
	var mat := puff.material_override as StandardMaterial3D
	assert_not_null(mat, "Should have StandardMaterial3D override")
	assert_eq(mat.billboard_mode, BaseMaterial3D.BILLBOARD_PARTICLES)
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)

func test_spawn_dust_nulls_return_early() -> void:
	var spawner := DUST_SPAWNER.new()
	var config := DUST_SPAWNER.DustConfig.new()
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	spawner.spawn_dust(Vector3.ZERO, null, config)
	assert_eq(container.get_child_count(), 0, "Should not spawn with null container")

func test_is_dust_enabled_returns_true_when_no_store() -> void:
	var result := DUST_SPAWNER.is_dust_enabled(null)
	assert_true(result, "Should return true when tree is null")

func test_get_or_create_effects_container_creates_container() -> void:
	var container := DUST_SPAWNER.get_or_create_effects_container(get_tree())
	assert_not_null(container, "Should create effects container")
	assert_eq(container.name, "EffectsContainer")
	if container != null:
		container.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_dust_spawner.gd`

- [ ] **Step 3: Implement U_DustSpawner**

Create `scripts/core/utils/u_dust_spawner.gd`:

```gdscript
extends RefCounted
class_name U_DustSpawner

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_VFX_SELECTORS := preload("res://scripts/core/state/selectors/u_vfx_selectors.gd")
const I_VFX_MANAGER := preload("res://scripts/core/interfaces/i_vfx_manager.gd")

const STORE_SERVICE := StringName("state_store")
const DUST_PUFF_TEXTURE := preload("res://assets/core/textures/tex_dust_puff.png")
const DUST_PUFF_NAME_PREFIX := "DustPuff_"

static var _default_material: StandardMaterial3D = null

class DustConfig:
	var count: int = 10
	var lifetime: float = 0.5
	var scale: float = 0.3
	var spread: float = 0.4
	var drift: Vector3 = Vector3.UP
	var spawn_offset: Vector3 = Vector3.ZERO

	func _init(
		p_count: int = 10,
		p_lifetime: float = 0.5,
		p_scale: float = 0.3,
		p_spread: float = 0.4,
		p_drift: Vector3 = Vector3.UP,
		p_spawn_offset: Vector3 = Vector3.ZERO
	) -> void:
		count = p_count
		lifetime = p_lifetime
		scale = p_scale
		spread = p_spread
		drift = p_drift
		spawn_offset = p_spawn_offset

func spawn_dust(position: Vector3, container: Node3D, config: DustConfig) -> void:
	if container == null:
		push_warning("U_DustSpawner: Cannot spawn dust - container is null")
		return

	if config == null:
		push_warning("U_DustSpawner: Cannot spawn dust - config is null")
		return

	if not is_dust_enabled(container.get_tree()):
		return

	var material := _get_default_material()

	for i in range(config.count):
		var puff := Sprite3D.new()
		puff.name = DUST_PUFF_NAME_PREFIX + str(i)
		puff.texture = DUST_PUFF_TEXTURE
		puff.billboard = BaseMaterial3D.BILLBOARD_PARTICLES
		puff.material_override = material
		puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		puff.stretch_mode = TextureRect.STRETCH_SCALE
		puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		puff.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var random_offset := Vector3(
			(randf() - 0.5) * 2.0 * config.spread,
			(randf() - 0.5) * 2.0 * config.spread,
			(randf() - 0.5) * 2.0 * config.spread
		)
		puff.global_position = position + config.spawn_offset + random_offset
		puff.scale = Vector3.ZERO

		container.add_child(puff)

		_animate_puff(puff, config)

func _animate_puff(puff: Sprite3D, config: DustConfig) -> void:
	var tween := puff.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var grow_duration := config.lifetime * 0.3
	var hold_duration := config.lifetime * 0.2
	var fade_duration := config.lifetime * 0.5
	var uniform_scale := maxf(config.scale, 0.01)

	tween.tween_property(puff, "scale", Vector3(uniform_scale, uniform_scale, uniform_scale), grow_duration)
	tween.tween_interval(hold_duration)
	tween.parallel().tween_property(puff, "modulate:a", 0.0, fade_duration)
	tween.parallel().tween_property(puff, "position:y", puff.position.y + config.drift.y * config.lifetime, fade_duration)

	tween.tween_callback(puff.queue_free)

static func _get_default_material() -> StandardMaterial3D:
	if _default_material != null:
		return _default_material

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	_default_material = material
	return material

static func get_or_create_effects_container(tree: SceneTree) -> Node3D:
	if tree == null:
		if OS.is_debug_build():
			push_warning("U_DustSpawner: Cannot get effects container - tree is null")
		return null

	if not is_dust_enabled(tree):
		return null

	var manager := U_SERVICE_LOCATOR.try_get_service(StringName("vfx_manager")) as I_VFX_MANAGER
	if manager != null:
		var registered_container := manager.get_effects_container() as Node3D
		if registered_container != null and is_instance_valid(registered_container):
			return registered_container

	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return null

	var container := Node3D.new()
	container.name = "EffectsContainer"
	current_scene.add_child(container)
	if manager != null:
		manager.set_effects_container(container)
	return container

static func is_dust_enabled(tree: SceneTree) -> bool:
	if tree == null:
		return true

	var store := U_SERVICE_LOCATOR.try_get_service(STORE_SERVICE) as I_StateStore
	if store == null or not is_instance_valid(store):
		return true

	if not store.is_ready():
		return true

	var state: Dictionary = store.get_state()
	return U_VFX_SELECTORS.is_particles_enabled(state)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_dust_spawner.gd`

- [ ] **Step 5: Run style enforcement**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`

- [ ] **Step 6: Commit**

```bash
git add scripts/core/utils/u_dust_spawner.gd tests/unit/utils/test_dust_spawner.gd assets/core/textures/tex_dust_puff.png.import && git commit -m "(RED/GREEN) Add U_DustSpawner with DustConfig and Sprite3D dust puffs"
```

---

## Task 2: Update settings resources (new field names)

**Files:**
- Modify: `scripts/core/resources/ecs/rs_jump_particles_settings.gd`
- Modify: `scripts/core/resources/ecs/rs_landing_particles_settings.gd`
- Modify: `resources/core/base_settings/gameplay/cfg_jump_particles_default.tres`
- Modify: `resources/core/base_settings/gameplay/cfg_landing_particles_default.tres`

- [ ] **Step 1: Update RS_JumpParticlesSettings**

Rename fields to dust semantics:

| Old | New | Default |
|-----|-----|---------|
| emission_count | count | 10 |
| particle_lifetime | lifetime | 0.5 |
| particle_scale | scale | 0.1 |
| spread_angle | spread | 0.4 |
| initial_velocity | drift_strength | 3.0 |
| spawn_offset | spawn_offset | (0,-0.5,0) |
| particle_material | (remove) | — |

Add new field: `drift_direction: Vector3 = Vector3.UP`

Keep `enabled: bool = true`.

- [ ] **Step 2: Update RS_LandingParticlesSettings**

Same pattern with landing defaults: count=15, lifetime=0.6, scale=0.12, spread=0.5, drift_strength=2.5.

- [ ] **Step 3: Recreate .tres files**

Since field names changed, the .tres files won't load. Delete them and let the builder recreate them, or manually update the property names.

- [ ] **Step 4: Run style enforcement**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`

- [ ] **Step 5: Commit**

```bash
git add scripts/core/resources/ecs/ resources/core/base_settings/gameplay/ && git commit -m "(REFACTOR) Rename particle settings to dust semantics"
```

---

## Task 3: Update ECS systems to use U_DustSpawner

**Files:**
- Modify: `scripts/core/ecs/systems/s_spawn_particles_system.gd`
- Modify: `scripts/core/ecs/systems/s_jump_particles_system.gd`
- Modify: `scripts/core/ecs/systems/s_landing_particles_system.gd`

- [ ] **Step 1: Update S_SpawnParticlesSystem**

Replace `PARTICLE_SPAWNER := preload("res://scripts/core/utils/u_particle_spawner.gd")` with `DUST_SPAWNER := preload("res://scripts/core/utils/u_dust_spawner.gd")`.

- Remove `_u_particle_spawner_activate_frame1/2` methods
- Replace `spawn_particles()` call with `spawn_dust()`
- Replace `ParticleConfig` with `DustConfig`
- Update `_create_particle_config()` → `_create_dust_config()` using new settings field names

- [ ] **Step 2: Update S_JumpParticlesSystem**

Same changes as S_SpawnParticlesSystem:
- Replace PARTICLE_SPAWNER preload with DUST_SPAWNER
- Remove activation callbacks
- Use DustConfig with settings fields (count, lifetime, scale, spread, drift, spawn_offset)
- Add drift calculation: `Vector3.UP * settings.drift_strength`

- [ ] **Step 3: Update S_LandingParticlesSystem**

Same pattern. Landing uses `entity_landed` event.

- [ ] **Step 4: Run tests**

Run: `tools/run_gut_suite.sh`

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ecs/systems/ && git commit -m "(REFACTOR) Update ECS systems to use U_DustSpawner"
```

---

## Task 4: Remove U_ParticleSpawner and deferred activation callbacks

**Files:**
- Delete: `scripts/core/utils/u_particle_spawner.gd`
- Delete: `tests/unit/utils/test_particle_spawner.gd`
- Search and remove any remaining references to `U_ParticleSpawner`, `PARTICLE_SPAWNER`, `ParticleConfig`, and `_u_particle_spawner_activate_frame1/2` across the entire codebase

- [ ] **Step 1: Search for remaining references**

```bash
grep -rn "u_particle_spawner\|U_ParticleSpawner\|PARTICLE_SPAWNER\|ParticleConfig\|_u_particle_spawner_activate" scripts/ tests/ resources/ --include="*.gd" --include="*.tres"
```

Fix any found references.

- [ ] **Step 2: Delete old files**

```bash
rm scripts/core/utils/u_particle_spawner.gd
rm tests/unit/utils/test_particle_spawner.gd
```

- [ ] **Step 3: Run style enforcement and full suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd && tools/run_gut_suite.sh`

- [ ] **Step 4: Commit**

```bash
git add -u scripts/core/utils/u_particle_spawner.gd tests/unit/utils/test_particle_spawner.gd && git commit -m "(REFACTOR) Remove U_ParticleSpawner — replaced by U_DustSpawner"
```

---

## Task 5: Update M_SceneManager particle pause logic

**Files:**
- Modify: `scripts/core/managers/m_scene_manager.gd`

- [ ] **Step 1: Replace `_set_particles_paused()` with `_set_dust_paused()`**

The current method recursively finds `GPUParticles3D/2D` and `CPUParticles3D/2D` nodes and sets `speed_scale`. Replace with finding `Sprite3D` nodes named `DustPuff_*` and toggling their `visible` property (or pausing their Tweens).

Since `Sprite3D` respects `get_tree().paused` by default (Tween with `TWEEN_PAUSE_PROCESS` will pause), the scene manager only needs to handle the overlay-pause case (when overlays are shown but gameplay isn't fully paused). In this case, find `DustPuff_*` Sprite3D nodes and set `visible = false`.

Simplified approach: Since Tween `TWEEN_PAUSE_PROCESS` respects scene tree pause, and `get_tree().paused` is handled by M_TimeManager, the particle pause workaround is no longer needed. Remove `_set_particles_paused()` entirely and its call site `_update_particles_and_focus()`.

- [ ] **Step 2: Clean up related variables**

Remove `_particle_original_speeds` dictionary and `_prune_particle_speed_cache()`.

- [ ] **Step 3: Run tests**

Run: `tools/run_gut_suite.sh`

- [ ] **Step 4: Commit**

```bash
git add scripts/core/managers/m_scene_manager.gd && git commit -m "(REFACTOR) Remove GPU particle pause workaround — Sprite3D dust respects scene tree pause"
```

---

## Task 6: Update BaseVolumeController particle visibility toggle

**Files:**
- Modify: `scripts/core/gameplay/base_volume_controller.gd`

- [ ] **Step 1: Replace GPUParticles3D/CPUParticles3D checks with Sprite3D check**

In `_apply_visual_visibility()`, replace:

```gdscript
if node is GPUParticles3D:
	(node as GPUParticles3D).emitting = enabled
elif node is CPUParticles3D:
	(node as CPUParticles3D).emitting = enabled
```

With:

```gdscript
if node is Sprite3D and (node as Sprite3D).name.begins_with("DustPuff_"):
	(node as Sprite3D).visible = enabled
```

- [ ] **Step 2: Run tests**

- [ ] **Step 3: Commit**

```bash
git add scripts/core/gameplay/base_volume_controller.gd && git commit -m "(FIX) Update volume controller to toggle Sprite3D dust visibility"
```

---

## Task 7: Replace goal zone CPUParticles3D sparkles with Sprite3D sparkle system

**Files:**
- Modify: `scenes/core/prefabs/prefab_goal_zone.tscn` (via builder if applicable)
- Modify: `tests/scenes/test_exterior.tscn` (via builder if applicable)
- Modify: `scripts/core/gameplay/inter_victory_zone.gd` (or add sparkle timer logic)

- [ ] **Step 1: Find the builder for prefab_goal_zone**

Search for the builder script that creates the goal zone prefab. Add a `Sprite3D` node named "Sparkles" with the same billboard material pattern, plus a timer-driven sparkle animation (2-3 puffs pulsing in scale/alpha on a cycle).

- [ ] **Step 2: Replace CPUParticles3D with Sprite3D in scene builder**

Remove the `Sparkles` CPUParticles3D node creation and replace with a `Sprite3D`-based sparkle:
- Create a `Node3D` named "Sparkles" to hold individual sparkle `Sprite3D` nodes
- Add 3 `Sprite3D` children with the dust puff texture, billboard mode
- Each pulsates in scale and alpha on a staggered cycle via `Tween` or timer

- [ ] **Step 3: Update `visual_paths` in the builder**

The `visual_paths` array currently references `NodePath("Sparkles")`. The new `Node3D` parent keeps this path working — `visible = false` on the parent hides all sparkle children.

- [ ] **Step 4: Regenerate scenes if needed**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --script tools/rebuild_scenes.gd`

- [ ] **Step 5: Update `base_volume_controller.gd` sparkle visibility**

The sparkle parent is a `Node3D`, not a `Sprite3D` with "DustPuff_" prefix. Add handling: `Node3D` in `visual_paths` already gets `.visible = enabled` (line 185). Confirm this covers sparkles.

- [ ] **Step 6: Run tests**

Run: `tools/run_gut_suite.sh`

- [ ] **Step 7: Commit**

```bash
git add scripts/ scenes/ && git commit -m "(FIX) Replace goal zone CPUParticles3D sparkles with Sprite3D billboard system"
```

---

## Task 8: Update scene builder references and VFX selectors

**Files:**
- Modify: `scripts/core/utils/editors/u_template_base_scene_builder.gd`
- Modify: `scripts/core/resources/state/rs_gameplay_initial_state.gd`
- Modify: `scripts/core/state/selectors/u_visual_selectors.gd`

- [ ] **Step 1: Update u_template_base_scene_builder.gd**

Change the references:
- `const JUMP_PARTICLES_SETTINGS := preload(...)` → `const JUMP_DUST_SETTINGS := preload(...)` (path unchanged since we're updating the .tres in place)
- `const LANDING_PARTICLES_SETTINGS := preload(...)` → same update
- `S_JumpParticlesSystem` node name → consider renaming to `S_JumpDustSystem` (or keep if ECS system class name stays)
- Verify the builder creates nodes correctly with new settings

- [ ] **Step 2: Update state/selectors**

In `u_visual_selectors.gd`, rename `jump_particles_enabled` → `jump_dust_enabled` and `landing_particles_enabled` → `landing_dust_enabled` if desired. Or keep the old names for backward compatibility.

In `rs_gameplay_initial_state.gd`, same.

- [ ] **Step 3: Run style enforcement and full suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd && tools/run_gut_suite.sh`

- [ ] **Step 4: Commit**

```bash
git add scripts/core/utils/editors/ scripts/core/resources/state/ scripts/core/state/selectors/ && git commit -m "(REFACTOR) Update builder and selector references from particles to dust"
```

---

## Task 9: Final integration verification

- [ ] **Step 1: Run full test suite**

Run: `tools/run_gut_suite.sh`

- [ ] **Step 2: Run style enforcement**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`

- [ ] **Step 3: Verify no GPUParticles3D references remain**

```bash
grep -rn "GPUParticles3D\|CPUParticles3D\|ParticleProcessMaterial\|U_ParticleSpawner\|ParticleConfig" scripts/ tests/ --include="*.gd"
```

Expected: No results (all replaced with Sprite3D/U_DustSpawner/DustConfig).

- [ ] **Step 4: Verify dust puffs visible in-game (manual check)**

Launch the game, trigger jump and landing effects, verify Sprite3D puffs appear and animate correctly.

- [ ] **Step 5: Commit any fixes**