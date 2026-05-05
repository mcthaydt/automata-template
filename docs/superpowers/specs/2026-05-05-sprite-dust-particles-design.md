# Design: Landing Cloud-Expanding Particle

## Summary

Replace the single-frame dust puff with a 4-frame cartoon smoke puff sprite sheet animation for landing particles. The effect triggers at the entity's landing position on the ground, playing through 4 frames of expanding cloud shapes before auto-cleaning up.

## Visual Description

4-frame horizontal sprite sheet (128×32 total, 32×32 per frame). Cartoon smoke puff style: soft rounded shapes, light gray/white tones, clean pixel-art style. Frames show a progression from small tight puff to large dissipating cloud.

## Asset Generation

Use `pixellab_create_object`:
- **directions=1**
- **n_frames=4**
- **size=32**
- **view="side"**
- **description="cartoon smoke puff expanding, soft rounded shape, light gray, pixel art"**

After generation:
1. Review the 4 candidate frames
2. Download images and combine into a horizontal sprite sheet (128×32)
3. Save as `assets/core/textures/tex_landing_cloud.png`

## Code Changes

### U_DustSpawner

Add `sprite_sheet_frames: int = 0` to `DustConfig`.

When `sprite_sheet_frames > 0`:
- Create an `AnimatedSprite3D` node instead of `Sprite3D`
- Load `tex_landing_cloud.png` as `SpriteFrames` atlas with `sprite_sheet_frames` horizontal frames
- Set `playing = true`, `frame = 0`
- On `animation_finished`, call `queue_free`

When `sprite_sheet_frames == 0`: keep existing `Sprite3D` + Tween behavior.

### RS_LandingParticlesSettings

Add:
- `@export var use_cloud_animation: bool = true`
- `@export var cloud_frame_count: int = 4`

### S_LandingParticlesSystem

Update `_create_dust_config()` to pass `cloud_frame_count` to `DustConfig` when `use_cloud_animation` is true.

## Integration

- Fully backward compatible — dust puffs without sprite sheet still work via existing Tween scale animation
- Only landing particles affected; spawn and jump effects keep current behavior unless explicitly configured
- No changes to VFX manager, scene manager, or state slice

## Testing

- `test_dust_spawner.gd`: verify AnimatedSprite3D creation and cleanup when `sprite_sheet_frames > 0`
- `test_landing_particles_system.gd`: verify new config fields propagate correctly

## Files Affected

| File | Change |
|------|--------|
| `assets/core/textures/tex_landing_cloud.png` | **New** — sprite sheet asset |
| `scripts/core/utils/u_dust_spawner.gd` | Add sprite-sheet path to `spawn_dust()` and `_animate_puff()` |
| `scripts/core/resources/ecs/rs_landing_particles_settings.gd` | Add `use_cloud_animation` and `cloud_frame_count` |
| `scripts/core/ecs/systems/s_landing_particles_system.gd` | Pass new config fields to dust config |
| `tests/unit/utils/test_dust_spawner.gd` | Add sprite-sheet tests |
| `tests/unit/ecs/systems/test_landing_particles_system.gd` | Add config field tests |
