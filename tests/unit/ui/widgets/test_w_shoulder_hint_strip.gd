extends GutTest

const W_ShoulderHintStrip := preload("res://scripts/core/ui/widgets/w_shoulder_hint_strip.gd")

func test_create_row_returns_hbox() -> void:
	var row := W_ShoulderHintStrip.create_row()
	assert_not_null(row)
	assert_eq(row.name, "ShoulderHintRow")
	assert_eq(row.alignment, BoxContainer.ALIGNMENT_CENTER)
	row.queue_free()

func test_populate_adds_five_children() -> void:
	var row := W_ShoulderHintStrip.create_row()
	add_child_autofree(row)
	W_ShoulderHintStrip.populate(row, "LB", "RB")
	await wait_process_frames(1)
	assert_eq(row.get_child_count(), 5, "Row should have spacer, LB, spacer, RB, spacer")
	assert_eq(row.get_child(1).text, "LB")
	assert_eq(row.get_child(3).text, "RB")
