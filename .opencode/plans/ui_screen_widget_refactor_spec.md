# UI Screen Widget Refactor Design

## Date: 2026-05-07
## Status: Draft — pending user review

---

## 1. Problem Statement

Current UI screen controllers (e.g. `UI_SettingsPanel`, `UI_MainMenu`, `UI_PauseMenu`) are monolithic scripts that mix scene-tree construction, focus management, theme application, store subscription, and domain logic in a single file. This makes them hard for LLMs to modify reliably: a request like "change tab switching behavior" forces the model to reason across 600+ lines of unrelated chrome, background, and focus code.

## 2. Goal

Decompose every screen into small, single-responsibility **widget** classes (`W_*`) so that:
- Each widget is ≤120 lines and has one clear purpose.
- Each widget has its own isolated test file (no full scene instantiation required).
- Screen controllers become thin orchestrators (≤120 lines) that only wire widgets to the store.
- LLM-driven changes require reading ≤2 files (widget + test) instead of one 600-line controller.

## 3. Widget Taxonomy

Widgets are plain `Control` subclasses under `scripts/core/ui/widgets/`.

| Widget | Responsibility | Target LOC |
|--------|---------------|------------|
| `W_TabStrip` | Horizontal tab buttons, `ButtonGroup`, shoulder hints, `ui_focus_next`/`ui_focus_prev` cycling, visible-tab wrapping | ~100 |
| `W_MenuButtonList` | Vertical button column, focus wrapping, sound-arming, theme token application | ~80 |
| `W_OverlayChrome` | Close button, panel chrome header row, spacer layout | ~60 |
| `W_BackgroundImage` | Auto-provision `TextureRect` from preset map, nearest-neighbor filtering, shader fallback | ~70 |
| `W_SettingsForm` | Label+control rows (dropdown, slider, toggle), inline groups, focus registration | ~120 |
| `W_FocusChain` | Reusable vertical/horizontal/grid focus neighbor wiring, visibility filtering | ~50 |

## 4. Screen Controller Contract (After Widgets)

A screen controller (e.g. `UI_SettingsPanel`) becomes a thin orchestrator:

```gdscript
class_name UI_SettingsPanel
extends BaseOverlay

var _tab_strip: W_TabStrip
var _chrome: W_OverlayChrome
var _form: W_SettingsForm

func _on_panel_ready() -> void:
    _chrome = W_OverlayChrome.new(self)
    _tab_strip = W_TabStrip.new(_chrome.tab_bar_container)
    _form = W_SettingsForm.new(_chrome.content_container)
    _tab_strip.tab_switched.connect(_on_tab_switched)
    # ... store subscription and action dispatch only
```

**Boundaries:**
- Widgets own their subtree creation and internal focus.
- Screen controllers own store subscription and navigation action dispatch.
- No widget reaches outside its subtree.
- No `BaseWidget` base class — widgets use plain `Control` with helper composition to stay independently readable.

## 5. Test Strategy

### Widget Isolation Tests
Each widget gets isolated tests in a bare `Control` tree. Example:

```gdscript
# test_w_tab_strip.gd
func test_tab_switch_changes_active_id():
    var strip := W_TabStrip.new()
    strip.add_tab("display", Button.new())
    strip.add_tab("audio", Button.new())
    add_child_autofree(strip)
    strip.switch_to_tab("audio")
    assert_eq(strip.active_tab_id, "audio")
```

### Screen Integration Tests
Screen controller tests shrink to integration tests that verify widgets are wired together correctly, not that internal widget logic works.

## 6. Migration Path

Migrate **one screen at a time**, starting with the worst offender:

1. **SettingsPanel first** (648 lines → target ~100 lines + 3 widgets)
2. **PauseMenu** (185 lines → quick win, validates pattern)
3. **MainMenu** (354 lines → medium effort)
4. **Endgame screens** (small, lower priority)

Per screen:
1. Extract widget(s) from screen script into new `W_*` file under `scripts/core/ui/widgets/`.
2. Write widget tests under `tests/unit/ui/widgets/`.
3. Run widget tests until they pass.
4. Replace inline logic in screen script with widget instance(s).
5. Run full UI test suite (`tools/run_gut_suite.sh`) to confirm zero regressions.
6. Run style suite (`tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`) for new files.
7. Commit with `(GREEN)` marker.

## 7. Naming & File Structure

| Category | Prefix | Example Path |
|----------|--------|--------------|
| Widget scripts | `W_` | `scripts/core/ui/widgets/w_tab_strip.gd` |
| Widget tests | `test_w_` | `tests/unit/ui/widgets/test_w_tab_strip.gd` |
| Screen controllers | `UI_` | `scripts/core/ui/settings/ui_settings_panel.gd` |

Widgets receive dependencies via constructor injection or lightweight `set_store()` — no global lookups inside widgets.

## 8. Base Class Decision

**No `BaseWidget` class.** Widgets extend `Control` directly. Common behavior (sound arming, theme tokens, focus configuration) is composed via existing helpers (`U_FocusConfigurator`, `U_UIThemeRoleUtils`, `U_UIMotion`) rather than inheritance. This keeps each widget file self-contained and readable without hierarchy context.

## 9. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Widget tests pass but screen integration breaks | Keep existing screen integration tests until migration of that screen is complete; add orchestrator-level tests for wiring. |
| Widget LOC creeps back up | Enforce via style suite: new `test_widget_file_size_cap` rule (120 lines). |
| Widget duplication across screens | Accept limited duplication; prefer duplication over premature abstraction that re-couples files. |
| Headless rebuild needed after `.tscn` changes | This refactor is script-only; no `.tscn` creation or modification, so no rebuild required. |

## 10. Acceptance Criteria

- [ ] `W_TabStrip` extracted from `UI_SettingsPanel`, with `test_w_tab_strip.gd` passing.
- [ ] `UI_SettingsPanel` reduced to ≤120 lines.
- [ ] `W_MenuButtonList` extracted from `UI_PauseMenu`, with `test_w_menu_button_list.gd` passing.
- [ ] `UI_PauseMenu` reduced to ≤120 lines.
- [ ] Full `tests/unit/ui/` suite passes after each screen migration.
- [ ] Style suite passes after new files added.
- [ ] Zero behavioral regressions in manual UI flow verification matrix (pause, settings, tab cycling, focus, back actions).
