extends GutTest

## Tests for display settings tab focus navigation wrapping


var _store: M_StateStore
var _tab: Control

func before_each() -> void:
	_store = M_StateStore.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

func after_each() -> void:
	U_ServiceLocator.clear()
	if _tab != null and is_instance_valid(_tab):
		_tab.queue_free()
		_tab = null

func test_focus_wraps_from_first_to_last_control() -> void:
	# GIVEN: Display settings tab with multiple focusable controls
	var scene := load("res://scenes/core/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# Find first and last focusable controls
	var first_control := _find_first_focusable(_tab)
	var last_control := _find_last_focusable(_tab)

	assert_not_null(first_control, "Should have a first focusable control")
	assert_not_null(last_control, "Should have a last focusable control")

	# WHEN: Focus is on first control and user presses up
	# THEN: Focus should wrap to last control
	var up_neighbor := first_control.get_focus_neighbor(SIDE_TOP)
	if up_neighbor != NodePath():
		var up_node := first_control.get_node_or_null(up_neighbor)
		assert_eq(up_node, last_control, "Up from first control should focus last control (wrapping)")

func test_focus_wraps_from_last_to_first_control() -> void:
	# GIVEN: Display settings tab with multiple focusable controls
	var scene := load("res://scenes/core/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# Find first and last focusable controls
	var first_control := _find_first_focusable(_tab)
	var last_control := _find_last_focusable(_tab)

	assert_not_null(first_control, "Should have a first focusable control")
	assert_not_null(last_control, "Should have a last focusable control")

	# WHEN: Focus is on last control and user presses down
	# THEN: Focus should wrap to first control
	var down_neighbor := last_control.get_focus_neighbor(SIDE_BOTTOM)
	if down_neighbor != NodePath():
		var down_node := last_control.get_node_or_null(down_neighbor)
		assert_eq(down_node, first_control, "Down from last control should focus first control (wrapping)")

func test_display_focus_chain_reconfigures_after_dependency_visibility_changes() -> void:
	var scene := load("res://scenes/core/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	var post_processing_toggle := _tab.find_child("PostProcessingToggle", true, false) as CheckBox
	var post_processing_preset := _tab.find_child("PostProcessPresetOption", true, false) as OptionButton
	assert_not_null(post_processing_toggle, "Post processing toggle should exist")
	assert_not_null(post_processing_preset, "Post processing preset option should exist")

	post_processing_toggle.button_pressed = false
	_tab._set_control_group_enabled(post_processing_preset, false)
	_tab._configure_focus_neighbors()

	var focusables := _get_all_focusables(_tab)
	var first_control := focusables[0]
	var last_control := focusables[focusables.size() - 1]
	assert_eq(first_control.get_node_or_null(first_control.focus_neighbor_top), last_control, "Up from first visible display control should wrap after dependency changes")
	assert_eq(last_control.get_node_or_null(last_control.focus_neighbor_bottom), first_control, "Down from last visible display control should wrap after dependency changes")
	assert_false(focusables.has(post_processing_preset), "Disabled dependency control should not remain in display focus chain")

func _find_first_focusable(root: Node) -> Control:
	var focusables := _get_all_focusables(root)
	if focusables.size() > 0:
		return focusables[0]
	return null

func _find_last_focusable(root: Node) -> Control:
	var focusables := _get_all_focusables(root)
	if focusables.size() > 0:
		return focusables[focusables.size() - 1]
	return null

func _get_all_focusables(root: Node) -> Array[Control]:
	var focusables: Array[Control] = []
	_collect_focusables(root, focusables)
	return focusables

func _collect_focusables(node: Node, out: Array[Control]) -> void:
	if node is Control and node.focus_mode == Control.FOCUS_ALL:
		out.append(node as Control)
	for child in node.get_children():
		if child is Node:
			_collect_focusables(child, out)
