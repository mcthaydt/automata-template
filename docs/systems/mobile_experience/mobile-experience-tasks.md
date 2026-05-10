# Mobile Experience Tasks

Project-facing checklist for the mobile experience overhaul.

## Completed

- [x] Scene convention auto-registration.
- [x] Mobile presentation baseline.
- [x] Portrait-compatible mobile controls.
- [x] Touch reliability through resets, overlays, transitions, and gamepad handoff.
- [x] App lifecycle Redux slice and notification observer.
- [x] Focus-driven audio mute and background autosave trigger.
- [x] Safe-area inset helper and mobile control clamping.
- [x] Android and Web export preset baseline.

## Release Gates

- [ ] Complete the real-device runtime checks in `docs/systems/mobile_experience/mobile-qa-checklist.md`.
- [ ] Complete Android export checks, including local release signing path verification.
- [ ] Complete Web export checks from a served local export.
- [ ] Run the desktop fallback checks when physical device access is blocked.
- [ ] Run the targeted scene manager suite.
- [ ] Run the targeted touchscreen suite.
- [ ] Run the targeted lifecycle and safe-area suite.
- [ ] Run the style guard.
- [ ] Run the full GUT suite before merge.

## Deferred

- iOS export configuration.
- Mobile renderer and performance retuning.
- Save-path verification on every target OS.
- On-screen keyboard integration.
