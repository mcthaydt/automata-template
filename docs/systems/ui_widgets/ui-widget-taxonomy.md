# UI Widget Taxonomy

## Overview

The UI widget refactor extracts reusable, independently-testable components from monolithic screen controllers. This document serves as the canonical reference for the current widget types, their contracts, and how to migrate existing screens.

## Philosophy

- **No BaseWidget class.** Every widget extends plain `Control` or is a `class_name`d static helper. This avoids inheritance coupling and makes each widget self-contained.
- **Internal nodes via `add_child()`.** Widgets create their own internal tree (e.g. `HButtonArray` inside `W_TabStrip`). Callers never manually construct child nodes.
- **Static helpers for stateless logic.** When a pattern is pure computation (tree walking, focus configuration), prefer a static helper over a scene-tree node to avoid node overhead.
- **Isolated tests in bare scene trees.** Every widget has a matching `test_w_*.gd` that instantiates the widget in an empty scene, exercises its public API, and asserts on signals/properties.

## Widget Catalog

### Control Nodes (Scene-Tree Widgets)

These are instantiated with `.new()` and added to the screen tree.

#### W_TabStrip
**File:** `res://scripts/core/ui/widgets/w_tab_strip.gd`
**Contract:** Horizontal tab bar with shoulder (LB/RB) navigation, signal-driven tab switching.
**Key API:**
```gdscript
var tabs := W_TabStrip.new()
tabs.set_tabs(["Display", "Audio", "VFX"])
tabs.set_active_tab(0)
tabs.tab_selected.connect(_on_tab_selected)
```
**Consumers:** `UI_SettingsPanel`
**Tests:** `tests/unit/ui/widgets/test_w_tab_strip.gd` (10 tests)

#### W_OverlayChrome
**File:** `res://scripts/core/ui/widgets/w_overlay_chrome.gd`
**Contract:** Close button + optional title label placed at the top edge of an overlay panel.
**Key API:**
```gdscript
var chrome := W_OverlayChrome.new()
chrome.set_close_target(self)
chrome.set_close_callback(_on_close)
chrome.set_title("Settings")
add_child(chrome)
```
**Consumers:** `UI_SettingsPanel`
**Tests:** `tests/unit/ui/widgets/test_w_overlay_chrome.gd` (6 tests)

#### W_MenuButtonList
**File:** `res://scripts/core/ui/widgets/w_menu_button_list.gd`
**Contract:** Vertical button list with focus wrapping, `add_button()` API, and optional visibility callbacks.
**Key API:**
```gdscript
var list := W_MenuButtonList.new()
list.add_button("Resume", _on_resume, true)  # label, callback, visible
list.add_button("Settings", _on_settings, true)
add_child(list)
```
**Consumers:** `UI_PauseMenu`, `UI_MainMenu`
**Tests:** `tests/unit/ui/widgets/test_w_menu_button_list.gd` (9 tests)

#### W_RightStickScroller
**File:** `res://scripts/core/ui/widgets/w_right_stick_scroller.gd`
**Contract:** Polls `JOY_AXIS_RIGHT_X/Y` and drives `ScrollContainer` scroll offsets.
**Key API:**
```gdscript
var scroller := W_RightStickScroller.new()
scroller.bind_scroll_container(_scroll_container, 800.0, W_AnalogStickAdapter.STICK_DEADZONE)
add_child(scroller)
```
**Consumers:** `UI_InputRebindingOverlay`
**Tests:** `tests/unit/ui/widgets/test_w_right_stick_scroller.gd` (3 tests)

#### W_SaveSlotGrid
**File:** `res://scripts/core/ui/widgets/w_save_slot_grid.gd`
**Contract:** Manages save-slot list UI with thumbnails, main buttons, optional delete buttons, focus chaining, and slot press signals.
**Key API:**
```gdscript
var grid := W_SaveSlotGrid.new()
grid.bind_slot_container(existing_vbox)
grid.set_slots(metadata, &"save", U_UIThemeBuilder.active_config)
grid.slot_pressed.connect(_on_slot_pressed)
```
**Consumers:** `UI_SaveLoadMenu`
**Tests:** `tests/unit/ui/widgets/test_w_save_slot_grid.gd` (9 tests)

---

### Static Helpers (Stateless Utilities)

These are `class_name`d scripts with `static func` only. No node instantiation.

#### W_BackgroundImage
**File:** `res://scripts/core/ui/widgets/w_background_image.gd`
**Contract:** Maps shader-preset enum strings to static 400×400 PNG textures and returns a configured `TextureRect`.
**Key API:**
```gdscript
var bg := W_BackgroundImage.setup_from_preset("retro_grid")
if bg != null:
    add_child(bg)
```
**Consumers:** `BaseMenuScreen._setup_background_shader()`, `UI_LoadingScreen._setup_background_shader()`
**Tests:** `tests/unit/ui/widgets/test_w_background_image.gd` (5 tests)

#### W_BackgroundShader
**File:** `res://scripts/core/ui/widgets/w_background_shader.gd`
**Contract:** Creates or re-uses a `ShaderMaterial` on a `ColorRect`, applies `sh_menu_fullscreen_shader.gdshader` uniforms.
**Key API:**
```gdscript
var material := W_BackgroundShader.setup_material(rect, "retro_grid", 0.5, 1.0)
W_BackgroundShader.update_uniforms(material, "scanline_drift", 0.8, 2.0)
```
**Consumers:** `BaseMenuScreen`, `UI_LoadingScreen`
**Tests:** `tests/unit/ui/widgets/test_w_background_shader.gd` (7 tests)

#### W_AnalogStickAdapter
**File:** `res://scripts/core/ui/widgets/w_analog_stick_adapter.gd`
**Contract:** Encapsulates analog stick deadzone detection (`Input.get_joy_axis`) and input-event swallowing (`set_input_as_handled`).
**Key API:**
```gdscript
if W_AnalogStickAdapter.should_swallow(event):
    viewport.set_input_as_handled()
var up := W_AnalogStickAdapter.is_pressed("ui_up")
```
**Consumers:** `BaseMenuScreen._process()`, `BaseMenuScreen._unhandled_input()`
**Tests:** `tests/unit/ui/widgets/test_w_analog_stick_adapter.gd` (4 tests)

#### W_MotionTargetResolver
**File:** `res://scripts/core/ui/widgets/w_motion_target_resolver.gd`
**Contract:** Walks the screen node tree to find the motion-animation target: explicit `NodePath` → `CenterContainer` with `PanelContainer` descendant → fallback to screen itself.
**Key API:**
```gdscript
var target := W_MotionTargetResolver.resolve(self, motion_target_path)
```
**Consumers:** `BaseMenuScreen.play_enter_animation()`, `BaseMenuScreen.play_exit_animation()`
**Tests:** `tests/unit/ui/widgets/test_w_motion_target_resolver.gd` (5 tests)

#### W_SettingsFocusConfigurator
**File:** `res://scripts/core/ui/widgets/w_settings_focus_configurator.gd`
**Contract:** Collects focusable controls from a settings tab (via `Callable` getters to handle null/visible guards) and configures vertical/horizontal focus neighbors.
**Key API:**
```gdscript
W_SettingsFocusConfigurator.configure_vertical(self, [
    func() -> Control: return _mouse_sensitivity_slider,
    func() -> Control: return _reset_button,
])
W_SettingsFocusConfigurator.configure_inline_pairs(self, [
    [_reset_button, _rebind_button]
])
```
**Consumers:** All 8 settings tab scripts (`UI_DisplaySettingsTab`, `UI_AudioSettingsTab`, `UI_VFXSettingsTab`, `UI_LocalizationSettingsTab`, `UI_KeyboardMouseSettingsTab`, `UI_TouchscreenSettingsTab`, `UI_GamepadSettingsTab`)
**Tests:** `tests/unit/ui/widgets/test_w_settings_focus_configurator.gd` (5 tests)

#### W_SaveSlotThumbnailLoader
**File:** `res://scripts/core/ui/widgets/w_save_slot_thumbnail_loader.gd`
**Contract:** Async threaded texture loading with filesystem fallback for `user://` save slot thumbnails; `res://` threaded-load failures fall back to the placeholder for export safety.
**Consumers:** `W_SaveSlotGrid`
**Tests:** `tests/unit/ui/widgets/test_w_save_slot_thumbnail_loader.gd` (3 tests)

#### W_SaveSlotRowFactory
**File:** `res://scripts/core/ui/widgets/w_save_slot_row_factory.gd`
**Contract:** Builds save-slot row controls and wires slot/delete callbacks for `W_SaveSlotGrid`.
**Consumers:** `W_SaveSlotGrid`
**Tests:** Covered by `tests/unit/ui/widgets/test_w_save_slot_grid.gd`

#### W_SaveSlotFormatter
**File:** `res://scripts/core/ui/widgets/w_save_slot_formatter.gd`
**Contract:** Formats ISO timestamps, playtime, slot display names, and save-slot button text.
**Consumers:** `W_SaveSlotGrid`, `UI_SaveLoadMenu`
**Tests:** `tests/unit/ui/widgets/test_w_save_slot_formatter.gd` (4 tests)

---

## File Structure

```
scripts/core/ui/widgets/
├── w_tab_strip.gd
├── w_overlay_chrome.gd
├── w_menu_button_list.gd
├── w_background_image.gd
├── w_background_shader.gd
├── w_analog_stick_adapter.gd
├── w_motion_target_resolver.gd
├── w_settings_focus_configurator.gd
├── w_right_stick_scroller.gd
├── w_save_slot_grid.gd
├── w_save_slot_row_factory.gd
├── w_save_slot_thumbnail_loader.gd
└── w_save_slot_formatter.gd

tests/unit/ui/widgets/
├── test_w_tab_strip.gd
├── test_w_overlay_chrome.gd
├── test_w_menu_button_list.gd
├── test_w_background_image.gd
├── test_w_background_shader.gd
├── test_w_analog_stick_adapter.gd
├── test_w_motion_target_resolver.gd
├── test_w_settings_focus_configurator.gd
├── test_w_right_stick_scroller.gd
├── test_w_save_slot_grid.gd
├── test_w_save_slot_thumbnail_loader.gd
└── test_w_save_slot_formatter.gd
```

## Style Constraints

From `tests/unit/style/test_style_enforcement.gd`:

- **All `scripts/core/ui/widgets/w_*.gd` files must be under 120 lines.**
- **All `scripts/core/ui/widgets/` files must use the `w_` prefix.**
- Core scripts must never import from `demo/` paths.

## Migration Guide for LLMs

### When adding a new settings tab

1. Add `const W_SETTINGS_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/widgets/w_settings_focus_configurator.gd")`
2. In `_configure_focus_neighbors()`, replace the 20-25 line null-check + `append` + `U_FOCUS_CONFIGURATOR.configure_vertical_focus(...)` block with:
   ```gdscript
   W_SETTINGS_FOCUS_CONFIGURATOR.configure_vertical(self, [
       func() -> Control: return _my_slider,
       func() -> Control: return _my_toggle,
       ...
   ])
   ```
3. For horizontal button rows (Cancel/Reset/Apply):
   ```gdscript
   W_SETTINGS_FOCUS_CONFIGURATOR.configure_horizontal(self, [_cancel_btn, _reset_btn, _apply_btn], true)
   ```

### When building a new full-screen menu

1. Extend `BaseMenuScreen` (already delegates analog stick, background, and motion target logic to widgets).
2. For vertical button lists, instantiate `W_MenuButtonList` instead of manually creating `Button` nodes.
3. For tabbed panels, instantiate `W_TabStrip` instead of inline `HButtonArray` or `TabContainer`.

### When migrating an existing overlay

1. List all `@onready` nodes. Keep native popup nodes such as `ConfirmationDialog` and `AcceptDialog`, plus business-logic dependencies that are not UI chrome.
2. Prefer builder-bound or widget-owned chrome over new `@onready` chrome declarations. `BaseOverlay` has no `@onready` chrome baseline and should stay thin.
3. Extract large inline UI logic blocks to widgets:
   ```gdscript
   var grid := W_SaveSlotGrid.new()
   grid.bind_slot_container(_slot_list_container)
   grid.set_slots(metadata, mode, theme_config)
   ```
4. Keep overlay scripts focused on business actions, store dispatch, modal dialog behavior, and builder setup.

## Testing Patterns

Every widget test follows this structure:

```gdscript
extends GutTest

const W_MyWidget := preload("res://scripts/core/ui/widgets/w_my_widget.gd")

func test_my_behavior() -> void:
    var widget := W_MyWidget.new()
    add_child_autofree(widget)
    await wait_process_frames(1)

    # Exercise public API
    widget.some_method("value")

    # Assert on signals, properties, or tree state
    assert_eq(widget.some_property, expected_value)
```

- Use `add_child_autofree(widget)` so GUT cleans up.
- Use `await wait_process_frames(1)` after adding to tree so `_ready()` and deferred signals fire.
- Do NOT mock internal nodes; test through the public API only.

## Remaining Monolithic Areas

Not yet widgetized:

- **Settings tab form rows** — `U_SETTINGS_TAB_BUILDER` already handles row creation; extracting further would create builder-to-widget coupling. Keep as-is.
- **Dialog overlays** — Native `ConfirmationDialog`/`AcceptDialog` are Godot builtins with platform-specific windowing. Wrapping them adds abstraction with no testability gain.
- **Save/Load menu** — Phase 11 extracted slot-grid rendering, thumbnail loading, and display formatting into widgets. Keep save/load/delete business actions in `UI_SaveLoadMenu`.

## Changelog

- **2026-05-09** — Phase 12 complete. Documented the BaseOverlay migration rule: prefer builder/widget chrome over additional `@onready` chrome declarations.
- **2026-05-09** — Phase 11 complete. Added `W_SaveSlotGrid`, `W_SaveSlotThumbnailLoader`, and `W_SaveSlotFormatter`; integrated into `UI_SaveLoadMenu`.
- **2025-05-07** — Phase 8 complete. Added `W_BackgroundShader`.
- **2025-05-07** — Phase 7 complete. Added `W_MotionTargetResolver`.
- **2025-05-07** — Phase 6 complete. Added `W_AnalogStickAdapter`, removed unused `W_FocusNavigator`.
- **2025-05-07** — Phase 5 complete. Added `W_SettingsFocusConfigurator`, integrated into all 8 settings tabs.
- **2025-05-07** — Phase 4 complete. Added `W_FocusNavigator` (later removed), integrated into `BaseMenuScreen`.
- **2025-05-07** — Phase 3 complete. Added `W_BackgroundImage`.
- **2025-05-07** — Phase 2 complete. Integrated `W_MenuButtonList` into `UI_MainMenu`.
- **2025-05-07** — Phase 1 complete. Added `W_TabStrip`, `W_OverlayChrome`, `W_MenuButtonList`. Integrated into `UI_SettingsPanel`, `UI_PauseMenu`.
