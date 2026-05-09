class_name W_ShoulderHintStrip

## Static helper to create shoulder-hint label rows that flank tab strips.
##
## Extracted from W_TabStrip / UI_SettingsPanel to keep chrome layout reusable.

static func create_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ShoulderHintRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row

static func create_hint(text: String) -> Label:
	var hint := Label.new()
	hint.text = text
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return hint

static func populate(row: HBoxContainer, left_text: String, right_text: String) -> void:
	if row == null:
		return
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var spacer_left := Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb := create_hint(left_text)
	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rb := create_hint(right_text)
	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer_left)
	row.add_child(lb)
	row.add_child(mid_spacer)
	row.add_child(rb)
	row.add_child(spacer_right)
