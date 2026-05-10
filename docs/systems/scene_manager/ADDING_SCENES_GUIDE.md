# Adding Scenes

Most scenes register from their file path convention. Scene registry resources remain available for explicit overrides, generated export baselines, and advanced module support.

## How to Add a New Scene

### Option 1: Convention-First Authoring

1. Create the scene through an editor/builder workflow. Do not create `.tscn` files by hand.
2. Save gameplay scenes as `gameplay_<name>.tscn` under a `scenes/**/gameplay/` folder.
3. Save UI overlays and settings panels as `ui_<name>.tscn` under `scenes/core/ui/overlays/` or `scenes/core/ui/settings/`.
4. Use the filename without the prefix as the scene id:
   - `res://scenes/demo/gameplay/gameplay_demo_room.tscn` -> `demo_room`
   - `res://scenes/core/ui/overlays/ui_save_load_menu.tscn` -> `save_load_menu`
5. Restart the editor/game or rerun the test so `U_SceneRegistryLoader` scans convention paths in editor/headless contexts.

Convention defaults:

| Path convention | Scene type | Transition | Preload priority |
|-----------------|------------|------------|------------------|
| `**/gameplay/gameplay_*.tscn` | `GAMEPLAY` | `loading` | `5` |
| `core/ui/overlays/ui_*.tscn` | `UI` | `instant` | `5` |
| `core/ui/settings/ui_*.tscn` | `UI` | `instant` | `5` |

Ignored scene folders include `prefabs`, `templates`, and `core/ui/widgets`; these are dependencies, not directly routed scenes.

### Option 2: Registry Resource Override

Create an `RS_SceneRegistryEntry` resource when a scene needs non-default metadata, a generated mobile/web manifest entry, or advanced module registration.

1. In Godot editor, go to `FileSystem` -> `resources/core/scene_registry/`.
2. Right-click -> `New Resource`.
3. Search for and select `RS_SceneRegistryEntry`.
4. Configure the resource properties:
   - **scene_id**: Unique name, for example `my_level`.
   - **scene_path**: Path to the `.tscn` file.
   - **scene_type**: `MENU`, `GAMEPLAY`, `UI`, or `END_GAME`.
   - **default_transition**: `instant`, `fade`, or `loading`.
   - **preload_priority**: `0-10`, with `10` for boot-critical scenes.
5. Save as `cfg_<scene_name>_entry.tres`.

Explicit hardcoded and manifest/resource entries win over convention-derived entries when scene ids collide.

### Option 3: Via GDScript

```gdscript
var entry := RS_SceneRegistryEntry.new()
entry.scene_id = "my_level"
entry.scene_path = "res://scenes/levels/my_level.tscn"
entry.scene_type = 1  # GAMEPLAY
entry.default_transition = "fade"
entry.preload_priority = 5
ResourceSaver.save(entry, "res://resources/core/scene_registry/cfg_my_level_entry.tres")
```

## Scene Type Guide

- **MENU (0)**: Main menu and shell scenes.
- **GAMEPLAY (1)**: Interactive levels; hides cursor and allows pause.
- **UI (2)**: Overlays and panels such as pause, settings, and save/load.
- **END_GAME (3)**: Game over, victory, and credits scenes.

## Changing The Starting Gameplay Scene

After registering a gameplay scene, set `default_gameplay_scene_id` in `resources/core/cfg_game_config.tres` to make it the New Game/startup preload target.

`retry_scene_id` in the same resource is optional. Leave it empty when retries should use `default_gameplay_scene_id`; set it only when retry should restart somewhere else.

## Preload Priority Guide

- **10-15**: Critical scenes (main menu, pause) - preloaded at startup
- **5-9**: Common scenes - preloaded when memory allows
- **0-4**: Rare scenes - loaded on-demand

**Note**: Preloaded scenes transition instantly (< 0.5s). On-demand scenes take 1-3s to load.

## Example Scenes

**Convention-derived scenes**:
- `gameplay_demo_room.tscn`: `demo_room`, GAMEPLAY, loading, priority 5
- `ui_save_load_menu.tscn`: `save_load_menu`, UI, instant, priority 5 unless overridden by a boot-critical entry
- `ui_settings_panel.tscn`: `settings_panel`, UI, instant, priority 5 unless overridden by manifest metadata

**Critical scenes** stay hardcoded in `U_SceneRegistry` for boot safety. Generated manifest entries stay available as the mobile/web-safe baseline where runtime directory iteration is not used.

## Troubleshooting

**Scene not loading?**
- Check scene_id is unique (not already used)
- Verify the scene path points to an existing `.tscn` file
- Confirm the scene follows a supported convention or has an override resource/manifest entry
- Check console for errors during startup

**Can't find my scene in registry?**
- Registry entries load once on first access through `U_SceneRegistry`.
- Restart the game/editor or reset the registry in tests to reload entries.
- For exports, make sure generated manifest/resource entries include scenes that cannot rely on directory scanning.
- For override resources, check that the `.tres` file has the correct `RS_SceneRegistryEntry` type.
