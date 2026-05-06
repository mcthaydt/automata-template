extends RefCounted
class_name U_UIPaletteResolver

const PALETTE_NORMAL := preload("res://resources/core/ui_themes/cfg_palette_normal.tres")
const PALETTE_DEUTERANOPIA := preload("res://resources/core/ui_themes/cfg_palette_deuteranopia.tres")
const PALETTE_DEUTERANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_deuteranopia_high_contrast.tres")
const PALETTE_PROTANOPIA := preload("res://resources/core/ui_themes/cfg_palette_protanopia.tres")
const PALETTE_PROTANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_protanopia_high_contrast.tres")
const PALETTE_TRITANOPIA := preload("res://resources/core/ui_themes/cfg_palette_tritanopia.tres")
const PALETTE_TRITANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_tritanopia_high_contrast.tres")
const PALETTE_NORMAL_HC := preload("res://resources/core/ui_themes/cfg_palette_normal_high_contrast.tres")

const _PALETTE_MAP := {
	"deuteranopia": PALETTE_DEUTERANOPIA,
	"deuteranopia_high_contrast": PALETTE_DEUTERANOPIA_HC,
	"protanopia": PALETTE_PROTANOPIA,
	"protanopia_high_contrast": PALETTE_PROTANOPIA_HC,
	"tritanopia": PALETTE_TRITANOPIA,
	"tritanopia_high_contrast": PALETTE_TRITANOPIA_HC,
	"normal_high_contrast": PALETTE_NORMAL_HC,
}

static func resolve_palette(color_blind_mode: String, high_contrast: bool) -> Resource:
	if color_blind_mode == "normal" and not high_contrast:
		return PALETTE_NORMAL
	var key := color_blind_mode + ("_high_contrast" if high_contrast else "")
	return _PALETTE_MAP.get(key, PALETTE_NORMAL)
