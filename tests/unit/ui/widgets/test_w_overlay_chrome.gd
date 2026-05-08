extends GutTest

const W_OverlayChrome := preload("res://scripts/core/ui/widgets/w_overlay_chrome.gd")

func test_creates_close_button() -> void:
	var chrome := W_OverlayChrome.new()
	var close := chrome.get_close_button()
	assert_not_null(close, "Chrome should create a close button")
	assert_eq(close.name, "CloseButton")
	chrome.queue_free()

func test_emits_close_pressed() -> void:
	var chrome := W_OverlayChrome.new()
	var emitted: Dictionary = {"value": false}
	chrome.close_pressed.connect(func() -> void: emitted["value"] = true)
	chrome.close_pressed.emit()
	assert_true(emitted["value"])
	chrome.queue_free()

func test_get_chrome_row_returns_hbox() -> void:
	var chrome := W_OverlayChrome.new()
	var row := chrome.get_chrome_row()
	assert_not_null(row, "Chrome row should exist")
	assert_eq(row.name, "PanelChrome")
	chrome.queue_free()

func test_close_button_has_correct_properties() -> void:
	var chrome := W_OverlayChrome.new()
	var close := chrome.get_close_button()
	assert_eq(close.text, "X")
	assert_true(close.flat)
	assert_eq(close.focus_mode, Control.FOCUS_NONE)
	assert_eq(close.custom_minimum_size, Vector2(44, 44))
	chrome.queue_free()

func test_chrome_row_expands_horizontally() -> void:
	var chrome := W_OverlayChrome.new()
	var row := chrome.get_chrome_row()
	assert_eq(row.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	chrome.queue_free()
