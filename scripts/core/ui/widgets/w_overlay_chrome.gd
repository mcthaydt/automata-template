extends Control
class_name W_OverlayChrome

## Reusable chrome row for overlay panels.
##
## Provides a horizontal chrome row (HBoxContainer) with a close button
## wrapped in a MarginContainer. Consumers can add additional children
## (tabs, spacers, shoulder hints) into the chrome row via get_chrome_row().
##
## The close button emits close_pressed when pressed.

signal close_pressed

var _panel_chrome: HBoxContainer = null
var _close_button: Button = null
var _close_button_margin: MarginContainer = null

func _init() -> void:
	_panel_chrome = HBoxContainer.new()
	_panel_chrome.name = "PanelChrome"
	_panel_chrome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_panel_chrome)

	_close_button_margin = MarginContainer.new()
	_close_button_margin.name = "CloseButtonMargin"
	_close_button_margin.size_flags_horizontal = Control.SIZE_SHRINK_END
	_panel_chrome.add_child(_close_button_margin)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.flat = true
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.custom_minimum_size = Vector2(44, 44)
	_close_button.pressed.connect(func() -> void: close_pressed.emit())
	_close_button_margin.add_child(_close_button)

func get_chrome_row() -> HBoxContainer:
	return _panel_chrome

func get_close_button() -> Button:
	return _close_button

func get_close_button_margin() -> MarginContainer:
	return _close_button_margin
