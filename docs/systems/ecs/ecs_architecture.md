# ECS Architecture Documentation

**Owner**: Development Team | **Last Updated**: 2025-10-20

---

## Table of Contents

1. [Overview](#1-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Component Breakdown](#3-component-breakdown)
4. [Data Flow](#4-data-flow)
5. [Integration Points](#5-integration-points)
6. [Key Patterns](#6-key-patterns)
7. [Example Flows](#7-example-flows)
8. [Current Limitations](#8-current-limitations)
9. [Summary](#9-summary)

---

## 1. Overview

### 1.1 What Is This System?

The ECS (Entity-Component-System) architecture is a data-oriented design pattern that separates game object data (Components) from behavior (Systems). This project implements a **scene-tree integrated ECS** where:

- **Entities** are represented by Godot scene nodes (typically `CharacterBody3D`)
- **Components** are node children that store data (`extends Node`, `class_name ECSComponent`)
- **Systems** are nodes that process components (`extends Node`, `class_name ECSSystem`)
- **M_ECSManager** is the central registry that tracks components and systems

### 1.2 Why This Architecture?

**Goals**:
- **Modularity**: Add/remove gameplay features without touching existing code
- **Composition**: Build complex entities from simple components
- **Testability**: Components and systems can be tested in isolation
- **Hot-reloading**: Change system logic without restarting the game
- **Separation of Concerns**: Data (components) separate from logic (systems)

**Trade-offs Accepted**:
- More boilerplate than traditional OOP (must create component + system files)
- Indirection through manager (systems query components via M_ECSManager)
- Scene tree dependency (entities must be nodes in scene)

### 1.3 Core Principles

1. **Components are data containers** - No game logic, only properties
2. **Systems are logic processors** - Stateless, operate on components
3. **Manager is the registry** - Central source of truth for all components/systems
4. **Auto-registration** - Components/systems self-discover the manager on `_ready()`
5. **Type-based queries** - Systems request components by type (`StringName`)

---

## 2. High-Level Architecture

### 2.1 System Diagram

```
Scene Tree
│
├─ CharacterBody3D (Entity: Player)
│  ├─ C_MovementComponent (data: velocity, speed, acceleration)
│  ├─ C_InputComponent (data: input_vector, jump_pressed)
│  ├─ C_JumpComponent (data: jump_velocity, ground_check_raycast_path)
│  └─ C_FloatingComponent (data: floating_enabled, floating_height)
│
├─ M_ECSManager (Centralized Registry)
│  ├─ _components: Dictionary[StringName, Array[BaseECSComponent]]
│  │   ├─ "C_MovementComponent" → [component1, component2, ...]
│  │   ├─ "C_InputComponent" → [component3, ...]
│  │   └─ ...
│  ├─ _systems: Array[BaseECSSystem] (sorted by execution_priority)
│  │   ├─ S_InputSystem (priority: 0)
│  │   ├─ S_JumpSystem (priority: 40)
│  │   ├─ S_MovementSystem (priority: 50)
│  │   └─ ...
│  └─ Signals: registered(component), unregistered(component)
│
├─ Systems (Process components every frame)
│  ├─ S_InputSystem → reads Input singleton, updates C_InputComponents
│  ├─ S_MovementSystem → reads C_InputComponent + C_MovementComponent, moves body
│  ├─ S_JumpSystem → reads C_InputComponent + C_JumpComponent, applies jump velocity
│  ├─ S_GravitySystem → applies gravity to C_MovementComponent.velocity
│  ├─ S_FloatingSystem → overrides gravity when C_FloatingComponent present
│  ├─ S_RotateToInputSystem → rotates body based on input direction
│  ├─ S_AlignWithSurfaceSystem → aligns visual mesh to surface normals
│  └─ S_LandingIndicatorSystem → projects landing indicator to ground
│
└─ Components (Attached to entities)
    ├─ ECSComponent (Base class)
    │   ├─ COMPONENT_TYPE: StringName (e.g., "C_MovementComponent")
    │   ├─ _manager: M_ECSManager (cached reference)
    │   └─ _locate_manager() → finds manager in scene tree
    ├─ C_MovementComponent
    ├─ C_InputComponent
    ├─ C_JumpComponent
    ├─ C_FloatingComponent
    ├─ C_AlignWithSurfaceComponent
    ├─ C_RotateToInputComponent
    └─ C_LandingIndicatorComponent
```

### 2.2 Data Flow Overview

```
[1] Scene Loads
     ↓
[2] M_ECSManager._ready() → registers with ServiceLocator (per-scene instance)
     ↓
[3] Components._ready() → locate manager → register(self)
     ↓
[4] Systems._ready() → locate manager → cache reference
     ↓
[5] Game Loop: Godot calls M_ECSManager._physics_process(delta)
     ↓
[6] Manager keeps systems sorted by execution_priority and calls system.process_tick(delta)
     ├─ get_components(COMPONENT_TYPE) → query manager
     ├─ for component in components:
     │   ├─ Read component data
     │   ├─ Apply logic
     │   └─ Write component data or call entity methods
     └─ emit signals if needed
     ↓
[7] Repeat [5-6] every frame
```

---

## 3. Component Breakdown

### 3.1 M_ECSManager

**Location**: `scripts/core/managers/m_ecs_manager.gd`

**Purpose**: Central registry for all components and systems. Provides type-based component queries.

**Key Properties**:
```gdscript
var _components: Dictionary = {}  # StringName → Array[BaseECSComponent]
var _systems: Array[BaseECSSystem] = []
```

**Key Methods**:

#### `register_component(component: BaseECSComponent) -> void`
```gdscript
# Lines 18-31
# Called automatically by components on _ready()
# Stores component in _components[component.COMPONENT_TYPE]
# Emits registered(component) signal
# Asserts if component is null or has no COMPONENT_TYPE
```

#### `unregister_component(component: BaseECSComponent) -> void`
```gdscript
# Lines 33-49
# Called automatically on component exit_tree
# Removes component from _components array
# Emits unregistered(component) signal
```

#### `get_components(component_type: StringName) -> Array`
```gdscript
# Lines 51-53
# Returns all components of given type
# Prunes null entries from internal storage before returning
# Systems call this to query components; returns empty array if type not found
```

#### `_ready() -> void`
```gdscript
# Lines 12-16
# Ensures single instance per scene tree
# Registers with ServiceLocator for discovery
```

**Signals**:
- `registered(component: BaseECSComponent)` - Fired when component registers
- `unregistered(component: BaseECSComponent)` - Fired when component unregisters

**Discovery Pattern**:
- Registers itself with `U_ServiceLocator` on `_ready()` (one instance per gameplay scene)
- Components/systems find it via `U_ECSUtils.get_manager()`:
  1. @export injection (tests)
  2. Parent hierarchy walk (duck-typed `register_component`/`register_system`)
  3. ServiceLocator fallback

**Query Cache & Metrics**:
- `M_ECSManager` memoizes `query_entities()` responses by required/optional signature to short-circuit repeat calls.
- Instrumentation is controlled via the `query_metrics_enabled` export; disabling it clears any recorded stats and skips future tracking.
- When metrics are enabled the manager only retains the most recent entries up to `query_metrics_capacity`. Call `clear_query_metrics()` when you need a fresh baseline during profiling sessions.

---

### 3.2 ECSComponent (Base Class)

**Location**: `scripts/core/ecs/base_ecs_component.gd`

**Purpose**: Base class for all data components. Handles auto-registration with manager.

**Editor Customization**:
All components use the `@icon` decorator for visual organization in the Godot editor:
```gdscript
@icon("res://assets/editor_icons/component.svg")
extends BaseECSComponent
class_name C_MovementComponent
```
This displays a custom icon in the scene tree and inspector for easy identification.

**Key Properties**:
```gdscript
const COMPONENT_TYPE := StringName("")  # Override in subclasses
var _manager: M_ECSManager = null  # Cached manager reference
```

**Key Methods**:

#### `_ready() -> void` (lines 17-38)
```gdscript
# Auto-locates M_ECSManager in scene tree
# Registers self with manager
# Caches manager reference for faster future access
# Subclasses override but must call super._ready()
```

#### `_locate_manager() -> M_ECSManager` (lines 40-55)
```gdscript
# Discovery algorithm:
# 1. Check for injected `ecs_manager` (test hook)
# 2. Walk up parent hierarchy (duck-typed `register_component`/`register_system`)
# 3. Fallback to `U_ServiceLocator.try_get_service("ecs_manager")`
# 4. Returns null if no manager found (component remains unregistered)
```

#### `_exit_tree() -> void` (lines 57-60)
```gdscript
# Auto-unregisters from manager when component removed from scene
# Ensures no dangling references
```

**Lifecycle**:
```
Component added to scene
     ↓
_ready() called
     ↓
_locate_manager() searches scene tree
     ↓
manager.register_component(self)
     ↓
Component active (systems can query it)
     ↓
_exit_tree() called
     ↓
manager.unregister_component(self)
     ↓
Component destroyed
```

---

### 3.3 ECSSystem (Base Class)

**Location**: `scripts/core/ecs/base_ecs_system.gd`

**Purpose**: Base class for all logic systems. Provides component query API.

**Editor Customization**:
All systems use the `@icon` decorator for visual organization in the Godot editor:
```gdscript
@icon("res://assets/editor_icons/system.svg")
extends BaseECSSystem
class_name S_MovementSystem
```
This displays a custom icon in the scene tree and inspector for easy identification.

**Key Properties**:
```gdscript
var _manager: M_ECSManager = null  # Cached manager reference
```

**Key Methods**:

#### `_ready() -> void` (lines 17-23)
```gdscript
# Locates M_ECSManager in scene tree
# Caches reference (does NOT register with manager)
# Subclasses override to add initialization logic
```

#### `_locate_manager() -> M_ECSManager` (lines 40-55)
```gdscript
# Same discovery algorithm as ECSComponent
# Systems locate manager but don't register themselves
# This is asymmetric: components register, systems don't
```

#### `get_components(component_type: StringName) -> Array` (lines 26-30)
```gdscript
# Wrapper around manager.get_components()
# Returns empty array if manager not found (graceful degradation)
# Convenience method to avoid typing _manager.get_components()
```

**System Processing Pattern**:
```gdscript
# Typical system implementation
# Note: Systems override process_tick(), not _physics_process() directly
# The base ECSSystem class wraps _physics_process() and calls process_tick()
func process_tick(delta: float) -> void:
    var input_components = get_components(C_InputComponent.COMPONENT_TYPE)
    var movement_components = get_components(C_MovementComponent.COMPONENT_TYPE)

    for input_comp in input_components:
        # Find matching movement component by entity
        var body = input_comp.get_character_body()
        for movement_comp in movement_components:
            if movement_comp.get_character_body() == body:
                # Apply logic: update movement_comp based on input_comp
                movement_comp.velocity = input_comp.input_vector * movement_comp.speed
```

---

### 3.4 Concrete Components

#### C_MovementComponent (`scripts/core/ecs/components/c_movement_component.gd`)

**Data**:
```gdscript
@export var settings: RS_MovementSettings
var _horizontal_dynamics_velocity: Vector2 = Vector2.ZERO
var _last_debug_snapshot: Dictionary = {}
```

**Runtime Behavior**:
- `get_character_body() -> CharacterBody3D` — Walks up to the `E_*` entity root and auto-discovers the first `CharacterBody3D` in its subtree (cached between calls).
- `get_horizontal_dynamics_velocity()` / `set_horizontal_dynamics_velocity(value)` — Track the second-order dynamics state used by `S_MovementSystem`.
- `reset_dynamics_state()` — Clears the cached dynamics velocity when switching back to direct acceleration.
- `update_debug_snapshot(snapshot)` — Stores a deep copy for inspector overlays and unit tests.

**Used By**:
- `S_MovementSystem` — Applies input-driven movement and second-order dynamics.
- `S_GravitySystem` — Modifies vertical velocity.
- `S_FloatingSystem` — Applies air-control modifiers based on support state.

---

#### C_InputComponent (`scripts/core/ecs/components/c_input_component.gd`)

**Data**:
```gdscript
@export var input_vector: Vector2 = Vector2.ZERO
@export var jump_pressed: bool = false
@export var jump_just_pressed: bool = false
@export_node_path("Node") var character_body_path: NodePath
```

**Methods**:
- `get_character_body() -> CharacterBody3D`

**Used By**:
- `S_InputSystem` - Reads `Input` singleton, writes to component
- `S_MovementSystem` - Reads input_vector to calculate movement
- `S_JumpSystem` - Reads jump_pressed to trigger jump
- `S_RotateToInputSystem` - Reads input_vector for rotation

---

#### C_JumpComponent (`scripts/core/ecs/components/c_jump_component.gd`)

**Data**:
```gdscript
@export var settings: RS_JumpSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath
```

**Runtime State** (not @exported):
```gdscript
var _last_on_floor_time: float = -INF
var _air_jumps_remaining: int = 0
var _last_jump_time: float = -INF
var _last_apex_time: float = -INF
var _last_vertical_velocity: float = 0.0
var _debug_snapshot: Dictionary = {}
```

**Used By**:
- `S_JumpSystem` - Implements coyote time, jump buffering, applies jump velocity
	- Resolves related components via `query_entities()` instead of NodePath cross-references

---

#### C_FloatingComponent (`scripts/core/ecs/components/c_floating_component.gd`)

**Data**:
```gdscript
@export var settings: RS_FloatingSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node3D") var raycast_root_path: NodePath
```

**Runtime State**:
```gdscript
var _debug_snapshot: Dictionary = {}  # For debugging
```

**Used By**:
- `S_FloatingSystem` - Applies spring force to maintain height above ground
- `S_GravitySystem` - Skips gravity when floating is active

---

#### C_AlignWithSurfaceComponent (`scripts/core/ecs/components/c_align_with_surface_component.gd`)

**Data**:
```gdscript
@export var settings: RS_AlignSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node3D") var visual_alignment_path: NodePath
```

**Used By**:
- `S_AlignWithSurfaceSystem` - Smoothly aligns visual mesh with surface normals

---

#### C_RotateToInputComponent (`scripts/core/ecs/components/c_rotate_to_input_component.gd`)

**Data**:
```gdscript
@export var settings: RS_RotateToInputSettings
@export_node_path("Node3D") var target_node_path: NodePath
```

**Used By**:
- `S_RotateToInputSystem` - Rotates body to face input direction

---

### 3.5 Settings Resources (RS_*)

**Pattern**: Resource-Driven Configuration

All components use `Resource` classes (prefixed with `RS_`) to store configuration data. This pattern provides:
- **Inspector-friendly**: Edit values in Godot editor with real-time updates
- **Reusability**: Share settings between multiple component instances
- **Hot-reload**: Changes persist without recompiling
- **Serialization**: Saved as `.tres` files in `resources/` folder

**Location**: `scripts/core/ecs/resources/`

#### RS_MovementSettings (`rs_movement_settings.gd`)
```gdscript
extends Resource
class_name RS_MovementSettings

@export var max_speed: float = 6.0
@export var sprint_speed_multiplier: float = 1.5
@export var acceleration: float = 20.0
@export var deceleration: float = 25.0
@export var use_second_order_dynamics: bool = true
@export var response_frequency: float = 1.0
@export var damping_ratio: float = 0.5
@export var grounded_damping_multiplier: float = 1.5
@export var air_damping_multiplier: float = 0.75
@export var support_grace_time: float = 0.25
@export var air_control_scale: float = 0.3
@export var slope_limit_degrees: float = 50.0
```

#### RS_JumpSettings (`rs_jump_settings.gd`)
```gdscript
extends Resource
class_name RS_JumpSettings

@export var jump_force: float = 12.0
@export var coyote_time: float = 0.15
@export var max_air_jumps: int = 0
@export var jump_buffer_time: float = 0.15
@export var apex_coyote_time: float = 0.1
@export var apex_velocity_threshold: float = 0.1
```

#### RS_FloatingSettings (`rs_floating_settings.gd`)
```gdscript
extends Resource
class_name RS_FloatingSettings

@export var hover_height: float = 1.5
@export var hover_frequency: float = 3.0
@export var damping_ratio: float = 1.0
@export var max_up_speed: float = 20.0
@export var max_down_speed: float = 30.0
@export var fall_gravity: float = 60.0
@export var height_tolerance: float = 0.05
@export var settle_speed_tolerance: float = 0.1
@export var align_to_normal: bool = true
```

#### RS_RotateToInputSettings (`rs_rotate_to_input_settings.gd`)
```gdscript
extends Resource
class_name RS_RotateToInputSettings

@export var turn_speed_degrees: float = 720.0
@export var max_turn_speed_degrees: float = 1080.0
@export var use_second_order: bool = true
@export var rotation_frequency: float = 3.0
@export var rotation_damping: float = 1.0
```

#### RS_AlignSettings (`rs_align_settings.gd`)
```gdscript
extends Resource
class_name RS_AlignSettings

@export var smoothing_speed: float = 12.0
@export var align_only_when_supported: bool = true
@export var recent_support_tolerance: float = 0.2
@export var fallback_up_direction: Vector3 = Vector3.UP
```

#### RS_LandingIndicatorSettings (`rs_landing_indicator_settings.gd`)
```gdscript
extends Resource
class_name RS_LandingIndicatorSettings

@export var indicator_height_offset: float = 0.05
@export var ground_plane_height: float = 0.0
@export var max_projection_distance: float = 10.0
@export var ray_origin_lift: float = 0.15
@export var align_to_hit_normal: bool = true
@export_range(0, 2, 1) var normal_axis: int = 2  # 0=X, 1=Y, 2=Z
@export var normal_axis_positive: bool = false
```

**Usage Pattern**:
```gdscript
# In component
@export var settings: RS_MovementSettings

func _ready():
    if settings == null:
        push_error("Missing settings resource!")
        return

    # Access settings
    var speed = settings.max_speed
    var accel = settings.acceleration
```

**Default Instances**: Pre-configured `.tres` files in `resources/` folder:
- `movement_default.tres` → RS_MovementSettings
- `jump_default.tres` → RS_JumpSettings
- `floating_default.tres` → RS_FloatingSettings
- `rotate_default.tres` → RS_RotateToInputSettings
- `align_default.tres` → RS_AlignSettings
- `landing_indicator_default.tres` → RS_LandingIndicatorSettings

---

### 3.6 Concrete Systems

#### S_InputSystem (`scripts/core/ecs/systems/s_input_system.gd`)

**Purpose**: Reads Godot `Input` singleton, writes to `C_InputComponent`

**Processing**:
```gdscript
func process_tick(_delta: float) -> void:
    var input_components = get_components(C_InputComponent.COMPONENT_TYPE)

    for component in input_components:
        if component == null:
            continue

        # Read input actions
        var input_x := Input.get_axis("move_left", "move_right")
        var input_y := Input.get_axis("move_forward", "move_backward")

        # Write to component
        component.input_vector = Vector2(input_x, input_y)
        component.jump_just_pressed = Input.is_action_just_pressed("jump")
        component.jump_pressed = Input.is_action_pressed("jump")
```

**Execution Order**: First (reads input before other systems)

---

#### S_MovementSystem (`scripts/core/ecs/systems/s_movement_system.gd`)

**Purpose**: Applies movement based on input, handles acceleration/friction

**Processing**:
1. Query the manager for entities containing `C_MovementComponent` + `C_InputComponent` (with optional `C_FloatingComponent` for support checks).
2. For each entity:
   - Resolve the `CharacterBody3D` via `C_MovementComponent.get_character_body()` (auto-discovered at runtime).
   - Read sprint/input state, compute desired velocity using camera-relative vectors (`U_ECSUtils.get_active_camera()` fallback).
   - Apply second-order dynamics or acceleration/deceleration depending on settings and support state.
   - Apply friction when idle, clamp horizontal speed, and update debug snapshot.
3. After iterating, write velocities back to each body and invoke `move_and_slide()`.

**Dependencies**: Entities must provide both `C_MovementComponent` and `C_InputComponent`; floating support is optional.

---

#### S_JumpSystem (`scripts/core/ecs/systems/s_jump_system.gd`)

**Purpose**: Implements jump logic with coyote time and jump buffering

**Processing**:
1. Query the manager for entities with `C_JumpComponent` + `C_InputComponent` (optional `C_FloatingComponent`).
2. Build a body→floating map for entities where floating isn’t part of the query result.
3. For each entity query:
   - Resolve the body from the jump component.
   - Pull jump intent from the input component and check grounded/floating support windows.
   - Apply jump buffering, coyote time, and air-jump limits.
   - When a jump resolves, consume the input request, update debug snapshot, adjust velocities, and publish the `entity_jumped` event.

**Features**:
- **Coyote Time**: Jump shortly after losing support.
- **Jump Buffering**: Stored jump input triggers when support returns.
- **Event Integration**: Publishes `entity_jumped` with full payload for particles, audio, etc.

---

#### S_GravitySystem (`scripts/core/ecs/systems/s_gravity_system.gd`)

**Purpose**: Applies gravity to movement components (unless floating)

**Processing**:
1. Query the manager for entities containing a `C_MovementComponent` (optionally a `C_FloatingComponent`).
2. Deduplicate bodies so that gravity is applied at most once per `CharacterBody3D`.
3. Skip entities that are managed by floating components or already grounded.
4. Subtract gravity from the body’s vertical velocity and write the result back.

**Interaction with Floating**: Entities with an attached floating component are skipped (fallback mapping via `U_ECSUtils.map_components_by_body()` supports legacy wiring).

---

#### S_FloatingSystem (`scripts/core/ecs/systems/s_floating_system.gd`)

**Purpose**: Maintains entity at specified height above ground using spring physics

**Processing**:
1. Query entities that expose `C_FloatingComponent`.
2. Deduplicate per body (supports setups with multiple floating modules on the same entity).
3. Aggregate raycast hits to compute average surface normal and closest distance.
4. When support exists, apply critically-damped spring dynamics toward the desired hover height, clamp velocities, optionally align the body’s up vector, and update support metadata.
5. When no support is found, apply configured fall gravity while clamping vertical velocity.

**Physics**: Implements a spring-damper system for smooth floating and ground alignment.

---

#### S_RotateToInputSystem (`scripts/core/ecs/systems/s_rotate_to_input_system.gd`)

**Purpose**: Rotates entity to face input direction

**Processing**:
1. Query entities containing both `C_RotateToInputComponent` and `C_InputComponent`.
2. Resolve the target node to rotate (still supplied via the component’s NodePath).
3. Read movement input from the queried `C_InputComponent` (NodePath lookup retained as fallback).
4. Convert the 2D input vector to a desired yaw and clamp turn rate using either second-order dynamics or simple angular acceleration.
5. Persist rotation velocity state on the component when using the second-order path.

---

## 4. Data Flow

### 4.1 Component Registration Flow

```
[1] Component node added to scene
         ↓
[2] Component._ready() called by Godot
         ↓
[3] _locate_manager() searches scene tree
         │
         ├─ [3a] Walk parent hierarchy
         │      Check: node.has_method("register_component")
         │      If found: return node
         │
         └─ [3b] Fallback: resolve via ServiceLocator ("ecs_manager")
         ↓
[4] _manager = located_manager  (cache reference)
         ↓
[5] _manager.register_component(self)
         ↓
[6] Manager adds to _components[COMPONENT_TYPE]
         ↓
[7] Manager emits registered(component) signal
         ↓
[8] Component now queryable by systems
```

### 4.2 System Query Flow

```
[1] M_ECSManager._physics_process(delta) selects the next system in priority order
         ↓
[2] system.process_tick(delta) runs
         ↓
[3] var entities = system.query_entities(required_types, optional_types)
         ↓
[4] Manager assembles U_EntityQuery results from entity→component map
         ↓
[5] Returns Array[U_EntityQuery] (each holds entity + component dictionary)
         ↓
[6] System iterates entity queries
         │
[6a] for query in entities:
         │      ├─ var movement = query.get_component(C_MovementComponent.COMPONENT_TYPE)
         │      ├─ Optional: var floating = query.get_component(C_FloatingComponent.COMPONENT_TYPE)
         │      ├─ Apply logic using resolved components
         │      └─ Write component data or call entity methods
         │
         └─ Continue next frame
```

### 4.3 Entity Query Resolution

**Goal**: Allow systems to operate on sets of components that coexist on the same entity without manual NodePath wiring.

**Pattern**:
- Components register with the manager using their `COMPONENT_TYPE`.
- `M_ECSManager` maintains an entity→component map keyed by the closest ancestor whose name starts with `E_`.
- Systems call `query_entities(required_types, optional_types)` to retrieve `U_EntityQuery` objects.

**U_EntityQuery Structure**:
```gdscript
class_name U_EntityQuery

var entity: Node  # Entity root (e.g., E_Player)
var components: Dictionary[StringName, ECSComponent]

func get_component(component_type: StringName) -> ECSComponent:
    return components.get(component_type)
```

**Usage** (S_MovementSystem):
```
[1] required := [C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE]
[2] optional := [C_FloatingComponent.COMPONENT_TYPE]
[3] for query in manager.query_entities(required, optional):
         ├─ movement := query.get_component(C_MovementComponent.COMPONENT_TYPE)
         ├─ input := query.get_component(C_InputComponent.COMPONENT_TYPE)
         ├─ floating := query.get_component(C_FloatingComponent.COMPONENT_TYPE)  # May be null
         └─ Apply movement logic using resolved components
```

**Benefits**:
- No cross-component NodePath exports.
- Optional components seamlessly handled (null when absent).
- Systems can share helper maps via `U_ECSUtils.map_components_by_body()` without re-querying.

**Scene-Only NodePaths**: Components still export NodePaths for non-component dependencies (e.g., raycasts, meshes). These references remain within the owning entity and do not participate in entity queries.

### 4.4 Component Unregistration Flow

```
[1] Component node removed from scene
         ↓
[2] Component._exit_tree() called by Godot
         ↓
[3] Check: _manager != null
         ↓
[4] _manager.unregister_component(self)
         ↓
[5] Manager removes from _components[COMPONENT_TYPE] array
         ↓
[6] Manager emits unregistered(component) signal
         ↓
[7] Component destroyed by Godot
```

---

## 5. Integration Points

### 5.1 Scene Tree Setup

**Typical Scene Structure**:
```
Main Scene (Node)
├─ M_ECSManager (manager node)
│
├─ Player (CharacterBody3D) ← Entity
│  ├─ C_MovementComponent
│  ├─ C_InputComponent
│  ├─ C_JumpComponent
│  ├─ C_FloatingComponent
│  ├─ MeshInstance3D (visual)
│  └─ RayCast3D (ground check)
│
├─ S_InputSystem
├─ S_MovementSystem
├─ S_JumpSystem
├─ S_GravitySystem
├─ S_FloatingSystem
└─ S_RotateToInputSystem
```

**Setup Steps**:
1. Add `M_ECSManager` node to scene (anywhere in tree)
2. Add entity node (e.g., `CharacterBody3D`)
3. Add components as children of entity
4. Configure component @export properties in inspector:
   - Set `character_body_path` (and other same-entity NodePaths like raycasts) where required
   - No cross-component NodePath wiring needed for movement/jump; systems join components via queries
5. Add system nodes to scene (anywhere in tree)
6. Systems automatically discover manager on scene load

### 5.2 Discovery Pattern

**How components/systems find M_ECSManager**:

**Step 1: Parent Hierarchy Walk** (preferred, faster)
```gdscript
func _locate_manager() -> M_ECSManager:
    var current_node: Node = get_parent()
    while current_node != null:
        if current_node.has_method("register_component"):
            return current_node
        current_node = current_node.get_parent()
    # ... fallback to step 2
```

**Step 2: ServiceLocator Fallback**
```gdscript
func _locate_manager() -> M_ECSManager:
    # ... parent walk failed
    var manager := U_ServiceLocator.try_get_service(StringName("ecs_manager")) as M_ECSManager
    return manager
```

**Why This Pattern?**
- **Flexible**: Manager can be anywhere in scene tree
- **Cached**: Result stored in `_manager` variable
- **Fail-Fast**: Asserts if manager not found (developer error)
- **No Singleton**: Avoids global state, testable

### 5.3 Lifecycle Order

**Scene Load**:
```
1. M_ECSManager._ready()       → registers with ServiceLocator ("ecs_manager")
2. Components._ready()          → locate manager, register
3. Systems._ready()             → locate manager, cache reference
4. Game loop starts
```

**Scene Unload**:
```
1. Game loop stops
2. Components._exit_tree()      → unregister from manager
3. Systems destroyed
4. M_ECSManager destroyed
```

**Hot-Reload** (F5 in editor):
```
1. Scene unloads (all nodes destroyed)
2. Scene reloads (new instances created)
3. All components re-register
4. Systems re-locate manager
```

### 5.4 Testing Integration

**Unit Testing Components**:
```gdscript
# tests/unit/ecs/components/test_movement_component.gd
extends GutTest

func test_movement_component_defaults():
    var component = C_MovementComponent.new()
    assert_eq(component.velocity, Vector3.ZERO)
    assert_eq(component.max_speed, 5.0)
```

**Integration Testing Systems**:
```gdscript
# tests/unit/ecs/systems/test_movement_system.gd
extends GutTest

func test_movement_system_applies_velocity():
    # Setup
    var manager = M_ECSManager.new()
    add_child(manager)
    await get_tree().process_frame

    var body = CharacterBody3D.new()
    add_child(body)

    var movement_comp = C_MovementComponent.new()
    movement_comp.settings = RS_MovementSettings.new()
    body.add_child(movement_comp)
    await get_tree().process_frame

    var input_comp = C_InputComponent.new()
    input_comp.input_vector = Vector2(1, 0)
    body.add_child(input_comp)
    await get_tree().process_frame

    var system = S_MovementSystem.new()
    add_child(system)
    await get_tree().process_frame

    # Execute
    system._physics_process(0.016)

    # Verify
    assert_true(movement_comp.velocity.x > 0, "Velocity should increase")
```

---

## 6. Key Patterns

### 6.1 Entity Abstraction via Scene Nodes

**Pattern**: Entities are represented by `CharacterBody3D` (or other `Node` types).

**Why Not Explicit Entity Class?**
- Leverages Godot's scene tree for hierarchy
- Entities get all node features (transform, parent/child, signals)
- No need for separate entity ID system

**Trade-off**: Entities must be in scene tree (can't have "abstract" entities).

**Entity Identification Contract**:
- Attach `scripts/core/ecs/base_ecs_entity.gd` to every gameplay entity root. The script registers the node with the ECS manager so component discovery becomes deterministic without relying on naming.
- Entities are discovered via `BaseECSEntity` and the `E_` prefix; the legacy `ecs_entity` group fallback has been removed.
- The manager caches discovered roots in its instance-id dictionary, so reparenting or renaming should continue to satisfy the script/prefix contract without relying on metadata.

### 6.2 Auto-Registration

**Pattern**: Components self-register on `_ready()`.

**Benefits**:
- No manual registration code needed
- Hot-reload friendly (components re-register automatically)
- Declarative (add component to scene = it's registered)

**Implementation**:
```gdscript
# In ECSComponent base class
func _ready() -> void:
    _manager = _locate_manager()
    if _manager:
        _manager.register_component(self)
```

### 6.3 Type-Based Component Queries

**Pattern**: Systems query components by `StringName` constant.

**Example**:
```gdscript
const COMPONENT_TYPE := StringName("C_MovementComponent")

# In system:
var components = get_components(C_MovementComponent.COMPONENT_TYPE)
```

**Benefits**:
- Fast lookup (Dictionary keyed by StringName)
- Type-safe (constant defined per component class)
- Easy to query (no complex filter predicates)

**Limitation**: Can only query one component type at a time (no multi-component queries).

### 6.4 Cross-Component NodePath References

**Pattern**: Components store `NodePath` to other required components.

**Example**:
```gdscript
# In C_MovementComponent
@export_node_path("Node") var input_component_path: NodePath

func get_input_component() -> C_InputComponent:
    if input_component_path.is_empty():
        return null
    return get_node_or_null(input_component_path) as C_InputComponent
```

**Benefits**:
- Works with Godot inspector (drag-and-drop node references)
- Serializable (saves with scene)

**Drawbacks**:
- **Tight Coupling**: Component knows about other specific component types
- **Manual Matching**: Systems must manually cross-reference components
- **Not Composable**: Can't easily swap input sources (player vs AI)

**See**: [§8 Current Limitations](#8-current-limitations) for improvement proposals.

### 6.5 Settings Resources

**Pattern**: Components optionally load settings from `Resource` files.

**Example**:
```gdscript
# In C_FloatingComponent
@export var settings: FloatingSettings

func _ready():
    super._ready()  # Register with manager
    if settings:
        floating_height = settings.height
        floating_spring_strength = settings.spring_strength
```

**Benefits**:
- Reusable configs across multiple entities
- Editor-friendly (edit in inspector, save as `.tres` file)
- Hot-reload friendly (change resource, see instant updates)

### 6.6 Component State Validation

**Pattern**: Components validate state in `_ready()` before registration.

**Example**:
```gdscript
# In C_JumpComponent._ready()
func _ready() -> void:
    if settings:
        # Validate settings exist
        if settings.jump_velocity == null:
            push_error("JumpComponent: settings.jump_velocity is null")
            return
    super._ready()  # Register only if valid
```

**Benefits**:
- Fail-fast on configuration errors
- Clear error messages in console
- Prevents invalid components from being registered

### 6.7 Scene Tree Scope & Cross-Tree References

**The Problem**: Components in `player_template.tscn` (instantiated) cannot reference nodes in `base_scene_template.tscn` (parent scene) via NodePath. Scene boundaries break NodePath references.

**Example**:
```
base_scene_template.tscn
├─ E_PlayerCamera (Camera3D)           ← In base scene
└─ E_Player (instance of player_template.tscn)
    └─ C_MovementComponent
        └─ camera_node_path: NodePath  ← Cannot reach E_PlayerCamera!
```

**NodePath Policy**:

| Reference Type | Scope | Method |
|----------------|-------|--------|
| ✅ Component → Body | Same entity subtree | NodePath export |
| ✅ Component → RayCast | Same entity subtree | NodePath export |
| ❌ Component → Another Component | Any scope | Use query system |
| ❌ Component → Cross-tree Node | Different scene file | Runtime discovery |

**Cross-Tree Resolution Patterns**:

#### 1. General Infrastructure (`U_ECSUtils`)

```gdscript
# For singletons (one instance per scene)
static func get_singleton_from_group(
        from_node: Node,
        group_name: StringName,
        warn_on_missing: bool = true) -> Node:
    """Get first node from group (managers, main camera, main player, etc.)"""
    if from_node == null:
        return null
    var tree := from_node.get_tree()
    if tree == null:
        return null
    var nodes: Array = tree.get_nodes_in_group(group_name)
    if not nodes.is_empty():
        return nodes[0]
    if warn_on_missing:
        push_warning("U_ECSUtils: No node found in group '%s'" % String(group_name))
    return null

# For collections (multiple instances)
static func get_nodes_from_group(from_node: Node, group_name: StringName) -> Array:
    """Get all nodes from group (spawn points, enemies, collectibles, etc.)"""
    if from_node == null:
        return []
    var tree := from_node.get_tree()
    if tree == null:
        return []
    var nodes: Array = tree.get_nodes_in_group(group_name)
    return nodes.duplicate()

# Specialized helper for cameras
static func get_active_camera(from_node: Node) -> Camera3D:
    """Resolve the active gameplay camera without relying on NodePaths."""
    if from_node == null:
        return null
    var camera_manager := U_SERVICE_LOCATOR.try_get_service(StringName("camera_manager"))
    if camera_manager != null and camera_manager.has_method("get_main_camera"):
        var main_camera := camera_manager.call("get_main_camera") as Camera3D
        if main_camera != null and is_instance_valid(main_camera):
            return main_camera
    var viewport := from_node.get_viewport()
    if viewport != null:
        var camera := viewport.get_camera_3d()
        if camera != null:
            return camera
    return get_singleton_from_group(from_node, StringName("main_camera"), false) as Camera3D
```

#### 2. Cross-Tree Reference Strategy

- Prefer explicit references and ServiceLocator for managers/cameras/entities.
- Group helpers remain only as legacy fallbacks; do not introduce new group dependencies.

| Reference | Preferred Lookup | Notes |
|-----------|------------------|-------|
| `ecs_manager` | `U_ECSUtils.get_manager()` (injection → parent → ServiceLocator) | Group path removed |
| `main_camera` | `M_CameraManager.get_main_camera()` via ServiceLocator | Legacy group fallback only |
| `main_player` | Explicit scene references | Avoid group reliance |
| `spawn_points` | Typed scene paths or registries | Group helper only for legacy content |
| `interactables` | Controller registration | Group usage deprecated |

#### 3. Resolution Priority (for any cross-tree reference)

```
1. Injected dependency (tests) or ServiceLocator registration
2. Parent hierarchy (same-tree optimization)
3. Legacy group helpers (avoid in new code)
4. Return null + warning
```

#### 4. Specialized Helpers Use General Pattern

```gdscript
# Camera helper (Godot API + group fallback)
static func get_active_camera(from_node: Node) -> Camera3D:
    """Get active camera (cross-tree safe)"""
    if from_node == null:
        return null
    # Priority 1: Viewport's active camera (Godot's native "current" camera)
    var viewport := from_node.get_viewport()
    if viewport != null:
        var cam := viewport.get_camera_3d()
        if cam != null:
            return cam
    # Priority 2: Fallback to "main_camera" group
    return get_singleton_from_group(from_node, StringName("main_camera"), false) as Camera3D

# Manager helper (parent hierarchy + group fallback)
static func get_manager(from_node: Node) -> M_ECSManager:
    """Get ECS manager (same-tree optimization + cross-tree fallback)"""
    if from_node == null:
        return null
    # Priority 1: Injected manager (tests)
    if "ecs_manager" in from_node:
        var injected := from_node.get("ecs_manager")
        if injected != null and is_instance_valid(injected):
            return injected as M_ECSManager

    # Priority 2: Parent hierarchy (faster for same-tree)
    var current := from_node.get_parent()
    while current != null:
        if current.has_method("register_component") and current.has_method("register_system"):
            return current as M_ECSManager
        current = current.get_parent()

    # Priority 3: ServiceLocator fallback
    return U_ServiceLocator.try_get_service(StringName("ecs_manager")) as M_ECSManager

# Testing hook (capture warnings in unit tests)
static func set_warning_handler(handler: Callable) -> void:
    _warning_handler = handler

static func reset_warning_handler() -> void:
    _warning_handler = Callable()
```

#### 5. Example: Camera Access with Override Pattern

```gdscript
# Component (optional same-subtree override)
@export_node_path("Camera3D") var camera_node_path: NodePath

# System (uses override OR runtime discovery)
func process_tick(delta: float) -> void:
    for entity in query_entities([C_MovementComponent.COMPONENT_TYPE]):
        var movement_comp = entity.get_component(C_MovementComponent.COMPONENT_TYPE)

        # Priority: 1) component override → 2) runtime discovery → 3) null
        var camera: Camera3D = null
        if movement_comp.camera_node_path:
            camera = movement_comp.get_node_or_null(movement_comp.camera_node_path)
        if not camera:
            camera = U_ECSUtils.get_active_camera(self)  # Cross-tree safe!

        if camera:
            # Use camera for movement rotation/aiming...
```

**Why This Matters**:

- **Scene Composition**: Templates instantiate other templates (player in base scene)
- **Prefabs**: Reusable entities work in any scene without manual wiring
- **Dynamic Spawning**: Runtime-spawned entities discover resources automatically
- **Decoupling**: Systems find resources without hardcoded scene structure

**Rule of Thumb**: If it's in a different scene file, use runtime discovery, not NodePath.

---

### 6.8 Priority-Sorted System Scheduling

**What changed**: Every system exposes `@export var execution_priority: int` (clamped to `0–1000`). `M_ECSManager` keeps a cached, priority-sorted list and drives systems from its own `_physics_process`. Individual systems only run their `_physics_process` when unmanaged (useful for isolated testing scenarios).

**Scheduling rules**:
- Lower numbers execute earlier within the same physics frame.
- Ties fall back to registration order, guaranteeing deterministic behaviour across loads.
- Updating `execution_priority` at runtime calls `M_ECSManager.mark_systems_dirty()`, forcing a re-sort before the next tick.
- Priorities are editor-visible so scene authors can reason about ordering without checking code.

**Recommended bands** (leave gaps so future systems can slot in without renumbering):
- `0–9` Input capture and sensor sampling (`S_InputSystem`).
- `10–39` Pre-physics state derivation (input buffering, timers, cache warm-up).
- `40–69` Core motion & forces (`S_JumpSystem`, `S_GravitySystem`, `S_MovementSystem`).
- `70–109` Post-motion adjustments (`S_FloatingSystem`, `S_RotateToInputSystem`, `S_AlignWithSurfaceSystem`).
- `110–199` Feedback layers (`S_LandingIndicatorSystem`, VFX/audio responders).
- `200+` Diagnostics, analytics, and experimental systems that must never block gameplay.

**Example**:
```gdscript
func _ready() -> void:
	execution_priority = 50  # Movement runs after input (0) but before alignment (90)
```

**Verification**:
- `tests/unit/ecs/test_ecs_manager.gd` asserts priority order execution using a log of invoked systems.
- `tests/unit/ecs/systems/test_landing_indicator_system.gd` covers mixed-priority scenarios to ensure deterministic ordering when multiple systems act on the same entity.

See [§8.4 System Execution Ordering](#84-system-execution-ordering) for status notes and migration guidance.

---

## 7. Example Flows

### 7.1 Player Jump (Complete Flow)

**Scenario**: Player presses jump button, character jumps.

**Flow**:
```
[Frame N: Jump Button Pressed]

1. S_InputSystem._process()
   ├─ Input.is_action_just_pressed("jump") → true
   ├─ Queries: get_components(C_InputComponent.COMPONENT_TYPE)
   ├─ Writes: input_comp.jump_just_pressed = true
   └─ Result: C_InputComponent.jump_just_pressed = true

2. S_JumpSystem._physics_process(delta)
   ├─ Queries: get_components(C_JumpComponent.COMPONENT_TYPE)
   ├─ For each jump_comp:
   │   ├─ var input_comp = jump_comp.get_input_component()
   │   ├─ var body = jump_comp.get_character_body()
   │   ├─ var raycast = jump_comp.get_ground_check_raycast()
   │   │
   │   ├─ Check: raycast.is_colliding() → true (on ground)
   │   ├─ Update: jump_comp.time_since_grounded = 0.0
   │   │
   │   ├─ Check: input_comp.jump_just_pressed → true
   │   ├─ Update: jump_comp.time_since_jump_pressed = 0.0
   │   │
   │   ├─ Check: can_jump = (time_since_grounded < coyote_time) → true
   │   ├─ Apply: body.velocity.y = jump_comp.jump_velocity
   │   └─ Consume: jump_comp.time_since_jump_pressed = 999.0
   │
   └─ Result: body.velocity.y = 5.0 (upward velocity)

3. S_GravitySystem._physics_process(delta)
   ├─ Queries: get_components(C_MovementComponent.COMPONENT_TYPE)
   ├─ Check: entity has C_FloatingComponent? → No
   ├─ Apply: movement_comp.velocity.y += GRAVITY * delta
   ├─ Sync: body.velocity = movement_comp.velocity
   └─ Result: Gravity will start pulling down next frame

[Frame N+1: In Air]

4. S_JumpSystem._physics_process(delta)
   ├─ Check: raycast.is_colliding() → false (in air)
   ├─ Update: jump_comp.time_since_grounded += delta (starts coyote timer)
   └─ Result: Can still jump within coyote_time window

5. S_GravitySystem._physics_process(delta)
   ├─ Apply: movement_comp.velocity.y += GRAVITY * delta
   └─ Result: Character decelerates upward, then falls

[Frame N+10: Landing]

6. S_JumpSystem._physics_process(delta)
   ├─ Check: raycast.is_colliding() → true (landed)
   ├─ Update: jump_comp.time_since_grounded = 0.0
   └─ Result: Ready to jump again
```

### 7.2 Player Movement (Complete Frame)

**Scenario**: Player holds right arrow key, character moves right.

**Flow** (single frame):
```
[_process(delta) - Runs before _physics_process]

1. S_InputSystem._process(delta)
   ├─ Input.get_axis("move_left", "move_right") → 1.0
   ├─ Input.get_axis("move_forward", "move_backward") → 0.0
   ├─ Writes: input_comp.input_vector = Vector2(1, 0)
   └─ Result: Input captured

[_physics_process(delta) - Runs after _process]

2. S_MovementSystem._physics_process(delta)
   ├─ Queries: get_components(C_MovementComponent.COMPONENT_TYPE)
   ├─ For each movement_comp:
   │   ├─ var input_comp = movement_comp.get_input_component()
   │   ├─ var body = movement_comp.get_character_body()
   │   │
   │   ├─ Calculate: input_dir = Vector3(1, 0, 0)
   │   ├─ Calculate: target_velocity = input_dir * max_speed = Vector3(5, 0, 0)
   │   │
   │   ├─ Lerp: movement_comp.velocity = lerp(current, target, acceleration * delta)
   │   │       = lerp(Vector3(0,0,0), Vector3(5,0,0), 50 * 0.016)
   │   │       = lerp(Vector3(0,0,0), Vector3(5,0,0), 0.8)
   │   │       = Vector3(4, 0, 0)
   │   │
   │   ├─ Apply: body.velocity = movement_comp.velocity
   │   ├─ Move: body.move_and_slide()
   │   └─ Sync: movement_comp.velocity = body.velocity
   │
   └─ Result: Character moves right at 4 m/s (accelerating toward 5 m/s)

3. S_RotateToInputSystem._process(delta)
   ├─ Queries: manager.query_entities([C_RotateToInputComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE])
   ├─ For each entity query:
   │   ├─ rotate_comp = query.get_component(C_RotateToInputComponent.COMPONENT_TYPE)
   │   ├─ input_comp = query.get_component(C_InputComponent.COMPONENT_TYPE)
   │   ├─ var body = rotate_comp.get_character_body()
   │   │
   │   ├─ Calculate: input_dir = Vector3(1, 0, 0)
   │   ├─ Calculate: target_rotation = atan2(1, 0) = 1.57 rad (90 degrees)
   │   │
   │   ├─ Lerp: new_rotation = lerp_angle(current, target, rotation_speed * delta)
   │   ├─ Apply: body.rotation.y = new_rotation
   │   │
   └─ Result: Character rotates to face right
```

### 7.3 Floating Character (System Interaction)

**Scenario**: Character with `C_FloatingComponent` hovers above ground.

**Flow**:
```
[Physics Tick]

1. S_FloatingSystem._physics_process(delta)
   ├─ Queries: manager.query_entities([C_FloatingComponent.COMPONENT_TYPE])
   ├─ For each floating_comp:
   │   ├─ Check: floating_comp.floating_enabled → true
   │   ├─ var raycast = floating_comp.get_ground_check_raycast()
   │   ├─ Check: raycast.is_colliding() → true
   │   │
   │   ├─ Calculate: distance_to_ground = raycast distance
   │   ├─ Calculate: height_error = floating_height - distance_to_ground
   │   │           = 1.0 - 0.8 = 0.2 (too low, need to rise)
   │   │
   │   ├─ Spring Force: k * x - d * v
   │   │   = 10 * 0.2 - 0.5 * body.velocity.y
   │   │   = 2.0 - (0.5 * -0.5)
   │   │   = 2.0 + 0.25 = 2.25 N (upward)
   │   │
   │   ├─ Apply: body.velocity.y += spring_force * delta
   │   │         = -0.5 + 2.25 * 0.016 = -0.464
   │   │
   │   ├─ Move: body.move_and_slide()
   │   └─ Debug: Update _debug_snapshot
   │
   └─ Result: Character rises slowly toward target height

2. S_GravitySystem._physics_process(delta)
   ├─ Queries: get_components(C_MovementComponent.COMPONENT_TYPE)
   ├─ For each movement_comp:
   │   ├─ var body = movement_comp.get_character_body()
   │   │
   │   ├─ Build: floating_by_body map
   │   ├─ Check: floating_by_body.has(body) → true
   │   │
   │   └─ Skip: Gravity NOT applied (floating active)
   │
   └─ Result: Floating overrides gravity

[Next Frame]
   Floating system continues adjusting height until:
   height_error ≈ 0 and velocity.y ≈ 0
   → Character hovers stably at floating_height
```

---

## 8. Current Limitations

### 8.1 Multi-Component Queries (Stories 2.1–2.6)

**Status**: ✅ Delivered. `M_ECSManager.query_entities(required, optional)` now powers every gameplay system.

**Highlights**:
- Returns `Array[U_EntityQuery]`, each providing the entity root and a dictionary of resolved components.
- Optional components are supported; missing entries resolve to `null`.
- The manager caches an entity→component map so repeated queries avoid walking the scene tree.
- `U_ECSUtils.map_components_by_body()` supplements queries when systems need body-level deduplication.

**Migration Notes**:
- Remove NodePath links between components; rely on queries to co-locate data.
- In tests, `await get_tree().process_frame` after spawning manager + components before calling `query_entities()` to allow deferred registration to complete.

---

### 8.2 Component Coupling (Stories 4.1–4.4)

**Status**: ✅ Delivered. Components no longer reference each other through NodePaths; systems stitch data together via entity queries.

**Highlights**:
- Movement, jump, rotate-to-input, and align-with-surface components auto-discover their entity’s `CharacterBody3D` and expose typed getters.
- Cross-component relationships live entirely in systems (`S_MovementSystem`, `S_JumpSystem`, etc.), eliminating hidden dependencies inside components.
- Scenes wire only scene-graph resources (meshes, raycasts, markers). Component-to-component wiring is forbidden and enforced by validation hooks.

**Migration Notes**:
- Remove legacy `*_component_path` exports from existing scenes (use the updated templates for reference).
- Tests constructing components in isolation should rely on helper factories that create minimal entity trees to satisfy auto-discovery requirements.

---

### 8.3 Event Bus System (Stories 3.1–3.4)

**Status**: ✅ Delivered. `U_ECSEventBus` provides publish/subscribe semantics with a rolling history buffer for debugging.

**Highlights**:
- `U_ECSEventBus.publish(event_type: StringName, payload: Dictionary)` timestamps every event.
- Subscribers register callable handlers and receive events in the order they were fired.
- History buffer defaults to 1,000 events and is configurable (`set_history_limit()`).
- Sample systems (`S_JumpParticlesSystem`, `S_JumpSoundSystem`) demonstrate decoupled reactions to `entity_jumped`.

**Migration Notes**:
- Replace ad-hoc signal wiring between systems with event bus topics.
- Be mindful of payload size: keep dictionaries lean (<1 KB) to avoid ballooning the history buffer.

#### Standard ECS Events (Phase 7, Enhanced Phase 10B-6)

**📚 See [ecs_events.md](./ecs_events.md) for comprehensive event documentation including typed events, priority system, and API reference.**

**Core Events** (Phase 10B-6 - Typed Events):

| Event | Typed Class | Publisher | Subscribers | Priority |
|-------|-------------|-----------|-------------|----------|
| `health_changed` | `Evn_HealthChanged` | `C_HealthComponent` | _(state-driven)_ | - |
| `entity_death` | `Evn_EntityDeath` | `C_HealthComponent` | `M_SceneManager` (10), `S_GamepadVibrationSystem` (0) | 10: Quick game over |
| `victory_triggered` | `Evn_VictoryTriggered` | `C_VictoryTriggerComponent` | `S_GameEventSystem` (0), `S_VictorySoundSystem` (0) | Rule trigger fan-out |
| `victory_execution_requested` | _(StringName)_ | `S_GameEventSystem` | `S_VictoryHandlerSystem` (10) | Validated gameplay writes |
| `victory_executed` | _(StringName)_ | `S_VictoryHandlerSystem` | `M_SceneManager` (5) | Transition after validation |
| `checkpoint_activated` | `Evn_CheckpointActivated` | `S_CheckpointHandlerSystem` | `UI_HudController` (0) | - |

**Additional Events** (StringName):
- `victory_zone_entered`, `checkpoint_zone_entered`, `damage_zone_entered/exited`
- `entity_jumped`, `entity_landed`, `component_registered`, `entity_registered/unregistered`

**Subscription Pattern with Priority**:
```gdscript
# Subscribe with priority (higher = called first)
var _unsubscribe := U_ECSEventBus.subscribe(
    StringName("entity_death"),
    _on_entity_death,
    10  # High priority
)

# Unsubscribe in _exit_tree()
func _exit_tree() -> void:
    if _unsubscribe != null and _unsubscribe.is_valid():
        _unsubscribe.call()
```

**Typed Event Publishing**:
```gdscript
var death_event := Evn_EntityDeath.new(entity_id, prev_health, 0.0, true)
U_ECSEventBus.publish_typed(death_event)  # Auto-converts to "entity_death"
```

**Priority Guidelines**:
- **10**: Critical state updates before transitions (e.g., S_VictoryHandlerSystem)
- **5-9**: Important ordering (e.g., M_SceneManager transitions after state)
- **0** (default): No special ordering needed (UI, VFX, haptics)

---

### 8.4 System Execution Ordering (Stories 5.1–5.3)

**Status**: ✅ Delivered. Systems no longer rely on scene-tree placement; `M_ECSManager` sorts them by `execution_priority` every time the order changes.

**Highlights**:
- `execution_priority` is exported on `BaseECSSystem`, clamped to `0–1000`, and visible in the inspector.
- Lower values run earlier; registration order breaks ties.
- `M_ECSManager.mark_systems_dirty()` is invoked whenever a system’s priority changes, so the next physics tick re-sorts the cache.
- Recommended priority bands are documented in [§6.8](#68-priority-sorted-system-scheduling).

**Migration Notes**:
- Update existing scenes to set priorities explicitly (e.g., Input = 0, Jump ≈ 40, Movement ≈ 50, Alignment ≈ 90).
- Remove legacy per-system `_physics_process` calls in tests; instead, tick the manager (`manager._physics_process(delta)`).
- When adding a new system, pick a value that leaves at least five unused slots above and below for future insertions.

**Next Steps**: Add optional debug instrumentation that prints the executed order in-editor when a developer flag is enabled (tracked separately).

---

### 8.5 Entity IDs & Tagging ✅ RESOLVED (Phase 6 - 2025-12-09)

**Status**: Implemented

**Solution**: Explicit entity ID and tag system added to `BaseECSEntity` with automatic registration via `M_ECSManager`.

#### Entity ID System

**Pattern**: All entities (nodes extending `BaseECSEntity`) have unique string identifiers.

**ID Assignment**:
- **Auto-generated**: ID derived from node name (`E_Player` → `"player"`)
  - Strips `E_` prefix, converts to lowercase
  - Cached after first call to `get_entity_id()`
- **Manual override**: Set `entity_id` export variable for custom IDs
- **Duplicate handling**: Automatically appends `_{instance_id}` suffix on collision

**Core Methods** (in `BaseECSEntity`):
```gdscript
func get_entity_id() -> StringName    # Returns cached or generated ID
func set_entity_id(id: StringName)     # Allows manager to update on duplicates
```

**Manager Integration** (in `M_ECSManager`):
```gdscript
func register_entity(entity: Node) -> void           # Auto-registers when first component added
func get_entity_by_id(id: StringName) -> Node        # Lookup entity by ID
func get_all_entity_ids() -> Array[StringName]      # Get all registered IDs
```

#### Tag System

**Pattern**: Entities can have multiple freeform tags for categorization.

**Tag Usage**:
- **Export variable**: `@export var tags: Array[StringName] = []`
- **Dynamic management**: `add_tag(tag)`, `remove_tag(tag)`, `has_tag(tag)`
- **Tag queries**: Find entities by tags (ANY or ALL match)

**Core Methods** (in `BaseECSEntity`):
```gdscript
func get_tags() -> Array[StringName]       # Returns defensive copy
func has_tag(tag: StringName) -> bool      # Check for tag
func add_tag(tag: StringName) -> void      # Add tag, updates manager index
func remove_tag(tag: StringName) -> void   # Remove tag, updates manager index
```

**Manager Queries** (in `M_ECSManager`):
```gdscript
func get_entities_by_tag(tag: StringName) -> Array[Node]
func get_entities_by_tags(tags: Array[StringName], match_all: bool = false) -> Array[Node]
```

#### Example Usage

```gdscript
# Entity setup in scene
var player := E_PlayerRoot.new()
player.entity_id = StringName("player")        # Manual ID
player.tags = [StringName("player"), StringName("controllable")]

# System queries
var manager := U_ECSUtils.get_manager(self)
var player_entity := manager.get_entity_by_id(StringName("player"))
var hostile_entities := manager.get_entities_by_tag(StringName("enemy"))
var boss_enemies := manager.get_entities_by_tags([StringName("enemy"), StringName("boss")], true)
```

#### State Store Integration

**Snapshot Building** (in `U_ECSUtils`):
```gdscript
func build_entity_snapshot(entity: Node) -> Dictionary
    # Returns: { "entity_id": String, "tags": Array[String], "position": Vector3, ... }
```

**Redux Actions** (in `U_EntityActions`):
- Accept both `String` and `StringName` for entity_id parameters
- Automatically converted to String for dictionary keys

#### Events

**Entity Lifecycle Events** (published to `U_ECSEventBus`):
- `"entity_registered"` - payload: `{ "entity_id": StringName, "entity": Node }`
- `"entity_unregistered"` - payload: `{ "entity_id": StringName, "entity": Node }`

#### Benefits

✅ **Unique identifiers**: Every entity has a stable ID across scene transitions
✅ **Flexible categorization**: Tag-based queries for gameplay logic
✅ **State persistence**: Entity IDs integrate with Redux state snapshots
✅ **Event-driven architecture**: Entity registration/unregistration via event bus
✅ **Automatic management**: Auto-registration when first component added
✅ **Collision-safe**: Duplicate IDs automatically resolved with instance ID suffix

#### ID/Tag Inventory (Phase 6 rollout)

**Templates**

| Scene | Entity Node | entity_id | tags | Notes |
|---|---|---|---|---|
| templates/tmpl_character.tscn | E_CharacterRoot | `""` (auto → `characterroot`) | `[character]` | Generic character base (movement/physics/health, no input) |
| templates/tmpl_camera.tscn | E_CameraRoot | `camera` | `[camera]` | Main camera; member of `main_camera` group |

**Prefabs**

| Prefab | Entity Node | entity_id | tags | Notes |
|---|---|---|---|---|
| scenes/core/prefabs/prefab_checkpoint_safe_zone.tscn | E_Checkpoint_SafeZone | `checkpoint_safezone` | `[checkpoint, objective]` | Passive respawn/restore volume |
| scenes/core/prefabs/prefab_player.tscn | E_PlayerRoot | `player` | `[player, character]` | Player prefab (character template + input/gamepad/player tag) |
| scenes/core/prefabs/prefab_death_zone.tscn | E_DeathZone | `deathzone` | `[hazard, death]` | Instant-death hazard volume |
| scenes/core/prefabs/prefab_spike_trap.tscn | E_SpikeTrap | `spiketrap` | `[hazard, trap]` | Reusable spike trap hazard |
| scenes/core/prefabs/prefab_goal_zone.tscn | E_GoalZone | `goalzone` | `[objective, goal]` | Area completion objective |
| scenes/core/prefabs/prefab_door_trigger.tscn | E_DoorTrigger | `doortrigger` | `[trigger, door]` | Scene transition door; configure door_id/targets per instance |

**Gameplay scenes**

| Scene | Entity Node | entity_id | tags | Notes |
|---|---|---|---|---|
| scenes/demo/gameplay/gameplay_exterior.tscn | E_DoorTrigger | `door_to_house` | `[trigger, door]` | Transition to `interior_house` |
| scenes/demo/gameplay/gameplay_exterior.tscn | E_DeathZone | `deathzone_exterior` | `[hazard, death]` | Pit/kill floor |
| scenes/demo/gameplay/gameplay_exterior.tscn | E_SpikeTrapA / E_SpikeTrapB | `spiketrap_a` / `spiketrap_b` | `[hazard, trap]` | Dual spike traps using shared settings |
| scenes/demo/gameplay/gameplay_exterior.tscn | E_Checkpoint_SafeZone | `checkpoint_exterior` | `[checkpoint, objective]` | Exterior checkpoint near spawn |
| scenes/demo/gameplay/gameplay_exterior.tscn | E_TutorialSign | `tutorial_exterior` | `[interactable, tutorial]` | Signpost dialogue on exterior path |
| scenes/demo/gameplay/gameplay_exterior.tscn | E_FinalGoal | `finalgoal` | `[objective, endgame]` | Final victory trigger for exterior |
| scenes/demo/gameplay/gameplay_interior_house.tscn | E_DoorTrigger | `door_to_exterior` | `[trigger, door]` | Transition back to exterior |
| scenes/demo/gameplay/gameplay_interior_house.tscn | E_DeathZone | `deathzone_interior` | `[hazard, death]` | Interior pit hazard |
| scenes/demo/gameplay/gameplay_interior_house.tscn | E_GoalZone | `goalzone_interior` | `[objective, goal]` | Interior objective target |
| scenes/demo/gameplay/gameplay_interior_house.tscn | E_TutorialSign_Interior | `tutorial_interior` | `[interactable, tutorial]` | Interior signpost hint |

**Tagging strategy**
- `hazard` pairs with context tags (`death` for lethal volume, `trap` for spike traps) so systems can filter by severity.
- `objective` marks win/goal flows; combine with `goal` for standard objectives or `endgame` for final victory.
- `checkpoint` marks respawn/restore anchors; still carries `objective` for UI/state visibility.
- `trigger` + `door` marks scene transitions and keeps door queries simple (hinting + interaction prompts).
- `interactable` + `tutorial` marks non-lethal interactables (signposts) that surface tutorial text.
- `player` and `camera` remain reserved for the controllable character and active camera; treat them as unique IDs per scene.

**Implementation**: `scripts/core/ecs/base_ecs_entity.gd`, `scripts/core/managers/m_ecs_manager.gd`
**Tests**: `tests/unit/ecs/test_entity_ids.gd` (27 tests, all passing)
**Documentation**: Phase 6 of style/scene cleanup project

---

### 8.6 Manual Body Deduplication

**Resolution**: Shared helper `U_ECSUtils.map_components_by_body()` builds the mapping once, removing duplicate loops across systems.

---

## 9. Summary

### 9.1 Strengths of Current Implementation

**✓ Clean Separation**: Components store data, systems process logic
**✓ Godot Integration**: Leverages scene tree naturally
**✓ Auto-Registration**: Components self-register on scene load
**✓ Testable**: Components/systems can be unit tested
**✓ Hot-Reload Friendly**: F5 in editor re-registers everything
**✓ Discoverable**: Manager found via scene tree (no singleton)
**✓ Fail-Fast**: Asserts catch configuration errors early

### 9.2 Current Feature Set

**Implemented**:
- Component/system base classes with lifecycle management
- Manager discovery utilities (`U_ECSUtils.get_manager`, group helpers)
- Auto-registration/unregistration with validation hooks
- Multi-component entity queries with optional component support
- U_EntityQuery caching + body deduplication helpers
- Event bus (`U_ECSEventBus`) with rolling history buffer
- Priority-sorted system scheduling via `execution_priority`
- Settings resources and deep-copy snapshots for debugging
- Decoupled component architecture (no cross-component NodePaths)
- Query-driven systems: movement, jump, gravity, floating, rotate-to-input, align-to-surface, landing indicator
- **Entity IDs & tagging** (Phase 6): Unique identifiers, tag-based queries, auto-registration, state store integration

**Not Implemented (Yet)** (see [§8](#8-current-limitations)):
- ~~Explicit entity ID abstraction~~ ✅ Implemented (Phase 6)
- ~~Component tag/indexing layer~~ ✅ Implemented (Phase 6)
- Optional execution-order visualiser/debug overlay

### 9.3 Next Steps

**For Production Use**:
1. Introduce stable entity identifiers and persistence hooks.
2. Add a component tagging/indexing layer for coarse-grained queries.
3. Ship optional execution-order tooling (debug overlays or logging toggles).
4. Refresh scene templates/tutorials to highlight priority conventions.

**For Code Quality**:
1. Extend the automated API docs for query helpers and priority scheduling.
2. Add soak/performance benchmarks that churn priorities at runtime.
3. Expand unit coverage for event-driven responder systems (particles, audio, camera shake).
4. Continue enforcing deep-copy semantics for shared dictionaries/arrays.

## Physics Engine Dependency

This template uses **Jolt Physics** via the Godot Jolt addon (`addons/godot-jolt`).

**Configuration:** `project.godot` line 235:
```ini
[physics]
3d/physics_engine="Jolt Physics"
```

**For LLMs:** If generating physics-related code, assume Jolt Physics is active. Do not suggest Godot Physics-specific features unless marked as optional.

**Export Checklist:**
- ✅ `addons/godot-jolt/` must be included in export presets
- ✅ Jolt shared libraries must be packaged for target platform
- ✅ Fallback to Godot Physics requires `project.godot` change + testing

---

## 10. Current Runtime Contracts

These contracts are the active authoring rules for ECS code in this template.

### 10.1 Components

- Extend `BaseECSComponent`.
- Define `const COMPONENT_TYPE := StringName("YourComponent")` and set `component_type = COMPONENT_TYPE` in `_init()`.
- Enforce required settings/resources with `_validate_required_settings()`. Push an error and return `false` to abort registration; use `_on_required_settings_ready()` for post-validation setup.
- Prefer exported `NodePath` fields plus typed getters that use `get_node_or_null(...) as Type` and return `null` on empty paths.
- Keep call sites null-safe. Missing authored paths should disable behavior instead of erroring unless the setting is truly mandatory.
- Use `U_NodeFind.find_character_body_recursive(...)` for generic `CharacterBody3D` discovery instead of duplicating recursive body helpers.
- If exposing debug state, return deep copies with `snapshot.duplicate(true)` so callers cannot mutate component internals.
- Spawn freeze/unfreeze state lives in `C_SpawnStateComponent` (`is_physics_frozen`, `unfreeze_at_frame`, `suppress_landing_until_frame`). Movement, jump, and floating systems gate through that component.

### 10.2 Systems

- Extend `BaseECSSystem` and implement `process_tick(delta)`.
- Override `get_phase()` in every `S_*` system. `M_ECSManager` sorts by phase first, then `execution_priority`, then instance ID.
- Query through `get_components(StringName)`, dedupe by body where needed, and clamp/guard authored numeric values.
- Use `U_ECSUtils.map_components_by_body()` when multiple component arrays need the same body-keyed lookup.
- Let systems auto-discover `M_ECSManager` through parent traversal or the `ecs_manager` ServiceLocator entry; avoid manual scene wiring unless a test injects a manager.
- Event-driven request systems should extend `BaseEventVFXSystem` or `BaseEventSFXSystem` and implement `get_event_name()` plus `create_request_from_payload()`.

### 10.3 Manager

- Keep exactly one `M_ECSManager` per active gameplay scene.
- The manager registers with ServiceLocator during `_ready()`, emits component lifecycle signals, and calls `component.on_registered(self)`.
- `get_components()` strips null entries automatically; only add extra missing-component guards when behavior truly requires them.
- Entity root caching is dictionary-backed in `M_ECSManager` and `U_ECSUtils`; do not use metadata tags as hidden manager indexes.
- `BaseECSEntity` registers itself with the manager for entity lookup.

### 10.4 Entities

- Entity roots extend `BaseECSEntity`.
- `entity_id` is exported, cached after first access, and can be generated from node names for compatibility.
- Duplicate IDs receive an `_{instance_id}` suffix automatically.
- Tags are freeform `Array[StringName]`; mutate them with `add_tag(tag)`, `remove_tag(tag)`, and `has_tag(tag)` so the manager tag index stays current.
- Use `get_entity_by_id(id)`, `get_entities_by_tag(tag)`, and `get_entities_by_tags(tags, match_all)` for manager queries.

### 10.5 Channel Boundary

Per `docs/architecture/adr/0001-channel-taxonomy.md`, ECS components and systems publish gameplay events through `U_ECSEventBus`. Managers dispatch Redux actions instead, except `M_ECSManager`, which is ECS infrastructure and may publish entity registration lifecycle events.

### 9.4 Related Documentation

- **docs/systems/ecs/for_humans/ecs_ELI5.md** - Beginner-friendly explanation
- **docs/systems/ecs/for_humans/ecs_tradeoffs.md** - Pros/cons analysis
- **docs/systems/ecs/general/ecs_refactor_recommendations.md** - Improvement proposals
- **tests/unit/ecs/** - Example usage in tests

---

**End of Architecture Documentation**
