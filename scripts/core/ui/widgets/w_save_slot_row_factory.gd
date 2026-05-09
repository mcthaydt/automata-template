extends RefCounted
class_name W_SaveSlotRowFactory

const W_SAVE_SLOT_FORMATTER := preload("res://scripts/core/ui/widgets/w_save_slot_formatter.gd")
const W_SAVE_SLOT_THUMBNAIL_LOADER := preload("res://scripts/core/ui/widgets/w_save_slot_thumbnail_loader.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")

static func create_slot_item(
	slot_meta: Dictionary,
	mode: StringName,
	theme_config: RS_UIThemeConfig,
	placeholder_texture: Texture2D,
	pending_thumbnail_loads: Dictionary,
	slot_callback: Callable,
	delete_callback: Callable
) -> HBoxContainer:
	var slot_id: StringName = slot_meta.get("slot_id", &"")
	var exists: bool = slot_meta.get("exists", false)
	var is_autosave: bool = slot_id == &"autosave"
	var row := HBoxContainer.new()
	row.name = "Slot_" + String(slot_id)
	var path: String = slot_meta.get("thumbnail_path", "")
	var thumbnail := W_SAVE_SLOT_THUMBNAIL_LOADER.configured_rect(path, placeholder_texture, pending_thumbnail_loads)
	var main_button := _main_button(slot_meta, mode, exists, is_autosave, slot_callback)
	var delete_button := _delete_button(exists, is_autosave, slot_id, delete_callback)
	row.add_child(thumbnail)
	row.add_child(main_button)
	row.add_child(delete_button)
	_apply_theme(row, main_button, delete_button, thumbnail, theme_config)
	return row

static func _main_button(slot_meta: Dictionary, mode: StringName, exists: bool, is_autosave: bool, slot_callback: Callable) -> Button:
	var slot_id: StringName = slot_meta.get("slot_id", &"")
	var button := Button.new()
	button.name = "MainButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = W_SAVE_SLOT_FORMATTER.format_button_text(slot_meta, mode, exists, is_autosave)
	button.disabled = mode == &"load" and not exists
	if slot_callback.is_valid():
		button.pressed.connect(func() -> void: slot_callback.call(slot_id, exists))
	return button

static func _delete_button(exists: bool, is_autosave: bool, slot_id: StringName, delete_callback: Callable) -> Button:
	var button := Button.new()
	button.name = "DeleteButton"
	button.text = U_LOCALIZATION_UTILS.localize_with_fallback(&"common.delete", "Delete")
	button.custom_minimum_size = Vector2(80, 0)
	button.visible = exists and not is_autosave
	button.disabled = not exists or is_autosave
	if exists and not is_autosave and delete_callback.is_valid():
		button.pressed.connect(func() -> void: delete_callback.call(slot_id))
	return button

static func _apply_theme(row: HBoxContainer, main: Button, delete: Button, thumbnail: TextureRect, config: RS_UIThemeConfig) -> void:
	if config == null:
		return
	row.add_theme_constant_override(&"separation", config.separation_compact)
	main.custom_minimum_size = Vector2(0, 76)
	main.add_theme_font_size_override(&"font_size", config.section_header)
	delete.add_theme_font_size_override(&"font_size", config.section_header)
	thumbnail.custom_minimum_size = Vector2(96, 54)
