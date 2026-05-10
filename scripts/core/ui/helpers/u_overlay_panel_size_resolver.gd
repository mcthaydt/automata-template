extends RefCounted
class_name U_OverlayPanelSizeResolver

const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

static func resolve(viewport_size: Vector2, max_size: Vector2, config: RS_UI_THEME_CONFIG) -> Vector2:
	var margin := float(config.margin_outer) if config != null else 0.0
	var available_width := maxf(viewport_size.x - margin * 2.0, 1.0)
	var available_height := maxf(viewport_size.y - margin * 2.0, 1.0)
	return Vector2(minf(max_size.x, available_width), minf(max_size.y, available_height))

static func get_visible_viewport_size(node: Node, fallback: Vector2) -> Vector2:
	var viewport := node.get_viewport() if node != null else null
	if viewport == null:
		return fallback
	return viewport.get_visible_rect().size

static func get_theme_config(config: Resource) -> RS_UI_THEME_CONFIG:
	var typed_config := config as RS_UI_THEME_CONFIG
	if typed_config == null:
		typed_config = RS_UI_THEME_CONFIG.new()
	typed_config.ensure_runtime_defaults()
	return typed_config
