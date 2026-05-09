extends GutTest

const W_SaveSlotGrid := preload("res://scripts/core/ui/widgets/w_save_slot_grid.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

func test_set_slots_creates_slot_rows() -> void:
	var grid := W_SaveSlotGrid.new()
	add_child_autofree(grid)
	grid.set_slots([_slot(&"slot_01", true)], &"save", null)
	assert_not_null(grid.get_node_or_null("SlotListContainer/Slot_slot_01"))

func test_empty_load_slot_disables_main_button() -> void:
	var grid := W_SaveSlotGrid.new()
	add_child_autofree(grid)
	grid.set_slots([_slot(&"slot_01", false)], &"load", null)
	var button := grid.get_node("SlotListContainer/Slot_slot_01/MainButton") as Button
	assert_true(button.disabled)

func test_save_mode_empty_slot_keeps_main_button_enabled() -> void:
	var grid := W_SaveSlotGrid.new()
	add_child_autofree(grid)
	grid.set_slots([_slot(&"slot_01", false)], &"save", null)
	var button := grid.get_node("SlotListContainer/Slot_slot_01/MainButton") as Button
	assert_false(button.disabled)

func test_delete_button_hidden_for_autosave() -> void:
	var grid := W_SaveSlotGrid.new()
	add_child_autofree(grid)
	grid.set_slots([_slot(&"autosave", true)], &"save", null)
	var button := grid.get_node("SlotListContainer/Slot_autosave/DeleteButton") as Button
	assert_false(button.visible)

func test_set_buttons_enabled_toggles_slot_buttons() -> void:
	var grid := W_SaveSlotGrid.new()
	add_child_autofree(grid)
	grid.set_slots([_slot(&"slot_01", true)], &"save", null)
	grid.set_buttons_enabled(false)
	var main := grid.get_node("SlotListContainer/Slot_slot_01/MainButton") as Button
	var delete := grid.get_node("SlotListContainer/Slot_slot_01/DeleteButton") as Button
	assert_true(main.disabled)
	assert_true(delete.disabled)

func test_theme_tokens_apply_to_slot_row() -> void:
	var grid := W_SaveSlotGrid.new()
	var config := RS_UI_THEME_CONFIG.new()
	config.separation_compact = 11
	config.section_header = 17
	add_child_autofree(grid)
	grid.set_slots([_slot(&"slot_01", true)], &"save", config)
	var row := grid.get_node("SlotListContainer/Slot_slot_01") as HBoxContainer
	var button := row.get_node("MainButton") as Button
	assert_eq(row.get_theme_constant(&"separation"), 11)
	assert_eq(button.get_theme_font_size(&"font_size"), 17)

func _slot(slot_id: StringName, exists: bool) -> Dictionary:
	return {
		"slot_id": slot_id,
		"exists": exists,
		"timestamp": "2025-12-26T14:30:00Z",
		"area_name": "Test Area",
		"playtime_seconds": 3723,
		"thumbnail_path": ""
	}
