extends GutTest

const UI_TouchscreenSettingsTab := preload("res://scripts/core/ui/settings/ui_touchscreen_settings_tab.gd")

func before_each() -> void:
	U_StateHandoff.clear_all()

func after_each() -> void:
	U_StateHandoff.clear_all()

func test_touchscreen_settings_tab_extends_vboxcontainer():
	var tab := UI_TouchscreenSettingsTab.new()
	assert_true(tab is VBoxContainer, "Touchscreen settings tab should extend VBoxContainer")
	tab.free()

func test_on_state_changed_does_not_corrupt_button_size_via_preview_constraint() -> void:
	# Regression: _apply_preview_size_limits() was called after _updating_from_state = false.
	# Setting max_value on a Godot slider clamps the current value AND emits value_changed when
	# the preview container hasn't been laid out yet (size = zero, falls back to 200x120).
	# That triggered _on_button_size_changed with _updating_from_state == false, dispatching
	# a tiny constrained value (~0.5) to Redux and shrinking all real touchscreen buttons.
	var store := await _create_state_store()
	store.dispatch(U_InputActions.update_touchscreen_settings({"button_size": 1.5}))
	await _await_frames(1)

	var tab := UI_TouchscreenSettingsTab.new()
	add_child_autofree(tab)
	await _await_frames(3)

	var settings := U_InputSelectors.get_touchscreen_settings(store.get_state())
	assert_almost_eq(
		float(settings.get("button_size", 0.0)),
		1.5,
		0.001,
		"Opening the touchscreen settings tab must not dispatch a corrupted button_size from preview size constraints"
	)
	store.queue_free()

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	store.debug_initial_state = RS_DebugInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	add_child_autofree(store)
	await _await_frames(2)
	return store

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
