extends GutTest

const W_RightStickScroller := preload("res://scripts/core/ui/widgets/w_right_stick_scroller.gd")

func test_bind_scroll_container_sets_target_speed_deadzone() -> void:
	var scroller := W_RightStickScroller.new()
	var scroll := ScrollContainer.new()
	scroller.bind_scroll_container(scroll, 600.0, 0.25)
	assert_eq(scroller._scroll_target, scroll, "Should store scroll target")
	assert_eq(scroller._speed, 600.0, "Should store speed")
	assert_eq(scroller._deadzone, 0.25, "Should store deadzone")
	scroller.queue_free()
	scroll.queue_free()

func test_unsets_process_when_scroll_target_freed() -> void:
	var scroller := W_RightStickScroller.new()
	var scroll := ScrollContainer.new()
	scroller.bind_scroll_container(scroll)
	assert_eq(scroller.process_mode, Node.PROCESS_MODE_ALWAYS, "Process should be set to ALWAYS")
	scroll.free()
	scroller._process(0.016)
	assert_eq(scroller.process_mode, Node.PROCESS_MODE_INHERIT, "Process should return to INHERIT after target freed")
	scroller.queue_free()
