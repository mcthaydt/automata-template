extends RefCounted
class_name W_SaveSlotFormatter

const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const MONTH_KEYS: Array[StringName] = [
	&"date.month.jan", &"date.month.feb", &"date.month.mar", &"date.month.apr",
	&"date.month.may", &"date.month.jun", &"date.month.jul", &"date.month.aug",
	&"date.month.sep", &"date.month.oct", &"date.month.nov", &"date.month.dec"
]
const MONTH_FALLBACKS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

static func format_timestamp(iso_timestamp: String) -> String:
	if iso_timestamp.is_empty():
		return U_LOCALIZATION_UTILS.localize_with_fallback(&"overlay.save_load.unknown_date", "Unknown Date")
	var parts: PackedStringArray = iso_timestamp.split("T")
	if parts.size() < 2:
		return iso_timestamp
	var date_components: PackedStringArray = parts[0].split("-")
	var time_components: PackedStringArray = parts[1].replace("Z", "").split(":")
	if date_components.size() < 3 or time_components.size() < 2:
		return iso_timestamp
	var month_name: String = _month_name(date_components[1].to_int())
	var hour: int = time_components[0].to_int()
	var hour_12: int = hour
	var am_pm_key := &"date.am"
	if hour >= 12:
		am_pm_key = &"date.pm"
		if hour > 12:
			hour_12 = hour - 12
	elif hour == 0:
		hour_12 = 12
	return "%s %s, %s %d:%s %s" % [
		month_name,
		date_components[2],
		date_components[0],
		hour_12,
		time_components[1],
		_am_pm(am_pm_key)
	]

static func format_playtime(seconds: int) -> String:
	var hours: int = int(seconds / 3600.0)
	var minutes: int = int((seconds % 3600) / 60.0)
	var secs: int = seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]

static func get_slot_display_name(slot_id: StringName, is_autosave: bool) -> String:
	if is_autosave:
		return U_LOCALIZATION_UTILS.localize_with_fallback(&"overlay.save_load.autosave", "AUTOSAVE")
	return slot_id.to_upper()

static func format_button_text(slot_meta: Dictionary, mode: StringName, exists: bool, is_autosave: bool) -> String:
	var slot_id: StringName = slot_meta.get("slot_id", &"")
	var name := get_slot_display_name(slot_id, is_autosave)
	if not exists:
		var key := &"overlay.save_load.new_save" if mode == &"save" else &"overlay.save_load.empty_slot"
		var fallback := "[New Save]" if mode == &"save" else "[Empty]"
		return "%s\n%s" % [name, U_LOCALIZATION_UTILS.localize_with_fallback(key, fallback)]
	return "%s\n%s | %s | %s" % [
		name,
		format_timestamp(slot_meta.get("timestamp", "")),
		slot_meta.get("area_name", U_LOCALIZATION_UTILS.localize_with_fallback(&"overlay.save_load.unknown_area", "Unknown")),
		format_playtime(slot_meta.get("playtime_seconds", 0))
	]

static func _month_name(month_num: int) -> String:
	if month_num < 1 or month_num > 12:
		return "???"
	var key: StringName = MONTH_KEYS[month_num - 1]
	return U_LOCALIZATION_UTILS.localize_with_fallback(key, MONTH_FALLBACKS[month_num - 1])

static func _am_pm(key: StringName) -> String:
	var fallback := "AM" if key == &"date.am" else "PM"
	return U_LOCALIZATION_UTILS.localize_with_fallback(key, fallback)
