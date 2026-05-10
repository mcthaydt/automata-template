extends RefCounted
class_name U_SceneConventionScanner

const SCENE_TYPE_GAMEPLAY := 1
const SCENE_TYPE_UI := 2

const DEFAULT_GAMEPLAY_TRANSITION := "loading"
const DEFAULT_GAMEPLAY_PRELOAD_PRIORITY := 5
const DEFAULT_UI_TRANSITION := "instant"
const DEFAULT_UI_PRELOAD_PRIORITY := 5


static func infer_entry(path: String) -> Dictionary:
	if _should_ignore_path(path):
		return {}
	if not path.begins_with("res://scenes/") or not path.ends_with(".tscn"):
		return {}

	if _is_gameplay_scene_path(path):
		return _build_entry(
			path,
			_strip_scene_prefix(path.get_file().get_basename(), "gameplay_"),
			SCENE_TYPE_GAMEPLAY,
			DEFAULT_GAMEPLAY_TRANSITION,
			DEFAULT_GAMEPLAY_PRELOAD_PRIORITY
		)

	if _is_ui_scene_path(path):
		return _build_entry(
			path,
			_strip_scene_prefix(path.get_file().get_basename(), "ui_"),
			SCENE_TYPE_UI,
			DEFAULT_UI_TRANSITION,
			DEFAULT_UI_PRELOAD_PRIORITY
		)

	return {}

static func infer_entries(paths: PackedStringArray) -> Dictionary:
	var entries: Dictionary = {}
	for path: String in paths:
		var entry: Dictionary = infer_entry(path)
		if entry.is_empty():
			continue
		entries[entry["scene_id"]] = entry
	return entries

static func _build_entry(
	path: String,
	scene_id: String,
	scene_type: int,
	default_transition: String,
	preload_priority: int
) -> Dictionary:
	if scene_id.is_empty():
		return {}
	return {
		"scene_id": StringName(scene_id),
		"path": path,
		"scene_type": scene_type,
		"default_transition": default_transition,
		"preload_priority": preload_priority,
	}

static func _should_ignore_path(path: String) -> bool:
	return (
		path.contains("/prefabs/") or
		path.contains("/templates/") or
		path.contains("/ui/widgets/")
	)

static func _is_gameplay_scene_path(path: String) -> bool:
	return path.contains("/gameplay/") and path.get_file().begins_with("gameplay_")

static func _is_ui_scene_path(path: String) -> bool:
	return (
		(path.contains("/ui/overlays/") or path.contains("/ui/settings/")) and
		path.get_file().begins_with("ui_")
	)

static func _strip_scene_prefix(file_basename: String, prefix: String) -> String:
	if file_basename.begins_with(prefix):
		return file_basename.trim_prefix(prefix)
	return file_basename
