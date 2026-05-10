# Mobile / Touchscreen Pitfalls

Mobile and touchscreen-specific runtime gotchas.

Manual release gates live in `docs/systems/mobile_experience/mobile-qa-checklist.md`.

---

## App Lifecycle And Back Gesture

- **Do not subscribe to OS notifications in individual managers**: `U_AppLifecycleObserver` is the central lifecycle bridge. It translates Godot notifications into Redux actions and synthetic input only; managers should react to state/selectors or normal input flow.

  **Lifecycle actions emitted by the observer**:
  - `ACTION_APP_BACKGROUNDED` from `NOTIFICATION_APPLICATION_PAUSED`
  - `ACTION_APP_FOREGROUNDED` from `NOTIFICATION_APPLICATION_RESUMED`
  - `ACTION_APP_FOCUS_LOST` from `NOTIFICATION_WM_WINDOW_FOCUS_OUT`
  - `ACTION_APP_FOCUS_GAINED` from `NOTIFICATION_WM_WINDOW_FOCUS_IN`

  **Why this matters**: Scattering OS notification handlers across audio, save, UI, and input code creates ordering bugs and duplicate side effects. Keep the observer thin, then let subscribers handle side effects through the existing Redux contracts.

- **Android back gesture maps to `ui_cancel` only**: `NOTIFICATION_WM_GO_BACK_REQUEST` becomes a synthetic `ui_cancel` event. `U_AppLifecycleObserver` must not open pause menus, pop overlays, or call scene managers directly.

  **Current routing contract**:
  - Gameplay shell with overlays: `ui_cancel` closes the top overlay.
  - Gameplay shell without overlays: `ui_cancel` is a no-op; `ui_pause` opens the pause menu.
  - Main-menu shell: `ui_cancel` routes back toward the root panel when the current base scene is the root menu.
  - Endgame shell: `ui_cancel` follows the screen-specific retry, credits, or return-to-menu behavior.

- **Backgrounding and focus are separate**: App pause/resume controls `is_backgrounded`; window focus in/out controls `is_focused`. Do not collapse them into one flag. Audio reacts to focus changes, while suspend/autosave behavior reacts to backgrounding.

- **Safe area math stays pure**: `U_SafeAreaInsets` accepts caller-provided usable/window rects. It must not call `DisplayServer` directly. Runtime callers such as `UI_MobileControls` source live rects through `U_DisplayServerWindowOps`, then pass those rects into the helper.

---

## Mobile/Touchscreen Pitfalls

- **Device state must persist across game resets**: When implementing game reset/restart actions (like `U_GameplayActions.reset_progress()`), DO NOT reset the entire input state to defaults. Device-specific state fields must be preserved across progress resets to maintain correct device type after restarting the run.

  **Problem**: After completing the game and clicking "reset run" from the victory screen, the touchscreen controls become unresponsive. The game resets `active_device` from `2` (TOUCHSCREEN) to `0` (KEYBOARD_MOUSE), causing `MobileControls` to hide and input to stop working.

  **Why this happens**: When `reset_progress()` calls `INPUT_REDUCER.get_default_gameplay_input_state()`, it resets ALL input state including device detection fields. The default state has `active_device: 0` (KEYBOARD_MOUSE), which overrides the actual device type.

  **Solution**: When resetting gameplay state, preserve device state from the current input state before applying defaults:
  ```gdscript
  # In u_gameplay_reducer.gd ACTION_RESET_PROGRESS handler:

  # WRONG - resets everything including device state:
  var reset_input := INPUT_REDUCER.get_default_gameplay_input_state()
  return _apply_input_state(reset_state, reset_input)

  # CORRECT - preserve device state:
  var current_input: Dictionary = _get_current_input(state)
  var reset_input := INPUT_REDUCER.get_default_gameplay_input_state()
  reset_input["active_device"] = current_input.get("active_device", 0)
  reset_input["gamepad_connected"] = current_input.get("gamepad_connected", false)
  reset_input["gamepad_device_id"] = current_input.get("gamepad_device_id", -1)
  reset_input["touchscreen_enabled"] = current_input.get("touchscreen_enabled", false)
  reset_input["last_input_time"] = current_input.get("last_input_time", 0.0)
  return _apply_input_state(reset_state, reset_input)
  ```

  **Fields that must be preserved**:
  - `active_device` (TOUCHSCREEN/GAMEPAD/KEYBOARD_MOUSE)
  - `gamepad_connected` status
  - `gamepad_device_id`
  - `touchscreen_enabled`
  - `last_input_time`

  **Fields that should be reset** (transient gameplay input):
  - `move_input` → Vector2.ZERO
  - `look_input` → Vector2.ZERO
  - `jump_pressed` → false
  - `jump_just_pressed` → false
  - `sprint_pressed` → false

  **Testing**: After implementing a reset action, verify device type persists:
  1. Start game on mobile (device_type should be 2)
  2. Complete game or trigger reset action
  3. Verify device_type remains 2 (not reset to 0)
  4. Verify touchscreen controls continue working without gamepad input

  **Real example**: `scripts/state/reducers/u_gameplay_reducer.gd:199-207` preserves device state during `ACTION_RESET_PROGRESS` to fix touchscreen controls becoming unresponsive after victory screen reset.

---

## Screen Orientation

- **Mobile fullscreen must explicitly set screen orientation**: When `M_DisplayManager` forces mobile into fullscreen mode, `U_DisplayWindowApplier` must call `screen_set_orientation(SCREEN_ORIENTATION_SENSOR_LANDSCAPE)` to allow landscape rotation. Without this call, Godot's fullscreen mode on Android/iOS locks to the device's natural orientation, ignoring the `project.godot` `window/handheld/orientation` setting.

  **Why this happens**: `DisplayServer.window_set_mode(WINDOW_MODE_FULLSCREEN)` on mobile overrides the project orientation setting. The project-level `sensor_landscape` acts as a default, but runtime fullscreen requires an explicit `screen_set_orientation` call to restore landscape rotation.

  **Current routing contract**:
  - Mobile (`U_MobilePlatformDetector.is_mobile() == true`): `apply_settings()` calls `_set_orientation(SCREEN_ORIENTATION_SENSOR_LANDSCAPE)` before setting window mode. This allows landscape↔reverse-landscape rotation but blocks portrait.
  - Desktop: No orientation override is applied (OS manages window orientation).
  - Orientation call goes through `I_WindowOps.screen_set_orientation()` for testability.

  **Compat note**: `SCREEN_ORIENTATION_SENSOR_LANDSCAPE` (value `4`) and `SCREEN_OF_MAIN_WINDOW` (value `-1`) are defined as compat constants in `U_DisplayWindowApplier` and `U_DisplayServerWindowOps` because Godot 4.6.1 (headless test runner) does not expose the `ScreenOrientation` enum. The constant values map to `DisplayServer.SCREEN_SENSOR_LANDSCAPE` and `DisplayServer.SCREEN_OF_MAIN_WINDOW` in Godot 4.7. `U_DisplayServerWindowOps.screen_set_orientation()` guards with `DisplayServer.has_method("screen_set_orientation")` so it no-ops on older runtimes.

  **Important**: The Godot 4.7 `ScreenOrientation` enum values differ from what you might expect. Always verify against `ClassDB.class_get_integer_constant_list("DisplayServer")` rather than guessing:
  - `SCREEN_LANDSCAPE = 0` (locked landscape)
  - `SCREEN_PORTRAIT = 1` (locked portrait)
  - `SCREEN_REVERSE_LANDSCAPE = 2` (locked reverse-landscape)
  - `SCREEN_REVERSE_PORTRAIT = 3` (locked reverse-portrait — this is NOT sensor landscape!)
  - `SCREEN_SENSOR_LANDSCAPE = 4` (landscape + reverse-landscape, auto-rotate between them)
  - `SCREEN_SENSOR_PORTRAIT = 5` (portrait + reverse-portrait)
  - `SCREEN_SENSOR = 6` (all four orientations)
