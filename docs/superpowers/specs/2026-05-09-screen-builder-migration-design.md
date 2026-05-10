# Screen Builder Migration — Design Spec

## Date: 2026-05-09
## Scope: Phase 9 (InputRebindingOverlay), Phase 10 (InputProfileSelector), Phase 11 (SaveLoadMenu), Phase 12 (BaseOverlay)

## Overview

Replace `@onready` chrome node declarations and inline node creation in remaining overlay screens with builder-driven or widget-driven construction. Target 20-40% line-count reduction.

## Current Status — 2026-05-09 Gap Patch

- Phase 9 is intentionally on the helper-utility path for focus navigation. The existing `U_RebindFocusNavigation` now owns focus sync, row highlight logic, and custom key navigation; `W_RebindFocusNavigator` is no longer the planned destination unless a future pass explicitly converts the helper into a stateful widget.
- Phase 10 now uses `U_UIMenuBuilder` for overlay chrome/theme binding and delegates profile binding preview rows to `W_ProfileBindingPreview`.
- Phase 11 remains functionally extracted. `W_SaveSlotRowFactory` was added to keep `W_SaveSlotGrid` under the widget line cap while preserving its ownership/focus role.
- The builder `bind_panel` argument order is standardized as `(panel, padding, content)` across `U_UIMenuBuilder` and `U_SettingsTabBuilder`.
- Fixed bugs from the audit: save-slot external container orphaning, freed thumbnail pending-key cleanup, `res://` image fallback in exported builds, malformed `set_tooltip` indentation, duplicated binding-label formatting, right-stick deadzone drift, and the no-op save/load event subscription stub.
- Added a style guard for the Phase 9/10 overlay line caps.

## Approach

**Aggressive (Option B)** — Extract reusable widgets for the large logic blocks, not just chrome nodes.

### What stays `@onready` (justified)

- `ConfirmationDialog`, `AcceptDialog`, `AcceptDialog` — native Godot popups with window-manager behavior; runtime creation is fragile and offers no benefit.
- Profile manager, save manager, state store references — these are business-logic dependencies, not UI chrome.

## Phase 9 — UI_InputRebindingOverlay

### Existing: 694 lines

| Block | Lines | Strategy |
|---|---|---|
| `@onready` declarations | 14 | Keep dialogs; replace chrome with `W_OverlayChrome` + builder |
| Right-stick scroll (`_update_right_stick_scroll`) | 28 | Extract to `W_RightStickScroller` |
| Focus navigation (`_sync_focus_tracking_from_control`, `_refresh_action_row_highlight`, `_connect_bottom_row_focus_handlers`, `_focus_next_action`, `_focus_previous_action`, `_apply_focus`, `_cycle_row_button`, `_ensure_row_visible`, `_connect_row_focus_handlers`, `_cycle_bottom_button`, `_navigate`, `_navigate_focus`) | ~120 | Extract to `W_RebindFocusNavigator` |
| Public interface (begin_capture, reset_single_action, connect_row_focus_handlers, is_reserved, refresh_bindings, set_reset_button_enabled, configure_focus_neighbors, apply_focus, get_active_device_category, is_binding_custom, get_active_profile, get_profile_for_device_category) | ~46 | Keep — these implement `I_RebindOverlay` |

### New Widget: `W_RightStickScroller`

**File:** `scripts/core/ui/widgets/w_right_stick_scroller.gd`
**Contract:** Polls `Input.get_joy_axis(JOY_AXIS_RIGHT_X/Y)` each frame and drives `scroll_horizontal`/`scroll_vertical` on a target `ScrollContainer`.

```gdscript
class_name W_RightStickScroller extends Control

var _scroll_target: ScrollContainer = null
var _speed: float = 800.0
var _deadzone: float = W_AnalogStickAdapter.STICK_DEADZONE

func bind_scroll_container(target: ScrollContainer, speed: float = 800.0, deadzone: float = W_AnalogStickAdapter.STICK_DEADZONE) -> void:
    _scroll_target = target
    _speed = speed
    _deadzone = deadzone

func _process(delta: float) -> void:
    # ... poll + scroll logic extracted from UI_InputRebindingOverlay ...
```

**Tests:** `tests/unit/ui/widgets/test_w_right_stick_scroller.gd` (3 tests)

### Focus Helper: `U_RebindFocusNavigation`

**File:** `scripts/core/ui/helpers/u_rebind_focus_navigation.gd`
**Contract:** Encapsulates focus-navigation logic specific to the rebind overlay (row highlight dimming, bottom-row tracking, row-button cycling, etc.). This replaces the original widget extraction plan for now.

**API:**
```gdscript
class_name U_RebindFocusNavigation extends RefCounted

func setup(action_rows: Dictionary, focusable_actions: Array[StringName], reset_button: Button, close_button: Button) -> void
func sync_focus_from(control: Control) -> void
func navigate(direction: StringName) -> void
func configure_focus_neighbors() -> void
func apply_focus() -> void
func cycle_row_button(direction: int) -> void
func focus_next_action() -> void
func focus_previous_action() -> void
func ensure_row_visible(row: Control) -> void
func connect_row_focus_handlers(row: Control, add_button: Button, replace_button: Button, reset_button: Button) -> void
func refresh_highlight(is_on_bottom_row: bool, focused_action_index: int) -> void
```

**Tests:** `tests/unit/ui/test_input_rebinding_overlay.gd`

### Builder extension

`U_UIMenuBuilder` already supports `bind_button`, `bind_theme_role`. No builder changes needed.

Use `W_OverlayChrome` for title + close button row instead of `@onready` references.

### Target: 500 lines (~28% reduction)

---

## Phase 10 — UI_InputProfileSelector

### Existing: 605 lines

| Block | Lines | Strategy |
|---|---|---|
| `@onready` declarations | 16 | Replace chrome with `W_OverlayChrome` + builder |
| Preview grid (`_build_bindings_preview`, `_add_action_group_row`, `_add_action_row`, `_add_binding_icons_for_action`, `_apply_preview_row_theme_tokens`) | ~120 | Extract to `W_ProfileBindingPreview` |
| Profile cycling / button text (`_update_button_text`, `_cycle_profile`, `_on_profile_button_pressed`, `_populate_profiles`) | ~80 | Keep in screen — business logic |
| Navigation override (`_navigate_focus`, `_unhandled_input`, `_configure_focus_neighbors`) | ~60 | Keep in screen — profile-selector specific |

### New Widget: `W_ProfileBindingPreview`

**File:** `scripts/core/ui/widgets/w_profile_binding_preview.gd`
**Contract:** Renders a vertical list of action-to-binding rows for a given `RS_InputProfile`. Supports both grouped rows (e.g., movement WASD) and single-action rows.

**API:**
```gdscript
class_name W_ProfileBindingPreview extends Control

func set_profile(profile: RS_InputProfile, theme_config: RS_UIThemeConfig) -> void
func clear() -> void
```

**Tests:** `tests/unit/ui/widgets/test_w_profile_binding_preview.gd` (4 tests)

### Target: 420 lines (~31% reduction)

---

## Phase 11 — UI_SaveLoadMenu

### Existing: 791 lines

| Block | Lines | Strategy |
|---|---|---|
| `@onready` declarations | 9 | Replace chrome with builder |
| Slot grid creation (`_create_slot_item`, `_clear_slot_list`, `_configure_slot_focus`, `_restore_focus_to_slot`, `_get_focused_slot_index`, `_apply_slot_item_theme`) | ~180 | Extract to `W_SaveSlotGrid` |
| Thumbnail async loading (`_load_thumbnail_async`, `_process`, `_load_texture_from_image`, `_ensure_placeholder_texture_loaded`, `_get_placeholder_texture`) | ~100 | Extract to `W_SaveSlotThumbnailLoader` (static helper) |
| Timestamp / playtime formatting (`_format_timestamp`, `_format_playtime`, `_get_localized_month_name`, `_get_localized_am_pm`) | ~60 | Extract to `W_SaveSlotFormatter` (static helper) |
| Save/load/delete business logic (`_perform_save`, `_perform_load`, `_perform_delete`, `_on_action_dispatched`, `_on_slot_item_pressed`, `_on_delete_button_pressed`, `_show_confirmation`, `_on_confirmation_ok`, `_on_confirmation_cancel`) | ~120 | Keep in screen |

### New Widget: `W_SaveSlotGrid`

**File:** `scripts/core/ui/widgets/w_save_slot_grid.gd`
**Contract:** Manages a vertical list of save-slot rows (thumbnail + main button + optional delete button). Handles focus chain, async thumbnail loading, and slot metadata display.

**API:**
```gdscript
class_name W_SaveSlotGrid extends Control

signal slot_pressed(slot_id: StringName, exists: bool)
signal delete_pressed(slot_id: StringName)

func set_slots(metadata: Array[Dictionary], mode: StringName, theme_config: RS_UIThemeConfig) -> void
func get_focused_slot_index() -> int
func restore_focus(slot_index: int) -> void
func set_buttons_enabled(enabled: bool) -> void
```

**Tests:** `tests/unit/ui/widgets/test_w_save_slot_grid.gd` (6 tests)

### New Static Helper: `W_SaveSlotRowFactory`

**File:** `scripts/core/ui/widgets/w_save_slot_row_factory.gd`
**Contract:** Builds save-slot row controls for `W_SaveSlotGrid` so the grid stays focused on container ownership, focus, and thumbnail polling.

**Tests:** Covered through `tests/unit/ui/widgets/test_w_save_slot_grid.gd`

### New Static Helper: `W_SaveSlotThumbnailLoader`

**File:** `scripts/core/ui/widgets/w_save_slot_thumbnail_loader.gd`
**Contract:** Async `ResourceLoader.load_threaded_request` wrapper + `Image.load` fallback for save slot thumbnails. Stateless.

**API:**
```gdscript
class_name W_SaveSlotThumbnailLoader

static func load_async(texture_rect: TextureRect, path: String, placeholder: Texture2D) -> void
static func poll_pending(pending: Dictionary, placeholder: Texture2D) -> Array[TextureRect]  # returns completed
```

**Tests:** `tests/unit/ui/widgets/test_w_save_slot_thumbnail_loader.gd` (3 tests)

### New Static Helper: `W_SaveSlotFormatter`

**File:** `scripts/core/ui/widgets/w_save_slot_formatter.gd`
**Contract:** Formats ISO 8601 timestamps, playtime seconds, and slot display names.

**API:**
```gdscript
class_name W_SaveSlotFormatter

static func format_timestamp(iso_timestamp: String) -> String
static func format_playtime(seconds: int) -> String
static func get_slot_display_name(slot_id: StringName, is_autosave: bool) -> String
```

**Tests:** `tests/unit/ui/widgets/test_w_save_slot_formatter.gd` (4 tests)

### Target: 480 lines (~39% reduction)

---

## Phase 12 — BaseOverlay

### Existing: 166 lines

No `@onready` declarations. The baseline is already clean.

**Action:** Document in `ui-widget-taxonomy.md` that overlays should prefer builder widgets over `@onready` for chrome. No code changes.

---

## Risk: Widget Line Cap

Style suite enforces **120-line cap** on `scripts/core/ui/widgets/w_*.gd`.

| Widget | Estimated Lines | Risk |
|---|---|---|
| `W_RightStickScroller` | ~35 | Low |
| `U_RebindFocusNavigation` | ~330 | Existing helper — not subject to widget cap |
| `W_ProfileBindingPreview` | ~85 | Low |
| `W_SaveSlotGrid` | ~110 | Medium — if thumbnail loading inlined, split to helper |
| `W_SaveSlotRowFactory` | ~65 | Low |
| `W_SaveSlotThumbnailLoader` | ~50 | Low |
| `W_SaveSlotFormatter` | ~40 | Low |

If `W_SaveSlotGrid` exceeds 120 lines, keep thumbnail loading in `W_SaveSlotThumbnailLoader` (already planned) to stay under cap.

## Updated `ui-widget-taxonomy.md` Additions

```markdown
### W_RightStickScroller
**File:** `res://scripts/core/ui/widgets/w_right_stick_scroller.gd`  
**Contract:** Polls right analog stick axes and drives `ScrollContainer` scroll offsets.  
**Consumers:** `UI_InputRebindingOverlay`  

### U_RebindFocusNavigation
**File:** `res://scripts/core/ui/helpers/u_rebind_focus_navigation.gd`  
**Contract:** Focus tracking, row highlight dimming, and directional navigation for rebind action rows.  
**Consumers:** `UI_InputRebindingOverlay`  

### W_ProfileBindingPreview
**File:** `res://scripts/core/ui/widgets/w_profile_binding_preview.gd`  
**Contract:** Renders action-to-binding preview rows from an `RS_InputProfile`.  
**Consumers:** `UI_InputProfileSelector`  

### W_SaveSlotGrid
**File:** `res://scripts/core/ui/widgets/w_save_slot_grid.gd`  
**Contract:** Manages save-slot list UI with thumbnails, main buttons, and optional delete buttons.  
**Consumers:** `UI_SaveLoadMenu`  

### W_SaveSlotRowFactory
**File:** `res://scripts/core/ui/widgets/w_save_slot_row_factory.gd`  
**Contract:** Builds save-slot row controls and wires slot/delete callbacks.  
**Consumers:** `W_SaveSlotGrid`  

### W_SaveSlotThumbnailLoader
**File:** `res://scripts/core/ui/widgets/w_save_slot_thumbnail_loader.gd`  
**Contract:** Async threaded texture loading with fallback for save slot thumbnails.  
**Consumers:** `W_SaveSlotGrid`  

### W_SaveSlotFormatter
**File:** `res://scripts/core/ui/widgets/w_save_slot_formatter.gd`  
**Contract:** Formats ISO timestamps, playtime, and slot display names.  
**Consumers:** `W_SaveSlotGrid`, `UI_SaveLoadMenu`  
```

## Test Strategy

Per screen:
1. Write widget tests first (RED).
2. Refactor screen to use widget (GREEN).
3. Run full UI test suite.
4. Run style suite (`test_style_enforcement.gd`).
5. Commit with (RED)/(GREEN) markers.

## Success Criteria

- [x] `UI_InputRebindingOverlay` ≤ 500 lines
- [x] `UI_InputProfileSelector` ≤ 420 lines
- [x] `UI_SaveLoadMenu` ≤ 480 lines
- [x] All new widgets ≤ 120 lines
- [x] Targeted gap-patch tests pass
- [x] `ui-widget-taxonomy.md` updated
- [x] Style suite passes
