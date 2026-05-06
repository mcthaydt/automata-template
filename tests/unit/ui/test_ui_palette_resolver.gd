extends GutTest

const U_UIPaletteResolver := preload("res://scripts/core/ui/utils/u_ui_palette_resolver.gd")

const PALETTE_NORMAL := preload("res://resources/core/ui_themes/cfg_palette_normal.tres")
const PALETTE_DEUTERANOPIA := preload("res://resources/core/ui_themes/cfg_palette_deuteranopia.tres")
const PALETTE_DEUTERANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_deuteranopia_high_contrast.tres")
const PALETTE_PROTANOPIA := preload("res://resources/core/ui_themes/cfg_palette_protanopia.tres")
const PALETTE_PROTANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_protanopia_high_contrast.tres")
const PALETTE_TRITANOPIA := preload("res://resources/core/ui_themes/cfg_palette_tritanopia.tres")
const PALETTE_TRITANOPIA_HC := preload("res://resources/core/ui_themes/cfg_palette_tritanopia_high_contrast.tres")
const PALETTE_NORMAL_HC := preload("res://resources/core/ui_themes/cfg_palette_normal_high_contrast.tres")

func test_resolve_normal_no_contrast_returns_default() -> void:
	var result := U_UIPaletteResolver.resolve_palette("normal", false)
	assert_eq(result, PALETTE_NORMAL)

func test_resolve_normal_high_contrast_returns_normal_hc() -> void:
	var result := U_UIPaletteResolver.resolve_palette("normal", true)
	assert_eq(result, PALETTE_NORMAL_HC)

func test_resolve_deuteranopia_no_contrast_returns_deuteranopia() -> void:
	var result := U_UIPaletteResolver.resolve_palette("deuteranopia", false)
	assert_eq(result, PALETTE_DEUTERANOPIA)

func test_resolve_deuteranopia_high_contrast_returns_deuteranopia_hc() -> void:
	var result := U_UIPaletteResolver.resolve_palette("deuteranopia", true)
	assert_eq(result, PALETTE_DEUTERANOPIA_HC)

func test_resolve_protanopia_no_contrast_returns_protanopia() -> void:
	var result := U_UIPaletteResolver.resolve_palette("protanopia", false)
	assert_eq(result, PALETTE_PROTANOPIA)

func test_resolve_protanopia_high_contrast_returns_protanopia_hc() -> void:
	var result := U_UIPaletteResolver.resolve_palette("protanopia", true)
	assert_eq(result, PALETTE_PROTANOPIA_HC)

func test_resolve_tritanopia_no_contrast_returns_tritanopia() -> void:
	var result := U_UIPaletteResolver.resolve_palette("tritanopia", false)
	assert_eq(result, PALETTE_TRITANOPIA)

func test_resolve_tritanopia_high_contrast_returns_tritanopia_hc() -> void:
	var result := U_UIPaletteResolver.resolve_palette("tritanopia", true)
	assert_eq(result, PALETTE_TRITANOPIA_HC)

func test_resolve_unknown_mode_falls_back_to_normal() -> void:
	var result := U_UIPaletteResolver.resolve_palette("bogus", true)
	assert_eq(result, PALETTE_NORMAL)

func test_resolve_unknown_mode_no_contrast_falls_back_to_normal() -> void:
	var result := U_UIPaletteResolver.resolve_palette("bogus", false)
	assert_eq(result, PALETTE_NORMAL)
