extends GutTest

const W_FocusNavigator := preload("res://scripts/core/ui/widgets/w_focus_navigator.gd")

func test_navigate_down_moves_focus() -> void:
	var screen := Control.new()
	var a := Button.new()
	var b := Button.new()
	a.focus_mode = Control.FOCUS_ALL
	b.focus_mode = Control.FOCUS_ALL
	screen.add_child(a)
	screen.add_child(b)
	a.focus_neighbor_bottom = a.get_path_to(b)
	b.focus_neighbor_top = b.get_path_to(a)
	add_child_autofree(screen)
	a.grab_focus()
	await wait_process_frames(1)

	W_FocusNavigator.navigate(screen, StringName("ui_down"))
	await wait_process_frames(1)
	assert_eq(screen.get_viewport().gui_get_focus_owner(), b)

func test_navigate_skips_invisible() -> void:
	var screen := Control.new()
	var a := Button.new()
	var b := Button.new()
	a.focus_mode = Control.FOCUS_ALL
	b.focus_mode = Control.FOCUS_ALL
	b.visible = false
	screen.add_child(a)
	screen.add_child(b)
	a.focus_neighbor_bottom = a.get_path_to(b)
	add_child_autofree(screen)
	a.grab_focus()
	await wait_process_frames(1)

	W_FocusNavigator.navigate(screen, StringName("ui_down"))
	await wait_process_frames(1)
	assert_eq(screen.get_viewport().gui_get_focus_owner(), a, "Focus should stay on A because B is invisible")
