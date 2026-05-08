extends GutTest

const W_TabStrip := preload("res://scripts/core/ui/widgets/w_tab_strip.gd")

var _received_tab_id: int = -1

func _on_tab_switched(id: int) -> void:
    _received_tab_id = id

func test_add_tab_and_switch() -> void:
    var strip := W_TabStrip.new()
    var btn_a := Button.new()
    var btn_b := Button.new()
    strip.add_tab(0, btn_a, &"tab_a", "Tab A")
    strip.add_tab(1, btn_b, &"tab_b", "Tab B")
    add_child_autofree(strip)
    await wait_process_frames(1)
    strip.switch_to_tab(1)
    assert_eq(strip.get_active_tab_id(), 1)
    assert_true(btn_b.button_pressed, "Active tab button should be pressed")

func test_shoulder_navigation_skips_hidden_tabs() -> void:
    var strip := W_TabStrip.new()
    strip.add_tab(0, Button.new(), &"a", "A")
    strip.add_tab(1, Button.new(), &"b", "B")
    strip.add_tab(2, Button.new(), &"c", "C")
    add_child_autofree(strip)
    await wait_process_frames(1)
    strip.set_tab_visible(1, false)
    strip.switch_to_tab(0)
    strip.handle_shoulder_input(1)
    assert_eq(strip.get_active_tab_id(), 2, "Should skip hidden tab 1")

func test_tab_switch_emits_signal() -> void:
    var strip := W_TabStrip.new()
    strip.add_tab(0, Button.new(), &"a", "A")
    add_child_autofree(strip)
    await wait_process_frames(1)
    _received_tab_id = -1
    strip.tab_switched.connect(_on_tab_switched)
    strip.switch_to_tab(0)
    assert_eq(_received_tab_id, 0)
