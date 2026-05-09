extends GutTest

const W_SaveSlotThumbnailLoader := preload("res://scripts/core/ui/widgets/w_save_slot_thumbnail_loader.gd")

func test_load_async_uses_placeholder_when_path_empty() -> void:
	var rect := TextureRect.new()
	add_child_autofree(rect)
	var placeholder := PlaceholderTexture2D.new()
	W_SaveSlotThumbnailLoader.load_async(rect, "", placeholder)
	assert_eq(rect.texture, placeholder)

func test_load_async_uses_placeholder_when_file_missing() -> void:
	var rect := TextureRect.new()
	add_child_autofree(rect)
	var placeholder := PlaceholderTexture2D.new()
	W_SaveSlotThumbnailLoader.load_async(rect, "user://missing_thumb.png", placeholder)
	assert_eq(rect.texture, placeholder)

func test_poll_pending_removes_invalid_texture_rect() -> void:
	var pending: Dictionary = {null: "res://missing.png"}
	var completed := W_SaveSlotThumbnailLoader.poll_pending(pending, PlaceholderTexture2D.new())
	assert_eq(completed.size(), 1)
	assert_true(pending.is_empty())
