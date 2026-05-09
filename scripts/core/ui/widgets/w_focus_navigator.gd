class_name W_FocusNavigator

## Pure helper for resolving focus neighbor navigation.
##
## Does NOT handle sound arming or grab_focus() — the caller (screen controller)
## retains ownership of side effects.  This keeps the widget stateless and
## avoids fragile cross-object method reflection.

static func find_next_focus(screen: Control, direction: StringName) -> Control:
	var viewport := screen.get_viewport()
	var focused := viewport.gui_get_focus_owner() if viewport != null else null
	if focused == null:
		return null
	if not screen.is_ancestor_of(focused):
		return null

	match direction:
		"ui_up":
			if focused.focus_neighbor_top != NodePath():
				return focused.get_node_or_null(focused.focus_neighbor_top) as Control
		"ui_down":
			if focused.focus_neighbor_bottom != NodePath():
				return focused.get_node_or_null(focused.focus_neighbor_bottom) as Control
		"ui_left":
			if focused.focus_neighbor_left != NodePath():
				return focused.get_node_or_null(focused.focus_neighbor_left) as Control
		"ui_right":
			if focused.focus_neighbor_right != NodePath():
				return focused.get_node_or_null(focused.focus_neighbor_right) as Control
	return null
