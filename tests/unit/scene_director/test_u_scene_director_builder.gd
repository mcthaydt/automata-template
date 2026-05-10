extends GutTest

const SCENE_DIRECTOR_BUILDER := preload("res://scripts/core/utils/scene_director/u_scene_director_builder.gd")
const M_SCENE_DIRECTOR := preload("res://scripts/core/managers/m_scene_director_manager.gd")
const RS_SCENE_DIRECTIVE := preload("res://scripts/core/resources/scene_director/rs_scene_directive.gd")
const RS_BEAT_DEFINITION := preload("res://scripts/core/resources/scene_director/rs_beat_definition.gd")
const I_STATE_STORE := preload("res://scripts/core/interfaces/i_state_store.gd")

var _temp_path: String = ""

func before_each() -> void:
	_temp_path = "res://tests/unit/scene_director/temp_test_sd.tscn"

func after_each() -> void:
	if not _temp_path.is_empty() and FileAccess.file_exists(_temp_path):
		DirAccess.remove_absolute(_temp_path)

func test_create_root_produces_manager_node() -> void:
	var builder := SCENE_DIRECTOR_BUILDER.new()
	builder.call("create_root")
	var node: Node = builder.call("build")
	assert_not_null(node)
	assert_true(node is M_SCENE_DIRECTOR)
	node.free()

func test_add_directive_appends_to_directives() -> void:
	var builder := SCENE_DIRECTOR_BUILDER.new()
	builder.call("create_root")
	var directive: Resource = RS_SCENE_DIRECTIVE.new()
	directive.directive_id = &"dir_test"
	builder.call("add_directive", directive)
	var node: Node = builder.call("build")
	assert_eq(node.directives.size(), 1)
	assert_eq(node.directives[0].directive_id, &"dir_test")
	node.free()

func test_add_directives_appends_multiple() -> void:
	var builder := SCENE_DIRECTOR_BUILDER.new()
	builder.call("create_root")
	var d1: Resource = RS_SCENE_DIRECTIVE.new()
	d1.directive_id = &"d1"
	var d2: Resource = RS_SCENE_DIRECTIVE.new()
	d2.directive_id = &"d2"
	var list: Array[Resource] = [d1, d2]
	builder.call("add_directives", list)
	var node: Node = builder.call("build")
	assert_eq(node.directives.size(), 2)
	assert_eq(node.directives[0].directive_id, &"d1")
	assert_eq(node.directives[1].directive_id, &"d2")
	node.free()

func test_set_state_store_injects_store() -> void:
	var builder := SCENE_DIRECTOR_BUILDER.new()
	builder.call("create_root")
	var store := StoreStub.new()
	add_child_autofree(store)
	builder.call("set_state_store", store)
	var node: Node = builder.call("build")
	assert_eq(node.state_store, store)
	node.free()
	store.free()

func test_build_without_create_root_returns_null() -> void:
	var builder := SCENE_DIRECTOR_BUILDER.new()
	var result: Node = builder.call("build")
	assert_eq(result, null)

func test_save_produces_tscn_file() -> void:
	var builder := SCENE_DIRECTOR_BUILDER.new()
	builder.call("create_root")
	var directive: Resource = RS_SCENE_DIRECTIVE.new()
	directive.directive_id = &"dir_saved"
	builder.call("add_directive", directive)
	var saved: bool = builder.call("save", _temp_path)
	assert_true(saved)
	assert_true(FileAccess.file_exists(_temp_path))
	builder.call("build").free()

func test_save_without_create_root_returns_false_and_errors() -> void:
	var builder := SCENE_DIRECTOR_BUILDER.new()
	var result: bool = builder.call("save", _temp_path)
	assert_false(result)

func test_fluent_chaining_returns_self() -> void:
	var builder := SCENE_DIRECTOR_BUILDER.new()
	var chain_result: Variant = builder.call("create_root")
	assert_eq(chain_result, builder)

	var directive: Resource = RS_SCENE_DIRECTIVE.new()
	directive.directive_id = &"dir_chain"
	chain_result = builder.call("add_directive", directive)
	assert_eq(chain_result, builder)
	builder.call("build").free()


class StoreStub extends I_STATE_STORE:
	func dispatch(_action: Dictionary) -> void:
		pass

	func subscribe(_callback: Callable) -> Callable:
		return func() -> void: pass

	func get_state() -> Dictionary:
		return {}

	func get_slice(_slice_name: StringName) -> Dictionary:
		return {}

	func is_ready() -> bool:
		return true

	func apply_loaded_state(_loaded_state: Dictionary) -> void:
		pass
