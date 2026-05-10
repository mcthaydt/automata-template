extends GutTest

const GD_DIRECTORIES := [
	"res://scripts/core/gameplay",
	"res://scripts/core",
	"res://scripts/demo",
	"res://scripts/core/utils",
	"res://scripts/core/events",
	"res://scripts/core/scene_structure",
	"res://scripts/core/resources/qb",
	"res://scripts/core/resources/qb/conditions",
	"res://scripts/core/resources/qb/effects",
	"res://scripts/core/resources/scene_director",
	"res://scripts/core/resources/ecs",
	"res://scripts/core/resources/display",
	"res://scripts/core/resources/localization",
	"res://scripts/core/resources/ai",
	"res://scripts/core/debug",
	"res://tests/unit/interactables",
	"res://tests/unit/input",
	"res://tests/unit/lighting",
	"res://tests/unit/style",
	"res://tests/unit/ui"
]

const TRIGGER_RESOURCE_DIRECTORIES := [
	"res://resources/core/triggers"
]

const INTERACTION_RESOURCE_DIRECTORIES := [
	"res://resources/core/interactions"
]

const TRIGGER_RESOURCE_FILES := [
	"res://resources/core/triggers/cfg_scene_trigger_settings.tres"
]

const INTERACTION_RESOURCE_ALLOWED_SUBDIRS := [
	"doors",
	"checkpoints",
	"hazards",
	"victory",
	"signposts",
	"endgame"
]

const PRODUCTION_PATH_DIRECTORIES := [
	"res://assets",
	"res://scenes",
	"res://scripts",
	"res://resources"
]

const UI_POLISHED_OVERLAY_SCENES := [
	"res://scenes/core/ui/menus/ui_pause_menu.tscn",
	"res://scenes/core/ui/overlays/ui_save_load_menu.tscn",
	"res://scenes/core/ui/overlays/ui_input_rebinding_overlay.tscn",
	"res://scenes/core/ui/overlays/ui_input_profile_selector.tscn",
	"res://scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn",
]

const UI_THEME_OVERRIDE_ALLOWED_COUNTS := {
	"res://scenes/core/ui/widgets/ui_virtual_button.tscn": 4,
}

const SCRIPT_FILENAME_EXCEPTIONS := [
	"root.gd" # Root bootstrap script (intentionally unprefixed)
]

const AI_RESOURCE_ALLOWED_SUBDIRECTORIES := [
	"brain",
	"goals",
	"tasks",
	"actions",
	"bt",
]

const BT_RESOURCE_MAX_LINES := 199
const BT_GENERAL_DIR := "res://scripts/core/resources/bt"
const BT_AI_DIR := "res://scripts/core/resources/ai/bt"
const BT_UTILS_DIR := "res://scripts/core/utils/bt"
const BT_PLANNER_PATH := "res://scripts/core/resources/ai/bt/rs_bt_planner.gd"
const BT_PLANNER_SEARCH_PATH := "res://scripts/core/utils/ai/u_bt_planner_search.gd"
const BT_PLANNER_MAX_LINES := 149
const BT_PLANNER_SEARCH_MAX_LINES := 119
const RS_BT_SCORED_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_scored_node.gd"
const RS_BT_SCORED_NODE_MAX_LINES := 50
const U_BT_BUILDER_PATH := "res://scripts/core/utils/bt/u_bt_builder.gd"
const U_BT_BUILDER_MAX_LINES := 100
const U_AI_BT_FACTORY_PATH := "res://scripts/core/utils/ai/u_ai_bt_factory.gd"
const U_AI_BT_FACTORY_MAX_LINES := 200
const U_EDITOR_PREFAB_BUILDER_PATH := "res://scripts/core/utils/editors/u_editor_prefab_builder.gd"
const U_EDITOR_PREFAB_BUILDER_MAX_LINES := 200
const U_EDITOR_BLOCKOUT_BUILDER_PATH := "res://scripts/core/utils/editors/u_editor_blockout_builder.gd"
const U_EDITOR_BLOCKOUT_BUILDER_MAX_LINES := 200
const U_SETTINGS_TAB_BUILDER_PATH := "res://scripts/core/ui/helpers/u_settings_tab_builder.gd"
const U_SETTINGS_TAB_BUILDER_MAX_LINES := 300
const U_UI_MENU_BUILDER_PATH := "res://scripts/core/ui/helpers/u_ui_menu_builder.gd"
const U_UI_MENU_BUILDER_MAX_LINES := 200
const UI_INPUT_REBINDING_OVERLAY_PATH := "res://scripts/core/ui/overlays/ui_input_rebinding_overlay.gd"
const UI_INPUT_REBINDING_OVERLAY_MAX_LINES := 500
const UI_INPUT_PROFILE_SELECTOR_PATH := "res://scripts/core/ui/overlays/ui_input_profile_selector.gd"
const UI_INPUT_PROFILE_SELECTOR_MAX_LINES := 420
const U_UI_SETTINGS_CATALOG_PATH := "res://scripts/core/ui/helpers/u_ui_settings_catalog.gd"
const U_UI_SETTINGS_CATALOG_MAX_LINES := 180
const WIDGET_DIR := "res://scripts/core/ui/widgets"
const WIDGET_MAX_LINES := 120
const BT_GENERAL_FORBIDDEN_TOKENS := [
	"U_AI",
	"I_AIAction",
	"I_Condition",
	"U_AITaskStateKeys",
	"RS_WorldStateEffect",
	"RS_BTPlanner",
	"RS_BTPlannerAction",
]

const REQUIRED_EXTENSION_RECIPES := [
	"ai.md",
	"state.md",
	"vcam.md",
	"ecs.md",
	"managers.md",
	"ui.md",
	"scenes.md",
	"save.md",
	"input.md",
	"audio.md",
	"objectives.md",
	"conditions_effects_rules.md",
	"events.md",
	"debug.md",
	"display_post_process.md",
	"localization.md",
	"resources.md",
	"tests.md",
	"builders.md",
]

# Valid prefixes by directory
const SCRIPT_PREFIX_RULES := {
	"res://scripts/core": ["u_"],
	"res://scripts/core/interfaces": ["i_"],
	"res://scripts/core/managers": ["m_"],
	"res://scripts/demo/gameplay": ["inter_", "s_"],
	"res://scripts/core/utils": ["u_"],
	"res://scripts/core/input": ["u_", "i_"],
	"res://scripts/core/input/sources": [""], # Wildcard: validated by suffix rule (see test_input_source_scripts_follow_suffix_rule)
	"res://scripts/core/resources/input/profiles": [""],
	"res://scripts/core/resources/input": ["rs_"],
	"res://scripts/core/resources/interactions": ["rs_"],
	"res://scripts/core/resources/lighting": ["rs_"], # Character lighting resources
	"res://scripts/core/resources": ["rs_"],
	"res://scripts/core/resources/managers": ["rs_"],
	"res://scripts/core/resources/bt": ["rs_"],
	"res://scripts/core/resources/ai/bt": ["rs_"],
	"res://scripts/core/resources/ai/bt/scorers": ["rs_"],
	"res://scripts/core/managers/helpers": ["u_"],
	"res://scripts/core/ecs/systems": ["s_", "base_"], # s_*_system.gd plus base system scripts
	"res://scripts/core/ecs/systems/helpers": ["u_"], # vCam/system helper utilities
	"res://scripts/core/ecs/components": ["c_"],
	"res://scripts/core/ecs/resources": ["rs_"],
	"res://scripts/core/events/ecs": ["evn_", "base_", "u_"], # evn_ for typed events, base_ for BaseECSEvent, u_ for ECS event bus/names
	"res://scripts/core/events/state": ["u_"], # u_state_event_bus.gd
	"res://scripts/core/ecs": ["base_", "u_"], # base_ecs_*.gd files, base_event_vfx_system.gd, u_entity_query.gd
	"res://scripts/core/ecs/markers": ["marker_"],
	"res://scripts/core/state/actions": ["u_"],
	"res://scripts/core/state/reducers": ["u_"],
	"res://scripts/core/state/selectors": ["u_"],
	"res://scripts/core/resources/state": ["rs_"], # State initial state resources
	"res://scripts/core/resources/qb": ["rs_"], # QB base condition/effect/rule resources
	"res://scripts/core/resources/qb/conditions": ["rs_"], # QB condition resources
	"res://scripts/core/resources/qb/effects": ["rs_"], # QB effect resources
	"res://scripts/core/qb/rules": ["br_"], # QB rule builder scripts
	"res://scripts/core/utils/scene_director": ["br_", "u_"], # br_ for directive builders, u_ for SD utilities
	"res://scripts/core/resources/scene_director": ["rs_"], # Scene director beat/objective/directive resources
	"res://scripts/core/resources/ecs": ["rs_"], # ECS component settings resources
	"res://scripts/core/resources/display": ["rs_"], # Display preset resources
	"res://scripts/core/resources/localization": ["rs_"], # Localization resources
	"res://scripts/core/resources/ai": ["rs_"], # AI resources
	"res://scripts/core/resources/ai/actions": ["rs_"], # AI action resources
	"res://scripts/core/debug": ["debug_"], # Debug utility scripts
	"res://scripts/core/state": ["u_", "m_"], # m_state_store.gd is in root
	"res://scripts/core/resources/ui": ["rs_"], # UI screen definitions
	"res://scripts/core/ui/base": ["base_"], # base_*.gd UI base classes
	"res://scripts/core/ui/settings": ["ui_", "base_"], # ui_ for overlays, base_ for shared overlay base
	"res://scripts/core/ui/utils": ["u_"], # UI utilities
	"res://scripts/core/ui": ["ui_", "u_"], # ui_ for controllers, u_ for utilities
	"res://scripts/core/gameplay/helpers": ["u_"], # gameplay helper utilities
	"res://scripts/core/ui/widgets": ["w_"], # w_* widget scripts
	"res://scripts/core/gameplay": ["e_", "inter_", "base_", "triggered_", "s_", "l_"], # e_ for entities, inter_ for interactable controllers, base_ for base controllers, triggered_ for special controllers, s_ for gameplay-scoped ECS systems
	"res://scripts/core/scene_structure": ["marker_"], # marker_*.gd organizational scripts
	"res://scripts/core/scene_management/transitions": ["trans_", "base_"], # transition effects
	"res://scripts/core/resources/scene_management": ["rs_"], # scene registry resources
	"res://scripts/core/scene_management/handlers": ["h_"], # Scene type handlers (Phase 10B-3)
	"res://scripts/core/scene_management": ["u_", "sp_"], # u_scene_registry.gd, u_transition_factory.gd, sp_spawn_point.gd
	"res://scripts/core/events": ["base_"], # base_event_bus.gd
}

func test_gd_files_use_tab_indentation() -> void:
	var offenses: Array[String] = []
	for dir_path in GD_DIRECTORIES:
		_collect_gd_spacing_offenses(dir_path, offenses)
	assert_eq(offenses.size(), 0,
		"All .gd files should use tab indentation. Offending lines:\n%s" % "\n".join(offenses))

func test_trigger_resources_define_script_reference() -> void:
	var missing: Array[String] = []
	for dir_path in TRIGGER_RESOURCE_DIRECTORIES:
		_collect_tres_without_script(dir_path, missing)
	for file_path in TRIGGER_RESOURCE_FILES:
		if not _resource_has_script_reference(file_path):
			missing.append(file_path)
	assert_eq(missing.size(), 0,
		"Trigger settings resources must include script = ExtResource(). Missing:\n%s" % "\n".join(missing))

func test_interaction_resources_define_script_reference() -> void:
	var missing: Array[String] = []
	for dir_path in INTERACTION_RESOURCE_DIRECTORIES:
		_collect_tres_without_script(dir_path, missing)
	assert_eq(missing.size(), 0,
		"Interaction config resources must include script = ExtResource(). Missing:\n%s" % "\n".join(missing))

func _collect_gd_spacing_offenses(dir_path: String, offenses: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_spacing_offenses("%s/%s" % [dir_path, entry], offenses)
		elif entry.ends_with(".gd"):
			_scan_gd_file("%s/%s" % [dir_path, entry], offenses)
		entry = dir.get_next()
	dir.list_dir_end()

func _scan_gd_file(path: String, offenses: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		var line := file.get_line()
		if line.begins_with(" ") and not line.strip_edges().is_empty():
			offenses.append("%s:%d" % [path, line_number])
	file.close()

func _collect_tres_without_script(dir_path: String, missing: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_tres_without_script("%s/%s" % [dir_path, entry], missing)
		elif entry.ends_with(".tres"):
			var path := "%s/%s" % [dir_path, entry]
			if not _resource_has_script_reference(path):
				missing.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

func _resource_has_script_reference(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var has_script := false
	while not file.eof_reached():
		if file.get_line().strip_edges().begins_with("script = ExtResource"):
			has_script = true
			break
	file.close()
	return has_script

func _collect_paths_with_spaces(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if entry.find(" ") != -1:
			violations.append(path)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_paths_with_spaces(path, violations)
		entry = dir.get_next()
	dir.list_dir_end()

# ============================================================================
# Phase 4 - Comprehensive Prefix Validation Tests
# ============================================================================

func test_scripts_follow_prefix_conventions() -> void:
	var violations: Array[String] = []

	# Check each directory with prefix rules
	for dir_path in SCRIPT_PREFIX_RULES.keys():
		_check_directory_prefixes(dir_path, SCRIPT_PREFIX_RULES[dir_path], violations)

	var message := "Scripts must follow documented prefix conventions"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nSee STYLE_GUIDE.md for complete prefix matrix."
	else:
		message += " - all scripts compliant!"

	assert_eq(violations.size(), 0, message)

func test_input_source_scripts_follow_suffix_rule() -> void:
	var violations: Array[String] = []

	_check_script_suffix_directory("res://scripts/core/input/sources", "_source.gd", violations)

	var message := "Input sources must follow documented naming patterns"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nSee STYLE_GUIDE.md input sources section."
	else:
		message += " - all input sources compliant!"

	assert_eq(violations.size(), 0, message)

func test_scenes_follow_naming_conventions() -> void:
	var violations: Array[String] = []

	# Check core gameplay scenes
	_check_scene_directory("res://scenes/core/gameplay", "gameplay_", violations)

	# Check core UI scenes
	_check_scene_directory("res://scenes/core/ui", "ui_", violations)

	# Check core prefab scenes
	_check_scene_directory("res://scenes/core/prefabs", "prefab_", violations)

	# Check core debug scenes
	_check_scene_directory("res://scenes/core/debug", "debug_", violations)

	var message := "Scene files must follow documented naming patterns"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nSee STYLE_GUIDE.md scene naming table."
	else:
		message += " - all scenes compliant!"

	assert_eq(violations.size(), 0, message)

func test_resources_follow_naming_conventions() -> void:
	var violations: Array[String] = []

	# Check UI screen definitions
	_check_resource_directory("res://resources/core/ui_screens",
		["_screen.tres", "_overlay.tres"], violations)

	# Interaction config instances
	_check_resource_directory("res://resources/core/interactions", ["cfg_"], violations)

	# Interaction config placement (must be in typed subdirectories)
	_collect_interaction_resource_placement_violations("res://resources/core/interactions", violations)

	# Scene registry entries don't need strict naming - just verify they exist and have scripts
	# (handled by test_trigger_resources_define_script_reference)

	# Check settings resources (non-strict, just informational)
	# Resources can have various naming patterns, so we don't enforce strict rules here

	var message := "Resource files must follow documented naming patterns"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nSee STYLE_GUIDE.md resource naming table."
	else:
		message += " - all resources compliant!"

	assert_eq(violations.size(), 0, message)

func test_production_paths_have_no_spaces() -> void:
	var violations: Array[String] = []

	for dir_path in PRODUCTION_PATH_DIRECTORIES:
		_collect_paths_with_spaces(dir_path, violations)

	var message := "Production res:// paths must not include spaces"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nRename files/directories to remove spaces."
	else:
		message += " - all paths compliant!"

	assert_eq(violations.size(), 0, message)

func test_polished_overlay_scenes_have_no_inline_theme_overrides() -> void:
	var violations: Array[String] = []

	for scene_path in UI_POLISHED_OVERLAY_SCENES:
		var override_count: int = _count_theme_override_lines(scene_path)
		if override_count > 0:
			violations.append("%s (%d inline theme_override_ lines)" % [scene_path, override_count])

	var message := "Polished overlay scenes should not regress to inline theme_override_* styling"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\nUse RS_UIThemeConfig tokens in script/theme builder instead."

	assert_eq(violations.size(), 0, message)

func test_no_inline_theme_overrides_except_semantic() -> void:
	var override_counts: Dictionary = {}
	_collect_scene_theme_override_counts("res://scenes/core/ui", override_counts)

	var total_override_count: int = 0
	var violations: Array[String] = []
	var scene_paths: Array[String] = []
	for path_variant in override_counts.keys():
		scene_paths.append(str(path_variant))
	scene_paths.sort()

	for scene_path in scene_paths:
		var override_count: int = int(override_counts.get(scene_path, 0))
		total_override_count += override_count
		var allowed_count: int = int(UI_THEME_OVERRIDE_ALLOWED_COUNTS.get(scene_path, 0))
		if override_count > allowed_count:
			violations.append("%s (%d inline theme_override_ lines; allowed %d)" % [scene_path, override_count, allowed_count])

	var violations_message := "UI scenes should avoid inline theme_override_* except semantic exceptions"
	if violations.size() > 0:
		violations_message += ":\n" + "\n".join(violations)
		violations_message += "\nUse RS_UIThemeConfig tokens and script-applied overrides instead."
	assert_eq(violations.size(), 0, violations_message)

	assert_lte(
		total_override_count,
		4,
		"Expected <= 4 total inline theme_override_* lines under scenes/core/ui (semantic virtual-button overrides only), got %d" % total_override_count
	)

func test_scene_organization_root_structure() -> void:
	var root_scene := load("res://scenes/core/root.tscn") as PackedScene
	assert_not_null(root_scene, "Root scene must exist")

	# Use PackedScene.get_state() to check node structure without instantiation
	# This avoids runtime initialization issues (M_TimeManager warnings, ServiceLocator conflicts)
	var scene_state := root_scene.get_state()

	var has_managers := false
	var has_state_store := false
	var has_scene_manager := false
	var has_cursor_manager := false
	var has_time_manager := false
	var has_screenshot_cache := false
	var has_character_lighting_manager := false
	var has_active_scene_container := false
	var has_ui_overlay_stack := false

	for i in range(scene_state.get_node_count()):
		var node_name := scene_state.get_node_name(i)
		var node_path := scene_state.get_node_path(i)
		var path_str := str(node_path)

		if node_name == "Managers":
			has_managers = true
		elif node_name == "M_StateStore" and path_str.contains("Managers"):
			has_state_store = true
		elif node_name == "M_SceneManager" and path_str.contains("Managers"):
			has_scene_manager = true
		elif node_name == "M_CursorManager" and path_str.contains("Managers"):
			has_cursor_manager = true
		elif node_name == "M_TimeManager" and path_str.contains("Managers"):
			has_time_manager = true
		elif node_name == "M_ScreenshotCacheManager" and path_str.contains("Managers"):
			has_screenshot_cache = true
		elif node_name == "M_CharacterLightingManager" and path_str.contains("Managers"):
			has_character_lighting_manager = true
		elif node_name == "ActiveSceneContainer":
			has_active_scene_container = true
		elif node_name == "UIOverlayStack":
			has_ui_overlay_stack = true

	assert_true(has_managers, "Root scene must have Managers node")
	assert_true(has_state_store, "Root scene must have M_StateStore in Managers")
	assert_true(has_scene_manager, "Root scene must have M_SceneManager in Managers")
	assert_true(has_cursor_manager, "Root scene must have M_CursorManager in Managers")
	assert_true(has_time_manager, "Root scene must have M_TimeManager in Managers")
	assert_true(has_screenshot_cache, "Root scene must have M_ScreenshotCacheManager in Managers")
	assert_true(has_character_lighting_manager, "Root scene must have M_CharacterLightingManager in Managers")
	assert_true(has_active_scene_container, "Root scene must have ActiveSceneContainer")
	assert_true(has_ui_overlay_stack, "Root scene must have UIOverlayStack")

func test_scene_organization_gameplay_structure() -> void:
	var gameplay_base := load("res://scenes/core/gameplay/gameplay_base.tscn") as PackedScene
	assert_not_null(gameplay_base, "Gameplay base scene must exist")

	# Inspect the packed scene's state directly to avoid runtime initialization issues
	var scene_state := gameplay_base.get_state()

	# Find required nodes by name in the scene tree
	var has_managers := false
	var has_systems := false
	var has_entities := false
	var has_spawn_points_in_entities := false
	var entities_node_path := ""

	for i in range(scene_state.get_node_count()):
		var node_name := scene_state.get_node_name(i)
		var node_path := scene_state.get_node_path(i)

		if node_name == "Managers":
			has_managers = true
		elif node_name == "Systems":
			has_systems = true
		elif node_name == "Entities":
			has_entities = true
			entities_node_path = str(node_path)
		elif node_name == "SpawnPoints":
			# Check if spawn points are under Entities
			var path_str := str(node_path)
			if path_str.begins_with(entities_node_path + "/") or path_str.contains("Entities/"):
				has_spawn_points_in_entities = true

	assert_true(has_managers, "Gameplay scene must have Managers node")
	assert_true(has_systems, "Gameplay scene must have Systems node")
	assert_true(has_entities, "Gameplay scene must have Entities node")
	assert_true(has_spawn_points_in_entities,
		"Spawn points must be under Entities node per SCENE_ORGANIZATION_GUIDE.md")

func test_character_template_defines_camera_follow_anchor() -> void:
	var character_scene := load("res://scenes/core/templates/tmpl_character.tscn") as PackedScene
	assert_not_null(character_scene, "Character template scene must exist")

	var character_instance := character_scene.instantiate() as Node
	assert_not_null(character_instance, "Character template must instantiate")
	add_child_autofree(character_instance)

	var follow_anchor := character_instance.get_node_or_null("Player_Body/CameraFollowAnchor") as Node3D
	assert_not_null(
		follow_anchor,
		"tmpl_character.tscn must define Player_Body/CameraFollowAnchor for vCam follow targeting"
	)
	if follow_anchor != null:
		assert_eq(
			follow_anchor.transform.origin,
			Vector3(0, 0.64, 0),
			"CameraFollowAnchor should be at half sprite height (0.64) for vCam follow targeting"
		)

func test_camera_template_uses_camera_follow_anchor_path() -> void:
	var camera_scene := load("res://scenes/core/templates/tmpl_camera.tscn") as PackedScene
	assert_not_null(camera_scene, "Camera template scene must exist")

	var camera_instance := camera_scene.instantiate() as Node
	assert_not_null(camera_instance, "Camera template must instantiate")
	add_child_autofree(camera_instance)

	var vcam_component := camera_instance.get_node_or_null("Components/C_VCamComponent")
	assert_not_null(vcam_component, "tmpl_camera.tscn must include Components/C_VCamComponent")
	if vcam_component != null:
		assert_eq(
			vcam_component.follow_target_path,
			NodePath("../../../E_Player/Player_Body/CameraFollowAnchor"),
			"C_VCamComponent.follow_target_path should target CameraFollowAnchor"
		)

func test_prefab_player_inherits_camera_follow_anchor() -> void:
	var player_prefab := load("res://scenes/core/prefabs/prefab_player.tscn") as PackedScene
	assert_not_null(player_prefab, "Player prefab scene must exist")

	var player_instance := player_prefab.instantiate() as Node
	assert_not_null(player_instance, "Player prefab must instantiate")
	add_child_autofree(player_instance)

	var follow_anchor := player_instance.get_node_or_null("Player_Body/CameraFollowAnchor") as Node3D
	assert_not_null(
		follow_anchor,
		"prefab_player.tscn must include Player_Body/CameraFollowAnchor (inherited from tmpl_character)"
	)
	if follow_anchor != null:
		assert_eq(
			follow_anchor.transform.origin,
			Vector3(0, 0.64, 0),
			"CameraFollowAnchor should be at half sprite height (0.64) for vCam follow targeting"
		)

func test_gameplay_scenes_do_not_embed_hud_instances() -> void:
	var violations: Array[String] = []
	_collect_gameplay_hud_embedding_violations("res://scenes/gameplay", violations)

	var message := "Gameplay scenes must not embed HUD instances (HUD is root-managed by M_SceneManager)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)

	assert_eq(violations.size(), 0, message)

func test_vcam_debug_logging_not_enabled_in_authored_scenes() -> void:
	var violations: Array[String] = []
	_collect_scene_text_match_violations("res://scenes/gameplay", "debug_rotation_logging = true", violations)
	_collect_scene_text_match_violations("res://scenes/templates", "debug_rotation_logging = true", violations)

	var message := "Authored scenes must not enable S_VCamSystem debug_rotation_logging"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)

	assert_eq(violations.size(), 0, message)

func test_ai_move_target_magic_strings_not_used_in_ai_scripts() -> void:
	var violations: Array[String] = []
	_collect_gd_literal_occurrences("res://scripts/core/resources/ai", "\"ai_move_target\"", violations)
	_collect_gd_literal_occurrences("res://scripts/core/ecs/systems", "\"ai_move_target\"", violations, "s_ai_")

	var message := "AI scripts should not use bare \"ai_move_target\" string literals"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\nUse U_AITaskStateKeys constants instead."
	assert_eq(violations.size(), 0, message)

func test_ai_action_scripts_use_task_state_key_constants() -> void:
	var violations: Array[String] = []
	_collect_gd_literal_occurrences("res://scripts/core/resources/ai/actions", "task_state[\"", violations)
	_collect_gd_literal_occurrences("res://scripts/core/utils/ai", "task_state[\"", violations)

	var message := "AI scripts should not use bare string keys for task_state access"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\nUse U_AITaskStateKeys constants instead."
	assert_eq(violations.size(), 0, message)

func test_ai_resource_scripts_are_grouped_by_subdirectory() -> void:
	var violations: Array[String] = []
	_collect_ai_resource_layout_violations("res://scripts/core/resources/ai", violations)

	var message := "AI resource scripts must live under scripts/core/resources/ai/{brain,goals,tasks,actions}"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_bt_resource_scripts_stay_under_two_hundred_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_file_line_limit_violations(BT_GENERAL_DIR, BT_RESOURCE_MAX_LINES, violations)
	_collect_gd_file_line_limit_violations(BT_AI_DIR, BT_RESOURCE_MAX_LINES, violations)

	var message := "BT resource scripts should stay under 200 lines each"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_bt_general_resources_do_not_reference_ai_specific_types() -> void:
	var violations: Array[String] = []
	_collect_gd_forbidden_token_violations(BT_GENERAL_DIR, BT_GENERAL_FORBIDDEN_TOKENS, violations)

	var message := "General BT resources must not import AI-specific interfaces/utilities/types"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_bt_general_utils_do_not_reference_ai_specific_types() -> void:
	var violations: Array[String] = []
	_collect_gd_forbidden_token_violations(BT_UTILS_DIR, BT_GENERAL_FORBIDDEN_TOKENS, violations)

	var message := "General BT utils must not import AI-specific interfaces/utilities/types"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_bt_general_does_not_reference_planner_runtime_utils() -> void:
	const PLANNER_UTIL_TOKENS: Array[String] = [
		"U_BTPlannerSearch",
		"U_BTPlannerRuntime",
	]
	var violations: Array[String] = []
	_collect_gd_forbidden_token_violations(BT_GENERAL_DIR, PLANNER_UTIL_TOKENS, violations)
	_collect_gd_forbidden_token_violations(BT_UTILS_DIR, PLANNER_UTIL_TOKENS, violations)

	var message := "General BT resources/utils must not reference planner runtime utilities (U_BTPlannerSearch, U_BTPlannerRuntime)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_bt_planner_scripts_stay_within_loc_caps() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(BT_PLANNER_PATH, BT_PLANNER_MAX_LINES, violations)
	_collect_gd_single_file_line_limit_violation(BT_PLANNER_SEARCH_PATH, BT_PLANNER_SEARCH_MAX_LINES, violations)

	var message := "Planner scripts must stay within enforced LOC caps"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_rs_bt_scored_node_stays_under_fifty_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(RS_BT_SCORED_NODE_PATH, RS_BT_SCORED_NODE_MAX_LINES, violations)
	var message := "RS_BTScoredNode must stay under 50 lines (it is a thin decorator — keep it minimal)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_u_bt_builder_stays_under_one_hundred_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(U_BT_BUILDER_PATH, U_BT_BUILDER_MAX_LINES, violations)
	var message := "U_BTBuilder must stay under 100 lines (pure factory methods — no logic)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_u_ai_bt_factory_stays_under_two_hundred_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(U_AI_BT_FACTORY_PATH, U_AI_BT_FACTORY_MAX_LINES, violations)
	var message := "U_AIBTFactory must stay under 200 lines (pure factory methods — no logic)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_u_editor_prefab_builder_stays_under_two_hundred_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(U_EDITOR_PREFAB_BUILDER_PATH, U_EDITOR_PREFAB_BUILDER_MAX_LINES, violations)
	var message := "U_EditorPrefabBuilder must stay under 200 lines (core builder API — delegate shape logic to U_EditorShapeFactory)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_u_editor_blockout_builder_stays_under_two_hundred_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(U_EDITOR_BLOCKOUT_BUILDER_PATH, U_EDITOR_BLOCKOUT_BUILDER_MAX_LINES, violations)
	var message := "U_EditorBlockoutBuilder must stay under 200 lines (core blockout API — keep focused)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_u_settings_tab_builder_stays_under_three_hundred_twenty_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(U_SETTINGS_TAB_BUILDER_PATH, 320, violations)
	var message := "U_SettingsTabBuilder must stay under 320 lines (fluent builder — delegate to helpers)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_u_ui_menu_builder_stays_under_two_hundred_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(U_UI_MENU_BUILDER_PATH, U_UI_MENU_BUILDER_MAX_LINES, violations)
	var message := "U_UIMenuBuilder must stay under 200 lines (fluent builder — keep focused)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_input_builder_migration_overlays_stay_under_line_caps() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(
		UI_INPUT_REBINDING_OVERLAY_PATH,
		UI_INPUT_REBINDING_OVERLAY_MAX_LINES,
		violations
	)
	_collect_gd_single_file_line_limit_violation(
		UI_INPUT_PROFILE_SELECTOR_PATH,
		UI_INPUT_PROFILE_SELECTOR_MAX_LINES,
		violations
	)
	var message := "Input builder migration overlays must stay under their Phase 9/10 line caps"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_u_ui_settings_catalog_stays_under_one_hundred_eighty_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_single_file_line_limit_violation(U_UI_SETTINGS_CATALOG_PATH, U_UI_SETTINGS_CATALOG_MAX_LINES, violations)
	var message := "U_UISettingsCatalog must stay under 180 lines (static data utility — keep minimal)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_widget_files_stay_under_one_hundred_twenty_lines() -> void:
	var violations: Array[String] = []
	_collect_gd_file_line_limit_violations(WIDGET_DIR, WIDGET_MAX_LINES, violations)
	var message := "W_* widget files must stay under 120 lines (single-responsibility components)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_ecs_system_filenames_do_not_include_demo_marker() -> void:
	var violations: Array[String] = []
	_collect_gd_filename_substring_violations("res://scripts/core/ecs/systems", "_demo_", violations)

	var message := "ECS system scripts under scripts/core/ecs/systems must not include '_demo_' in filename"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_save_manager_has_no_bare_print_calls() -> void:
	var save_manager_path := "res://scripts/core/managers/m_save_manager.gd"
	var file := FileAccess.open(save_manager_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % save_manager_path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"m_save_manager.gd must not contain bare print() calls; route through U_DebugLogThrottle or remove non-actionable logs"
	)

func test_vcam_manager_has_no_bare_print_calls() -> void:
	var vcam_manager_path := "res://scripts/core/managers/m_vcam_manager.gd"
	var file := FileAccess.open(vcam_manager_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % vcam_manager_path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"m_vcam_manager.gd must not contain bare print() calls; route through throttled/verbose debug helpers"
	)

func test_run_coordinator_manager_has_no_bare_print_calls() -> void:
	var run_coordinator_path := "res://scripts/core/managers/m_run_coordinator_manager.gd"
	var file := FileAccess.open(run_coordinator_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % run_coordinator_path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"m_run_coordinator_manager.gd must not contain bare print() calls; route warnings through push_warning()"
	)

func test_scene_manager_has_no_bare_print_calls() -> void:
	var scene_manager_path := "res://scripts/core/managers/m_scene_manager.gd"
	var file := FileAccess.open(scene_manager_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % scene_manager_path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"m_scene_manager.gd must not contain bare print() calls; route debug traces through verbose/throttled helpers"
	)

func test_scene_director_manager_has_no_bare_print_calls() -> void:
	var scene_director_manager_path := "res://scripts/core/managers/m_scene_director_manager.gd"
	var file := FileAccess.open(scene_director_manager_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % scene_director_manager_path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"m_scene_director_manager.gd must not contain bare print() calls; route diagnostics through verbose helpers"
	)

func test_vcam_collision_detector_has_no_bare_print_calls() -> void:
	var collision_detector_path := "res://scripts/core/managers/helpers/u_vcam_collision_detector.gd"
	var file := FileAccess.open(collision_detector_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % collision_detector_path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"u_vcam_collision_detector.gd must not contain bare print() calls; route debug output through verbose/throttled helpers"
	)

func test_victory_handler_system_has_no_bare_print_calls() -> void:
	var victory_handler_path := "res://scripts/core/ecs/systems/s_victory_handler_system.gd"
	var file := FileAccess.open(victory_handler_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % victory_handler_path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"s_victory_handler_system.gd must not contain bare print() calls; route debug output through print_verbose()/shared debug helpers"
	)

func test_spawn_recovery_system_has_no_bare_print_calls() -> void:
	var spawn_recovery_path := "res://scripts/core/ecs/systems/s_spawn_recovery_system.gd"
	var file := FileAccess.open(spawn_recovery_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % spawn_recovery_path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"s_spawn_recovery_system.gd must not contain bare print() calls; route debug output through print_verbose()/shared debug helpers"
	)

func test_gravity_system_has_no_bare_print_calls() -> void:
	var gravity_system_path := "res://scripts/core/ecs/systems/s_gravity_system.gd"
	var file := FileAccess.open(gravity_system_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % gravity_system_path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"s_gravity_system.gd must not contain bare print() calls; route debug output through print_verbose()/shared debug helpers"
	)

func test_floating_system_has_no_direct_print_calls() -> void:
	_assert_file_has_no_direct_print_calls(
		"res://scripts/core/ecs/systems/s_floating_system.gd",
		"s_floating_system.gd"
	)

func test_input_system_has_no_direct_print_calls() -> void:
	_assert_file_has_no_direct_print_calls(
		"res://scripts/core/ecs/systems/s_input_system.gd",
		"s_input_system.gd"
	)

func test_movement_system_has_no_direct_print_calls() -> void:
	_assert_file_has_no_direct_print_calls(
		"res://scripts/core/ecs/systems/s_movement_system.gd",
		"s_movement_system.gd"
	)

func test_rotate_to_input_system_has_no_direct_print_calls() -> void:
	_assert_file_has_no_direct_print_calls(
		"res://scripts/core/ecs/systems/s_rotate_to_input_system.gd",
		"s_rotate_to_input_system.gd"
	)

func test_vcam_debug_helper_has_no_direct_print_calls() -> void:
	_assert_file_has_no_direct_print_calls(
		"res://scripts/core/ecs/systems/helpers/u_vcam_debug.gd",
		"u_vcam_debug.gd"
	)

func test_vcam_look_input_helper_has_no_direct_print_calls() -> void:
	_assert_file_has_no_direct_print_calls(
		"res://scripts/core/ecs/systems/helpers/u_vcam_look_input.gd",
		"u_vcam_look_input.gd"
	)

func test_vcam_look_spring_helper_has_no_direct_print_calls() -> void:
	_assert_file_has_no_direct_print_calls(
		"res://scripts/core/ecs/systems/helpers/u_vcam_look_spring.gd",
		"u_vcam_look_spring.gd"
	)

func test_rule_systems_do_not_define_local_rule_pipeline_helpers() -> void:
	var context_builders: Array[String] = [
		"res://scripts/core/ecs/systems/s_camera_state_system.gd",
		"res://scripts/core/ecs/systems/s_character_state_system.gd",
		"res://scripts/core/ecs/systems/s_game_event_system.gd",
		"res://scripts/core/managers/m_objectives_manager.gd",
		"res://scripts/core/managers/m_scene_director_manager.gd",
	]
	var forbidden_methods: Array[String] = [
		"_refresh_active_rules",
		"_get_applicable_rules",
		"_apply_state_gates",
		"_mark_fired_rules",
	]
	var violations: Array[String] = []

	for path in context_builders:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			violations.append("%s (unable to open file)" % path)
			continue
		var file_text: String = file.get_as_text()
		file.close()

		for method_name in forbidden_methods:
			var signature: String = "func %s(" % method_name
			if file_text.find(signature) != -1:
				violations.append("%s defines %s" % [path, method_name])

	var message := "Rule systems should use shared U_RuleEvaluator pipeline helpers"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func _assert_file_has_no_direct_print_calls(path: String, label: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_false(
		text.find("print(") != -1,
		"%s must not contain bare print() calls; route debug output through U_DebugLogThrottle/shared helpers" % label
	)
	assert_false(
		text.find("print_verbose(") != -1,
		"%s must not call print_verbose() directly; route debug output through U_DebugLogThrottle/shared helpers" % label
	)

func test_rule_systems_and_helpers_do_not_duplicate_property_readers() -> void:
	var affected_files: Array[String] = [
		"res://scripts/core/ecs/systems/s_camera_state_system.gd",
		"res://scripts/core/ecs/systems/s_character_state_system.gd",
		"res://scripts/core/ecs/systems/s_game_event_system.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_runtime_context.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_landing_impact.gd",
		"res://scripts/core/utils/qb/u_rule_validator.gd",
		"res://scripts/core/utils/qb/u_rule_scorer.gd",
		"res://scripts/core/utils/qb/u_rule_selector.gd",
	]
	var forbidden_methods: Array[String] = [
		"_read_string_property",
		"_read_string_name_property",
		"_read_bool_property",
		"_read_float_property",
		"_read_int_property",
		"_read_array_property",
		"_is_script_instance_of",
		"_object_has_property",
		"_variant_to_string_name",
		"_get_context_value",
		"_extract_event_names_from_rule",
	]
	var violations: Array[String] = []

	for path in affected_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			violations.append("%s (unable to open file)" % path)
			continue
		var file_text: String = file.get_as_text()
		file.close()

		for method_name in forbidden_methods:
			var signature: String = "func %s(" % method_name
			if file_text.find(signature) != -1:
				violations.append("%s defines %s" % [path, method_name])

	var message := "Rule systems and helpers should use shared U_RuleUtils property readers"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_rule_systems_do_not_use_bare_string_context_keys() -> void:
	var context_builders: Array[String] = [
		"res://scripts/core/ecs/systems/s_camera_state_system.gd",
		"res://scripts/core/ecs/systems/s_character_state_system.gd",
		"res://scripts/core/ecs/systems/s_game_event_system.gd",
		"res://scripts/core/managers/m_objectives_manager.gd",
		"res://scripts/core/managers/m_scene_director_manager.gd",
	]
	# Forbidden: context["key"] or context.get("key") with bare string keys
	# Allowed: context[RSRuleContext.KEY_*]
	var forbidden_patterns: Array[String] = [
		'context["',
		"context.get(\"",
		"context.has(\"",
		"context.erase(\"",
	]
	var allowed_patterns: Array[String] = [
		"context[RSRuleContext",
		"context.get(RSRuleContext",
		"context.has(RSRuleContext",
		"context.erase(RSRuleContext",
	]
	var violations: Array[String] = []

	for path in context_builders:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			violations.append("%s (unable to open file)" % path)
			continue
		var line_number: int = 0
		while not file.eof_reached():
			line_number += 1
			var line: String = file.get_line()
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue

			for forbidden in forbidden_patterns:
				if line.find(forbidden) == -1:
					continue
				var is_allowed := false
				for allowed in allowed_patterns:
					if line.find(allowed) != -1:
						is_allowed = true
						break
				if not is_allowed:
					violations.append("%s:%d uses bare string context key: %s" % [path, line_number, stripped])
		file.close()

	var message := "Context builders should use RSRuleContext.KEY_* constants for context access"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_scene_manager_transition_path_avoids_reflection_and_array_wrapper_captures() -> void:
	var path := "res://scripts/core/managers/m_scene_manager.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_eq(
		text.find('_camera_manager.get("_camera_blend_tween")'),
		-1,
		"M_SceneManager should query I_CameraManager.is_blend_active() instead of reflecting private tween state."
	)
	assert_eq(
		text.find("var current_progress: Array = ["),
		-1,
		"M_SceneManager transition code should not use Array-wrapper mutable capture for progress state."
	)
	assert_eq(
		text.find("var new_scene_ref: Array = ["),
		-1,
		"M_SceneManager transition code should use typed transition state, not Array-wrapper mutable capture for scene refs."
	)


func test_migrated_files_do_not_duplicate_dependency_resolution_pattern() -> void:
	# Files that have been migrated to use U_DependencyResolution should not
	# contain the old inline cache→export→ServiceLocator pattern in their
	# _resolve_* methods. The shared utility is the single source of truth.
	var affected_files: Array[String] = [
		"res://scripts/core/ecs/systems/s_camera_state_system.gd",
		"res://scripts/core/ecs/systems/s_character_state_system.gd",
		"res://scripts/core/ecs/systems/s_game_event_system.gd",
		"res://scripts/core/managers/m_vcam_manager.gd",
		"res://scripts/core/managers/m_character_lighting_manager.gd",
		"res://scripts/core/managers/m_run_coordinator_manager.gd",
		"res://scripts/core/gameplay/inter_victory_zone.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_runtime_services.gd",
		"res://scripts/core/ecs/base_event_sfx_system.gd",
		"res://scripts/core/ui/menus/ui_splash_screen.gd",
		"res://scripts/core/ui/hud/ui_virtual_button.gd",
		"res://scripts/core/ui/base/base_panel.gd",
		"res://scripts/core/gameplay/base_interactable_controller.gd",
		"res://scripts/core/managers/m_vfx_manager.gd",
		"res://scripts/core/managers/m_audio_manager.gd",
		"res://scripts/core/managers/m_localization_manager.gd",
		"res://scripts/core/managers/m_display_manager.gd",
		"res://scripts/core/utils/scene_director/u_store_action_binder.gd",
	]
	# Forbidden: inline U_STATE_UTILS.try_get_store calls in migrated files
	# that should delegate to U_DependencyResolution
	var dep_res_forbidden_patterns: Array[String] = [
		"U_STATE_UTILS.try_get_store",
		"U_StateUtils.try_get_store",
	]
	var dep_res_violations: Array[String] = []

	for path in affected_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			dep_res_violations.append("%s (unable to open file)" % path)
			continue
		var file_text: String = file.get_as_text()
		file.close()

		for pattern in dep_res_forbidden_patterns:
			if file_text.find(pattern) != -1:
				dep_res_violations.append("%s still contains %s (should use U_DependencyResolution)" % [path, pattern])

	var dep_res_message := "Migrated files should use U_DependencyResolution instead of inline U_STATE_UTILS.try_get_store"
	if dep_res_violations.size() > 0:
		dep_res_message += ":\n" + "\n".join(dep_res_violations)
	assert_eq(dep_res_violations.size(), 0, dep_res_message)

func test_ecs_systems_do_not_define_local_get_frame_state_snapshot() -> void:
	# Systems that have been migrated to use BaseECSSystem.get_frame_state_snapshot()
	# should not define their own _get_frame_state_snapshot method.
	var migrated_files: Array[String] = [
		"res://scripts/core/ecs/systems/s_camera_state_system.gd",
		"res://scripts/core/ecs/systems/s_character_state_system.gd",
		"res://scripts/core/ecs/systems/s_vcam_system.gd",
	]
	var forbidden_pattern: String = "func _get_frame_state_snapshot"
	var snapshot_violations: Array[String] = []

	for path in migrated_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			snapshot_violations.append("%s (unable to open file)" % path)
			continue
		var file_text: String = file.get_as_text()
		file.close()

		if file_text.find(forbidden_pattern) != -1:
			snapshot_violations.append("%s still defines _get_frame_state_snapshot (should use inherited get_frame_state_snapshot)" % path)

	var snapshot_message := "Migrated systems should not define local _get_frame_state_snapshot"
	if snapshot_violations.size() > 0:
		snapshot_message += ":\n" + "\n".join(snapshot_violations)
	assert_eq(snapshot_violations.size(), 0, snapshot_message)

# Helper functions for prefix validation

func _check_directory_prefixes(dir_path: String, allowed_prefixes: Array, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				var subdir_path := "%s/%s" % [dir_path, entry]
				# Check if there's a specific rule for this subdirectory
				var subdir_prefixes := allowed_prefixes
				if subdir_path in SCRIPT_PREFIX_RULES:
					subdir_prefixes = SCRIPT_PREFIX_RULES[subdir_path]
				_check_directory_prefixes(subdir_path, subdir_prefixes, violations)
		elif entry.ends_with(".gd"):
			if not _is_valid_script_name(entry, allowed_prefixes):
				violations.append("%s/%s - invalid prefix (allowed: %s)" % [
					dir_path, entry, str(allowed_prefixes)
				])
		entry = dir.get_next()
	dir.list_dir_end()

func _is_valid_script_name(filename: String, allowed_prefixes: Array) -> bool:
	# Check if it's a documented exception
	if _is_exception(filename):
		return true

	# If no prefixes specified, all non-exceptions are violations
	if allowed_prefixes.is_empty():
		return false

	# Check if filename starts with any allowed prefix
	for prefix in allowed_prefixes:
		if filename.begins_with(prefix):
			return true

	return false

func _is_exception(filename: String) -> bool:
	return filename.begins_with("test_") or filename in SCRIPT_FILENAME_EXCEPTIONS

func _check_script_suffix_directory(dir_path: String, required_suffix: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_script_suffix_directory("%s/%s" % [dir_path, entry], required_suffix, violations)
		elif entry.ends_with(".gd"):
			if not entry.ends_with(required_suffix):
				violations.append("%s/%s - must end with '%s'" % [
					dir_path, entry, required_suffix
				])
		entry = dir.get_next()
	dir.list_dir_end()

func _check_scene_directory(dir_path: String, required_prefix: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_scene_directory("%s/%s" % [dir_path, entry], required_prefix, violations)
		elif entry.ends_with(".tscn"):
			if not entry.begins_with(required_prefix):
				violations.append("%s/%s - must start with '%s'" % [
					dir_path, entry, required_prefix
				])
		entry = dir.get_next()
	dir.list_dir_end()

func _check_resource_directory(dir_path: String, required_patterns: Array,
		violations: Array[String], strict: bool = true) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_resource_directory("%s/%s" % [dir_path, entry],
					required_patterns, violations, strict)
		elif entry.ends_with(".tres"):
			var matches := false
			for pattern in required_patterns:
				if pattern.begins_with("_") and entry.ends_with(pattern):
					matches = true
					break
				elif not pattern.begins_with("_") and entry.begins_with(pattern):
					matches = true
					break

			if strict and not matches:
				violations.append("%s/%s - must match patterns: %s" % [
					dir_path, entry, str(required_patterns)
				])
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_interaction_resource_placement_violations(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				if dir_path == "res://resources/interactions" and not INTERACTION_RESOURCE_ALLOWED_SUBDIRS.has(entry):
					violations.append("%s - invalid interaction config category directory" % path)
				_collect_interaction_resource_placement_violations(path, violations)
		elif entry.ends_with(".tres"):
			if dir_path == "res://resources/interactions":
				violations.append("%s - interaction config instances must live in a category subdirectory" % path)
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_gameplay_hud_embedding_violations(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gameplay_hud_embedding_violations(path, violations)
		elif entry.ends_with(".tscn"):
			if _scene_embeds_hud_overlay(path):
				violations.append("%s embeds ui_hud_overlay.tscn or HUD root node" % path)
		entry = dir.get_next()
	dir.list_dir_end()

func _scene_embeds_hud_overlay(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var has_hud_ext_resource := false
	var has_hud_node := false
	while not file.eof_reached():
		var line := file.get_line()
		if line.find("res://scenes/core/ui/hud/ui_hud_overlay.tscn") != -1:
			has_hud_ext_resource = true
		if line.begins_with("[node name=\"HUD\""):
			has_hud_node = true
		if has_hud_ext_resource or has_hud_node:
			file.close()
			return true

	file.close()
	return false

func _collect_scene_text_match_violations(
	dir_path: String,
	needle: String,
	violations: Array[String]
) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_scene_text_match_violations(path, needle, violations)
		elif entry.ends_with(".tscn"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				entry = dir.get_next()
				continue
			var found := false
			while not file.eof_reached():
				if file.get_line().find(needle) != -1:
					found = true
					break
			file.close()
			if found:
				violations.append("%s contains '%s'" % [path, needle])
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_gd_literal_occurrences(
	dir_path: String,
	needle: String,
	violations: Array[String],
	filename_prefix_filter: String = ""
) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_literal_occurrences(path, needle, violations, filename_prefix_filter)
		elif entry.ends_with(".gd"):
			if filename_prefix_filter != "" and not entry.begins_with(filename_prefix_filter):
				entry = dir.get_next()
				continue

			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				entry = dir.get_next()
				continue
			var line_number: int = 0
			while not file.eof_reached():
				line_number += 1
				var line: String = file.get_line()
				if line.find(needle) != -1:
					violations.append("%s:%d" % [path, line_number])
			file.close()
		entry = dir.get_next()
	dir.list_dir_end()

func _count_theme_override_lines(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0

	var count := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.find("theme_override_") != -1:
			count += 1

	file.close()
	return count

func _collect_ai_resource_layout_violations(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_ai_resource_layout_violations(path, violations)
		elif entry.ends_with(".gd") and entry.begins_with("rs_ai_"):
			var relative_path := path.trim_prefix("res://scripts/core/resources/ai/")
			var slash_index := relative_path.find("/")
			if slash_index == -1:
				violations.append("%s is in ai root; expected brain/goals/tasks/actions subdirectory" % path)
			else:
				var top_level_dir := relative_path.substr(0, slash_index)
				if not AI_RESOURCE_ALLOWED_SUBDIRECTORIES.has(top_level_dir):
					violations.append("%s is under unexpected ai subdirectory '%s'" % [path, top_level_dir])
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_scene_theme_override_counts(dir_path: String, override_counts: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_scene_theme_override_counts(path, override_counts)
		elif entry.ends_with(".tscn"):
			var override_count: int = _count_theme_override_lines(path)
			if override_count > 0:
				override_counts[path] = override_count
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_gd_filename_substring_violations(
	dir_path: String,
	needle: String,
	violations: Array[String]
) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_filename_substring_violations(path, needle, violations)
		elif entry.ends_with(".gd"):
			if entry.find(needle) != -1:
				violations.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_gd_file_line_limit_violations(dir_path: String, max_lines: int, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_file_line_limit_violations(path, max_lines, violations)
		elif entry.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				entry = dir.get_next()
				continue
			var line_count: int = 0
			while not file.eof_reached():
				file.get_line()
				line_count += 1
			file.close()
			if line_count > max_lines:
				violations.append("%s has %d lines (max %d)" % [path, line_count, max_lines])
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_gd_single_file_line_limit_violation(path: String, max_lines: int, violations: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		violations.append("%s is missing or unreadable" % path)
		return
	var line_count: int = 0
	while not file.eof_reached():
		file.get_line()
		line_count += 1
	file.close()
	if line_count > max_lines:
		violations.append("%s has %d lines (max %d)" % [path, line_count, max_lines])

func _collect_gd_forbidden_token_violations(
	dir_path: String,
	forbidden_tokens: Array,
	violations: Array[String]
) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_forbidden_token_violations(path, forbidden_tokens, violations)
		elif entry.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				entry = dir.get_next()
				continue
			var file_text: String = file.get_as_text()
			file.close()
			for token in forbidden_tokens:
				if file_text.find(token) != -1:
					violations.append("%s references forbidden token '%s'" % [path, token])
		entry = dir.get_next()
	dir.list_dir_end()


func test_resolve_state_store_naming_consistent() -> void:
	var gd_dirs: Array[String] = [
		"res://scripts/core/ecs",
		"res://scripts/core/managers",
		"res://scripts/core/gameplay",
		"res://scripts/demo",
	]
	var violations: Array[String] = []
	for dir_path in gd_dirs:
		_check_for_method_definition(dir_path, "func _resolve_store()", violations)
	assert_eq(violations.size(), 0, "Found files defining _resolve_store() instead of _resolve_state_store():\n" + "\n".join(violations))


func _check_for_method_definition(dir_path: String, method_signature: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_for_method_definition(path, method_signature, violations)
		elif entry.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				while not file.eof_reached():
					var line := file.get_line()
					if line.find(method_signature) != -1:
						violations.append(path)
						break
				file.close()
		entry = dir.get_next()
	dir.list_dir_end()

## C7: No direct state.get("objectives", {}) outside selectors and reducers in production code.
func test_objectives_state_access_uses_selectors() -> void:
	var allowed_files: Array[String] = [
		"res://scripts/core/state/selectors/u_objectives_selectors.gd",
		"res://scripts/core/state/reducers/u_objectives_reducer.gd",
		"res://scripts/core/managers/helpers/u_save_migration_engine.gd",
		"res://scripts/core/utils/scene_director/u_objectives_debug_tracer.gd",
		"res://scripts/core/ecs/systems/s_victory_handler_system.gd",
		"res://scripts/core/ui/menus/ui_victory.gd",
	]
	var production_dirs: Array[String] = [
		"res://scripts/core/ecs",
		"res://scripts/core/state",
		"res://scripts/core/ui",
		"res://scripts/core/managers",
		"res://scripts/core",
		"res://scripts/core/interfaces",
		"res://scripts/core/utils",
		"res://scripts/core/input",
		"res://scripts/core/scene_management",
		"res://scripts/core/events",
		"res://scripts/core/scene_structure",
		"res://scripts/core/resources",
		"res://scripts/core/gameplay",
		"res://scripts/demo",
		"res://scripts/core/debug",
	]
	var violations: Array[String] = []
	var patterns: Array[String] = [
		'state.get("objectives"',
		'state.get(&"objectives"',
		'state["objectives"]',
	]
	for dir_path in production_dirs:
		_check_for_patterns_in_files(dir_path, patterns, allowed_files, violations)
	assert_eq(violations.size(), 0, "Found direct objectives state access outside selectors/reducers:\n" + "\n".join(violations))

## C8: No direct state.get("slice", {}) or state["slice"] in manager/helper files.
## All state reads must go through U_*Selectors.
func test_managers_use_selectors_for_state_access() -> void:
	# Files exempt from this check:
	# - m_state_store.gd: The state store itself owns the state dict
	# - u_save_migration_engine.gd: Operates on save file data, not live Redux state
	var allowed_files: Array[String] = [
		"res://scripts/core/state/m_state_store.gd",
		"res://scripts/core/managers/helpers/u_save_migration_engine.gd",
	]
	var manager_dirs: Array[String] = [
		"res://scripts/core/managers",
	]
	var violations: Array[String] = []
	var patterns: Array[String] = [
		"state.get(",
		'state["',
		'state[&"',
		"state['",
		"state[&'",
	]
	for dir_path in manager_dirs:
		_check_for_patterns_in_files(dir_path, patterns, allowed_files, violations)
	assert_eq(violations.size(), 0, "Found direct state slice access in manager files (should use selectors):\n" + "\n".join(violations))

## C11: No direct state.get("slice") or state["slice"] in production code scopes covered
## by C8 (managers) and C11 (ECS systems, helpers, interactables, UI targets).
## Files deferred to post-C11 cleanup are explicitly listed below.
func test_all_production_files_use_selectors_for_state_access() -> void:
	var allowed_files: Array[String] = [
		# Core exemptions: own the state dict or operate on save data
		"res://scripts/core/state/m_state_store.gd",
		"res://scripts/core/managers/helpers/u_save_migration_engine.gd",
		# False positives: files that use local dict variables named "state" (not Redux state)
		# u_vcam_orbit_effects and u_vcam_rotation use "state" for per-vcam internal tracking dicts.
		# Decomposed helpers carry the same per-vcam dict pattern.
		# u_vcam_look_input uses "state" for look-input smoothing state.
		# Renaming these local vars is a larger refactor deferred beyond C11.
		"res://scripts/core/ecs/systems/helpers/u_vcam_orbit_effects.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_rotation.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_look_spring.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_orbit_centering.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_look_ahead.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_ground_anchor.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_soft_zone_applier.gd",
		"res://scripts/core/ecs/systems/helpers/u_vcam_look_input.gd",
		# Generic serializer: uses state.get(slice_name, null) with a variable key (not a string literal).
		"res://scripts/core/utils/u_global_settings_serialization.gd",
		# Deferred — not in C11 scope; will be migrated post-C11:
		"res://scripts/core/ecs/systems/s_jump_system.gd",
		"res://scripts/core/ecs/systems/s_playtime_system.gd",
		"res://scripts/core/ecs/components/c_scene_trigger_component.gd",
		"res://scripts/core/gameplay/inter_endgame_goal_zone.gd",
		"res://scripts/core/ui/hud/ui_hud_controller.gd",
		"res://scripts/core/ui/hud/ui_mobile_controls.gd",
		"res://scripts/core/ui/menus/ui_main_menu.gd",
		"res://scripts/core/ui/overlays/ui_input_rebinding_overlay.gd",
		"res://scripts/core/ui/overlays/ui_save_load_menu.gd",
		"res://scripts/core/utils/scene_director/u_objectives_debug_tracer.gd",
	]
	var production_dirs: Array[String] = [
		"res://scripts/core/ecs",
		"res://scripts/core/gameplay",
		"res://scripts/core/ui",
		"res://scripts/core/managers",
		"res://scripts/core/scene_management",
		"res://scripts/core/scene_management",
		"res://scripts/core/utils",
		"res://scripts/demo",
	]
	var violations: Array[String] = []
	var patterns: Array[String] = [
		"state.get(",
		'state["',
		'state[&"',
		"state['",
		"state[&'",
	]
	for dir_path in production_dirs:
		_check_for_patterns_in_files(dir_path, patterns, allowed_files, violations)
	assert_eq(
		violations.size(),
		0,
		"Found direct state slice access in production files (should use selectors):\n" + "\n".join(violations)
	)

## C12: No "cinema_grade" identifiers should remain in scripts/ after the
## cinema_grade → color_grading rename. All display/post-process code should
## use color_grading terminology.
func test_no_cinema_grade_identifiers_in_scripts() -> void:
	var violations: Array[String] = []
	_collect_gd_literal_occurrences("res://scripts", "cinema_grade", violations)
	_collect_gd_filename_substring_violations("res://scripts", "cinema_grade", violations)
	assert_eq(
		violations.size(),
		0,
		"Found cinema_grade identifiers in scripts/ (should be renamed to color_grading):\n" + "\n".join(violations)
	)

## C12-gap: No bare "cinema" identifiers in display/post-process/debug scripts.
## The camera manager's "cinematics" is a different concept (cutscene camera work)
## and is allowlisted. All other uses should be "color_grading".
func test_no_cinema_identifiers_in_display_scripts() -> void:
	var allowed_files: Array[String] = [
		"res://scripts/core/managers/m_camera_manager.gd",  # "cinematics" = cutscene camera work
	]
	var display_dirs: Array[String] = [
		"res://scripts/core/managers/helpers/display",
		"res://scripts/core/state",
		"res://scripts/core/utils/debug",
		"res://scripts/core/debug",
	]
	var violations: Array[String] = []
	for dir_path in display_dirs:
		_collect_gd_literal_occurrences(dir_path, "cinema", violations)
	# Filter out allowed files
	var filtered: Array[String] = []
	for v in violations:
		var is_allowed := false
		for allowed in allowed_files:
			if v.find(allowed) != -1:
				is_allowed = true
				break
		if not is_allowed:
			filtered.append(v)
	assert_eq(
		filtered.size(),
		0,
		"Found cinema identifiers in display/debug scripts (should be color_grading):\n" + "\n".join(filtered)
	)

## C12-gap: No "Combined" identifiers in display/post-process scripts.
## The grain+dither pass was renamed from "combined" — no display code should
## reference CombinedLayer, CombinedRect, or combined visibility helpers.
func test_no_combined_identifiers_in_display_scripts() -> void:
	var display_dirs: Array[String] = [
		"res://scripts/core/managers/helpers/display",
		"res://scripts/core/utils/debug",
	]
	var violations: Array[String] = []
	for dir_path in display_dirs:
		_collect_gd_literal_occurrences(dir_path, "CombinedLayer", violations)
		_collect_gd_literal_occurrences(dir_path, "CombinedRect", violations)
		_collect_gd_literal_occurrences(dir_path, "combined_visible", violations)
		_collect_gd_literal_occurrences(dir_path, "get_combined_rect", violations)
		_collect_gd_literal_occurrences(dir_path, "set_combined_visible", violations)
		_collect_gd_literal_occurrences(dir_path, "set_combined_parameter", violations)
	assert_eq(
		violations.size(),
		0,
		"Found Combined identifiers in display scripts (should be grain_dither):\n" + "\n".join(violations)
	)

## C12: No CRT-related identifiers (crt_, chromatic_aberration, scanline,
## curvature) should remain in display/post-process scripts after CRT removal.
## Allowlist: non-post-process uses of these terms (e.g. audio scanning).
func test_no_crt_identifiers_in_display_scripts() -> void:
	var allowed_files: Array[String] = [
		# Audio/input scanning is unrelated to CRT display
	]
	var display_dirs: Array[String] = [
		"res://scripts/core/managers/helpers/display",
		"res://scripts/core/state",
		"res://scripts/core/utils/display",
		"res://scripts/core/ui/settings",
		"res://scripts/core/debug",
	]
	var violations: Array[String] = []
	for dir_path in display_dirs:
		_collect_gd_literal_occurrences(dir_path, "crt_enabled", violations)
		_collect_gd_literal_occurrences(dir_path, "crt_scanline", violations)
		_collect_gd_literal_occurrences(dir_path, "crt_curvature", violations)
		_collect_gd_literal_occurrences(dir_path, "crt_chromatic", violations)
		_collect_gd_literal_occurrences(dir_path, "chromatic_aberration", violations)
		_collect_gd_literal_occurrences(dir_path, "scanline_intensity", violations)
	# Filter out allowed files
	var filtered: Array[String] = []
	for v in violations:
		var is_allowed := false
		for allowed in allowed_files:
			if v.find(allowed) != -1:
				is_allowed = true
				break
		if not is_allowed:
			filtered.append(v)
	assert_eq(
		filtered.size(),
		0,
		"Found CRT identifiers in display scripts (CRT should be fully removed):\n" + "\n".join(filtered)
	)

## C12: Only U_PostProcessPipeline's delegate appliers should construct ColorRect
## children under PostProcessOverlay. All other files must go through the pipeline.
func test_post_process_overlay_colorrect_creation_only_via_pipeline() -> void:
	var allowed_files: Array[String] = [
		"res://scripts/core/managers/helpers/display/u_post_process_pipeline.gd",
		"res://scripts/core/managers/helpers/display/u_display_color_grading_applier.gd",
		"res://scripts/core/managers/helpers/display/u_display_post_process_applier.gd",
		# Editor-only preview (removes itself at runtime; not under PostProcessOverlay)
		"res://scripts/core/utils/display/u_color_grading_preview.gd",
	]
	var display_dirs: Array[String] = [
		"res://scripts/core/managers/helpers/display",
		"res://scripts/core/utils/display",
	]
	var violations: Array[String] = []
	for dir_path in display_dirs:
		_collect_gd_literal_occurrences(dir_path, "ColorRect.new()", violations)
	# Filter out allowed delegate appliers
	var filtered: Array[String] = []
	for v in violations:
		var is_allowed := false
		for allowed in allowed_files:
			if v.find(allowed) != -1:
				is_allowed = true
				break
		if not is_allowed:
			filtered.append(v)
	assert_eq(
		filtered.size(),
		0,
		"Found ColorRect.new() in display helpers outside pipeline delegates:\n" + "\n".join(filtered)
	)

## F3: No direct _state[ mutation outside m_state_store.gd.
## All state mutations must flow through dispatch() so that action history,
## version bumping, validator, and signal batching stay consistent.
## The only exception is m_state_store.gd itself, which owns _state and has
## invariant-annotated direct-mutation paths for bulk load/restore.
func test_no_state_mutation_outside_store() -> void:
	var allowed_files: Array[String] = [
		"res://scripts/core/state/m_state_store.gd",
	]
	var production_dirs: Array[String] = [
		"res://scripts/core/ecs",
		"res://scripts/core/gameplay",
		"res://scripts/core/ui",
		"res://scripts/core/managers",
		"res://scripts/core/scene_management",
		"res://scripts/core/utils",
		"res://scripts/core",
		"res://scripts/core/state",
		"res://scripts/core/input",
		"res://scripts/core/events",
		"res://scripts/core/scene_structure",
		"res://scripts/core/interfaces",
		"res://scripts/core/resources",
		"res://scripts/core/debug",
	]
	var violations: Array[String] = []
	for dir_path in production_dirs:
		_collect_state_mutation_violations(dir_path, allowed_files, violations)
	assert_eq(
		violations.size(),
		0,
		"Found _state[ mutations outside m_state_store.gd — all mutations must go through dispatch():\n" + "\n".join(violations)
	)

## F5: Managers must not publish to U_ECSEventBus.
## Per the channel taxonomy (docs/architecture/adr/0001-channel-taxonomy.md):
##   ECS component/system → U_ECSEventBus (subscribers can be anywhere)
##   Manager → Redux dispatch only
##   Manager-UI wiring → Godot signals
##   Everything else → method calls
## m_ecs_manager.gd is the only allowed publisher because it IS the ECS
## infrastructure (publishes entity_registered/unregistered lifecycle events).
func test_managers_dont_publish_to_ecs_bus() -> void:
	var allowed_files: Array[String] = [
		"res://scripts/core/managers/m_ecs_manager.gd",
	]
	var manager_dir := "res://scripts/core/managers"
	var violations: Array[String] = []
	# Match both direct U_ECSEventBus references and const alias U_ECS_EVENT_BUS references,
	# plus the EVENT_BUS alias used by m_spawn_manager
	_collect_gd_literal_occurrences(manager_dir, "ECSEventBus.publish", violations)
	_collect_gd_literal_occurrences(manager_dir, "EVENT_BUS.publish", violations)
	# Filter out allowed files (m_ecs_manager is ECS infrastructure)
	var filtered: Array[String] = []
	for v in violations:
		var is_allowed := false
		for allowed in allowed_files:
			if v.find(allowed) != -1:
				is_allowed = true
				break
		if not is_allowed:
			filtered.append(v)
	assert_eq(
		filtered.size(),
		0,
		"Managers must not publish to U_ECSEventBus (use Redux dispatch instead):\n" + "\n".join(filtered)
	)

## F5: m_scene_manager must not subscribe to victory-related ECS events.
## Victory routing should go through Redux (ACTION_TRIGGER_VICTORY_ROUTING),
## not through U_ECSEventBus subscriptions. Manager-to-manager communication
## belongs on the Redux channel, not the ECS event bus.
func test_scene_manager_no_victory_ecs_subscription() -> void:
	var violations: Array[String] = []
	# Search for victory event names in m_scene_manager.gd
	# The filename_prefix_filter ensures we only check m_scene_manager.gd
	_collect_gd_literal_occurrences(
		"res://scripts/core/managers",
		"OBJECTIVE_VICTORY_TRIGGERED",
		violations,
		"m_scene_manager"
	)
	assert_eq(
		violations.size(),
		0,
		"m_scene_manager must not subscribe to victory ECS events (use Redux dispatch):\n" + "\n".join(violations)
	)

## F5: Managers may only declare allow-listed Godot signals.
## Per the channel taxonomy, Manager-UI wiring uses Godot signals.
## This allow-list ensures managers only declare signals for UI wiring
## and prevents new inter-system signal declarations without review.
func test_manager_signals_allow_list() -> void:
	var allowed_signals: Dictionary = {
		# m_ecs_manager — component lifecycle notifications for UI consumers
		"res://scripts/core/managers/m_ecs_manager.gd": [
			"component_added", "component_removed"
		],
		# m_cursor_manager — cursor state for UI
		"res://scripts/core/managers/m_cursor_manager.gd": [
			"cursor_state_changed"
		],
		# m_time_manager — time state for UI
		"res://scripts/core/managers/m_time_manager.gd": [
			"pause_state_changed", "timescale_changed", "world_hour_changed"
		],
		# m_scene_manager — transition state for UI
		"res://scripts/core/managers/m_scene_manager.gd": [
			"transition_visual_complete"
		],
		# m_input_profile_manager — input profile state for UI
		"res://scripts/core/managers/m_input_profile_manager.gd": [
			"profile_switched", "bindings_reset", "custom_binding_added"
		],
		# u_palette_manager — palette state for UI
		"res://scripts/core/managers/helpers/u_palette_manager.gd": [
			"active_palette_changed"
		],
		# m_input_device_manager — device state for UI
		"res://scripts/core/managers/m_input_device_manager.gd": [
			"device_changed"
		],
	}
	var violations: Array[String] = []
	_collect_manager_signal_violations("res://scripts/core/managers", allowed_signals, violations)
	assert_eq(
		violations.size(),
		0,
		"Managers must only declare allow-listed signals for UI wiring (channel taxonomy):\n" + "\n".join(violations)
	)

func _collect_state_mutation_violations(dir_path: String, allowed_files: Array[String], violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_state_mutation_violations(path, allowed_files, violations)
		elif entry.ends_with(".gd"):
			if allowed_files.has(path):
				entry = dir.get_next()
				continue
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var line_number: int = 0
				while not file.eof_reached():
					line_number += 1
					var line := file.get_line()
					var stripped: String = line.strip_edges()
					if stripped.begins_with("#"):
						continue
					# Match _state[ with word boundary (not preceded by another identifier char)
					# and followed by assignment (= but not ==)
					if _is_state_member_mutation(line):
						violations.append("%s:%d %s" % [path, line_number, stripped])
						break  # One violation per file is enough
				file.close()
		entry = dir.get_next()

func _is_state_member_mutation(line: String) -> bool:
	# Look for _state[ followed by assignment (= but not ==)
	var idx: int = line.find("_state[")
	while idx != -1:
		# Check word boundary: char before _state must not be an identifier char
		if idx > 0:
			var prev_char: String = line[idx - 1]
			if prev_char.is_valid_identifier():
				idx = line.find("_state[", idx + 7)
				continue
		# Find the closing bracket
		var bracket_end: int = line.find("]", idx)
		if bracket_end == -1:
			idx = line.find("_state[", idx + 7)
			continue
		# Check if there's an assignment after the bracket ( = but not ==)
		var after_bracket: String = line.substr(bracket_end + 1).strip_edges()
		if after_bracket.begins_with("=") and not after_bracket.begins_with("=="):
			return true
		idx = line.find("_state[", idx + 7)
	return false

func _check_for_patterns_in_files(dir_path: String, patterns: Array[String], allowed_files: Array[String], violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_for_patterns_in_files(path, patterns, allowed_files, violations)
		elif entry.ends_with(".gd"):
			if allowed_files.has(path):
				entry = dir.get_next()
				continue
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var line_number: int = 0
				var found := false
				while not file.eof_reached():
					line_number += 1
					var line := file.get_line()
					var stripped: String = line.strip_edges()
					if stripped.begins_with("#"):
						continue
					if _line_has_disallowed_state_access(line, patterns):
						violations.append("%s:%d %s" % [path, line_number, stripped])
						found = true
					if found:
						break
				file.close()
		entry = dir.get_next()
	dir.list_dir_end()

func _line_has_disallowed_state_access(line: String, patterns: Array[String]) -> bool:
	var normalized_line: String = line.replace(" ", "").replace("\t", "")
	var candidates: Array[String] = [line]
	if normalized_line != line:
		candidates.append(normalized_line)

	for candidate in candidates:
		for pattern in patterns:
			var idx: int = candidate.find(pattern)
			while idx != -1:
				if _is_state_token_boundary(candidate, idx):
					return true
				idx = candidate.find(pattern, idx + pattern.length())
	return false

func _is_state_token_boundary(line: String, state_index: int) -> bool:
	if state_index <= 0:
		return true
	var prev_char: String = line.substr(state_index - 1, 1)
	return not _is_identifier_char(prev_char)

func _is_identifier_char(char: String) -> bool:
	if char.is_empty():
		return false
	if char == "_":
		return true
	var code: int = char.unicode_at(0)
	var is_number: bool = code >= 48 and code <= 57
	var is_upper: bool = code >= 65 and code <= 90
	var is_lower: bool = code >= 97 and code <= 122
	return is_number or is_upper or is_lower

func _collect_manager_signal_violations(
	dir_path: String,
	allowed_signals: Dictionary,
	violations: Array[String]
) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_manager_signal_violations(path, allowed_signals, violations)
		elif entry.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var line_number: int = 0
				while not file.eof_reached():
					line_number += 1
					var line: String = file.get_line()
					var stripped: String = line.strip_edges()
					if not stripped.begins_with("signal "):
						continue
					var signal_name: String = _extract_signal_name(stripped)
					if signal_name.is_empty():
						continue
					var file_allowed: Variant = allowed_signals.get(path)
					if file_allowed == null:
						violations.append("%s:%d signal '%s' — file has no allow-list entry" % [path, line_number, signal_name])
					elif not (file_allowed as Array).has(signal_name):
						violations.append("%s:%d signal '%s' — not on allow-list for this file" % [path, line_number, signal_name])
				file.close()
		entry = dir.get_next()
	dir.list_dir_end()

func _extract_signal_name(line: String) -> String:
	var after_signal: String = line.substr(7).strip_edges()
	var paren_idx: int = after_signal.find("(")
	if paren_idx != -1:
		return after_signal.substr(0, paren_idx).strip_edges()
	return after_signal.split(" ")[0]


# --- F8: VCam/CameraState System Decomposition (v7.2) ---

func _count_file_lines(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var count: int = 0
	while not file.eof_reached():
		file.get_line()
		count += 1
	file.close()
	return count


func _count_method_lines(path: String, method_name: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	var start_line: int = -1
	var end_line: int = -1
	var indent_level: int = -1
	var in_method: bool = false

	for i in range(lines.size()):
		var line: String = lines[i]
		if line.find("func %s(" % method_name) >= 0:
			start_line = i
			var stripped: String = line.lstrip("\t ")
			indent_level = line.length() - stripped.length()
			in_method = true
			continue
		if in_method:
			if line.strip_edges() == "":
				continue
			var stripped: String = line.lstrip("\t ")
			var current_indent: int = line.length() - stripped.length()
			if current_indent <= indent_level and (stripped.begins_with("func ") or stripped.begins_with("var ") or stripped.begins_with("signal ")):
				end_line = i - 1
				break

	if end_line == -1:
		end_line = lines.size() - 1

	if start_line == -1:
		return -1
	return end_line - start_line + 1


func test_s_vcam_system_stays_under_400_lines() -> void:
	var line_count: int = _count_file_lines("res://scripts/core/ecs/systems/s_vcam_system.gd")
	assert_lt(line_count, 400,
		"S_VCamSystem should stay under 400 lines (current=%d)." % line_count)


func test_s_camera_state_system_stays_under_400_lines() -> void:
	var line_count: int = _count_file_lines("res://scripts/core/ecs/systems/s_camera_state_system.gd")
	assert_lt(line_count, 400,
		"S_CameraStateSystem should stay under 400 lines (current=%d)." % line_count)


func test_vcam_system_process_tick_under_80_lines() -> void:
	var method_lines: int = _count_method_lines("res://scripts/core/ecs/systems/s_vcam_system.gd", "process_tick")
	assert_lt(method_lines, 80,
		"S_VCamSystem.process_tick should stay under 80 lines (current=%d)." % method_lines)


func test_camera_state_system_process_tick_under_80_lines() -> void:
	var method_lines: int = _count_method_lines("res://scripts/core/ecs/systems/s_camera_state_system.gd", "process_tick")
	assert_lt(method_lines, 80,
		"S_CameraStateSystem.process_tick should stay under 80 lines (current=%d)." % method_lines)


func test_all_ecs_system_helpers_under_400_lines() -> void:
	# u_vcam_response_smoother.gd (468 lines) is exempt — coherent 2nd-order dynamics lifecycle
	var exempt_files: Array[String] = [
		"res://scripts/core/ecs/systems/helpers/u_vcam_response_smoother.gd",  # 468 lines - coherent 2nd-order dynamics lifecycle
		"res://scripts/core/ecs/systems/helpers/u_vcam_look_spring.gd",  # 405 lines - 2nd-order spring + release damping (Phase 0 decomposition)
	]
	var helper_dir := "res://scripts/core/ecs/systems/helpers"
	var dir := DirAccess.open(helper_dir)
	assert_not_null(dir, "Should be able to open helpers directory")
	if dir == null:
		return

	var violations: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.ends_with(".gd"):
			file_name = dir.get_next()
			continue
		var path: String = helper_dir + "/" + file_name
		if path in exempt_files:
			file_name = dir.get_next()
			continue
		var line_count: int = _count_file_lines(path)
		if line_count >= 400:
			violations.append("%s — %d lines" % [path, line_count])
		file_name = dir.get_next()
	dir.list_dir_end()

	var message := "ECS system helpers should stay under 400 lines (exempt: u_vcam_response_smoother.gd)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)


func test_vcam_system_has_no_evaluate_and_submit() -> void:
	var file := FileAccess.open("res://scripts/core/ecs/systems/s_vcam_system.gd", FileAccess.READ)
	assert_not_null(file, "Should open s_vcam_system.gd")
	if file == null:
		return
	var source := file.get_as_text()
	file.close()
	assert_false(source.find("_evaluate_and_submit") >= 0,
		"S_VCamSystem should not have dead _evaluate_and_submit method")

func test_vcam_system_has_no_step_orbit_release_axis() -> void:
	var file := FileAccess.open("res://scripts/core/ecs/systems/s_vcam_system.gd", FileAccess.READ)
	assert_not_null(file, "Should open s_vcam_system.gd")
	if file == null:
		return
	var source := file.get_as_text()
	file.close()
	assert_false(source.find("func _step_orbit_release_axis(") >= 0,
		"S_VCamSystem should not have dead _step_orbit_release_axis method")

func test_vcam_system_has_no_resolve_orbit_center_target_yaw() -> void:
	var file := FileAccess.open("res://scripts/core/ecs/systems/s_vcam_system.gd", FileAccess.READ)
	assert_not_null(file, "Should open s_vcam_system.gd")
	if file == null:
		return
	var source := file.get_as_text()
	file.close()
	assert_false(source.find("func _resolve_orbit_center_target_yaw(") >= 0,
		"S_VCamSystem should not have dead _resolve_orbit_center_target_yaw method")

func test_vcam_system_has_no_apply_vcam_effect_pipeline() -> void:
	var file := FileAccess.open("res://scripts/core/ecs/systems/s_vcam_system.gd", FileAccess.READ)
	assert_not_null(file, "Should open s_vcam_system.gd")
	if file == null:
		return
	var source := file.get_as_text()
	file.close()
	assert_false(source.find("func _apply_vcam_effect_pipeline(") >= 0,
		"S_VCamSystem should not have dead _apply_vcam_effect_pipeline method")

func test_vcam_system_has_no_resolve_state_store() -> void:
	var file := FileAccess.open("res://scripts/core/ecs/systems/s_vcam_system.gd", FileAccess.READ)
	assert_not_null(file, "Should open s_vcam_system.gd")
	if file == null:
		return
	var source := file.get_as_text()
	file.close()
	assert_false(source.find("func _resolve_state_store(") >= 0,
		"S_VCamSystem should not have dead _resolve_state_store method")

func test_vcam_system_has_no_update_runtime_rotation() -> void:
	var file := FileAccess.open("res://scripts/core/ecs/systems/s_vcam_system.gd", FileAccess.READ)
	assert_not_null(file, "Should open s_vcam_system.gd")
	if file == null:
		return
	var source := file.get_as_text()
	file.close()
	assert_false(source.find("func _update_runtime_rotation(") >= 0,
		"S_VCamSystem should not have dead _update_runtime_rotation method")

func test_vcam_system_has_no_resolve_runtime_rotation_for_evaluation() -> void:
	var file := FileAccess.open("res://scripts/core/ecs/systems/s_vcam_system.gd", FileAccess.READ)
	assert_not_null(file, "Should open s_vcam_system.gd")
	if file == null:
		return
	var source := file.get_as_text()
	file.close()
	assert_false(source.find("func _resolve_runtime_rotation_for_evaluation(") >= 0,
		"S_VCamSystem should not have dead _resolve_runtime_rotation_for_evaluation method")

func test_all_ecs_systems_declare_explicit_phase() -> void:
	var violations: Array[String] = []
	var dir := DirAccess.open("res://scripts/core/ecs/systems/")
	if dir == null:
		push_error("Cannot open scripts/core/ecs/systems/ directory")
		assert_false(true, "Directory access failed")
		return
	dir.include_navigational = false
	dir.include_hidden = false
	var filename := dir.get_next()
	while filename != "":
		if not filename.ends_with(".gd") or not filename.begins_with("s_"):
			filename = dir.get_next()
			continue
		var file_path := "res://scripts/core/ecs/systems/" + filename
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			violations.append("%s: cannot open file" % filename)
			filename = dir.get_next()
			continue
		var source := file.get_as_text()
		file.close()
		if source.find("func get_phase()") < 0:
			violations.append("%s: missing get_phase() override" % filename)
		filename = dir.get_next()
	assert_eq(violations.size(), 0, "Every S_* system must declare get_phase(): %s" % [violations])

func test_base_event_bus_publish_does_not_duplicate_subscriber_list() -> void:
	var file_path := "res://scripts/core/events/base_event_bus.gd"
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s" % file_path)
		assert_false(true, "File access failed")
		return
	var source := file.get_as_text()
	file.close()
	# Extract only the publish function body (between "func publish" and next "func ")
	var publish_start: int = source.find("func publish")
	assert_ne(publish_start, -1, "Could not find func publish in base_event_bus.gd")
	var next_func: int = source.find("\nfunc ", publish_start + 1)
	if next_func < 0:
		next_func = source.length()
	var publish_body: String = source.substr(publish_start, next_func - publish_start)
	assert_false(publish_body.find(".duplicate()") >= 0,
		"BaseEventBus.publish() must not duplicate subscriber list — use _publishing guard + live iteration instead")



func test_no_localize_with_fallback_in_migrated_scripts() -> void:
	var ui_dirs: Array[String] = [
		"res://scripts/core/ui/settings",
		"res://scripts/core/ui/overlays",
		"res://scripts/core/ui/menus",
		"res://scripts/core/ui/helpers",
		"res://scripts/core/utils/display",
	]
	var violations: Array[String] = []
	for dir_path in ui_dirs:
		_collect_method_definition(violations, dir_path, "_localize_with_fallback")
	var message := "Migrated UI scripts must not define _localize_with_fallback (use U_LOCALIZATION_UTILS.localize_with_fallback instead)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func _collect_method_definition(violations: Array[String], dir_path: String, method_name: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_method_definition(violations, path, method_name)
		elif entry.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				entry = dir.get_next()
				continue
			var file_text: String = file.get_as_text()
			file.close()
			if file_text.find("func %s(" % method_name) != -1:
				violations.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

func test_managers_and_ecs_systems_have_no_bare_print_calls() -> void:
	var roots: Array[String] = [
		"res://scripts/core/managers",
		"res://scripts/core/ecs/systems",
	]
	var violations: Array[String] = []
	for root in roots:
		_collect_bare_print_calls(root, violations)

	var message := "Managers and ECS systems must not use bare print() calls"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_agents_routing_index_stays_under_line_cap() -> void:
	var file := FileAccess.open("res://AGENTS.md", FileAccess.READ)
	assert_not_null(file, "Should open AGENTS.md")
	if file == null:
		return
	var line_count := 0
	while not file.eof_reached():
		file.get_line()
		line_count += 1
	file.close()
	assert_lte(line_count, 150, "AGENTS.md should stay a routing index under 150 lines")

func test_adr_structure() -> void:
	var violations: Array[String] = []
	var dir := DirAccess.open("res://docs/architecture/adr")
	assert_not_null(dir, "Should open ADR directory")
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".md") and entry != "README.md":
			var path := "res://docs/architecture/adr/%s" % entry
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				violations.append("%s: cannot open" % path)
			else:
				var source := file.get_as_text()
				file.close()
				for section in ["**Status**", "## Context", "## Decision", "## Alternatives", "## Consequences"]:
					if source.find(section) < 0:
						violations.append("%s: missing %s" % [path, section])
		entry = dir.get_next()
	dir.list_dir_end()
	assert_eq(violations.size(), 0, "ADRs must contain required sections: %s" % [violations])

func test_extension_recipe_structure() -> void:
	var violations: Array[String] = []
	var dir := DirAccess.open("res://docs/architecture/extensions")
	assert_not_null(dir, "Should open extension recipe directory")
	if dir == null:
		return
	for required_recipe in REQUIRED_EXTENSION_RECIPES:
		if not FileAccess.file_exists("res://docs/architecture/extensions/%s" % required_recipe):
			violations.append("res://docs/architecture/extensions/%s: missing required recipe" % required_recipe)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".md") and entry != "README.md":
			var path := "res://docs/architecture/extensions/%s" % entry
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				violations.append("%s: cannot open" % path)
			else:
				var source := file.get_as_text()
				file.close()
				for section in ["## When To Use", "## Governing ADR", "## Canonical Example", "## Vocabulary", "## Recipe", "## Anti-patterns"]:
					if source.find(section) < 0:
						violations.append("%s: missing %s" % [path, section])
		entry = dir.get_next()
	dir.list_dir_end()
	assert_eq(violations.size(), 0, "Extension recipes must contain required sections: %s" % [violations])

func test_core_scripts_never_import_from_demo() -> void:
	var violations: Array[String] = []
	var forbidden_patterns: Array[String] = [
		"res://scripts/demo/",
		"res://scenes/demo/",
		"res://resources/demo/"
	]
	# u_scene_manifest.gd is allow-listed: it registers scene paths (including demo) but doesn't import/depend on demo code
	var allow_listed_files: Array[String] = ["res://scripts/core/scene_management/u_scene_manifest.gd", "res://scripts/core/root.gd"]
	_collect_demo_imports_in_core("res://scripts/core", violations, forbidden_patterns, allow_listed_files)
	var message := "scripts/core/ must not import from demo/ paths. Core must not depend on demo."
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func _collect_demo_imports_in_core(dir_path: String, violations: Array[String], forbidden_patterns: Array[String], allow_listed_files: Array[String] = []) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_demo_imports_in_core(path, violations, forbidden_patterns, allow_listed_files)
		elif entry.ends_with(".gd"):
			if path in allow_listed_files:
				entry = dir.get_next()
				continue
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				entry = dir.get_next()
				continue
			var line_number: int = 0
			while not file.eof_reached():
				line_number += 1
				var line: String = file.get_line()
				for pattern in forbidden_patterns:
					if pattern in line:
						violations.append("CORE_IMPORT_VIOLATION: %s:%d imports from %s" % [path, line_number, pattern])
			file.close()
		entry = dir.get_next()
	dir.list_dir_end()

func test_core_resources_never_reference_demo() -> void:
	var violations: Array[String] = []
	var forbidden_patterns: Array[String] = [
		"res://scripts/demo/",
		"res://scenes/demo/",
		"res://resources/demo/"
	]
	_collect_demo_refs_in_dir("res://resources/core", [".tres"], violations, forbidden_patterns)
	var message := "resources/core/ must not reference demo/ paths. Core must not depend on demo."
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_core_scenes_never_reference_demo() -> void:
	var violations: Array[String] = []
	var forbidden_patterns: Array[String] = [
		"res://scripts/demo/",
		"res://scenes/demo/",
		"res://resources/demo/"
	]
	_collect_demo_refs_in_dir("res://scenes/core", [".tscn"], violations, forbidden_patterns)
	var message := "scenes/core/ must not reference demo/ paths. Core must not depend on demo."
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func _collect_demo_refs_in_dir(dir_path: String, extensions: Array[String], violations: Array[String], forbidden_patterns: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_demo_refs_in_dir(path, extensions, violations, forbidden_patterns)
		else:
			var matched := false
			for ext in extensions:
				if entry.ends_with(ext):
					matched = true
					break
			if matched:
				var file := FileAccess.open(path, FileAccess.READ)
				if file != null:
					var line_number: int = 0
					while not file.eof_reached():
						line_number += 1
						var line: String = file.get_line()
						for pattern in forbidden_patterns:
							if pattern in line:
								violations.append("CORE_REF_VIOLATION: %s:%d references %s" % [path, line_number, pattern])
					file.close()
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_bare_print_calls(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_bare_print_calls(path, violations)
		elif entry.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				entry = dir.get_next()
				continue
			var line_number: int = 0
			while not file.eof_reached():
				line_number += 1
				var line: String = file.get_line().strip_edges()
				if line.begins_with("print("):
					violations.append("%s:%d" % [path, line_number])
			file.close()
		entry = dir.get_next()
	dir.list_dir_end()
