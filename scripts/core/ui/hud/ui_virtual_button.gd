extends Control
class_name UI_VirtualButton


signal button_pressed(action: StringName)
signal button_released(action: StringName)

enum ActionType {
	TAP,
	HOLD
}

@export var action: StringName = StringName("jump")
@export var action_type: ActionType = ActionType.HOLD
@export var can_reposition: bool = false
@export var control_name: StringName = StringName()

const DEFAULT_SIZE := Vector2(80, 80)
const PRESSED_SCALE := Vector2(0.95, 0.95)
const RELEASED_SCALE := Vector2.ONE
const PRESSED_MODULATE := Color(0.8, 0.8, 0.8, 1.0)
const RELEASED_MODULATE := Color(1, 1, 1, 1)
const ACTION_COLORS := {
	StringName("jump"): Color(0.6, 0.9, 1.0),
	StringName("sprint"): Color(0.6, 1.0, 0.7),
	StringName("interact"): Color(1.0, 0.85, 0.6),
	StringName("pause"): Color(1.0, 0.6, 0.7)
}
const BUTTON_BG_COLOR := Color(0.4, 0.4, 0.4, 0.5)
const BUTTON_BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const BUTTON_BORDER_WIDTH := 1.5
const ICON_PREFIX := "res://assets/core/button_prompts/mobile/icon_"
const ICON_SUFFIX := ".svg"

const BRIDGE_MODE_NONE := 0
const BRIDGE_MODE_INPUT_ACTION := 1
const BRIDGE_MODE_PAUSE_TOGGLE := 2

const ACTION_BRIDGE_MODES := {
	StringName("interact"): BRIDGE_MODE_INPUT_ACTION,
	StringName("pause"): BRIDGE_MODE_PAUSE_TOGGLE,
}

@onready var _icon_texture_rect: TextureRect = null

var _touch_id: int = -1
var _is_pressed: bool = false
var _is_repositioning: bool = false
var _touch_offset_from_control: Vector2 = Vector2.ZERO
var _store: I_StateStore = null
var _visual_base_scale: Vector2 = Vector2.ONE
var _visual_base_modulate: Color = Color(1, 1, 1, 1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_icon_texture_rect = get_node_or_null("ActionIcon") as TextureRect
	_ensure_default_size()
	_apply_button_style()
	_load_icon()
	_apply_release_visuals()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_touch_press(touch)
		else:
			_handle_touch_release(touch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)

func is_pressed() -> bool:
	return _is_pressed

func _handle_touch_press(event: InputEventScreenTouch) -> void:
	if _touch_id != -1:
		return
	var inside := _is_touch_inside(event.position)
	if not inside:
		return
	_touch_id = event.index
	_is_repositioning = can_reposition
	if _is_repositioning:
		_touch_offset_from_control = _get_parent_local_position(event.position) - position
		_is_pressed = false
		return
	_press()

func _handle_touch_release(event: InputEventScreenTouch) -> void:
	if event.index != _touch_id:
		return
	_release()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if _touch_id == -1 or event.index != _touch_id:
		return
	if _is_repositioning:
		var parent_local := _get_parent_local_position(event.position)
		position = parent_local - _touch_offset_from_control
		return
	if not _is_touch_inside(event.position):
		_release(true)

func _press() -> void:
	_visual_base_scale = scale
	_visual_base_modulate = modulate
	_is_pressed = true
	_apply_pressed_visuals()
	_bridge_on_press()
	if action_type == ActionType.HOLD:
		button_pressed.emit(action)

func _release(was_canceled: bool = false) -> void:
	var was_pressed := _is_pressed
	var was_repositioning := _is_repositioning
	_touch_id = -1
	_is_pressed = false
	_is_repositioning = false
	_touch_offset_from_control = Vector2.ZERO
	if was_pressed and action_type == ActionType.TAP and not was_canceled:
		button_pressed.emit(action)
	if was_pressed:
		button_released.emit(action)
		_bridge_on_release(was_repositioning)
	_apply_release_visuals()
	if was_repositioning:
		_save_position()

func _ensure_default_size() -> void:
	if size.x < DEFAULT_SIZE.x or size.y < DEFAULT_SIZE.y:
		size = DEFAULT_SIZE
	custom_minimum_size = DEFAULT_SIZE

func _draw() -> void:
	var center := size * 0.5
	var outer_radius: float = minf(size.x, size.y) * 0.5
	var inner_radius: float = outer_radius - BUTTON_BORDER_WIDTH
	if inner_radius < outer_radius and inner_radius > 0.0:
		draw_circle(center, outer_radius, BUTTON_BORDER_COLOR)
		draw_circle(center, inner_radius, BUTTON_BG_COLOR)
	else:
		draw_circle(center, outer_radius, BUTTON_BG_COLOR)

func _apply_button_style() -> void:
	queue_redraw()

func _load_icon() -> void:
	if _icon_texture_rect == null:
		return
	if action == StringName():
		return
	var icon_path: String = ICON_PREFIX + String(action) + ICON_SUFFIX
	var texture: Texture2D = load(icon_path) as Texture2D
	if texture == null:
		return
	var tint: Color = ACTION_COLORS.get(action, Color(1, 1, 1, 0.9))
	_icon_texture_rect.texture = texture
	_icon_texture_rect.modulate = tint

func _refresh_icon() -> void:
	_load_icon()

func _apply_pressed_visuals() -> void:
	modulate = Color(
		_visual_base_modulate.r * PRESSED_MODULATE.r,
		_visual_base_modulate.g * PRESSED_MODULATE.g,
		_visual_base_modulate.b * PRESSED_MODULATE.b,
		_visual_base_modulate.a
	)
	scale = Vector2(_visual_base_scale.x * PRESSED_SCALE.x, _visual_base_scale.y * PRESSED_SCALE.y)

func _apply_release_visuals() -> void:
	modulate = Color(
		_visual_base_modulate.r * RELEASED_MODULATE.r,
		_visual_base_modulate.g * RELEASED_MODULATE.g,
		_visual_base_modulate.b * RELEASED_MODULATE.b,
		_visual_base_modulate.a * RELEASED_MODULATE.a
	)
	scale = Vector2(_visual_base_scale.x * RELEASED_SCALE.x, _visual_base_scale.y * RELEASED_SCALE.y)

func _is_touch_inside(touch_position: Vector2) -> bool:
	return get_global_rect().has_point(touch_position)

func _save_position() -> void:
	var key_name: StringName = control_name
	if key_name == StringName():
		key_name = action
	if key_name == StringName():
		return
	var store := _get_store_instance()
	if store == null:
		return
	var action_dict := U_InputActions.save_virtual_control_position(String(key_name), position)
	store.dispatch(action_dict)

func _bridge_on_press() -> void:
	var mode := int(ACTION_BRIDGE_MODES.get(action, BRIDGE_MODE_NONE))
	match mode:
		BRIDGE_MODE_INPUT_ACTION:
			_bridge_input_action_pressed(action)
		BRIDGE_MODE_PAUSE_TOGGLE:
			_bridge_pause_pressed()
		_:
			pass

func _bridge_on_release(was_repositioning: bool) -> void:
	if was_repositioning:
		return
	var mode := int(ACTION_BRIDGE_MODES.get(action, BRIDGE_MODE_NONE))
	match mode:
		BRIDGE_MODE_INPUT_ACTION:
			_bridge_input_action_released(action)
		_:
			pass

func _bridge_input_action_pressed(action_name: StringName) -> void:
	if action_name == StringName():
		return
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	Input.action_press(action_name)

func _bridge_input_action_released(action_name: StringName) -> void:
	if action_name == StringName():
		return
	if not InputMap.has_action(action_name):
		return
	Input.action_release(action_name)

func _bridge_pause_pressed() -> void:
	var store := _get_store_instance()
	if store == null:
		return

	var nav_slice := store.get_slice(StringName("navigation"))

	if U_NavigationSelectors.is_paused(nav_slice):
		store.dispatch(U_NavigationActions.close_pause())
	else:
		store.dispatch(U_NavigationActions.open_pause())

func _get_parent_local_position(global_point: Vector2) -> Vector2:
	var parent_canvas := get_parent()
	if parent_canvas is CanvasItem:
		var canvas_item := parent_canvas as CanvasItem
		var inverse := canvas_item.get_global_transform_with_canvas().affine_inverse()
		return inverse * global_point
	return global_point

func _get_store_instance() -> I_StateStore:
	if _store != null and is_instance_valid(_store):
		return _store
	_store = U_DependencyResolution.resolve_state_store(_store, null, self)
	return _store
