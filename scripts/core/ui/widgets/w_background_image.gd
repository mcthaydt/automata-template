class_name W_BackgroundImage

## Static helper for provisioning and configuring menu background TextureRects.
##
## Centralizes the preset→texture mapping and configuration so it is not
## duplicated across BaseMenuScreen, UI_LoadingScreen, and any future screens.

const BACKGROUND_IMAGE_BY_PRESET := {
	"retro_grid":      "res://assets/core/textures/tex_bg_menu_main.png",
	"scanline_drift":  "res://assets/core/textures/tex_bg_menu_pause.png",
	"arcade_noise":    "res://assets/core/textures/tex_bg_game_over.png",
}

static func setup_from_preset(preset: String) -> TextureRect:
	if not BACKGROUND_IMAGE_BY_PRESET.has(preset):
		return null
	var texture := load(BACKGROUND_IMAGE_BY_PRESET[preset]) as Texture2D
	if texture == null:
		return null
	var tr := TextureRect.new()
	tr.name = "BackgroundImage"
	tr.texture = texture
	_configure(tr)
	return tr

static func configure_existing(tr: TextureRect) -> void:
	if tr == null:
		return
	_configure(tr)

static func _configure(tr: TextureRect) -> void:
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.z_index = -1
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
