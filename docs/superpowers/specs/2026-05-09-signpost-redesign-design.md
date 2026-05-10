# Signpost Redesign: Mobile-First Response Options

**Project**: Automata Template (Godot 4.7)
**Created**: 2026-05-09
**Status**: DESIGN APPROVED

## Summary

Redesign the signpost system from a fire-and-forget text message into a mobile-first, layered interaction system that supports optional response choices. The signpost will become the foundation for the planned dialogue system (renamed at that point). Three modes: message-only (backward compatible), message + responses, and responses-only.

A key interaction innovation is the **hold-to-peek** mechanic: response options with subtext show a `●` indicator. Holding the option reveals hidden intent, skill requirements, sarcasm, or consequences in an overlay detail card. Tapping commits. Not every option needs subtext — it's optional per response entry.

## Interaction Model

### Three Signpost Modes

| Mode | When | Behavior |
|---|---|---|
| Message-only | Config has `message` but no `responses` | Current behavior — non-interactive panel with auto-hide. Tap anywhere or wait for duration to dismiss. |
| Message + responses | Config has `responses` array | Bottom strip shows message text + response buttons. Tap a button to commit. Hold a button with `subtext` to peek at the real meaning. |
| Responses-only | Config has `responses` but empty `message` | Skips message phase, shows response options immediately. |

### Hold-to-Peek Detail Card

- Overlay card appears above the button strip while holding an option that has `subtext`
- Options with subtext show a small `●` indicator in their button
- The held option highlights; other options dim
- Release closes the card; still on the options screen (no commitment yet)
- Mobile: touch-hold (long press with ~300ms threshold). Keyboard: modifier key (Shift). Gamepad: hold A past threshold or X button as alternate peek

### Tap to Commit

- Fires the response's effect immediately
- Signpost panel dismisses or transitions to next message if the effect leads to one
- Non-repeatable signposts lock after commit

### Placement

Bottom strip — message text above, response buttons below. Easy thumb reach on mobile. Preserves 2.5D world visibility above the strip.

## Config Data Shape

### `RS_SignpostInteractionConfig` (extended)

```gdscript
@export_multiline var message: String = ""
@export var responses: Array[RS_SignpostResponse] = []  # NEW — empty = message-only mode
@export var repeatable: bool = true                      # existing — controls lock behavior
@export_range(0.1, 30.0, 0.1, "or_greater") var message_duration_sec: float = 3.0  # existing
@export var interact_prompt: String = "hud.interact_read"  # existing
```

### `RS_SignpostResponse` (NEW resource)

```gdscript
@export var label: String = ""                        # button text or localization key
@export_multiline var subtext: String = ""            # optional — hold-to-peek reveal
@export var effect: RS_EffectSetField = null          # effect to execute on commit
@export var skill_check: RS_SkillCheck = null         # optional — gates option behind stat threshold
@export var is_dismiss: bool = false                  # convenience — marks close/leave option
```

### `RS_SkillCheck` (NEW resource)

```gdscript
@export var stat: StringName = &""
@export var threshold: int = 0
```

- `label` and `subtext` both go through `U_LocalizationUtils.localize()` — localization keys work, literal strings degrade gracefully
- `subtext` can contain rich text tokens like `[Charisma 20+]`
- `effect` reuses the existing `RS_EffectSetField` pattern from QB v2 — same mechanism dialogue will use
- `skill_check` controls whether the option appears grayed out or available; the UI shows requirements in the detail card
- `is_dismiss` means "close panel without executing any effect" — no `effect` needed
- Empty `subtext` = no hold behavior, no `●` indicator. Keeps simple options simple.

**Migration**: Existing signpost configs (message-only) work unchanged. No `responses` array = same behavior as today.

## UI Architecture

### Widget Decomposition

All widgets follow the project's existing pattern: extend `Control` directly, create internal nodes via `add_child()`, live under `res://scripts/core/ui/widgets/` with `w_` prefix, under 120 LOC cap.

| Widget | Responsibility | LOC target |
|---|---|---|
| `W_SignpostMessage` | Renders message text block, handles auto-hide timer and fade-in/out motion | ~40 lines |
| `W_SignpostOptionBar` | Lays out response buttons horizontally, routes tap/hold input events | ~60 lines |
| `W_SignpostOptionButton` | Single option: displays label, `●` indicator for subtext, emits `tap` and `hold` signals | ~50 lines |
| `W_SignpostDetailCard` | Overlay card on hold: renders subtext + skill check badge, auto-sizes | ~40 lines |
| `W_SignpostSkillBadge` | Renders `[Stat N+]` skill requirement text | ~30 lines |

No common base class. Each widget is a standalone `Control` subclass.

### Builder

`U_SignpostPanelBuilder` (`scripts/core/ui/helpers/`) — fluent builder (like `U_SettingsTabBuilder`):

- `create_panel()` → root `SignpostPanelContainer`
- `add_message()` → `W_SignpostMessage`
- `add_option_bar()` → `W_SignpostOptionBar` with `W_SignpostOptionButton` children
- `add_detail_card()` → `W_SignpostDetailCard`
- `.build()` returns the constructed node tree

The HUD controller calls this builder to build or rebuild the panel subtree when signpost mode changes (message-only vs. responses).

### E_Signpost Prefab Builder

Migrate the existing hand-authored `E_Signpost` scene node to a `scripts/demo/editors/` builder script using `U_EditorPrefabBuilder`, following the established Phase 7 pattern. No hand-authored `.tscn` for the signpost scene structure.

### New `.tres` Resources

`RS_SignpostResponse` and `RS_SkillCheck` remain `.tres`-authored config resources — they're data, not scene structure. The builder pattern governs scene/node construction, not resource data.

## Controller Flow & Event Wiring

### Signpost Controller (`inter_signpost.gd` Changes

`_on_activated()` gains response serialization:

```gdscript
func _on_activated(player: Node3D) -> void:
    var typed := _resolve_config()
    if typed == null:
        return
    var effective_message := typed.message
    var effective_repeatable := typed.repeatable
    var effective_duration_sec := maxf(typed.message_duration_sec, 0.1)
    signpost_activated.emit(effective_message, self)
    U_ECSEventBus.publish(SIGNPOST_MESSAGE_EVENT, {
        "message": effective_message,
        "controller_id": get_instance_id(),
        "repeatable": effective_repeatable,
        "message_duration_sec": effective_duration_sec,
        "responses": _serialize_responses(typed.responses)  # NEW
    })
    if not effective_repeatable:
        lock()
        _hide_interact_prompt()
    super._on_activated(player)
```

`_serialize_responses()` converts `Array[RS_SignpostResponse]` into an array of dictionaries for the event bus. Resource references (effects, skill checks) serialize to dictionaries so they cross the event bus cleanly. The HUD controller deserializes them on receipt.

```
{label: "Examine", subtext: "", skill_check: null, effect: null, is_dismiss: false}
{label: "Knock", subtext: "You rap your knuckles on the cold iron...", skill_check: null, effect: {type: "publish_event", event_name: "signpost_knock_door"}, is_dismiss: false}
{label: "Persuade", subtext: "[Charisma 20+] \"Well, you'd like that, wouldn't you?\"", skill_check: {stat: "charisma", threshold: 20}, effect: {type: "set_field", field: "door_persuaded", value: true}, is_dismiss: false}
{label: "Leave", subtext: "", skill_check: null, effect: null, is_dismiss: true}
```

### HUD Controller (`ui_hud_controller.gd`) Changes

- `_on_signpost_message()` inspects `payload.responses`
- If `responses` is empty or missing → existing message-only flow (unchanged)
- If `responses` has entries → call `U_SignpostPanelBuilder` to build option bar, show panel in response mode
- On tap: fire the response's `effect`. If effect is `RS_EffectSetField`, execute it. If `is_dismiss`, close panel
- On hold: `W_SignpostOptionButton` emits `hold_started` → `W_SignpostDetailCard` appears with subtext. `hold_ended` → card hides

### Effect Execution (MVP)

Response effects reuse `RS_EffectSetField` from QB v2. Supported effect types for MVP:

- **Publish event** — same as current signpost flow, triggered by a specific response
- **Set field** — set a narrative flag (for dialogue state tracking later)
- **Dismiss** — close panel, no effect executed

More effect types (scene transitions, inventory, etc.) are future scope when the dialogue system proper lands.

### Mobile Input Flow

- `_gui_input()` on `W_SignpostOptionButton` distinguishes tap vs. hold using a timer threshold (~300ms)
- While the detail card is showing, the option bar captures all input — no accidental commit during hold
- Gamepad: A button = tap (commit). Hold A past threshold = peek. X button = alternate peek. Focus navigation via D-pad between options

### Backward Compatibility

- All existing signpost configs work unchanged (no `responses` key = message-only mode)
- The existing `signpost_activated` signal on `Inter_Signpost` continues to fire
- The mobile controls signpost-visibility-gate (`_is_signpost_visibility_blocked`) continues to work — it gates based on `_signpost_hide_until_sec` regardless of mode
- Existing tests pass without modification; new tests cover the response modes

## Migration Plan

| Current | Migration Target |
|---|---|
| Hand-authored `E_Signpost` in `.tscn` scenes | Builder script via `U_EditorPrefabBuilder` (or `U_SignpostBuilder` if warranted) |
| `RS_SignpostInteractionConfig` (.tres) | Extended with `responses` array — stays as `.tres` for config data |
| `inter_signpost.gd` controller | Stays, `_on_activated` refactored to serialize and pass responses |
| `ui_hud_overlay.tscn` signpost panel | Panel subtree built by `U_SignpostPanelBuilder`; existing message-only path preserved |
| New `W_Signpost*` widgets | Built programmatically, no hand-authored `.tscn` for widget internals |

## Files Affected

### New files
- `scripts/core/resources/interactions/rs_signpost_response.gd` — `RS_SignpostResponse`
- `scripts/core/resources/interactions/rs_skill_check.gd` — `RS_SkillCheck`
- `scripts/core/ui/widgets/w_signpost_message.gd`
- `scripts/core/ui/widgets/w_signpost_option_bar.gd`
- `scripts/core/ui/widgets/w_signpost_option_button.gd`
- `scripts/core/ui/widgets/w_signpost_detail_card.gd`
- `scripts/core/ui/widgets/w_signpost_skill_badge.gd`
- `scripts/core/ui/helpers/u_signpost_panel_builder.gd`
- `resources/core/interactions/signposts/cfg_signpost_response_*.tres` — sample response configs
- `tests/unit/ui/test_w_signpost_message.gd`
- `tests/unit/ui/test_w_signpost_option_bar.gd`
- `tests/unit/ui/test_w_signpost_option_button.gd`
- `tests/unit/ui/test_w_signpost_detail_card.gd`
- `tests/unit/ui/test_signpost_response_modes.gd`
- `tests/unit/interactables/test_e_signpost_responses.gd`

### Modified files
- `scripts/core/resources/interactions/rs_signpost_interaction_config.gd` — add `responses` array
- `scripts/core/gameplay/inter_signpost.gd` — serialize and pass responses in event payload
- `scripts/core/ui/hud/ui_hud_controller.gd` — inspect responses, route to builder
- `resources/core/interactions/signposts/cfg_signpost_default.tres` — unchanged (message-only, backward compatible)
- `resources/demo/interactions/signposts/cfg_signpost_*.tres` — add response examples to demo configs

## Out of Scope

- Full dialogue system (speaker names, typewriter text, multi-line sequences) — signpost redesign is the foundation, dialogue builds on top later
- NPC portrait/emotion display
- Voice acting / audio playback
- Dialogue log / history UI
- Scene transitions triggered by responses (future: use `RS_EffectSetField` with publish-event effects)
- Inventory effects from responses (future: expand `RS_EffectSetField` effect types)