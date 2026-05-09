extends RefCounted
class_name U_OverlayCloseNavigation

static func close_or_return_to_settings(overlay: Node, store: Variant) -> void:
	if store == null:
		_transition_back_to_settings_scene(overlay)
		return
	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)
	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	elif shell == StringName("main_menu"):
		_transition_back_to_settings_scene(overlay)
	else:
		store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_panel")))

static func transition_back_to_settings_scene(overlay: Node) -> void:
	_transition_back_to_settings_scene(overlay)

static func _transition_back_to_settings_scene(overlay: Node) -> void:
	if overlay == null or not overlay.has_method("get_store"):
		return
	var store = overlay.get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_panel"), "fade", 2))
