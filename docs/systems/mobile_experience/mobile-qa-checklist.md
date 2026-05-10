# Mobile QA Checklist

Manual mobile validation gates for Android native and mobile web builds.

## Real Device Runtime Checks

- [ ] Boot to menu in landscape.
- [ ] Rotate to portrait and confirm menu, settings, and endgame screens remain usable.
- [ ] Start gameplay and confirm portrait does not trap input or hide controls.
- [ ] Complete or reset a run and confirm touch controls still work.
- [ ] Connect and disconnect a gamepad and confirm touch visibility changes correctly.
- [ ] Suspend and resume the app and confirm pause state, audio mute, and autosave behavior.
- [ ] Foreground after suspend and confirm audio restores and the game remains paused when expected.
- [ ] Trigger Android back gesture in gameplay and confirm current `ui_cancel` routing: close top overlay when one exists; otherwise no-op. Use `ui_pause` to open pause from gameplay.
- [ ] Trigger Android back gesture in menu shells and confirm back navigation follows the active panel or screen contract.
- [ ] Confirm `UI_MobileControls` joystick and buttons stay outside notch or cutout regions.

## Android Export Checks

- [ ] APK builds via the configured Android preset.
- [ ] APK installs and launches on at least one physical Android device.
- [ ] Launcher icon and app name render correctly.
- [ ] Package name is `com.crispycabaret.automatatemplate`.
- [ ] Keystore file is not committed.
- [ ] Signing path for release builds: `~/.config/godot/automata-template/android/release.keystore`.
- [ ] Release signing credentials are provided locally through Godot export settings or CI secrets.
- [ ] Permissions remain limited to engine defaults; no network, location, camera, or microphone permissions are enabled for this program.

## Web Export Checks

- [ ] HTML5 export builds via the configured Web preset.
- [ ] Export is served through a local HTTP server, for example:

```bash
cd builds/web
python3 -m http.server 8080
```

- [ ] Mobile browser loads the served export.
- [ ] Touch controls are reachable in portrait and landscape browser orientations.
- [ ] PWA support remains off.

## Desktop Fallback Checks

Run these when a physical device is not available:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --emulate-mobile --quit-after 3
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
```

Desktop emulation is a smoke test only. Real-device checks remain required before shipping mobile changes.
