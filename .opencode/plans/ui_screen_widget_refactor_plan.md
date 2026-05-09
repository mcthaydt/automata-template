# UI Screen Widget Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose monolithic UI screen controllers into small, single-responsibility `W_*` widgets with isolated tests, making future LLM-driven changes reliable and scoped to ≤2 files.

**Architecture:** Extract reusable widgets (`W_TabStrip`, `W_OverlayChrome`, `W_MenuButtonList`) from `UI_SettingsPanel`, `UI_PauseMenu`, and `UI_MainMenu`. Screen controllers become thin orchestrators (≤120 lines) that instantiate widgets and wire store signals. Widgets extend plain `Control` with no base class, keeping them self-contained.

**Tech Stack:** Godot 4.7 (GDScript), GUT (headless via `tools/run_gut_suite.sh`), Redux navigation slice.

---

## File Structure Map

| New Files | Responsibility |
|-----------|---------------|
| `scripts/core/ui/widgets/w_tab_strip.gd` | Horizontal tab strip with `ButtonGroup`, shoulder hints, visible-tab cycling |
| `tests/unit/ui/widgets/test_w_tab_strip.gd` | Isolated widget tests (bare tree, no PackedScene) |
| `scripts/core/ui/widgets/w_overlay_chrome.gd` | Close button + panel chrome header row |
| `tests/unit/ui/widgets/test_w_overlay_chrome.gd` | Chrome layout and close signal tests |
| `scripts/core/ui/widgets/w_menu_button_list.gd` | Vertical button column, focus wrapping, theme tokens |
| `tests/unit/ui/widgets/test_w_menu_button_list.gd` | Button list focus and callback tests |
| `scripts/core/ui/widgets/w_background_image.gd` | Auto-provision `TextureRect` from preset map |
| `tests/unit/ui/widgets/test_w_background_image.gd` | Background image provisioning tests |

| Modified Files | Responsibility |
|--------------|---------------|
| `scripts/core/ui/settings/ui_settings_panel.gd` | Reduced to orchestrator (~100 lines) |
| `scripts/core/ui/menus/ui_pause_menu.gd` | Reduced to orchestrator (~80 lines) |
| `scripts/core/ui/menus/ui_main_menu.gd` | Reduced to orchestrator (~100 lines) — Phase 2 |

---

## Task 1: W_TabStrip Widget

**Files:**
- Create: `scripts/core/ui/widgets/w_tab_strip.gd`
- Create: `tests/unit/ui/widgets/test_w_tab_strip.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/ui/widgets/test_w_tab_strip.gd
extends GutTest

const W_TabStrip := preload("res://scripts/core/ui/widgets/w_tab_strip.gd")

func test_add_tab_and_switch() -> void:
    var strip := W_TabStrip.new()
    var btn_a := Button.new()
    var btn_b := Button.new()
    strip.add_tab(0, btn_a, &"tab_a", "Tab A")
    strip.add_tab(1, btn_b, &"tab_b", "Tab B")
    add_child_autofree(strip)
    await wait_process_frames(1)
    strip.switch_to_tab(1)
    assert_eq(strip.get_active_tab_id(), 1)
    assert_true(btn_b.button_pressed, "Active tab button should be pressed")

func test_shoulder_navigation_skips_hidden_tabs() -> void:
    var strip := W_TabStrip.new()
    strip.add_tab(0, Button.new(), &"a", "A")
    strip.add_tab(1, Button.new(), &"b", "B")
    strip.add_tab(2, Button.new(), &"c", "C")
    add_child_autofree(strip)
    strip.set_tab_visible(1, false)
    strip.switch_to_tab(0)
    strip.handle_shoulder_input(1)
    assert_eq(strip.get_active_tab_id(), 2, "Should skip hidden tab 1")

func test_tab_switch_emits_signal() -> void:
    var strip := W_TabStrip.new()
    strip.add_tab(0, Button.new(), &"a", "A")
    var received_id: int = -1
    strip.tab_switched.connect(func(id: int) -> void: received_id = id)
    strip.switch_to_tab(0)
    assert_eq(received_id, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/widgets/test_w_tab_strip.gd`
Expected: FAIL with `Parser Error: Could not find type "W_TabStrip"`

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/core/ui/widgets/w_tab_strip.gd
extends Control
class_name W_TabStrip

signal tab_switched(tab_id: int)

var _tab_buttons: Dictionary = {}
var _tab_order: Array[int] = []
var _active_tab: int = -1
var _button_group: ButtonGroup = ButtonGroup.new()
var _shoulder_hint_row: HBoxContainer = null
var _shoulder_hint_lb: PanelContainer = null
var _shoulder_hint_rb: PanelContainer = null

func add_tab(tab_id: int, button: Button, label_key: StringName, fallback: String) -> void:
    button.toggle_mode = true
    button.button_group = _button_group
    button.pressed.connect(_on_tab_button_pressed.bind(tab_id))
    button.focus_entered.connect(_on_tab_focused.bind(tab_id))
    _tab_buttons[tab_id] = {"button": button, "key": label_key, "fallback": fallback}
    _tab_order.append(tab_id)
    add_child(button)

func switch_to_tab(tab_id: int) -> void:
    if _active_tab == tab_id:
        return
    _active_tab = tab_id
    var entry: Dictionary = _tab_buttons.get(tab_id, {})
    var btn: Button = entry.get("button") as Button
    if btn != null:
        btn.button_pressed = true
    tab_switched.emit(tab_id)

func get_active_tab_id() -> int:
    return _active_tab

func set_tab_visible(tab_id: int, visible: bool) -> void:
    var entry: Dictionary = _tab_buttons.get(tab_id, {})
    var btn: Button = entry.get("button") as Button
    if btn != null:
        btn.visible = visible

func handle_shoulder_input(direction: int) -> void:
    var visible: Array[int] = _get_visible_tab_ids()
    if visible.is_empty():
        return
    var current_index: int = visible.find(_active_tab)
    if current_index < 0:
        current_index = 0
    var next_index: int = wrapi(current_index + direction, 0, visible.size())
    switch_to_tab(visible[next_index])

func _get_visible_tab_ids() -> Array[int]:
    var result: Array[int] = []
    for tab_id: int in _tab_order:
        var entry: Dictionary = _tab_buttons.get(tab_id, {})
        var btn: Button = entry.get("button") as Button
        if btn != null and btn.visible:
            result.append(tab_id)
    return result

func _on_tab_button_pressed(tab_id: int) -> void:
    switch_to_tab(tab_id)

func _on_tab_focused(tab_id: int) -> void:
    switch_to_tab(tab_id)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/widgets/test_w_tab_strip.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/widgets/w_tab_strip.gd tests/unit/ui/widgets/test_w_tab_strip.gd
git commit -m "feat(ui): add W_TabStrip widget with isolated tests (GREEN)"
```

---

## Task 2: Integrate W_TabStrip into UI_SettingsPanel

**Files:**
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd` (remove tab logic, add widget)
- Modify: `tests/unit/ui/settings/test_settings_panel_tabs.gd` (update assertions for widget boundary)

- [ ] **Step 1: Remove inline tab methods from UI_SettingsPanel**

Delete from `UI_SettingsPanel`:
- `_build_tab_bar()`
- `_create_shoulder_prompts()`
- `_bind_tab_bar_motion()`
- `_configure_focus_neighbors()` (tab button part only; keep content focus)
- `_configure_tab_key_focus_paths()`
- `_switch_visible_tab()`
- `_get_visible_tab_ids()`
- `_update_tab_button_states()`
- `_set_tab_visible()`
- `_is_tab_hidden()`
- `_snap_to_first_visible_tab()`
- `_find_first_focusable_in_tab()`
- `_get_focusable_descendants()`
- `_on_tab_button_pressed()`
- `_on_tab_button_focused()`
- `_navigate_focus()` override (move consume_next_nav to controller level)
- `_unhandled_input()` shoulder handling (move to controller)

- [ ] **Step 2: Add W_TabStrip orchestration in UI_SettingsPanel**

```gdscript
# In UI_SettingsPanel._on_panel_ready():
_tab_strip = W_TabStrip.new()
_tab_bar.add_child(_tab_strip)  # _tab_bar is the existing HBoxContainer
for tab_id: TabId in _TAB_ORDER:
    var label_info: Dictionary = _TAB_LABELS[tab_id]
    var button := Button.new()
    button.text = U_LOCALIZATION_UTILS.localize_with_fallback(label_info.key, label_info.fallback)
    button.name = "TabButton_%d" % tab_id
    button.focus_mode = Control.FOCUS_ALL
    _tab_strip.add_tab(tab_id, button, label_info.key, label_info.fallback)
_tab_strip.tab_switched.connect(_on_tab_switched)

# Replace _unhandled_input shoulder handling:
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_focus_next"):
        _tab_strip.handle_shoulder_input(1)
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("ui_focus_prev"):
        _tab_strip.handle_shoulder_input(-1)
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)
```

- [ ] **Step 3: Run existing SettingsPanel tests**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tabs.gd`
Expected: PASS (with possible minor test adjustments for node path changes)

- [ ] **Step 4: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd tests/unit/ui/settings/test_settings_panel_tabs.gd
git commit -m "refactor(ui): integrate W_TabStrip into UI_SettingsPanel (GREEN)"
```

---

## Task 3: W_OverlayChrome Widget

**Files:**
- Create: `scripts/core/ui/widgets/w_overlay_chrome.gd`
- Create: `tests/unit/ui/widgets/test_w_overlay_chrome.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/ui/widgets/test_w_overlay_chrome.gd
extends GutTest

const W_OverlayChrome := preload("res://scripts/core/ui/widgets/w_overlay_chrome.gd")

func test_creates_close_button() -> void:
    var chrome := W_OverlayChrome.new()
    add_child_autofree(chrome)
    await wait_process_frames(1)
    var close := chrome.get_close_button()
    assert_not_null(close, "Chrome should create a close button")
    assert_eq(close.name, "CloseButton")

func test_emits_close_pressed() -> void:
    var chrome := W_OverlayChrome.new()
    add_child_autofree(chrome)
    await wait_process_frames(1)
    var emitted: bool = false
    chrome.close_pressed.connect(func() -> void: emitted = true)
    chrome.get_close_button().emit_signal("pressed")
    assert_true(emitted)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/widgets/test_w_overlay_chrome.gd`
Expected: FAIL (missing class)

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/core/ui/widgets/w_overlay_chrome.gd
extends Control
class_name W_OverlayChrome

signal close_pressed

var _close_button: Button = null
var _panel_chrome: HBoxContainer = null

func _ready() -> void:
    _panel_chrome = HBoxContainer.new()
    _panel_chrome.name = "PanelChrome"
    _panel_chrome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(_panel_chrome)

    _close_button = Button.new()
    _close_button.name = "CloseButton"
    _close_button.text = "X"
    _close_button.flat = true
    _close_button.focus_mode = Control.FOCUS_NONE
    _close_button.custom_minimum_size = Vector2(44, 44)
    _close_button.pressed.connect(func() -> void: close_pressed.emit())
    add_child(_close_button)

func get_close_button() -> Button:
    return _close_button

func get_chrome_row() -> HBoxContainer:
    return _panel_chrome
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/widgets/test_w_overlay_chrome.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/widgets/w_overlay_chrome.gd tests/unit/ui/widgets/test_w_overlay_chrome.gd
git commit -m "feat(ui): add W_OverlayChrome widget with isolated tests (GREEN)"
```

---

## Task 4: Integrate W_OverlayChrome into UI_SettingsPanel

**Files:**
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Replace inline chrome logic with W_OverlayChrome**

Delete from `UI_SettingsPanel`:
- `_create_close_button()`
- `_create_panel_chrome()`
- `_attach_close_button_to_chrome()`

Add in `_on_panel_ready()`:
```gdscript
_chrome = W_OverlayChrome.new()
_chrome.close_pressed.connect(_on_close_pressed)
# Reparent existing _tab_bar into chrome row if needed
```

- [ ] **Step 2: Run SettingsPanel tests**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/`
Expected: PASS

- [ ] **Step 3: Run full UI suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd
git commit -m "refactor(ui): integrate W_OverlayChrome into UI_SettingsPanel (GREEN)"
```

---

## Task 5: W_MenuButtonList Widget

**Files:**
- Create: `scripts/core/ui/widgets/w_menu_button_list.gd`
- Create: `tests/unit/ui/widgets/test_w_menu_button_list.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/ui/widgets/test_w_menu_button_list.gd
extends GutTest

const W_MenuButtonList := preload("res://scripts/core/ui/widgets/w_menu_button_list.gd")

func test_adds_buttons_vertically() -> void:
    var list := W_MenuButtonList.new()
    list.add_button(&"play", "Play", Callable())
    list.add_button(&"quit", "Quit", Callable())
    add_child_autofree(list)
    await wait_process_frames(1)
    var buttons: Array[Button] = list.get_buttons()
    assert_eq(buttons.size(), 2)
    assert_eq(buttons[0].text, "Play")

func test_focuses_first_button() -> void:
    var list := W_MenuButtonList.new()
    list.add_button(&"a", "A", Callable())
    list.add_button(&"b", "B", Callable())
    add_child_autofree(list)
    await wait_process_frames(1)
    var buttons: Array[Button] = list.get_buttons()
    assert_true(buttons[0].has_focus())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/widgets/test_w_menu_button_list.gd`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/core/ui/widgets/w_menu_button_list.gd
extends VBoxContainer
class_name W_MenuButtonList

var _buttons: Array[Button] = []

func add_button(key: StringName, fallback: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = fallback
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if callback.is_valid():
        button.pressed.connect(callback)
    add_child(button)
    _buttons.append(button)

func get_buttons() -> Array[Button]:
    return _buttons.duplicate()

func configure_vertical_focus(wrap: bool = true) -> void:
    if _buttons.is_empty():
        return
    U_FocusConfigurator.configure_vertical_focus(_buttons, wrap)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/widgets/test_w_menu_button_list.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/widgets/w_menu_button_list.gd tests/unit/ui/widgets/test_w_menu_button_list.gd
git commit -m "feat(ui): add W_MenuButtonList widget with isolated tests (GREEN)"
```

---

## Task 6: Integrate W_MenuButtonList into UI_PauseMenu

**Files:**
- Modify: `scripts/core/ui/menus/ui_pause_menu.gd`

- [ ] **Step 1: Remove inline button setup, use W_MenuButtonList**

In `UI_PauseMenu._on_panel_ready()`:
```gdscript
var button_list := W_MenuButtonList.new()
button_list.add_button(&"menu.pause.resume", "Resume", _on_resume_pressed)
button_list.add_button(&"menu.pause.settings", "Settings", _on_settings_pressed)
button_list.add_button(&"menu.pause.save", "Save", _on_save_pressed)
button_list.add_button(&"menu.pause.load", "Load", _on_load_pressed)
button_list.add_button(&"menu.pause.quit", "Quit", _on_quit_pressed)
button_list.configure_vertical_focus(true)
_main_panel_content.add_child(button_list)
```

Delete `_setup_menu_builder()` and builder references.

- [ ] **Step 2: Run PauseMenu tests**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu.gd`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add scripts/core/ui/menus/ui_pause_menu.gd
git commit -m "refactor(ui): integrate W_MenuButtonList into UI_PauseMenu (GREEN)"
```

---

## Task 7: Style Enforcement

**Files:**
- Modify: `tests/unit/style/test_style_enforcement.gd` (add widget LOC cap)

- [ ] **Step 1: Add `test_widget_file_size_cap`**

```gdscript
func test_widget_file_size_cap() -> void:
    var widget_files := _glob_scripts("res://scripts/core/ui/widgets/")
    for path in widget_files:
        var line_count: int = _count_lines(path)
        if line_count > 120:
            push_error("Widget %s exceeds 120-line cap (%d lines)" % [path, line_count])
            fail_test("Widget file size cap exceeded")
```

- [ ] **Step 2: Run style suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add tests/unit/style/test_style_enforcement.gd
git commit -m "style: enforce 120-line cap on W_* widget files (GREEN)"
```

---

## Task 8: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `tools/run_gut_suite.sh`
Expected: Zero unexpected failures; maintain or increase test count.

- [ ] **Step 2: Run style suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: PASS

- [ ] **Step 3: Manual smoke test matrix**

Verify these flows still work:
- [ ] Main menu → Settings panel → tab cycling with shoulder buttons
- [ ] Pause menu → Settings → back to Pause
- [ ] Gameplay → ESC → Pause → Resume
- [ ] Settings panel tab visibility hides Gamepad tab when no gamepad

---

## Self-Review Checklist

- [ ] **Spec coverage:** Every widget from taxonomy (W_TabStrip, W_OverlayChrome, W_MenuButtonList) has an extraction task. SettingsPanel and PauseMenu are covered.
- [ ] **No placeholders:** Every step contains exact file paths, exact code, and exact commands.
- [ ] **Type consistency:** `W_TabStrip.add_tab(tab_id: int, ...)` uses `int` consistently. `W_MenuButtonList` returns `Array[Button]`.
- [ ] **Test isolation:** Widget tests never load a `.tscn`; they use `add_child_autofree(widget)` in a bare tree.
- [ ] **No `.tscn` changes:** This refactor is script-only; no headless rebuild required.

---

## Execution Handoff

**Plan saved to:** `.opencode/plans/ui_screen_widget_refactor_plan.md`

**Execution mode:** Inline Execution (Option 2)

**Next step:** Begin Task 1 once plan mode ends.
