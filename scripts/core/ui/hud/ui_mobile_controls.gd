extends CanvasLayer
class_name UI_MobileControls

const VIRTUAL_JOYSTICK_SCENE := preload("res://scenes/core/ui/widgets/ui_virtual_joystick.tscn")
const VIRTUAL_BUTTON_SCENE := preload("res://scenes/core/ui/widgets/ui_virtual_button.tscn")

@export var force_enable: bool = false
@export var emulate_mobile_override: bool = false
@export var fade_delay: float = 2.0
@export var fade_duration: float = 0.5
@export_range(0.0, 1.0, 0.05) var idle_opacity: float = 0.3
@export_range(0.0, 1.0, 0.05) var active_opacity: float = 1.0

const DEFAULT_TOUCHSCREEN_PROFILE_PATH := "res://scripts/core/resources/input/profiles/default_touchscreen_profile.gd"
const SHELL_GAMEPLAY := StringName("gameplay")
const EDIT_OVERLAY_ID := StringName("edit_touch_controls")
const SIGNPOST_MESSAGE_EVENT := StringName("signpost_message")
const SIGNPOST_DEFAULT_DURATION_SEC: float = 3.0
const SIGNPOST_MIN_DURATION_SEC: float = 0.05
const SIGNPOST_VISIBILITY_BUFFER_SEC: float = 0.35
const DOUBLE_TAP_MAX_INTERVAL_SEC: float = 0.30
const DOUBLE_TAP_MAX_DISTANCE_PX: float = 72.0
const PORTRAIT_EDGE_PADDING: float = 16.0
const PORTRAIT_CONTROL_GAP: float = 8.0
const PORTRAIT_BUTTON_GAP: float = 16.0
var _state_store: I_StateStore = null
var _unsubscribe: Callable = Callable()
var _unsubscribe_signpost: Callable = Callable()
var _controls_root: Control = null
var _default_touchscreen_settings: RS_TouchscreenSettings = RS_TouchscreenSettings.new()
var _joystick: UI_VirtualJoystick = null
var _buttons: Array[UI_VirtualButton] = []
var _profile: RS_InputProfile = null
var _profile_button_positions: Dictionary = {}
var _profile_joystick_position: Vector2 = Vector2.ZERO
var _device_type: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
var _is_transitioning: bool = false
var _has_overlay_active: bool = false
var _is_edit_overlay_active: bool = false
var _current_shell: StringName = StringName("")
var _current_scene_id: StringName = StringName("")
var _fade_delay: float = 0.0
var _fade_duration: float = 0.0
var _fade_elapsed: float = 0.0
var _is_fading: bool = false
var _overlay_input_logged: bool = false
var _awaiting_transition_signal: bool = false  # True when waiting for transition_visual_complete
var _signpost_hide_until_sec: float = -1.0
var _is_signpost_visibility_blocked: bool = false
var _pending_camera_center_just_pressed: bool = false
var _runtime_time_sec: float = 0.0
var _last_empty_space_tap_time_sec: float = -1.0
var _last_empty_space_tap_position: Vector2 = Vector2.ZERO
var _look_touch_id: int = -1
var _look_touch_last_position: Vector2 = Vector2.ZERO
var _pending_look_delta: Vector2 = Vector2.ZERO
var _touch_look_active: bool = false
var _look_drag_sensitivity: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)
	visible = false
	_runtime_time_sec = 0.0

	if not _should_enable():
		queue_free()
		return

	_controls_root = get_node_or_null("Controls") as Control
	if _controls_root == null:
		_controls_root = Control.new()
		_controls_root.name = "Controls"
		add_child(_controls_root)

	_register_with_input_device_manager()

	_profile = _load_touchscreen_profile()
	_cache_profile_positions()

	_state_store = await U_StateUtils.await_store_ready(self)
	if _state_store == null:
		push_error("MobileControls: No M_StateStore available")
		return

	if _unsubscribe == Callable() or not _unsubscribe.is_valid():
		_unsubscribe = _state_store.subscribe(_on_state_changed)

	var initial_state := _state_store.get_state()
	_device_type = _normalize_device_type(U_InputSelectors.get_active_device_type(initial_state))

	_build_controls(initial_state)
	_apply_state(initial_state)
	_update_visibility()
	_subscribe_signpost_messages()

	# Connect to SceneManager's transition_visual_complete signal
	# This tells us when fade-in animation completes and scene is fully visible
	var scene_manager := U_ServiceLocator.try_get_service(StringName("scene_manager"))
	if scene_manager != null and scene_manager.has_signal("transition_visual_complete"):
		scene_manager.transition_visual_complete.connect(_on_transition_visual_complete)

func _exit_tree() -> void:
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()
	if _unsubscribe_signpost != Callable() and _unsubscribe_signpost.is_valid():
		_unsubscribe_signpost.call()
		_unsubscribe_signpost = Callable()
	_state_store = null
	_is_fading = false
	_fade_elapsed = 0.0
	_signpost_hide_until_sec = -1.0
	_is_signpost_visibility_blocked = false
	_pending_camera_center_just_pressed = false
	_runtime_time_sec = 0.0
	_last_empty_space_tap_time_sec = -1.0
	_last_empty_space_tap_position = Vector2.ZERO
	_reset_look_touch_state(true)
	_unregister_from_input_device_manager()

func _on_locale_changed(_locale: StringName) -> void:
	for button in _buttons:
		if button != null and button.has_method("_refresh_icon"):
			button._refresh_icon()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_empty_space_tap(touch.position)
			_handle_look_touch_press(touch)
		else:
			_handle_look_touch_release(touch)
	elif event is InputEventScreenDrag:
		_handle_look_touch_drag(event as InputEventScreenDrag)

func consume_camera_center_just_pressed() -> bool:
	var just_pressed := _pending_camera_center_just_pressed
	_pending_camera_center_just_pressed = false
	return just_pressed

func consume_look_delta() -> Vector2:
	var look_delta := _pending_look_delta
	_pending_look_delta = Vector2.ZERO
	return look_delta

func is_touch_look_active() -> bool:
	return _touch_look_active or not _pending_look_delta.is_zero_approx()

func _should_enable() -> bool:
	if force_enable:
		return true
	if OS.has_feature("mobile"):
		return true
	return _is_emulate_mode()

func _register_with_input_device_manager() -> void:
	var input_manager := U_ServiceLocator.try_get_service(StringName("input_device_manager")) as M_InputDeviceManager
	if input_manager != null:
		input_manager.register_mobile_controls(self)

func _unregister_from_input_device_manager() -> void:
	var input_manager := U_ServiceLocator.try_get_service(StringName("input_device_manager")) as M_InputDeviceManager
	if input_manager != null:
		input_manager.unregister_mobile_controls(self)

func _is_emulate_mode() -> bool:
	if emulate_mobile_override:
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has("--emulate-mobile")

func _handle_empty_space_tap(position: Vector2) -> void:
	if not _can_process_gameplay_touch():
		_reset_double_tap_state()
		return
	if _is_touch_over_virtual_controls(position):
		_reset_double_tap_state()
		return

	var now_sec: float = _runtime_time_sec
	if _last_empty_space_tap_time_sec >= 0.0:
		var elapsed_sec := now_sec - _last_empty_space_tap_time_sec
		var distance_px := _last_empty_space_tap_position.distance_to(position)
		if elapsed_sec <= DOUBLE_TAP_MAX_INTERVAL_SEC and distance_px <= DOUBLE_TAP_MAX_DISTANCE_PX:
			_pending_camera_center_just_pressed = true
			_reset_double_tap_state()
			return

	_last_empty_space_tap_time_sec = now_sec
	_last_empty_space_tap_position = position

func _reset_double_tap_state() -> void:
	_last_empty_space_tap_time_sec = -1.0
	_last_empty_space_tap_position = Vector2.ZERO

func _is_touch_over_virtual_controls(position: Vector2) -> bool:
	if _joystick != null and is_instance_valid(_joystick) and _joystick.get_global_rect().has_point(position):
		return true
	for button in _buttons:
		if button == null or not is_instance_valid(button):
			continue
		if button.get_global_rect().has_point(position):
			return true
	return false

func _can_process_gameplay_touch() -> bool:
	if _awaiting_transition_signal:
		return false
	if _device_type != M_InputDeviceManager.DeviceType.TOUCHSCREEN:
		return false
	if _current_shell != SHELL_GAMEPLAY:
		return false
	if _has_overlay_active or _is_edit_overlay_active:
		return false
	if _is_transitioning:
		return false
	if _is_signpost_visibility_blocked:
		return false
	if force_enable:
		return true
	return U_SceneRegistry.get_scene_type(_current_scene_id) == U_SceneRegistry.SceneType.GAMEPLAY

func _handle_look_touch_press(event: InputEventScreenTouch) -> void:
	if _look_touch_id != -1:
		return
	if not _can_process_gameplay_touch():
		return
	if _is_touch_over_virtual_controls(event.position):
		return
	_look_touch_id = event.index
	_look_touch_last_position = event.position
	_touch_look_active = false

func _handle_look_touch_drag(event: InputEventScreenDrag) -> void:
	if _look_touch_id == -1 or event.index != _look_touch_id:
		return
	if not _can_process_gameplay_touch():
		_reset_look_touch_state(true)
		return
	var drag_delta: Vector2 = event.position - _look_touch_last_position
	_look_touch_last_position = event.position
	if drag_delta.is_zero_approx():
		return
	_touch_look_active = true
	var look_delta := drag_delta * _look_drag_sensitivity
	_pending_look_delta += look_delta
	_on_input_activity()

func _handle_look_touch_release(event: InputEventScreenTouch) -> void:
	if _look_touch_id == -1 or event.index != _look_touch_id:
		return
	_reset_look_touch_state(false)

func _reset_look_touch_state(clear_pending_delta: bool) -> void:
	_look_touch_id = -1
	_look_touch_last_position = Vector2.ZERO
	_touch_look_active = false
	if clear_pending_delta:
		_pending_look_delta = Vector2.ZERO

func _load_touchscreen_profile() -> RS_InputProfile:
	var script: GDScript = load(DEFAULT_TOUCHSCREEN_PROFILE_PATH)
	if script != null:
		var instance: RefCounted = script.new()
		if instance.has_method("build"):
			var result: Variant = instance.build()
			if result is RS_InputProfile:
				return result as RS_InputProfile
	push_error("MobileControls: Failed to load default touchscreen profile")
	return null

func _cache_profile_positions() -> void:
	_profile_button_positions.clear()
	_profile_joystick_position = Vector2.ZERO

	if _profile != null:
		_profile_joystick_position = _profile.virtual_joystick_position
		for button_dict in _profile.virtual_buttons:
			var action_variant: Variant = button_dict.get("action")
			var position_variant: Variant = button_dict.get("position")
			if position_variant is Vector2:
				var action_name := StringName()
				if action_variant is StringName:
					action_name = action_variant
				elif action_variant is String:
					action_name = StringName(action_variant)
				if action_name != StringName():
					_profile_button_positions[String(action_name)] = position_variant

func _build_controls(state: Dictionary) -> void:
	_buttons.clear()
	if _joystick != null and is_instance_valid(_joystick):
		_joystick.queue_free()
		_joystick = null

	var joystick_instance := _create_virtual_joystick()
	if joystick_instance != null:
		joystick_instance.name = "VirtualJoystick"
		_controls_root.add_child(joystick_instance)
		_joystick = joystick_instance
		_connect_input_signals(_joystick)

	for button_key in _profile_button_positions.keys():
		var button_instance := VIRTUAL_BUTTON_SCENE.instantiate() as UI_VirtualButton
		if button_instance == null:
			continue
		var action_name := StringName(button_key)
		button_instance.name = "Button_%s" % action_name
		button_instance.action = action_name
		_controls_root.add_child(button_instance)
		_buttons.append(button_instance)
		_connect_input_signals(button_instance)
	_apply_state(state)

func _create_virtual_joystick() -> UI_VirtualJoystick:
	if ClassDB.class_exists("VirtualJoystick"):
		return VIRTUAL_JOYSTICK_SCENE.instantiate() as UI_VirtualJoystick
	return UI_VirtualJoystick.new()

func _apply_state(state: Dictionary) -> void:
	if state == null:
		return
	_device_type = _normalize_device_type(U_InputSelectors.get_active_device_type(state))

	_apply_touchscreen_settings(U_InputSelectors.get_touchscreen_settings(state))
	_apply_positions(state)
	_update_navigation_state(state)
	_clamp_all_controls()
	_update_visibility()

func _normalize_device_type(device_type: int) -> int:
	if device_type == M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE and _should_enable():
		return M_InputDeviceManager.DeviceType.TOUCHSCREEN
	return device_type

func _apply_touchscreen_settings(settings: Dictionary) -> void:
	_look_drag_sensitivity = clampf(
		float(settings.get("look_drag_sensitivity", _default_touchscreen_settings.look_drag_sensitivity)),
		0.1,
		5.0
	)

	if _joystick != null:
		var joystick_scale: float = float(settings.get("virtual_joystick_size", 1.0))
		_joystick.scale = Vector2.ONE * max(joystick_scale, 0.01)
		var joystick_alpha: float = float(settings.get("virtual_joystick_opacity", 0.7))
		_joystick.modulate.a = clampf(joystick_alpha, 0.0, 1.0)
		_joystick.deadzone = float(settings.get("joystick_deadzone", _default_touchscreen_settings.joystick_deadzone))

	var button_scale: float = float(settings.get("button_size", _default_touchscreen_settings.button_size))
	var button_alpha: float = float(settings.get("button_opacity", 0.8))
	var custom_sizes: Dictionary = {}
	var custom_opacities: Dictionary = {}
	if settings.has("custom_button_sizes") and settings["custom_button_sizes"] is Dictionary:
		custom_sizes = settings["custom_button_sizes"]
	if settings.has("custom_button_opacities") and settings["custom_button_opacities"] is Dictionary:
		custom_opacities = settings["custom_button_opacities"]

	for button in _buttons:
		if button == null:
			continue
		var action_key := String(button.action)
		var size_value := button_scale
		if custom_sizes.has(action_key):
			size_value = float(custom_sizes.get(action_key, button_scale))
		button.scale = Vector2.ONE * max(size_value, 0.01)

		var opacity_value := button_alpha
		if custom_opacities.has(action_key):
			opacity_value = float(custom_opacities.get(action_key, button_alpha))
		button.modulate.a = clampf(opacity_value, 0.0, 1.0)

func _apply_positions(state: Dictionary, allow_overlay_override: bool = false) -> void:
	# Skip position updates when edit overlay is active - let user drag freely
	if _is_edit_overlay_active and not allow_overlay_override:
		return

	if _joystick != null:
		_joystick.position = _get_joystick_position(state)
		_joystick.set_meta("_mobile_controls_custom_position", _has_custom_joystick_position(state))

	var button_positions := _get_button_positions(state)
	var custom_button_positions := _get_custom_button_positions(state)
	for button in _buttons:
		if button == null:
			continue
		var action_key := String(button.action)
		if button_positions.has(action_key):
			button.position = button_positions[action_key]
		button.set_meta(
			"_mobile_controls_custom_position",
			_has_custom_button_position(custom_button_positions, action_key)
		)

func _clamp_all_controls() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	_clamp_all_controls_to_rect(viewport.get_visible_rect())

func _clamp_all_controls_to_rect(bounds: Rect2) -> void:
	_apply_portrait_reachable_layout(bounds)
	_clamp_control_to_rect(_joystick, bounds)
	for button in _buttons:
		_clamp_control_to_rect(button, bounds)

func _apply_portrait_reachable_layout(bounds: Rect2) -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	if bounds.size.x >= bounds.size.y:
		return
	if _joystick == null or not is_instance_valid(_joystick):
		return

	var default_buttons: Array[UI_VirtualButton] = []
	for action_name in [StringName("pause"), StringName("interact"), StringName("jump"), StringName("sprint")]:
		var button := _get_button_for_action(action_name)
		if button != null and not _uses_custom_position(button):
			default_buttons.append(button)

	if default_buttons.is_empty():
		return

	var max_button_width: float = _get_max_button_width(default_buttons)
	if not _uses_custom_position(_joystick):
		var available_joystick_width: float = (
			bounds.size.x -
			max_button_width -
			(PORTRAIT_EDGE_PADDING * 2.0) -
			PORTRAIT_CONTROL_GAP
		)
		if available_joystick_width > 0.0 and _joystick.size.x > 0.0:
			var max_joystick_scale: float = available_joystick_width / _joystick.size.x
			_joystick.scale = Vector2.ONE * minf(_joystick.scale.x, max_joystick_scale)
		var joystick_size: Vector2 = _joystick.size * _joystick.scale
		var joystick_x: float = bounds.position.x + PORTRAIT_EDGE_PADDING
		var joystick_y: float = bounds.end.y - joystick_size.y - PORTRAIT_EDGE_PADDING
		_joystick.position = Vector2(joystick_x, joystick_y)

	_fit_default_button_stack_to_portrait(default_buttons, bounds)
	max_button_width = _get_max_button_width(default_buttons)
	var total_button_height: float = 0.0
	for button in default_buttons:
		var button_size: Vector2 = button.size * button.scale
		total_button_height += button_size.y
	total_button_height += PORTRAIT_BUTTON_GAP * float(maxi(default_buttons.size() - 1, 0))

	var button_x: float = bounds.end.x - max_button_width - PORTRAIT_EDGE_PADDING
	var stack_y: float = bounds.end.y - total_button_height - PORTRAIT_EDGE_PADDING
	stack_y = maxf(stack_y, bounds.position.y + PORTRAIT_EDGE_PADDING)
	for button in default_buttons:
		var placed_button_size: Vector2 = button.size * button.scale
		button.position = Vector2(button_x, stack_y)
		stack_y += placed_button_size.y + PORTRAIT_BUTTON_GAP

func _get_max_button_width(buttons: Array[UI_VirtualButton]) -> float:
	var max_width: float = 0.0
	for button in buttons:
		if button == null or not is_instance_valid(button):
			continue
		max_width = maxf(max_width, (button.size * button.scale).x)
	return max_width

func _fit_default_button_stack_to_portrait(buttons: Array[UI_VirtualButton], bounds: Rect2) -> void:
	var total_height: float = 0.0
	for button in buttons:
		if button == null or not is_instance_valid(button):
			continue
		total_height += (button.size * button.scale).y
	total_height += PORTRAIT_BUTTON_GAP * float(maxi(buttons.size() - 1, 0))
	var available_height := maxf(bounds.size.y - (PORTRAIT_EDGE_PADDING * 2.0), 1.0)
	if total_height <= available_height:
		return
	var scale_factor := available_height / total_height
	for button in buttons:
		if button == null or not is_instance_valid(button):
			continue
		button.scale = button.scale * scale_factor

func _clamp_control_to_rect(control: Control, bounds: Rect2) -> void:
	if control == null or not is_instance_valid(control):
		return
	var scaled_size: Vector2 = control.size * control.scale
	var clamped_position := control.position
	clamped_position.x = clampf(
		clamped_position.x,
		bounds.position.x,
		max(bounds.end.x - scaled_size.x, bounds.position.x)
	)
	clamped_position.y = clampf(
		clamped_position.y,
		bounds.position.y,
		max(bounds.end.y - scaled_size.y, bounds.position.y)
	)
	control.position = clamped_position

func _get_joystick_position(state: Dictionary) -> Vector2:
	var custom: Variant = U_InputSelectors.get_virtual_control_position(state, "virtual_joystick")
	if custom is Vector2:
		return custom
	return _profile_joystick_position

func _has_custom_joystick_position(state: Dictionary) -> bool:
	return U_InputSelectors.get_virtual_control_position(state, "virtual_joystick") is Vector2

func _get_button_positions(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var custom_positions := _get_custom_button_positions(state)
	for action_key in _profile_button_positions.keys():
		var custom_position: Variant = custom_positions.get(action_key)
		if custom_position == null and custom_positions.has(StringName(action_key)):
			custom_position = custom_positions.get(StringName(action_key))
		if custom_position is Vector2:
			result[action_key] = custom_position
		else:
			result[action_key] = _profile_button_positions.get(action_key, Vector2.ZERO)
	return result

func _get_custom_button_positions(state: Dictionary) -> Dictionary:
	var custom_positions_variant: Variant = U_InputSelectors.get_touchscreen_settings(state).get("custom_button_positions", {})
	if custom_positions_variant is Dictionary:
		return custom_positions_variant
	return {}

func _has_custom_button_position(custom_positions: Dictionary, action_key: String) -> bool:
	return custom_positions.has(action_key) or custom_positions.has(StringName(action_key))

func _get_button_for_action(action_name: StringName) -> UI_VirtualButton:
	for button in _buttons:
		if button != null and is_instance_valid(button) and button.action == action_name:
			return button
	return null

func _uses_custom_position(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	return bool(control.get_meta("_mobile_controls_custom_position", false))

func _update_navigation_state(state: Dictionary) -> void:
	var nav_state: Dictionary = state.get("navigation", {})
	var previous_overlay_active: bool = _has_overlay_active

	_current_shell = U_NavigationSelectors.get_shell(nav_state)
	var stack: Array = U_NavigationSelectors.get_overlay_stack(nav_state)
	_has_overlay_active = stack.size() > 0
	_is_edit_overlay_active = U_NavigationSelectors.get_top_overlay_id(nav_state) == EDIT_OVERLAY_ID
	if previous_overlay_active != _has_overlay_active:
		_overlay_input_logged = false

	var scene_state: Dictionary = state.get("scene", {})
	var was_transitioning: bool = _is_transitioning
	_is_transitioning = bool(scene_state.get("is_transitioning", false))
	_current_scene_id = scene_state.get("current_scene_id", StringName(""))

	# When transition starts, block visibility updates until signal fires
	if not was_transitioning and _is_transitioning:
		_awaiting_transition_signal = true

	# Fallback: If state says transition ended but we're still waiting for signal, unblock
	# This handles test environments without real SceneManager or missed signals
	if was_transitioning and not _is_transitioning and _awaiting_transition_signal:
		_awaiting_transition_signal = false
	if not _can_process_gameplay_touch():
		_reset_double_tap_state()
		_reset_look_touch_state(true)

func _update_visibility() -> void:
	# Always show controls when editing, regardless of device type
	if _is_edit_overlay_active:
		visible = true
		_awaiting_transition_signal = false
		return

	# Block all visibility updates if waiting for transition signal
	if _awaiting_transition_signal:
		visible = false
		return

	var device_allows: bool = _device_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN
	var shell_allows: bool = (_current_shell == SHELL_GAMEPLAY) or (force_enable and _current_shell == StringName(""))
	var overlay_allows: bool = not _has_overlay_active or _is_edit_overlay_active
	var scene_allows: bool = true
	if not force_enable:
		scene_allows = U_SceneRegistry.get_scene_type(_current_scene_id) == U_SceneRegistry.SceneType.GAMEPLAY
	var signpost_allows: bool = not _is_signpost_visibility_blocked

	var should_show: bool = device_allows and shell_allows and scene_allows and signpost_allows and not _is_transitioning and overlay_allows

	visible = should_show

func _on_state_changed(__action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return
	_apply_state(state)

## Called when SceneManager's visual transition completes (fade-in finishes)
func _on_transition_visual_complete(__scene_id: StringName) -> void:
	if _awaiting_transition_signal:
		_awaiting_transition_signal = false
		_update_visibility()

func force_apply_positions(state: Dictionary, clamp_controls: bool = true) -> void:
	_apply_positions(state, true)
	if clamp_controls:
		_clamp_all_controls()

func _connect_input_signals(control: Node) -> void:
	if control == null:
		return
	if control.has_signal("joystick_moved"):
		control.joystick_moved.connect(_on_input_activity)
	if control.has_signal("joystick_released"):
		control.joystick_released.connect(_on_input_activity)
	if control.has_signal("button_pressed"):
		control.button_pressed.connect(func(_action: StringName) -> void:
			_on_input_activity()
		)
	if control.has_signal("button_released"):
		control.button_released.connect(func(_action: StringName) -> void:
			_on_input_activity()
		)

## Called when the player interacts with any virtual control.
## Resets opacity to the active value and schedules a tween back to idle opacity.
func _on_input_activity(__data: Variant = null) -> void:
	if _controls_root == null:
		return
	if _has_overlay_active:
		return
	var active_color: Color = _controls_root.modulate
	active_color.a = active_opacity
	_controls_root.modulate = active_color
	_fade_delay = max(fade_delay, 0.0)
	_fade_duration = max(fade_duration, 0.0)
	_fade_elapsed = 0.0
	_is_fading = true

func _process(_delta: float) -> void:
	_runtime_time_sec += maxf(_delta, 0.0)
	_update_signpost_visibility_gate()
	if _controls_root == null or not _is_fading:
		return
	var step: float = max(_delta, 1.0 / 60.0)
	_fade_elapsed += step
	if _fade_elapsed < _fade_delay:
		return
	var progress: float = 1.0
	if _fade_duration > 0.0:
		progress = clampf((_fade_elapsed - _fade_delay) / _fade_duration, 0.0, 1.0)
	var color: Color = _controls_root.modulate
	color.a = lerp(active_opacity, idle_opacity, progress)
	_controls_root.modulate = color
	if progress >= 1.0:
		_is_fading = false

func get_buttons() -> Array:
	return _buttons.duplicate()

func _subscribe_signpost_messages() -> void:
	if _unsubscribe_signpost != Callable() and _unsubscribe_signpost.is_valid():
		return
	_unsubscribe_signpost = U_ECSEventBus.subscribe(SIGNPOST_MESSAGE_EVENT, _on_signpost_message)

func _on_signpost_message(payload: Variant) -> void:
	var data := _extract_event_payload(payload)
	var message_text: String = String(data.get("message", "")).strip_edges()
	if message_text.is_empty():
		return
	var duration_sec: float = _resolve_signpost_duration(data)
	var hide_until: float = _runtime_time_sec + duration_sec + SIGNPOST_VISIBILITY_BUFFER_SEC
	_signpost_hide_until_sec = maxf(_signpost_hide_until_sec, hide_until)
	_update_signpost_visibility_gate()

func _extract_event_payload(event_payload: Variant) -> Dictionary:
	if typeof(event_payload) != TYPE_DICTIONARY:
		return {}
	var event: Dictionary = event_payload
	var nested_payload: Variant = event.get("payload", null)
	if typeof(nested_payload) == TYPE_DICTIONARY:
		return nested_payload as Dictionary
	return event

func _resolve_signpost_duration(payload: Dictionary) -> float:
	var duration_variant: Variant = payload.get("message_duration_sec", SIGNPOST_DEFAULT_DURATION_SEC)
	var duration_sec: float = SIGNPOST_DEFAULT_DURATION_SEC
	if duration_variant is float:
		duration_sec = duration_variant
	elif duration_variant is int:
		duration_sec = float(duration_variant)
	return maxf(duration_sec, SIGNPOST_MIN_DURATION_SEC)

func _update_signpost_visibility_gate() -> void:
	var blocked: bool = false
	if _signpost_hide_until_sec >= 0.0:
		blocked = _runtime_time_sec < _signpost_hide_until_sec
		if not blocked:
			_signpost_hide_until_sec = -1.0
	if blocked == _is_signpost_visibility_blocked:
		return
	_is_signpost_visibility_blocked = blocked
	_update_visibility()
