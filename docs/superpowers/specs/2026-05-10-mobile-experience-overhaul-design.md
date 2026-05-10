# Mobile Experience Overhaul Design

## Summary

The mobile overhaul makes mobile a first-class platform target without turning portrait gameplay into a separate product. The work is one program with four phases: convention-based scene auto-registration, mobile presentation baseline, touch gameplay polish, and production QA.

## Goals

- Standard scenes under known folders register through conventions instead of hand-authored scene registry entries.
- Mobile runs fullscreen cleanly and handles safe-area and portrait-compatible layouts without broken menus or unusable HUD.
- Touchscreen gameplay feels reliable across resets, transitions, overlays, and gamepad handoff.
- Mobile QA has repeatable commands, real-device checks, and debug visibility.

## Non-Goals

- Portrait-optimized gameplay composition is not part of this plan. Portrait should run without breaking, but landscape remains the intended gameplay orientation.
- Runtime scene-tree discovery is not the source of truth for scene loading. SceneManager continues to consume registry metadata.
- New `.tscn` files are not authored by hand. Any new scene or prefab work must use the existing builder workflow.

## Architecture

Scene auto-registration extends the existing scene registry loader path. A new convention scanner/generator derives scene entries from paths such as `scenes/demo/gameplay/gameplay_demo_room.tscn` and feeds `U_SceneRegistry` through the same dictionary shape used by `U_SceneRegistryBuilder` and `RS_SceneManifestConfig`.

Mobile presentation remains split across Display Manager, UI Manager, and Input Manager ownership boundaries. Display owns fullscreen/window/mobile scaling state. UI owns shell, overlay, settings, and HUD layout behavior. Input owns active device detection, touchscreen settings, and touch/gamepad handoff.

Gameplay touch input continues through `UI_MobileControls` and `S_TouchscreenSystem`. Improvements should preserve the existing Redux input state contracts and the mobile reset pitfall documented in `docs/guides/pitfalls/MOBILE.md`.

## Scene Auto-Registration Design

The preferred authoring experience is zero config for standard scenes. Authors place a scene in a conventional folder and run a sync/validation tool.

Initial conventions:

- `scenes/demo/gameplay/gameplay_*.tscn` registers as `SceneType.GAMEPLAY`, `default_transition = "loading"`, `preload_priority = 5`.
- `scenes/core/ui/menus/ui_*.tscn` registers as `SceneType.MENU` or `SceneType.END_GAME` from an allow-list for core screens that are not hardcoded.
- `scenes/core/ui/overlays/ui_*.tscn` and `scenes/core/ui/settings/ui_*.tscn` register as `SceneType.UI`, `default_transition = "instant"`, `preload_priority = 5`.
- Hardcoded boot-critical scenes stay hardcoded in `U_SceneRegistry` for startup safety.
- Existing manifest resources remain supported for explicit overrides and extension modules.

The scanner must avoid prefabs, templates, widgets, debug scenes, and tests unless a rule explicitly includes them.

## Mobile Presentation Design

Mobile should default to fullscreen/export-safe behavior and keep UI inside safe areas. Portrait support is compatibility-level:

- Menus, settings, overlays, and endgame screens should reflow or remain usable in portrait.
- Gameplay HUD and controls should clamp to visible safe bounds in portrait.
- Camera framing and gameplay layout do not need a portrait-specific design pass.
- Mobile fullscreen and orientation behavior should be validated on physical devices, because headless tests cannot prove OS-level behavior.

## Touch Gameplay Design

Touch control improvements should prioritize reliability over new gesture surface area:

- Preserve active device state across run reset and scene transitions.
- Keep controls hidden during overlays, non-gameplay shells, and transitions.
- Avoid touch/mouse emulation races on mobile and web.
- Make touch look, recenter gesture, virtual joystick, and buttons configurable through existing touchscreen settings.
- Prevent HUD prompts and signposts from fighting the touch-control area.

## QA Design

The overhaul must ship with testable gates:

- Unit tests for scene convention scanning and duplicate/override behavior.
- Scene registry tests proving generated entries load through `U_SceneRegistry`.
- Input and touchscreen flow tests for reset, visibility, device handoff, and touch look.
- Display/UI tests for selector defaults and safe-area helpers where headless coverage is possible.
- Manual mobile checklist for fullscreen, portrait compatibility, real touch, real gamepad, app suspend/resume, and reset-after-victory.

## Open Decisions Locked By Brainstorming

- Mobile overhaul is one phased program.
- Scene auto-registration means convention-based scene registration for standard scenes.
- Portrait gameplay is allowed but not optimized.
- Runtime systems keep existing manager boundaries and Redux contracts.
