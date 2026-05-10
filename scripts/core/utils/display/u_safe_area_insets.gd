extends RefCounted
class_name U_SafeAreaInsets

## Pure safe-area inset math.
##
## Returns a Rect2 where position is left/top inset and size is right/bottom
## inset. Callers provide usable/window rects; this helper does not touch
## DisplayServer.

static func compute(usable_rect: Rect2, window_rect: Rect2) -> Rect2:
	var left: float = maxf(usable_rect.position.x - window_rect.position.x, 0.0)
	var top: float = maxf(usable_rect.position.y - window_rect.position.y, 0.0)
	var right: float = maxf(window_rect.end.x - usable_rect.end.x, 0.0)
	var bottom: float = maxf(window_rect.end.y - usable_rect.end.y, 0.0)
	return Rect2(Vector2(left, top), Vector2(right, bottom))

static func apply_to_rect(window_rect: Rect2, insets: Rect2) -> Rect2:
	var position := window_rect.position + insets.position
	var size := Vector2(
		maxf(window_rect.size.x - insets.position.x - insets.size.x, 0.0),
		maxf(window_rect.size.y - insets.position.y - insets.size.y, 0.0)
	)
	return Rect2(position, size)
