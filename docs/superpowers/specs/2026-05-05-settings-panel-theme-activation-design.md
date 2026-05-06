# Settings Panel Theme Activation Design

## Summary

The theme system (`RS_UIThemeConfig`, `U_UIThemeBuilder`, `RS_UIMotionSet`, `RS_UIColorPalette`) is fully defined but the settings panel (`UI_SettingsPanel` + tab content) only uses font sizes and spacing constants. Button StyleBoxes, panel borders, slider theming, focus rings, motion animations, and accessibility palette switching are all defined but never applied. This spec activates the full theme pipeline for the settings panel.

**Approach**: Hybrid — Base Theme + Semantic Exceptions (Approach C). Apply the full `Theme` resource to the root control for type-level cascading defaults, keep semantic role overrides only for contextual exceptions.

## Section 1: Base Theme Application

### Problem
`UI_SettingsPanel` never calls `U_UIThemeBuilder.build_theme()`. Only per-control semantic overrides are applied via `add_theme_*_override()`. All StyleBox definitions, focus styles, separator styles, and bar styles in `RS_UIThemeConfig` are unused by the settings panel.

### Solution — Two-layer architecture

#### Layer 1: Base Theme (applied once on root Control)
```gdscript
UI_SettingsPanel.theme = U_UIThemeBuilder.build_theme(config, null, palette)
```
This cascades to all children with type-level defaults:
- `Button` → `button_normal/hover/pressed/focus/disabled` StyleBoxes
- `PanelContainer` → `panel_section` rounded+bordered StyleBox
- `HSlider`/`VSlider` → themed `slider_bg/slider_fill/slider_grabber`
- `ProgressBar` → `progress_bar_bg/progress_bar_fill`
- `Control` → `focus_stylebox` focus ring
- `HSeparator`/`VSeparator` → `separator_style`
- Default font sizes and spacing constants

The existing `cfg_motion_fade_slide.tres` is assigned via `motion_set` on the root to enable enter/exit panel animations handled by `BasePanel`.

#### Layer 2: Semantic Exceptions (per-control overrides where needed)
Existing `add_theme_*_override()` calls remain for context-specific exceptions:
- `heading` → larger font than label default
- `field_label` → `body_small` font + `text_secondary` color
- `danger` → red color override on specific buttons
- `overlay_dim` → adjusted alpha on background ColorRect
- Tab buttons → `TabActive`/`TabInactive` type variations
- `main_panel` / `panel_padding` → panel section style + margins

### Theme rebuild lifecycle
```
_ready()
  → read active_config from U_UIThemeBuilder
  → resolve initial palette (default = normal, no high contrast)
  → build_theme(config, null, palette)
  → self.theme = built_theme
  → apply_semantic_overrides()
  → subscribe to accessibility_settings state slice
```

## Section 2: Tab Styling & Type Variations

### Problem
Tab buttons reference `theme_type_variation = "TabActive"` / `"TabInactive"` but these have no backing definitions in any built theme.

### Solution
After building the base Theme, register type variations and apply per-variation overrides on the Theme resource itself:

| Variation | Override | Value |
|-----------|----------|-------|
| `TabActive` | `font_color` | `config.text_primary` |
| `TabActive` | `normal StyleBox` | Subtle accent-tinted background (`bg_panel_light`), 2px bottom border in `accent_primary` |
| `TabActive` | `focus StyleBox` | Same as normal but with `accent_focus` bottom border |
| `TabInactive` | `font_color` | `config.text_secondary` |
| `TabInactive` | `normal StyleBox` | Transparent background, no border |
| `TabInactive` | `hover StyleBox` | `bg_panel_light` background at low alpha |
| `TabInactive` | `focus StyleBox` | `focus_stylebox` outline |

```gdscript
theme.set_type_variation(&"TabActive", &"Button")
theme.set_type_variation(&"TabInactive", &"Button")
theme.set_stylebox(&"normal", &"TabActive", active_normal_style)
theme.set_color(&"font_color", &"TabActive", config.text_primary)
# ... etc for each override
```

The tab bar gets a thin `HSeparator` at the bottom (using `separator_style`). The active tab's bottom border visually breaks through this separator.

Tab visibility/device-context logic (`_set_tab_visible`, `_update_tab_visibility`) and focus snap on hidden-tab-switch remain unchanged — they already work correctly.

## Section 3: Motion & Animations

### Panel enter/exit
- `motion_set = preload("res://resources/core/ui/motions/cfg_motion_fade_slide.tres")` on settings panel root
- Enter: fade in (0.28s, `modulate:a` 0→1) + slide up (`position:y` +18→0, 0.32s, parallel)
- Exit: fade out (0.22s, `modulate:a` 1→0) + slide up (`position:y` 0→-14, 0.22s, parallel)
- `BasePanel.play_enter_animation()` / `play_exit_animation()` already handles this when `motion_set != null`

### Overlay background dim
`OverlayBackground` ColorRect fades in/out in sync with panel enter/exit using the same tween, rather than appearing instantly.

### Button interactions
Wire `cfg_motion_button_default.tres` to all focusable controls in the settings panel:
- Tab buttons
- Action buttons (Cancel, Reset, Apply)
- CheckBox/CheckButton nodes
- OptionButton nodes

```gdscript
U_UIMotion.bind_interactive(button, cfg_motion_button_default)
```

Effects:
- Hover: scale 1.0→1.03 (0.1s, `TRANS_CUBIC/EASE_OUT`)
- Focus: scale 1.0→1.02 (0.1s)
- Press: compress to 0.97 then rebound to 1.0 (0.12s total)

`U_UIMotion.bind_interactive()` walks the control tree automatically — call it once per tab content on build, plus once on the tab bar container.

### Tab content transitions
When switching tabs, crossfade old content out (0.15s modulate out) and new content in (0.15s modulate in, 0.05s staggered delay).

### Slider enhancements
- Grabber gets hover/focus highlight via themed `slider_grabber_highlight` StyleBox
- Value label updates in real-time during drag (already functional)
- Touchscreen slider preview widgets (VirtualJoystick, VirtualButton instances) are excluded from motion binding — they handle their own rendering

### Mobile touch
- Button press motion fires on touch-up (natural Godot behavior)
- No hover states on mobile — skipped naturally since touch devices don't fire hover signals
- Touchscreen tab sliders include live preview with instant-apply pattern

## Section 4: Accessibility Palette Wiring

### Problem
`RS_UIColorPalette` has palette_id, primary, secondary, success, warning, danger, info, background, and text — but `U_UIThemeBuilder.build_theme()` only uses `palette.text`. The existing palette `.tres` files are orphaned.

### Palette resolution
New static utility `U_UIPaletteResolver`:

```gdscript
static func resolve_palette(color_blind_mode: String, high_contrast: bool) -> RS_UIColorPalette:
    if color_blind_mode == "normal" and not high_contrast:
        return cfg_palette_normal
    var key := color_blind_mode + ("_high_contrast" if high_contrast else "")
    return PALETTE_MAP.get(key, cfg_palette_normal)
```

`PALETTE_MAP` maps string keys to preloaded palette resources:

| Key | Resource |
|-----|----------|
| `"deuteranopia"` | `cfg_palette_deuteranopia.tres` |
| `"deuteranopia_high_contrast"` | `cfg_palette_deuteranopia_high_contrast.tres` |
| `"protanopia"` | `cfg_palette_protanopia.tres` |
| `"protanopia_high_contrast"` | `cfg_palette_protanopia_high_contrast.tres` |
| `"tritanopia"` | `cfg_palette_tritanopia.tres` |
| `"tritanopia_high_contrast"` | `cfg_palette_tritanopia_high_contrast.tres` |
| `"normal_high_contrast"` | `cfg_palette_normal_high_contrast.tres` |

### Full palette-to-theme wiring
Extend `U_UIThemeBuilder.build_theme()` to map palette colors into theme config overrides:

| Palette property | Theme config override |
|------------------|----------------------|
| `palette.primary` | `config.accent_primary`, `config.accent_focus`, `config.slider_fill_color` |
| `palette.secondary` | `config.accent_hover` |
| `palette.success` | `config.success` |
| `palette.warning` | `config.warning` |
| `palette.danger` | `config.danger` |
| `palette.info` | `config.section_header_color` |
| `palette.background` | `config.bg_base` |
| `palette.text` | `config.text_primary` (already wired) |

Additional derived overrides when palette is provided:
- `config.bg_panel` = `palette.background.lightened(0.05)`
- `config.bg_panel_light` = `palette.background.lightened(0.12)`
- `config.text_secondary` = `palette.text` at 0.75 alpha
- `config.text_disabled` = `palette.text` at 0.4 alpha

### Reactive rebuilding
1. `UI_SettingsPanel` subscribes to `accessibility_settings` state slice in `_ready()`
2. On `slice_updated` → read `color_blind_mode` + `high_contrast` → `U_UIPaletteResolver.resolve_palette()` → `_rebuild_theme(palette)`
3. `_rebuild_theme(palette)`:
   ```gdscript
   func _rebuild_theme(palette: RS_UIColorPalette) -> void:
       var config := U_UI_THEME_BUILDER.active_config
       if config is RS_UI_THEME_CONFIG:
           self.theme = U_UI_THEME_BUILDER.build_theme(config, null, palette)
           _apply_semantic_overrides()
   ```
4. Theme reassignment is synchronous — all children inherit new colors immediately

## Section 5: Polish & Edge Cases

### Responsive panel sizing
- Replace hardcoded 860x620 with `custom_minimum_size` + `size_flags_horizontal = SIZE_SHRINK_CENTER`
- Panel width: 90% of viewport (max 860px), height: 85% of viewport (max 620px)
- Tab bar wraps when labels overflow horizontal space
- Test targets: 360px (phone portrait), 768px (tablet), 1080p, 4K

### Touch targets
- All interactive elements meet 44px minimum touch height per WCAG
- Slider grabber StyleBox expanded to ensure adequate touch area
- Tab buttons sized to minimum 44px height

### Focus management
- Focus trap: when panel opens with gamepad/keyboard, focus stays within panel (inherited from `BaseOverlay`)
- After tab switch, focus snaps to first control after one process frame (already implemented)
- Focus ring visible on all interactive controls via `focus_stylebox` from base theme

### Back/Esc handling
- Esc key / mobile back → `U_NavigationActions.close_top_overlay()`
- Exit animation plays before panel removal (handled by `BaseOverlay`)
- Mobile back gesture routes through `M_UIInputHandler`

### Removals
- Replace `Color(0.25, 0.5, 0.75, 1.0)` literal in slider value label with `config.text_secondary` theme token
- No new `.tscn` files required — all changes are script-side

### State store subscriptions
- `_exit_tree()` unsubscribes from all state store connections
- Tab content sub-overlays (Input Profiles, Rebind Controls, Edit Layout) managed by navigation state — unchanged

### Non-goals (unchanged)
- Redux actions, reducers, and selectors (add one palette resolution dispatch only)
- Tab visibility filtering by device context
- Apply/Cancel vs instant-apply patterns per tab
- Builder scripts (`U_SettingsTabBuilder`, `U_UIMenuBuilder`, `U_UI_SettingsRowBuilder`) — extended, not replaced
- Scene organization and file layout

## Files to Modify

| File | Change |
|------|--------|
| `scripts/core/ui/settings/ui_settings_panel.gd` | Add `_build_theme()`, `_rebuild_theme()`, `motion_set` assignment, `bind_interactive()` calls, accessibility slice subscription |
| `scripts/core/ui/utils/u_ui_theme_builder.gd` | Add `_apply_type_variations()`, extend `_apply_text_colors` for full palette wiring |
| `scripts/core/ui/utils/u_ui_motion.gd` | No functional changes — used as-is via `motion_set` + `bind_interactive()` |
| `scripts/core/resources/ui/rs_ui_theme_config.gd` | No changes — only verify defaults are sufficient |
| Tab scripts (7 files under `scripts/core/ui/settings/ui_*_settings_tab.gd`) | Small changes: call `bind_interactive()` on build, remove inline color literal |
| `scripts/core/ui/helpers/u_settings_tab_builder.gd` | Remove hardcoded slider color, add motion binding hook |

## Files to Create

| File | Purpose |
|------|---------|
| `scripts/core/ui/utils/u_ui_palette_resolver.gd` | `U_UIPaletteResolver` static utility — maps accessibility state to palette .tres |

## Testing

### Unit tests
- `U_UIPaletteResolver` returns correct palette per color_blind_mode + high_contrast
- `U_UIThemeBuilder` applies full palette overrides when palette arg is provided
- `motion_set` assignment doesn't break settings panel instantiation

### Style enforcement
- No new `theme_override_*` lines introduced in UI scenes (already compliant)
- May need to add `ui_settings_panel.tscn` to `UI_POLISHED_OVERLAY_SCENES` list
- Hardcoded color literal removal verified

### Visual verification
- Panel renders with themed buttons, panels, sliders, focus rings
- Enter/exit animation plays smoothly
- Tab switching has crossfade transition
- Palette switch changes all colors globally
- Panel scales correctly at 360px, 768px, 1080p, 4K
