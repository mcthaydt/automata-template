# Redux State Store Usage Guide

**Version**: 1.0  
**Last Updated**: 2025-10-27  
**For**: SSA Rising State Store v3.0

This guide shows common patterns and examples for using the Redux-style state store in SSA Rising.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Concepts](#core-concepts)
3. [Common Patterns](#common-patterns)
4. [Adding New State](#adding-new-state)
5. [ECS System Integration](#ecs-system-integration)
6. [Testing State Code](#testing-state-code)
7. [Debugging & Tools](#debugging--tools)
8. [Hot Reload & Live Editing](#hot-reload--live-editing)
9. [Performance Tips](#performance-tips)
10. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Accessing the Store

```gdscript
# In any node (system, manager, UI):
func _ready() -> void:
    # Wait for store to register in group
    await get_tree().process_frame
    
    var store: M_StateStore = U_StateUtils.get_store(self)
    if not store:
        push_error("Could not find M_StateStore")
        return
```

### Dispatching Actions

```gdscript
# Dispatch an action to update state
store.dispatch(U_GameplayActions.pause_game())
store.dispatch(U_EntityActions.update_entity_snapshot("player", {"position": Vector3(10, 5, 0)}))
store.dispatch(U_MenuActions.navigate_to_screen("settings"))
```

### Reading State

```gdscript
# Get entire slice
var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
var is_paused: bool = gameplay_state.get("paused", false)

# Use selectors for derived state
var player_pos: Vector3 = EntitySelectors.get_player_position(gameplay_state)
var is_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
```

### Subscribing to Changes

```gdscript
var _store: M_StateStore
var _subscription_id: int

func _ready() -> void:
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)
    
    # Subscribe to slice updates
    _subscription_id = _store.subscribe(_on_state_changed)

func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
    print("State changed by: ", action.get("type"))
    
    # Read updated state
    var gameplay: Dictionary = new_state.get("gameplay", {})
    var is_paused: bool = gameplay.get("paused", false)
    _update_pause_indicator(is_paused)

func _exit_tree() -> void:
    # Clean up subscription
    if _store and _subscription_id >= 0:
        _store.unsubscribe(_subscription_id)
```

---

## Core Concepts

### State Slices

State is organized into **slices** - independent domains of state:

- **boot**: Loading progress, initialization state
- **menu**: Active screen, character/difficulty selection
- **gameplay**: Health, score, level, pause state

Each slice has its own:
- Initial state resource (`RS_*InitialState`)
- Actions (`U_*Actions`)
- Reducer (`*Reducer`)
- Selectors (`*Selectors`)

### Actions

Actions are plain dictionaries describing state changes:

```gdscript
{
    "type": StringName("gameplay/pause"),
    "payload": null
}
```

**Never create action dictionaries manually** - always use action creators:

```gdscript
# CORRECT
store.dispatch(U_GameplayActions.pause_game())

# WRONG - fragile, no type checking
store.dispatch({"type": "gameplay/pause", "payload": null})
```

### Reducers

Reducers are pure functions that compute new state:

```gdscript
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var next_state: Dictionary = state.duplicate(true)
    
    match action.get("type"):
        U_GameplayActions.ACTION_UPDATE_HEALTH:
            next_state["health"] = action.get("payload", {}).get("health", 0)
        
        U_GameplayActions.ACTION_TAKE_DAMAGE:
            var amount: int = action.get("payload", {}).get("amount", 0)
            next_state["health"] = max(0, next_state.get("health", 0) - amount)
    
    return next_state
```

**Rules for reducers:**
1. Always duplicate state first: `state.duplicate(true)`
2. Never modify input state directly
3. Return new state object
4. Keep logic pure (no side effects, no I/O)

### Selectors

Selectors derive computed values from state:

```gdscript
class_name GameplaySelectors

# Simple field access
static func get_health(state: Dictionary) -> int:
    return state.get("health", 100)

# Derived/computed values
static func is_low_health(state: Dictionary) -> bool:
    return get_health(state) < 30

static func is_game_over(state: Dictionary) -> bool:
    return get_health(state) <= 0
```

---

## Common Patterns

### Pattern 1: UI Subscribing to State

```gdscript
# HUD displays health from state
extends Control

var _store: M_StateStore
var _sub_id: int
@onready var health_label: Label = $HealthLabel

func _ready() -> void:
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)
    _sub_id = _store.subscribe(_on_state_changed)
    
    # Initialize UI with current state
    _update_ui(_store.get_state())

func _on_state_changed(_action: Dictionary, new_state: Dictionary) -> void:
    _update_ui(new_state)

func _update_ui(state: Dictionary) -> void:
    var gameplay: Dictionary = state.get("gameplay", {})
    var health: int = GameplaySelectors.get_health(gameplay)
    health_label.text = "Health: %d" % health

func _exit_tree() -> void:
    if _store:
        _store.unsubscribe(_sub_id)
```

### Pattern 2: ECS System Dispatching Actions

```gdscript
# System updates state based on entity changes
extends BaseECSSystem

var _store: M_StateStore

func _ready() -> void:
    super._ready()
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)

func process_tick(_delta: float) -> void:
    # Get player entity
    var player: Node3D = _get_player()
    if not player:
        return
    
    # Read component
    var health_comp: C_HealthComponent = player.get_node_or_null("C_HealthComponent")
    if not health_comp:
        return
    
    # Sync component to state
    var current_state: Dictionary = _store.get_slice(StringName("gameplay"))
    var state_paused: bool = GameplaySelectors.get_is_paused(current_state)
    
    # Example: Sync component state with store
    if should_pause and not state_paused:
        _store.dispatch(U_GameplayActions.pause_game())
```

### Pattern 3: State-Driven System Behavior

```gdscript
# System reacts to state changes
extends BaseECSSystem

var _store: M_StateStore
var _is_paused: bool = false

func _ready() -> void:
    super._ready()
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)
    _store.slice_updated.connect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
    if slice_name == "gameplay":
        var was_paused: bool = _is_paused
        _is_paused = GameplaySelectors.get_is_paused(slice_state)
        
        if _is_paused != was_paused:
            _on_pause_changed(_is_paused)

func _on_pause_changed(paused: bool) -> void:
    if paused:
        print("Game paused - stop processing")
    else:
        print("Game unpaused - resume processing")

func process_tick(delta: float) -> void:
    if _is_paused:
        return  # Skip processing while paused
    
    # Normal system logic...
```

### Pattern 4: State Transitions

```gdscript
# Transitioning between game states
func _on_start_game_pressed() -> void:
    # Read menu configuration
    var menu_state: Dictionary = _store.get_slice(StringName("menu"))
    var config: Dictionary = {
        "character": menu_state.get("pending_character"),
        "difficulty": menu_state.get("pending_difficulty")
    }
    
    # Transition to gameplay with config
    _store.dispatch(U_TransitionActions.transition_to_gameplay(config))
    
    # Load gameplay scene
    get_tree().change_scene_to_file("res://scenes/demo/gameplay/level_01.tscn")
```

---

## Adding New State

Follow this 5-step pattern to add new state fields:

### Step 1: Update Initial State Resource

```gdscript
# scripts/core/state/resources/rs_gameplay_initial_state.gd
class_name RS_GameplayInitialState
extends Resource

@export var health: int = 100
@export var score: int = 0
@export var level: int = 1
@export var combo: int = 0  # NEW FIELD
```

### Step 2: Add Action Creator

```gdscript
# scripts/core/state/actions/u_gameplay_actions.gd
const ACTION_UPDATE_COMBO := StringName("gameplay/update_combo")

static func _static_init() -> void:
    # Register action
    ActionRegistry.register_action(ACTION_UPDATE_COMBO)
    # ... other registrations

static func update_combo(combo: int) -> Dictionary:
    return {
        "type": ACTION_UPDATE_COMBO,
        "payload": {"combo": combo}
    }
```

### Step 3: Update Reducer

```gdscript
# scripts/core/state/reducers/gameplay_reducer.gd
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var next_state: Dictionary = state.duplicate(true)
    
    match action.get("type"):
        U_GameplayActions.ACTION_UPDATE_COMBO:
            var combo: int = action.get("payload", {}).get("combo", 0)
            next_state["combo"] = combo
        # ... other cases
    
    return next_state
```

### Step 4: Add Selector (if needed)

```gdscript
# scripts/core/state/selectors/u_gameplay_selectors.gd
static func get_combo(state: Dictionary) -> int:
    return state.get("combo", 0)

static func is_combo_active(state: Dictionary) -> bool:
    return get_combo(state) > 0
```

### Step 5: Add Tests

```gdscript
# tests/unit/state/test_gameplay_slice_reducers.gd
func test_update_combo() -> void:
    # GIVEN initial state with combo = 0
    var initial: Dictionary = _create_initial_state()
    assert_eq(initial.get("combo"), 0)
    
    # WHEN update_combo action dispatched
    var action: Dictionary = U_GameplayActions.update_combo(5)
    var next: Dictionary = GameplayReducer.reduce(initial, action)
    
    # THEN combo should update
    assert_eq(next.get("combo"), 5)
    
    # AND original state unchanged (immutability)
    assert_eq(initial.get("combo"), 0)
```

---

## ECS System Integration

### Recommended Pattern: State as Source of Truth

Use state store as the **single source of truth**, with ECS components as implementation details:

```gdscript
# S_HealthSystem.gd - syncs components to state
extends BaseECSSystem

var _store: M_StateStore

func _ready() -> void:
    super._ready()
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)
    _store.slice_updated.connect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
    if slice_name != "gameplay":
        return
    
    # Read state
    var health: int = GameplaySelectors.get_health(slice_state)
    
    # Sync to component
    var player: Node3D = _get_player()
    if not player:
        return
    
    var health_comp: C_HealthComponent = player.get_node_or_null("C_HealthComponent")
    if health_comp:
        health_comp.current_health = health

func process_tick(_delta: float) -> void:
    # System can still update state based on game logic
    var player: Node3D = _get_player()
    if not player:
        return
    
    var health_comp: C_HealthComponent = player.get_node_or_null("C_HealthComponent")
    if not health_comp:
        return
    
    # Detect health changes and dispatch
    var state: Dictionary = _store.get_slice(StringName("gameplay"))
    var entities: Dictionary = state.get("entities", {})
    
    # Dispatch entity snapshot to state
    _store.dispatch(U_EntityActions.update_entity_snapshot("player", {
        "position": body.global_position,
        "velocity": body.velocity
    }))
```

---

## Testing State Code

### Reducer Tests

```gdscript
extends GutTest

func before_each() -> void:
    # Reset action registry between tests
    ActionRegistry._registered_actions.clear()
    U_GameplayActions._static_init()

func test_pause_sets_paused_true() -> void:
    # GIVEN state with paused = false
    var state: Dictionary = {"paused": false, "entities": {}}
    
    # WHEN pause action dispatched
    var action: Dictionary = U_GameplayActions.pause_game()
    var next: Dictionary = GameplayReducer.reduce(state, action)
    
    # THEN paused = true
    assert_eq(next.get("paused"), true)
    
    # AND original state unchanged
    assert_eq(state.get("paused"), false)

func test_health_cannot_go_negative() -> void:
    # GIVEN paused state
    var state: Dictionary = {"paused": true}
    
    # WHEN unpause action dispatched
    var action: Dictionary = U_GameplayActions.unpause_game()
    var next: Dictionary = GameplayReducer.reduce(state, action)
    
    # THEN paused = false
    assert_eq(next.get("paused"), false)
```

### Selector Tests

```gdscript
func test_is_low_health_threshold() -> void:
    # GIVEN state with 29 health
    var state: Dictionary = {"health": 29}
    
    # WHEN checking is_low_health
    var result: bool = GameplaySelectors.is_low_health(state)
    
    # THEN should return true (< 30)
    assert_true(result)

func test_is_not_low_health() -> void:
    # GIVEN state with 30 health
    var state: Dictionary = {"health": 30}
    
    # WHEN checking is_low_health
    var result: bool = GameplaySelectors.is_low_health(state)
    
    # THEN should return false (>= 30)
    assert_false(result)
```

### Integration Tests

```gdscript
func test_full_store_integration() -> void:
    # GIVEN a configured store
    var store: M_StateStore = autofree(M_StateStore.new())
    var settings := RS_StateStoreSettings.new()
    settings.enable_history = true
    store.settings = settings
    
    # Add gameplay slice
    var initial_state := RS_GameplayInitialState.new()
    initial_state.health = 100
    store.gameplay_initial_state = initial_state
    
    store._initialize()
    
    # WHEN dispatching actions
    store.dispatch(U_GameplayActions.pause_game())
    store.dispatch(U_EntityActions.update_entity_snapshot("player", {}))
    
    # THEN state updates correctly
    var state: Dictionary = store.get_slice(StringName("gameplay"))
    assert_eq(state.get("health"), 80)
    assert_eq(state.get("score"), 100)
    
    # AND history recorded
    assert_eq(store.get_action_count(), 2)
```

---

## Debugging & Tools

### Debug Overlay (F3)

Press **F3** to toggle the debug overlay showing:
- Current state for all slices
- Recent action history (last 10 actions)
- Timestamps and action types

### Manual State Inspection

```gdscript
# Get full state tree
var full_state: Dictionary = store.get_state()
print(JSON.stringify(full_state, "  "))

# Get specific slice
var gameplay: Dictionary = store.get_slice(StringName("gameplay"))
print("Health: ", gameplay.get("health"))
print("Score: ", gameplay.get("score"))
```

### Action History

```gdscript
# Get recent actions
var history: Array = store.get_action_history(10)
for action_entry in history:
    print("[%d] %s - %s" % [
        action_entry.get("timestamp"),
        action_entry.get("action", {}).get("type"),
        action_entry.get("action", {}).get("payload")
    ])
```

### Benchmarking Performance

```gdscript
# Measure dispatch overhead
var start_time: int = Time.get_ticks_usec()

for i in range(1000):
    var action: Dictionary = U_GameplayActions.pause_game() if i % 2 == 0 else U_GameplayActions.unpause_game()
    store.dispatch(action)

var elapsed_ms: float = (Time.get_ticks_usec() - start_time) / 1000.0
var avg_per_dispatch: float = elapsed_ms / 1000.0
print("Avg dispatch time: %.3f ms" % avg_per_dispatch)
```

---

## Hot Reload & Live Editing

The state store supports Godot's hot reload feature with some caveats:

### What Persists During Hot Reload

- **Current state values**: All slice data persists
- **Action history**: Recent actions remain in memory
- **Subscriptions**: Signal connections persist

### What Requires Scene Restart

- **Reducer logic changes**: Modified reducer functions won't apply until scene restart
- **New actions**: Adding new action types requires ActionRegistry re-initialization
- **Slice structure changes**: Adding/removing slices requires full restart

### Initial State Resource Editing

Changes to `.tres` files apply on next scene load:

1. Edit `default_gameplay_initial_state.tres` in inspector
2. Save resource
3. Reload scene (F6) or restart game
4. New initial state takes effect

**Example**: Change default health from 100 to 150
- Edit resource → Save → Reload scene → New games start with 150 health

### Live Debugging Workflow

1. **Run game** (F5)
2. **Toggle debug overlay** (F3) to see state
3. **Dispatch actions** via game interactions
4. **Edit reducer logic** → Save
5. **Hot reload** (happens automatically)
6. **Restart scene** (F6) to see reducer changes

---

## Performance Tips

### Tip 1: Use Selectors for Derived State

```gdscript
# GOOD - selector caches logic
var is_low: bool = GameplaySelectors.is_low_health(state)

# AVOID - recalculating every time
var is_low: bool = state.get("health", 0) < 30
```

### Tip 2: Minimize State Duplication

```gdscript
# GOOD - store IDs, derive rest
{
    "selected_character_id": "warrior",
    "selected_difficulty": "hard"
}

# AVOID - storing redundant computed data
{
    "selected_character_id": "warrior",
    "selected_character_name": "Warrior",  # Can be derived
    "selected_character_health": 100,       # Can be derived
    "selected_difficulty": "hard"
}
```

### Tip 3: Batch Related Actions

```gdscript
# AVOID - multiple dispatches for same entity
store.dispatch(U_EntityActions.update_entity_snapshot("player", {"position": pos}))
store.dispatch(U_EntityActions.update_entity_snapshot("player", {"velocity": vel}))
store.dispatch(U_EntityActions.update_entity_snapshot("player", {"rotation": rot}))

# BETTER - single compound action (if frequently used together)
const ACTION_UPDATE_PLAYER_STATS := StringName("gameplay/update_player_stats")

static func update_player_stats(health: int, score: int, level: int) -> Dictionary:
    return {
        "type": ACTION_UPDATE_PLAYER_STATS,
        "payload": {"health": health, "score": score, "level": level}
    }
```

### Tip 4: Subscribe to Specific Slices

```gdscript
# GOOD - react only to gameplay changes
_store.slice_updated.connect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
    if slice_name != "gameplay":
        return  # Ignore boot/menu updates
    
    _update_ui(slice_state)

# AVOID - subscribing to all state changes
_store.state_updated.connect(_on_every_change)  # Fires for ALL slices
```

---

## Troubleshooting

### Problem: "Could not find M_StateStore"

**Cause**: Store not in scene tree or accessed before `_ready()`

**Solution**:
```gdscript
func _ready() -> void:
    await get_tree().process_frame  # Wait for store to register
    var store: M_StateStore = U_StateUtils.get_store(self)
```

### Problem: State Not Updating

**Causes**:
1. Action not registered in ActionRegistry
2. Reducer not handling action type
3. Reducer not registered with store

**Debug**:
```gdscript
# Check action registered
if not ActionRegistry.is_registered(U_GameplayActions.ACTION_UPDATE_HEALTH):
    print("Action not registered!")

# Enable verbose logging
store.settings.enable_logging = true
```

### Problem: "Unrecognized UID" Scene Errors

**Cause**: Manually-specified UIDs in `.tscn` files

**Solution**: Remove `uid="uid://xxx"` from scene headers, let Godot generate UIDs automatically

### Problem: Buttons Not Clickable in UI

**Cause**: Overlay container blocking input

**Solution**: Set `mouse_filter = 2` (MOUSE_FILTER_IGNORE) on full-screen containers that shouldn't intercept clicks

### Problem: Test Failures with "Unexpected Errors"

**Cause**: Missing `U_StateEventBus.reset()` or `ActionRegistry` cleanup

**Solution**:
```gdscript
func before_each() -> void:
    U_StateEventBus.reset()
    ActionRegistry._registered_actions.clear()
```

---

## Action Type Naming Conventions

Follow these conventions for consistent action naming:

### Format: `domain/verb_noun`

```gdscript
# Domain: gameplay, menu, boot, transition
# Verb: update, set, add, remove, toggle, navigate, etc.
# Noun: health, score, screen, character, etc.

const ACTION_PAUSE_GAME := StringName("gameplay/pause")
const ACTION_UPDATE_ENTITY_SNAPSHOT := StringName("gameplay/UPDATE_ENTITY_SNAPSHOT")
const ACTION_NAVIGATE_TO_SCREEN := StringName("menu/navigate_to_screen")
const ACTION_TRANSITION_TO_GAMEPLAY := StringName("transition/to_gameplay")
```

### Examples by Pattern

**Toggle (change boolean)**:
- `gameplay/pause`
- `gameplay/unpause`
- `menu/toggle_setting`

**Update (set new snapshot/value)**:
- `gameplay/UPDATE_ENTITY_SNAPSHOT`
- `menu/navigate_to_screen`
- `boot/update_loading_progress`

**Set (explicit assignment)**:
- `gameplay/set_level`
- `menu/set_character`

**Toggle (boolean flip)**:
- `gameplay/pause`
- `gameplay/unpause`

**Navigate (screen/state transitions)**:
- `menu/navigate_to_screen`
- `transition/to_gameplay`

**Complex (multi-field)**:
- `gameplay/player_died`
- `gameplay/level_complete`

---

## Next Steps

- Review [PRD](../redux-state-store-prd.md) for architecture details
- Check [tasks.md](../redux-state-store-tasks.md) for implementation status
- See the per-topic pitfalls under [docs/guides/pitfalls/](../../../guides/pitfalls/) for common mistakes
- Run tests: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gexit`

---

## 10. ECS Integration Patterns

The state store integrates seamlessly with ECS systems. This section demonstrates real-world patterns from M_PauseManager and S_HealthSystem.

### 10.1 Basic Integration Pattern

**Step 1**: Get store reference in `_ready()`:

```gdscript
extends BaseECSSystem
class_name S_YourSystem

var _store: M_StateStore = null

func _ready() -> void:
	super._ready()
	
	# CRITICAL: Wait one frame for M_StateStore to register in group
	await get_tree().process_frame
	
	# Get store reference
	_store = U_StateUtils.get_store(self)
	
	if not _store:
		push_error("S_YourSystem: Could not find M_StateStore")
		return
```

**Why `await get_tree().process_frame`?**
- M_StateStore registers itself in its `_ready()` which runs concurrently with systems
- Without the await, `get_store()` might execute before M_StateStore has added itself to the group
- See `docs/guides/pitfalls/` for more details

**Step 2**: Subscribe to state changes:

```gdscript
func _ready() -> void:
	# ... get store ...
	
	# Subscribe to specific slice
	_store.slice_updated.connect(_on_slice_updated)
	
	# Read initial state
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	_update_from_state(gameplay_state)

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name == StringName("gameplay"):
		_update_from_state(slice_state)

func _update_from_state(state: Dictionary) -> void:
	# Use selectors to extract specific values
	var is_paused: bool = GameplaySelectors.get_is_paused(state)
	# ... react to state ...
```

**Step 3**: Dispatch actions:

```gdscript
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("some_action"):
		# Dispatch action to modify state
		_store.dispatch(U_GameplayActions.some_action(data))
```

**Step 4**: Clean up in `_exit_tree()`:

```gdscript
func _exit_tree() -> void:
	# Unsubscribe to prevent memory leaks
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)
```

### 10.2 Real Example: M_PauseManager

**Full implementation** (`scripts/core/ecs/systems/m_pause_manager.gd`):

```gdscript
@icon("res://assets/editor_icons/system.svg")
extends BaseECSSystem
class_name M_PauseManager

signal pause_state_changed(is_paused: bool)

var _store: M_StateStore = null
var _cursor_manager: M_CursorManager = null
var _is_paused: bool = false

func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	
	_store = U_StateUtils.get_store(self)
	if not _store:
		push_error("M_PauseManager: Could not find M_StateStore")
		return
	
	# Optional: Get cursor manager for UX coordination
	var cursor_managers: Array[Node] = get_tree().get_nodes_in_group("cursor_manager")
	if cursor_managers.size() > 0:
		_cursor_manager = cursor_managers[0] as M_CursorManager
	
	# Subscribe to state changes
	_store.slice_updated.connect(_on_slice_updated)
	
	# Read initial state
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	_is_paused = GameplaySelectors.get_is_paused(gameplay_state)

func _exit_tree() -> void:
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

func _input(event: InputEvent) -> void:
	if not _store:
		return
	
	# Handle pause toggle
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if not _store:
		return
	
	# Read current state via selector
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	var is_currently_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
	
	# Dispatch action to toggle
	if is_currently_paused:
		_store.dispatch(U_GameplayActions.unpause_game())
		if _cursor_manager:
			_cursor_manager.set_cursor_state(true, false)  # Lock cursor
	else:
		_store.dispatch(U_GameplayActions.pause_game())
		if _cursor_manager:
			_cursor_manager.set_cursor_state(false, true)  # Unlock cursor

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	
	# Read new pause state
	var new_paused: bool = GameplaySelectors.get_is_paused(slice_state)
	
	if new_paused != _is_paused:
		_is_paused = new_paused
		pause_state_changed.emit(_is_paused)
```

**Key patterns demonstrated:**
1. **Await pattern**: Wait one frame before getting store
2. **Selector usage**: Use `GameplaySelectors` to extract specific state
3. **Action dispatch**: Dispatch actions to modify state
4. **Subscription**: React to state changes via `slice_updated` signal
5. **Cleanup**: Disconnect signals in `_exit_tree()`
6. **Coordination**: Optionally coordinate with other managers (cursor)

### 10.3 Real Example: S_HealthSystem

**Simplified implementation** (`scripts/core/ecs/systems/s_health_system.gd`):

```gdscript
@icon("res://assets/editor_icons/system.svg")
extends BaseECSSystem
class_name S_HealthSystem

signal player_death

var _store: M_StateStore = null
var _damage_timer: Timer = null

func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	
	_store = U_StateUtils.get_store(self)
	if not _store:
		push_error("S_HealthSystem: Could not find M_StateStore")
		return
	
	# Subscribe to state changes
	_store.slice_updated.connect(_on_slice_updated)
	
	# Create timer for periodic damage (demo purposes)
	_damage_timer = Timer.new()
	_damage_timer.wait_time = 5.0
	_damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(_damage_timer)
	_damage_timer.start()

func _exit_tree() -> void:
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

func _on_damage_timer_timeout() -> void:
	# Check if game is paused
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	if GameplaySelectors.get_is_paused(gameplay_state):
		return  # Don't apply damage while paused
	
	# Dispatch pause action (example of system using state)
	if not _is_paused and should_pause:
		_store.dispatch(U_GameplayActions.pause_game())

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	
	# Check for pause state change
	var is_paused: bool = GameplaySelectors.get_is_paused(slice_state)
	if is_paused != _is_paused:
		_is_paused = is_paused
		pause_changed.emit(is_paused)
```

**Key patterns demonstrated:**
1. **Pause awareness**: Check pause state before processing
2. **Timer integration**: Dispatch actions on timer events
3. **Health tracking**: React to health changes via selector
4. **Death detection**: Emit system-specific signals based on state

### 10.4 Respecting Pause State

**All systems should check pause state before processing:**

```gdscript
func process_tick(delta: float) -> void:
	# Get pause state
	var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
	if GameplaySelectors.get_is_paused(gameplay_state):
		return  # Skip processing while paused
	
	# Normal processing...
```

**Systems that respect pause:**
- S_MovementSystem
- S_JumpSystem
- S_RotateToInputSystem
- S_GravitySystem
- S_InputSystem
- S_HealthSystem

### 10.5 UI Integration Example

**HUD that reacts to state** (`scripts/core/ui/hud_controller.gd`):

```gdscript
extends CanvasLayer

const U_StateUtils := preload("res://scripts/core/state/utils/u_state_utils.gd")
const U_EntitySelectors := preload("res://scripts/core/state/selectors/u_entity_selectors.gd")

@onready var pause_label: Label = $MarginContainer/VBoxContainer/PauseLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar

var _store: M_StateStore = null
var _player_entity_id: String = "E_Player"

func _ready() -> void:
	_store = U_StateUtils.get_store(self)
	if _store == null:
		push_error("HUD: Could not find M_StateStore")
		return

	_player_entity_id = String(_store.get_slice(StringName("gameplay")).get("player_entity_id", "E_Player"))
	_store.slice_updated.connect(_on_slice_updated)
	_update_display(_store.get_state())

func _exit_tree() -> void:
	if _store != null and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	_update_display(_store.get_state())

func _update_display(state: Dictionary) -> void:
	pause_label.text = ""
	_update_health(state)

func _update_health(state: Dictionary) -> void:
	var health := U_EntitySelectors.get_entity_health(state, _player_entity_id)
	var max_health := U_EntitySelectors.get_entity_max_health(state, _player_entity_id)
	max_health = max(max_health, 1.0)
	health = clampf(health, 0.0, max_health)

	if not is_equal_approx(health_bar.max_value, max_health):
		health_bar.max_value = max_health
	if not is_equal_approx(health_bar.value, health):
		health_bar.value = health

	health_bar.format = "%d / %d"
	health_bar.tooltip_text = "%d / %d" % [int(round(health)), int(round(max_health))]
```

**Benefits of state-driven UI:**
- UI automatically updates when state changes
- No manual wiring between gameplay code and UI widgets
- Single source of truth for live gameplay data (health, pause state, etc.)
- Easy to add new UI elements—subscribe and read from selectors

### 10.6 Testing ECS Integration

**Unit test example** (`tests/unit/integration/test_poc_pause_system.gd`):

```gdscript
extends GutTest

var store: M_StateStore
var pause_system: M_PauseManager

func before_each() -> void:
	U_StateEventBus.reset()
	U_ECSEventBus.reset()
	
	# Create store
	store = M_StateStore.new()
	add_child(store)
	
	# Create pause system
	pause_system = M_PauseManager.new()
	add_child(pause_system)
	
	await get_tree().process_frame

func test_pause_system_dispatches_pause_action() -> void:
	# Initial state should be unpaused
	var state: Dictionary = store.get_slice(StringName("gameplay"))
	assert_false(GameplaySelectors.get_is_paused(state))
	
	# Toggle pause
	pause_system.toggle_pause()
	await get_tree().process_frame
	
	# State should now be paused
	state = store.get_slice(StringName("gameplay"))
	assert_true(GameplaySelectors.get_is_paused(state))
```

### 10.7 Common Pitfalls

**❌ DON'T: Access store without await**
```gdscript
func _ready() -> void:
	_store = U_StateUtils.get_store(self)  # WRONG - may be null
```

**✅ DO: Wait one frame**
```gdscript
func _ready() -> void:
	await get_tree().process_frame
	_store = U_StateUtils.get_store(self)  # CORRECT
```

---

**❌ DON'T: Forget to unsubscribe**
```gdscript
func _exit_tree() -> void:
	pass  # WRONG - memory leak
```

**✅ DO: Always disconnect**
```gdscript
func _exit_tree() -> void:
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)
```

---

**❌ DON'T: Mutate state directly**
```gdscript
func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	slice_state["health"] = 100  # WRONG - mutates copy, no effect
```

**✅ DO: Dispatch actions**
```gdscript
func toggle_pause() -> void:
	_store.dispatch(U_GameplayActions.pause_game())  # CORRECT
```

---

**❌ DON'T: Process during pause without checking**
```gdscript
func process_tick(delta: float) -> void:
	apply_damage()  # WRONG - runs even when paused
```

**✅ DO: Check pause state**
```gdscript
func process_tick(delta: float) -> void:
	var state: Dictionary = _store.get_slice(StringName("gameplay"))
	if GameplaySelectors.get_is_paused(state):
		return
	apply_damage()  # CORRECT
```

### 10.8 Integration Checklist

When integrating a new system with state store:

- [ ] Add `await get_tree().process_frame` before `get_store()`
- [ ] Store reference in instance variable
- [ ] Check for null store and push_error if missing
- [ ] Subscribe to relevant slice via `slice_updated.connect()`
- [ ] Read initial state after subscribing
- [ ] Use selectors to extract values (don't access dict directly)
- [ ] Dispatch actions to modify state (never mutate)
- [ ] Disconnect signals in `_exit_tree()`
- [ ] Respect pause state in `process_tick()`
- [ ] Add unit tests for integration
- [ ] Test in-game to verify behavior

---

**Questions?** Check the PRD or inspect working examples in `scenes/debug/state_test_*.gd`
