extends GutTest

# Test suite for M_DisplayManager scaffolding and lifecycle (Phase 1B)

const M_DISPLAY_MANAGER := preload("res://scripts/core/managers/m_display_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_WINDOW_OPS := preload("res://tests/mocks/mock_window_ops.gd")
const I_DISPLAY_MANAGER := preload("res://scripts/core/interfaces/i_display_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/core/state/selectors/u_display_selectors.gd")
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_display_initial_state.gd")
const RS_UI_COLOR_PALETTE := preload("res://scripts/core/resources/ui/rs_ui_color_palette.gd")
const U_DISPLAY_UI_THEME_APPLIER := preload("res://scripts/core/managers/helpers/display/u_display_ui_theme_applier.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
var _manager: Node
var _store: Node

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_DISPLAY_UI_THEME_APPLIER.clear_active_palette()
	U_UI_THEME_BUILDER.active_config = null
	_manager = null
	_store = null

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_DISPLAY_UI_THEME_APPLIER.clear_active_palette()
	U_UI_THEME_BUILDER.active_config = null
	_manager = null
	_store = null

func test_manager_extends_interface() -> void:
	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)

	assert_true(_manager is I_DISPLAY_MANAGER, "M_DisplayManager should extend I_DisplayManager")

func test_initial_state_keeps_desktop_windowed_and_defaults_mobile_to_fullscreen() -> void:
	var defaults := RS_DISPLAY_INITIAL_STATE.new()
	var display_state := defaults.to_dictionary()

	assert_eq(display_state.get("window_mode"), "windowed", "Desktop default should remain windowed")
	assert_eq(display_state.get("mobile_window_mode"), "fullscreen", "Mobile default should boot fullscreen")

func test_mobile_resolution_scale_selector_defaults_to_mobile_baseline() -> void:
	assert_almost_eq(
		U_DISPLAY_SELECTORS.get_mobile_resolution_scale({}),
		0.35,
		0.001,
		"Missing mobile_resolution_scale should use mobile baseline"
	)

func test_mobile_resolution_scale_selector_clamps_to_safe_range() -> void:
	assert_almost_eq(
		U_DISPLAY_SELECTORS.get_mobile_resolution_scale({"display": {"mobile_resolution_scale": 0.05}}),
		0.25,
		0.001,
		"Selector should clamp mobile resolution scale to minimum"
	)
	assert_almost_eq(
		U_DISPLAY_SELECTORS.get_mobile_resolution_scale({"display": {"mobile_resolution_scale": 1.25}}),
		1.0,
		0.001,
		"Selector should clamp mobile resolution scale to maximum"
	)

func test_manager_registers_with_service_locator() -> void:
	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var service := U_SERVICE_LOCATOR.try_get_service(StringName("display_manager"))
	assert_not_null(service, "Display manager should register with ServiceLocator")
	assert_eq(service, _manager, "ServiceLocator should return the display manager instance")

func test_manager_discovers_state_store() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	var resolved_store: Node = _manager.get("_state_store") as Node
	assert_eq(resolved_store, _store, "Manager should discover StateStore via U_StateUtils.try_get_store()")

func test_manager_subscribes_to_slice_updated() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	var handler := Callable(_manager, "_on_slice_updated")
	assert_true(_store.slice_updated.is_connected(handler), "Manager should connect to StateStore slice_updated signal")

func test_manager_applies_settings_on_ready() -> void:
	await _setup_manager_with_store({"window_mode": "windowed", "ui_scale": 1.0})

	assert_eq(int(_manager.get("_apply_count")), 1, "Manager should apply display settings on ready")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("window_mode"), "windowed", "Initial apply should read settings from state")

func test_manager_applies_settings_on_slice_change() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	_store.set_slice(StringName("display"), {"window_mode": "fullscreen"})
	_store.slice_updated.emit(StringName("display"), {"window_mode": "fullscreen"})

	assert_eq(int(_manager.get("_apply_count")), 2, "Manager should apply settings on display slice updates")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("window_mode"), "fullscreen", "Apply should reflect updated state")

func test_manager_hash_prevents_redundant_applies() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	var apply_count := int(_manager.get("_apply_count"))
	_store.slice_updated.emit(StringName("display"), {"window_mode": "windowed"})

	assert_eq(int(_manager.get("_apply_count")), apply_count, "Hash should prevent redundant apply calls")

func test_localization_override_updates_effective_ui_scale() -> void:
	await _setup_manager_with_store(
		{"window_mode": "windowed", "ui_scale": 1.0},
		{"ui_scale_override": 1.1}
	)

	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_almost_eq(float(applied.get("ui_scale", 0.0)), 1.1, 0.001, "Localization ui_scale_override should affect effective ui_scale")

func test_localization_slice_update_reapplies_scale_without_dispatch_loop() -> void:
	await _setup_manager_with_store(
		{"window_mode": "windowed", "ui_scale": 1.0},
		{"ui_scale_override": 1.0}
	)
	_store.clear_dispatched_actions()
	var apply_count := int(_manager.get("_apply_count"))

	_store.set_slice(StringName("localization"), {"ui_scale_override": 1.1})
	_store.slice_updated.emit(StringName("localization"), {"ui_scale_override": 1.1})

	assert_eq(int(_manager.get("_apply_count")), apply_count + 1, "Localization updates should trigger re-apply for effective scale")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_almost_eq(float(applied.get("ui_scale", 0.0)), 1.1, 0.001, "Effective ui_scale should include localization override")
	assert_eq(_store.get_dispatched_actions().size(), 0, "Display manager should not dispatch actions when reacting to localization updates")

func test_preview_sets_flag() -> void:
	await _setup_manager_with_store({"ui_scale": 1.0})

	_manager.set_display_settings_preview({"ui_scale": 1.5})
	assert_true(bool(_manager.get("_display_settings_preview_active")), "Preview should set active flag")

func test_preview_overrides_state() -> void:
	await _setup_manager_with_store({"window_mode": "windowed", "ui_scale": 1.0})

	_manager.set_display_settings_preview({"ui_scale": 1.5})
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("ui_scale"), 1.5, "Preview should override ui_scale")
	assert_eq(applied.get("window_mode"), "windowed", "Preview should retain base state values")

func test_clear_preview_restores_state_and_clears_flag() -> void:
	await _setup_manager_with_store({"ui_scale": 1.0})

	_manager.set_display_settings_preview({"ui_scale": 1.5})
	_manager.clear_display_settings_preview()

	assert_false(bool(_manager.get("_display_settings_preview_active")), "Clear preview should reset active flag")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("ui_scale"), 1.0, "Clear preview should restore ui_scale from state")

func test_set_ui_scale_clamps_to_min() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	add_child_autofree(label)
	manager.register_ui_scale_root(label)

	manager.set_ui_scale(0.1)

	assert_eq(label.get_theme_font_size("font_size"), 16, "UI scale should clamp to minimum")

func test_set_ui_scale_clamps_to_max() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	add_child_autofree(label)
	manager.register_ui_scale_root(label)

	manager.set_ui_scale(5.0)

	assert_eq(label.get_theme_font_size("font_size"), 26, "UI scale should clamp to maximum")

func test_set_ui_scale_applies_font_scale_to_controls() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	var root := Control.new()
	add_child_autofree(root)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	root.add_child(label)
	manager.register_ui_scale_root(root)

	manager.set_ui_scale(1.2)

	assert_eq(label.get_theme_font_size("font_size"), 24, "UI scale should apply to registered controls")

func test_register_ui_scale_root_applies_current_scale() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	manager.set_ui_scale(1.2)

	var root := Control.new()
	add_child_autofree(root)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	root.add_child(label)
	manager.register_ui_scale_root(root)

	assert_eq(label.get_theme_font_size("font_size"), 24, "Registering should apply the current UI scale")

func test_apply_window_size_preset_sets_window_size() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	var ops = MOCK_WINDOW_OPS.new()
	ops.screen_size = Vector2i(1920, 1080)
	manager.window_ops = ops

	manager.apply_window_size_preset("1280x720")
	assert_eq(ops.window_size, Vector2i(1280, 720), "Window size preset should set window size")
	assert_eq(ops.window_position, Vector2i(320, 180), "Window size preset should center the window")
	manager.free()

func test_apply_window_size_preset_invalid_is_noop() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	var ops = MOCK_WINDOW_OPS.new()
	ops.window_size = Vector2i(900, 700)
	manager.window_ops = ops

	manager.apply_window_size_preset("not_a_real_preset")
	assert_eq(ops.window_size, Vector2i(900, 700), "Invalid preset should not change window size")
	assert_eq(ops.calls.size(), 0, "Invalid preset should not call window ops")
	manager.free()

func test_set_window_mode_fullscreen_calls_display_server() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	var ops = MOCK_WINDOW_OPS.new()
	ops.window_mode = DisplayServer.WINDOW_MODE_WINDOWED
	ops.borderless = true
	manager.window_ops = ops
	add_child_autofree(manager)

	manager.set_window_mode("fullscreen")
	await get_tree().process_frame
	assert_eq(ops.window_mode, DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen mode should update window ops mode")
	assert_eq(ops.get_call_count("window_set_flag"), 0, "Fullscreen should not toggle window style flags")

func test_set_window_mode_windowed_calls_display_server() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	var ops = MOCK_WINDOW_OPS.new()
	ops.window_mode = DisplayServer.WINDOW_MODE_WINDOWED
	ops.borderless = true
	manager.window_ops = ops
	add_child_autofree(manager)

	manager.set_window_mode("windowed")
	await get_tree().process_frame
	assert_eq(ops.window_mode, DisplayServer.WINDOW_MODE_WINDOWED, "Windowed mode should update window ops mode")
	assert_false(ops.borderless, "Windowed mode should clear borderless flag")

func test_set_window_mode_borderless_calls_display_server() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	var ops = MOCK_WINDOW_OPS.new()
	ops.window_mode = DisplayServer.WINDOW_MODE_WINDOWED
	ops.borderless = false
	ops.screen_size = Vector2i(2560, 1440)
	manager.window_ops = ops

	manager.set_window_mode("borderless")
	assert_eq(ops.window_mode, DisplayServer.WINDOW_MODE_WINDOWED, "Borderless mode should use windowed mode")
	assert_true(ops.borderless, "Borderless mode should enable borderless flag")
	assert_eq(ops.window_size, Vector2i(2560, 1440), "Borderless mode should resize to screen size")
	assert_eq(ops.window_position, Vector2i.ZERO, "Borderless mode should move to origin")
	manager.free()

func test_set_window_mode_borderless_defers_style_mask_after_fullscreen_on_macos() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	var ops = MOCK_WINDOW_OPS.new()
	ops.os_name = "macOS"
	ops.window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	ops.borderless = false
	manager.window_ops = ops
	add_child_autofree(manager)

	manager.set_window_mode("borderless")
	assert_eq(ops.get_call_count("window_set_flag"), 0, "Borderless flag should not change while exiting fullscreen")

	await get_tree().process_frame
	assert_eq(ops.get_call_count("window_set_flag"), 0, "macOS should wait an extra frame before touching style masks")

	await get_tree().process_frame
	assert_true(ops.borderless, "Borderless flag should settle after retries")

func test_set_vsync_enabled_calls_display_server() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	var ops = MOCK_WINDOW_OPS.new()
	ops.vsync_mode = DisplayServer.VSYNC_DISABLED
	manager.window_ops = ops
	add_child_autofree(manager)

	manager.set_vsync_enabled(true)
	await get_tree().process_frame
	assert_eq(ops.vsync_mode, DisplayServer.VSYNC_ENABLED, "VSync enabled should update window ops")

	manager.set_vsync_enabled(false)
	await get_tree().process_frame
	assert_eq(ops.vsync_mode, DisplayServer.VSYNC_DISABLED, "VSync disabled should update window ops")

func test_palette_theme_binding_applies_to_registered_controls() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	var root := Control.new()
	add_child_autofree(root)
	var label := Label.new()
	root.add_child(label)
	manager.register_ui_scale_root(root)

	manager._apply_accessibility_settings({
		"color_blind_mode": "normal",
		"high_contrast_enabled": false,
	})

	var palette := manager.get_active_palette()
	assert_not_null(palette, "Palette should be available after applying accessibility settings")
	assert_true(palette is RS_UI_COLOR_PALETTE, "Palette should be RS_UIColorPalette")
	var typed_palette := palette as RS_UI_COLOR_PALETTE

	assert_true(
		label.get_theme_color("font_color").is_equal_approx(typed_palette.text),
		"Label font color should bind to palette text color"
	)

func test_register_ui_scale_root_applies_current_palette_theme() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	manager._apply_accessibility_settings({
		"color_blind_mode": "normal",
		"high_contrast_enabled": true,
	})

	var palette := manager.get_active_palette()
	assert_not_null(palette, "Palette should be available after applying accessibility settings")
	assert_true(palette is RS_UI_COLOR_PALETTE, "Palette should be RS_UIColorPalette")
	var typed_palette := palette as RS_UI_COLOR_PALETTE

	var root := Control.new()
	add_child_autofree(root)
	var label := Label.new()
	root.add_child(label)
	manager.register_ui_scale_root(root)

	assert_true(
		label.get_theme_color("font_color").is_equal_approx(typed_palette.text),
		"Registering should apply the current palette theme"
	)

func _setup_manager_with_store(display_state: Dictionary, localization_state: Dictionary = {}) -> void:
	_store = MOCK_STATE_STORE.new()
	_store.set_slice(StringName("display"), display_state)
	if not localization_state.is_empty():
		_store.set_slice(StringName("localization"), localization_state)
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	var game_viewport := SubViewport.new()
	game_viewport.name = "GameViewport"
	add_child_autofree(game_viewport)
	U_SERVICE_LOCATOR.register(StringName("game_viewport"), game_viewport)

	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

 
