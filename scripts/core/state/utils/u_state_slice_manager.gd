extends RefCounted
class_name U_StateSliceManager

## Helper for managing state slices and reducers for M_StateStore.
##
## Extracted as part of Phase 9C (T092b) to keep M_StateStore focused on
## orchestration while this helper owns slice registration, dependency
## validation, and reducer application.

const U_VFX_REDUCER := preload("res://scripts/core/state/reducers/u_vfx_reducer.gd")
const U_VCAM_REDUCER := preload("res://scripts/core/state/reducers/u_vcam_reducer.gd")
const U_AUDIO_REDUCER := preload("res://scripts/core/state/reducers/u_audio_reducer.gd")
const U_APP_REDUCER := preload("res://scripts/core/state/reducers/u_app_reducer.gd")
const U_DISPLAY_REDUCER := preload("res://scripts/core/state/reducers/u_display_reducer.gd")
const U_LOCALIZATION_REDUCER := preload("res://scripts/core/state/reducers/u_localization_reducer.gd")
const U_TIME_REDUCER := preload("res://scripts/core/state/reducers/u_time_reducer.gd")
const U_OBJECTIVES_REDUCER := preload("res://scripts/core/state/reducers/u_objectives_reducer.gd")
const U_SCENE_DIRECTOR_REDUCER := preload("res://scripts/core/state/reducers/u_scene_director_reducer.gd")
const RS_OBJECTIVES_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_objectives_initial_state.gd")
const RS_SCENE_DIRECTOR_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_scene_director_initial_state.gd")
const RS_VCAM_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_vcam_initial_state.gd")

## Initialize core slices based on the provided initial state resources.
##
## Populates the given slice_configs and state dictionaries.
static func initialize_slices(
	slice_configs: Dictionary,
	state: Dictionary,
	boot_initial_state: RS_BootInitialState,
	menu_initial_state: RS_MenuInitialState,
	navigation_initial_state: Resource,
	settings_initial_state: RS_SettingsInitialState,
	gameplay_initial_state: RS_GameplayInitialState,
	scene_initial_state: RS_SceneInitialState,
	debug_initial_state: RS_DebugInitialState,
	vcam_initial_state: Resource = null,
	vfx_initial_state: RS_VFXInitialState = null,
	audio_initial_state: RS_AudioInitialState = null,
	display_initial_state: Resource = null,
	objectives_initial_state: Resource = null,
	scene_director_initial_state: Resource = null,
	localization_initial_state: Resource = null,
	time_initial_state: Resource = null
) -> void:
	# Boot slice
	if boot_initial_state != null:
		var boot_config := RS_StateSliceConfig.new(StringName("boot"))
		boot_config.reducer = Callable(U_BootReducer, "reduce")
		boot_config.initial_state = boot_initial_state.to_dictionary()
		boot_config.dependencies = []
		boot_config.transient_fields = []
		register_slice(slice_configs, state, boot_config)

	# Menu slice
	if menu_initial_state != null:
		var menu_config := RS_StateSliceConfig.new(StringName("menu"))
		menu_config.reducer = Callable(U_MenuReducer, "reduce")
		menu_config.initial_state = menu_initial_state.to_dictionary()
		menu_config.dependencies = []
		menu_config.transient_fields = []
		register_slice(slice_configs, state, menu_config)

	# Navigation slice (transient)
	if navigation_initial_state == null:
		navigation_initial_state = RS_NavigationInitialState.new()
	if navigation_initial_state != null:
		var navigation_config := RS_StateSliceConfig.new(StringName("navigation"))
		navigation_config.reducer = Callable(U_NavigationReducer, "reduce")
		navigation_config.initial_state = navigation_initial_state.to_dictionary()
		navigation_config.dependencies = []
		navigation_config.transient_fields = []
		navigation_config.is_transient = true
		register_slice(slice_configs, state, navigation_config)

	# Settings slice
	if settings_initial_state == null:
		settings_initial_state = RS_SettingsInitialState.new()
	if settings_initial_state != null:
		var settings_config := RS_StateSliceConfig.new(StringName("settings"))
		settings_config.reducer = Callable(U_SettingsReducer, "reduce")
		settings_config.initial_state = settings_initial_state.to_dictionary()
		settings_config.dependencies = []
		settings_config.transient_fields = []
		register_slice(slice_configs, state, settings_config)

	# Gameplay slice
	if gameplay_initial_state != null:
		var gameplay_config := RS_StateSliceConfig.new(StringName("gameplay"))
		gameplay_config.reducer = Callable(U_GameplayReducer, "reduce")
		gameplay_config.initial_state = gameplay_initial_state.to_dictionary()
		gameplay_config.dependencies = []
		gameplay_config.transient_fields = [
			StringName("input"),
			StringName("move_input"),
			StringName("look_input"),
			StringName("touch_look_active"),
			StringName("jump_pressed"),
			StringName("jump_just_pressed"),
			StringName("sprint_pressed"),
		]
		register_slice(slice_configs, state, gameplay_config)

	# Scene slice
	if scene_initial_state != null:
		var scene_config := RS_StateSliceConfig.new(StringName("scene"))
		scene_config.reducer = Callable(U_SceneReducer, "reduce")
		scene_config.initial_state = scene_initial_state.to_dictionary()
		scene_config.dependencies = []
		scene_config.transient_fields = ["is_transitioning", "transition_type", "scene_stack"]
		register_slice(slice_configs, state, scene_config)

	# Debug slice
	if debug_initial_state != null:
		var debug_config := RS_StateSliceConfig.new(StringName("debug"))
		debug_config.reducer = Callable(U_DebugReducer, "reduce")
		debug_config.initial_state = debug_initial_state.to_dictionary()
		debug_config.dependencies = []
		debug_config.transient_fields = []
		register_slice(slice_configs, state, debug_config)

	# vCam slice (transient runtime observability)
	if vcam_initial_state == null:
		vcam_initial_state = RS_VCAM_INITIAL_STATE.new()
	if vcam_initial_state != null:
		if not vcam_initial_state.has_method("to_dictionary"):
			push_error("U_StateSliceManager: vcam_initial_state missing to_dictionary()")
		else:
			var vcam_initial_dict: Variant = vcam_initial_state.call("to_dictionary")
			if vcam_initial_dict is Dictionary:
				var vcam_config := RS_StateSliceConfig.new(StringName("vcam"))
				vcam_config.reducer = Callable(U_VCAM_REDUCER, "reduce")
				vcam_config.initial_state = (vcam_initial_dict as Dictionary).duplicate(true)
				vcam_config.dependencies = []
				vcam_config.transient_fields = []
				vcam_config.is_transient = true
				register_slice(slice_configs, state, vcam_config)
			else:
				push_error("U_StateSliceManager: vcam_initial_state.to_dictionary() must return Dictionary")

	# Objectives slice
	if objectives_initial_state == null:
		objectives_initial_state = RS_OBJECTIVES_INITIAL_STATE.new()
	if objectives_initial_state != null:
		var objectives_config := RS_StateSliceConfig.new(StringName("objectives"))
		objectives_config.reducer = Callable(U_OBJECTIVES_REDUCER, "reduce")
		objectives_config.initial_state = objectives_initial_state.to_dictionary()
		objectives_config.dependencies = []
		objectives_config.transient_fields = []
		register_slice(slice_configs, state, objectives_config)

	# Scene director slice (transient)
	if scene_director_initial_state == null:
		scene_director_initial_state = RS_SCENE_DIRECTOR_INITIAL_STATE.new()
	if scene_director_initial_state != null:
		var scene_director_config := RS_StateSliceConfig.new(StringName("scene_director"))
		scene_director_config.reducer = Callable(U_SCENE_DIRECTOR_REDUCER, "reduce")
		scene_director_config.initial_state = scene_director_initial_state.to_dictionary()
		scene_director_config.dependencies = []
		scene_director_config.transient_fields = []
		scene_director_config.is_transient = true
		register_slice(slice_configs, state, scene_director_config)

	# VFX slice
	if vfx_initial_state != null:
		var vfx_config := RS_StateSliceConfig.new(StringName("vfx"))
		vfx_config.reducer = Callable(U_VFX_REDUCER, "reduce")
		vfx_config.initial_state = vfx_initial_state.to_dictionary()
		vfx_config.dependencies = []
		vfx_config.transient_fields = []
		register_slice(slice_configs, state, vfx_config)

	# Audio slice
	if audio_initial_state != null:
		var audio_config := RS_StateSliceConfig.new(StringName("audio"))
		audio_config.reducer = Callable(U_AUDIO_REDUCER, "reduce")
		audio_config.initial_state = audio_initial_state.to_dictionary()
		audio_config.dependencies = []
		audio_config.transient_fields = []
		register_slice(slice_configs, state, audio_config)

	# App lifecycle slice (transient runtime state)
	var app_config := RS_StateSliceConfig.new(StringName("app"))
	app_config.reducer = Callable(U_APP_REDUCER, "reduce")
	app_config.initial_state = U_APP_REDUCER.get_default_app_state()
	app_config.dependencies = []
	app_config.transient_fields = []
	app_config.is_transient = true
	register_slice(slice_configs, state, app_config)

	# Display slice
	if display_initial_state != null:
		var display_config := RS_StateSliceConfig.new(StringName("display"))
		display_config.reducer = Callable(U_DISPLAY_REDUCER, "reduce")
		display_config.initial_state = display_initial_state.to_dictionary()
		display_config.dependencies = []
		display_config.transient_fields = []
		register_slice(slice_configs, state, display_config)

	# Localization slice
	if localization_initial_state != null:
		var loc_config := RS_StateSliceConfig.new(StringName("localization"))
		loc_config.reducer = Callable(U_LOCALIZATION_REDUCER, "reduce")
		loc_config.initial_state = localization_initial_state.to_dictionary()
		loc_config.dependencies = []
		loc_config.transient_fields = []
		register_slice(slice_configs, state, loc_config)

	# Time slice
	if time_initial_state != null:
		var time_config := RS_StateSliceConfig.new(StringName("time"))
		time_config.reducer = Callable(U_TIME_REDUCER, "reduce")
		time_config.initial_state = time_initial_state.to_dictionary()
		time_config.dependencies = []
		time_config.transient_fields = [
			StringName("is_paused"),
			StringName("active_channels"),
			StringName("timescale"),
		]
		register_slice(slice_configs, state, time_config)

## Register a single slice config into the given dictionaries.
static func register_slice(
	slice_configs: Dictionary,
	state: Dictionary,
	config: RS_StateSliceConfig
) -> void:
	if config == null:
		push_error("U_StateSliceManager.register_slice: Config is null")
		return

	if config.slice_name == StringName():
		push_error("U_StateSliceManager.register_slice: Slice name is empty")
		return

	if _has_circular_dependency(slice_configs, config.slice_name, config.dependencies):
		push_error(
			"U_StateSliceManager.register_slice: Circular dependency detected for slice '%s'"
			% String(config.slice_name)
		)
		return

	slice_configs[config.slice_name] = config
	state[config.slice_name] = config.initial_state.duplicate(true)

## Validate that all declared slice dependencies exist and are valid.
static func validate_slice_dependencies(slice_configs: Dictionary) -> bool:
	var all_valid := true

	for slice_name in slice_configs:
		var config: RS_StateSliceConfig = slice_configs[slice_name]
		for dep in config.dependencies:
			if not slice_configs.has(dep):
				push_error(
					"U_StateSliceManager: Slice '%s' declares dependency on unregistered slice '%s'"
					% [String(slice_name), String(dep)]
				)
				all_valid = false

	return all_valid

## Apply reducers for all slices to produce the next state.
##
## Mutates the provided state dictionary and returns true if any slice changed.
static func apply_reducers(
	state: Dictionary,
	slice_configs: Dictionary,
	action: Dictionary,
	signal_batcher: U_SignalBatcher,
	pending_immediate_updates: Dictionary
) -> bool:
	var any_changed: bool = false

	for slice_name in slice_configs:
		var config: RS_StateSliceConfig = slice_configs[slice_name]
		if config == null or config.reducer == Callable():
			continue

		var current_slice: Dictionary = state.get(slice_name, {})
		var reduced: Variant = config.reducer.callv([current_slice, action])

		if not (reduced is Dictionary):
			continue

		var next_slice: Dictionary = reduced as Dictionary

		# Reference equality short-circuit: if the reducer returned the same
		# dictionary reference, the action was not handled by this slice.
		# All reducers return `state` unchanged for unrecognized actions.
		if is_same(next_slice, current_slice):
			continue

		# Reducer produced a new dictionary — store it directly.
		# Reducers always create fresh dicts via state.duplicate(), so
		# next_slice is not shared with any other reference.
		state[slice_name] = next_slice
		any_changed = true

		if signal_batcher != null:
			signal_batcher.mark_slice_dirty(slice_name, next_slice)
		else:
			pending_immediate_updates[slice_name] = next_slice.duplicate(true)

	return any_changed

static func _has_circular_dependency(
	slice_configs: Dictionary,
	slice_name: StringName,
	dependencies: Array[StringName],
	visited: Dictionary = {},
	rec_stack: Dictionary = {}
) -> bool:
	visited[slice_name] = true
	rec_stack[slice_name] = true

	for dep in dependencies:
		if not visited.get(dep, false):
			var dep_config: RS_StateSliceConfig = slice_configs.get(dep)
			if dep_config != null:
				if _has_circular_dependency(slice_configs, dep, dep_config.dependencies, visited, rec_stack):
					return true
		elif rec_stack.get(dep, false):
			return true

	rec_stack[slice_name] = false
	return false

static func _dictionaries_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key):
			return false
		if not _variants_equal(a[key], b[key]):
			return false
	return true

static func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if not _variants_equal(a[i], b[i]):
			return false
	return true

static func _variants_equal(a: Variant, b: Variant) -> bool:
	var type_a: int = typeof(a)
	var type_b: int = typeof(b)
	if type_a != type_b:
		if _is_numeric_type(type_a) and _is_numeric_type(type_b):
			return is_equal_approx(float(a), float(b))
		return false

	match type_a:
		TYPE_DICTIONARY:
			return _dictionaries_equal(a as Dictionary, b as Dictionary)
		TYPE_ARRAY:
			return _arrays_equal(a as Array, b as Array)
		TYPE_FLOAT:
			return is_equal_approx(float(a), float(b))
		TYPE_VECTOR2:
			return (a as Vector2).is_equal_approx(b as Vector2)
		TYPE_VECTOR2I:
			return (a as Vector2i) == (b as Vector2i)
		TYPE_VECTOR3:
			return (a as Vector3).is_equal_approx(b as Vector3)
		TYPE_VECTOR3I:
			return (a as Vector3i) == (b as Vector3i)
		TYPE_VECTOR4:
			return (a as Vector4).is_equal_approx(b as Vector4)
		TYPE_VECTOR4I:
			return (a as Vector4i) == (b as Vector4i)
		TYPE_QUATERNION:
			return (a as Quaternion).is_equal_approx(b as Quaternion)
		TYPE_COLOR:
			return (a as Color).is_equal_approx(b as Color)
		_:
			return a == b

static func _is_numeric_type(type_id: int) -> bool:
	return type_id == TYPE_INT or type_id == TYPE_FLOAT
