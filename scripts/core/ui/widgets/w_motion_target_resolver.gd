class_name W_MotionTargetResolver

## Static helper for resolving the motion-animation target node in menu screens.
##
## Encapsulates the tree-walk logic that finds either an explicit target,
## a CenterContainer/PanelContainer combo, or falls back to the screen itself.

static func resolve(screen: Control, explicit_path: NodePath) -> Node:
	var explicit := _resolve_explicit(screen, explicit_path)
	if explicit != null:
		return explicit

	var center := _resolve_center_panel(screen)
	if center != null:
		return center

	return screen

static func _resolve_explicit(screen: Control, path: NodePath) -> Node:
	if path == NodePath():
		return null
	return screen.get_node_or_null(path)

static func _resolve_center_panel(screen: Control) -> Control:
	if not _has_backdrop_layer(screen):
		return null
	var center := _find_center_container_with_panel(screen)
	if center == null:
		return null
	return center

static func _has_backdrop_layer(screen: Control) -> bool:
	return _resolve_background(screen) != null

static func _resolve_background(screen: Control) -> Control:
	var bg_image := screen.get_node_or_null("BackgroundImage") as TextureRect
	if bg_image != null:
		return bg_image
	var background := screen.get_node_or_null("Background") as ColorRect
	if background != null:
		return background
	var overlay_background := screen.get_node_or_null("OverlayBackground") as ColorRect
	if overlay_background != null:
		return overlay_background
	return screen.get_node_or_null("ColorRect") as ColorRect

static func _find_center_container_with_panel(root: Node) -> CenterContainer:
	for child in root.get_children():
		if not (child is Node):
			continue
		var child_node := child as Node
		if child_node is CenterContainer:
			var center := child_node as CenterContainer
			if _find_panel_descendant(center) != null:
				return center
		var nested := _find_center_container_with_panel(child_node)
		if nested != null:
			return nested
	return null

static func _find_panel_descendant(root: Node) -> PanelContainer:
	if root is PanelContainer:
		return root as PanelContainer
	for child in root.get_children():
		if not (child is Node):
			continue
		var child_node := child as Node
		var panel := _find_panel_descendant(child_node)
		if panel != null:
			return panel
	return null