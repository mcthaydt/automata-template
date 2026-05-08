extends Control
class_name W_MenuButtonList

## Configures focus, theme tokens, and localization for a vertical button list.
##
## Buttons remain wherever they are in the scene tree; this widget tracks
## references and configures them without reparenting.

const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _buttons: Array[Button] = []
var _label_keys: Dictionary = {}
var _label_fallbacks: Dictionary = {}

func add_existing_button(button: Button, key: StringName, fallback: String, callback: Callable) -> void:
	if button == null:
		return
	if not _buttons.has(button):
		_buttons.append(button)
	_label_keys[button] = key
	_label_fallbacks[button] = fallback
	if callback.is_valid() and button.pressed.get_connections().is_empty():
		button.pressed.connect(callback)

func get_buttons() -> Array[Button]:
	return _buttons.duplicate()

func apply_theme_tokens(config: Variant) -> void:
	var typed_config = config as RS_UI_THEME_CONFIG
	if typed_config == null:
		return
	for button in _buttons:
		button.add_theme_font_size_override("font_size", typed_config.section_header)

func localize_labels() -> void:
	for button in _buttons:
		var key: StringName = _label_keys.get(button, StringName())
		if key != StringName():
			var fallback: String = _label_fallbacks.get(button, str(key))
			button.text = U_LOCALIZATION_UTILS.localize_with_fallback(key, fallback)

func configure_vertical_focus(wrap: bool = true) -> void:
	if _buttons.is_empty():
		return
	var controls: Array[Control] = []
	controls.assign(_buttons)
	U_FOCUS_CONFIGURATOR.configure_vertical_focus(controls, wrap)
