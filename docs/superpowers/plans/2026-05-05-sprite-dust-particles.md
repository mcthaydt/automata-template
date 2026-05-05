# Landing Cloud-Expanding Particle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace single-frame dust puff with 4-frame cartoon smoke puff sprite sheet for landing particles.

**Architecture:** Generate a 4-frame 128×32 sprite sheet via pixellab, then extend `U_DustSpawner` to support `AnimatedSprite3D` when a sprite sheet is configured. Add flags to `RS_LandingParticlesSettings` so landing particles use the cloud animation by default.

**Tech Stack:** Godot 4.7, GDScript, pixellab API, GUT tests

---

### Task 1: Generate Sprite Sheet Asset via pixellab

**Files:**
- Create: `assets/core/textures/tex_landing_cloud.png`
- Delete: (none)

**No automated test for this task.** Visual review only.

- [ ] **Step 1: Call pixellab_create_object**

```json
{
  "description": "cartoon smoke puff expanding, soft rounded shape, light gray, pixel art",
  "directions": 1,
  "n_frames": 4,
  "size": 32
}
```

- [ ] **Step 2: Review returned frames**

Call `pixellab_get_object` with the object ID from Step 1. Wait for status `"completed"`.

- [ ] **Step 3: Download the 4 frame images and combine into a horizontal sprite sheet**

Use Python/Pillow to combine 4 frames horizontally into one 128×32 PNG. Save as:

```
assets/core/textures/tex_landing_cloud.png
```

Python snippet (run in a temporary script or inline):

```python
from PIL import Image
import sys

frames = [Image.open(f"frame_{i}.png") for i in range(4)]
for f in frames:
    assert f.size == (32, 32), f"Unexpected frame size: {f.size}"
sheet = Image.new("RGBA", (128, 32))
for i, f in enumerate(frames):
    sheet.paste(f, (i * 32, 0))
sheet.save("assets/core/textures/tex_landing_cloud.png")
```

- [ ] **Step 4: Verify the file exists and is 128×32**

```bash
file assets/core/textures/tex_landing_cloud.png
```

Expected output contains: `PNG image data, 128 x 32`

- [ ] **Step 5: Commit asset**

```bash
git add assets/core/textures/tex_landing_cloud.png
git commit -m "(ASSET) Add landing cloud sprite sheet"
```

---

### Task 2: Add Sprite Sheet Support to U_DustSpawner

**Files:**
- Modify: `scripts/core/utils/u_dust_spawner.gd`

**Tests:**
- Test file: `tests/unit/utils/test_dust_spawner.gd`
- New tests: (listed in each step)

- [ ] **Step 1: Add `sprite_sheet_frames` and `sprite_sheet_texture` to `DustConfig`**

Add two new fields inside `class DustConfig` in `scripts/core/utils/u_dust_spawner.gd`:

```gdscript
var sprite_sheet_frames: int = 0
var sprite_sheet_texture: Texture2D = null
```

Update `_init` signature and assignments:

```gdscript
func _init(
    p_count: int = 10,
    p_lifetime: float = 0.5,
    p_scale: float = 0.3,
    p_spread: float = 0.4,
    p_drift: Vector3 = Vector3.UP,
    p_spawn_offset: Vector3 = Vector3.ZERO,
    p_vertical_spread_scale: float = 1.0,
    p_sprite_sheet_frames: int = 0,
    p_sprite_sheet_texture: Texture2D = null
) -> void:
    count = p_count
    lifetime = p_lifetime
    scale = p_scale
    spread = p_spread
    drift = p_drift
    spawn_offset = p_spawn_offset
    vertical_spread_scale = maxf(p_vertical_spread_scale, 0.0)
    sprite_sheet_frames = maxi(p_sprite_sheet_frames, 0)
    sprite_sheet_texture = p_sprite_sheet_texture
```

- [ ] **Step 2: Run existing dust spawner tests to ensure no regressions**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_dust_spawner.gd
```

Expected: PASS

- [ ] **Step 3: Update `spawn_dust` to create `AnimatedSprite3D` when sprite sheet configured**

Inside `spawn_dust()`, replace the inner loop body that creates `Sprite3D`:

```gdscript
for i in range(config.count):
    var puff: Node3D
    if config.sprite_sheet_frames > 0 and config.sprite_sheet_texture != null:
        var anim_sprite := AnimatedSprite3D.new()
        anim_sprite.name = DUST_PUFF_NAME_PREFIX + str(i)
        var sprite_frames := SpriteFrames.new()
        sprite_frames.add_animation("default")
        sprite_frames.set_animation_speed("default", config.sprite_sheet_frames / config.lifetime)
        var frame_count := config.sprite_sheet_frames
        for f in range(frame_count):
            var atlas := AtlasTexture.new()
            atlas.atlas = config.sprite_sheet_texture
            atlas.region = Rect2(f * 32, 0, 32, 32)
            sprite_frames.add_frame("default", atlas)
        anim_sprite.sprite_frames = sprite_frames
        anim_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        anim_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        anim_sprite.autoplay = "default"
        puff = anim_sprite
    else:
        var sprite := Sprite3D.new()
        sprite.name = DUST_PUFF_NAME_PREFIX + str(i)
        sprite.texture = DUST_PUFF_TEXTURE
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        sprite.material_override = material
        sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        sprite.scale = Vector3.ZERO
        puff = sprite

    container.add_child(puff)
    puff.global_position = position + config.spawn_offset + Vector3(
        (randf() - 0.5) * 2 * config.spread,
        (randf() - 0.5) * 2 * config.spread * config.vertical_spread_scale,
        (randf() - 0.5) * 2 * config.spread
    )

    if config.sprite_sheet_frames > 0 and config.sprite_sheet_texture != null:
        _animate_cloud(puff as AnimatedSprite3D, config)
    else:
        _animate_puff(puff as Sprite3D, config)
```

- [ ] **Step 4: Add `_animate_cloud` method**

Add `_animate_cloud` to `u_dust_spawner.gd`:

```gdscript
func _animate_cloud(cloud: AnimatedSprite3D, config: DustConfig) -> void:
    var tween := cloud.create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    var phase1_dur := config.lifetime * 0.3
    var phase2_dur := config.lifetime * 0.2
    var phase3_dur := config.lifetime * 0.5
    var scale_vec := Vector3(config.scale, config.scale, config.scale)
    cloud.scale = Vector3.ZERO
    tween.tween_property(cloud, "scale", scale_vec, phase1_dur)
    tween.tween_interval(phase2_dur)
    tween.parallel().tween_property(cloud, "modulate:a", 0.0, phase3_dur)
    tween.parallel().tween_property(cloud, "position", cloud.position + config.drift * config.lifetime, phase3_dur)
    tween.tween_callback(cloud.queue_free)
```

- [ ] **Step 5: Write failing tests for sprite-sheet cloud spawning**

Add to `tests/unit/utils/test_dust_spawner.gd`:

```gdscript
func test_dust_config_accept_sprite_sheet_fields() -> void:
    var texture := GradientTexture2D.new()
    var config := DUST_SPAWNER.DustConfig.new(
        5, 0.5, 0.3, 0.4, Vector3.UP, Vector3.ZERO, 1.0, 4, texture
    )
    assert_eq(config.sprite_sheet_frames, 4)
    assert_eq(config.sprite_sheet_texture, texture)

func test_spawn_dust_with_sprite_sheet_creates_animated_sprite3d() -> void:
    var spawner := DUST_SPAWNER.new()
    var texture := ImageTexture.create_from_image(Image.create(128, 32, false, Image.FORMAT_RGBA8))
    var config := DUST_SPAWNER.DustConfig.new(3, 0.6, 0.3, 0.4, Vector3.UP, Vector3.ZERO, 1.0, 4, texture)
    var container := Node3D.new()
    add_child(container)
    autofree(container)

    spawner.spawn_dust(Vector3.ZERO, container, config)

    assert_eq(container.get_child_count(), 3, "Should create 3 cloud nodes")
    for child in container.get_children():
        assert_true(child is AnimatedSprite3D, "Each child should be AnimatedSprite3D when sprite_sheet_frames > 0")

func test_spawn_dust_without_sprite_sheet_creates_sprite3d() -> void:
    var spawner := DUST_SPAWNER.new()
    var config := DUST_SPAWNER.DustConfig.new(3, 0.6, 0.3, 0.4, Vector3.UP, Vector3.ZERO, 1.0, 0, Texture2D.new())
    var container := Node3D.new()
    add_child(container)
    autofree(container)

    spawner.spawn_dust(Vector3.ZERO, container, config)

    assert_eq(container.get_child_count(), 3, "Should create 3 puff nodes")
    for child in container.get_children():
        assert_true(child is Sprite3D, "Each child should be Sprite3D when sprite_sheet_frames == 0")

func test_cloud_animated_sprite_has_sprite_frames() -> void:
    var spawner := DUST_SPAWNER.new()
    var texture := ImageTexture.create_from_image(Image.create(128, 32, false, Image.FORMAT_RGBA8))
    var config := DUST_SPAWNER.DustConfig.new(1, 0.6, 0.3, 0.4, Vector3.UP, Vector3.ZERO, 1.0, 4, texture)
    var container := Node3D.new()
    add_child(container)
    autofree(container)

    spawner.spawn_dust(Vector3.ZERO, container, config)

    var cloud := container.get_child(0) as AnimatedSprite3D
    assert_not_null(cloud, "Cloud should be AnimatedSprite3D")
    assert_not_null(cloud.sprite_frames, "Cloud should have SpriteFrames assigned")
    assert_eq(cloud.sprite_frames.get_frame_count("default"), 4, "SpriteFrames default anim should have 4 frames")
    assert_true(cloud.autoplay == "default" or cloud.animation == "default", "Cloud should be playing default animation")
```

- [ ] **Step 6: Run new tests, expect FAIL**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_dust_spawner.gd
```

Expected: FAIL (Sprite3D tests still pass; new AnimatedSprite3D tests fail because `_animate_cloud` and sprite frame creation are not yet wired)

- [ ] **Step 7: Run full test suite**

```bash
tools/run_gut_suite.sh
```

Expected: Pass (minus known mobile/joy failures unrelated to this task)

- [ ] **Step 8: Commit**

```bash
git add scripts/core/utils/u_dust_spawner.gd tests/unit/utils/test_dust_spawner.gd
git commit -m "(FEAT) Add sprite-sheet cloud support to U_DustSpawner"
```

---

### Task 3: Update Landing Particles Settings

**Files:**
- Modify: `scripts/core/resources/ecs/rs_landing_particles_settings.gd`
- Recreate: `resources/core/base_settings/gameplay/cfg_landing_particles_default.tres`

**Tests:**
- Test file: `tests/unit/ecs/systems/test_landing_particles_system.gd`

- [ ] **Step 1: Add cloud animation fields to settings resource**

Add inside `scripts/core/resources/ecs/rs_landing_particles_settings.gd` after existing exports:

```gdscript
@export_group("Cloud Animation")
@export var use_cloud_animation: bool = true
@export var cloud_frame_count: int = 4
```

- [ ] **Step 2: Update default resource `.tres`**

`cfg_landing_particles_default.tres` must be recreated because the script changed (Godot may auto-update exports, but for format_version=5 with uids, it's safer to recreate via builder or let Godot rewrite on open). Use the script to generate it, or manually add lines:

```
use_cloud_animation = true
cloud_frame_count = 4
```

Place them at the end of the `[resource]` block, after `drift_direction`.

- [ ] **Step 3: Write failing tests for new settings fields**

Add to `tests/unit/ecs/systems/test_landing_particles_system.gd`:

```gdscript
func test_settings_use_cloud_animation_default() -> void:
    var settings := SETTINGS.new()
    assert_eq(settings.use_cloud_animation, true, "use_cloud_animation should default to true")

func test_settings_cloud_frame_count_default() -> void:
    var settings := SETTINGS.new()
    assert_eq(settings.cloud_frame_count, 4, "cloud_frame_count should default to 4")

func test_settings_use_cloud_animation_configurable() -> void:
    var settings := SETTINGS.new()
    settings.use_cloud_animation = false
    assert_eq(settings.use_cloud_animation, false, "use_cloud_animation should be configurable")

func test_settings_cloud_frame_count_configurable() -> void:
    var settings := SETTINGS.new()
    settings.cloud_frame_count = 8
    assert_eq(settings.cloud_frame_count, 8, "cloud_frame_count should be configurable")

func test_landing_dust_config_includes_cloud_settings() -> void:
    var context := await _create_system_with_settings()
    autofree_context(context)
    var system: S_LandingParticlesSystem = context["system"]
    var settings: RS_LandingParticlesSettings = context["settings"]
    settings.use_cloud_animation = true
    settings.cloud_frame_count = 4

    var config := system._create_dust_config()
    assert_eq(config.sprite_sheet_frames, 4, "Config should include cloud_frame_count")
    assert_not_null(config.sprite_sheet_texture, "Config should include sprite sheet texture when use_cloud_animation is true")
```

- [ ] **Step 4: Run new tests, expect FAIL**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_landing_particles_system.gd
```

Expected: FAIL (last test fails because `_create_dust_config` doesn't yet set `sprite_sheet_frames` / `sprite_sheet_texture`)

- [ ] **Step 5: Commit**

```bash
git add scripts/core/resources/ecs/rs_landing_particles_settings.gd tests/unit/ecs/systems/test_landing_particles_system.gd
git commit -m "(FEAT) Add cloud animation settings to RS_LandingParticlesSettings"
```

---

### Task 4: Update Landing Particles System

**Files:**
- Modify: `scripts/core/ecs/systems/s_landing_particles_system.gd`

**Tests:**
- Test file: `tests/unit/ecs/systems/test_landing_particles_system.gd`

- [ ] **Step 1: Update `_create_dust_config()` to pass sprite-sheet data**

Update `s_landing_particles_system.gd`:

```gdscript
const CLOUD_TEXTURE := preload("res://assets/core/textures/tex_landing_cloud.png")
```

Replace the existing `_create_dust_config()` method with:

```gdscript
func _create_dust_config() -> DUST_SPAWNER.DustConfig:
    var config := DUST_SPAWNER.DustConfig.new(
        settings.count,
        settings.lifetime,
        settings.scale,
        settings.spread,
        settings.drift_direction * settings.drift_strength,
        settings.spawn_offset,
        0.05
    )
    if settings.use_cloud_animation and settings.cloud_frame_count > 0:
        config.sprite_sheet_frames = settings.cloud_frame_count
        config.sprite_sheet_texture = CLOUD_TEXTURE
    return config
```

- [ ] **Step 2: Run landing particles tests, expect PASS**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_landing_particles_system.gd
```

Expected: PASS

- [ ] **Step 3: Run full test suite**

```bash
tools/run_gut_suite.sh
```

Expected: Pass (minus known failures)

- [ ] **Step 4: Commit**

```bash
git add scripts/core/ecs/systems/s_landing_particles_system.gd
git commit -m "(FEAT) Wire landing particles to cloud sprite sheet"
```

---

## Spec Coverage Checklist

| Spec Requirement | Plan Task |
|------------------|-----------|
| Generate 4-frame sprite sheet via pixellab | Task 1 |
| Save as `assets/core/textures/tex_landing_cloud.png` | Task 1 |
| Add `sprite_sheet_frames` / `sprite_sheet_texture` to `DustConfig` | Task 2, Step 1 |
| Create `AnimatedSprite3D` when sprite sheet configured | Task 2, Step 3 |
| Add `_animate_cloud` for sprite-sheet lifecycle | Task 2, Step 4 |
| Backward compatibility (no sprite sheet → old behavior) | Task 2, Step 3 inline if/else |
| Add `use_cloud_animation` / `cloud_frame_count` to settings | Task 3, Step 1 |
| Update default `.tres` | Task 3, Step 2 |
| Wire landing system to pass config fields | Task 4, Step 1 |
| Tests for new config, spawning, and settings | Task 2 Steps 5-6, Task 3 Steps 3-4 |

## Placeholder Scan

- No TBD, TODO, or "fill in later" statements.
- Every test includes exact assertion code.
- Every task references an exact file path.
- Type/method names are consistent across tasks (`AnimatedSprite3D`, `SpriteFrames`, `AtlasTexture`, `DustConfig.sprite_sheet_frames`, etc.).
