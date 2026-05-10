extends GutTest

const W_SaveSlotFormatter := preload("res://scripts/core/ui/widgets/w_save_slot_formatter.gd")

func test_format_playtime_uses_hh_mm_ss() -> void:
	assert_eq(W_SaveSlotFormatter.format_playtime(3723), "01:02:03")

func test_format_timestamp_formats_iso_timestamp() -> void:
	assert_eq(W_SaveSlotFormatter.format_timestamp("2025-12-26T14:30:00Z"), "Dec 26, 2025 2:30 PM")

func test_format_timestamp_returns_unknown_for_empty_value() -> void:
	assert_eq(W_SaveSlotFormatter.format_timestamp(""), "Unknown Date")

func test_get_slot_display_name_uses_autosave_label() -> void:
	assert_eq(W_SaveSlotFormatter.get_slot_display_name(&"autosave", true), "AUTOSAVE")
	assert_eq(W_SaveSlotFormatter.get_slot_display_name(&"slot_01", false), "SLOT_01")
