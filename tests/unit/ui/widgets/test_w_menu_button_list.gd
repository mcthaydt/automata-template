extends GutTest

const W_MenuButtonList := preload("res://scripts/core/ui/widgets/w_menu_button_list.gd")

func test_adds_buttons_vertically() -> void:
	var list := W_MenuButtonList.new()
	list.add_button(&"play", "Play", Callable())
	list.add_button(&"quit", "Quit", Callable())
	add_child_autofree(list)
	await wait_process_frames(1)
	var buttons: Array[Button] = list.get_buttons()
	assert_eq(buttons.size(), 2)
	assert_eq(buttons[0].text, "Play")

func test_focuses_first_button() -> void:
	var list := W_MenuButtonList.new()
	list.add_button(&"a", "A", Callable())
	list.add_button(&"b", "B", Callable())
	add_child_autofree(list)
	await wait_process_frames(1)
	var buttons: Array[Button] = list.get_buttons()
	assert_true(buttons[0].has_focus())

func test_callback_invoked_on_press() -> void:
	var list := W_MenuButtonList.new()
	var invoked: Dictionary = {"value": false}
	list.add_button(&"test", "Test", func() -> void: invoked["value"] = true)
	add_child_autofree(list)
	await wait_process_frames(1)
	var buttons: Array[Button] = list.get_buttons()
	buttons[0].pressed.emit()
	await wait_process_frames(1)
	assert_true(invoked["value"])

func test_configure_vertical_focus_sets_neighbors() -> void:
	var list := W_MenuButtonList.new()
	list.add_button(&"a", "A", Callable())
	list.add_button(&"b", "B", Callable())
	list.add_button(&"c", "C", Callable())
	add_child_autofree(list)
	await wait_process_frames(1)
	list.configure_vertical_focus(true)
	await wait_process_frames(1)
	var buttons: Array[Button] = list.get_buttons()
	assert_ne(buttons[0].focus_neighbor_bottom, NodePath(""), "First button should have bottom neighbor")
	assert_ne(buttons[2].focus_neighbor_top, NodePath(""), "Last button should have top neighbor")
