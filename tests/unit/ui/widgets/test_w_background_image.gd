extends GutTest

const W_BackgroundImage := preload("res://scripts/core/ui/widgets/w_background_image.gd")

func test_setup_from_preset_creates_texture_rect() -> void:
	var tr := W_BackgroundImage.setup_from_preset("retro_grid")
	assert_not_null(tr, "retro_grid should map to a valid texture")
	assert_eq(tr.name, "BackgroundImage")
	assert_eq(tr.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	tr.queue_free()

func test_setup_from_preset_invalid_returns_null() -> void:
	var tr := W_BackgroundImage.setup_from_preset("nonexistent")
	assert_null(tr, "Invalid preset should return null")

func test_configure_existing_sets_properties() -> void:
	var tr := TextureRect.new()
	tr.name = "ExistingBg"
	W_BackgroundImage.configure_existing(tr)
	assert_eq(tr.z_index, -1)
	assert_eq(tr.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(tr.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	tr.queue_free()
