@icon("res://assets/core/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_TouchscreenSystem

## Processes virtual joystick/buttons on mobile and updates input components.
## Guards against device races and supports an emergency disable flag.

const INPUT_TYPE := StringName("C_InputComponent")
const ACTION_MOVE_STRENGTH := StringName("move")
const ACTION_LOOK_STRENGTH := StringName("look")
const SHELL_GAMEPLAY := StringName("gameplay")
const I_INPUT_DEVICE_MANAGER := preload("res://scripts/core/interfaces/i_input_device_manager.gd")
const GAMEPLAY_ACTIONS := preload("res://scripts/core/state/actions/u_gameplay_actions.gd")

@export var force_enable: bool = false
@export var emulate_mobile_override: bool = false

var _state_store: I_StateStore = null
var _mobile_controls: UI_MobileControls = null
var _joystick: UI_VirtualJoystick = null
var _button_map: Dictionary = {}
var _last_jump_pressed: bool = false
var _last_touch_look_active: bool = false

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.INPUT

func on_configured() -> void:
	_ensure_state_store_ready()

func process_tick(__delta: float) -> void:
	if not _should_process():
		return

	_ensure_state_store_ready()
	var store := _get_state_store()
	if store == null:
		return

	var state := store.get_state()
	if not _can_process_gameplay_touch(state):
		_dispatch_touch_look_active_if_changed(store, false)
		return

	var active_device: int = U_InputSelectors.get_active_device_type(state)
	if active_device != M_InputDeviceManager.DeviceType.TOUCHSCREEN:
		_dispatch_touch_look_active_if_changed(store, false)
		return  # Guard against race where device switched this frame

	if not _ensure_controls_ready():
		_dispatch_touch_look_active_if_changed(store, false)
		return

	var move_vector := _get_move_vector()
	var look_delta := _consume_look_delta()
	var touch_look_active := _is_touch_look_active()
	var jump_pressed := _get_button_pressed(StringName("jump"))
	var sprint_pressed := _get_button_pressed(StringName("sprint"))
	var jump_just_pressed := jump_pressed and not _last_jump_pressed
	var camera_center_just_pressed := _consume_camera_center_just_pressed()

	_dispatch_state(
		store,
		move_vector,
		look_delta,
		touch_look_active,
		jump_pressed,
		jump_just_pressed,
		sprint_pressed,
		camera_center_just_pressed
	)
	_update_components(move_vector, look_delta, jump_just_pressed, sprint_pressed)

	_last_jump_pressed = jump_pressed

func _should_process() -> bool:
	if force_enable:
		return true
	if OS.has_feature("mobile"):
		return true
	return _is_emulate_mode()

func _is_emulate_mode() -> bool:
	if emulate_mobile_override:
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has("--emulate-mobile")

func _ensure_state_store_ready() -> void:
	if _state_store != null and is_instance_valid(_state_store):
		return
	_state_store = U_StateUtils.get_store(self)

func _get_state_store() -> I_StateStore:
	if _state_store == null or not is_instance_valid(_state_store):
		_state_store = null
		return null
	return _state_store

func _ensure_controls_ready() -> bool:
	if _mobile_controls == null or not is_instance_valid(_mobile_controls):
		_mobile_controls = _resolve_mobile_controls()
		_button_map.clear()
		_joystick = null
		if _mobile_controls != null and is_instance_valid(_mobile_controls):
			_joystick = _mobile_controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick
			_cache_buttons(_mobile_controls.get_buttons())

	if _mobile_controls == null or not is_instance_valid(_mobile_controls):
		return false

	if _joystick == null or not is_instance_valid(_joystick):
		_joystick = _mobile_controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick

	if _button_map.is_empty():
		_cache_buttons(_mobile_controls.get_buttons())

	return _joystick != null and is_instance_valid(_joystick)

func _cache_buttons(buttons: Array) -> void:
	_button_map.clear()
	for button in buttons:
		if not (button is UI_VirtualButton):
			continue
		var vb := button as UI_VirtualButton
		_button_map[String(vb.action)] = vb

func _resolve_mobile_controls() -> UI_MobileControls:
	var manager := U_ServiceLocator.try_get_service(StringName("input_device_manager")) as I_INPUT_DEVICE_MANAGER
	if manager != null:
		var controls := manager.get_mobile_controls() as UI_MobileControls
		if controls != null and is_instance_valid(controls):
			return controls

	var tree := get_tree()
	if tree != null:
		var matches := tree.get_root().find_children("*", "UI_MobileControls", true, false)
		if not matches.is_empty():
			var first_match := matches[0] as UI_MobileControls
			if first_match != null and is_instance_valid(first_match):
				return first_match
	return null

func _get_move_vector() -> Vector2:
	if _joystick == null or not is_instance_valid(_joystick):
		return Vector2.ZERO
	return _joystick.get_vector()

func _get_button_pressed(action: StringName) -> bool:
	var button: UI_VirtualButton = _button_map.get(String(action))
	if button == null or not is_instance_valid(button):
		return false
	return button.is_pressed()

func _consume_camera_center_just_pressed() -> bool:
	if _mobile_controls == null or not is_instance_valid(_mobile_controls):
		return false
	return _mobile_controls.consume_camera_center_just_pressed()

func _consume_look_delta() -> Vector2:
	if _mobile_controls == null or not is_instance_valid(_mobile_controls):
		return Vector2.ZERO
	return _mobile_controls.consume_look_delta()

func _is_touch_look_active() -> bool:
	if _mobile_controls == null or not is_instance_valid(_mobile_controls):
		return false
	return _mobile_controls.is_touch_look_active()

func _dispatch_state(
	store: I_StateStore,
	move_vector: Vector2,
	look_delta: Vector2,
	touch_look_active: bool,
	jump_pressed: bool,
	jump_just_pressed: bool,
	sprint_pressed: bool,
	camera_center_just_pressed: bool
) -> void:
	if store == null or not is_instance_valid(store):
		return
	store.dispatch(U_InputActions.update_move_input(move_vector))
	store.dispatch(U_InputActions.update_look_input(look_delta, U_InputActions.LOOK_SOURCE_TOUCHSCREEN))
	store.dispatch(U_InputActions.update_camera_center_state(camera_center_just_pressed))
	store.dispatch(U_InputActions.update_jump_state(jump_pressed, jump_just_pressed))
	store.dispatch(U_InputActions.update_sprint_state(sprint_pressed))
	_dispatch_touch_look_active_if_changed(store, touch_look_active)

func _dispatch_touch_look_active_if_changed(store: I_StateStore, active: bool) -> void:
	if store == null or not is_instance_valid(store):
		return
	if _last_touch_look_active == active:
		return
	_last_touch_look_active = active
	store.dispatch(GAMEPLAY_ACTIONS.set_touch_look_active(active))

func _update_components(
	move_vector: Vector2,
	look_delta: Vector2,
	jump_just_pressed: bool,
	sprint_pressed: bool
) -> void:
	var components := get_components(INPUT_TYPE)
	var move_strength := clampf(move_vector.length(), 0.0, 1.0)
	var look_strength := clampf(look_delta.length(), 0.0, 1.0)

	for entry in components:
		var input_component := entry as C_InputComponent
		if input_component == null:
			continue

		input_component.set_move_vector(move_vector)
		input_component.set_sprint_pressed(sprint_pressed)
		if jump_just_pressed:
			input_component.set_jump_pressed(true)
		input_component.set_device_type(M_InputDeviceManager.DeviceType.TOUCHSCREEN)
		input_component.clear_action_strengths()
		input_component.set_action_strength(ACTION_MOVE_STRENGTH, move_strength)
		input_component.set_action_strength(ACTION_LOOK_STRENGTH, look_strength)

func _is_touchscreen_disabled(state: Dictionary) -> bool:
	return U_DebugSelectors.is_touchscreen_disabled(state)

func _can_process_gameplay_touch(state: Dictionary) -> bool:
	if _is_touchscreen_disabled(state):
		return false
	if U_NavigationSelectors.get_shell(state) != SHELL_GAMEPLAY:
		return false
	if not U_NavigationSelectors.get_overlay_stack(state).is_empty():
		return false
	if U_SceneSelectors.is_transitioning(state):
		return false
	if force_enable:
		return true
	return U_SceneRegistry.get_scene_type(U_SceneSelectors.get_current_scene_id(state)) == U_SceneRegistry.SceneType.GAMEPLAY
