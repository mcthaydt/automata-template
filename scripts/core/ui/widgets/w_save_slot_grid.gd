extends Control
class_name W_SaveSlotGrid

signal slot_pressed(slot_id: StringName, exists: bool)
signal delete_pressed(slot_id: StringName)
const W_SAVE_SLOT_THUMBNAIL_LOADER := preload("res://scripts/core/ui/widgets/w_save_slot_thumbnail_loader.gd")
const W_SAVE_SLOT_ROW_FACTORY := preload("res://scripts/core/ui/widgets/w_save_slot_row_factory.gd")
const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")
var _slot_list: VBoxContainer = null
var _pending_thumbnail_loads: Dictionary = {}
var _placeholder_texture: Texture2D = null

func _init() -> void:
	_slot_list = VBoxContainer.new()
	_slot_list.name = "SlotListContainer"
	_slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_slot_list)

func bind_slot_container(container: VBoxContainer) -> void:
	if container != null:
		if _slot_list != null and _slot_list != container and _slot_list.get_parent() == self:
			remove_child(_slot_list)
			_slot_list.free()
		_slot_list = container

func set_placeholder_texture(texture: Texture2D) -> void:
	_placeholder_texture = texture

func set_slots(metadata: Array[Dictionary], mode: StringName, theme_config: RS_UIThemeConfig) -> void:
	clear()
	for slot_meta in metadata:
		_slot_list.add_child(W_SAVE_SLOT_ROW_FACTORY.create_slot_item(
			slot_meta,
			mode,
			theme_config,
			_placeholder_texture,
			_pending_thumbnail_loads,
			_on_slot_pressed,
			_on_delete_pressed
		))
	set_process(not _pending_thumbnail_loads.is_empty())

func clear() -> void:
	_pending_thumbnail_loads.clear()
	set_process(false)
	for child in _slot_list.get_children():
		child.queue_free()

func get_focused_slot_index() -> int:
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	var parent := focused.get_parent() if focused != null else null
	if parent is HBoxContainer and parent.get_parent() == _slot_list:
		return parent.get_index()
	return -1

func restore_focus(slot_index: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	var rows := _valid_rows()
	var target_index: int = clampi(slot_index, 0, rows.size() - 1)
	for index in range(target_index, rows.size()):
		var button := rows[index].get_node_or_null("MainButton") as Button
		if button != null and not button.disabled and button.is_inside_tree():
			button.grab_focus()
			return

func configure_focus(back_button: Button) -> void:
	var controls: Array[Control] = []
	for row in _valid_rows():
		var button := row.get_node_or_null("MainButton") as Button
		if button != null and not button.disabled:
			controls.append(button)
	if back_button != null and not controls.is_empty():
		controls.append(back_button)
		U_FOCUS_CONFIGURATOR.configure_vertical_focus(controls, true)

func set_buttons_enabled(enabled: bool) -> void:
	for row in _valid_rows():
		for name in ["MainButton", "DeleteButton"]:
			var button := row.get_node_or_null(name) as Button
			if button != null:
				button.disabled = not enabled

func _process(_delta: float) -> void:
	W_SAVE_SLOT_THUMBNAIL_LOADER.poll_pending(_pending_thumbnail_loads, _placeholder_texture)
	if _pending_thumbnail_loads.is_empty():
		set_process(false)

func _on_slot_pressed(slot_id: StringName, exists: bool) -> void:
	slot_pressed.emit(slot_id, exists)

func _on_delete_pressed(slot_id: StringName) -> void:
	delete_pressed.emit(slot_id)

func _valid_rows() -> Array[HBoxContainer]:
	var rows: Array[HBoxContainer] = []
	for child in _slot_list.get_children():
		if child is HBoxContainer and not child.is_queued_for_deletion():
			rows.append(child)
	return rows
