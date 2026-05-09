@icon("res://assets/core/editor_icons/icn_utility.svg")
extends VBoxContainer
class_name UI_VFXSettingsTab

const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_SETTINGS_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_settings_tab_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_VFX_ACTIONS := preload("res://scripts/core/state/actions/u_vfx_actions.gd")
const U_VFX_SELECTORS := preload("res://scripts/core/state/selectors/u_vfx_selectors.gd")
const RS_VFX_INITIAL_STATE := preload("res://scripts/core/resources/state/rs_vfx_initial_state.gd")
const W_SETTINGS_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/widgets/w_settings_focus_configurator.gd")

const TITLE_KEY := &"settings.vfx.title"
const LABEL_SCREEN_SHAKE_KEY := &"settings.vfx.label.screen_shake"
const LABEL_SHAKE_INTENSITY_KEY := &"settings.vfx.label.shake_intensity"
const LABEL_DAMAGE_FLASH_KEY := &"settings.vfx.label.damage_flash"
const LABEL_PARTICLES_KEY := &"settings.vfx.label.particles"
const BUTTON_RESET_DEFAULTS_KEY := &"settings.vfx.button.reset_defaults"

const TOOLTIP_SCREEN_SHAKE_KEY := &"settings.vfx.tooltip.screen_shake"
const TOOLTIP_SHAKE_INTENSITY_KEY := &"settings.vfx.tooltip.shake_intensity"
const TOOLTIP_DAMAGE_FLASH_KEY := &"settings.vfx.tooltip.damage_flash"
const TOOLTIP_PARTICLES_KEY := &"settings.vfx.tooltip.particles"

var _state_store: I_StateStore = null
var _unsubscribe: Callable = Callable()
var _updating_from_state: bool = false
var _builder: RefCounted = null
var _vfx_manager: M_VFXManager = null

var _shake_enabled_toggle: CheckBox
var _intensity_slider: HSlider
var _intensity_percentage: Label
var _flash_enabled_toggle: CheckBox
var _particles_enabled_toggle: CheckBox
var _reset_button: Button

func _ready() -> void:
	_setup_builder()
	if _builder != null:
		_builder.build()
	_capture_control_references()
	_configure_focus_neighbors()
	_configure_tooltips()
	set_meta(&"settings_builder", true)

	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		push_error("UI_VFXSettingsTab: StateStore not found")
		return

	_vfx_manager = U_ServiceLocator.try_get_service(StringName("vfx_manager")) as M_VFXManager

	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

func _setup_builder() -> void:
	_builder = U_SETTINGS_TAB_BUILDER.new(self)
	_builder.bind_theme_role(self, &"separation_default")
	_builder.set_heading(TITLE_KEY)
	_builder.add_toggle(LABEL_SCREEN_SHAKE_KEY, _on_shake_enabled_toggled, TOOLTIP_SCREEN_SHAKE_KEY, "Enables camera shake feedback.", "ShakeEnabledToggle")
	_builder.add_slider(LABEL_SHAKE_INTENSITY_KEY, 0.0, 2.0, 0.1, _on_intensity_changed, &"", TOOLTIP_SHAKE_INTENSITY_KEY, "Adjusts camera shake strength.", "IntensitySlider")
	_builder.add_toggle(LABEL_DAMAGE_FLASH_KEY, _on_flash_enabled_toggled, TOOLTIP_DAMAGE_FLASH_KEY, "Flashes the screen when taking damage.", "FlashEnabledToggle")
	_builder.add_toggle(LABEL_PARTICLES_KEY, _on_particles_enabled_toggled, TOOLTIP_PARTICLES_KEY, "Shows particle effects.", "ParticlesEnabledToggle")
	_builder.add_button_row(Callable(), Callable(), _on_reset_pressed, &"", &"", BUTTON_RESET_DEFAULTS_KEY, "", "", "Reset to Defaults")

func _capture_control_references() -> void:
	_shake_enabled_toggle = _find_child_by_name(self, "ShakeEnabledToggle") as CheckBox
	_intensity_slider = _find_child_by_name(self, "IntensitySlider") as HSlider
	_intensity_percentage = _find_child_by_name(self, "IntensitySliderValue") as Label
	_flash_enabled_toggle = _find_child_by_name(self, "FlashEnabledToggle") as CheckBox
	_particles_enabled_toggle = _find_child_by_name(self, "ParticlesEnabledToggle") as CheckBox
	_reset_button = _find_child_by_name(self, "ResetButton") as Button

func _find_child_by_name(parent: Node, name: String) -> Node:
	for child in parent.get_children():
		if child.name == name:
			return child
		var result := _find_child_by_name(child, name)
		if result != null:
			return result
	return null

func _exit_tree() -> void:
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()

func _enter_tree() -> void:
	if not is_node_ready():
		return
	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if _state_store == null:
		return
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		return
	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

func _configure_focus_neighbors() -> void:
	W_SETTINGS_FOCUS_CONFIGURATOR.configure_vertical(self, [
		func() -> Control: return _shake_enabled_toggle,
		func() -> Control: return _intensity_slider,
		func() -> Control: return _flash_enabled_toggle,
		func() -> Control: return _particles_enabled_toggle,
	])

	# Connect last vertical control to reset button
	var last_control: Control = null
	for ctrl in [_shake_enabled_toggle, _intensity_slider, _flash_enabled_toggle, _particles_enabled_toggle]:
		if ctrl != null and ctrl.focus_mode != Control.FOCUS_NONE and ctrl.visible:
			last_control = ctrl
	if last_control != null and _reset_button != null:
		last_control.focus_neighbor_bottom = last_control.get_path_to(_reset_button)
		_reset_button.focus_neighbor_top = _reset_button.get_path_to(last_control)
		_reset_button.focus_neighbor_bottom = _reset_button.get_path_to(last_control)

func _configure_tooltips() -> void:
	if _shake_enabled_toggle != null:
		_shake_enabled_toggle.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_SCREEN_SHAKE_KEY,
			"Enables camera shake feedback."
		)
	if _intensity_slider != null:
		_intensity_slider.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_SHAKE_INTENSITY_KEY,
			"Adjusts camera shake strength."
		)
	if _flash_enabled_toggle != null:
		_flash_enabled_toggle.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_DAMAGE_FLASH_KEY,
			"Flashes the screen when taking damage."
		)
	if _particles_enabled_toggle != null:
		_particles_enabled_toggle.tooltip_text = U_LOCALIZATION_UTILS.localize_with_fallback(
			TOOLTIP_PARTICLES_KEY,
			"Shows particle effects."
		)

func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
	if state == null or state.is_empty():
		return

	_updating_from_state = true

	if _shake_enabled_toggle != null:
		_shake_enabled_toggle.set_block_signals(true)
		_shake_enabled_toggle.button_pressed = U_VFXSelectors.is_screen_shake_enabled(state)
		_shake_enabled_toggle.set_block_signals(false)

	if _intensity_slider != null:
		var intensity := U_VFXSelectors.get_screen_shake_intensity(state)
		_intensity_slider.set_block_signals(true)
		_intensity_slider.value = intensity
		_intensity_slider.set_block_signals(false)
		_update_percentage_label(intensity)

	if _flash_enabled_toggle != null:
		_flash_enabled_toggle.set_block_signals(true)
		_flash_enabled_toggle.button_pressed = U_VFXSelectors.is_damage_flash_enabled(state)
		_flash_enabled_toggle.set_block_signals(false)

	if _particles_enabled_toggle != null:
		_particles_enabled_toggle.set_block_signals(true)
		_particles_enabled_toggle.button_pressed = U_VFXSelectors.is_particles_enabled(state)
		_particles_enabled_toggle.set_block_signals(false)

	_updating_from_state = false

func _on_shake_enabled_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	if _state_store != null:
		_state_store.dispatch(U_VFXActions.set_screen_shake_enabled(pressed))

func _on_intensity_changed(value: float) -> void:
	_update_percentage_label(value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	if _state_store != null:
		_state_store.dispatch(U_VFXActions.set_screen_shake_intensity(value))
	if _vfx_manager != null:
		_vfx_manager.trigger_test_shake(value)

func _on_flash_enabled_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	if _state_store != null:
		_state_store.dispatch(U_VFXActions.set_damage_flash_enabled(pressed))

func _on_particles_enabled_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	if _state_store != null:
		_state_store.dispatch(U_VFXActions.set_particles_enabled(pressed))

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var defaults := RS_VFXInitialState.new()

	_updating_from_state = true
	if _shake_enabled_toggle != null:
		_shake_enabled_toggle.set_block_signals(true)
		_shake_enabled_toggle.button_pressed = defaults.screen_shake_enabled
		_shake_enabled_toggle.set_block_signals(false)
	if _intensity_slider != null:
		_intensity_slider.set_block_signals(true)
		_intensity_slider.value = defaults.screen_shake_intensity
		_intensity_slider.set_block_signals(false)
		_update_percentage_label(defaults.screen_shake_intensity)
	if _flash_enabled_toggle != null:
		_flash_enabled_toggle.set_block_signals(true)
		_flash_enabled_toggle.button_pressed = defaults.damage_flash_enabled
		_flash_enabled_toggle.set_block_signals(false)
	if _particles_enabled_toggle != null:
		_particles_enabled_toggle.set_block_signals(true)
		_particles_enabled_toggle.button_pressed = defaults.particles_enabled
		_particles_enabled_toggle.set_block_signals(false)
	_updating_from_state = false

	if _state_store != null:
		_state_store.dispatch(U_VFXActions.set_screen_shake_enabled(defaults.screen_shake_enabled))
		_state_store.dispatch(U_VFXActions.set_screen_shake_intensity(defaults.screen_shake_intensity))
		_state_store.dispatch(U_VFXActions.set_damage_flash_enabled(defaults.damage_flash_enabled))
		_state_store.dispatch(U_VFXActions.set_particles_enabled(defaults.particles_enabled))

func _update_percentage_label(value: float) -> void:
	if _intensity_percentage != null:
		_intensity_percentage.text = "%d%%" % int(value * 100.0)

func _on_locale_changed(_locale: StringName) -> void:
	_localize_labels()
	_configure_tooltips()

func _localize_labels() -> void:
	if _builder != null:
		_builder.localize_labels()
