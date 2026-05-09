class_name W_SettingsFocusConfigurator

## Pure helper that collects focusable controls from a tab and configures
## both vertical wrapping and inline (left/right) neighbor pairs.
##
## Extracted from the repetitive ~25-line _configure_focus_neighbors() blocks
## in every settings tab script.

const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")

static func configure_vertical(tab: Control, control_getters: Array[Callable]) -> void:
	var visible: Array[Control] = []
	for getter in control_getters:
		var ctrl := getter.call() as Control
		if ctrl != null and ctrl.focus_mode != Control.FOCUS_NONE and ctrl.visible:
			visible.append(ctrl)
	if not visible.is_empty():
		U_FOCUS_CONFIGURATOR.configure_vertical_focus(visible, true)

static func configure_inline_pairs(tab: Control, pairs: Array[Array]) -> void:
	for pair in pairs:
		if pair.size() < 2:
			continue
		var left: Control = pair[0]
		var right: Control = pair[1]
		if left != null and right != null and left.is_inside_tree() and right.is_inside_tree():
			left.focus_neighbor_right = left.get_path_to(right)
			right.focus_neighbor_left = right.get_path_to(left)
