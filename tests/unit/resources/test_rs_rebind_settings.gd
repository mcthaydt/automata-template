extends GutTest

func test_defaults_match_spec() -> void:
	var settings := RS_RebindSettings.new()
	assert_eq(settings.reserved_actions.size(), 3)
	assert_true(settings.is_reserved(StringName("ui_focus_next")))
	assert_true(settings.is_reserved(StringName("ui_focus_prev")))
	assert_true(settings.is_reserved(StringName("pause")))
	assert_false(settings.is_reserved(StringName("interact")))
	assert_false(settings.allow_conflicts)
	assert_true(settings.require_confirmation)
	assert_eq(settings.max_events_per_action, 3)
	assert_true(settings.warn_on_reserved)
	assert_true(settings.should_warn(StringName("toggle_debug_overlay")))
	assert_false(settings.should_warn(StringName("jump")))

func test_warning_actions_can_be_extended() -> void:
	var settings := RS_RebindSettings.new()
	settings.warning_actions.append(StringName("interact"))
	assert_true(settings.should_warn(StringName("interact")))
