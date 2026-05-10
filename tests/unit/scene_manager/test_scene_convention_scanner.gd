extends GutTest

const U_SceneConventionScanner = preload("res://scripts/core/scene_management/helpers/u_scene_convention_scanner.gd")
const U_SceneRegistry = preload("res://scripts/core/scene_management/u_scene_registry.gd")


func test_infer_entry_uses_gameplay_demo_defaults() -> void:
	var entry: Dictionary = U_SceneConventionScanner.infer_entry(
		"res://scenes/demo/gameplay/gameplay_demo_room.tscn"
	)

	assert_eq(entry.get("scene_id"), StringName("demo_room"), "Should strip gameplay prefix")
	assert_eq(entry.get("path"), "res://scenes/demo/gameplay/gameplay_demo_room.tscn", "Should preserve path")
	assert_eq(entry.get("scene_type"), U_SceneRegistry.SceneType.GAMEPLAY, "Should infer gameplay type")
	assert_eq(entry.get("default_transition"), "loading", "Gameplay demo scenes should use loading")
	assert_eq(entry.get("preload_priority"), 5, "Gameplay demo scenes should preload at medium priority")

func test_infer_entry_uses_ui_overlay_defaults() -> void:
	var entry: Dictionary = U_SceneConventionScanner.infer_entry(
		"res://scenes/core/ui/overlays/ui_save_load_menu.tscn"
	)

	assert_eq(entry.get("scene_id"), StringName("save_load_menu"), "Should strip ui prefix")
	assert_eq(entry.get("path"), "res://scenes/core/ui/overlays/ui_save_load_menu.tscn", "Should preserve path")
	assert_eq(entry.get("scene_type"), U_SceneRegistry.SceneType.UI, "Should infer UI type")
	assert_eq(entry.get("default_transition"), "instant", "UI overlays should use instant")

func test_infer_entry_uses_ui_settings_defaults() -> void:
	var entry: Dictionary = U_SceneConventionScanner.infer_entry(
		"res://scenes/core/ui/settings/ui_settings_panel.tscn"
	)

	assert_eq(entry.get("scene_id"), StringName("settings_panel"), "Should strip ui prefix")
	assert_eq(entry.get("path"), "res://scenes/core/ui/settings/ui_settings_panel.tscn", "Should preserve path")
	assert_eq(entry.get("scene_type"), U_SceneRegistry.SceneType.UI, "Should infer UI type")
	assert_eq(entry.get("default_transition"), "instant", "UI settings should use instant")

func test_infer_entry_ignores_prefabs_templates_and_widgets() -> void:
	var ignored_paths := PackedStringArray([
		"res://scenes/core/prefabs/prefab_player.tscn",
		"res://scenes/core/templates/tmpl_base_scene.tscn",
		"res://scenes/core/ui/widgets/ui_virtual_button.tscn",
	])

	for path: String in ignored_paths:
		assert_true(
			U_SceneConventionScanner.infer_entry(path).is_empty(),
			"Should ignore non-registry scene path: %s" % path
		)

func test_infer_entries_returns_entries_keyed_by_scene_id() -> void:
	var entries: Dictionary = U_SceneConventionScanner.infer_entries(PackedStringArray([
		"res://scenes/demo/gameplay/gameplay_demo_room.tscn",
		"res://scenes/core/ui/overlays/ui_save_load_menu.tscn",
		"res://scenes/core/prefabs/prefab_player.tscn",
	]))

	assert_eq(entries.size(), 2, "Should include inferred scenes and skip ignored paths")
	assert_true(entries.has(StringName("demo_room")), "Should key gameplay entry by scene_id")
	assert_true(entries.has(StringName("save_load_menu")), "Should key UI entry by scene_id")
	assert_eq(
		entries[StringName("demo_room")].get("default_transition"),
		"loading",
		"Should retain inferred entry metadata"
	)
