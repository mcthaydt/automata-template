class_name U_SceneDirectorBuilder
extends RefCounted

const M_SCENE_DIRECTOR := preload("res://scripts/core/managers/m_scene_director_manager.gd")

var _root: Node = null


func create_root() -> U_SceneDirectorBuilder:
	var node := Node.new()
	node.name = "M_SceneDirectorManager"
	node.set_script(M_SCENE_DIRECTOR)
	_root = node
	return self


func add_directive(resource: Resource) -> U_SceneDirectorBuilder:
	if _root == null:
		push_error("U_SceneDirectorBuilder: add_directive() called before create_root()")
		return self
	var current: Array[Resource] = _root.directives
	current.append(resource)
	_root.directives = current
	return self


func add_directives(resources: Array[Resource]) -> U_SceneDirectorBuilder:
	if _root == null:
		push_error("U_SceneDirectorBuilder: add_directives() called before create_root()")
		return self
	var current: Array[Resource] = _root.directives
	current.append_array(resources)
	_root.directives = current
	return self


func set_state_store(store) -> U_SceneDirectorBuilder:
	if _root == null:
		push_error("U_SceneDirectorBuilder: set_state_store() called before create_root()")
		return self
	_root.state_store = store
	return self


func build() -> Node:
	if _root == null:
		return null
	return _root


func save(save_path: String) -> bool:
	if _root == null:
		return false
	_set_owner_recursive(_root, _root)
	var packed := PackedScene.new()
	var pack_result := packed.pack(_root)
	if pack_result != OK:
		push_error("U_SceneDirectorBuilder: pack() failed with code %d" % pack_result)
		return false
	var save_result := ResourceSaver.save(packed, save_path)
	if save_result != OK:
		push_error("U_SceneDirectorBuilder: ResourceSaver.save() failed with code %d" % save_result)
		return false
	return true


func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.set_owner(owner)
	var scene_path: String = node.get_scene_file_path()
	if not scene_path.is_empty():
		return
	for child in node.get_children():
		_set_owner_recursive(child, owner)
