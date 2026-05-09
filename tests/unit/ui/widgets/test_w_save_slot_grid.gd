extends GutTest

const W_SaveSlotGrid := preload("res://scripts/core/ui/widgets/w_save_slot_grid.gd")
const W_SaveSlotThumbnailLoader := preload("res://scripts/core/ui/widgets/w_save_slot_thumbnail_loader.gd")
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

func test_bind_slot_container_removes_auto_created_container() -> void:
	var grid := W_SaveSlotGrid.new()
	var external := VBoxContainer.new()
	add_child_autofree(grid)
	add_child_autofree(external)
	grid.bind_slot_container(external)

	assert_null(grid.get_node_or_null("SlotListContainer"), "Auto-created slot list should not remain orphaned after binding external container")

func test_thumbnail_loader_erases_freed_pending_key() -> void:
	var rect := TextureRect.new()
	var pending := {rect: "res://missing_thumbnail_for_test.png"}
	rect.free()

	W_SaveSlotThumbnailLoader.poll_pending(pending, null)

	assert_true(pending.is_empty(), "Freed TextureRect keys should be removed from pending loads")

func test_thumbnail_loader_uses_placeholder_for_res_path_image_fallback() -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var placeholder := ImageTexture.create_from_image(image)

	var texture := W_SaveSlotThumbnailLoader._load_texture_from_image("res://resources/core/ui/tex_save_slot_placeholder.png", placeholder)

	assert_eq(texture, placeholder, "res:// threaded-load failures should not fall back to filesystem image loading")

func _slot(slot_id: StringName, exists: bool) -> Dictionary:
	return {
		"slot_id": slot_id,
		"exists": exists,
		"timestamp": "2025-12-26T14:30:00Z",
		"area_name": "Test Area",
		"playtime_seconds": 3723,
		"thumbnail_path": ""
	}
