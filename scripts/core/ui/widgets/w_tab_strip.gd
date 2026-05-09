extends HBoxContainer
class_name W_TabStrip

signal tab_switched(tab_id: int)

var _tab_buttons: Dictionary = {}
var _tab_order: Array[int] = []
var _active_tab: int = -1
var _button_group: ButtonGroup = ButtonGroup.new()

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func add_tab(tab_id: int, button: Button, label_key: StringName, fallback: String, active_variation: String = "", inactive_variation: String = "") -> void:
	button.toggle_mode = true
	button.button_group = _button_group
	button.pressed.connect(_on_tab_button_pressed.bind(tab_id))
	button.focus_entered.connect(_on_tab_focused.bind(tab_id))
	_tab_buttons[tab_id] = {
		"button": button,
		"key": label_key,
		"fallback": fallback,
		"active_variation": active_variation,
		"inactive_variation": inactive_variation,
	}
	_tab_order.append(tab_id)
	add_child(button)

func switch_to_tab(tab_id: int) -> void:
	if _active_tab == tab_id:
		return
	_active_tab = tab_id
	for key: int in _tab_buttons:
		var entry: Dictionary = _tab_buttons[key]
		var btn: Button = entry.get("button") as Button
		if btn == null:
			continue
		if key == tab_id:
			btn.button_pressed = true
			var active_var: String = entry.get("active_variation", "")
			if active_var != "":
				btn.theme_type_variation = active_var
		else:
			btn.button_pressed = false
			var inactive_var: String = entry.get("inactive_variation", "")
			if inactive_var != "":
				btn.theme_type_variation = inactive_var
	tab_switched.emit(tab_id)

func get_active_tab_id() -> int:
	return _active_tab

func set_tab_visible(tab_id: int, visible: bool) -> void:
	var entry: Dictionary = _tab_buttons.get(tab_id, {})
	var btn: Button = entry.get("button") as Button
	if btn != null:
		btn.visible = visible

func handle_shoulder_input(direction: int) -> void:
	var visible: Array[int] = _get_visible_tab_ids()
	if visible.is_empty():
		return
	var current_index: int = visible.find(_active_tab)
	if current_index < 0:
		current_index = 0
	var next_index: int = wrapi(current_index + direction, 0, visible.size())
	switch_to_tab(visible[next_index])

func get_tab_button(tab_id: int) -> Button:
	var entry: Dictionary = _tab_buttons.get(tab_id, {})
	return entry.get("button") as Button

func get_visible_tab_ids() -> Array[int]:
	return _get_visible_tab_ids()

func _get_visible_tab_ids() -> Array[int]:
	var result: Array[int] = []
	for tab_id: int in _tab_order:
		var entry: Dictionary = _tab_buttons.get(tab_id, {})
		var btn: Button = entry.get("button") as Button
		if btn != null and btn.visible:
			result.append(tab_id)
	return result

func _on_tab_button_pressed(tab_id: int) -> void:
	switch_to_tab(tab_id)

func _on_tab_focused(tab_id: int) -> void:
	switch_to_tab(tab_id)
