extends GutTest

const W_MotionTargetResolver := preload("res://scripts/core/ui/widgets/w_motion_target_resolver.gd")

func test_resolve_explicit_path() -> void:
	var screen := Control.new()
	var target := Button.new()
	target.name = "Target"
	screen.add_child(target)
	add_child_autofree(screen)
	await wait_process_frames(1)

	var result := W_MotionTargetResolver.resolve(screen, NodePath("Target"))
	assert_eq(result, target, "Should return the explicit target node")

func test_resolve_center_container_with_panel() -> void:
	var screen := Control.new()
	var bg := ColorRect.new()
	bg.name = "Background"
	screen.add_child(bg)
	var center := CenterContainer.new()
	screen.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	add_child_autofree(screen)
	await wait_process_frames(1)

	var result := W_MotionTargetResolver.resolve(screen, NodePath())
	assert_eq(result, center, "Should return CenterContainer when backdrop + panel exist")

func test_resolve_fallback_to_self() -> void:
	var screen := Control.new()
	add_child_autofree(screen)
	await wait_process_frames(1)

	var result := W_MotionTargetResolver.resolve(screen, NodePath())
	assert_eq(result, screen, "Should fall back to screen when no backdrop or explicit target")

func test_has_backdrop_layer_detects_background() -> void:
	var screen := Control.new()
	var bg := TextureRect.new()
	bg.name = "BackgroundImage"
	screen.add_child(bg)
	add_child_autofree(screen)
	await wait_process_frames(1)

	assert_true(W_MotionTargetResolver._has_backdrop_layer(screen), "Should detect BackgroundImage as backdrop")

func test_find_panel_descendant_recursive() -> void:
	var root := Control.new()
	var nested := Control.new()
	var panel := PanelContainer.new()
	nested.add_child(panel)
	root.add_child(nested)
	add_child_autofree(root)
	await wait_process_frames(1)

	var result := W_MotionTargetResolver._find_panel_descendant(root)
	assert_eq(result, panel, "Should find PanelContainer nested deeply")
