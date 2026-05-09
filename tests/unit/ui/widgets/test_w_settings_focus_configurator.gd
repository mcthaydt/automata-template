extends GutTest

const W_SettingsFocusConfigurator := preload("res://scripts/core/ui/widgets/w_settings_focus_configurator.gd")
const U_FocusConfigurator := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")

func test_configure_vertical_with_mixed_controls() -> void:
	var tab := Control.new()
	var a := Button.new()
	var b := Button.new()
	var hidden := Button.new()
	hidden.visible = false
	var no_focus := Button.new()
	no_focus.focus_mode = Control.FOCUS_NONE
	tab.add_child(a)
	tab.add_child(b)
	tab.add_child(hidden)
	tab.add_child(no_focus)
	add_child_autofree(tab)
	await wait_process_frames(1)

	W_SettingsFocusConfigurator.configure_vertical(tab, [
		func() -> Control: return a,
		func() -> Control: return b,
		func() -> Control: return hidden,
		func() -> Control: return no_focus,
	])
	await wait_process_frames(1)
	# Only a and b should have neighbors configured
	assert_ne(a.focus_neighbor_bottom, NodePath(""), "A should have bottom neighbor")
	assert_ne(b.focus_neighbor_top, NodePath(""), "B should have top neighbor")

func test_configure_inline_pairs() -> void:
	var tab := Control.new()
	var left := Button.new()
	var right := Button.new()
	tab.add_child(left)
	tab.add_child(right)
	add_child_autofree(tab)
	await wait_process_frames(1)

	W_SettingsFocusConfigurator.configure_inline_pairs(tab, [[left, right]])
	await wait_process_frames(1)
	assert_eq(left.focus_neighbor_right, left.get_path_to(right))
	assert_eq(right.focus_neighbor_left, right.get_path_to(left))

func test_configure_vertical_empty_does_not_crash() -> void:
	var tab := Control.new()
	add_child_autofree(tab)
	await wait_process_frames(1)
	# Should not crash with empty array
	W_SettingsFocusConfigurator.configure_vertical(tab, [])
	pass_test("Empty control list should not crash")
