# Settings Panel Theme Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activate the full theme pipeline (StyleBoxes, focus rings, motion animations, accessibility palette switching, tab type variations, responsive sizing) for the settings panel, add a mobile close affordance, and wire controller tab navigation — all of which are defined but unused.

**Architecture:** Hybrid base-theme + semantic-exceptions pattern. `U_UIThemeBuilder.build_theme()` is called once to produce a full `Theme` resource that cascades through all children. Semantic role overrides remain only for contextual exceptions. Motion is wired via `motion_set` (enter/exit) + `bind_interactive` (per-control). A new `U_UIPaletteResolver` utility maps accessibility state to palette `.tres` resources, and `U_UIThemeBuilder` is extended to apply full palette overrides.

**Tech Stack:** Godot 4.7 Dev 5, GDScript, Redux state store, `BaseOverlay`/`BasePanel` base classes, `U_UIThemeBuilder` + `RS_UIThemeConfig`, `U_UIMotion` + `RS_UIMotionSet`

---

### Task 1: U_UIPaletteResolver — Create utility + tests

**Files:**
- Create: `scripts/core/ui/utils/u_ui_palette_resolver.gd`
- Create: `tests/unit/ui/test_ui_palette_resolver.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"

const U_UIPaletteResolver := preload("res://scripts/core/ui/utils/u_ui_palette_resolver.gd")

const PALETTE_NORMAL := preload("res://resources/core/ui_themes/cfg_palette_normal.tres")
const PALETTE_DEUTERANOPIA := preload("res://resources/core/ui_themes/cfg_palette_deuteranopia.tres")
const PALETTE_DEUTERANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_deuteranopia_high_contrast.tres")
const PALETTE_PROTANOPIA := preload("res://resources/core/ui_themes/cfg_palette_protanopia.tres")
const PALETTE_PROTANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_protanopia_high_contrast.tres")
const PALETTE_TRITANOPIA := preload("res://resources/core/ui_themes/cfg_palette_tritanopia.tres")
const PALETTE_TRITANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_tritanopia_high_contrast.tres")
const PALETTE_NORMAL_HC := preload("res://resources/core/ui_themes/cfg_palette_normal_high_contrast.tres")

func test_resolve_normal_no_contrast_returns_default() -> void:
	var result := U_UIPaletteResolver.resolve_palette("normal", false)
	assert_eq(result, PALETTE_NORMAL)

func test_resolve_normal_high_contrast_returns_normal_hc() -> void:
	var result := U_UIPaletteResolver.resolve_palette("normal", true)
	assert_eq(result, PALETTE_NORMAL_HC)

func test_resolve_deuteranopia_no_contrast_returns_deuteranopia() -> void:
	var result := U_UIPaletteResolver.resolve_palette("deuteranopia", false)
	assert_eq(result, PALETTE_DEUTERANOPIA)

func test_resolve_deuteranopia_high_contrast_returns_deuteranopia_hc() -> void:
	var result := U_UIPaletteResolver.resolve_palette("deuteranopia", true)
	assert_eq(result, PALETTE_DEUTERANOPIA_HC)

func test_resolve_protanopia_no_contrast_returns_protanopia() -> void:
	var result := U_UIPaletteResolver.resolve_palette("protanopia", false)
	assert_eq(result, PALETTE_PROTANOPIA)

func test_resolve_protanopia_high_contrast_returns_protanopia_hc() -> void:
	var result := U_UIPaletteResolver.resolve_palette("protanopia", true)
	assert_eq(result, PALETTE_PROTANOPIA_HC)

func test_resolve_tritanopia_no_contrast_returns_tritanopia() -> void:
	var result := U_UIPaletteResolver.resolve_palette("tritanopia", false)
	assert_eq(result, PALETTE_TRITANOPIA)

func test_resolve_tritanopia_high_contrast_returns_tritanopia_hc() -> void:
	var result := U_UIPaletteResolver.resolve_palette("tritanopia", true)
	assert_eq(result, PALETTE_TRITANOPIA_HC)

func test_resolve_unknown_mode_falls_back_to_normal() -> void:
	var result := U_UIPaletteResolver.resolve_palette("bogus", true)
	assert_eq(result, PALETTE_NORMAL)

func test_resolve_unknown_mode_no_contrast_falls_back_to_normal() -> void:
	var result := U_UIPaletteResolver.resolve_palette("bogus", false)
	assert_eq(result, PALETTE_NORMAL)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --script tests/unit/ui/test_ui_palette_resolver.gd 2>&1 | head -20`
Expected: Parse error or "U_UIPaletteResolver not found"

- [ ] **Step 3: Write minimal implementation**

```gdscript
extends RefCounted
class_name U_UIPaletteResolver

const RS_UI_COLOR_PALETTE := preload("res://scripts/core/resources/ui/rs_ui_color_palette.gd")

const PALETTE_NORMAL := preload("res://resources/core/ui_themes/cfg_palette_normal.tres")
const PALETTE_DEUTERANOPIA := preload("res://resources/core/ui_themes/cfg_palette_deuteranopia.tres")
const PALETTE_DEUTERANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_deuteranopia_high_contrast.tres")
const PALETTE_PROTANOPIA := preload("res://resources/core/ui_themes/cfg_palette_protanopia.tres")
const PALETTE_PROTANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_protanopia_high_contrast.tres")
const PALETTE_TRITANOPIA := preload("res://resources/core/ui_themes/cfg_palette_tritanopia.tres")
const PALETTE_TRITANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_tritanopia_high_contrast.tres")
const PALETTE_NORMAL_HC := preload("res://resources/core/ui_themes/cfg_palette_normal_high_contrast.tres")

const _PALETTE_MAP := {
	"deuteranopia": PALETTE_DEUTERANOPIA,
	"deuteranopia_high_contrast": PALETTE_DEUTERANOPIA_HC,
	"protanopia": PALETTE_PROTANOPIA,
	"protanopia_high_contrast": PALETTE_PROTANOPIA_HC,
	"tritanopia": PALETTE_TRITANOPIA,
	"tritanopia_high_contrast": PALETTE_TRITANOPIA_HC,
	"normal_high_contrast": PALETTE_NORMAL_HC,
}

static func resolve_palette(color_blind_mode: String, high_contrast: bool) -> Resource:
	if color_blind_mode == "normal" and not high_contrast:
		return PALETTE_NORMAL
	var key := color_blind_mode + ("_high_contrast" if high_contrast else "")
	return _PALETTE_MAP.get(key, PALETTE_NORMAL)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/run_gut_suite.sh -gtests=res://tests/unit/ui/test_ui_palette_resolver.gd`
Expected: All 10 tests PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/utils/u_ui_palette_resolver.gd tests/unit/ui/test_ui_palette_resolver.gd
git commit -m "feat: add U_UIPaletteResolver for accessibility palette mapping (GREEN)"
```

---

### Task 2: Extend U_UIThemeBuilder — type variations + full palette wiring

**Files:**
- Modify: `scripts/core/ui/utils/u_ui_theme_builder.gd`

- [ ] **Step 1: Add type variations method and full palette wiring to `U_UIThemeBuilder`**

Replace the `_apply_text_colors` method in `scripts/core/ui/utils/u_ui_theme_builder.gd:110-131` with the expanded version below. Also add `_apply_type_variations` and insert its call in `build_theme`.

In `build_theme` (line 38), insert after `_apply_text_colors(...)`:
```gdscript
	_apply_type_variations(theme, typed_config)
```

Add the new method before `_duplicate_theme_or_new`:
```gdscript
static func _apply_type_variations(theme: Theme, config) -> void:
	theme.set_type_variation(&"TabActive", &"Button")
	theme.set_stylebox(&"normal", &"TabActive", _create_tab_active_normal(config))
	theme.set_stylebox(&"focus", &"TabActive", _create_tab_active_focus(config))
	theme.set_color(&"font_color", &"TabActive", config.text_primary)

	theme.set_type_variation(&"TabInactive", &"Button")
	theme.set_stylebox(&"normal", &"TabInactive", _create_tab_inactive_normal(config))
	theme.set_stylebox(&"hover", &"TabInactive", _create_tab_inactive_hover(config))
	theme.set_stylebox(&"focus", &"TabInactive", config.focus_stylebox)
	theme.set_color(&"font_color", &"TabInactive", config.text_secondary)

static func _create_tab_active_normal(config) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = config.bg_panel_light
	style.border_color = config.bg_panel_light
	style.set_border_width_all(0)
	style.border_width_bottom = 2
	style.border_color = config.accent_primary
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

static func _create_tab_active_focus(config) -> StyleBoxFlat:
	var style := _create_tab_active_normal(config)
	style.border_color = config.accent_focus
	style.set_border_width_all(2)
	return style

static func _create_tab_inactive_normal(config) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

static func _create_tab_inactive_hover(config) -> StyleBoxFlat:
	var style := _create_tab_inactive_normal(config)
	style.bg_color = Color(config.bg_panel_light.r, config.bg_panel_light.g, config.bg_panel_light.b, 0.4)
	return style
```

Now replace `_apply_text_colors` with the full palette version:
```gdscript
static func _apply_text_colors(
	theme: Theme,
	config,
	palette: Resource,
	preserve_base_colors: bool
) -> void:
	var has_palette: bool = palette is RS_UI_COLOR_PALETTE
	var preserve_existing: bool = preserve_base_colors and not has_palette

	var text_color: Color = config.text_primary
	var accent_primary: Color = config.accent_primary
	var accent_hover: Color = config.accent_hover
	var accent_focus: Color = config.accent_focus
	var success_color: Color = config.success
	var warning_color: Color = config.warning
	var danger_color: Color = config.danger
	var slider_fill: Color = config.slider_fill_color
	var section_header_col: Color = config.section_header_color

	if has_palette:
		var typed_palette := palette as RS_UI_COLOR_PALETTE
		text_color = typed_palette.text
		accent_primary = typed_palette.primary
		accent_hover = typed_palette.secondary
		accent_focus = typed_palette.primary
		slider_fill = typed_palette.primary
		section_header_col = typed_palette.info
		success_color = typed_palette.success
		warning_color = typed_palette.warning
		danger_color = typed_palette.danger

	for type_name: StringName in _TEXT_COLOR_TYPES:
		if preserve_existing and theme.has_color(&"font_color", type_name):
			continue
		theme.set_color(&"font_color", type_name, text_color)

	_set_color_if_allowed(theme, &"font_disabled_color", &"Button", config.text_disabled, preserve_existing)
	_set_color_if_allowed(theme, &"font_pressed_color", &"Button", text_color, preserve_existing)
	_set_color_if_allowed(theme, &"font_hover_color", &"Button", text_color, preserve_existing)
	_set_color_if_allowed(theme, &"font_focus_color", &"Button", text_color, preserve_existing)

	if has_palette:
		theme.set_color(&"font_color", &"Button", text_color)
		theme.set_color(&"font_color", &"Label", text_color)
```

- [ ] **Step 2: Run existing tests to ensure no regressions**

Run: `tools/run_gut_suite.sh`
Expected: No new failures vs baseline. The `ui_virtual_joystick.gd` parse error is a known issue.

- [ ] **Step 3: Commit**

```bash
git add scripts/core/ui/utils/u_ui_theme_builder.gd
git commit -m "feat: add type variations + full palette wiring to U_UIThemeBuilder (GREEN)"
```

---

### Task 3: Add mobile close button to UI_SettingsPanel

**Files:**
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Add close button to settings panel `_ready()`**

In `ui_settings_panel.gd`, add a preloaded resource and modify `_ready()`:

Add after line 19 (after the last preload):
```gdscript
const CFG_MOTION_BUTTON_DEFAULT := preload("res://resources/core/ui/motions/cfg_motion_button_default.tres")
const U_UI_MOTION := preload("res://scripts/core/ui/utils/u_ui_motion.gd")
```

Add a new member variable after line 52 (`var _tab_buttons: Dictionary = {}`):
```gdscript
var _close_button: Button = null
```

In `_ready()` (line 61), modify to:
```gdscript
func _ready() -> void:
	super._ready()
	_create_close_button()
	_build_tab_bar()
	_create_tab_contents()
	_update_tab_visibility()
	switch_to_tab(TabId.DISPLAY)
```

Add the `_create_close_button` method before `_build_tab_bar`:
```gdscript
func _create_close_button() -> void:
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.flat = true
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.custom_minimum_size = Vector2(44, 44)
	_close_button.pressed.connect(_on_close_pressed)
	U_UI_MOTION.bind_interactive(_close_button, CFG_MOTION_BUTTON_DEFAULT)
	add_child(_close_button)
	_close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_button.offset_right = 0
	_close_button.offset_top = 8
	_close_button.offset_left = -52
	_close_button.offset_bottom = 52
```

Add the close handler:
```gdscript
func _on_close_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.close_top_overlay())
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd
git commit -m "feat: add persistent close button to settings panel for mobile touch (GREEN)"
```

---

### Task 4: Add horizontal focus to tab bar for controller navigation

**Files:**
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: The tab bar already has `U_FocusConfigurator.configure_horizontal_focus()` called in `_configure_focus_neighbors()` (line 205). But the navigation model extends `BaseMenuScreen` which uses analog stick `_navigate_focus` method. The tab buttons need to be included in the focus chain properly.

The `_configure_focus_neighbors` method already configures horizontal focus neighbors on visible tab buttons. The `switch_to_tab` method already grabs focus on the first focusable in the tab. However, when a controller user presses left/right while focused on a tab button, the horizontal focus neighbors should move between tabs without switching them — switching should only happen on confirm/select.

Modify `_build_tab_bar` (line 85) to use focus_entered for tab switching instead of pressed, while pressed still works for mouse/touch:

Replace line 97:
```gdscript
		button.pressed.connect(_on_tab_button_pressed.bind(tab_id))
```
With:
```gdscript
		button.pressed.connect(_on_tab_button_pressed.bind(tab_id))
		button.focus_entered.connect(_on_tab_button_focused.bind(tab_id))
```

Add the focus handler before `_on_tab_button_pressed`:
```gdscript
func _on_tab_button_focused(tab_id: TabId) -> void:
	switch_to_tab(tab_id)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd
git commit -m "feat: auto-switch tabs on controller focus for tab bar navigation (GREEN)"
```

---

### Task 5: Apply base theme to UI_SettingsPanel

**Files:**
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Add `_apply_base_theme()` and wire `motion_set`**

Add new constant preloads at the top of the file (after line 19). Note: `CFG_MOTION_BUTTON_DEFAULT` and `U_UI_MOTION` were already added by Task 3 — only add the two new ones:
```gdscript
const CFG_MOTION_FADE_SLIDE := preload("res://resources/core/ui/motions/cfg_motion_fade_slide.tres")
const U_UI_PALETTE_RESOLVER := preload("res://scripts/core/ui/utils/u_ui_palette_resolver.gd")
```

In `_ready()` (line 61), modify to call theme application before building tabs:
```gdscript
func _ready() -> void:
	super._ready()
	_apply_base_theme()
	_create_close_button()
	_build_tab_bar()
	_create_tab_contents()
	_update_tab_visibility()
	switch_to_tab(TabId.DISPLAY)
	_bind_tab_bar_motion()
```

Add `_apply_base_theme` method before `_create_close_button`:
```gdscript
func _apply_base_theme() -> void:
	var config: Resource = U_UI_THEME_BUILDER.active_config
	if not (config is RS_UI_THEME_CONFIG):
		return
	var typed_config := config as RS_UI_THEME_CONFIG
	typed_config.ensure_runtime_defaults()
	self.theme = U_UI_THEME_BUILDER.build_theme(typed_config)
	motion_set = CFG_MOTION_FADE_SLIDE
```

Add `_bind_tab_bar_motion` method:
```gdscript
func _bind_tab_bar_motion() -> void:
	for tab_key: int in _tab_buttons:
		var entry: Dictionary = _tab_buttons[tab_key]
		var button: Button = entry.button as Button
		if button != null:
			U_UI_MOTION.bind_interactive(button, CFG_MOTION_BUTTON_DEFAULT)
```

Also bind motion to the close button (add at end of `_create_close_button`):
```gdscript
	U_UI_MOTION.bind_interactive(_close_button, CFG_MOTION_BUTTON_DEFAULT)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd
git commit -m "feat: apply base Theme + motion_set to UI_SettingsPanel (GREEN)"
```

---

### Task 6: Wire motion to settings tab content controls

**Files:**
- Modify: `scripts/core/ui/helpers/u_settings_tab_builder.gd`
- Modify: `scripts/core/ui/settings/ui_display_settings_tab.gd` (and other tabs with dynamic controls)

- [ ] **Step 1: Add motion preloads and `bind_motion_to_focusable` to `U_SettingsTabBuilder`**

In `u_settings_tab_builder.gd`, add after line 7:
```gdscript
const U_UI_MOTION := preload("res://scripts/core/ui/utils/u_ui_motion.gd")
const CFG_MOTION_BUTTON_DEFAULT := preload("res://resources/core/ui/motions/cfg_motion_button_default.tres")
```

In `build()` (line 204), modify to call motion binding:
```gdscript
func build() -> Control:
	apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
	localize_labels()
	if not _focusable_controls.is_empty():
		U_FOCUS_CONFIGURATOR.configure_vertical_focus(_focusable_controls, true)
		_bind_motion_to_focusable()
	return _tab
```

Add the new method before `localize_labels`:
```gdscript
func _bind_motion_to_focusable() -> void:
	for control: Control in _focusable_controls:
		U_UI_MOTION.bind_interactive(control, CFG_MOTION_BUTTON_DEFAULT)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/ui/helpers/u_settings_tab_builder.gd
git commit -m "feat: bind interactive motion to settings tab focusable controls (GREEN)"
```

---

### Task 7: Fix hardcoded color in slider value label

**Files:**
- Modify: `scripts/core/ui/helpers/u_settings_tab_builder.gd`

- [ ] **Step 1: Replace hardcoded color with theme token**

In `u_settings_tab_builder.gd`, replace `_create_slider_value_label` (line 151):
```gdscript
func _create_slider_value_label(key: StringName, custom_name: String = "") -> Label:
	var label := Label.new()
	var base_name := custom_name if custom_name != "" else key.capitalize().replace(" ", "")
	label.name = base_name + "Value"
	label.custom_minimum_size = Vector2(50, 0)
	return label
```

The value_label color will come from the theme role token (`text_secondary`) applied via `_apply_theme_entry` → `U_UI_THEME_ROLE_UTILS.apply_settings_role` which already handles `&"value_label"` with `text_secondary`.

- [ ] **Step 2: Commit**

```bash
git add scripts/core/ui/helpers/u_settings_tab_builder.gd
git commit -m "fix: remove hardcoded slider color, use theme token via value_label role (GREEN)"
```

---

### Task 8: Wire accessibility palette subscription for reactive rebuilding

**Files:**
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Add accessibility state subscription and palette-aware rebuild**

Add a member variable after `var _close_button: Button = null`:
```gdscript
var _current_palette: Resource = null
```

Add `_subscribe_accessibility` call in `_ready()`, after `switch_to_tab`:
```gdscript
func _ready() -> void:
	super._ready()
	_apply_base_theme()
	_create_close_button()
	_build_tab_bar()
	_create_tab_contents()
	_update_tab_visibility()
	switch_to_tab(TabId.DISPLAY)
	_bind_tab_bar_motion()
	_subscribe_accessibility()
```

Modify `_on_slice_updated` (line 283) to rebuild theme when accessibility changes:
```gdscript
func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	_update_tab_visibility()
	if slice_name == StringName("accessibility"):
		_rebuild_theme_from_state()
```

Add `_subscribe_accessibility` and `_rebuild_theme_from_state`:
```gdscript
func _subscribe_accessibility() -> void:
	var store := get_store()
	if store == null:
		return

func _rebuild_theme_from_state() -> void:
	var store := get_store()
	if store == null:
		return
	var state: Dictionary = store.get_state()
	var accessibility: Dictionary = state.get("accessibility", {})
	var color_blind_mode: String = accessibility.get("color_blind_mode", "normal")
	var high_contrast: bool = accessibility.get("high_contrast", false)
	var palette := U_UI_PALETTE_RESOLVER.resolve_palette(color_blind_mode, high_contrast)
	_current_palette = palette
	_rebuild_theme(palette)

func _rebuild_theme(palette: Resource) -> void:
	var config: Resource = U_UI_THEME_BUILDER.active_config
	if not (config is RS_UI_THEME_CONFIG):
		return
	var typed_config := config as RS_UI_THEME_CONFIG
	typed_config.ensure_runtime_defaults()
	self.theme = U_UI_THEME_BUILDER.build_theme(typed_config, null, palette)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd
git commit -m "feat: add accessibility palette subscription + reactive theme rebuild (GREEN)"
```

---

### Task 9: Run style enforcement and fix any violations

**Files:**
- None expected to change — verification only

- [ ] **Step 1: Run style enforcement suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: All style tests pass. The settings panel has no inline `theme_override_*` in its `.tscn`.

Verify no new `theme_override_*` entries in UI scenes were introduced:
Run: `git diff main...HEAD -- scenes/core/ui/ | grep 'theme_override' || echo "No new theme overrides found"`
Expected: "No new theme overrides found"

- [ ] **Step 2: Run full test suite**

Run: `tools/run_gut_suite.sh`
Expected: No new failures vs baseline. Known: `ui_virtual_joystick.gd` parse error on 4.6.1.

- [ ] **Step 3: Commit if any style fixes were made**

```bash
# Only if needed
git add -A
git commit -m "style: post-activation style enforcement fixes"
```

---

### Task 10: Visual verification and responsiveness

**Files:**
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd` (responsive sizing)

- [ ] **Step 1: Apply responsive panel sizing**

In `ui_settings_panel.gd`, add after `_ready()` a method called to set responsive sizing:

```gdscript
func _apply_responsive_sizing() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var panel: Control = $CenterContainer/Panel
	if panel == null:
		return
	var max_width: float = minf(viewport_size.x * 0.9, 860.0)
	var max_height: float = minf(viewport_size.y * 0.85, 620.0)
	panel.custom_minimum_size = Vector2(320.0, 200.0)
	panel.size = Vector2(max_width, max_height)
```

Call `_apply_responsive_sizing()` at the end of `_ready()` and connect to viewport size changed:

```gdscript
func _ready() -> void:
	...
	_subscribe_accessibility()
	_apply_responsive_sizing()
	get_viewport().size_changed.connect(_apply_responsive_sizing)
```

- [ ] **Step 2: Verify tab bar wraps on narrow screens**

The `HBoxContainer` tab bar should wrap when overflow occurs. In the `.tscn`, ensure the TabBar HBoxContainer doesn't have `clip_contents` set. No `.tscn` changes needed — `Container` children won't clip by default, and wrapping is handled naturally since it's not constrained.

- [ ] **Step 3: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd
git commit -m "feat: add responsive panel sizing to settings panel (GREEN)"
```

---

### Task 11: Final integration test and cleanup

**Files:**
- None new

- [ ] **Step 1: Run full test suite one final time**

Run: `tools/run_gut_suite.sh`
Expected: All tests pass, no regressions.

- [ ] **Step 2: Run style enforcement**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add -A
git diff --cached --stat
git commit -m "test: final integration verification — all suites pass post theme activation"
```
