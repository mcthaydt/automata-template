extends RefCounted
class_name W_OverlayChrome

signal close_pressed

var _close_button: Button = null
var _panel_chrome: HBoxContainer = null

func _init() -> void:
	_panel_chrome = HBoxContainer.new()
	_panel_chrome.name = "PanelChrome"
	_panel_chrome.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.flat = true
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.custom_minimum_size = Vector2(44, 44)
	_close_button.pressed.connect(func() -> void: close_pressed.emit())

func get_close_button() -> Button:
	return _close_button

func get_chrome_row() -> HBoxContainer:
	return _panel_chrome
