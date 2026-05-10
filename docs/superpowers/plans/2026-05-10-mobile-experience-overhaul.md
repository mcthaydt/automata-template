# Mobile Experience Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve mobile authoring, presentation, touch gameplay reliability, and QA through a phased overhaul.

**Architecture:** Scene auto-registration extends the existing `U_SceneRegistryLoader` pipeline with convention-derived metadata while preserving hardcoded boot-critical scenes and manifest overrides. Mobile runtime work stays inside existing Display Manager, UI Manager, Input Manager, and touchscreen ECS boundaries.

**Tech Stack:** Godot 4.7, GDScript, GUT, Redux-style state store, `U_SceneRegistry`, `RS_SceneManifestConfig`, `UI_MobileControls`, `S_TouchscreenSystem`.

---

## Current Progress

Last updated: 2026-05-10.

Completed phases:

- Phase 1: Scene Convention Auto-Registration.
- Phase 2: Mobile Presentation Baseline.
- Phase 3: Touch Gameplay Polish.
- Phase 4: App Lifecycle & System UI.
- Phase 5: Mobile Export Configuration.
- Phase 6: QA, Docs, And Mobile Release Gates.

Current phase:

- Implementation plan tasks and final verification are complete.

Recent commits:

- `7108b24c test: add scene convention scanner`
- `87ea73bc feat: load conventional scene registry entries`
- `9e93c32d docs: document convention-based scene registration`
- `4569c63a feat: add mobile presentation baseline`
- `3eef7ab8 feat: make mobile UI portrait-compatible`
- `6ca1528e fix: harden mobile touch input flow`
- `ed80c676 feat: add app lifecycle redux slice`
- `6a66cc43 feat: add app lifecycle observer`
- `25f29ea2 feat: react to app lifecycle in audio and autosave`
- `8b404340 feat: clamp mobile controls to safe-area insets`
- `ed20a4cb docs: update mobile overhaul safe-area progress`
- `b55df415 docs: document app lifecycle contract`
- `980c446d docs: update mobile overhaul lifecycle docs progress`
- `5aa5ceef build: configure mobile and web export presets`
- `2ed74f5f docs: update mobile overhaul export progress`
- `b0698dc9 docs: add mobile experience QA gates`
- `7bf7f2fb docs: update mobile overhaul QA progress`
- `80b0013c test: align touchscreen system setup with navigation shell`

Latest verified gates:

- `tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_convention_scanner.gd` -> `5/5 passed`, 20 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_registry.gd` -> `24/24 passed`, 140 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_display_manager.gd` -> `28/28 passed`, 51 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/helpers/test_u_display_window_applier.gd` -> `4/4 passed`, 7 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_mobile_platform_detector.gd` -> `16/16 passed`, 18 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd` -> `10/10 passed`, 92 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_m_input_device_manager.gd` -> `16/16 passed`, 85 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_settings_migration.gd` -> `4/4 passed`, 48 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/state/test_u_app_reducer.gd` -> `7/7 passed`, 14 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/state/test_m_state_store.gd` -> `30/30 passed`, 75 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_app_lifecycle_observer.gd` -> `6/6 passed`, 19 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_safe_area_insets.gd` -> `3/3 passed`, 6 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_audio_manager.gd` -> `24/24 passed`, 68 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/save/test_autosave_scheduler.gd` -> `17/17 passed`, 22 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` -> `93/93 passed`, 154 asserts.
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_touchscreen_system.gd` -> `7/7 passed`, 16 asserts.
- `tools/run_gut_suite.sh` -> `4560/4578 passing`, 18 expected pending/risky headless/runtime skips, 14267 asserts.

Next task: Branch integration / PR.

---

## File Structure

- Create `scripts/core/scene_management/helpers/u_scene_convention_scanner.gd`: pure helper that maps conventional `.tscn` paths to scene registry dictionaries.
- Modify `scripts/core/scene_management/helpers/u_scene_registry_loader.gd`: load generated convention entries after hardcoded/manifest entries and before optional dev directory scans.
- Modify `scripts/core/scene_management/u_scene_manifest.gd`: keep manifest entries for explicit overrides and generated baseline scenes.
- Modify `tests/unit/scene_manager/test_scene_registry.gd`: add coverage for convention-derived scene IDs, duplicate skip behavior, and ignored folders.
- Create `tests/unit/scene_manager/test_scene_convention_scanner.gd`: focused tests for path-to-entry inference.
- Modify `docs/systems/scene_manager/ADDING_SCENES_GUIDE.md`: document zero-config scene authoring.
- Modify `docs/systems/scene_manager/scene-manager-overview.md`: update scene registration contract.
- Modify `docs/systems/input_manager/input-manager-overview.md`: document mobile reliability contracts added during touch polish.
- Modify `docs/guides/pitfalls/MOBILE.md`: add newly discovered reset, orientation, fullscreen, and QA pitfalls.
- Modify `scripts/core/resources/state/rs_display_initial_state.gd`: add mobile presentation state only if needed after tests expose a missing state contract.
- Modify `scripts/core/state/selectors/u_display_selectors.gd`: expose safe mobile presentation selectors only when backed by state.
- Modify `scripts/core/managers/helpers/display/u_display_window_applier.gd`: apply mobile fullscreen/orientation behavior through Display Manager boundaries.
- Modify `scripts/core/ui/hud/ui_mobile_controls.gd`: clamp controls to safe bounds, improve portrait-compatible placement, and keep visibility transitions deterministic.
- Modify `scripts/core/ecs/systems/s_touchscreen_system.gd`: tighten touch dispatch gates and component updates if tests find race conditions.
- Modify `scripts/core/managers/m_input_device_manager.gd`: adjust active-device detection only for confirmed touch/gamepad handoff failures.
- Modify `tests/unit/integration/test_touchscreen_input_flow.gd`: expand mobile control reset, visibility, and handoff cases.
- Modify `tests/unit/managers/test_m_input_device_manager.gd`: cover touch/gamepad/mobile disconnect edge cases.
- Create `docs/systems/mobile_experience/mobile-experience-tasks.md`: project-facing task checklist with completion notes.
- Create `docs/systems/mobile_experience/mobile-qa-checklist.md`: manual mobile QA checklist for real devices.
- Create `scripts/core/state/reducers/u_app_reducer.gd`: Redux reducer for the new `app` slice (`is_backgrounded`, `is_focused`).
- Create `scripts/core/state/selectors/u_app_selectors.gd`: selectors for the `app` slice.
- Create `scripts/core/utils/lifecycle/u_app_lifecycle_observer.gd`: autoload that translates Godot lifecycle notifications into Redux actions and back-gesture into `ui_cancel`.
- Create `scripts/core/utils/display/u_safe_area_insets.gd`: pure helper that returns `Rect2` insets from usable-rect minus window-rect.
- Create `tests/unit/state/test_u_app_reducer.gd`: focused tests for the `app` reducer and selectors.
- Create `tests/unit/utils/test_u_app_lifecycle_observer.gd`: tests for notification → action translation using injected dispatch.
- Create `tests/unit/utils/test_u_safe_area_insets.gd`: tests for inset math with mocked rects.
- Modify `scripts/core/managers/m_audio_manager.gd`: mute/unmute master bus on focus changes.
- Modify `scripts/core/managers/helpers/u_autosave_scheduler.gd`: add a `BACKGROUND` trigger.
- Modify `tests/unit/managers/test_m_audio_manager.gd`: cover focus-driven mute/unmute behavior.
- Modify `tests/unit/managers/helpers/test_u_autosave_scheduler.gd`: cover the new `BACKGROUND` trigger.
- Modify `export_presets.cfg`: fill in Android preset (launcher icons, package name, permissions, signing path doc) and add a Web preset.
- Modify `project.godot`: add `display/window/handheld/orientation` and `rendering/renderer/rendering_method.mobile`.

## Phase 1: Scene Convention Auto-Registration

**Outcome:** Standard scenes register from folder conventions. Explicit manifests still work, and boot-critical scenes remain hardcoded.

### Task 1: Add Scanner Tests

**Files:**
- Create: `tests/unit/scene_manager/test_scene_convention_scanner.gd`
- Create later in task: `scripts/core/scene_management/helpers/u_scene_convention_scanner.gd`

- [x] Write tests for gameplay path inference:
  - `res://scenes/demo/gameplay/gameplay_demo_room.tscn` produces scene_id `demo_room`.
  - `scene_type` is `U_SceneRegistry.SceneType.GAMEPLAY`.
  - `default_transition` is `loading`.
  - `preload_priority` is `5`.
- [x] Write tests for UI overlay/settings path inference:
  - `res://scenes/core/ui/overlays/ui_save_load_menu.tscn` produces scene_id `save_load_menu`, type `UI`, transition `instant`.
  - `res://scenes/core/ui/settings/ui_settings_panel.tscn` produces scene_id `settings_panel`, type `UI`, transition `instant`.
- [x] Write tests for ignored paths:
  - `res://scenes/core/prefabs/prefab_player.tscn` returns an empty dictionary.
  - `res://scenes/core/templates/tmpl_base_scene.tscn` returns an empty dictionary.
  - `res://scenes/core/ui/widgets/ui_virtual_button.tscn` returns an empty dictionary.
- [x] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_convention_scanner.gd
```

Expected failure observed before implementation: `U_SceneConventionScanner` did not exist.

### Task 2: Implement Pure Convention Scanner

**Files:**
- Create: `scripts/core/scene_management/helpers/u_scene_convention_scanner.gd`
- Test: `tests/unit/scene_manager/test_scene_convention_scanner.gd`

- [x] Implement `U_SceneConventionScanner.infer_entry(path: String) -> Dictionary`.
- [x] Implement `U_SceneConventionScanner.infer_entries(paths: PackedStringArray) -> Dictionary`.
- [x] Use existing scene registry dictionary keys: `scene_id`, `path`, `scene_type`, `default_transition`, `preload_priority`.
- [x] Keep the helper pure: no `DirAccess`, no `load()`, no ServiceLocator.
- [x] Run the scanner test and verify pass:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_convention_scanner.gd
```

- [x] Commit:

```bash
git add scripts/core/scene_management/helpers/u_scene_convention_scanner.gd tests/unit/scene_manager/test_scene_convention_scanner.gd
git commit -m "test: add scene convention scanner"
```

Completed in `7108b24c`.

### Task 3: Wire Scanner Into Registry Loader

**Files:**
- Modify: `scripts/core/scene_management/helpers/u_scene_registry_loader.gd`
- Modify: `tests/unit/scene_manager/test_scene_registry.gd`

- [x] Add tests proving convention entries are available through `U_SceneRegistry.get_scene(StringName("demo_room"))`.
- [x] Add tests proving explicit hardcoded or manifest entries win over convention entries when IDs collide.
- [x] Modify `U_SceneRegistryLoader` to collect conventional scene paths in dev/headless contexts and register inferred entries with duplicate skipping.
- [x] Do not enable runtime directory scanning for mobile/web exports. For exports, generated manifest entries remain the mobile-safe source.
- [x] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_registry.gd
```

- [x] Run style guard because a production script was added:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [x] Commit:

```bash
git add scripts/core/scene_management/helpers/u_scene_registry_loader.gd tests/unit/scene_manager/test_scene_registry.gd
git commit -m "feat: load conventional scene registry entries"
```

Completed in `87ea73bc`.

### Task 4: Document Zero-Config Scene Authoring

**Files:**
- Modify: `docs/systems/scene_manager/ADDING_SCENES_GUIDE.md`
- Modify: `docs/systems/scene_manager/scene-manager-overview.md`
- Modify: `docs/architecture/extensions/scenes.md`

- [x] Replace the default “create a resource first” path with the convention-first workflow.
- [x] Keep registry resources documented as override and advanced module support.
- [x] State that new `.tscn` files must still be created by builders, not by hand.
- [x] Run style guard because docs structure/scene registration docs changed:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [x] Commit:

```bash
git add docs/systems/scene_manager/ADDING_SCENES_GUIDE.md docs/systems/scene_manager/scene-manager-overview.md docs/architecture/extensions/scenes.md
git commit -m "docs: document convention-based scene registration"
```

Completed in `9e93c32d`.

## Phase 2: Mobile Presentation Baseline

**Outcome:** Mobile boots fullscreen/export-safe, menus and overlays remain usable in portrait, and gameplay HUD/controls do not leave the usable viewport.

### Task 5: Add Presentation Contract Tests

**Files:**
- Modify: `tests/unit/managers/test_display_manager.gd`
- Modify: `tests/unit/managers/helpers/test_u_display_window_applier.gd`
- Modify if needed: `tests/unit/utils/test_u_mobile_platform_detector.gd`

- [x] Add tests for mobile fullscreen/window mode defaults if current state does not already express them.
- [x] Add tests for selector behavior around `mobile_resolution_scale`.
- [x] Add tests for any new safe-area helper before implementing the helper. No safe-area helper was needed in this task; safe-area work remains scoped to Task 13.
- [x] Run targeted display tests and confirm expected failures:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_display_manager.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/helpers/test_u_display_window_applier.gd
```

Expected failures observed before implementation: missing `mobile_window_mode`, unclamped scale selector, and missing mobile fullscreen/window-size behavior.

### Task 6: Implement Mobile Presentation State And Helpers

**Files:**
- Modify as tests require: `scripts/core/resources/state/rs_display_initial_state.gd`
- Modify as tests require: `scripts/core/state/selectors/u_display_selectors.gd`
- Modify as tests require: `scripts/core/managers/helpers/display/u_display_window_applier.gd`
- Modify as tests require: `scripts/core/utils/display/u_mobile_platform_detector.gd`

- [x] Keep Display Manager responsible for fullscreen/window operations.
- [x] Keep UI layout scaling separate from post-process overlays.
- [x] Add only state fields that have a test and a runtime consumer.
- [x] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_display_manager.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/helpers/test_u_display_window_applier.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_mobile_platform_detector.gd
```

- [x] Commit:

```bash
git add scripts/core/resources/state/rs_display_initial_state.gd scripts/core/state/selectors/u_display_selectors.gd scripts/core/managers/helpers/display/u_display_window_applier.gd scripts/core/utils/display/u_mobile_platform_detector.gd tests/unit/managers/test_display_manager.gd tests/unit/managers/helpers/test_u_display_window_applier.gd tests/unit/utils/test_u_mobile_platform_detector.gd
git commit -m "feat: add mobile presentation baseline"
```

Completed in `4569c63a`.

### Task 7: Make Mobile UI Portrait-Compatible

**Files:**
- Modify: `scripts/core/ui/hud/ui_mobile_controls.gd`
- Modify if needed: `scripts/core/ui/hud/ui_hud_controller.gd`
- Modify if needed: `scripts/core/ui/settings/ui_settings_panel.gd`
- Modify tests: `tests/unit/integration/test_touchscreen_input_flow.gd`

- [x] Add or update tests for clamping saved custom joystick and button positions to visible viewport bounds.
- [x] Add or update tests for controls staying hidden during overlays and non-gameplay shells.
- [x] Update mobile controls placement so portrait viewport sizes keep controls reachable.
- [x] Keep portrait gameplay compatibility limited to usable controls and non-overlapping UI.
- [x] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
```

- [x] Commit:

```bash
git add scripts/core/ui/hud/ui_mobile_controls.gd scripts/core/ui/hud/ui_hud_controller.gd scripts/core/ui/settings/ui_settings_panel.gd tests/unit/integration/test_touchscreen_input_flow.gd
git commit -m "feat: make mobile UI portrait-compatible"
```

Completed in `3eef7ab8`. Only `scripts/core/ui/hud/ui_mobile_controls.gd` and `tests/unit/integration/test_touchscreen_input_flow.gd` required changes.

## Phase 3: Touch Gameplay Polish

**Outcome:** Touch input remains reliable through transitions, resets, overlays, and device switches.

### Task 8: Expand Touch Reliability Tests

**Files:**
- Modify: `tests/unit/integration/test_touchscreen_input_flow.gd`
- Modify: `tests/unit/managers/test_m_input_device_manager.gd`
- Modify if needed: `tests/unit/integration/test_touchscreen_settings_migration.gd`

- [x] Test reset-after-victory or reset-progress keeps `active_device`, `touchscreen_enabled`, and gamepad state fields.
- [x] Test mobile/web emulated mouse events do not switch active device away from touchscreen.
- [x] Test gamepad input can take over on mobile and hide touch controls.
- [x] Test touch controls reappear when a real touch event switches active device back to touchscreen.
- [x] Run the targeted tests and verify new assertions fail only where implementation is missing.

Completion notes:
- Added reset-progress preservation coverage for touchscreen and gamepad state fields.
- Added mobile/web emulated mouse button and motion coverage with a dedicated pointer-emulation test hook.
- Added gamepad takeover and real-touch return coverage through `M_InputDeviceManager` plus `UI_MobileControls` visibility.
- Added touchscreen ECS dispatch gating coverage for pause overlays, non-gameplay shells, and scene transitions. Existing guards already satisfied the new navigation-blocking test before production changes were needed.

### Task 9: Implement Touch Reliability Fixes

**Files:**
- Modify as tests require: `scripts/core/ui/hud/ui_mobile_controls.gd`
- Modify as tests require: `scripts/core/ecs/systems/s_touchscreen_system.gd`
- Modify as tests require: `scripts/core/managers/m_input_device_manager.gd`
- Modify as tests require: `scripts/core/state/reducers/u_gameplay_reducer.gd`

- [x] Preserve existing ownership: `M_InputDeviceManager` detects devices, `UI_MobileControls` owns virtual control state, `S_TouchscreenSystem` dispatches gameplay input.
- [x] Do not dispatch touch input when navigation shell is not gameplay.
- [x] Do not process touch input while scene transitions or blocking overlays are active.
- [x] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_m_input_device_manager.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_settings_migration.gd
```

- [x] Commit:

```bash
git add scripts/core/ui/hud/ui_mobile_controls.gd scripts/core/ecs/systems/s_touchscreen_system.gd scripts/core/managers/m_input_device_manager.gd scripts/core/state/reducers/u_gameplay_reducer.gd tests/unit/integration/test_touchscreen_input_flow.gd tests/unit/managers/test_m_input_device_manager.gd tests/unit/integration/test_touchscreen_settings_migration.gd
git commit -m "fix: harden mobile touch input flow"
```

Completed in `6ca1528e`.

## Phase 4: App Lifecycle & System UI

**Outcome:** Mobile builds respond to OS-level focus and background events through Redux, audio mutes when backgrounded, autosave fires on suspend, the Android back gesture maps to `ui_cancel`, and `UI_MobileControls` respects safe-area insets.

### Task 8: Add App Slice Tests

**Files:**
- Create: `tests/unit/state/test_u_app_reducer.gd`
- Create later in task: `scripts/core/state/reducers/u_app_reducer.gd`
- Create later in task: `scripts/core/state/selectors/u_app_selectors.gd`

- [x] Write tests for `ACTION_APP_BACKGROUNDED` flipping `is_backgrounded` true and leaving other state untouched.
- [x] Write tests for `ACTION_APP_FOREGROUNDED` flipping `is_backgrounded` false.
- [x] Write tests for `ACTION_APP_FOCUS_LOST` / `ACTION_APP_FOCUS_GAINED` toggling `is_focused`.
- [x] Write tests for selectors returning current values.
- [x] Write a reducer-purity test (same input state + action returns equal state, reducer does not mutate the input).
- [x] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/state/test_u_app_reducer.gd
```

Expected: fail because reducer/selectors do not exist yet.

Completion notes:
- Added `U_AppActions`, `U_AppReducer`, and `U_AppSelectors`.
- Added app slice registration through `U_StateSliceManager` as transient runtime state.
- Initial focused run failed because app actions/reducer/selectors did not exist; final focused run passed.

### Task 9: Implement App Reducer And Selectors

**Files:**
- Create: `scripts/core/state/reducers/u_app_reducer.gd`
- Create: `scripts/core/state/selectors/u_app_selectors.gd`

- [x] Implement the four actions and the `is_backgrounded` / `is_focused` fields.
- [x] Keep reducer pure: no `ServiceLocator`, no signals, no I/O.
- [x] Wire into the existing root reducer alongside other slice reducers.
- [x] Run the slice tests and verify pass:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/state/test_u_app_reducer.gd
```

- [x] Run style guard:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [x] Commit:

```bash
git add scripts/core/state/reducers/u_app_reducer.gd scripts/core/state/selectors/u_app_selectors.gd tests/unit/state/test_u_app_reducer.gd
git commit -m "feat: add app lifecycle redux slice"
```

### Task 10: Add Lifecycle Observer Tests

**Files:**
- Create: `tests/unit/utils/test_u_app_lifecycle_observer.gd`
- Create later in task: `scripts/core/utils/lifecycle/u_app_lifecycle_observer.gd`

- [x] Inject a fake dispatcher into the observer; do not require real OS notifications.
- [x] Test `_notification(NOTIFICATION_APPLICATION_PAUSED)` dispatches `ACTION_APP_BACKGROUNDED`.
- [x] Test `_notification(NOTIFICATION_APPLICATION_RESUMED)` dispatches `ACTION_APP_FOREGROUNDED`.
- [x] Test `_notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)` dispatches `ACTION_APP_FOCUS_LOST`.
- [x] Test `_notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)` dispatches `ACTION_APP_FOCUS_GAINED`.
- [x] Test `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` emits a `ui_cancel` action through the configured input dispatch.
- [x] Test the observer does not dispatch on unrelated notifications.
- [x] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_app_lifecycle_observer.gd
```

Expected: fail because the observer does not exist yet.

Completion notes:
- Added observer tests using injected state and input dispatch callables.
- Initial focused run failed because `U_AppLifecycleObserver` did not exist; final focused run passed.

### Task 11: Implement Lifecycle Observer

**Files:**
- Create: `scripts/core/utils/lifecycle/u_app_lifecycle_observer.gd`
- Modify if needed: `scripts/core/managers/m_game_manager.gd` (autoload registration / boot wiring)

- [x] Implement `_notification(what: int)` translating the five notifications listed in Task 10 into actions.
- [x] Keep the observer thin: no pause logic, no audio logic — just emit actions. Side effects live in subscribing managers.
- [x] Register as an autoload (or attach to an existing root manager) so it stays alive across scene changes.
- [x] Run the observer test and verify pass:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_app_lifecycle_observer.gd
```

- [x] Run style guard:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [x] Commit:

```bash
git add scripts/core/utils/lifecycle/u_app_lifecycle_observer.gd scripts/core/managers/m_game_manager.gd tests/unit/utils/test_u_app_lifecycle_observer.gd
git commit -m "feat: add app lifecycle observer"
```

### Task 12: Wire Audio And Autosave Reactions

**Files:**
- Modify: `scripts/core/managers/m_audio_manager.gd`
- Modify: `scripts/core/managers/helpers/u_autosave_scheduler.gd`
- Modify: `tests/unit/managers/test_m_audio_manager.gd`
- Modify: `tests/unit/managers/helpers/test_u_autosave_scheduler.gd`

- [x] Add tests proving `M_AudioManager` mutes the master bus when `is_focused` transitions to false and restores when true.
- [x] Add tests proving `U_AutosaveScheduler` accepts a new `BACKGROUND` trigger and writes a save.
- [x] Implement the audio bus reaction subscribing to the `app` selector (or the dispatched action stream — match the pattern already used by other managers).
- [x] Implement the `BACKGROUND` autosave trigger and dispatch it from `U_AppLifecycleObserver` on background.
- [x] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_m_audio_manager.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/helpers/test_u_autosave_scheduler.gd
```

- [x] Commit:

```bash
git add scripts/core/managers/m_audio_manager.gd scripts/core/managers/helpers/u_autosave_scheduler.gd tests/unit/managers/test_m_audio_manager.gd tests/unit/managers/helpers/test_u_autosave_scheduler.gd
git commit -m "feat: react to app lifecycle in audio and autosave"
```

Completion notes:
- Current test paths are `tests/unit/managers/test_audio_manager.gd` and `tests/unit/save/test_autosave_scheduler.gd`.
- Added focus-lost/focus-gained master-bus mute restoration coverage, including preserving a user-muted master bus.
- Added background lifecycle autosave coverage using critical priority and synchronous write behavior.

### Task 13: Add Safe-Area Inset Helper

**Files:**
- Create: `tests/unit/utils/test_u_safe_area_insets.gd`
- Create later in task: `scripts/core/utils/display/u_safe_area_insets.gd`
- Modify: `scripts/core/ui/hud/ui_mobile_controls.gd`
- Modify: `tests/unit/integration/test_touchscreen_input_flow.gd`

- [x] Write tests for `U_SafeAreaInsets.compute(usable_rect, window_rect) -> Rect2` with: full-screen case (zero insets), notched case (top inset only), all-sides padded case.
- [x] Implement the helper; keep it pure — no `DisplayServer` calls inside the helper, callers pass rects in.
- [x] Update `UI_MobileControls` clamp (current viewport clamp at lines 389-405) to subtract insets from the allowed area before clamping. Source the live insets via `U_DisplayServerWindowOps` + `U_SafeAreaInsets`.
- [x] Add a test in `test_touchscreen_input_flow.gd` proving custom joystick/button positions stay outside notch insets.
- [x] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_safe_area_insets.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
```

- [x] Commit:

```bash
git add scripts/core/utils/display/u_safe_area_insets.gd scripts/core/ui/hud/ui_mobile_controls.gd tests/unit/utils/test_u_safe_area_insets.gd tests/unit/integration/test_touchscreen_input_flow.gd
git commit -m "feat: clamp mobile controls to safe-area insets"
```

Completed in `8b404340`.

Completion notes:
- Added pure safe-area inset math plus focused full-screen, notched, and all-sides padded coverage.
- `UI_MobileControls` now clamps against safe control bounds sourced from `U_DisplayServerWindowOps`; desktop-sized usable rects larger than the viewport are ignored to avoid false insets in windowed/editor contexts.
- Added touchscreen integration coverage for custom joystick/button positions clamping below a simulated top notch inset.

### Task 14: Document Lifecycle And Back-Gesture Pitfalls

**Files:**
- Modify: `docs/systems/input_manager/input-manager-overview.md`
- Modify: `docs/guides/pitfalls/MOBILE.md`

- [x] Document the lifecycle observer contract and the four actions it emits.
- [x] Document Android back gesture routing as a synthetic `ui_cancel` input event.
- [x] Add pitfall: do not subscribe to OS notifications in individual managers — go through the observer + Redux.
- [x] Run style guard:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [x] Commit:

```bash
git add docs/systems/input_manager/input-manager-overview.md docs/guides/pitfalls/MOBILE.md
git commit -m "docs: document app lifecycle contract"
```

Completed in `b55df415`.

Completion notes:
- The original checklist said gameplay back gesture should open the pause menu. Current runtime tests and `M_UIInputHandler` define a different contract: `ui_cancel` closes gameplay overlays and otherwise no-ops; `ui_pause` opens pause. The docs were updated to match the existing tested behavior instead of documenting a false routing contract.

## Phase 5: Mobile Export Configuration

**Outcome:** `export_presets.cfg` ships an Android preset with launcher icons and signing path documented, plus a Web preset. `project.godot` declares mobile orientation and renderer.

### Task 15: Configure Android Export Preset

**Files:**
- Modify: `export_presets.cfg`

- [x] Populate launcher icons (foreground + background + adaptive) from existing `assets/core/textures/` assets — reuse `tex_icon.svg` derivatives; do not commission new art in this program.
- [x] Set the Android package name and app category (already 2 / Games).
- [x] Document the keystore path and signing flow in `docs/systems/mobile_experience/mobile-qa-checklist.md` (created in Phase 6). The keystore itself stays gitignored.
- [x] Limit permissions to engine defaults; do not add network, location, etc.

Completion notes:
- Android preset now exports to `builds/android/automata-template.apk`.
- Package is `com.crispycabaret.automatatemplate`, app name is `Automata Template`, and app category remains Games.
- Launcher icon fields reuse `res://assets/core/textures/tex_icon.svg`; no new art was added.
- Permission toggles remain disabled, including network and location.

### Task 16: Add Web Export Preset

**Files:**
- Modify: `export_presets.cfg`

- [x] Add an HTML5 preset.
- [x] Leave PWA support off in this program.
- [x] Confirm canvas sizing remains portrait-compatible (no fixed-aspect lock that would break portrait layout).

Completion notes:
- Added a Web preset exporting to `builds/web/index.html`.
- PWA support remains disabled.
- `html/canvas_resize_policy=2` keeps canvas sizing responsive instead of fixed-aspect locked.

### Task 17: Update project.godot Mobile Settings

**Files:**
- Modify: `project.godot`

- [x] Add `display/window/handheld/orientation = "sensor_landscape"` (landscape preferred, portrait allowed for compatibility).
- [x] Set `rendering/renderer/rendering_method.mobile` to match the desktop renderer method. Renderer/perf retuning is deferred.
- [x] Run style guard since `project.godot` changed:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [x] Commit:

```bash
git add export_presets.cfg project.godot
git commit -m "build: configure mobile and web export presets"
```

Completed in `5aa5ceef`.

Completion notes:
- `project.godot` already had `rendering/renderer/rendering_method.mobile="gl_compatibility"`, matching desktop. This task only needed the handheld orientation setting.

## Phase 6: QA, Docs, And Mobile Release Gates

**Outcome:** The project has a repeatable mobile validation path before shipping mobile changes.

### Task 18: Add Mobile QA Checklist

**Files:**
- Create: `docs/systems/mobile_experience/mobile-qa-checklist.md`
- Create: `docs/systems/mobile_experience/mobile-experience-tasks.md`
- Modify: `docs/guides/pitfalls/MOBILE.md`
- Modify: `docs/systems/input_manager/input-manager-overview.md`
- Modify: `docs/systems/display_manager/display-manager-overview.md`

- [x] Document real-device checks:
  - Boot to menu in landscape.
  - Rotate to portrait and confirm menu/settings/endgame remain usable.
  - Start gameplay and confirm portrait does not trap input or hide controls.
  - Complete/reset run and confirm touch controls still work.
  - Connect/disconnect gamepad and confirm correct touch visibility.
  - Suspend/resume app and confirm pause engages, audio mutes, and an autosave was written.
  - Foreground after suspend and confirm audio restores and the game stays paused.
  - Trigger Android back gesture in gameplay (expect pause menu) and in a menu (expect back navigation).
  - Confirm `UI_MobileControls` joystick/buttons stay outside notch/cutout regions.
- [x] Document Android export checks:
  - APK builds via the configured preset.
  - APK installs and launches on at least one physical Android device.
  - Launcher icon and app name render correctly.
  - Keystore signing path is documented (path only — keystore itself gitignored).
- [x] Document Web export checks:
  - HTML5 export builds via the configured preset.
  - Served via a local HTTP server (e.g. `python3 -m http.server`) and loads in a mobile browser.
  - Touch controls reachable in both portrait and landscape browser orientations.
- [x] Document desktop fallback checks:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --emulate-mobile --quit-after 3
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
```

- [x] Run style guard because new docs and possibly directories were added:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [x] Commit:

```bash
git add docs/systems/mobile_experience/mobile-qa-checklist.md docs/systems/mobile_experience/mobile-experience-tasks.md docs/guides/pitfalls/MOBILE.md docs/systems/input_manager/input-manager-overview.md docs/systems/display_manager/display-manager-overview.md
git commit -m "docs: add mobile experience QA gates"
```

Completed in `b0698dc9`.

Completion notes:
- Added `docs/systems/mobile_experience/mobile-qa-checklist.md` with real-device, Android export, Web export, and desktop fallback checks.
- Added `docs/systems/mobile_experience/mobile-experience-tasks.md` as the project-facing mobile release gate tracker.
- Linked mobile QA gates from mobile pitfalls, input manager, and display manager docs.
- Documented the release keystore path as `~/.config/godot/automata-template/android/release.keystore`; the keystore itself remains outside the repo.

## Final Verification

- [x] Run the targeted scene manager suite:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_registry.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_convention_scanner.gd
```

- [x] Run the targeted touchscreen suite:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_m_input_device_manager.gd
```

- [x] Run the targeted lifecycle and safe-area suite:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/state/test_u_app_reducer.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_app_lifecycle_observer.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_safe_area_insets.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_audio_manager.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/save/test_autosave_scheduler.gd
```

- [x] Run the style guard:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [x] Run the full suite before merging:

```bash
tools/run_gut_suite.sh
```

## Self-Review Notes

- Spec coverage: the plan covers scene auto-registration, mobile fullscreen/presentation, portrait compatibility, touch reliability, app lifecycle (suspend/resume + back gesture), system-UI affordances (safe-area insets), mobile export configuration, and QA docs.
- Scope: this is a master plan. If execution feels too large for one branch, split into six branches matching the phases above.
- Targets: Android native export and Mobile web. iOS, mobile renderer/perf retuning, save-path verification, and on-screen keyboard integration are deferred per the spec's Deferred section.
- Ambiguity resolved: portrait support means compatibility, not optimized portrait gameplay.
- Runtime boundary check: SceneManager still consumes registry metadata; mobile behavior stays in Display/UI/Input ownership boundaries; lifecycle observer dispatches actions only — managers react via existing Redux subscriptions.
