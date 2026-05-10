extends RefCounted
class_name U_SceneRegistryLoader


const PRELOADED_SCENE_REGISTRY_ENTRIES := [
	preload("res://resources/core/scene_registry/cfg_core_scene_entries.tres"),
]

static var _pending_extra_entries: Array[Resource] = []
static var _extension_loaders: Array[Callable] = []


static func add_extension_loader(loader: Callable) -> void:
	if not _extension_loaders.has(loader):
		_extension_loaders.append(loader)

static func clear_extension_loaders() -> void:
	_extension_loaders.clear()

static func register_extra_entry(resource: Resource) -> void:
	_pending_extra_entries.push_back(resource)

const MANIFEST_SCRIPT_PATH := "res://scripts/core/scene_management/u_scene_manifest.gd"


func load_resource_entries(scenes: Dictionary, register_scene_callable: Callable) -> void:
	if register_scene_callable == Callable() or not register_scene_callable.is_valid():
		return

	# Load entries from the builder manifest first (mobile-safe script file).
	var _manifest_result: Dictionary = _load_entries_from_manifest(scenes, register_scene_callable)

	# Mobile/Web-safe baseline: registry resources are preloaded so core scenes remain
	# available even when exported PCKs do not support directory iteration.
	for loader: Callable in U_SceneRegistryLoader._extension_loaders:
		if loader == Callable():
			continue
		loader.call()
	var extra_result: Dictionary = _load_entries_from_resources(
		U_SceneRegistryLoader._pending_extra_entries,
		scenes,
		register_scene_callable,
		true
	)
	U_SceneRegistryLoader._pending_extra_entries.clear()
	var preloaded_result: Dictionary = _load_entries_from_resources(
		PRELOADED_SCENE_REGISTRY_ENTRIES,
		scenes,
		register_scene_callable,
		false
	)

	var res_result: Dictionary = {"loaded": 0, "skipped": 0}
	var test_result: Dictionary = {"loaded": 0, "skipped": 0}
	var convention_result: Dictionary = {"loaded": 0, "skipped": 0}
	convention_result = load_conventional_scene_entries(scenes, register_scene_callable)
	if _should_scan_registry_dirs():
		# Optional additive scan for dev/headless runs so newly-authored resources can
		# register without code changes. Duplicates from the preload manifest are expected.
		res_result = _load_entries_from_dir(
			"res://resources/core/scene_registry",
			scenes,
			register_scene_callable,
			false,
			false
		)
		# tests/scene_registry is optional; don't warn if it's missing.
		test_result = _load_entries_from_dir(
			"res://tests/scene_registry",
			scenes,
			register_scene_callable,
			false,
			false
		)

	# Keep totals available for potential debugging, even if unused by callers.
	var _total_loaded: int = (
		int(preloaded_result.get("loaded", 0)) +
		int(extra_result.get("loaded", 0)) +
		int(res_result.get("loaded", 0)) +
		int(test_result.get("loaded", 0)) +
		int(convention_result.get("loaded", 0))
	)
	var _total_skipped: int = (
		int(preloaded_result.get("skipped", 0)) +
		int(extra_result.get("skipped", 0)) +
		int(res_result.get("skipped", 0)) +
		int(test_result.get("skipped", 0)) +
		int(convention_result.get("skipped", 0))
	)
	_total_loaded = _total_loaded # silence unused variable warning until needed
	_total_skipped = _total_skipped

func load_conventional_scene_entries(
	scenes: Dictionary,
	register_scene_callable: Callable
) -> Dictionary:
	if register_scene_callable == Callable() or not register_scene_callable.is_valid():
		return {"loaded": 0, "skipped": 0}
	if not _should_scan_conventional_scene_paths():
		return {"loaded": 0, "skipped": 0}

	var paths: PackedStringArray = _collect_scene_files_recursive("res://scenes")
	var entries: Dictionary = U_SceneConventionScanner.infer_entries(paths)
	var loaded_count: int = 0
	var skipped_count: int = 0
	var scene_ids: Array = entries.keys()
	scene_ids.sort()

	for scene_id: StringName in scene_ids:
		var entry: Dictionary = entries[scene_id] as Dictionary
		if _register_scene_from_dict(entry, scene_id, scenes, register_scene_callable):
			loaded_count += 1
		else:
			skipped_count += 1

	return {"loaded": loaded_count, "skipped": skipped_count}

func _load_entries_from_manifest(
	scenes: Dictionary,
	register_scene_callable: Callable
) -> Dictionary:
	var loaded_count: int = 0
	var skipped_count: int = 0

	if not (FileAccess.file_exists(MANIFEST_SCRIPT_PATH) or 
		FileAccess.file_exists(MANIFEST_SCRIPT_PATH.trim_suffix(".gd") + ".gdc") or 
		FileAccess.file_exists(MANIFEST_SCRIPT_PATH.trim_suffix(".gd") + ".gde")):
		return {"loaded": 0, "skipped": 0}

	var script: Variant = load(MANIFEST_SCRIPT_PATH)
	if script == null or not (script is Script):
		return {"loaded": 0, "skipped": 0}

	var manifest: RefCounted = script.new()
	if manifest == null or not manifest.has_method("build"):
		return {"loaded": 0, "skipped": 0}

	var result: Variant = manifest.call("build")
	if not (result is Dictionary):
		return {"loaded": 0, "skipped": 0}

	var entries: Dictionary = result as Dictionary
	for scene_id: StringName in entries:
		var entry: Dictionary = entries[scene_id] as Dictionary
		if _register_scene_from_dict(entry, scene_id, scenes, register_scene_callable):
			loaded_count += 1
		else:
			skipped_count += 1

	return {"loaded": loaded_count, "skipped": skipped_count}

func _register_scene_from_dict(
	entry: Dictionary,
	scene_id: StringName,
	scenes: Dictionary,
	register_scene_callable: Callable
) -> bool:
	var path: String = entry.get("path", "")
	var scene_type_value: int = entry.get("scene_type", 1)
	var transition: String = entry.get("default_transition", "fade")
	var priority: int = entry.get("preload_priority", 0)

	if path.is_empty():
		return false

	if scenes.has(scene_id):
		return false

	register_scene_callable.call(scene_id, path, scene_type_value, transition, priority)
	return true

func _load_entries_from_resources(
	resources: Array,
	scenes: Dictionary,
	register_scene_callable: Callable,
	warn_on_duplicates: bool = true
) -> Dictionary:
	var loaded_count: int = 0
	var skipped_count: int = 0

	for i in range(resources.size()):
		var resource: Resource = resources[i] as Resource
		var source_label: String = "preloaded_scene_registry[%d]" % i
		if _register_loaded_entry(resource, source_label, scenes, register_scene_callable, warn_on_duplicates):
			loaded_count += 1
		else:
			skipped_count += 1

	return {"loaded": loaded_count, "skipped": skipped_count}

func _load_entries_from_dir(
	dir_path: String,
	scenes: Dictionary,
	register_scene_callable: Callable,
	warn_on_missing_dir: bool = true,
	warn_on_duplicates: bool = true
) -> Dictionary:
	var loaded_count: int = 0
	var skipped_count: int = 0

	var dir := _open_dir(dir_path)
	if dir == null:
		# In exports (especially mobile/web), relying on directory iteration can fail due to
		# path normalization quirks or export filters. Backfill provides a safety net, but
		# warn so missing entries don't silently downgrade transitions (e.g., "loading" → "fade").
		if warn_on_missing_dir and not (OS.has_feature("headless") or DisplayServer.get_name() == "headless"):
			push_warning("U_SceneRegistryLoader: Could not open dir '%s' for scene registry entries" % dir_path)
		return {"loaded": 0, "skipped": 0}

	var file_names: PackedStringArray = _collect_tres_files(dir, dir_path)
	for file_name in file_names:
		var resource_path: String = _join_path(dir_path, file_name)
		var resource: Resource = load(resource_path)
		if _register_loaded_entry(resource, resource_path, scenes, register_scene_callable, warn_on_duplicates):
			loaded_count += 1
		else:
			skipped_count += 1
	if loaded_count == 0 and skipped_count == 0 and warn_on_missing_dir and not (OS.has_feature("headless") or DisplayServer.get_name() == "headless"):
		push_warning("U_SceneRegistryLoader: No .tres entries found under '%s' (exports may be missing resources/scene_registry files)" % dir_path)
	return {"loaded": loaded_count, "skipped": skipped_count}

func _register_loaded_entry(
	resource: Resource,
	resource_path: String,
	scenes: Dictionary,
	register_scene_callable: Callable,
	warn_on_duplicates: bool
) -> bool:
	if resource == null:
		push_warning("U_SceneRegistryLoader: Failed to load scene registry resource at %s, skipping" % resource_path)
		return false

	if resource is RS_SceneManifestConfig:
		return _register_manifest_config(resource, resource_path, scenes, register_scene_callable, warn_on_duplicates)

	if not (resource is RS_SceneRegistryEntry):
		push_warning("U_SceneRegistryLoader: Resource at %s is not RS_SceneRegistryEntry or RS_SceneManifestConfig (found %s), skipping" % [resource_path, resource.get_class()])
		return false

	var entry := resource as RS_SceneRegistryEntry
	if not entry.is_valid():
		push_warning("U_SceneRegistryLoader: Scene entry in %s is invalid (scene_id or scene_path empty), skipping" % resource_path)
		return false

	if scenes.has(entry.scene_id):
		if warn_on_duplicates:
			push_warning("U_SceneRegistryLoader: Scene '%s' from %s already registered (hardcoded or duplicate), skipping" % [entry.scene_id, resource_path])
		return false

	register_scene_callable.call(
		entry.scene_id,
		entry.scene_path,
		entry.scene_type,
		entry.default_transition,
		entry.preload_priority
	)
	return true

func _register_manifest_config(
	config: RS_SceneManifestConfig,
	resource_path: String,
	scenes: Dictionary,
	register_scene_callable: Callable,
	warn_on_duplicates: bool
) -> bool:
	var loaded_count: int = 0
	for data in config.entries:
		if not config._is_valid_entry_dict(data):
			continue
		var scene_id := StringName(data.get("scene_id", ""))
		if scenes.has(scene_id):
			if warn_on_duplicates:
				push_warning("U_SceneRegistryLoader: Scene '%s' from manifest %s already registered, skipping" % [scene_id, resource_path])
			continue
		register_scene_callable.call(
			scene_id,
			data.get("scene_path", ""),
			int(data.get("scene_type", 2)),
			data.get("default_transition", "fade"),
			int(data.get("preload_priority", 0))
		)
		loaded_count += 1
	return loaded_count > 0

func _should_scan_registry_dirs() -> bool:
	# Mobile/Web exports may block directory iteration in packed resources.
	return not OS.has_feature("mobile") and not OS.has_feature("web")

func _should_scan_conventional_scene_paths() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return false
	return OS.has_feature("editor") or OS.has_feature("headless") or DisplayServer.get_name() == "headless"

func _collect_scene_files_recursive(root_path: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	_collect_scene_files_recursive_at(root_path, result)
	result.sort()
	return result

func _collect_scene_files_recursive_at(dir_path: String, result: PackedStringArray) -> void:
	var dir := _open_dir(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = _join_path(dir_path, file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_collect_scene_files_recursive_at(full_path, result)
		elif file_name.ends_with(".tscn"):
			result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _collect_tres_files(dir: DirAccess, dir_path: String) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()

	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	# Some export targets may not enumerate files via list_dir_begin/get_next even when
	# the directory is accessible. Fallback to static file listing for resiliency.
	if files.is_empty():
		var static_files: PackedStringArray = DirAccess.get_files_at(dir_path.trim_suffix("/"))
		for file_name in static_files:
			if file_name.ends_with(".tres"):
				files.append(file_name)

	files.sort()
	return files

func _open_dir(dir_path: String) -> DirAccess:
	var normalized: String = dir_path.trim_suffix("/")

	var dir := DirAccess.open(normalized)
	if dir != null:
		return dir

	# Some platforms are picky about trailing slashes; try both forms.
	dir = DirAccess.open(normalized + "/")
	return dir

func _join_path(dir_path: String, file_name: String) -> String:
	if dir_path.ends_with("/"):
		return dir_path + file_name
	return dir_path + "/" + file_name

func backfill_default_gameplay_scenes(_scenes: Dictionary, _register_scene_callable: Callable) -> void:
	pass # Removed: manifest is now the single source of truth for non-critical scenes.
