extends GutTest

const UI_KeyboardMouseSettingsTab := preload("res://scripts/core/ui/settings/ui_keyboard_mouse_settings_tab.gd")

func test_keyboard_mouse_settings_tab_extends_vboxcontainer():
	var tab := UI_KeyboardMouseSettingsTab.new()
	assert_true(tab is VBoxContainer, "K/M settings tab should extend VBoxContainer")
	tab.free()

func test_setup_builder_creates_reset_and_rebind_buttons():
	var tab := UI_KeyboardMouseSettingsTab.new()

	tab._setup_builder()
	tab._builder.build()

	assert_not_null(_find_child_by_name(tab, "ResetButton"), "Reset button should be created")
	assert_not_null(_find_child_by_name(tab, "RebindButton"), "Rebind button should be created")
	tab.free()

func test_setup_builder_does_not_create_blank_apply_or_cancel_buttons():
	var tab := UI_KeyboardMouseSettingsTab.new()

	tab._setup_builder()
	tab._builder.build()

	assert_null(_find_child_by_name(tab, "ApplyButton"), "K/M tab should not create a blank Apply button")
	assert_null(_find_child_by_name(tab, "CancelButton"), "K/M tab should not create a blank Cancel button")
	tab.free()

func test_focus_chain_wraps_through_sliders_toggle_reset_and_rebind():
	var tab := UI_KeyboardMouseSettingsTab.new()
	tab._setup_builder()
	tab._builder.build()
	tab._capture_control_references()
	tab._configure_focus_neighbors()

	var first := _find_child_by_name(tab, "MouseSensitivitySlider") as Control
	var last := _find_child_by_name(tab, "RebindButton") as Control
	var reset := _find_child_by_name(tab, "ResetButton") as Control

	assert_not_null(first, "Mouse sensitivity slider should be in focus chain")
	assert_not_null(reset, "Reset button should be in focus chain")
	assert_not_null(last, "Rebind button should be in focus chain")
	assert_eq(first.get_node_or_null(first.focus_neighbor_top), last, "Up from first K/M control should wrap to rebind")
	assert_eq(last.get_node_or_null(last.focus_neighbor_bottom), first, "Down from rebind should wrap to first K/M control")
	assert_eq(reset.get_node_or_null(reset.focus_neighbor_bottom), last, "Down from reset should continue to rebind")
	tab.free()

func _find_child_by_name(parent: Node, child_name: String) -> Node:
	for child in parent.get_children():
		if child.name == child_name:
			return child
		var result := _find_child_by_name(child, child_name)
		if result != null:
			return result
	return null
