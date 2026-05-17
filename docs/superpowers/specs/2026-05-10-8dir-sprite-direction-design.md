# 8-Directional Sprite Direction System

## Status

Design approved. Ready for implementation.

## Overview

A new ECS component + system pair that drives 8-directional sprite selection on `Sprite3D` or `AnimatedSprite3D` nodes, adapted to the current camera yaw. Follows the Xenogears-style model: the sprite shows which side of the character the camera is looking at when idle, and which direction the character is moving when in motion.

## Component: `C_SpriteDirectionComponent`

**File:** `scripts/core/ecs/components/c_sprite_direction_component.gd`
**Extends:** `BaseECSComponent`

### Exported Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `target_node_path` | `NodePath` | — | Path to `Sprite3D` or `AnimatedSprite3D` on the entity |
| `animation_prefix` | `String` | `""` | Current intent prefix (e.g. `"idle"`, `"walk"`, `"talk"`). Written by external animation state systems; never written by this system. |
| `direction_mode` | `enum { AUTO, SPRITE3D, ANIMATED_SPRITE3D }` | `AUTO` | AUTO detects node type at runtime |
| `frame_layout` | `enum { SOUTH_FIRST, NORTH_FIRST }` | `SOUTH_FIRST` | `SOUTH_FIRST`: frame 0 = `down`, frame index = direction index directly. `NORTH_FIRST`: frame 0 = `up`, frame index = `(direction_index + 4) % 8`. `Sprite3D` mode only. |
| `facing_override` | `Vector3` | `Vector3.ZERO` | When non-zero, used as world-space facing vector regardless of velocity or body rotation. Written by AI systems for idle NPC facing. |

### Read-Only Output Fields

| Field | Type | Description |
|---|---|---|
| `current_direction_index` | `int` | Last computed direction index (0–7) |
| `current_direction_name` | `String` | Last computed direction name (e.g. `"down"`, `"up_right"`) |

## Direction Layout

8 directions clockwise from toward-camera, matching screen-relative intent naming:

| Index | Name | Compass |
|---|---|---|
| 0 | `down` | S — facing camera |
| 1 | `down_right` | SW |
| 2 | `right` | W |
| 3 | `up_right` | NW |
| 4 | `up` | N — facing away |
| 5 | `up_left` | NE |
| 6 | `left` | E |
| 7 | `down_left` | SE |

## System: `S_SpriteDirectionSystem`

**File:** `scripts/core/ecs/systems/s_sprite_direction_system.gd`
**Extends:** `BaseECSSystem`
**Phase:** `VFX` (after `PHYSICS_SOLVE` and `CAMERA` so both velocity and camera position are settled)

### Query

Required: `[C_SpriteDirectionComponent, C_MovementComponent]`
Optional: none

No `C_InputComponent` required — NPC compatible by default.

### Per-Tick Logic Per Entity

1. Resolve target sprite node from `target_node_path`; on failure log once and skip entity permanently
2. Determine **facing vector** using priority order:
   1. `facing_override` if non-zero
   2. Horizontal velocity if `velocity.length() > move_threshold` (default `0.1`)
   3. Body `global_rotation.y` (idle fallback — works for both player and AI-rotated NPCs)
3. Get camera yaw via `ECS_UTILS.get_active_camera()`; if no camera skip direction update (sprite holds last frame)
4. Handle degenerate camera pitch (near ±90°): use world-space facing directly instead of projecting through camera space
5. Compute relative angle = `atan2` of facing vector in camera space
6. Quantize to direction index 0–7 using 45° buckets with half-step offset (transitions at midpoints, not at cardinal edges)
7. If index unchanged since last tick, skip sprite update
8. Drive sprite:
   - `AnimatedSprite3D`: play `"{prefix}_{direction_name}"` if prefix non-empty, else `"{direction_name}"`; log warning if clip missing
   - `Sprite3D`: set `frame = direction_index` adjusted for `frame_layout`; log warning if frame count < 8
9. Write `current_direction_index` and `current_direction_name` back to component

No state store dispatch. Direction is a pure visual output; consumers read from the component directly.

## Data Flow

```
S_MovementSystem (PHYSICS_SOLVE)
  → body.velocity settled

S_RotateToInputSystem (PHYSICS_SOLVE)
  → body.global_rotation.y settled

[CAMERA phase]
  → active Camera3D position/basis settled

S_SpriteDirectionSystem (VFX)
  reads: body.velocity, body.global_rotation.y, C_SpriteDirectionComponent.facing_override
  reads: ECS_UTILS.get_active_camera() yaw
  writes: Sprite3D.frame  OR  AnimatedSprite3D.play()
  writes: C_SpriteDirectionComponent.current_direction_index/name
```

## Animation Naming Contract

For `AnimatedSprite3D` mode, animation clips must be named `{prefix}_{direction_name}` or just `{direction_name}` when no prefix is set.

Examples: `idle_down`, `walk_up_right`, `talk_left`, `down` (no prefix).

The `animation_prefix` field is the integration point for external animation state systems. It defaults to `""` and is never modified by `S_SpriteDirectionSystem`.

## Edge Cases

| Condition | Behavior |
|---|---|
| No active camera | Skip direction update; sprite holds last frame; one-shot debug warning |
| Camera pitch near ±90° | Use world-space facing directly, skip camera-space projection |
| Target node missing or wrong type | Log error once per entity; skip permanently |
| First frame after spawn (no velocity) | Treat as idle; use body rotation |
| Sprite sheet frame count < 8 | Log warning; clamp frame index to `frame_count - 1` |
| Animation clip missing | Log warning with attempted clip name |
| `animation_prefix` changes mid-tick | No special handling; read fresh each tick |

## Testing Plan

Unit tests at `tests/unit/ecs/`:

- Direction quantization: all 8 angle ranges map to correct index, including boundary midpoints
- `facing_override` non-zero: uses override vector, ignores velocity and body rotation
- Moving: velocity-derived direction used
- Idle: body-rotation-derived direction used
- `AnimatedSprite3D` mode: correct clip name composed; no redundant call when direction unchanged
- `Sprite3D` mode: correct frame index for both `SOUTH_FIRST` and `NORTH_FIRST` layouts
- Missing target node: error logged, entity skipped, no crash
- No active camera: direction skipped, no crash

## Files to Create

| File | Type |
|---|---|
| `scripts/core/ecs/components/c_sprite_direction_component.gd` | New component |
| `scripts/core/ecs/systems/s_sprite_direction_system.gd` | New system |
| `tests/unit/ecs/components/test_sprite_direction_component.gd` | Unit tests |
| `tests/unit/ecs/systems/test_sprite_direction_system.gd` | Unit tests |
