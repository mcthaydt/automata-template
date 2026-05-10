@icon("res://assets/core/editor_icons/icn_main_root.svg")
extends Node

## Root scene script (dedicated editor icon + ServiceLocator bootstrap).

const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const U_UI_THEME_DEBUG := preload("res://scripts/core/ui/utils/u_ui_theme_debug.gd")
const U_APP_LIFECYCLE_OBSERVER := preload("res://scripts/core/utils/lifecycle/u_app_lifecycle_observer.gd")
const UI_THEME_CONFIG_DEFAULT := preload("res://resources/core/ui/cfg_ui_theme_default.tres")
const APP_LIFECYCLE_OBSERVER_NAME := "U_AppLifecycleObserver"

func _enter_tree() -> void:
	_theme_debug_log("_enter_tree start")
	_register_demo_scene_entries()
	_initialize_ui_theme_config()
	_initialize_service_locator()
	_ensure_app_lifecycle_observer()

func _register_demo_scene_entries() -> void:
	var scene_registry_loader := preload("res://scripts/core/scene_management/helpers/u_scene_registry_loader.gd")
	var demo_loader := preload("res://scripts/demo/managers/helpers/u_demo_scene_registry_loader.gd")
	scene_registry_loader.add_extension_loader(demo_loader.initialize)

func _ready() -> void:
	_theme_debug_log("_ready start")
	_initialize_ui_theme_config()
	_initialize_service_locator()
	_ensure_app_lifecycle_observer()

func _exit_tree() -> void:
	var is_persistent := _is_persistent_app_root()
	_theme_debug_log("_exit_tree persistent=%s" % str(is_persistent))
	if is_persistent:
		_theme_debug_log("clearing active_config on persistent root exit")
		U_UI_THEME_BUILDER.active_config = null

## Register all managers with the service locator for fast, centralized access
func _initialize_service_locator() -> void:
	# Get references to all manager nodes
	var managers_node := get_node_or_null("Managers")
	if managers_node == null:
		_theme_debug_log("service locator init skipped: no Managers node")
		# Managers node doesn't exist - likely running in test environment
		# Skip ServiceLocator initialization (tests handle their own setup)
		return

	# Check if the critical manager exists (state_store is required for all others)
	# If state_store doesn't exist, we're probably a gameplay scene loaded under root.tscn
	# which already initialized ServiceLocator, or we're in a test environment
	var state_store_node := managers_node.get_node_or_null("M_StateStore")
	if state_store_node == null:
		_theme_debug_log("service locator init skipped: Managers exists, no M_StateStore")
		# No state store in this scene - skip ServiceLocator initialization
		# Tests or root.tscn handle their own ServiceLocator setup
		return

	_theme_debug_log("service locator init proceeding with persistent managers")

	# Register all services (use get_node_or_null to be defensive)
	_register_if_exists(managers_node, "M_StateStore", StringName("state_store"))
	_register_if_exists(managers_node, "M_CursorManager", StringName("cursor_manager"))
	_register_if_exists(managers_node, "M_SceneManager", StringName("scene_manager"))
	_register_if_exists(managers_node, "M_TimeManager", StringName("time_manager"))
	_register_if_exists(managers_node, "M_TimeManager", StringName("pause_manager"))
	_register_if_exists(managers_node, "M_SpawnManager", StringName("spawn_manager"))
	_register_if_exists(managers_node, "M_CameraManager", StringName("camera_manager"))
	_register_if_exists(managers_node, "M_VCamManager", StringName("vcam_manager"))
	_register_if_exists(managers_node, "M_VFXManager", StringName("vfx_manager"))
	_register_if_exists(managers_node, "M_CharacterLightingManager", StringName("character_lighting_manager"))
	_register_if_exists(managers_node, "M_AudioManager", StringName("audio_manager"))
	_register_if_exists(managers_node, "M_DisplayManager", StringName("display_manager"))
	_register_if_exists(managers_node, "M_LocalizationManager", StringName("localization_manager"))
	_register_if_exists(managers_node, "M_InputProfileManager", StringName("input_profile_manager"))
	_register_if_exists(managers_node, "M_InputDeviceManager", StringName("input_device_manager"))
	_register_if_exists(managers_node, "M_UIInputHandler", StringName("ui_input_handler"))
	_register_if_exists(managers_node, "M_SaveManager", StringName("save_manager"))
	_register_if_exists(managers_node, "M_ObjectivesManager", StringName("objectives_manager"))
	_register_if_exists(managers_node, "M_RunCoordinatorManager", StringName("run_coordinator"))
	_register_if_exists(managers_node, "M_SceneDirectorManager", StringName("scene_director"))

	# Register root-level containers and viewport nodes.
	_register_container("HUDLayer", StringName("hud_layer"))
	_register_container("UIOverlayStack", StringName("ui_overlay_stack"))
	_register_container("TransitionOverlay", StringName("transition_overlay"))
	_register_container("LoadingOverlay", StringName("loading_overlay"))
	_register_container("GameViewportContainer/GameViewport", StringName("game_viewport"))
	_register_container("GameViewportContainer/GameViewport/ActiveSceneContainer", StringName("active_scene_container"))
	_register_container("GameViewportContainer/GameViewport/PostProcessOverlay", StringName("post_process_overlay"))

	# Register dependencies for validation
	U_ServiceLocator.register_dependency(StringName("time_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("time_manager"), StringName("cursor_manager"))
	U_ServiceLocator.register_dependency(StringName("spawn_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("scene_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("camera_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("vcam_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("vcam_manager"), StringName("camera_manager"))
	U_ServiceLocator.register_dependency(StringName("vfx_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("vfx_manager"), StringName("camera_manager"))
	U_ServiceLocator.register_dependency(StringName("character_lighting_manager"), StringName("scene_manager"))
	U_ServiceLocator.register_dependency(StringName("character_lighting_manager"), StringName("camera_manager"))
	U_ServiceLocator.register_dependency(StringName("audio_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("display_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("localization_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("input_profile_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("input_device_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("save_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("save_manager"), StringName("scene_manager"))
	U_ServiceLocator.register_dependency(StringName("objectives_manager"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("run_coordinator"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("run_coordinator"), StringName("objectives_manager"))
	U_ServiceLocator.register_dependency(StringName("scene_director"), StringName("state_store"))
	U_ServiceLocator.register_dependency(StringName("scene_director"), StringName("objectives_manager"))

	# Validate all dependencies
	if not U_ServiceLocator.validate_all():
		push_error("Root: Service dependency validation failed")

	# Print dependency graph in verbose mode
	print_verbose(U_ServiceLocator.get_dependency_graph())

## Helper to register a service only if the node exists
func _register_if_exists(parent: Node, node_name: String, service_name: StringName) -> void:
	var node := parent.get_node_or_null(node_name)
	if node != null:
		U_ServiceLocator.register(service_name, node)

func _register_container(path: String, service_name: StringName) -> void:
	var node := get_node_or_null(path)
	if node != null:
		U_ServiceLocator.register(service_name, node)

func _ensure_app_lifecycle_observer() -> void:
	if get_node_or_null(APP_LIFECYCLE_OBSERVER_NAME) != null:
		return
	var observer := U_APP_LIFECYCLE_OBSERVER.new()
	observer.name = APP_LIFECYCLE_OBSERVER_NAME
	add_child(observer)

func _initialize_ui_theme_config() -> void:
	U_UI_THEME_BUILDER.active_config = UI_THEME_CONFIG_DEFAULT
	var cfg_class := UI_THEME_CONFIG_DEFAULT.get_class() if UI_THEME_CONFIG_DEFAULT != null else "null"
	_theme_debug_log("active_config set to default (%s)" % cfg_class)

func _is_persistent_app_root() -> bool:
	var managers_node := get_node_or_null("Managers")
	if managers_node == null:
		return false
	return managers_node.get_node_or_null("M_StateStore") != null

func _theme_debug_log(message: String) -> void:
	var node_path := str(get_path()) if is_inside_tree() else "<not-in-tree>"
	U_UI_THEME_DEBUG.log("Root:%s:%s" % [name, node_path], message)
