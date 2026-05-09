extends RefCounted
class_name U_RebindFocusNavigation


static func configure_focus_neighbors(overlay: Node) -> void:
	# Horizontal neighbors for per-row buttons
	for action in overlay._focusable_actions:
		if not overlay._action_rows.has(action):
			continue
		var row_data: Dictionary = overlay._action_rows[action]
		var add_button: Button = row_data.get("add_button")
		var replace_button: Button = row_data.get("replace_button")
		var reset_button: Button = row_data.get("reset_button")

		var row_buttons: Array[Control] = []
		if add_button != null:
			row_buttons.append(add_button)
		if replace_button != null:
			row_buttons.append(replace_button)
		if reset_button != null:
			row_buttons.append(reset_button)
		if not row_buttons.is_empty():
			U_FocusConfigurator.configure_horizontal_focus(row_buttons, false)

	var add_buttons: Array[Button] = []
	for action in overlay._focusable_actions:
		var row: Dictionary = overlay._action_rows.get(action, {}) as Dictionary
		var add_button: Button = row.get("add_button")
		if add_button != null:
			add_buttons.append(add_button)

	var count: int = add_buttons.size()
	for i in range(count):
		var btn: Button = add_buttons[i]
		if btn == null:
			continue
		if i > 0:
			btn.focus_neighbor_top = btn.get_path_to(add_buttons[i - 1])
		if i < count - 1:
			btn.focus_neighbor_bottom = btn.get_path_to(add_buttons[i + 1])

	var bottom_buttons: Array[Control] = []
	if overlay._reset_button != null:
		bottom_buttons.append(overlay._reset_button)
	if overlay._close_button != null:
		bottom_buttons.append(overlay._close_button)

	if not bottom_buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(bottom_buttons, true)
		if count > 0:
			var last_add: Button = add_buttons[count - 1]
			if last_add != null:
				last_add.focus_neighbor_bottom = last_add.get_path_to(bottom_buttons[0])
				for bottom in bottom_buttons:
					if bottom != null:
						bottom.focus_neighbor_top = bottom.get_path_to(last_add)

static func get_first_focusable(overlay: Node) -> Control:
	if not overlay._focusable_actions.is_empty():
		var first_action: StringName = overlay._focusable_actions[0]
		if overlay._action_rows.has(first_action):
			var row_data: Dictionary = overlay._action_rows[first_action]
			var add_button: Button = row_data.get("add_button")
			if add_button != null:
				return add_button
	return null

static func focus_next_action(overlay: Node) -> void:
	if overlay._focusable_actions.is_empty():
		return
	overlay._row_button_index = 0
	overlay._focused_action_index = (overlay._focused_action_index + 1) % overlay._focusable_actions.size()
	apply_focus(overlay)

static func focus_previous_action(overlay: Node) -> void:
	if overlay._focusable_actions.is_empty():
		return
	overlay._row_button_index = 0
	overlay._focused_action_index -= 1
	if overlay._focused_action_index < 0:
		overlay._focused_action_index = overlay._focusable_actions.size() - 1
	apply_focus(overlay)

static func apply_focus(overlay: Node) -> void:
	if overlay._is_on_bottom_row:
		var buttons: Array[Button] = []
		if overlay._reset_button != null and not overlay._reset_button.disabled:
			buttons.append(overlay._reset_button)
		if overlay._close_button != null and not overlay._close_button.disabled:
			buttons.append(overlay._close_button)

		if buttons.is_empty():
			overlay._is_on_bottom_row = false
		else:
			if overlay._bottom_button_index < 0 or overlay._bottom_button_index >= buttons.size():
				overlay._bottom_button_index = clampi(overlay._bottom_button_index, 0, buttons.size() - 1)
			var button := buttons[overlay._bottom_button_index]
			if button != null:
				button.grab_focus()

		for action_key in overlay._action_rows.keys():
			var data: Dictionary = overlay._action_rows[action_key]
			var row_container: Control = data.get("container")
			if row_container != null:
				row_container.modulate = Color(1, 1, 1, 0.7)
		if overlay._is_on_bottom_row:
			return

	if overlay._focused_action_index < 0 or overlay._focused_action_index >= overlay._focusable_actions.size():
		return

	var action: StringName = overlay._focusable_actions[overlay._focused_action_index]
	if not overlay._action_rows.has(action):
		return

	var row_data: Dictionary = overlay._action_rows[action]
	var add_button: Button = row_data.get("add_button")
	var replace_button: Button = row_data.get("replace_button")
	var reset_button: Button = row_data.get("reset_button")

	var row_buttons: Array[Button] = []
	if add_button != null and not add_button.disabled:
		row_buttons.append(add_button)
	if replace_button != null and not replace_button.disabled:
		row_buttons.append(replace_button)
	if reset_button != null and not reset_button.disabled:
		row_buttons.append(reset_button)

	if not row_buttons.is_empty():
		if overlay._row_button_index < 0 or overlay._row_button_index >= row_buttons.size():
			overlay._row_button_index = clampi(overlay._row_button_index, 0, row_buttons.size() - 1)
		var focused_button := row_buttons[overlay._row_button_index]
		if focused_button != null:
			focused_button.grab_focus()
	else:
		var container: Control = row_data.get("container")
		if container != null:
			container.grab_focus()

	for other_action in overlay._action_rows.keys():
		var other_data: Dictionary = overlay._action_rows[other_action]
		var other_container: Control = other_data.get("container")
		if other_container != null:
			other_container.modulate = Color(1, 1, 1, 1) if other_action == action else Color(1, 1, 1, 0.7)

static func cycle_row_button(overlay: Node, direction: int) -> void:
	if overlay._focused_action_index < 0 or overlay._focused_action_index >= overlay._focusable_actions.size():
		return
	var action: StringName = overlay._focusable_actions[overlay._focused_action_index]
	if not overlay._action_rows.has(action):
		return

	var row_data: Dictionary = overlay._action_rows[action]
	var add_button: Button = row_data.get("add_button")
	var replace_button: Button = row_data.get("replace_button")
	var reset_button: Button = row_data.get("reset_button")

	var row_buttons: Array[Button] = []
	if add_button != null and not add_button.disabled:
		row_buttons.append(add_button)
	if replace_button != null and not replace_button.disabled:
		row_buttons.append(replace_button)
	if reset_button != null and not reset_button.disabled:
		row_buttons.append(reset_button)
	if row_buttons.is_empty():
		return

	overlay._row_button_index += direction
	if overlay._row_button_index < 0:
		overlay._row_button_index = row_buttons.size() - 1
	if overlay._row_button_index >= row_buttons.size():
		overlay._row_button_index = 0

	apply_focus(overlay)

static func ensure_row_visible(overlay: Node, row: Control) -> void:
	if row == null:
		return
	if overlay._scroll == null:
		return
	if not row.is_inside_tree():
		return
	var original_horizontal: float = overlay._scroll.scroll_horizontal
	overlay._scroll.ensure_control_visible(row)
	overlay._scroll.scroll_horizontal = original_horizontal

static func connect_row_focus_handlers(
	overlay: Node,
	row: Control,
	add_button: Button,
	replace_button: Button,
	reset_button: Button
) -> void:
	if row != null:
		row.focus_entered.connect(func() -> void:
			ensure_row_visible(overlay, row)
			if overlay.has_method("_sync_focus_tracking_from_control"):
				overlay.call("_sync_focus_tracking_from_control", row)
		)
	if add_button != null:
		add_button.focus_entered.connect(func() -> void:
			ensure_row_visible(overlay, row)
			if overlay.has_method("_sync_focus_tracking_from_control"):
				overlay.call("_sync_focus_tracking_from_control", add_button)
		)
	if replace_button != null:
		replace_button.focus_entered.connect(func() -> void:
			ensure_row_visible(overlay, row)
			if overlay.has_method("_sync_focus_tracking_from_control"):
				overlay.call("_sync_focus_tracking_from_control", replace_button)
		)
	if reset_button != null:
		reset_button.focus_entered.connect(func() -> void:
			ensure_row_visible(overlay, row)
			if overlay.has_method("_sync_focus_tracking_from_control"):
				overlay.call("_sync_focus_tracking_from_control", reset_button)
		)

static func sync_focus_tracking_from_control(overlay: Node, control: Control) -> void:
	if control == null:
		return

	if control == overlay._reset_button or control == overlay._close_button:
		overlay._is_on_bottom_row = true
		overlay._bottom_button_index = 0 if control == overlay._reset_button else 1
		refresh_action_row_highlight(overlay)
		return

	for index in range(overlay._focusable_actions.size()):
		var action: StringName = overlay._focusable_actions[index]
		var row_data: Dictionary = overlay._action_rows.get(action, {}) as Dictionary
		var row_container := row_data.get("container") as Control
		var add_button := row_data.get("add_button") as Button
		var replace_button := row_data.get("replace_button") as Button
		var reset_button := row_data.get("reset_button") as Button

		if control != row_container and control != add_button and control != replace_button and control != reset_button:
			continue

		overlay._is_on_bottom_row = false
		overlay._focused_action_index = index

		var row_buttons: Array[Button] = []
		if add_button != null and not add_button.disabled:
			row_buttons.append(add_button)
		if replace_button != null and not replace_button.disabled:
			row_buttons.append(replace_button)
		if reset_button != null and not reset_button.disabled:
			row_buttons.append(reset_button)
		overlay._row_button_index = row_buttons.find(control) if (control is Button and row_buttons.has(control)) else 0
		refresh_action_row_highlight(overlay)
		return

static func refresh_action_row_highlight(overlay: Node) -> void:
	for action_key in overlay._action_rows.keys():
		var data: Dictionary = overlay._action_rows[action_key]
		var row_container := data.get("container") as Control
		if row_container == null:
			continue
		if overlay._is_on_bottom_row:
			row_container.modulate = Color(1, 1, 1, 0.7)
		elif overlay._focused_action_index >= 0 \
				and overlay._focused_action_index < overlay._focusable_actions.size() \
				and action_key == overlay._focusable_actions[overlay._focused_action_index]:
			row_container.modulate = Color(1, 1, 1, 1)
		else:
			row_container.modulate = Color(1, 1, 1, 0.7)

static func cycle_bottom_button(overlay: Node, direction: int) -> void:
	var buttons: Array[Button] = []
	if overlay._reset_button != null and not overlay._reset_button.disabled:
		buttons.append(overlay._reset_button)
	if overlay._close_button != null and not overlay._close_button.disabled:
		buttons.append(overlay._close_button)
	if buttons.is_empty():
		return

	overlay._bottom_button_index += direction
	if overlay._bottom_button_index < 0:
		overlay._bottom_button_index = buttons.size() - 1
	if overlay._bottom_button_index >= buttons.size():
		overlay._bottom_button_index = 0

	apply_focus(overlay)

static func navigate(overlay: Node, direction: StringName) -> void:
	if overlay._is_capturing:
		return

	match direction:
		StringName("ui_up"):
			if overlay._is_on_bottom_row:
				overlay._is_on_bottom_row = false
				if overlay._focusable_actions.is_empty():
					return
				if overlay._focused_action_index < 0 or overlay._focused_action_index >= overlay._focusable_actions.size():
					overlay._focused_action_index = overlay._focusable_actions.size() - 1
				apply_focus(overlay)
			else:
				focus_previous_action(overlay)
		StringName("ui_down"):
			if overlay._is_on_bottom_row:
				return
			if overlay._focusable_actions.is_empty():
				if overlay._reset_button != null or overlay._close_button != null:
					overlay._is_on_bottom_row = true
					overlay._bottom_button_index = 0
					apply_focus(overlay)
				return
			if overlay._focused_action_index < 0:
				overlay._focused_action_index = 0
				apply_focus(overlay)
				return
			if overlay._focused_action_index < overlay._focusable_actions.size() - 1:
				focus_next_action(overlay)
			else:
				if overlay._reset_button != null or overlay._close_button != null:
					overlay._is_on_bottom_row = true
					overlay._bottom_button_index = 0
					apply_focus(overlay)
		StringName("ui_left"):
			if overlay._is_on_bottom_row:
				cycle_bottom_button(overlay, -1)
			else:
				cycle_row_button(overlay, -1)
		StringName("ui_right"):
			if overlay._is_on_bottom_row:
				cycle_bottom_button(overlay, 1)
			else:
				cycle_row_button(overlay, 1)
