extends GutTest

const APP_REDUCER := preload("res://scripts/core/state/reducers/u_app_reducer.gd")
const APP_SELECTORS := preload("res://scripts/core/state/selectors/u_app_selectors.gd")

func test_app_backgrounded_sets_backgrounded_true_and_preserves_other_fields() -> void:
	var state := {
		"is_backgrounded": false,
		"is_focused": true,
		"untouched": {"value": 7},
	}

	var reduced: Dictionary = APP_REDUCER.reduce(state, {
		"type": APP_REDUCER.ACTION_APP_BACKGROUNDED,
	})

	assert_true(bool(reduced.get("is_backgrounded", false)))
	assert_true(bool(reduced.get("is_focused", false)))
	assert_eq(reduced.get("untouched"), {"value": 7})

func test_app_foregrounded_sets_backgrounded_false() -> void:
	var state := {
		"is_backgrounded": true,
		"is_focused": true,
	}

	var reduced: Dictionary = APP_REDUCER.reduce(state, {
		"type": APP_REDUCER.ACTION_APP_FOREGROUNDED,
	})

	assert_false(bool(reduced.get("is_backgrounded", true)))

func test_focus_lost_and_gained_toggle_is_focused() -> void:
	var state := {
		"is_backgrounded": false,
		"is_focused": true,
	}

	var unfocused: Dictionary = APP_REDUCER.reduce(state, {
		"type": APP_REDUCER.ACTION_APP_FOCUS_LOST,
	})
	var focused: Dictionary = APP_REDUCER.reduce(unfocused, {
		"type": APP_REDUCER.ACTION_APP_FOCUS_GAINED,
	})

	assert_false(bool(unfocused.get("is_focused", true)))
	assert_true(bool(focused.get("is_focused", false)))

func test_selectors_return_current_values() -> void:
	var state := {
		"app": {
			"is_backgrounded": true,
			"is_focused": false,
		}
	}

	assert_true(APP_SELECTORS.is_backgrounded(state))
	assert_false(APP_SELECTORS.is_focused(state))

func test_reducer_is_pure_and_does_not_mutate_input() -> void:
	var state := {
		"is_backgrounded": false,
		"is_focused": true,
		"nested": {"value": 12},
	}
	var original := state.duplicate(true)
	var action := {"type": APP_REDUCER.ACTION_APP_BACKGROUNDED}

	var result_a: Dictionary = APP_REDUCER.reduce(state, action)
	var result_b: Dictionary = APP_REDUCER.reduce(state, action)

	assert_eq(result_a, result_b, "Same input and action should produce equal output")
	assert_eq(state, original, "Reducer should not mutate input state")
	assert_ne(state, result_a, "Reducer should return a new dictionary for handled actions")

func test_unknown_action_returns_same_state_reference() -> void:
	var state := APP_REDUCER.get_default_app_state()

	var reduced: Dictionary = APP_REDUCER.reduce(state, {"type": StringName("app/unknown")})

	assert_true(is_same(state, reduced), "Unknown actions should return the original state reference")

func test_state_slice_manager_registers_app_slice() -> void:
	var slice_configs := {}
	var state := {}

	U_StateSliceManager.initialize_slices(
		slice_configs,
		state,
		null,
		null,
		null,
		null,
		null,
		null,
		null
	)

	assert_true(state.has("app"), "State initialization should include the app slice")
	assert_eq(state["app"], APP_REDUCER.get_default_app_state())
