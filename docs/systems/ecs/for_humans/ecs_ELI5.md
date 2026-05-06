# ECS - Explain Like I'm 5

**Purpose**: A simple, friendly guide to understanding how our ECS (Entity-Component-System) works.

**Last Updated**: 2025-10-23

---

## What Is It? (The Simple Version)

Imagine you're building with LEGO blocks. Instead of having one giant block for each toy (a "car block", a "plane block"), you have lots of small pieces that you can mix and match:

- **Wheels** (a piece)
- **Wings** (a piece)
- **Engine** (a piece)
- **Seat** (a piece)

You can combine these pieces to make different things:
- Car = Wheels + Engine + Seat
- Plane = Wings + Engine + Seat
- Boat = Engine + Seat (no wheels or wings!)

**ECS works the same way!**

Instead of one giant "Player" script with all the code, you have small pieces:
- **Components** = LEGO pieces (data: velocity, jump_height, input)
- **Systems** = The instructions (how to move, how to jump, how to float)
- **Entities** = The complete toy (your player, enemies, objects)
- **M_ECSManager** = The LEGO instruction booklet (keeps track of all pieces)

---

## The Big Picture

```
Your Game
├─ M_ECSManager ← The LEGO Instruction Book (tracks all pieces)
│
├─ Player (Entity) ← The Complete Toy
│  ├─ C_MovementComponent ← Wheels (can move)
│  ├─ C_InputComponent ← Remote Control (player controls it)
│  ├─ C_JumpComponent ← Springs (can jump)
│  └─ C_FloatingComponent ← Balloons (can float)
│
└─ Systems ← The Instructions
   ├─ S_InputSystem ← Reads the remote control
   ├─ S_MovementSystem ← Makes the wheels turn
   ├─ S_JumpSystem ← Makes the springs bounce
   └─ S_FloatingSystem ← Makes the balloons float
```

Every frame (60 times per second):
1. **S_InputSystem** reads your controller
2. **S_MovementSystem** moves your character
3. **S_JumpSystem** makes you jump
4. **S_FloatingSystem** makes you hover

---

## The Key Players

### 1. M_ECSManager - The Instruction Book

Think of this as the **master instruction booklet** that knows where all your LEGO pieces are.

**What it does:**
- Keeps a list of all components (pieces)
- Helps systems find the pieces they need
- Makes sure pieces register when added
- Makes sure pieces unregister when removed

**Where it lives:** `scripts/core/managers/m_ecs_manager.gd`

**How to find it:**
```gdscript
# Components automatically find it when they're added to the scene
# You don't usually need to find it manually
```

### 2. Components - The LEGO Pieces

Components are like **individual LEGO pieces**. Each piece stores information but doesn't do anything on its own.

**Examples:**

**C_MovementComponent** (Wheels):
```gdscript
@export var velocity: Vector3 = Vector3.ZERO  # How fast am I moving?
@export var max_speed: float = 5.0           # What's my top speed?
@export var acceleration: float = 50.0       # How quickly do I speed up?
```

**C_InputComponent** (Remote Control):
```gdscript
@export var input_vector: Vector2 = Vector2.ZERO  # Which direction is player pressing?
@export var jump_pressed: bool = false            # Is player holding jump?
```

**C_JumpComponent** (Springs):
```gdscript
@export var jump_velocity: float = 5.0  # How high can I jump?
@export var coyote_time: float = 0.1    # How long can I jump after leaving ground?
```

**C_FloatingComponent** (Balloons):
```gdscript
@export var floating_enabled: bool = true     # Am I floating right now?
@export var floating_height: float = 1.0      # How high should I hover?
@export var floating_spring_strength: float = 10.0  # How strong is the float?
```

**Where they live:** `scripts/core/ecs/components/`

### 3. Systems - The Instructions

Systems are like **instruction manuals**. They tell the pieces what to do.

**Example: S_MovementSystem** (How to Make Wheels Turn)

```gdscript
# Every frame, this system:
# 1. Finds all movement components (wheels)
# 2. Finds all input components (remote controls)
# 3. Makes the wheels turn based on the remote control

func process_tick(delta: float):
    # Find all the wheels
    var movement_components = get_components("C_MovementComponent")

    for movement_comp in movement_components:
        # Find the matching remote control
        var input_comp = movement_comp.get_input_component()

        # If player is pressing right on the remote...
        if input_comp.input_vector.x > 0:
            # Make the wheels turn right
            movement_comp.velocity.x = movement_comp.max_speed
```

**Where they live:** `scripts/core/ecs/systems/`

### 4. Entities - The Complete Toys

Entities are like **complete toys** made from multiple pieces.

**Example: Player Entity**
```
Player (CharacterBody3D) ← This is the base toy
├─ C_MovementComponent ← Add wheels
├─ C_InputComponent ← Add remote control
├─ C_JumpComponent ← Add springs
└─ C_FloatingComponent ← Add balloons

Result: A toy that can move, jump, and float!
```

**In Godot's scene tree:**
```
CharacterBody3D (Player)
├─ C_MovementComponent (Node child)
├─ C_InputComponent (Node child)
├─ C_JumpComponent (Node child)
└─ C_FloatingComponent (Node child)
```

---

## How It Works (Step By Step)

Let's follow what happens when you press the jump button:

### Step 1: Scene Loads

```gdscript
# When you start the game:

[1] M_ECSManager appears → "I'm the instruction book!"
[2] Player entity appears → "I'm a toy!"
[3] C_JumpComponent appears → "I'm the springs! Let me register..."
[4] C_JumpComponent finds M_ECSManager → "Found the instruction book!"
[5] C_JumpComponent registers → "Instruction book, please remember me!"
[6] M_ECSManager adds to list → "Okay, I've got one C_JumpComponent"
```

### Step 2: You Press Jump

```gdscript
# Your controller sends a jump signal

[1] S_InputSystem.process_tick() runs
[2] S_InputSystem checks: Input.is_action_just_pressed("jump") → TRUE
[3] S_InputSystem finds all C_InputComponents
[4] S_InputSystem writes: input_comp.jump_pressed = true
```

### Step 3: Jump System Processes

```gdscript
# S_JumpSystem runs (every physics frame)

[1] S_JumpSystem asks manager: "Give me all C_JumpComponents"
[2] Manager responds: "Here's one!" (your player's jump component)
[3] S_JumpSystem asks jump component: "Where's your input component?"
[4] Jump component responds: "Here!" (points to C_InputComponent)
[5] S_JumpSystem checks: input_comp.jump_pressed == true → YES!
[6] S_JumpSystem checks: "Are you on the ground?" → YES!
[7] S_JumpSystem applies: body.velocity.y = jump_velocity (5.0)
[8] Result: Your character jumps!
```

### Step 4: Gravity Takes Over

```gdscript
# S_GravitySystem runs next

[1] S_GravitySystem asks manager: "Give me all C_MovementComponents"
[2] Manager responds: "Here's one!" (your player's movement component)
[3] S_GravitySystem checks: "Is this entity floating?"
[4] If NOT floating:
    S_GravitySystem applies: velocity.y += GRAVITY * delta
[5] Result: Gravity pulls you back down
```

**Visual Flow:**
```
You press jump button
        ↓
S_InputSystem detects press
        ↓
S_InputSystem writes: input_comp.jump_pressed = true
        ↓
S_JumpSystem reads: input_comp.jump_pressed
        ↓
S_JumpSystem checks: on ground? → Yes
        ↓
S_JumpSystem applies: body.velocity.y = 5.0
        ↓
Character flies upward!
        ↓
S_GravitySystem applies: velocity.y += GRAVITY
        ↓
Character falls back down
```

---

## Why We Use It (The Benefits)

### 1. Mix and Match Like LEGO

**Without ECS** (one giant block):
```gdscript
# player.gd - 1000 lines of code
func _ready():
    # Movement code
    # Jump code
    # Float code
    # Input code
    # All mixed together!
```

**With ECS** (small pieces):
```gdscript
# c_movement_component.gd - 50 lines
# c_jump_component.gd - 30 lines
# c_floating_component.gd - 40 lines
# c_input_component.gd - 20 lines

# Want a floating enemy that can't jump?
# Just use: Movement + Floating (no Jump component!)

# Want a player that can jump but not float?
# Just use: Movement + Jump + Input (no Floating component!)
```

### 2. Easy to Test

**Without ECS:**
```gdscript
# To test jumping, you need the entire player script
# That means you need movement, input, floating, everything!
```

**With ECS:**
```gdscript
# To test jumping, you only need:
# - C_JumpComponent (the piece)
# - S_JumpSystem (the instructions)
# That's it! Much simpler!
```

### 3. Easy to Change

**Want to change how jumping works?**

**Without ECS:** Find the jump code buried in 1000-line player.gd file

**With ECS:** Open `s_jump_system.gd` (100 lines), change the logic

### 4. Easy to Add Features

**Want to add wall-climbing?**

**Without ECS:** Modify player script, risk breaking existing features

**With ECS:**
1. Create `C_WallClimbComponent` (stores wall-climb data)
2. Create `S_WallClimbSystem` (handles wall-climb logic)
3. Add component to player in scene
4. Done! No existing code modified!

### 5. Easy to Remove Features

**Want to remove floating?**

**Without ECS:** Comment out code, hope you didn't break anything

**With ECS:** Delete `C_FloatingComponent` from player entity. Done!

---

## Common Patterns (How to Actually Use It)

### Pattern 1: Creating a New Component

**Step 1: Create the file**
```gdscript
# scripts/core/ecs/components/c_my_new_component.gd
extends BaseECSComponent
class_name C_MyNewComponent

const COMPONENT_TYPE := StringName("C_MyNewComponent")

# Add your data here
@export var my_value: float = 10.0
@export var my_enabled: bool = true
```

**Step 2: Add to scene**
1. Open your player scene
2. Right-click on CharacterBody3D → "Add Child Node"
3. Search for "Node" → Add
4. Attach script: `c_my_new_component.gd`
5. Set properties in inspector

**Step 3: Component automatically registers!**
```gdscript
# This happens automatically when scene loads:
# - Component finds M_ECSManager
# - Component registers with manager
# - Systems can now query for it
```

### Pattern 2: Creating a New System

**Step 1: Create the file**
```gdscript
# scripts/core/ecs/systems/s_my_new_system.gd
extends BaseECSSystem
class_name S_MyNewSystem

@export var execution_priority: int = 100  # Lower = earlier execution

func process_tick(delta: float) -> void:
    # Modern approach: Query entities with multiple components
    var entities = query_entities(
        [C_MyNewComponent.COMPONENT_TYPE],  # Required components
        []  # Optional components
    )

    # Process each entity
    for entity_query in entities:
        var my_component = entity_query.get_component(C_MyNewComponent.COMPONENT_TYPE)

        # Do something with the component
        if my_component.my_enabled:
            my_component.my_value += 1.0 * delta
```

**Step 2: Add to scene**
1. Add S_MyNewSystem node to your main scene (anywhere in tree)
2. Set `execution_priority` in inspector (lower numbers run first)
3. System automatically finds manager and registers!
4. System can now query components!

### Pattern 3: Components Working Together (Query-Based)

**Modern Pattern**: Systems use queries to find components that belong to the same entity.

**In systems:**
```gdscript
# S_MovementSystem - Query entities with BOTH Movement AND Input
func process_tick(delta: float) -> void:
    var entities = query_entities(
        [C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE],  # Both required
        [C_FloatingComponent.COMPONENT_TYPE]  # Optional floating
    )

    for entity_query in entities:
        var movement_comp = entity_query.get_component(C_MovementComponent.COMPONENT_TYPE)
        var input_comp = entity_query.get_component(C_InputComponent.COMPONENT_TYPE)
        var floating_comp = entity_query.get_component(C_FloatingComponent.COMPONENT_TYPE)  # May be null

        # All required components guaranteed non-null!
        movement_comp.velocity = input_comp.input_vector * movement_comp.max_speed

        # Optional components need null check
        if floating_comp != null:
            # Apply floating modifier...
```

**Benefits:**
- No manual wiring in inspector!
- Systems automatically find related components
- Easy to add optional components
- Components stay decoupled (no NodePath cross-references)

### Pattern 4: Settings Resources

**Step 1: Create a settings resource**
```gdscript
# scripts/core/ecs/components/floating_settings.gd
extends Resource
class_name FloatingSettings

@export var height: float = 1.0
@export var spring_strength: float = 10.0
@export var damping: float = 0.5
```

**Step 2: Use in component**
```gdscript
# In C_FloatingComponent
@export var settings: FloatingSettings

func _ready():
    super._ready()  # Register with manager
    if settings:
        floating_height = settings.height
        floating_spring_strength = settings.spring_strength
```

**Step 3: Create .tres file**
1. Right-click in FileSystem → "New Resource"
2. Search for "FloatingSettings"
3. Set values in inspector
4. Save as "floating_settings.tres"
5. Drag .tres file to component's `settings` property

### Pattern 5: Event-Driven Communication (Like Discord Channels!)

**Analogy**: Think of the Event Bus like Discord channels:
- Systems can "post messages" to channels (publish events)
- Other systems can "listen" to channels (subscribe to events)
- Systems don't need to know WHO is listening, they just broadcast

**Publishing Events** (in S_JumpSystem):
```gdscript
func process_tick(delta: float) -> void:
    # ... jump logic ...

    if player_jumped:
        # Broadcast to the "entity_jumped" channel
        U_ECSEventBus.publish("entity_jumped", {
            "entity": body,
            "velocity": jump_velocity,
            "position": body.global_position
        })
```

**Subscribing to Events** (in S_ParticleSystem):
```gdscript
func _ready():
    super._ready()

    # Listen to the "entity_jumped" channel
    U_ECSEventBus.subscribe("entity_jumped", _on_entity_jumped)

func _on_entity_jumped(event_data: Dictionary):
    # Someone jumped! Spawn particles!
    var position = event_data["position"]
    spawn_dust_particles(position)
```

**Why This Is Cool:**
```gdscript
# When player jumps, ALL these happen automatically:
# - ParticleSystem spawns dust particles
# - SoundSystem plays jump sound
# - CameraSystem adds screen shake
# - AnimationSystem plays jump animation

# JumpSystem doesn't know about ANY of these!
# Just publishes "entity_jumped" and everyone reacts!
```

**The Discord Analogy:**
```
Discord Server: "GameEvents"
├─ #entity-jumped channel
│  ├─ ParticleSystem is listening 👂
│  ├─ SoundSystem is listening 👂
│  ├─ CameraSystem is listening 👂
│  └─ AnimationSystem is listening 👂
│
├─ #entity-landed channel
│  ├─ SoundSystem is listening 👂
│  └─ ParticleSystem is listening 👂
│
└─ #entity-damaged channel
   ├─ HealthSystem is listening 👂
   ├─ VFXSystem is listening 👂
   └─ UISystem is listening 👂

When JumpSystem posts to #entity-jumped:
→ Everyone listening gets the message!
→ No one needs to know who else is listening!
→ Easy to add new listeners later!
```

**Benefits:**
- ✅ Systems don't need to know about each other
- ✅ Easy to add new reactions (just subscribe)
- ✅ No tight coupling between systems
- ✅ Emergent gameplay (fire + water = extinguish, never hardcoded!)

---

## Mental Models (Ways to Think About It)

### The Factory Floor Analogy

- **Entities** = Products being assembled (cars on assembly line)
- **Components** = Parts attached to products (wheels, engine, steering wheel)
- **M_ECSManager** = Factory inventory system (knows where all parts are)
- **Systems** = Assembly stations (Station 1: attach wheels, Station 2: install engine)

When a car (entity) moves through the factory:
1. Station 1 (S_InputSystem) reads the blueprint (input)
2. Station 2 (S_MovementSystem) attaches wheels and makes it move
3. Station 3 (S_JumpSystem) installs the suspension for jumping
4. Station 4 (S_FloatingSystem) adds hover technology

Each station only works on its specific parts. If a car doesn't have wheels (no C_MovementComponent), Station 2 skips it!

### The Orchestra Analogy

- **Entities** = Musicians (violinists, drummers, pianists)
- **Components** = Instruments (violin, drums, piano)
- **M_ECSManager** = Sheet music stand (everyone knows where to look)
- **Systems** = Conductors (one for strings, one for percussion, one for keys)

When the symphony plays:
1. String Conductor (S_MovementSystem) tells all violinists (movement components) to play
2. Percussion Conductor (S_JumpSystem) tells all drummers (jump components) to play
3. Keys Conductor (S_FloatingSystem) tells all pianists (floating components) to play

Each conductor only conducts their section. If there are no drums (no C_JumpComponent), the percussion conductor has nothing to conduct!

### The Restaurant Kitchen Analogy

- **Entities** = Orders (burger, salad, soup)
- **Components** = Ingredients on each order (bun, lettuce, tomato)
- **M_ECSManager** = Order ticket system (all orders visible to staff)
- **Systems** = Kitchen stations (grill, salad bar, soup station)

When an order comes in:
1. Prep Station (S_InputSystem) reads the order
2. Grill Station (S_MovementSystem) cooks items that need cooking
3. Salad Bar (S_JumpSystem) adds vegetables
4. Soup Station (S_FloatingSystem) prepares soup

Each station only processes orders with their ingredients. If an order has no lettuce (no C_JumpComponent), Salad Bar skips it!

---

## The Golden Rules

### Rule 1: Components Are Data Only

**BAD:**
```gdscript
# In component - NO GAME LOGIC!
func process_tick(delta):
    velocity.y += GRAVITY * delta  # This is logic, belongs in system!
```

**GOOD:**
```gdscript
# In component - ONLY DATA!
@export var velocity: Vector3 = Vector3.ZERO
@export var max_speed: float = 5.0

# In system - LOGIC GOES HERE!
func process_tick(delta):
    var movement_components = get_components(C_MovementComponent.COMPONENT_TYPE)
    for comp in movement_components:
        comp.velocity.y += GRAVITY * delta
```

**Why?** Because:
- Systems can be turned on/off independently
- Multiple systems can read same component data
- Easier to test (components are just data containers)
- Clearer separation of concerns

### Rule 2: Systems Are Stateless

**BAD:**
```gdscript
# In system - DON'T STORE STATE!
var accumulated_velocity: float = 0.0  # This breaks the pattern!

func process_tick(delta):
    accumulated_velocity += delta  # State in system = bad!
```

**GOOD:**
```gdscript
# Store state in components instead!
# In C_MovementComponent:
var accumulated_velocity: float = 0.0

# In S_MovementSystem:
func process_tick(delta):
    var components = get_components(C_MovementComponent.COMPONENT_TYPE)
    for comp in components:
        comp.accumulated_velocity += delta  # State in component = good!
```

**Why?** Because:
- Systems just process data
- All state lives in components
- Systems can be added/removed without losing state
- Multiple entities can use same system

### Rule 3: Components Register Automatically

**You DON'T need to do this:**
```gdscript
# In component - DON'T MANUALLY REGISTER!
func _ready():
    var manager = find_manager_somehow()
    manager.register_component(self)  # You don't need this!
```

**It happens automatically:**
```gdscript
# In ECSComponent base class (already done for you):
func _ready():
    _manager = _locate_manager()  # Finds manager automatically
    if _manager:
        _manager.register_component(self)  # Registers automatically
```

**Just add component to scene, and it registers itself!**

### Rule 4: One M_ECSManager Per Scene

There should only be ONE manager in your scene.

```gdscript
# M_ECSManager checks this automatically:
func _ready():
    var existing = get_tree().get_nodes_in_group("ecs_manager")
    if existing.size() > 1:
        push_error("Multiple M_ECSManager instances found!")
        queue_free()  # Remove duplicate
```

**Why?** Because:
- One source of truth for all components
- Avoids confusion (which manager has my component?)
- Simpler to reason about

### Rule 5: Systems Query Every Frame

**Pattern:**
```gdscript
# Systems query components EVERY frame
func process_tick(delta: float):
    var components = get_components(C_MovementComponent.COMPONENT_TYPE)
    # Process components...
```

**Don't cache component arrays:**
```gdscript
# BAD - Don't do this!
var cached_components: Array = []

func _ready():
    cached_components = get_components(C_MovementComponent.COMPONENT_TYPE)

func process_tick(delta):
    for comp in cached_components:  # Components might be added/removed!
        # This can break if components change
```

**Why?** Because:
- Components can be added/removed at runtime
- Querying is fast (Dictionary lookup)
- Always get up-to-date component list

---

## Quick Reference

### How to Get the Manager

```gdscript
# You usually don't need to - components/systems find it automatically!
# But if you do:
var manager = get_tree().get_nodes_in_group("ecs_manager")[0]
```

### How to Query Components (Modern Approach)

```gdscript
# In a system - Query entities with multiple components:
var entities = query_entities(
    [C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE],  # Required
    [C_FloatingComponent.COMPONENT_TYPE]  # Optional
)

for entity_query in entities:
    var movement = entity_query.get_component(C_MovementComponent.COMPONENT_TYPE)
    var input = entity_query.get_component(C_InputComponent.COMPONENT_TYPE)
    var floating = entity_query.get_component(C_FloatingComponent.COMPONENT_TYPE)  # May be null

    # All required components guaranteed non-null!
    # Use components...
```

### How to Access Component Data

```gdscript
# In a system:
var component = # ... found from manager

# Read data
var current_velocity = component.velocity

# Write data
component.velocity = Vector3(1, 0, 0)
```

### How to Publish and Subscribe to Events

```gdscript
# Publishing (in any system):
U_ECSEventBus.publish("entity_jumped", {
    "entity": body,
    "velocity": velocity,
    "position": body.global_position
})

# Subscribing (usually in _ready):
func _ready():
    super._ready()
    U_ECSEventBus.subscribe("entity_jumped", _on_entity_jumped)

func _on_entity_jumped(event_data: Dictionary):
    var entity = event_data["entity"]
    var position = event_data["position"]
    # React to the event...
```

### Component Naming Convention

```
c_<name>_component.gd

Examples:
- c_movement_component.gd
- c_input_component.gd
- c_jump_component.gd
- c_floating_component.gd
```

### System Naming Convention

```
s_<name>_system.gd

Examples:
- s_movement_system.gd
- s_input_system.gd
- s_jump_system.gd
- s_floating_system.gd
```

---

## Common Questions

### Q: Do I have to use ECS for everything?

**A:** No! Use ECS for:
- Things that need to be mixed and matched (movement, jumping, floating)
- Things that appear on multiple entity types (health, damage, inventory)
- Complex gameplay systems (combat, AI, status effects)

Don't use ECS for:
- One-off UI elements (pause menu button)
- Simple scripts (camera follow, door open/close)
- Things that never change (static scenery)

### Q: Why can't components just do their own logic?

**A:** They could, but then:
- You can't turn off features without deleting components
- Hard to add new features that interact with existing ones
- Systems can't coordinate multiple components
- Testing becomes harder (need full entity setup)

### Q: What if I need to access a component from another component?

**A:** You don't! Components should NEVER talk to each other directly. Instead:
1. Systems query entities with multiple components
2. Systems coordinate the interaction
3. Systems write results back to components

**Example:**
```gdscript
# WRONG - Component talking to component
# In C_MovementComponent:
func process_tick(delta):
    var input_comp = get_input_component()  # Components shouldn't know about each other!
    velocity = input_comp.input_vector * max_speed  # NO!

# RIGHT - System queries and coordinates
# In S_MovementSystem:
func process_tick(delta):
    var entities = query_entities(
        [C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE]
    )

    for entity_query in entities:
        var movement = entity_query.get_component(C_MovementComponent.COMPONENT_TYPE)
        var input = entity_query.get_component(C_InputComponent.COMPONENT_TYPE)
        movement.velocity = input.input_vector * movement.max_speed  # YES!
```

### Q: Can I have multiple systems processing the same component?

**A:** Yes! That's a strength of ECS!

**Example:**
- `S_MovementSystem` moves based on input
- `S_GravitySystem` applies gravity to velocity
- `S_FloatingSystem` overrides velocity when floating

All three systems work with `C_MovementComponent.velocity`!

### Q: What if my system needs to run in a specific order?

**A:** Use the `execution_priority` property! Lower numbers run first:

```gdscript
# In your system
@export var execution_priority: int = 50  # Lower = earlier

# Recommended priority bands:
# 0-9:     Input capture (S_InputSystem)
# 40-69:   Core motion (S_JumpSystem, S_MovementSystem)
# 70-109:  Post-motion (S_FloatingSystem, S_RotateToInputSystem)
# 110-199: Feedback (S_LandingIndicatorSystem)
```

The manager automatically runs systems in priority order every frame!

### Q: How do I debug ECS?

**A:** Several ways:
1. **Print component data:**
   ```gdscript
   print("Velocity: ", movement_comp.velocity)
   ```

2. **Use debug snapshots:**
   ```gdscript
   # In floating component:
   print(floating_comp._debug_snapshot)
   ```

3. **Check registered components:**
   ```gdscript
   var manager = get_tree().get_nodes_in_group("ecs_manager")[0]
   var floating_components = manager.get_components("C_FloatingComponent")
   print("Found ", floating_components.size(), " floating components")
   ```

4. **Breakpoints in systems:**
   Set breakpoints in system `process_tick()` to inspect component state

---

## Summary

ECS is like **LEGO for game code**:

- **Entities** = Complete toys (player, enemies, objects)
- **Components** = LEGO pieces (movement, jump, float, input)
- **Systems** = Instructions (how to move, how to jump, how to float)
- **M_ECSManager** = Instruction booklet (tracks all pieces)

**The Pattern:**
1. Create components (data pieces)
2. Create systems (logic processors)
3. Add components to entities in scene
4. Systems query entities and process them every frame
5. Systems publish events for cross-system communication

**Benefits:**
- ✅ Mix and match features like LEGO
- ✅ Easy to test (small pieces)
- ✅ Easy to add features (new component + system)
- ✅ Easy to remove features (delete component)
- ✅ Easy to understand (clear separation)
- ✅ Emergent gameplay (systems react to events)

**Remember:**
- Components = Data only (no logic!)
- Systems = Logic only (no state!)
- Components register automatically
- Systems query entities with multiple components
- Systems communicate via events (pub/sub)
- One manager per scene
- Execution priority controls system order

---

## Next Steps

Want to learn more? Check out:

- **docs/ecs/ecs_architecture.md** - Detailed technical architecture
- **docs/ecs/for humans/ecs_tradeoffs.md** - Pros and cons analysis
- **docs/ecs/refactor recommendations/ecs_refactor_recommendations.md** - Improvement proposals
- **scripts/core/ecs/** - Actual implementation files
- **tests/unit/ecs/** - Example usage in tests

**Happy coding!**
