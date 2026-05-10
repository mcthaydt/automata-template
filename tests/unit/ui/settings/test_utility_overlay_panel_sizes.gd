extends GutTest

const BaseOverlay := preload("res://scripts/core/ui/base/base_overlay.gd")

const SCENE_PATHS := {
	"input_rebinding": "res://scenes/core/ui/overlays/ui_input_rebinding_overlay.tscn",
	"edit_touch_controls": "res://scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn",
	"input_profile_selector": "res://scenes/core/ui/overlays/ui_input_profile_selector.tscn",
}

const SAVE_LOAD_MENU_SCENE := "res://scenes/core/ui/overlays/ui_save_load_menu.tscn"

const EXPECTED_SIZE_TEXT := "custom_minimum_size = Vector2(860, 620)"

func test_input_rebinding_panel_size():
	_assert_panel_size(SCENE_PATHS.input_rebinding)

func test_edit_touch_controls_panel_size():
	_assert_panel_size(SCENE_PATHS.edit_touch_controls)

func test_input_profile_selector_panel_size():
	_assert_panel_size(SCENE_PATHS.input_profile_selector)

func test_save_load_menu_panel_size_is_runtime_dynamic():
	var file := FileAccess.open(SAVE_LOAD_MENU_SCENE, FileAccess.READ)
	if file == null:
		assert_false(true, "Cannot open: " + SAVE_LOAD_MENU_SCENE)
		return
	var source := file.get_as_text()
	file.close()
	var has_motion_host := false
	var has_static_size := false
	for line in source.split("\n"):
		if "MainPanelMotionHost" in line:
			has_motion_host = true
		if has_motion_host and line.strip_edges() == EXPECTED_SIZE_TEXT:
			has_static_size = true
			break
	assert_false(has_static_size, SAVE_LOAD_MENU_SCENE + " MainPanelMotionHost should NOT have a static custom_minimum_size (sizing is now dynamic via PanelViewport)")

func _assert_panel_size(scene_path: String) -> void:
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		assert_false(true, "Cannot open: " + scene_path)
		return
	var source := file.get_as_text()
	file.close()
	var has_motion_host := false
	var has_correct_size := false
	for line in source.split("\n"):
		if "MainPanelMotionHost" in line:
			has_motion_host = true
		if has_motion_host and line.strip_edges() == EXPECTED_SIZE_TEXT:
			has_correct_size = true
			break
	assert_true(has_correct_size, scene_path + " MainPanelMotionHost custom_minimum_size should be " + EXPECTED_SIZE_TEXT)
