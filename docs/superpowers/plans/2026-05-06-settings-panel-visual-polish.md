# Settings Panel Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the settings panel match the approved improved mockup: a padded modal shell, compact header, correct LB/RB prompts, opaque readable panel surface, consistent two-column Display form, natural-size toggles, and a comfortable action row.

**Architecture:** Keep `UI_SettingsPanel` as the single overlay owner and keep tab contents as plain `Control`/`VBoxContainer` panels. Do not hand-edit or create `.tscn` files; all layout refinement is applied in scripts through `RS_UIThemeConfig` tokens, `U_SettingsTabBuilder`, and `U_UIThemeRoleUtils`. Focus remains owned by `U_FocusConfigurator`.

**Tech Stack:** Godot 4.7-style GDScript, GUT tests, existing `RS_UIThemeConfig`, existing button prompt assets under `assets/core/button_prompts/gamepad/`, existing tab builder/theme-role helpers.

---

## File Map

- Modify `scripts/core/ui/settings/ui_settings_panel.gd`
  - Owns modal shell spacing, background/scrim behavior, compact header/prompt layout, close button placement, and theme token application for the overall settings wrapper.
- Modify `scripts/core/ui/helpers/u_settings_tab_builder.gd`
  - Builds setting rows with predictable label/control sizing and natural-size toggles.
- Modify `scripts/core/ui/helpers/u_ui_theme_role_utils.gd`
  - Applies reusable settings role styling for rows, controls, panel shell, and action rows.
- Modify `scripts/core/ui/settings/ui_display_settings_tab.gd`
  - Keeps Display-specific focus chain and applies row/action sizing after builder creation if needed.
- Modify `scripts/core/ui/settings/ui_keyboard_mouse_settings_tab.gd`
  - Keep focus wrapping compatible with any builder row changes.
- Modify tests:
  - `tests/unit/ui/settings/test_settings_panel_tabs.gd`
  - `tests/unit/ui/helpers/test_u_settings_tab_builder.gd`
  - `tests/unit/ui/settings/test_ui_display_settings_tab_builder.gd`
  - `tests/unit/ui/test_display_settings_focus_wrapping.gd`
  - `tests/unit/ui/settings/test_ui_keyboard_mouse_settings_tab.gd`
- Do not modify `scenes/core/ui/settings/ui_settings_panel.tscn`.
- Do not add image assets.

---

### Task 1: Lock Modal Shell Spacing And Header Structure

**Files:**
- Modify: `tests/unit/ui/settings/test_settings_panel_tabs.gd`
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Write failing tests for outer modal margin, panel padding, close button placement, and compact prompt row**

Add these tests to `tests/unit/ui/settings/test_settings_panel_tabs.gd` after `test_panel_spacing_tokens_apply_to_outer_panel_not_inner_vbox`:

```gdscript
func test_panel_shell_has_viewport_margin_and_close_inside_panel_chrome():
	var config := RS_UIThemeConfig.new()
	config.margin_outer = 32
	config.margin_section = 24
	config.margin_inner = 12
	config.ensure_runtime_defaults()
	U_UIThemeBuilder.active_config = config

	var panel := await _create_panel()
	panel._apply_layout_tokens()
	var center := panel.get_node("CenterContainer") as CenterContainer
	var close_button := panel.find_child("CloseButton", true, false) as Button

	assert_eq(center.offset_left, 32.0, "Settings modal should have left viewport margin")
	assert_eq(center.offset_top, 32.0, "Settings modal should have top viewport margin")
	assert_eq(center.offset_right, -32.0, "Settings modal should have right viewport margin")
	assert_eq(center.offset_bottom, -32.0, "Settings modal should have bottom viewport margin")
	assert_true(close_button.get_parent().name == "PanelChrome", "Close button should live inside panel chrome")
	assert_eq(close_button.offset_right, -12.0, "Close button should use inner panel padding")
	panel.queue_free()
	U_UIThemeBuilder.active_config = null

func test_shoulder_prompts_are_inline_with_tab_bar():
	var panel := await _create_panel()
	var header := panel.find_child("PanelChrome", true, false) as Control
	var tab_bar := panel.find_child("TabBar", true, false) as HBoxContainer
	var prompt_row := panel.find_child("ShoulderPromptRow", true, false) as HBoxContainer

	assert_not_null(header, "Settings panel should create a header chrome row")
	assert_eq(tab_bar.get_parent(), header, "Tab bar should be inside header chrome")
	assert_eq(prompt_row.get_parent(), header, "Shoulder prompts should be inline in header chrome")
	assert_true(prompt_row.size_flags_horizontal == Control.SIZE_SHRINK_END, "Prompt row should stay compact at the right side")
	panel.queue_free()
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tabs.gd
```

Expected: the two new tests fail because `CenterContainer` has no outer offsets, `CloseButton` is a root child, and `ShoulderPromptRow` is still a separate row under `VBox`.

- [ ] **Step 3: Implement runtime header chrome without editing `.tscn`**

In `scripts/core/ui/settings/ui_settings_panel.gd`, add members:

```gdscript
var _panel_chrome: HBoxContainer = null
var _tab_header_spacer: Control = null
```

Add a helper and call it in `_ready()` after `_create_close_button()` and before `_build_tab_bar()`:

```gdscript
func _create_panel_chrome() -> void:
	var vbox := get_node_or_null("CenterContainer/Panel/VBox") as VBoxContainer
	if vbox == null:
		return
	_panel_chrome = HBoxContainer.new()
	_panel_chrome.name = "PanelChrome"
	_panel_chrome.alignment = BoxContainer.ALIGNMENT_BEGIN
	_panel_chrome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_chrome)
	vbox.move_child(_panel_chrome, 0)

	_tab_header_spacer = Control.new()
	_tab_header_spacer.name = "TabHeaderSpacer"
	_tab_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

Change `_build_tab_bar()` so it reparents `TabBar` into `_panel_chrome` before adding tab buttons:

```gdscript
func _build_tab_bar() -> void:
	if _tab_bar == null:
		return
	if _panel_chrome != null and _tab_bar.get_parent() != _panel_chrome:
		_tab_bar.reparent(_panel_chrome)
		_panel_chrome.move_child(_tab_bar, 0)
		if _tab_header_spacer.get_parent() == null:
			_panel_chrome.add_child(_tab_header_spacer)
	_tab_buttons.clear()
	_tab_button_group.allow_unpress = false
	for tab_id: TabId in _TAB_ORDER:
		var label_info: Dictionary = _TAB_LABELS[tab_id]
		var button := Button.new()
		var localized_text: String = U_LOCALIZATION_UTILS.localize_with_fallback(label_info.key, label_info.fallback)
		button.text = localized_text
		button.name = "TabButton_%d" % tab_id
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.button_group = _tab_button_group
		button.pressed.connect(_on_tab_button_pressed.bind(tab_id))
		button.focus_entered.connect(_on_tab_button_focused.bind(tab_id))
		_tab_bar.add_child(button)
		_tab_buttons[tab_id] = {
			"button": button,
			"key": label_info.key,
			"fallback": label_info.fallback,
		}
```

Change `_create_shoulder_prompts()` so the row is parented to `_panel_chrome`:

```gdscript
func _create_shoulder_prompts() -> void:
	if _panel_chrome == null:
		return
	var prompt_row := HBoxContainer.new()
	prompt_row.name = "ShoulderPromptRow"
	prompt_row.alignment = BoxContainer.ALIGNMENT_END
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_panel_chrome.add_child(prompt_row)

	var lb_icon := _create_prompt_icon("ShoulderPromptLBIcon", TEX_BUTTON_LB)
	var label := Label.new()
	label.name = "ShoulderPromptLabel"
	label.text = "Tabs"
	var rb_icon := _create_prompt_icon("ShoulderPromptRBIcon", TEX_BUTTON_RB)
	prompt_row.add_child(lb_icon)
	prompt_row.add_child(label)
	prompt_row.add_child(rb_icon)
```

Change `_create_close_button()` so it creates the button but does not leave it as a root child:

```gdscript
func _attach_close_button_to_chrome() -> void:
	if _panel_chrome == null or _close_button == null:
		return
	if _close_button.get_parent() != _panel_chrome:
		_close_button.reparent(_panel_chrome)
	_panel_chrome.add_child(_close_button)
	_close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
```

Call `_attach_close_button_to_chrome()` after `_create_panel_chrome()` in `_ready()`.

Update `_apply_layout_tokens()`:

```gdscript
	var center := get_node_or_null("CenterContainer") as CenterContainer
	if center != null:
		var outer := float(typed_config.margin_outer)
		center.offset_left = outer
		center.offset_top = outer
		center.offset_right = -outer
		center.offset_bottom = -outer
	if _panel_chrome != null:
		_panel_chrome.add_theme_constant_override("separation", typed_config.separation_default)
	if _close_button != null:
		var margin := float(typed_config.margin_inner)
		_close_button.offset_top = margin
		_close_button.offset_left = -44.0 - margin
		_close_button.offset_right = -margin
		_close_button.offset_bottom = margin + 44.0
```

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tabs.gd
```

Expected: all tests in `test_settings_panel_tabs.gd` pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd tests/unit/ui/settings/test_settings_panel_tabs.gd
git commit -m "Polish settings panel shell layout"
```

---

### Task 2: Fix LB/RB Prompt Rendering And Header Density

**Files:**
- Modify: `tests/unit/ui/settings/test_settings_panel_tabs.gd`
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Write failing test for prompt texture dimensions and compact spacing**

Add:

```gdscript
func test_shoulder_prompt_icons_are_wide_lb_rb_glyphs():
	var panel := await _create_panel()
	var lb_icon := panel.find_child("ShoulderPromptLBIcon", true, false) as TextureRect
	var rb_icon := panel.find_child("ShoulderPromptRBIcon", true, false) as TextureRect
	var prompt_row := panel.find_child("ShoulderPromptRow", true, false) as HBoxContainer

	assert_true(lb_icon.custom_minimum_size.x > lb_icon.custom_minimum_size.y, "LB icon should preserve shoulder-button aspect")
	assert_true(rb_icon.custom_minimum_size.x > rb_icon.custom_minimum_size.y, "RB icon should preserve shoulder-button aspect")
	assert_eq(prompt_row.get_theme_constant("separation"), 8, "Shoulder prompt spacing should be compact")
	assert_eq(lb_icon.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "LB icon should not be distorted")
	assert_eq(rb_icon.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "RB icon should not be distorted")
	panel.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tabs.gd
```

Expected: failure because prompt icons are square `28x28` and the prompt row has no explicit compact spacing.

- [ ] **Step 3: Implement prompt sizing**

Change `_create_prompt_icon(...)` in `ui_settings_panel.gd`:

```gdscript
func _create_prompt_icon(node_name: String, texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = texture
	icon.custom_minimum_size = Vector2(44, 26)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
```

In `_apply_layout_tokens()` add:

```gdscript
	var prompt_row := find_child("ShoulderPromptRow", true, false) as HBoxContainer
	if prompt_row != null:
		prompt_row.add_theme_constant_override("separation", typed_config.separation_compact)
	var prompt_label := find_child("ShoulderPromptLabel", true, false) as Label
	if prompt_label != null:
		prompt_label.add_theme_font_size_override("font_size", typed_config.body_small)
		prompt_label.add_theme_color_override("font_color", typed_config.text_secondary)
```

- [ ] **Step 4: Run test to verify pass**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tabs.gd
```

Expected: prompt tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd tests/unit/ui/settings/test_settings_panel_tabs.gd
git commit -m "Fix settings shoulder prompt layout"
```

---

### Task 3: Make Panel Surface Opaque Enough For Readability

**Files:**
- Modify: `tests/unit/ui/settings/test_settings_panel_tabs.gd`
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Write failing test for panel opacity**

Add:

```gdscript
func test_standalone_menu_background_is_subtle_inside_panel():
	var config := RS_UIThemeConfig.new()
	config.panel_section_opacity = 0.78
	config.ensure_runtime_defaults()
	U_UIThemeBuilder.active_config = config

	var panel := await _create_panel()
	panel._apply_layout_tokens()
	var shell := panel.get_node("CenterContainer/Panel") as PanelContainer
	var stylebox := shell.get_theme_stylebox("panel") as StyleBoxFlat

	assert_true(stylebox.bg_color.a >= 0.92, "Settings panel surface should be opaque enough for readable forms")
	panel.queue_free()
	U_UIThemeBuilder.active_config = null
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tabs.gd
```

Expected: failure because the panel style currently duplicates `panel_section`, which can be too transparent.

- [ ] **Step 3: Increase settings panel surface opacity locally**

In `_apply_layout_tokens()`, after duplicating `panel_style`, add:

```gdscript
		var panel_bg := panel_style.bg_color
		panel_bg.a = maxf(panel_bg.a, 0.94)
		panel_style.bg_color = panel_bg
```

Keep this local to `UI_SettingsPanel`; do not change global theme resources.

- [ ] **Step 4: Run test to verify pass**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tabs.gd
```

Expected: all settings panel shell tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd tests/unit/ui/settings/test_settings_panel_tabs.gd
git commit -m "Improve settings panel surface readability"
```

---

### Task 4: Create Builder Support For Natural-Size Toggles And Stable Form Widths

**Files:**
- Modify: `tests/unit/ui/helpers/test_u_settings_tab_builder.gd`
- Modify: `scripts/core/ui/helpers/u_settings_tab_builder.gd`
- Modify: `scripts/core/ui/helpers/u_ui_theme_role_utils.gd`

- [ ] **Step 1: Write failing builder tests**

Add tests to `tests/unit/ui/helpers/test_u_settings_tab_builder.gd`:

```gdscript
func test_toggle_controls_do_not_expand_to_full_row_width():
	var tab := VBoxContainer.new()
	var builder := U_SettingsTabBuilder.new(tab)
	builder.add_toggle(&"settings.test.toggle", Callable(), &"", "Toggle", "TestToggle")
	builder.build()

	var toggle := tab.find_child("TestToggle", true, false) as CheckBox
	assert_not_null(toggle, "Builder should create toggle")
	assert_eq(toggle.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "Toggles should keep natural width")
	tab.free()

func test_dropdown_controls_use_consistent_field_width():
	var tab := VBoxContainer.new()
	var builder := U_SettingsTabBuilder.new(tab)
	builder.add_dropdown(&"settings.test.dropdown", [{"id": "one", "label": "One"}], Callable(), &"", "Dropdown", "TestOption")
	builder.build()

	var dropdown := tab.find_child("TestOption", true, false) as OptionButton
	assert_not_null(dropdown, "Builder should create dropdown")
	assert_eq(dropdown.custom_minimum_size.x, 360.0, "Dropdowns should have stable field width")
	tab.free()
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/helpers/test_u_settings_tab_builder.gd
```

Expected: toggle test fails because toggles use `SIZE_EXPAND_FILL`; dropdown width test fails because no custom minimum width is set.

- [ ] **Step 3: Add builder sizing constants and apply them**

In `u_settings_tab_builder.gd`, add constants near the top:

```gdscript
const FIELD_LABEL_WIDTH := 220.0
const FIELD_CONTROL_WIDTH := 360.0
const SLIDER_VALUE_WIDTH := 72.0
```

In `add_dropdown(...)`, replace label and dropdown sizing with:

```gdscript
	label.custom_minimum_size = Vector2(0, 0) if (is_inline and _inline_group_item_count > 0) else Vector2(FIELD_LABEL_WIDTH, 0)
	var dropdown := OptionButton.new()
	dropdown.name = custom_name if custom_name != "" else key.capitalize().replace(" ", "") + "Option"
	dropdown.custom_minimum_size = Vector2(FIELD_CONTROL_WIDTH, 0)
	dropdown.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
```

In `add_toggle(...)`, replace sizing with:

```gdscript
	label.custom_minimum_size = Vector2(0, 0) if (is_inline and _inline_group_item_count > 0) else Vector2(FIELD_LABEL_WIDTH, 0)
	var toggle := CheckBox.new()
	toggle.name = custom_name if custom_name != "" else key.capitalize().replace(" ", "") + "Toggle"
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
```

In `add_slider(...)`, replace label, slider, and value label sizing with:

```gdscript
	label.custom_minimum_size = Vector2(0, 0) if (is_inline and _inline_group_item_count > 0) else Vector2(FIELD_LABEL_WIDTH, 0)
	var slider := HSlider.new()
	slider.name = custom_name if custom_name != "" else key.capitalize().replace(" ", "") + "Slider"
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.custom_minimum_size = Vector2(FIELD_CONTROL_WIDTH, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

In `_create_slider_value_label(...)`, add:

```gdscript
	label.custom_minimum_size = Vector2(SLIDER_VALUE_WIDTH, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
```

In `u_ui_theme_role_utils.gd`, keep `field_control` font sizing only; do not force expand flags there.

- [ ] **Step 4: Run builder tests to verify pass**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/helpers/test_u_settings_tab_builder.gd
```

Expected: all builder helper tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/helpers/u_settings_tab_builder.gd scripts/core/ui/helpers/u_ui_theme_role_utils.gd tests/unit/ui/helpers/test_u_settings_tab_builder.gd
git commit -m "Refine settings builder form control sizing"
```

---

### Task 5: Rebuild Display Tab Into A Cleaner Two-Column Rhythm

**Files:**
- Modify: `tests/unit/ui/settings/test_ui_display_settings_tab_builder.gd`
- Modify: `scripts/core/ui/settings/ui_display_settings_tab.gd`
- Modify: `scripts/core/ui/helpers/u_settings_tab_builder.gd` if Task 4 row APIs need a small extension

- [ ] **Step 1: Write failing Display layout tests**

Add to `tests/unit/ui/settings/test_ui_display_settings_tab_builder.gd`:

```gdscript
func test_display_tab_uses_compact_natural_toggles():
	var tab := UI_DisplaySettingsTab.new()
	add_child_autofree(tab)
	await get_tree().process_frame

	var vsync := tab.find_child("VSyncToggle", true, false) as CheckBox
	var post_processing := tab.find_child("PostProcessingToggle", true, false) as CheckBox
	var high_contrast := tab.find_child("HighContrastToggle", true, false) as CheckBox

	assert_eq(vsync.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "VSync toggle should not stretch as a full-width bar")
	assert_eq(post_processing.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "Post-processing toggle should not stretch as a full-width bar")
	assert_eq(high_contrast.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "High contrast toggle should not stretch as a full-width bar")

func test_display_tab_field_controls_have_consistent_widths():
	var tab := UI_DisplaySettingsTab.new()
	add_child_autofree(tab)
	await get_tree().process_frame

	var window_size := tab.find_child("WindowSizeOption", true, false) as OptionButton
	var window_mode := tab.find_child("WindowModeOption", true, false) as OptionButton
	var quality := tab.find_child("QualityPresetOption", true, false) as OptionButton
	var color_blind := tab.find_child("ColorBlindModeOption", true, false) as OptionButton

	assert_eq(window_size.custom_minimum_size.x, window_mode.custom_minimum_size.x, "Display dropdown widths should match")
	assert_eq(quality.custom_minimum_size.x, color_blind.custom_minimum_size.x, "Display dropdown widths should match")
	assert_true(window_size.custom_minimum_size.x >= 320.0, "Display dropdowns should be readable but not full-width")
```

- [ ] **Step 2: Run tests to verify fail**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_display_settings_tab_builder.gd
```

Expected: tests fail before Task 4 or until Display controls inherit the new builder sizing.

- [ ] **Step 3: Ensure Display builder uses the common sizing**

In `ui_display_settings_tab.gd`, keep `_setup_builder()` using `U_UI_SETTINGS_CATALOG.create_display_builder(...)`. Do not hand-create Display rows.

If `U_UI_SETTINGS_CATALOG.create_display_builder(...)` bypasses `U_SettingsTabBuilder` sizing for any Display controls, update the catalog/builder factory so all Display dropdowns, toggles, and sliders are created through:

```gdscript
builder.add_dropdown(...)
builder.add_toggle(...)
builder.add_slider(...)
builder.add_button_row(...)
```

If the catalog already uses those methods, no production edit is needed beyond Task 4.

- [ ] **Step 4: Run Display builder tests**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_display_settings_tab_builder.gd
```

Expected: Display builder tests pass.

- [ ] **Step 5: Run Display focus tests**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_display_settings_focus_wrapping.gd
```

Expected: focus wrapping still passes after layout changes.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/ui/settings/ui_display_settings_tab.gd scripts/core/ui/helpers/u_settings_tab_builder.gd tests/unit/ui/settings/test_ui_display_settings_tab_builder.gd tests/unit/ui/test_display_settings_focus_wrapping.gd
git commit -m "Align display settings form controls"
```

---

### Task 6: Clean Bottom Action Row Spacing And Alignment

**Files:**
- Modify: `tests/unit/ui/helpers/test_u_settings_tab_builder.gd`
- Modify: `scripts/core/ui/helpers/u_settings_tab_builder.gd`
- Modify: `scripts/core/ui/helpers/u_ui_theme_role_utils.gd`

- [ ] **Step 1: Write failing action row test**

Add to `test_u_settings_tab_builder.gd`:

```gdscript
func test_action_buttons_row_has_comfortable_spacing_and_padding_role():
	var tab := VBoxContainer.new()
	var builder := U_SettingsTabBuilder.new(tab)
	builder.add_button_row(Callable(), Callable(), Callable(), &"common.apply", &"common.cancel", &"common.reset", "Apply", "Cancel", "Reset")
	builder.build()

	var row := tab.find_child("ActionButtons", true, false) as HBoxContainer
	assert_not_null(row, "Builder should create action row")
	assert_eq(row.get_theme_constant("separation"), 12, "Action row should use default button spacing")
	assert_eq(row.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "Action row should keep compact button group width")
	tab.free()
```

- [ ] **Step 2: Run test to verify fail**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/helpers/test_u_settings_tab_builder.gd
```

Expected: action row uses compact spacing and may not have shrink sizing.

- [ ] **Step 3: Add explicit action row role**

In `u_settings_tab_builder.gd`, change `add_button_row(...)`:

```gdscript
	var row := HBoxContainer.new()
	row.name = "ActionButtons"
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_current_parent.add_child(row)
	_theme_map.append({"control": row, "role": &"action_row"})
```

In `u_ui_theme_role_utils.gd`, add to `apply_settings_role(...)`:

```gdscript
		&"action_row":
			control.add_theme_constant_override(&"separation", config.separation_default)
```

- [ ] **Step 4: Run builder tests**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/helpers/test_u_settings_tab_builder.gd
```

Expected: builder tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/helpers/u_settings_tab_builder.gd scripts/core/ui/helpers/u_ui_theme_role_utils.gd tests/unit/ui/helpers/test_u_settings_tab_builder.gd
git commit -m "Polish settings action row spacing"
```

---

### Task 7: Visual Regression Smoke With Existing Runtime

**Files:**
- Modify: no production files unless a test exposes a concrete issue.
- Test: settings/UI and style suites.

- [ ] **Step 1: Run focused settings suite**

Run:

```bash
tools/run_gut_suite.sh -gdir=res://tests/unit/ui/settings
```

Expected: all tests pass.

- [ ] **Step 2: Run builder helper tests**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/helpers/test_u_settings_tab_builder.gd
```

Expected: all tests pass.

- [ ] **Step 3: Run Display focus test**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_display_settings_focus_wrapping.gd
```

Expected: all tests pass.

- [ ] **Step 4: Run required style guard**

Run:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: 0 failures. This is required because UI script structure changed.

- [ ] **Step 5: Optional manual screenshot check**

Run the scene or game path normally used for UI smoke. Verify the Settings screen visually against the approved mockup:

- panel has viewport margin on all sides;
- close button sits inside panel chrome;
- tabs and LB/RB prompt are one compact header row;
- panel surface is opaque enough that the background image does not fight text;
- checkboxes are natural-size controls;
- dropdown widths are consistent;
- slider value does not collide;
- action buttons have bottom breathing room.

- [ ] **Step 6: Commit any final fixes**

If Step 5 reveals a concrete issue, write a focused failing test first, fix it, rerun relevant tests, then commit:

```bash
git add scripts/core/ui tests/unit/ui
git commit -m "Tighten settings panel visual polish"
```

---

## Self-Review

- Spec coverage: The plan covers the approved visual direction: modal margins, panel padding, close placement, LB/RB prompt correctness, opaque panel surface, two-column form rhythm, natural-size toggles, slider/value spacing, and action row padding.
- Completion-marker scan: No vague “add tests” steps remain. Each implementation task includes concrete paths, code snippets, commands, and expected results.
- Type consistency: All named methods and constants align with current files: `UI_SettingsPanel._apply_layout_tokens`, `U_SettingsTabBuilder.add_dropdown/add_toggle/add_slider/add_button_row`, and `U_UIThemeRoleUtils.apply_settings_role`.
- Project constraints: No worktree required, no hand-authored `.tscn` changes, no new assets, focus remains with `U_FocusConfigurator`.
