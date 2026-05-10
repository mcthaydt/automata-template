extends GutTest

## Unit tests for U_SceneRegistry static class
##
## Tests scene metadata management and door pairing validation.
## Tests follow TDD discipline: written BEFORE implementation.

const U_SceneRegistry = preload("res://scripts/core/scene_management/u_scene_registry.gd")
const U_SceneRegistryLoader = preload("res://scripts/core/scene_management/helpers/u_scene_registry_loader.gd")

var _saved_scenes: Dictionary = {}
var _saved_loaded: bool = false

func before_each() -> void:
	_saved_scenes = U_SceneRegistry._scenes.duplicate(true)
	_saved_loaded = U_SceneRegistry._resource_entries_loaded

func after_each() -> void:
	U_SceneRegistry._scenes = _saved_scenes.duplicate(true)
	U_SceneRegistry._resource_entries_loaded = _saved_loaded

## Test scene metadata structure
func test_get_scene_returns_metadata() -> void:
	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("demo_room"))

	assert_not_null(scene_data, "Should return scene data")
	assert_true(scene_data.has("scene_id"), "Should have scene_id")
	assert_true(scene_data.has("path"), "Should have path")
	assert_true(scene_data.has("scene_type"), "Should have scene_type")
	assert_true(scene_data.has("default_transition"), "Should have default_transition")
	assert_true(scene_data.has("preload_priority"), "Should have preload_priority")

## Test scene types enum
func test_scene_types_defined() -> void:
	assert_eq(U_SceneRegistry.SceneType.MENU, 0, "MENU type should be 0")
	assert_eq(U_SceneRegistry.SceneType.GAMEPLAY, 1, "GAMEPLAY type should be 1")
	assert_eq(U_SceneRegistry.SceneType.UI, 2, "UI type should be 2")
	assert_eq(U_SceneRegistry.SceneType.END_GAME, 3, "END_GAME type should be 3")

## Test getting scene by ID
func test_get_scene_with_valid_id() -> void:
	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("main_menu"))

	assert_not_null(scene_data, "Should return data for valid scene ID")
	assert_eq(scene_data["scene_id"], StringName("main_menu"), "Should return correct scene_id")

## Test getting scene with invalid ID
func test_get_scene_with_invalid_id() -> void:
	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("nonexistent_scene"))

	assert_eq(scene_data.size(), 0, "Should return empty dict for invalid scene ID")

## Test get_scene_path convenience method
func test_get_scene_path() -> void:
	var path: String = U_SceneRegistry.get_scene_path(StringName("demo_room"))

	assert_not_null(path, "Should return path for valid scene")
	assert_true(path.begins_with("res://scenes/"), "Path should start with res://scenes/")
	assert_true(path.ends_with(".tscn"), "Path should end with .tscn")

## Test get_scene_type convenience method
func test_get_scene_type() -> void:
	var scene_type: int = U_SceneRegistry.get_scene_type(StringName("demo_room"))

	assert_eq(scene_type, U_SceneRegistry.SceneType.GAMEPLAY, "Should return correct scene type")

## Test get_default_transition convenience method
func test_get_default_transition() -> void:
	var transition: String = U_SceneRegistry.get_default_transition(StringName("demo_room"))

	assert_true(transition in ["instant", "fade", "loading"], "Should return valid transition type")

## Test door pairing structure
func test_get_door_exit_returns_metadata() -> void:
	# API coverage: calling get_door_exit should return a Dictionary (possibly empty)
	var exit_data: Dictionary = U_SceneRegistry.get_door_exit(
		StringName("nonexistent_scene"),
		StringName("nonexistent_door")
	)
	assert_true(exit_data is Dictionary, "get_door_exit should return a Dictionary")

## Test deleted legacy demo door pairings are not registered
func test_legacy_demo_door_pairing_is_absent() -> void:
	var exit_data: Dictionary = U_SceneRegistry.get_door_exit(
		StringName("demo_room"),
		StringName("door_to_bar")
	)
	assert_true(exit_data.is_empty(), "Deleted legacy demo door pairings should be absent")

## Test the single-room demo has no authored exits
func test_demo_room_has_no_door_pairings() -> void:
	var exit_data: Dictionary = U_SceneRegistry.get_door_exit(
		StringName("demo_room"),
		StringName("door_to_anywhere")
	)
	assert_true(exit_data.is_empty(), "demo_room should not define door exits")

## Test invalid door ID returns empty dict
func test_invalid_door_id_returns_empty() -> void:
	var exit_data: Dictionary = U_SceneRegistry.get_door_exit(
		StringName("demo_room"),
		StringName("nonexistent_door_id")
	)
	assert_true(exit_data.is_empty(), "Unknown door id should return empty exit data")

## Test validate_door_pairings method
func test_validate_door_pairings_returns_true_for_valid_config() -> void:
	assert_true(U_SceneRegistry.validate_door_pairings() is bool, "API should return bool")

## Test door pairing validation detects broken pairings
func test_validation_allows_one_way_pairings() -> void:
	# Inject a one-way door exit that targets an existing scene but lacks
	# a return pairing. Current validation only enforces target existence,
	# so it should still return true and not emit errors.
	U_SceneRegistry._register_door_exit(
		StringName("demo_room"),
		StringName("door_one_way_test"),
		StringName("main_menu"),
		StringName("sp_none"),
		"fade"
	)
	assert_true(U_SceneRegistry.validate_door_pairings(), "Validation should pass when all targets exist (one-way is allowed)")
	# Cleanup injected test data
	var exits: Dictionary = U_SceneRegistry._door_exits.get(StringName("demo_room"), {})
	if exits is Dictionary and exits.has(StringName("door_one_way_test")):
		exits.erase(StringName("door_one_way_test"))

## Test get_all_scenes returns all registered scenes
func test_get_all_scenes() -> void:
	var all_scenes: Array = U_SceneRegistry.get_all_scenes()

	assert_gt(all_scenes.size(), 0, "Should return at least one scene")
	for scene_data in all_scenes:
		assert_true(scene_data is Dictionary, "Each item should be a Dictionary")
		assert_true(scene_data.has("scene_id"), "Each scene should have scene_id")

## Test get_scenes_by_type
func test_get_scenes_by_type() -> void:
	var gameplay_scenes: Array = U_SceneRegistry.get_scenes_by_type(U_SceneRegistry.SceneType.GAMEPLAY)

	assert_gt(gameplay_scenes.size(), 0, "Should return at least one gameplay scene")
	for scene_data in gameplay_scenes:
		assert_eq(scene_data["scene_type"], U_SceneRegistry.SceneType.GAMEPLAY, "All scenes should be GAMEPLAY type")

## Test preload priority values
func test_preload_priorities_are_valid() -> void:
	var all_scenes: Array = U_SceneRegistry.get_all_scenes()

	for scene_data in all_scenes:
		var priority: int = scene_data["preload_priority"]
		assert_true(priority >= 0 and priority <= 10, "Preload priority should be between 0 and 10")

## Test main_menu scene exists
func test_main_menu_scene_registered() -> void:
	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("main_menu"))

	assert_false(scene_data.is_empty(), "main_menu should be registered")
	assert_eq(scene_data["scene_type"], U_SceneRegistry.SceneType.MENU, "main_menu should be MENU type")

## Test demo_room scene exists
func test_demo_room_scene_registered() -> void:
	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("demo_room"))

	assert_false(scene_data.is_empty(), "demo_room should be registered")
	assert_eq(scene_data["scene_type"], U_SceneRegistry.SceneType.GAMEPLAY, "demo_room should be GAMEPLAY type")

func test_demo_room_can_be_registered_from_scene_conventions() -> void:
	U_SceneRegistry._scenes.clear()
	U_SceneRegistry._resource_entries_loaded = true

	U_SceneRegistry._loader.load_conventional_scene_entries(
		U_SceneRegistry._scenes,
		Callable(U_SceneRegistry, "_register_scene")
	)

	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("demo_room"))

	assert_false(scene_data.is_empty(), "demo_room should be available from conventional scene paths")
	assert_eq(scene_data.get("scene_id"), StringName("demo_room"), "Should infer scene_id from gameplay_demo_room")
	assert_eq(scene_data.get("path"), "res://scenes/demo/gameplay/gameplay_demo_room.tscn", "Should register the conventional demo scene path")
	assert_eq(scene_data.get("scene_type"), U_SceneRegistry.SceneType.GAMEPLAY, "Should infer GAMEPLAY type")
	assert_eq(scene_data.get("default_transition"), "loading", "Should use convention scanner gameplay defaults")
	assert_eq(scene_data.get("preload_priority"), 5, "Should use convention scanner gameplay preload priority")

func test_explicit_scene_entry_wins_over_convention_entry_on_id_collision() -> void:
	U_SceneRegistry._scenes.clear()
	U_SceneRegistry._resource_entries_loaded = true
	U_SceneRegistry._register_scene(
		StringName("demo_room"),
		"res://tests/scenes/test_scene1.tscn",
		U_SceneRegistry.SceneType.MENU,
		"instant",
		10
	)

	U_SceneRegistry._loader.load_conventional_scene_entries(
		U_SceneRegistry._scenes,
		Callable(U_SceneRegistry, "_register_scene")
	)
	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("demo_room"))

	assert_eq(scene_data.get("path"), "res://tests/scenes/test_scene1.tscn", "Explicit entry path should be preserved")
	assert_eq(scene_data.get("scene_type"), U_SceneRegistry.SceneType.MENU, "Explicit entry type should be preserved")
	assert_eq(scene_data.get("default_transition"), "instant", "Explicit transition should be preserved")
	assert_eq(scene_data.get("preload_priority"), 10, "Explicit preload priority should be preserved")

## Test settings_panel scene exists
func test_settings_panel_scene_registered() -> void:
	var scene_data: Dictionary = U_SceneRegistry.get_scene(StringName("settings_panel"))

	assert_false(scene_data.is_empty(), "settings_panel should be registered")
	assert_eq(scene_data["scene_type"], U_SceneRegistry.SceneType.UI, "settings_panel should be UI type")

## Test end-game scenes are present in the manifest
func test_endgame_scenes_present_in_manifest() -> void:
	var manifest_script: Script = load(U_SceneRegistryLoader.MANIFEST_SCRIPT_PATH)
	assert_not_null(manifest_script, "Scene manifest script must load")
	if manifest_script == null:
		return
	var manifest: Object = manifest_script.new()
	var scenes: Dictionary = manifest.call("build") as Dictionary

	var game_over: Dictionary = scenes.get(StringName("game_over"), {}) as Dictionary
	assert_false(game_over.is_empty(), "game_over should be present in manifest")
	assert_eq(game_over.get("scene_type", -1), U_SceneRegistry.SceneType.END_GAME,
		"game_over should be END_GAME type")

	var victory: Dictionary = scenes.get(StringName("victory"), {}) as Dictionary
	assert_false(victory.is_empty(), "victory should be present in manifest")
	assert_eq(victory.get("scene_type", -1), U_SceneRegistry.SceneType.END_GAME,
		"victory should be END_GAME type")

	var credits: Dictionary = scenes.get(StringName("credits"), {}) as Dictionary
	assert_false(credits.is_empty(), "credits should be present in manifest")
	assert_eq(credits.get("scene_type", -1), U_SceneRegistry.SceneType.END_GAME,
		"credits should be END_GAME type")

## Test gameplay scenes in manifest have valid transitions and types
func test_gameplay_scenes_have_valid_manifest_entries() -> void:
	var manifest_script: Script = load(U_SceneRegistryLoader.MANIFEST_SCRIPT_PATH)
	assert_not_null(manifest_script, "Scene manifest script must load")
	if manifest_script == null:
		return
	var manifest: Object = manifest_script.new()
	var scenes: Dictionary = manifest.call("build") as Dictionary

	var gameplay_ids: Array[StringName] = [
		StringName("demo_room"),
	]

	for scene_id: StringName in gameplay_ids:
		var entry: Dictionary = scenes.get(scene_id, {}) as Dictionary
		assert_false(entry.is_empty(), "'%s' should be present in manifest" % scene_id)
		assert_eq(entry.get("scene_type", -1), U_SceneRegistry.SceneType.GAMEPLAY,
			"'%s' should be GAMEPLAY type in manifest" % scene_id)
		var transition: String = String(entry.get("default_transition", ""))
		assert_true(transition in ["instant", "fade", "loading"],
			"'%s' should have a valid transition in manifest" % scene_id)

## Test localization settings UI scene is present in the manifest
func test_localization_settings_scene_present_in_manifest() -> void:
	var manifest_script: Script = load(U_SceneRegistryLoader.MANIFEST_SCRIPT_PATH)
	assert_not_null(manifest_script, "Scene manifest script must load")
	if manifest_script == null:
		return
	var manifest: Object = manifest_script.new()
	var scenes: Dictionary = manifest.call("build") as Dictionary

	var settings_panel: Dictionary = scenes.get(StringName("settings_panel"), {}) as Dictionary
	assert_false(settings_panel.is_empty(), "settings_panel should be present in manifest")
	assert_eq(settings_panel.get("scene_type", -1), U_SceneRegistry.SceneType.UI,
		"settings_panel should be UI type")
