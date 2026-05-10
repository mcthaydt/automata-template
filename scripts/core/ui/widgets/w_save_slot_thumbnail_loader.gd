extends RefCounted
class_name W_SaveSlotThumbnailLoader

static func load_async(texture_rect: TextureRect, path: String, placeholder: Texture2D) -> Dictionary:
	if texture_rect == null:
		return {}
	if path.is_empty() or not FileAccess.file_exists(path):
		texture_rect.texture = placeholder
		return {}
	if path.begins_with("user://"):
		texture_rect.texture = _load_texture_from_image(path, placeholder)
		return {}
	texture_rect.texture = placeholder
	var request_error: Error = ResourceLoader.load_threaded_request(path)
	if request_error != OK:
		texture_rect.texture = _load_texture_from_image(path, placeholder)
		return {}
	return {texture_rect: path}

static func configured_rect(path: String, placeholder: Texture2D, pending: Dictionary) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "Thumbnail"
	rect.custom_minimum_size = Vector2(80, 45)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pending.merge(load_async(rect, path, placeholder))
	return rect

static func poll_pending(pending: Dictionary, placeholder: Texture2D) -> Array[TextureRect]:
	var completed: Array[TextureRect] = []
	for key in pending.keys():
		if not is_instance_valid(key):
			pending.erase(key)
			completed.append(null)
			continue
		var texture_rect := key as TextureRect
		if texture_rect == null:
			pending.erase(key)
			continue
		var path: String = pending.get(texture_rect, "")
		if path.is_empty():
			completed.append(texture_rect)
			continue
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			texture_rect.texture = resource if resource is Texture2D else placeholder
			completed.append(texture_rect)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			texture_rect.texture = _load_texture_from_image(path, placeholder)
			completed.append(texture_rect)
	for texture_rect in completed:
		pending.erase(texture_rect)
	return completed

static func _load_texture_from_image(path: String, placeholder: Texture2D) -> Texture2D:
	if path.begins_with("res://"):
		return placeholder
	var image := Image.load_from_file(path)
	if image == null:
		return placeholder
	var texture := ImageTexture.create_from_image(image)
	return texture
