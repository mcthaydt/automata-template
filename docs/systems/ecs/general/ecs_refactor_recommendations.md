# ECS Refactoring Recommendations

**Project**: ECS (Entity-Component-System) Architecture
**Date**: 2025-10-23
**Status**: All tests GREEN ✅ | Refactor Complete 🎉
**Context**: Recommendations for both immediate code quality wins AND long-term architectural improvements

---

## Executive Summary

The current ECS implementation is **functional and well-tested**, but has opportunities for improvement in two areas:

### Part A: Code Quality (Quick Wins)
- Extract duplicate patterns across components/systems
- Reduce boilerplate
- Improve maintainability

**Estimated Effort**: 3-4 hours
**Risk**: Low (safe extractions)
**Impact**: Cleaner code, easier to extend

### Part B: Architectural Enhancements (Long-term)
- Multi-component query system
- Event bus for system communication
- Decouple components from each other
- System execution ordering

**Estimated Effort**: 2-3 weeks
**Risk**: Medium-High (requires design changes)
**Impact**: Enables emergent gameplay, true scalability

---

## Table of Contents

**PART A: CODE QUALITY REFACTORS**
1. [Tier 1: High-Impact Quick Wins](#tier-1-high-impact-quick-wins)
2. [Tier 2: Medium-Impact Improvements](#tier-2-medium-impact-improvements)
3. [Tier 3: Nice-to-Have Polish](#tier-3-nice-to-have-polish)

**PART B: ARCHITECTURAL REFACTORS**
4. [Tier 1: Multi-Component Query System](#tier-1-multi-component-query-system-critical)
5. [Tier 2: Event Bus for System Communication](#tier-2-event-bus-for-system-communication)
6. [Tier 3: Decouple Components](#tier-3-decouple-components-remove-nodepath-references)
7. [Tier 4: System Execution Ordering](#tier-4-system-execution-ordering)
8. [Tier 5: Component Tags & Entity Tracking](#tier-5-component-tags--entity-tracking-nice-to-have)

**APPENDIX**
- [Testing Strategy](#testing-strategy)
- [What NOT to Refactor](#what-not-to-refactor)
- [Implementation Roadmap](#implementation-roadmap)

---

# PART A: CODE QUALITY REFACTORS

## Tier 1: High-Impact Quick Wins ⭐

These refactorings eliminate significant duplication with minimal risk.

---

### 1. Extract Duplicate Manager Location Logic

**Location**: Both `base_ecs_component.gd:40-55` and `base_ecs_system.gd:40-55`

**Problem**: Identical `_locate_manager()` method duplicated in both base classes (30 lines × 2 = 60 lines of duplication).

**Current Code** (repeated in both files):
```gdscript
func _locate_manager() -> M_ECSManager:
    var current_node: Node = get_parent()
    while current_node != null:
        if current_node.has_method("register_component"):
            return current_node
        current_node = current_node.get_parent()

    var managers = get_tree().get_nodes_in_group("ecs_manager")
    if managers.size() > 0:
        return managers[0]

    assert(false, "M_ECSManager not found!")
    return null
```

**Solution**: Extract to shared utility class

```gdscript
# scripts/core/ecs/ecs_utils.gd
extends RefCounted
class_name ECSUtils

static func locate_manager(from_node: Node) -> M_ECSManager:
    """
    Locates M_ECSManager in the scene tree.

    Algorithm:
    1. Walk up parent hierarchy, check for has_method("register_component")
    2. Fallback to scene tree group "ecs_manager"
    3. Assert if not found (fail-fast)

    Args:
        from_node: The node searching for the manager

    Returns:
        M_ECSManager instance or null (asserts if not found)
    """
    # Parent hierarchy search
    var current_node: Node = from_node.get_parent()
    while current_node != null:
        if current_node.has_method("register_component"):
            return current_node
        current_node = current_node.get_parent()

    # Scene tree group fallback
    var managers = from_node.get_tree().get_nodes_in_group("ecs_manager")
    if managers.size() > 0:
        return managers[0]

    # Fail-fast
    assert(false, "M_ECSManager not found in scene tree!")
    return null
```

**Updated Base Classes**:
```gdscript
# In ECSComponent and ECSSystem
func _locate_manager() -> M_ECSManager:
    return ECSUtils.locate_manager(self)
```

**Benefits**:
- Eliminates 60 lines of duplication
- Single source of truth for discovery logic
- Easier to optimize later (e.g., caching strategy)
- Consistent behavior across components/systems

**Risk**: Very Low - pure extraction

**Test Strategy**:
- Add unit tests for `ECSUtils.locate_manager()`
- All existing component/system tests should pass unchanged

---

### 2. Create NodePath Getter Helper Pattern

**Location**: Repeated across 4+ components

**Problem**: Every component with NodePath properties has identical getter pattern:

**Current Pattern** (repeated 20+ times):
```gdscript
# In C_MovementComponent
@export_node_path("Node") var character_body_path: NodePath

func get_character_body() -> CharacterBody3D:
    if character_body_path.is_empty():
        return null
    return get_node_or_null(character_body_path) as CharacterBody3D

# In C_InputComponent
@export_node_path("Node") var character_body_path: NodePath

func get_character_body() -> CharacterBody3D:
    if character_body_path.is_empty():
        return null
    return get_node_or_null(character_body_path) as CharacterBody3D

# And so on...
```

**Solution**: Add helper to `BaseECSComponent` base class

```gdscript
# In scripts/core/ecs/base_ecs_component.gd (add to base class)

func _get_node_from_path(path: NodePath, type = null):
    """
    Resolves a NodePath to a node, with optional type casting.

    Args:
        path: The NodePath to resolve
        type: Optional type to cast to (e.g., CharacterBody3D, C_InputComponent)

    Returns:
        The resolved node (optionally cast to type), or null if path is empty or node not found
    """
    if path.is_empty():
        return null

    var node = get_node_or_null(path)

    if type == null:
        return node
    else:
        return node as type
```

**Updated Components**:
```gdscript
# In C_MovementComponent (simplified)
func get_character_body() -> CharacterBody3D:
    return _get_node_from_path(character_body_path, CharacterBody3D)

func get_input_component() -> C_InputComponent:
    return _get_node_from_path(input_component_path, C_InputComponent)

func get_support_component():
    return _get_node_from_path(support_component_path)
```

**Benefits**:
- Reduces ~40 lines of duplicated null-checking across components
- Consistent pattern for all NodePath getters
- Easy to add validation/debugging later (e.g., log warnings)
- Self-documenting (method name explains what it does)

**Risk**: Very Low - simple wrapper

**Test Strategy**:
- Existing component tests verify behavior unchanged
- Add unit test for `_get_node_from_path()` edge cases

---

### 3. Extract Settings Validation Pattern

**Location**: 5+ components have identical `_ready()` settings validation

**Problem**: Nearly identical pattern in C_JumpComponent, C_FloatingComponent, C_AlignWithSurfaceComponent, etc.

**Current Pattern**:
```gdscript
# In C_JumpComponent._ready() (lines 27-31)
func _ready() -> void:
    if settings:
        # Validate settings
        if settings.jump_velocity == null:
            push_error("JumpComponent: settings.jump_velocity is null")
            return
    super._ready()  # Register with manager

# In C_FloatingComponent._ready() (lines 30-35)
func _ready() -> void:
    if settings:
        # Validate settings
        if settings.height == null:
            push_error("FloatingComponent: settings.height is null")
            return
    super._ready()  # Register with manager
```

**Solution**: Create base validation pattern in `BaseECSComponent`

```gdscript
# In scripts/core/ecs/base_ecs_component.gd (add to base class)

@export var settings: Resource  # Optional base (subclasses override type)

func _ready() -> void:
    if not _validate_required_settings():
        return  # Don't register if invalid

    _component_ready()  # Override point for subclasses

    # Existing registration logic
    _manager = _locate_manager()
    if _manager:
        _manager.register_component(self)

func _validate_required_settings() -> bool:
    """
    Override in subclasses that require settings validation.
    Return false to prevent registration.
    """
    return true

func _component_ready() -> void:
    """
    Override point for component initialization logic.
    Called after settings validation, before registration.
    """
    pass
```

**Updated Components**:
```gdscript
# In C_JumpComponent
@export var settings: JumpSettings

func _validate_required_settings() -> bool:
    if settings == null:
        return true  # Settings optional

    if settings.jump_velocity == null:
        push_error("JumpComponent: settings.jump_velocity is null")
        return false

    return true

func _component_ready() -> void:
    if settings:
        jump_velocity = settings.jump_velocity
        coyote_time = settings.coyote_time
        # ...
```

**Benefits**:
- Eliminates ~30 lines of duplicated validation logic
- Clear lifecycle: validate → initialize → register
- Prevents invalid components from registering
- Easy to add global validation hooks later

**Risk**: Low - changes initialization order slightly

**Test Strategy**:
- Existing tests verify components still register correctly
- Add tests for invalid settings (should not register)

---

### 4. Create Time Utility Helper

**Location**: `Time.get_ticks_msec() / 1000.0` repeated across ECS systems/components

**Status**: ✅ Completed (2025-10-21) — `U_ECSUtils.get_current_time()` centralizes the conversion; ECS suites updated

**Implemented Utility**:
```gdscript
# scripts/core/utils/ecs/u_ecs_utils.gd
static func get_current_time() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
```

**Adopted In**:
- `C_InputComponent` (jump buffering timestamps)
- `S_JumpSystem`, `S_MovementSystem`, `S_FloatingSystem`, `S_AlignWithSurfaceSystem`
- ECS unit tests (movement, jump, floating, align) via helper preload

**Benefits**:
- DRY principle (6+ occurrences → 1 helper)
- Consistent second-based time source across ECS features
- Easy hook for future time-scaling or instrumentation

**Verification**:
- Added `test_get_current_time_returns_seconds()` in `tests/unit/ecs/test_u_ecs_utils.gd`
- Full ECS test suite passing via `gut_cmdln.gd ... -gexit`

---

## Tier 2: Medium-Impact Improvements

Consider after Tier 1 complete. Smaller impact but still valuable.

---

### 5. Extract Body Deduplication Pattern

**Status**: ✅ Completed (2025-10-21) — `U_ECSUtils.map_components_by_body()` deduplicates floating-component lookups, adopted by jump/gravity systems

**Summary**:
- Added `map_components_by_body(manager, component_type)` to `U_ECSUtils`
- Provides reusable body → component dictionary
- S_JumpSystem and S_GravitySystem now call the helper instead of manual loops
- Coverage added via `test_map_components_by_body_groups_components()` in `tests/unit/ecs/test_u_ecs_utils.gd`
- Full ECS suite passes (`gut_cmdln.gd … -gdir=res://tests/unit/ecs -gexit`)
```gdscript
# In S_JumpSystem (simplified)
func process_tick(delta: float) -> void:
    var floating_map := _map_components_by_body(
        C_FloatingComponent.COMPONENT_TYPE,
        func(c): return c.get_character_body()
    )

    var jump_components = get_components(C_JumpComponent.COMPONENT_TYPE)
    for jump_comp in jump_components:
        var body := jump_comp.get_character_body()

        # Skip if floating
        if floating_map.has(body):
            continue

        # Process jump...
```

**Benefits**:
- Eliminates ~20 lines of duplicated map-building
- Self-documenting (class name explains purpose)
- Type-safe (wraps Dictionary with clear API)
- Reusable for future systems

**Risk**: Low - pure extraction

**Test Strategy**: Existing system tests verify behavior unchanged

---

### 6. Extract Component-to-Body Mapping Utility

**Location**: Multiple systems manually iterate components to find bodies

**Problem**: Repetitive pattern of iterating components to build body mappings.

**Solution**: Already covered in #5 above with `_map_components_by_body()`

---

### 7. Add Debug Snapshot Base Implementation

**Location**: Only C_FloatingComponent has `_debug_snapshot`

**Problem**: If other components want debugging, they'll duplicate this pattern.

**Solution**: Add to `BaseECSComponent` base class

```gdscript
# In scripts/core/ecs/base_ecs_component.gd (add to base)

var _debug_snapshot: Dictionary = {}

func update_debug_snapshot(snapshot: Dictionary) -> void:
    """Update debug snapshot with current component state."""
    _debug_snapshot = snapshot.duplicate(true)

func get_debug_snapshot() -> Dictionary:
    """Get copy of debug snapshot for inspection."""
    return _debug_snapshot.duplicate(true)

func clear_debug_snapshot() -> void:
    """Clear debug snapshot."""
    _debug_snapshot.clear()
```

**Benefits**:
- Standardized debugging across all components
- No duplication when adding debug to new components
- Easy to add debug UI later (query all snapshots)

**Risk**: Very Low - additive only

**Test Strategy**: No changes needed (optional feature)

---

## Tier 3: Nice-to-Have Polish

Low priority. Consider only if extra time available.

---

### 8. Simplify Component Type Declaration

**Location**: Every component manually declares `COMPONENT_TYPE`

**Problem**: Component type duplicates class name (error-prone).

**Current Pattern**:
```gdscript
# In C_MovementComponent
class_name C_MovementComponent
const COMPONENT_TYPE := StringName("C_MovementComponent")  # Duplication!
```

**Solution**: Auto-derive from class name in base

```gdscript
# In ECSComponent base class
var _component_type: StringName = StringName("")

func _init():
    if _component_type == &"":
        _component_type = StringName(get_script().get_global_name())

func get_component_type() -> StringName:
    return _component_type
```

**Downside**: Loses compile-time constant. Systems would need to use `component.get_component_type()` instead of `C_MovementComponent.COMPONENT_TYPE`.

**Recommendation**: Skip this - current pattern is clear despite duplication.

---

### 9. Remove Redundant get_component_type() Override

**Location**: `c_align_with_surface_component.gd:23-24`

**Problem**: Unnecessary override that just returns COMPONENT_TYPE.

**Solution**: Delete lines 23-24.

```gdscript
# Delete these lines from c_align_with_surface_component.gd
func get_component_type() -> StringName:
    return COMPONENT_TYPE
```

Base class already has this implementation.

**Risk**: Very Low - safe deletion

---

### 10. Standardize Null-Safety in System Loops

**Location**: Every system has `if component == null: continue`

**Problem**: 4+ lines of null-checking in every system loop.

**Solution**: Filter null components in `ECSSystem.get_components()`

```gdscript
# In base_ecs_system.gd
func get_components(component_type: StringName) -> Array:
    if _manager == null:
        return []

    var components = _manager.get_components(component_type)

    # Filter out null components
    return components.filter(func(c): return c != null)
```

**Updated Systems**:
```gdscript
# Before
func process_tick(delta: float):
    var components = get_components(C_MovementComponent.COMPONENT_TYPE)
    for comp in components:
        if comp == null:  # No longer needed!
            continue
        # Process...

# After
func process_tick(delta: float):
    var components = get_components(C_MovementComponent.COMPONENT_TYPE)
    for comp in components:
        # Process... (null-safety guaranteed)
```

**Benefits**:
- Eliminates ~4 lines per system (5 systems = 20 lines)
- Centralized null filtering
- Systems can trust component array is valid

**Downside**: Slight performance cost (filter creates new array)

**Recommendation**: Low priority - current pattern is explicit and clear.

---

# PART B: ARCHITECTURAL REFACTORS

These are **long-term improvements** that enable emergent gameplay and true scalability. Much higher effort and risk than Part A.

## ✅ STATUS: ALL MAJOR REFACTORS COMPLETE

**Completed:**
- ✅ **Tier 1**: Multi-Component Query System (Stories 2.1-2.6)
- ✅ **Tier 2**: Event Bus for System Communication (Stories 3.1-3.4)
- ✅ **Tier 3**: Decouple Components (Stories 4.1-4.4)
- ✅ **Tier 4**: System Execution Ordering (Stories 5.1-5.3)

**Future Enhancement:**
- ⏭️ **Tier 5**: Component Tags & Entity Tracking (Nice-to-Have, deferred)

---

## Tier 1: Multi-Component Query System ✅ COMPLETE

**Impact**: ⭐⭐⭐⭐⭐ (Highest)
**Effort**: 2-3 days (Completed in Stories 2.1-2.6)
**Risk**: Medium
**Status**: ✅ **DELIVERED**

### Problem

Systems can only query ONE component type at a time. Matching components on the same entity requires manual cross-referencing.

**Current Pattern** (S_MovementSystem):
```gdscript
func process_tick(delta: float):
    var movement_components = get_components(C_MovementComponent.COMPONENT_TYPE)

    for movement_comp in movement_components:
        # Manually find matching input component
        var input_comp = movement_comp.get_input_component()

        if input_comp == null:
            continue  # Skip if no input

        # Process movement with input...
```

**Problems**:
1. **O(n) lookup** for each component (queries via NodePath)
2. **Tight coupling** (component knows about other component types)
3. **Not composable** (can't easily add 3rd component requirement)
4. **Manual null handling** (systems must check if cross-reference exists)

**Example Scenario** (fails with current system):
```gdscript
# Want: "All entities with Movement AND Input AND FloatingComponent"
# Current: Must query each type, then manually cross-reference
var movements = get_components(C_MovementComponent.COMPONENT_TYPE)
var inputs = get_components(C_InputComponent.COMPONENT_TYPE)
var floatings = get_components(C_FloatingComponent.COMPONENT_TYPE)

# Now manually match by entity... becomes O(n³)!
```

### Solution: Entity-Based Query API

**Add to M_ECSManager**:
```gdscript
# scripts/core/managers/m_ecs_manager.gd

# New property: track which components belong to same entity
var _entity_to_components: Dictionary = {}  # Entity (Node) → Array[BaseECSComponent]

func register_component(component: BaseECSComponent) -> void:
    # Existing registration logic...
    var component_type := component.COMPONENT_TYPE
    if not _components.has(component_type):
        _components[component_type] = []
    _components[component_type].append(component)

    # NEW: Track entity → component mapping
    var entity := _get_entity_from_component(component)
    if entity != null:
        if not _entity_to_components.has(entity):
            _entity_to_components[entity] = []
        _entity_to_components[entity].append(component)

    registered.emit(component)

func _get_entity_from_component(component: BaseECSComponent) -> Node:
    """
    Gets the entity (parent node) for a component.
    Typically the CharacterBody3D parent.
    """
    return component.get_parent()

func query_entities(required: Array[StringName], optional: Array[StringName] = []) -> Array:
    """
    Queries entities that have ALL required components, and optionally some optional components.

    Args:
        required: Component types that MUST be present
        optional: Component types that MAY be present

    Returns:
        Array[U_EntityQuery] where each U_EntityQuery has:
        - entity: Node (the CharacterBody3D or parent node)
        - components: Dictionary[StringName → ECSComponent]

    Example:
        var entities = query_entities(
            [C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE],
            [C_FloatingComponent.COMPONENT_TYPE]
        )

        for result in entities:
            var movement = result.components[C_MovementComponent.COMPONENT_TYPE]
            var input = result.components[C_InputComponent.COMPONENT_TYPE]
            var floating = result.components.get(C_FloatingComponent.COMPONENT_TYPE, null)
            # All guaranteed non-null (except optional floating)
    """
    var results: Array = []

    # Iterate all entities
    for entity in _entity_to_components.keys():
        var entity_components: Array = _entity_to_components[entity]

        # Build component type → component mapping for this entity
        var component_map: Dictionary = {}
        for comp in entity_components:
            component_map[comp.COMPONENT_TYPE] = comp

        # Check if entity has all required components
        var has_all_required := true
        for required_type in required:
            if not component_map.has(required_type):
                has_all_required = false
                break

        if not has_all_required:
            continue

        # Entity matches! Create result
        var result := U_EntityQuery.new()
        result.entity = entity
        result.components = component_map
        results.append(result)

    return results

func query_exclude(required: Array[StringName], excluded: Array[StringName]) -> Array:
    """
    Queries entities that have ALL required components but NONE of the excluded components.

    Example:
        # Entities with Movement but NOT Floating
        var grounded = query_exclude(
            [C_MovementComponent.COMPONENT_TYPE],
            [C_FloatingComponent.COMPONENT_TYPE]
        )
    """
    var results: Array = []

    for entity in _entity_to_components.keys():
        var entity_components: Array = _entity_to_components[entity]

        var component_map: Dictionary = {}
        for comp in entity_components:
            component_map[comp.COMPONENT_TYPE] = comp

        # Check required
        var has_all_required := true
        for required_type in required:
            if not component_map.has(required_type):
                has_all_required = false
                break

        if not has_all_required:
            continue

        # Check excluded
        var has_excluded := false
        for excluded_type in excluded:
            if component_map.has(excluded_type):
                has_excluded = true
                break

        if has_excluded:
            continue

        # Entity matches!
        var result := U_EntityQuery.new()
        result.entity = entity
        result.components = component_map
        results.append(result)

    return results

# Inner class for query results
class U_EntityQuery:
    var entity: Node
    var components: Dictionary  # StringName → ECSComponent

    func get_component(component_type: StringName):
        return components.get(component_type, null)
```

### Updated System Pattern

**Before**:
```gdscript
# S_MovementSystem (manual cross-reference)
func process_tick(delta: float):
    var movement_comps = get_components(C_MovementComponent.COMPONENT_TYPE)

    for movement_comp in movement_comps:
        var input_comp = movement_comp.get_input_component()  # Manual lookup
        if input_comp == null:
            continue

        var body = movement_comp.get_character_body()
        if body == null:
            continue

        # Process...
```

**After**:
```gdscript
# S_MovementSystem (query-based)
func process_tick(delta: float):
    var entities = _manager.query_entities(
        [C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE]
    )

    for entity_query in entities:
        var movement_comp = entity_query.get_component(C_MovementComponent.COMPONENT_TYPE)
        var input_comp = entity_query.get_component(C_InputComponent.COMPONENT_TYPE)
        var body = entity_query.entity as CharacterBody3D

        # All guaranteed non-null!
        # Process...
```

### Benefits

**Scalability**:
- O(1) component lookup (indexed by entity)
- Can query 3, 4, 5+ components easily
- No manual cross-referencing

**Composability**:
- Easy to add optional components: `query_entities([Required], [Optional])`
- Easy to exclude components: `query_exclude([Movement], [Floating])`
- Systems don't need to know how components find each other

**Emergent Gameplay**:
```gdscript
# Example: Damage system
var damageable = query_entities([HealthComponent, TransformComponent])
var fire_sources = query_entities([FireComponent, TransformComponent])

for entity in damageable:
    for fire in fire_sources:
        if entity.entity.global_position.distance_to(fire.entity.global_position) < 5.0:
            entity.get_component(HealthComponent).take_damage(10)
            # Emergent: Any entity with Health near Fire takes damage!
```

### Migration Path

1. **Add query API to M_ECSManager** (non-breaking, additive)
2. **Refactor one system at a time** to use queries
3. **Keep old `get_components()` API** for backward compatibility
4. **After all systems migrated**, remove NodePath cross-references from components

### Testing Strategy

```gdscript
# tests/unit/ecs/test_ecs_query_system.gd
func test_query_entities_returns_matching_entities():
    var manager = M_ECSManager.new()
    add_child(manager)

    var entity1 = CharacterBody3D.new()
    add_child(entity1)

    var movement = C_MovementComponent.new()
    entity1.add_child(movement)

    var input = C_InputComponent.new()
    entity1.add_child(input)

    await get_tree().process_frame

    var results = manager.query_entities([
        C_MovementComponent.COMPONENT_TYPE,
        C_InputComponent.COMPONENT_TYPE
    ])

    assert_eq(results.size(), 1)
    assert_eq(results[0].entity, entity1)
    assert_eq(results[0].get_component(C_MovementComponent.COMPONENT_TYPE), movement)
    assert_eq(results[0].get_component(C_InputComponent.COMPONENT_TYPE), input)
```

---

## Tier 2: Event Bus for System Communication ✅ COMPLETE

**Impact**: ⭐⭐⭐⭐ (Very High)
**Effort**: 2-3 days (Completed in Stories 3.1-3.4)
**Risk**: Low-Medium
**Status**: ✅ **DELIVERED**

### Problem

Systems can't communicate events without:
1. Direct coupling (system A calls system B)
2. Global signals (messy, hard to trace)
3. Polling (inefficient)

**Missing Capability**: Domain events like:
- `entity_jumped` → AnimationSystem plays jump animation
- `entity_landed` → SoundSystem plays landing sound
- `entity_took_damage` → VFXSystem spawns damage numbers
- `entity_entered_water` → StatusSystem adds "wet" status

### Solution: ECS Event Bus

**Create Global Event Bus**:
```gdscript
# scripts/core/events/ecs/u_ecs_event_bus.gd
extends Node
class_name U_ECSEventBus

signal event_emitted(event_name: StringName, data: Dictionary)

var _subscribers: Dictionary = {}  # StringName → Array[Callable]

func emit_event(event_name: StringName, data: Dictionary = {}) -> void:
    """
    Emits an event that systems can react to.

    Args:
        event_name: Name of the event (e.g., "entity_jumped", "entity_damaged")
        data: Event payload (e.g., {entity: Node, damage: 10})
    """
    if _subscribers.has(event_name):
        for callback in _subscribers[event_name]:
            callback.call(data)

    # Also emit signal for debugging/logging
    event_emitted.emit(event_name, data)

func subscribe(event_name: StringName, callback: Callable) -> Callable:
    """
    Subscribe to an event.

    Returns:
        Unsubscribe function (call it to stop listening)
    """
    if not _subscribers.has(event_name):
        _subscribers[event_name] = []

    _subscribers[event_name].append(callback)

    # Return unsubscribe function
    return func():
        if _subscribers.has(event_name):
            _subscribers[event_name].erase(callback)

func clear_subscribers(event_name: StringName = &"") -> void:
    """Clear subscribers for specific event, or all events if empty."""
    if event_name == &"":
        _subscribers.clear()
    else:
        _subscribers.erase(event_name)
```

**Add as AutoLoad**:
- Project Settings → AutoLoad → Add `u_ecs_event_bus.gd` as `ECSEvents`

### System Integration

**Publishing Events** (in S_JumpSystem):
```gdscript
func process_tick(delta: float):
    var entities = _manager.query_entities([C_JumpComponent.COMPONENT_TYPE])

    for entity_query in entities:
        var jump_comp = entity_query.get_component(C_JumpComponent.COMPONENT_TYPE)
        var body = entity_query.entity

        if _check_can_jump(jump_comp, body):
            body.velocity.y = jump_comp.jump_velocity

            # Emit event
            ECSEvents.emit_event("entity_jumped", {
                "entity": body,
                "velocity": jump_comp.jump_velocity
            })
```

**Subscribing to Events** (in S_AnimationSystem):
```gdscript
func _ready():
    super._ready()

    # Subscribe to jump events
    ECSEvents.subscribe("entity_jumped", _on_entity_jumped)
    ECSEvents.subscribe("entity_landed", _on_entity_landed)

func _on_entity_jumped(data: Dictionary):
    var entity = data["entity"]
    var anim_comp = _find_animation_component_for_entity(entity)
    if anim_comp:
        anim_comp.play("jump")

func _on_entity_landed(data: Dictionary):
    var entity = data["entity"]
    var anim_comp = _find_animation_component_for_entity(entity)
    if anim_comp:
        anim_comp.play("land")
```

### Benefits

**Decoupling**:
- Systems don't know about each other
- Can add new systems without modifying existing ones

**Emergent Gameplay**:
```gdscript
# FireSystem subscribes to "entity_damaged"
ECSEvents.subscribe("entity_damaged", func(data):
    if data.damage_type == "fire":
        # Apply burning status
        var entity = data.entity
        add_burning_component(entity)
)

# WaterSystem subscribes to "entity_entered_water"
ECSEvents.subscribe("entity_entered_water", func(data):
    # Remove burning, add wet status
    var entity = data.entity
    remove_burning_component(entity)
    add_wet_component(entity)
)

# Emergent: Fire + Water = extinguish, never hardcoded!
```

**Debugging**:
- Can log all events (single point)
- Can record/replay events for bug reproduction

### Migration Path

1. **Add U_ECSEventBus as AutoLoad**
2. **Start with one system** (e.g., JumpSystem emits "entity_jumped")
3. **Add reactive systems** (AnimationSystem, SoundSystem listen)
4. **Gradually migrate** other systems to emit/listen for events

### Testing Strategy

```gdscript
# tests/unit/ecs/test_ecs_event_bus.gd
func test_event_bus_delivers_events():
    var received := false
    var received_data := {}

    ECSEvents.subscribe("test_event", func(data):
        received = true
        received_data = data
    )

    ECSEvents.emit_event("test_event", {"value": 42})

    assert_true(received)
    assert_eq(received_data["value"], 42)
```

---

## Tier 3: Decouple Components ✅ COMPLETE

**Impact**: ⭐⭐⭐ (High)
**Effort**: 3-5 days (Completed in Stories 4.1-4.4)
**Risk**: Medium
**Status**: ✅ **DELIVERED**

### Problem

Components store NodePaths to other components:
```gdscript
# C_MovementComponent
@export_node_path("Node") var input_component_path: NodePath
@export_node_path("Node") var support_component_path: NodePath

func get_input_component() -> C_InputComponent:
    return _get_node_from_path(input_component_path, C_InputComponent)
```

**Issues**:
- **Tight coupling**: Component "knows" about other component types
- **Not composable**: Can't swap input sources (player vs AI)
- **Manual setup**: Must wire NodePaths in inspector

### Solution: Systems Wire Components Together

**Remove NodePaths from components**:
```gdscript
# C_MovementComponent (cleaned up)
class_name C_MovementComponent
extends BaseECSComponent

const COMPONENT_TYPE := StringName("C_MovementComponent")

@export var velocity: Vector3 = Vector3.ZERO
@export var max_speed: float = 5.0
@export var acceleration: float = 50.0
@export var friction: float = 20.0

# Removed:
# @export_node_path("Node") var input_component_path: NodePath
# @export_node_path("Node") var support_component_path: NodePath
# func get_input_component() -> C_InputComponent
# func get_support_component()
```

**Systems use queries**:
```gdscript
# S_MovementSystem (queries handle wiring)
func process_tick(delta: float):
    # Query entities with BOTH Movement AND Input
    var entities = _manager.query_entities(
        [C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE],
        [C_FloatingComponent.COMPONENT_TYPE]  # Optional floating support
    )

    for entity_query in entities:
        var movement = entity_query.get_component(C_MovementComponent.COMPONENT_TYPE)
        var input = entity_query.get_component(C_InputComponent.COMPONENT_TYPE)
        var floating = entity_query.get_component(C_FloatingComponent.COMPONENT_TYPE)  # May be null

        # No manual wiring needed!
        # Process movement...
```

### Benefits

**Composability**:
```gdscript
# Player with PlayerInputComponent
Player (CharacterBody3D)
├─ C_MovementComponent
├─ C_PlayerInputComponent  # Reads keyboard/gamepad
└─ C_JumpComponent

# AI with AIInputComponent (same MovementComponent!)
Enemy (CharacterBody3D)
├─ C_MovementComponent  # Exact same component
├─ C_AIInputComponent  # Calculates input from AI
└─ C_JumpComponent
```

**Modularity**:
- Add new input sources without touching MovementComponent
- Swap components at runtime (possess enemy = swap input component)
- Systems work with any input source

### Migration Path

1. **Implement query system first** (Tier 1)
2. **For each component**:
   - Remove NodePath exports
   - Remove getter methods
3. **For each system**:
   - Replace manual cross-referencing with queries
4. **Update tests** to not set NodePaths

**Breaking Change**: This will break existing scenes! All NodePaths will be lost.

**Mitigation**: Create migration script that removes NodePath properties from .tscn files.

### Testing Strategy

Same tests should pass, but setup changes:
```gdscript
# Before (manual wiring)
var movement = C_MovementComponent.new()
movement.input_component_path = movement.get_path_to(input)

# After (just add components, query handles wiring)
var movement = C_MovementComponent.new()
# No wiring needed!
```

---

## Tier 4: System Execution Ordering

**Status**: ✅ Delivered in Stories 5.1–5.3.

### Summary

- `BaseECSSystem` exposes `@export var execution_priority: int` clamped to `0–1000`.
- `M_ECSManager` owns the physics tick, keeps a cached priority-sorted array, and re-sorts whenever a system’s priority changes (`mark_systems_dirty()`).
- Systems only run their `_physics_process` when unmanaged (keeps backwards compatibility for isolated tests).

### Priority Conventions

| Band | Purpose | Example Systems |
|------|---------|-----------------|
| `0–9` | Input capture / sensor sampling | `S_InputSystem` |
| `10–39` | Pre-physics state prep (timers, caches) | future anticipation systems |
| `40–69` | Core forces & motion | `S_JumpSystem`, `S_GravitySystem`, `S_MovementSystem` |
| `70–109` | Post-motion adjustments | `S_FloatingSystem`, `S_RotateToInputSystem`, `S_AlignWithSurfaceSystem` |
| `110–199` | Feedback & UX layers | `S_LandingIndicatorSystem`, VFX/SFX responders |
| `200+` | Diagnostics / analytics / experiments | profiling hooks, debug overlays |

Leave gaps so new systems can slot in without renumbering.

### Validation & Tooling

- `tests/unit/ecs/test_ecs_manager.gd` ensures execution order respects priorities and tie-breaking.
- `tests/unit/ecs/systems/test_landing_indicator_system.gd` covers mixed-priority interactions.
- Future enhancement: optional debug overlay or log stream that prints the executed order each frame.

---

## Tier 5: Component Tags & Entity Tracking (Nice-to-Have)

**Impact**: ⭐⭐ (Medium, long-term)
**Effort**: 2-3 days
**Risk**: Low
**Priority**: Future enhancement

### Component Tags

**Problem**: Need lightweight categorization without creating component classes.

**Solution**:
```gdscript
# In ECSComponent base class
var _tags: Array[StringName] = []

func add_tag(tag: StringName) -> void:
    if not _tags.has(tag):
        _tags.append(tag)

func has_tag(tag: StringName) -> bool:
    return _tags.has(tag)

func remove_tag(tag: StringName) -> void:
    _tags.erase(tag)
```

**In M_ECSManager**:
```gdscript
func query_tagged(tags: Array[StringName]) -> Array:
    """Query entities with ALL specified tags."""
    # ...
```

**Usage**:
```gdscript
# Instead of creating BurnableComponent, MetallicComponent, etc.
entity.get_component(PropertiesComponent).add_tag("flammable")
entity.get_component(PropertiesComponent).add_tag("metallic")

# Query
var flammable = query_tagged(["flammable"])
var metal = query_tagged(["metallic"])
```

---

# Testing Strategy

## Before All Refactoring

```bash
# Run full ECS test suite
gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# Confirm: All tests GREEN ✅
```

## During Refactoring (After Each Change)

```bash
# Run affected tests
gut_cmdln.gd -gdir=res://tests/unit/ecs -gtest=test_ecs_manager.gd
gut_cmdln.gd -gdir=res://tests/unit/ecs/components
gut_cmdln.gd -gdir=res://tests/unit/ecs/systems
```

## After Refactoring

```bash
# Full regression suite
gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# Verify: All tests still GREEN ✅
# Verify: No new warnings in console
# Verify: Code coverage maintained
```

---

# What NOT to Refactor ✅

**Leave these alone** - already well-structured:

### ✅ M_ECSManager Core Logic
- `register_component()` / `unregister_component()` (lines 18-49)
- **High risk** to change
- Already clean and tested
- Core business logic

### ✅ Component Registration Flow
- Components automatically find manager
- Works perfectly with hot-reload
- Don't fix what isn't broken

### ✅ Settings Resources Pattern
- Works great with Godot inspector
- Reusable, hot-reload friendly
- Keep as-is

---

# Implementation Roadmap

## Phase 1: Code Quality (1 week)

**Week 1**:
- Day 1-2: Tier 1 refactors (extract duplicates)
- Day 3: Tier 2 refactors (body mapping helpers)
- Day 4: Testing & documentation
- Day 5: Code review & merge

**Deliverables**:
- Cleaner codebase
- Less duplication
- Easier to extend

## Phase 2: Query System (1 week)

**Week 2**:
- Day 1-2: Implement `query_entities()` in M_ECSManager
- Day 3: Write comprehensive tests
- Day 4-5: Migrate one system as proof-of-concept (S_MovementSystem)

**Deliverables**:
- Working query API
- One migrated system
- Migration guide for remaining systems

## Phase 3: Event Bus (1 week)

**Week 3**:
- Day 1: Implement U_ECSEventBus
- Day 2: Add to S_JumpSystem (emit "entity_jumped")
- Day 3: Create reactive systems (animation, sound)
- Day 4-5: Migrate additional systems

**Deliverables**:
- Working event system
- 3+ systems using events
- Event catalog documentation

## Phase 4: Decouple Components (1 week)

**Week 4**:
- Day 1-2: Remove NodePath cross-references
- Day 3: Update all systems to use queries
- Day 4: Migration script for .tscn files
- Day 5: Testing & bug fixes

**Deliverables**:
- Decoupled components
- All systems using queries
- Migration complete

## Phase 5: Polish (1 week)

**Week 5**:
- Day 1: System execution ordering
- Day 2-3: Component tags (if time allows)
- Day 4-5: Integration testing, documentation

**Deliverables**:
- Production-ready ECS
- Full documentation
- Tutorial examples

**Total Time**: 5 weeks for complete refactor

---

## Success Metrics

### Code Metrics
- **Lines of Code**: -200 lines (from deduplication)
- **Duplication**: -80% in manager location, NodePath getters
- **Cyclomatic Complexity**: Reduced in systems (cleaner logic)

### Quality Metrics
- **Test Pass Rate**: 100% maintained
- **Code Coverage**: ≥90% maintained
- **Performance**: No degradation (<1ms overhead for queries)

### Capability Metrics
- **Query Time**: Multi-component queries <0.1ms
- **Event Latency**: Event dispatch <0.05ms
- **Composability**: Can create new entity types without modifying existing components

---

## Summary

**Part A (Code Quality)**: Quick wins, low risk, immediate value
- Eliminate 200+ lines of duplication
- Cleaner patterns
- Easier to maintain

**Part B (Architecture)**: Long-term investment, high value, enables emergent gameplay
- Multi-component queries (critical for scalability)
- Event bus (enables system communication)
- Decoupled components (true composability)
- System ordering (explicit control)

**Recommendation**:
1. **Do Part A first** (1 week, safe)
2. **Then do Part B Tier 1** (query system, critical)
3. **Then Part B Tier 2** (event bus, high value)
4. **Evaluate** if Tier 3-5 needed based on actual game requirements

---

## Related Documentation

- **docs/ecs/ecs_architecture.md** - Current architecture details
- **docs/systems/ecs/for_humans/ecs_ELI5.md** - Beginner-friendly guide
- **docs/systems/ecs/for_humans/ecs_tradeoffs.md** - Pros and cons analysis
- **tests/unit/ecs/** - Existing test suite

**End of Refactoring Recommendations**
