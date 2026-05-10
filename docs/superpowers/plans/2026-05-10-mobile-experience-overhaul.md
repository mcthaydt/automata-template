# Mobile Experience Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve mobile authoring, presentation, touch gameplay reliability, and QA through a phased overhaul.

**Architecture:** Scene auto-registration extends the existing `U_SceneRegistryLoader` pipeline with convention-derived metadata while preserving hardcoded boot-critical scenes and manifest overrides. Mobile runtime work stays inside existing Display Manager, UI Manager, Input Manager, and touchscreen ECS boundaries.

**Tech Stack:** Godot 4.7, GDScript, GUT, Redux-style state store, `U_SceneRegistry`, `RS_SceneManifestConfig`, `UI_MobileControls`, `S_TouchscreenSystem`.

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

## Phase 1: Scene Convention Auto-Registration

**Outcome:** Standard scenes register from folder conventions. Explicit manifests still work, and boot-critical scenes remain hardcoded.

### Task 1: Add Scanner Tests

**Files:**
- Create: `tests/unit/scene_manager/test_scene_convention_scanner.gd`
- Create later in task: `scripts/core/scene_management/helpers/u_scene_convention_scanner.gd`

- [ ] Write tests for gameplay path inference:
  - `res://scenes/demo/gameplay/gameplay_demo_room.tscn` produces scene_id `demo_room`.
  - `scene_type` is `U_SceneRegistry.SceneType.GAMEPLAY`.
  - `default_transition` is `loading`.
  - `preload_priority` is `5`.
- [ ] Write tests for UI overlay/settings path inference:
  - `res://scenes/core/ui/overlays/ui_save_load_menu.tscn` produces scene_id `save_load_menu`, type `UI`, transition `instant`.
  - `res://scenes/core/ui/settings/ui_settings_panel.tscn` produces scene_id `settings_panel`, type `UI`, transition `instant`.
- [ ] Write tests for ignored paths:
  - `res://scenes/core/prefabs/prefab_player.tscn` returns an empty dictionary.
  - `res://scenes/core/templates/tmpl_base_scene.tscn` returns an empty dictionary.
  - `res://scenes/core/ui/widgets/ui_virtual_button.tscn` returns an empty dictionary.
- [ ] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_convention_scanner.gd
```

Expected: fail because `U_SceneConventionScanner` does not exist.

### Task 2: Implement Pure Convention Scanner

**Files:**
- Create: `scripts/core/scene_management/helpers/u_scene_convention_scanner.gd`
- Test: `tests/unit/scene_manager/test_scene_convention_scanner.gd`

- [ ] Implement `U_SceneConventionScanner.infer_entry(path: String) -> Dictionary`.
- [ ] Implement `U_SceneConventionScanner.infer_entries(paths: PackedStringArray) -> Dictionary`.
- [ ] Use existing scene registry dictionary keys: `scene_id`, `path`, `scene_type`, `default_transition`, `preload_priority`.
- [ ] Keep the helper pure: no `DirAccess`, no `load()`, no ServiceLocator.
- [ ] Run the scanner test and verify pass:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_convention_scanner.gd
```

- [ ] Commit:

```bash
git add scripts/core/scene_management/helpers/u_scene_convention_scanner.gd tests/unit/scene_manager/test_scene_convention_scanner.gd
git commit -m "test: add scene convention scanner"
```

### Task 3: Wire Scanner Into Registry Loader

**Files:**
- Modify: `scripts/core/scene_management/helpers/u_scene_registry_loader.gd`
- Modify: `tests/unit/scene_manager/test_scene_registry.gd`

- [ ] Add tests proving convention entries are available through `U_SceneRegistry.get_scene(StringName("demo_room"))`.
- [ ] Add tests proving explicit hardcoded or manifest entries win over convention entries when IDs collide.
- [ ] Modify `U_SceneRegistryLoader` to collect conventional scene paths in dev/headless contexts and register inferred entries with duplicate skipping.
- [ ] Do not enable runtime directory scanning for mobile/web exports. For exports, generated manifest entries remain the mobile-safe source.
- [ ] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_registry.gd
```

- [ ] Run style guard because a production script was added:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [ ] Commit:

```bash
git add scripts/core/scene_management/helpers/u_scene_registry_loader.gd tests/unit/scene_manager/test_scene_registry.gd
git commit -m "feat: load conventional scene registry entries"
```

### Task 4: Document Zero-Config Scene Authoring

**Files:**
- Modify: `docs/systems/scene_manager/ADDING_SCENES_GUIDE.md`
- Modify: `docs/systems/scene_manager/scene-manager-overview.md`
- Modify: `docs/architecture/extensions/scenes.md`

- [ ] Replace the default “create a resource first” path with the convention-first workflow.
- [ ] Keep registry resources documented as override and advanced module support.
- [ ] State that new `.tscn` files must still be created by builders, not by hand.
- [ ] Run style guard because docs structure/scene registration docs changed:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [ ] Commit:

```bash
git add docs/systems/scene_manager/ADDING_SCENES_GUIDE.md docs/systems/scene_manager/scene-manager-overview.md docs/architecture/extensions/scenes.md
git commit -m "docs: document convention-based scene registration"
```

## Phase 2: Mobile Presentation Baseline

**Outcome:** Mobile boots fullscreen/export-safe, menus and overlays remain usable in portrait, and gameplay HUD/controls do not leave the usable viewport.

### Task 5: Add Presentation Contract Tests

**Files:**
- Modify: `tests/unit/managers/test_display_manager.gd`
- Modify: `tests/unit/managers/helpers/test_u_display_window_applier.gd`
- Modify if needed: `tests/unit/utils/test_u_mobile_platform_detector.gd`

- [ ] Add tests for mobile fullscreen/window mode defaults if current state does not already express them.
- [ ] Add tests for selector behavior around `mobile_resolution_scale`.
- [ ] Add tests for any new safe-area helper before implementing the helper.
- [ ] Run targeted display tests and confirm expected failures:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_display_manager.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/helpers/test_u_display_window_applier.gd
```

### Task 6: Implement Mobile Presentation State And Helpers

**Files:**
- Modify as tests require: `scripts/core/resources/state/rs_display_initial_state.gd`
- Modify as tests require: `scripts/core/state/selectors/u_display_selectors.gd`
- Modify as tests require: `scripts/core/managers/helpers/display/u_display_window_applier.gd`
- Modify as tests require: `scripts/core/utils/display/u_mobile_platform_detector.gd`

- [ ] Keep Display Manager responsible for fullscreen/window operations.
- [ ] Keep UI layout scaling separate from post-process overlays.
- [ ] Add only state fields that have a test and a runtime consumer.
- [ ] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_display_manager.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/helpers/test_u_display_window_applier.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/utils/test_u_mobile_platform_detector.gd
```

- [ ] Commit:

```bash
git add scripts/core/resources/state/rs_display_initial_state.gd scripts/core/state/selectors/u_display_selectors.gd scripts/core/managers/helpers/display/u_display_window_applier.gd scripts/core/utils/display/u_mobile_platform_detector.gd tests/unit/managers/test_display_manager.gd tests/unit/managers/helpers/test_u_display_window_applier.gd tests/unit/utils/test_u_mobile_platform_detector.gd
git commit -m "feat: add mobile presentation baseline"
```

### Task 7: Make Mobile UI Portrait-Compatible

**Files:**
- Modify: `scripts/core/ui/hud/ui_mobile_controls.gd`
- Modify if needed: `scripts/core/ui/hud/ui_hud_controller.gd`
- Modify if needed: `scripts/core/ui/settings/ui_settings_panel.gd`
- Modify tests: `tests/unit/integration/test_touchscreen_input_flow.gd`

- [ ] Add or update tests for clamping saved custom joystick and button positions to visible viewport bounds.
- [ ] Add or update tests for controls staying hidden during overlays and non-gameplay shells.
- [ ] Update mobile controls placement so portrait viewport sizes keep controls reachable.
- [ ] Keep portrait gameplay compatibility limited to usable controls and non-overlapping UI.
- [ ] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
```

- [ ] Commit:

```bash
git add scripts/core/ui/hud/ui_mobile_controls.gd scripts/core/ui/hud/ui_hud_controller.gd scripts/core/ui/settings/ui_settings_panel.gd tests/unit/integration/test_touchscreen_input_flow.gd
git commit -m "feat: make mobile UI portrait-compatible"
```

## Phase 3: Touch Gameplay Polish

**Outcome:** Touch input remains reliable through transitions, resets, overlays, and device switches.

### Task 8: Expand Touch Reliability Tests

**Files:**
- Modify: `tests/unit/integration/test_touchscreen_input_flow.gd`
- Modify: `tests/unit/managers/test_m_input_device_manager.gd`
- Modify if needed: `tests/unit/integration/test_touchscreen_settings_migration.gd`

- [ ] Test reset-after-victory or reset-progress keeps `active_device`, `touchscreen_enabled`, and gamepad state fields.
- [ ] Test mobile/web emulated mouse events do not switch active device away from touchscreen.
- [ ] Test gamepad input can take over on mobile and hide touch controls.
- [ ] Test touch controls reappear when a real touch event switches active device back to touchscreen.
- [ ] Run the targeted tests and verify new assertions fail only where implementation is missing.

### Task 9: Implement Touch Reliability Fixes

**Files:**
- Modify as tests require: `scripts/core/ui/hud/ui_mobile_controls.gd`
- Modify as tests require: `scripts/core/ecs/systems/s_touchscreen_system.gd`
- Modify as tests require: `scripts/core/managers/m_input_device_manager.gd`
- Modify as tests require: `scripts/core/state/reducers/u_gameplay_reducer.gd`

- [ ] Preserve existing ownership: `M_InputDeviceManager` detects devices, `UI_MobileControls` owns virtual control state, `S_TouchscreenSystem` dispatches gameplay input.
- [ ] Do not dispatch touch input when navigation shell is not gameplay.
- [ ] Do not process touch input while scene transitions or blocking overlays are active.
- [ ] Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_m_input_device_manager.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_settings_migration.gd
```

- [ ] Commit:

```bash
git add scripts/core/ui/hud/ui_mobile_controls.gd scripts/core/ecs/systems/s_touchscreen_system.gd scripts/core/managers/m_input_device_manager.gd scripts/core/state/reducers/u_gameplay_reducer.gd tests/unit/integration/test_touchscreen_input_flow.gd tests/unit/managers/test_m_input_device_manager.gd tests/unit/integration/test_touchscreen_settings_migration.gd
git commit -m "fix: harden mobile touch input flow"
```

## Phase 4: QA, Docs, And Mobile Release Gates

**Outcome:** The project has a repeatable mobile validation path before shipping mobile changes.

### Task 10: Add Mobile QA Checklist

**Files:**
- Create: `docs/systems/mobile_experience/mobile-qa-checklist.md`
- Create: `docs/systems/mobile_experience/mobile-experience-tasks.md`
- Modify: `docs/guides/pitfalls/MOBILE.md`
- Modify: `docs/systems/input_manager/input-manager-overview.md`
- Modify: `docs/systems/display_manager/display-manager-overview.md`

- [ ] Document real-device checks:
  - Boot to menu in landscape.
  - Rotate to portrait and confirm menu/settings/endgame remain usable.
  - Start gameplay and confirm portrait does not trap input or hide controls.
  - Complete/reset run and confirm touch controls still work.
  - Connect/disconnect gamepad and confirm correct touch visibility.
  - Suspend/resume app and confirm state remains usable.
- [ ] Document desktop fallback checks:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --emulate-mobile --quit-after 3
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
```

- [ ] Run style guard because new docs and possibly directories were added:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [ ] Commit:

```bash
git add docs/systems/mobile_experience/mobile-qa-checklist.md docs/systems/mobile_experience/mobile-experience-tasks.md docs/guides/pitfalls/MOBILE.md docs/systems/input_manager/input-manager-overview.md docs/systems/display_manager/display-manager-overview.md
git commit -m "docs: add mobile experience QA gates"
```

## Final Verification

- [ ] Run the targeted scene manager suite:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_registry.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_convention_scanner.gd
```

- [ ] Run the targeted touchscreen suite:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_m_input_device_manager.gd
```

- [ ] Run the style guard:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

- [ ] Run the full suite before merging:

```bash
tools/run_gut_suite.sh
```

## Self-Review Notes

- Spec coverage: the plan covers scene auto-registration, mobile fullscreen/presentation, portrait compatibility, touch reliability, and QA docs.
- Scope: this is a master plan. If execution feels too large for one branch, split into four branches matching the phases above.
- Ambiguity resolved: portrait support means compatibility, not optimized portrait gameplay.
- Runtime boundary check: SceneManager still consumes registry metadata; mobile behavior stays in Display/UI/Input ownership boundaries.
