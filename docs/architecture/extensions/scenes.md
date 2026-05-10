# Add Scene / Transition / Registry Entry

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new gameplay scene
- A new reusable gameplay template scene
- A scene registry entry
- Spawn metadata for scene entry points
- A transition effect or transition routing change

This recipe does **not** cover:

- UI screens and overlays (see `ui.md`)
- Display/post-process presets (see `display_post_process.md`)
- Validated resource class authoring (see `resources.md`)

## Governing ADR(s)

- [ADR 0001: Channel Taxonomy](../adr/0001-channel-taxonomy.md)
- [ADR 0009: Template vs Demo Separation](../adr/0009-template-vs-demo-separation.md)
- [ADR 0010: Base Scene and Demo Entry Split](../adr/0010-base-scene-and-demo-entry-split.md)

## Canonical Example

- Base gameplay scene: `scenes/core/gameplay/gameplay_base.tscn`
- Gameplay template: `scenes/core/templates/tmpl_base_scene.tscn`
- Convention-derived scene id: `scenes/demo/gameplay/gameplay_demo_room.tscn` -> `demo_room`
- Scene registry override: `resources/core/scene_registry/cfg_gameplay_base_entry.tres`
- Registry entry resource type: `scripts/core/resources/scene_management/rs_scene_registry_entry.gd`
- Spawn metadata resource type: `scripts/core/resources/scene_management/rs_spawn_metadata.gd`
- Scene manager: `scripts/core/managers/m_scene_manager.gd`
- Registry utility: `scripts/core/scene_management/u_scene_registry.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `gameplay_*.tscn` | Gameplay scene filename prefix. Core base scenes remain under `scenes/core/gameplay/`; demo gameplay scenes move under `scenes/demo/gameplay/` during the core/demo split. |
| `tmpl_*.tscn` | Reusable template scene under `scenes/core/templates/`. |
| `cfg_*_entry.tres` | `RS_SceneRegistryEntry` instance under `resources/core/scene_registry/`; used for explicit overrides and generated export-safe baselines. |
| `cfg_sp_*.tres` | `RS_SpawnMetadata` instance under `resources/core/spawn_metadata/`. |
| `sp_*` | Spawn marker node name under `Entities/SpawnPoints`. |
| `U_SceneRegistry` | Static registry for scene ids, paths, scene types, transition defaults, preload priority, and door pairings. |
| `M_SceneManager` | Runtime transition, loading, overlay, active-scene, and cache coordinator. |

Core scenes must survive removal of demo content. Demo scenes may depend on core scenes, resources, and systems; core scenes must not depend on demo paths.

## Recipe

### Adding a new gameplay scene

1. Start from `scenes/core/templates/tmpl_base_scene.tscn` or duplicate `scenes/core/gameplay/gameplay_base.tscn` through builder/editor tooling. Do not create `.tscn` files by hand.
2. Save the scene as `scenes/core/gameplay/gameplay_<name>.tscn` for core scenes. For demo-only content, use `scenes/demo/gameplay/gameplay_<name>.tscn`.
3. Keep the scene tree aligned with `docs/guides/SCENE_ORGANIZATION_GUIDE.md`: `SceneObjects`, `Environment`, `Systems`, `Managers`, and `Entities`.
4. Add spawn markers under `Entities/SpawnPoints`; include `sp_default` unless the scene is never entered directly.
5. Let the convention scanner register the scene id from the filename. For example, `gameplay_demo_room.tscn` registers as `demo_room` with type `GAMEPLAY`, transition `loading`, and preload priority `5`.
6. Add `resources/core/scene_registry/cfg_<name>_entry.tres` using `RS_SceneRegistryEntry` only when the scene needs custom metadata, an explicit override, or generated mobile/web export coverage.
7. If the scene is entered from another scene, add `resources/core/spawn_metadata/cfg_sp_<name>.tres` or update existing spawn metadata.
8. Add or update scene manager integration tests for routing, preload behavior, spawn selection, or transition behavior as applicable.
9. Run `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`.

### Adding a new transition effect

1. Add the transition script under `scripts/core/scene_management/transitions/trans_<name>.gd`; extend the existing transition base class.
2. Register it in `U_TransitionFactory`.
3. Use it by scene registry default or explicit `M_SceneManager.transition_to_scene(scene_id, "<name>")`.
4. Add focused tests for effect construction and manager routing.
5. Keep transition state in `U_TransitionState`; do not reintroduce Array-wrapper callback state.

### Adding a door or bidirectional route

1. Add door/trigger controllers using the `Inter_*` controller pattern, not hand-authored parallel component stacks.
2. Place destination spawn markers 2-3 units outside trigger zones.
3. Register door pairings in `U_SceneRegistry._register_door_pairings()`.
4. Use cooldowns of at least `1.0` second for scene-transition triggers.
5. Add a test or manual verification note for ping-pong prevention.

## Anti-patterns

- **Gameplay scenes embedding root managers**: persistent managers live only in `scenes/root.tscn`; gameplay scenes own scene-local `M_ECSManager`.
- **Manual active-scene tree edits**: use `M_SceneManager` APIs instead of adding/removing children under `ActiveSceneContainer`.
- **Core scene references to demo paths**: violates the core/demo split and should be caught by import/path boundary checks.
- **Hand-authored `.tscn` files**: use builder/editor workflows so Godot owns scene metadata and UIDs.
- **Resource entries for default metadata**: use conventions first; reserve registry resources for overrides, advanced modules, and export-safe generated baselines.
- **Missing `sp_default`**: spawn fallback becomes fragile.
- **Spawn markers inside trigger volumes**: causes transition ping-pong.
- **Transition callbacks with Array wrappers**: use `U_TransitionState`.
- **Manager-domain events through `U_ECSEventBus`**: scene manager changes should route through manager APIs, Redux actions, or signals per ADR 0001.

## Out Of Scope

- UI screens and overlays: see `ui.md`
- Resource validation patterns: see `resources.md`
- State slice changes: see `state.md`
- Display and post-process transitions: see `display_post_process.md`

## References

- [Scene Manager Overview](../../systems/scene_manager/scene-manager-overview.md)
- [Scene Organization Guide](../../guides/SCENE_ORGANIZATION_GUIDE.md)
- [Target Structure](../../history/cleanup_v8/target_structure.md)
- [Template vs Demo Classification](../../history/cleanup_v8/template_vs_demo.md)
