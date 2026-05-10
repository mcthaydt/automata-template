# Scene Manager Overview

`M_SceneManager` coordinates scene transitions, overlays, active-scene lifecycle, transition effects, loading, camera handoff, and scene-cache behavior. The project uses a persistent root scene; gameplay scenes are loaded under `ActiveSceneContainer`.

## Root Architecture

- `scenes/root.tscn` persists for the full session.
- Root owns persistent managers: `M_StateStore`, `M_CursorManager`, `M_SceneManager`, UI overlay/transition/loading layers, and other app-level managers.
- Gameplay scenes must not contain `M_StateStore` or `M_CursorManager`.
- Each gameplay scene owns its own `M_ECSManager`.
- `ActiveSceneContainer` manages active gameplay/menu scene children. Do not manually add/remove children; use `M_SceneManager` APIs.
- Tests should not instantiate `root.tscn`; instantiate concrete gameplay scenes or helper harnesses directly.

## Scene Registration

Scene registration has three layers:

1. Boot-critical scenes are hardcoded in `U_SceneRegistry` so the app can always reach the splash, language selector, main menu, pause menu, save/load menu, loading screen, and test scenes.
2. Manifest/resource entries load next. These provide explicit metadata overrides and the mobile/web-safe generated baseline where runtime directory scans are not used.
3. Convention-derived entries load in editor/headless development contexts, after explicit entries and before optional development resource-directory scans. Duplicate scene ids are skipped, so hardcoded and manifest/resource metadata wins.

Convention-derived scene ids come from filenames:

```gdscript
res://scenes/demo/gameplay/gameplay_demo_room.tscn -> demo_room
res://scenes/core/ui/overlays/ui_save_load_menu.tscn -> save_load_menu
res://scenes/core/ui/settings/ui_settings_panel.tscn -> settings_panel
```

`U_SceneConventionScanner` maps gameplay scenes to `SceneType.GAMEPLAY`, `loading`, priority `5`, and supported UI overlay/settings scenes to `SceneType.UI`, `instant`, priority `5`. Prefabs, templates, and UI widgets are ignored.

Create new `.tscn` files through builders/editor tooling, not by hand. Add an `RS_SceneRegistryEntry` or manifest entry when a scene needs custom type, transition, priority, export-safe generated metadata, or an intentional override.

Preload priority guidelines:

- `10`: critical UI such as main menu and pause menu.
- `5-7`: frequently accessed scenes.
- `0-4`: occasional scenes.
- `0`: no preload; load on demand.

`M_SceneManager._ready()` validates door pairings through `U_SceneRegistry.validate_door_pairings()`. Invalid pairings log errors at startup.

## Default Gameplay Scene

The default New Game/startup gameplay scene is configured in `resources/core/cfg_game_config.tres` with `default_gameplay_scene_id`.

- Main menu New Game routing uses `default_gameplay_scene_id`.
- Splash and debug-skip background preloading use `default_gameplay_scene_id`.
- Save-state normalization falls back to `default_gameplay_scene_id` when a loaded scene id is blank or invalid.
- `retry_scene_id` is an optional override. Leave it empty to retry from `default_gameplay_scene_id`.

When changing the starting gameplay scene, update `resources/core/cfg_game_config.tres` and ensure the target scene id is registered in the scene registry.

## Transitions

Access the manager through the service locator:

```gdscript
var scene_manager := U_ServiceLocator.get_service(StringName("scene_manager")) as M_SceneManager
scene_manager.transition_to_scene(StringName("scene_id"))
scene_manager.transition_to_scene(StringName("scene_id"), "fade")
scene_manager.transition_to_scene(
	StringName("game_over"),
	"fade",
	M_SceneManager.Priority.CRITICAL
)
```

Transition types:

- `instant`: fast UI navigation.
- `fade`: fade out, load, fade in.
- `loading`: loading screen with progress bar for large scenes.

Transition selection priority:

1. Explicit transition type parameter.
2. Registry default from `U_SceneRegistry.get_default_transition()`.
3. Fallback to `instant`.

Priority levels:

- `NORMAL = 0`: standard navigation.
- `HIGH = 1`: important but not urgent.
- `CRITICAL = 2`: death/game-over style transitions; jump to the front of the queue.

Transition callbacks use `U_TransitionState` for mutable shared callback state. Do not reintroduce `Array` wrapper captures.

## Overlay Management

Overlay APIs exist on `M_SceneManager`, but UI controllers should route through Redux navigation actions whenever possible.

- `push_overlay(StringName("pause_menu"))`
- `pop_overlay()`
- `push_overlay_with_return(StringName("settings_menu"))`
- `pop_overlay_with_return()`
- `go_back()` for UI history.

`BaseOverlay`/root overlay layers must run while paused. Overlay reconciliation may be deferred during base scene transitions.

## Scene Triggers and Doors

Door/interactable scene transitions should use controller/config patterns rather than ad-hoc scene-tree manipulation.

- Register bidirectional door pairings in `U_SceneRegistry._register_door_pairings()`.
- Use trigger shape resources; avoid non-uniform node scaling.
- Use `local_offset` to align trigger shape with visual geometry.
- Set `cooldown_duration` to at least `1.0` second to prevent re-triggering during fade/spawn.
- Place spawn markers outside trigger zones to avoid ping-pong loops.
- Scene triggers can hint preload target scenes on proximity before activation.
- `U_ECSEventBus.publish()` wraps payloads in an event dictionary; unwrap `event["payload"]` when listening to prompt/signpost events.

## Spawn Points

- Spawn marker naming: `sp_` prefix, for example `sp_entrance_from_exterior`.
- Spawn markers live under `Entities/SpawnPoints`.
- A scene should provide `sp_default` for initial/fallback loads.
- Place spawn markers 2-3 units outside trigger zones.
- `M_SpawnManager` applies spawn on scene load with priority:
  - `target_spawn_point`
  - `last_checkpoint`
  - `sp_default`

Invalid checkpoints from another scene fall back to `sp_default`.

## State Persistence

- The `gameplay` slice persists across transitions through `StateHandoff`.
- Modify gameplay state through `U_GameplayActions`; do not mutate fields directly.
- Use `U_StateUtils.get_store(self)` after one process frame for scene/UI scripts that need store access.
- Transient transition fields, such as `is_transitioning` and `transition_type`, are excluded from saves.

## Camera Blending

- Camera blending is for `GAMEPLAY -> GAMEPLAY` transitions only.
- Both scenes must have `SceneType.GAMEPLAY`.
- Both scenes must expose a `Camera3D` in the `main_camera` group or through camera-manager registration.
- The transition type must be `fade`.
- Blend finalization checks must use `I_CameraManager.is_blend_active()`, not private-member reflection.
- Camera blend runs in the background and does not block state updates.

## Loading and Cache

- Critical scenes with `preload_priority >= 10` load at startup.
- Scene cache is LRU with count and memory limits.
- Preload hints dedupe already-cached/loading scenes.
- Async loading progress requires a loading-screen callback such as `update_progress(progress: float)`.
- Headless tests may use sync loading fallback when threaded loading stalls.

Performance targets:

- UI transitions: under `0.5s`.
- Gameplay transitions: under `3s`.
- Large scenes: under `5s` with loading screen.

## Pitfalls

- **Root scene architecture is mandatory**: persistent managers live only in `root.tscn`; gameplay scenes own only per-scene systems/managers such as `M_ECSManager`.
- **HUD/UI store lookup must use `U_StateUtils`**: direct parent traversal fails because the store lives in root while UI may live under child scenes.
- **Godot UIDs must be managed by Godot**: do not manually author scene UIDs.
- **Moving `class_name` scripts can require cache regeneration**: delete `.godot/global_script_class_cache.cfg` and `.godot/uid_cache.bin` when stale class paths break headless loads.
- **Fade tests need adequate wait time**: default fade is `0.2s`; wait at least 15 physics frames before asserting completion.
- **Tween process mode must match the wait loop**: physics tweens need physics-frame waits; idle tweens need process-frame waits.
- **Paused SceneTree stalls tweens/timers unless owners run while paused**: transition overlay nodes should temporarily use `PROCESS_MODE_ALWAYS` during fades.
- **Do not kill a Tween before `finished`**: cleanup should run from `finished` or a final `tween_callback`.
- **ESC must be ignored during active transitions**: pause during fade/loading can freeze transitions.
- **Transition queue uses priority sorting**: tests that spam transitions should assert the highest-priority request wins.
- **Scene cache has dual limits**: count and memory. Preloaded critical scenes still count.
- **Controllers expect no authored components**: do not add extra `C_*` component nodes or manual `Area3D` children to `E_*` interactable controllers.
- **Cooldown must exceed transition duration**: `1.0s` minimum is recommended.
- **Tween timing tests may be pending in headless mode**: visual timing should be manually validated in editor when needed.

## Verification

- Unit/integration suites under `tests/integration/scene_manager/`.
- Style and structure guard: `tests/unit/style/test_style_enforcement.gd`.
- Scene authoring guide: `docs/systems/scene_manager/ADDING_SCENES_GUIDE.md`.
