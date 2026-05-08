extends VBoxContainer
class_name W_MenuButtonList

const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")

var _buttons: Array[Button] = []

func _ready() -> void:
	call_deferred("_apply_initial_focus")

func _apply_initial_focus() -> void:
	if _buttons.is_empty():
		return
	var first: Button = _buttons[0]
	if first != null and first.is_inside_tree():
		first.grab_focus()

func add_button(key: StringName, fallback: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = String(key).replace(".", "_")
	button.text = fallback
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if callback.is_valid():
		button.pressed.connect(callback)
	add_child(button)
	_buttons.append(button)

func get_buttons() -> Array[Button]:
	return _buttons.duplicate()

func configure_vertical_focus(wrap: bool = true) -> void:
	if _buttons.is_empty():
		return
	var controls: Array[Control] = []
	controls.assign(_buttons)
	U_FOCUS_CONFIGURATOR.configure_vertical_focus(controls, wrap)
