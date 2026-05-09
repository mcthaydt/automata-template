@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_overlay.gd"
class_name UI_InputProfileSelector

const I_INPUT_PROFILE_MANAGER := preload("res://scripts/core/interfaces/i_input_profile_manager.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_MENU_BUILDER := preload("res://scripts/core/ui/helpers/u_ui_menu_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

const ACTION_LABEL_KEYS := {
	StringName("move"): &"input.action.move",
	StringName("jump"): &"input.action.jump",
	StringName("sprint"): &"input.action.sprint",
	StringName("interact"): &"input.action.interact",
	StringName("pause"): &"input.action.pause",
}
const OVERLAY_TITLE_KEY := &"overlay.input_profile_selector.title"
const OVERLAY_PROFILE_LABEL_KEY := &"overlay.input_profile_selector.profile_label"
const OVERLAY_RESET_BUTTON_KEY := &"overlay.input_profile_selector.reset_button"
const OVERLAY_PROFILE_LABEL_FALLBACK := "Profile"

@onready var _main_panel: PanelContainer = %MainPanel
@onready var _main_panel_padding: MarginContainer = %MainPanelPadding
@onready var _main_panel_content: VBoxContainer = %MainPanelContent
@onready var _heading_label: Label = %HeadingLabel
@onready var _profile_row: HBoxContainer = %ProfileRow
@onready var _profile_label: Label = %ProfileLabel
@onready var _profile_button: Button = %ProfileButton
@onready var _apply_button: Button = %ApplyButton
@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton
@onready var _preview_container: VBoxContainer = %PreviewContainer
@onready var _button_row: HBoxContainer = %ButtonRow
@onready var _header_label: Label = %HeaderLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _bindings_container: VBoxContainer = %BindingsContainer

@export var input_profile_manager: Node = null

const INPUT_PROFILE_MANAGER_SERVICE := StringName("input_profile_manager")

var _manager: Node = null
var _available_profiles: Array[String] = []
var _current_index: int = 0
var _theme_config: Resource = null
var _builder: RefCounted = null

func _on_panel_ready() -> void:
	_setup_builder()
	_apply_theme_tokens()
	if _profile_button != null and not _profile_button.pressed.is_connected(_on_profile_button_pressed):
		_profile_button.pressed.connect(_on_profile_button_pressed)

	_manager = _resolve_input_profile_manager()
	_localize_static_labels()
	if _manager == null:
		_update_preview()
		play_enter_animation()
		return
	if _manager.has_signal("profile_switched") and not _manager.profile_switched.is_connected(_on_manager_profile_switched):
		_manager.profile_switched.connect(_on_manager_profile_switched)
	_populate_profiles()
	_configure_focus_neighbors()
	_update_preview()
	play_enter_animation()

func _setup_builder() -> void:
	_builder = U_UI_MENU_BUILDER.new(self)
	_builder.bind_theme_role(self, &"overlay_dim", {"alpha": 0.5, "apply_menu_background": true})
	_builder.bind_theme_role(get_node_or_null("OverlayBackground") as ColorRect, &"overlay_dim", {"alpha": 0.5})
	_builder.bind_panel(_main_panel, _main_panel_padding, _main_panel_content)
	_builder.bind_title(_heading_label, OVERLAY_TITLE_KEY)
	_builder.bind_theme_role(_profile_row, &"separation_default")
	_builder.bind_theme_role(_preview_container, &"separation_compact")
	_builder.bind_theme_role(_bindings_container, &"separation_compact")
	_builder.bind_theme_role(_button_row, &"separation_compact")
	_builder.bind_theme_role(_profile_label, &"body_small")
	_builder.bind_theme_role(_profile_label, &"text_secondary")
	_builder.bind_theme_role(_header_label, &"body_small")
	_builder.bind_theme_role(_description_label, &"body_small")
	_builder.bind_theme_role(_description_label, &"text_secondary")
	_builder.bind_theme_role(_header_label, &"subheading")
	_builder.bind_button(_profile_button, OVERLAY_PROFILE_LABEL_KEY, Callable(), OVERLAY_PROFILE_LABEL_FALLBACK)
	_builder.bind_button(_cancel_button, &"common.cancel", _on_cancel_pressed, "Cancel")
	_builder.bind_button(_reset_button, OVERLAY_RESET_BUTTON_KEY, _on_reset_pressed, "Reset to Defaults")
	_builder.bind_button(_apply_button, &"common.apply", _on_apply_pressed, "Apply")
	_builder.build()

func _resolve_input_profile_manager() -> Node:
	if input_profile_manager != null and is_instance_valid(input_profile_manager):
		return input_profile_manager

	var manager := U_ServiceLocator.try_get_service(INPUT_PROFILE_MANAGER_SERVICE)
	if manager != null:
		return manager

	return null

func _on_manager_profile_switched(profile_id: String) -> void:
	if _available_profiles.is_empty():
		_populate_profiles()
		return
	var idx := _available_profiles.find(profile_id)
	if idx != -1:
		_current_index = idx
		_update_button_text()
	else:
		_populate_profiles()

func _navigate_focus(direction: StringName) -> void:
	var focused := get_viewport().gui_get_focus_owner()

	if focused == _profile_button and (direction == "ui_left" or direction == "ui_right"):
		if direction == "ui_left":
			_cycle_profile(-1)
		else:
			_cycle_profile(1)
		return

	super._navigate_focus(direction)

func _unhandled_input(event: InputEvent) -> void:
	# Note: Analog stick motion (InputEventJoypadMotion) is handled by
	# _navigate_focus() via the analog stick repeater from BaseMenuScreen.
	# Only handle discrete button presses (keyboard, D-pad) here.
	#
	# Analog stick motion should NOT be handled here with is_action_pressed()
	# as that bypasses debouncing and causes rapid cycling.

	# Skip analog stick motion events - let the repeater handle them
	if event is InputEventJoypadMotion:
		super._unhandled_input(event)
		return

	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner() if viewport != null else null

	# Handle discrete button presses for profile cycling (left/right like sliders)
	if focused == _profile_button:
		if event.is_action_pressed("ui_left"):
			_cycle_profile(-1)
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			_cycle_profile(1)
			if viewport != null:
				viewport.set_input_as_handled()
			return

	super._unhandled_input(event)

func _configure_focus_neighbors() -> void:
	# Configure button row horizontal focus
	var buttons: Array[Control] = []
	if _cancel_button != null:
		buttons.append(_cancel_button)
	if _reset_button != null:
		buttons.append(_reset_button)
	if _apply_button != null:
		buttons.append(_apply_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)
		# Connect profile button to button row
		if _profile_button != null:
			_profile_button.focus_neighbor_bottom = _profile_button.get_path_to(buttons[0])
			for button in buttons:
				button.focus_neighbor_top = button.get_path_to(_profile_button)
				button.focus_neighbor_bottom = button.get_path_to(_profile_button)

func _populate_profiles() -> void:
	if _manager == null:
		return
	# Start from all available profiles, then filter by active device type when possible.
	var all_ids: Array[String] = _manager.get_available_profile_ids()
	var filtered_ids: Array[String] = all_ids

	var store := get_store()
	var active_id := ""
	if store != null:
		var state: Dictionary = store.get_state()
		active_id = U_InputSelectors.get_active_profile_id(state)

	if store != null and "available_profiles" in _manager:
		var state: Dictionary = store.get_state()
		var device_type: int = U_InputSelectors.get_active_device_type(state)
		var profiles_dict: Dictionary = _manager.available_profiles
		var device_filtered: Array[String] = []
		for id_key in profiles_dict.keys():
			var profile: RS_InputProfile = profiles_dict[id_key]
			if profile == null:
				continue
			# On mobile, never show "default" (keyboard/mouse profile)
			if OS.has_feature("mobile") and String(id_key) == "default":
				continue
			if profile.device_type == device_type:
				device_filtered.append(String(id_key))
		if not device_filtered.is_empty():
			device_filtered.sort()
			filtered_ids = device_filtered
			# Ensure the current active profile is shown even if it doesn't match the current device filter
			# EXCEPT: never show "default" on mobile
			var should_include_active := not active_id.is_empty() and not filtered_ids.has(active_id) and all_ids.has(active_id)
			var is_default_on_mobile := OS.has_feature("mobile") and active_id == "default"
			if should_include_active and not is_default_on_mobile:
				filtered_ids.insert(0, active_id)

	_available_profiles = filtered_ids

	# Find currently active profile from settings
	if store == null:
		_current_index = 0
	else:
		_current_index = _available_profiles.find(active_id)
		if _current_index == -1:
			_current_index = 0

	_update_button_text()
	_update_preview()

func _update_button_text() -> void:
	if _profile_button == null or _available_profiles.is_empty():
		return
	var profile := _get_selected_profile()
	if profile != null:
		_profile_button.text = _localize_profile_text(profile.profile_name)
	else:
		_profile_button.text = _available_profiles[_current_index]
	_update_preview()

func _cycle_profile(direction: int) -> void:
	if _available_profiles.is_empty():
		return
	U_UISoundPlayer.play_slider_tick()
	# Cycle in the given direction with wrap-around
	_current_index = (_current_index + direction) % _available_profiles.size()
	if _current_index < 0:
		_current_index = _available_profiles.size() - 1
	_update_button_text()

func _on_profile_button_pressed() -> void:
	# Pressing the button also cycles forward (for mouse/touch users)
	_cycle_profile(1)

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	if _manager == null:
		_manager = _resolve_input_profile_manager()
	if _manager != null and _available_profiles.is_empty():
		_populate_profiles()
	if _manager != null and not _available_profiles.is_empty():
		var selected_profile := _available_profiles[_current_index]
		_manager.switch_profile(selected_profile)
	_close_overlay()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()

	# Get the default profile for the current device type
	var store := get_store()
	if store == null:
		return

	var state: Dictionary = store.get_state()
	var device_type: int = U_InputSelectors.get_active_device_type(state)

	# Get default profile ID based on device type
	var default_profile_id: String = ""
	if device_type == 0:  # KEYBOARD_MOUSE
		# On mobile, never use "default" (keyboard/mouse profile)
		if OS.has_feature("mobile"):
			default_profile_id = "default_touchscreen"
		else:
			default_profile_id = "default"
	elif device_type == 1:  # GAMEPAD
		default_profile_id = "default_gamepad"
	elif device_type == 2:  # TOUCHSCREEN
		default_profile_id = "default_touchscreen"

	# Update UI to show the default profile (user must press Apply to confirm)
	if _available_profiles.has(default_profile_id):
		_current_index = _available_profiles.find(default_profile_id)
		_update_button_text()
		_update_preview()
	else:
		push_warning("UI_InputProfileSelector: Default profile '%s' not found for device type %d" % [default_profile_id, device_type])

func _close_overlay() -> void:
	var store := get_store()
	if store == null:
		_transition_back_to_settings_scene()
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		if shell == StringName("main_menu"):
			_transition_back_to_settings_scene()
		else:
			store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_panel")))

func _on_back_pressed() -> void:
	# Back button behavior matches Cancel button
	_on_cancel_pressed()

func _on_locale_changed(_locale: StringName) -> void:
	_localize_static_labels()
	_update_button_text()

func _localize_static_labels() -> void:
	if _builder != null:
		_builder.localize_labels()
	if _profile_label != null:
		_profile_label.text = U_LOCALIZATION_UTILS.localize_with_fallback(OVERLAY_PROFILE_LABEL_KEY, OVERLAY_PROFILE_LABEL_FALLBACK)



func _apply_theme_tokens() -> void:
	if _builder != null:
		_builder.apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
	_theme_config = U_UI_THEME_BUILDER.active_config as RS_UI_THEME_CONFIG

func _transition_back_to_settings_scene() -> void:
	var store := get_store()
	if store == null:
		return
	store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_panel"), "fade", 2))

func _update_preview() -> void:
	if _header_label == null or _description_label == null or _bindings_container == null:
		return
	if _manager == null or _available_profiles.is_empty():
		_header_label.text = ""
		_description_label.text = ""
		_clear_bindings_container()
		return

	var profile := _get_selected_profile()
	if profile == null:
		_header_label.text = ""
		_description_label.text = ""
		_clear_bindings_container()
		return

	_header_label.text = _localize_profile_text(profile.profile_name)
	# Only show description for touchscreen profiles (device_type 2)
	# For keyboard/gamepad, the visual bindings are self-explanatory
	if profile.device_type == 2:  # TOUCHSCREEN
		_description_label.text = _localize_profile_text(profile.description)
	else:
		_description_label.text = ""
	_build_bindings_preview(profile)

func _get_selected_profile() -> RS_InputProfile:
	if _manager == null:
		return null
	if _available_profiles.is_empty():
		return null
	if _current_index < 0 or _current_index >= _available_profiles.size():
		return null

	var profile_id := _available_profiles[_current_index]
	var typed_manager := _manager as I_INPUT_PROFILE_MANAGER
	if typed_manager == null and not ("available_profiles" in _manager):
		return null

	if "available_profiles" in _manager:
		var profiles_dict: Dictionary = _manager.available_profiles
		if profiles_dict.has(profile_id):
			var profile: RS_InputProfile = profiles_dict.get(profile_id)
			return profile
	return null

func _clear_bindings_container() -> void:
	if _bindings_container == null:
		return
	for child in _bindings_container.get_children():
		child.queue_free()

func _build_bindings_preview(profile: RS_InputProfile) -> void:
	_clear_bindings_container()
	if profile == null:
		return

	var device_type_for_registry: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
	if profile.device_type == 1:  # GAMEPAD
		device_type_for_registry = M_InputDeviceManager.DeviceType.GAMEPAD

	# Movement actions
	var move_actions := [
		StringName("move_forward"),
		StringName("move_backward"),
		StringName("move_left"),
		StringName("move_right")
	]
	_add_action_group_row(_get_localized_action_label(&"move"), move_actions, profile, device_type_for_registry)

	# Individual actions
	var single_actions := [
		{ "action": StringName("jump"), "label": _get_localized_action_label(&"jump") },
		{ "action": StringName("sprint"), "label": _get_localized_action_label(&"sprint") },
		{ "action": StringName("interact"), "label": _get_localized_action_label(&"interact") },
		{ "action": StringName("pause"), "label": _get_localized_action_label(&"pause") }
	]

	for entry in single_actions:
		var action_name: StringName = entry["action"]
		var label: String = entry["label"]
		_add_action_row(label, action_name, profile, device_type_for_registry)

func _add_action_group_row(group_label: String, actions: Array, profile: RS_InputProfile, device_type: int) -> void:
	if profile == null or _bindings_container == null:
		return

	var has_any_binding := false
	for action_name in actions:
		var events := profile.get_events_for_action(action_name)
		if not events.is_empty():
			has_any_binding = true
			break

	if not has_any_binding:
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

	var label := Label.new()
	label.text = group_label + ":"
	label.custom_minimum_size = Vector2(100, 0)
	row.add_child(label)

	var icons_container := HBoxContainer.new()
	icons_container.add_theme_constant_override(&"separation", 4)
	row.add_child(icons_container)
	_apply_preview_row_theme_tokens(row, label, icons_container)

	for action_name in actions:
		_add_binding_icons_for_action(icons_container, action_name, profile, device_type)

	_bindings_container.add_child(row)

func _add_action_row(action_label: String, action_name: StringName, profile: RS_InputProfile, device_type: int) -> void:
	if profile == null or _bindings_container == null:
		return

	var events := profile.get_events_for_action(action_name)
	if events.is_empty():
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

	var label := Label.new()
	label.text = action_label + ":"
	label.custom_minimum_size = Vector2(100, 0)
	row.add_child(label)

	var icons_container := HBoxContainer.new()
	icons_container.add_theme_constant_override(&"separation", 4)
	row.add_child(icons_container)
	_apply_preview_row_theme_tokens(row, label, icons_container)

	_add_binding_icons_for_action(icons_container, action_name, profile, device_type)

	_bindings_container.add_child(row)

func _add_binding_icons_for_action(container: HBoxContainer, action: StringName, profile: RS_InputProfile, _device_type: int) -> void:
	if container == null or profile == null:
		return

	var event_text_color := Color(0.7, 0.7, 0.7, 1.0)
	var separator_color := Color(0.5, 0.5, 0.5, 1.0)
	var event_font_size := 0
	if _theme_config is RS_UI_THEME_CONFIG:
		var config := _theme_config as RS_UI_THEME_CONFIG
		event_text_color = config.text_secondary
		separator_color = config.text_disabled
		event_font_size = config.caption

	# Show the actual events from this profile (not the registry defaults)
	var events := profile.get_events_for_action(action)
	for i in range(events.size()):
		var event: InputEvent = events[i]
		if event == null:
			continue

		# Try to get texture for individual keys
		var texture: Texture2D = U_InputRebindUtils.get_texture_for_event(event)

		# Display texture or fallback to text
		if texture != null:
			var texture_rect := TextureRect.new()
			texture_rect.texture = texture
			texture_rect.custom_minimum_size = Vector2(24, 24)
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			container.add_child(texture_rect)
		else:
			# Fallback to text label
			var event_label := Label.new()
			event_label.text = U_InputRebindUtils.format_binding_label(U_InputRebindUtils.format_event_label(event))
			event_label.add_theme_color_override(&"font_color", event_text_color)
			if event_font_size > 0:
				event_label.add_theme_font_size_override(&"font_size", event_font_size)
			container.add_child(event_label)

		# Add separator comma between bindings (except last)
		if i < events.size() - 1:
			var separator := Label.new()
			separator.text = ", "
			separator.add_theme_color_override(&"font_color", separator_color)
			if event_font_size > 0:
				separator.add_theme_font_size_override(&"font_size", event_font_size)
			container.add_child(separator)

func _apply_preview_row_theme_tokens(row: HBoxContainer, label: Label, icons_container: HBoxContainer) -> void:
	if row == null:
		return
	if not (_theme_config is RS_UI_THEME_CONFIG):
		return
	var config := _theme_config as RS_UI_THEME_CONFIG
	row.add_theme_constant_override(&"separation", config.separation_compact)
	if icons_container != null:
		icons_container.add_theme_constant_override(&"separation", config.separation_compact)
	if label != null:
		label.add_theme_font_size_override(&"font_size", config.body_small)
		label.add_theme_color_override(&"font_color", config.text_secondary)

func _localize_profile_text(raw_text: String) -> String:
	if raw_text.is_empty():
		return ""
	var localized := U_LOCALIZATION_UTILS.localize(StringName(raw_text))
	if localized == raw_text:
		return raw_text
	return localized

func _get_localized_action_label(action_name: StringName) -> String:
	var key: StringName = ACTION_LABEL_KEYS.get(action_name, StringName())
	if key == StringName():
		return String(action_name).capitalize()
	var localized := U_LOCALIZATION_UTILS.localize(key)
	if localized == String(key):
		return String(action_name).capitalize()
	return localized
