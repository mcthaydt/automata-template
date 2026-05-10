# Mobile / Touchscreen Pitfalls

Mobile and touchscreen-specific runtime gotchas.

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
