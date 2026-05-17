# Three.js Frontend + Rust Backend Port Design

**Date:** 2026-05-17
**Status:** Approved

## 1. Overview

Port the Automata 2.5D game template from Godot 4.7 (GDScript) to a **Bevy ECS + Lua scripting + Three.js renderer** stack. Bevy owns the tick loop, runs the scheduler, and calls Lua systems as callbacks — matching the industry standard pattern (Unity/Godot/Unreal) where the engine drives and scripts react.

### 1.1 Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Architecture | Bevy drives, Lua reacts | Bevy App owns the tick loop and scheduler; Lua systems are called as script callbacks from Bevy wrapper systems; any Bevy crate drops in with zero bridge code |
| Tick loop owner | Bevy App + scheduler | Bevy runs the fixed timestep, orders systems, manages change detection — matching Unity/Godot industry standard |
| Event bus | Bevy `EventWriter<T>` / `EventReader<T>` | Typed events, double-buffered, routed to Lua subscribers |
| Entity store | Bevy `World` | Archetype storage, fast queries, change detection |
| Physics | `bevy_rapier3d` plugin | RigidBody/Collider as Bevy components; collision events as Bevy events; 0 lines of physics bridge code |
| Offline mode | Tauri desktop app | Bevy App + Lua runs natively in-process; Three.js webview renders |
| Web deployment | Online-only via WebSocket | Headless Bevy App (MinimalPlugins) serves browser clients |
| Player count | Single-player, multiplayer supported | Per-client connection state in Bevy resources |
| Sync protocol | Server → client: snapshots + events; Client → server: inputs | Thin client — no prediction, no reconciliation |
| Milestones | Split: Core → UI/Settings → Polish | Core 2.5D gameplay loop ships first |
| Manager count | All 20 managers preserved | Architectural continuity with Godot template |
| Rust compilation | Single native target | No WASM; same binary for Tauri and headless server |
| Bevy footprint | bevy_app + bevy_rapier3d + bevy_asset + bevy_input (~150-200 crates) | Any Bevy plugin works: `bevy_tweening`, `bevy_mod_picking`, `bevy_inspector_egui`, etc. |
| Config/systems format | Lua + JSON | Hot-reloadable game logic; JSON for entity/room/component definitions |

## 2. Tech Stack

### 2.1 Rust Engine Core

Bevy App owns the scheduler, World, events, and the fixed timestep loop. Lua runs inside Bevy systems as a scripting callback layer.

| Concern | Choice | Purpose |
|---|---|---|
| App framework | **bevy_app** (MinimalPlugins) | Scheduler, startup/shutdown, plugin system, headless mode for server |
| ECS | **bevy_ecs::World + Commands + Query** | Archetype storage, change detection, parallel query iteration |
| Physics | **bevy_rapier3d** | RigidBody/Collider/Velocity as Bevy components; collision events as Bevy events; RapierContext for queries |
| Events | **bevy_ecs Events** | Typed EventWriter/EventReader routed to Lua subscribers |
| Input | **bevy_input** | KeyCode, GamepadButton, GamepadAxis enums; Input<T> resource |
| Asset pipeline | **bevy_asset** | Hot-reload textures, GLB meshes, JSON, sprite sheets at runtime |
| Lua runtime | **mlua** | Safe Rust ↔ Lua bridge; serde integration for table ↔ struct round-trips |
| Networking | **tokio + tungstenite** | Async WebSocket server (active in server mode) |
| Serialization | **serde + bincode** | Compact binary snapshot/event encoding |
| Entity configuration | Lua tables via mlua | Spawn entities, configure components from Lua/JSON definitions |
| Time | **bevy_time** | Fixed timestep at 30 Hz; delta exposed to Lua systems |

### 2.2 Deployment Targets (same Rust binary)

| Target | Engine | Client | Use case |
|---|---|---|---|
| **Tauri desktop app** | Bevy App (MinimalPlugins) in-process | Tauri webview + Three.js, IPC bridge | Offline single-player |
| **Headless server** | Bevy App (MinimalPlugins, no windowing) standalone | Browser → WebSocket → server | Online single-player / multiplayer |

### 2.3 Client (TypeScript + Three.js)

Same client code runs in both browser and Tauri webview.

| Concern | Choice | Purpose |
|---|---|---|
| 3D rendering | **Three.js** (WebGPURenderer) | Sprite billboarding, camera controls, mesh rendering |
| UI framework | **React** | Menu/overlay/settings component tree |
| UI state | **Zustand** | Redux-like UI state |
| Desktop shell | **Tauri v2** | Webview host, IPC bridge to Bevy, native FS access |
| Build | **Vite** | Fast HMR, TS-native |
| Transport adapter | `WebSocketTransport` / `TauriTransport` | Same `ITransport` interface, swapped per deployment |

## 3. Architecture: Bevy Drives, Lua Reacts

### 3.1 Tick Loop (Bevy-owned)

```
Bevy App (30 Hz fixed timestep)         Lua Scripts (react)
────────────────────────────────────    ────────────────────────────
                                       
PreUpdate schedule:                     
  ├─ flush_input_queue         ←──     (transport → Bevy World)
  └─ s_lua_input_capture       ──→     Lua: S_InputCapture:process()
                                        reads Input<KeyCode> via engine:get_input()
                                        writes InputComponent to entities
                                       
Update schedule:                        
  ├─ s_lua_movement            ──→     Lua: S_Movement:process(dt)
  ├─ s_lua_jump                ──→     Lua: S_Jump:process(dt)
  ├─ s_lua_gravity             ──→     Lua: S_Gravity:process(dt)
  └─ ... (all gameplay systems)        
                                       
  │ Bevy Rapier3D physics step auto-runs between Update and PostUpdate
  │ RigidBody velocity → Transform sync is automatic
  │ CollisionEvent/ContactForceEvent auto-emitted
                                       
PostUpdate schedule:                    
  ├─ s_lua_align_surface       ──→     Lua: S_AlignSurface:process(dt)
  ├─ s_lua_direction_facing    ──→     Lua: S_DirectionFacing:process(dt)
  ├─ s_lua_vfx_emitter         ──→     Lua: S_VfxEmitter:process(dt)
  ├─ s_lua_audio_emitter       ──→     Lua: S_AudioEmitter:process(dt)
  │                                     
  ├─ emit_snapshot             ←──     Query<&Transform> → serialize → transport
  └─ emit_client_events        ←──     Drain Bevy events → serialize → transport
```

Key difference from Godot: **Bevy runs physics between Update and PostUpdate automatically.** Lua systems don't call `physics_step()` — they just apply forces/move bodies in Update, read positions in PostUpdate.

### 3.2 Bevy SystemSet Structure

```
#[derive(SystemSet, Debug, Clone, PartialEq, Eq, Hash)]
enum GameSystemSet {
    InputCapture,      // Priority 0-9 equivalent
    PrePhysics,        // Priority 10-39
    CoreMotion,        // Priority 40-69 (before physics)
    PostMotion,        // Priority 70-109 (after physics)
    Feedback,          // Priority 110-199
    Diagnostics,       // Priority 200+
}

app.configure_sets(Update,
    InputCapture
        .before(PrePhysics),
    PrePhysics
        .before(CoreMotion),
    CoreMotion
        .before(bevy_rapier3d::PhysicsSet::StepSimulation),
    PostMotion
        .after(bevy_rapier3d::PhysicsSet::StepSimulation)
        .before(Feedback),
    Feedback
        .before(Diagnostics),
);
```

Each Lua system has a Rust wrapper registered into the appropriate set:

```rust
fn s_movement_wrapper(world: &mut World) {
    // Lua system dispatch — calls S_Movement:process(dt)
    let lua = world.resource::<LuaRuntime>();
    lua.call_system("S_Movement", world);
}
```

### 3.3 Per-Room System Toggles

Rooms enable/disable Lua systems via a `RoomSystems` Bevy resource. Each Lua wrapper function checks the resource before calling into Lua:

```rust
fn s_floating_wrapper(world: &mut World) {
    let enabled = world.resource::<RoomSystems>().is_enabled("S_Floating");
    if !enabled { return; }
    world.resource::<LuaRuntime>().call_system("S_Floating", world);
}
```

```json
// room JSON
{
  "systems": {
    "enabled": ["S_InputCapture", "S_Movement", "S_Jump", "S_Gravity"],
    "disabled": ["S_Floating"]
  }
}
```

### 3.4 Engine API Surface (exposed to Lua via mlua)

```lua
-- Entity CRUD (backed by Bevy World)
entity_id = engine:spawn(config)
engine:despawn(entity_id)
exists = engine:entity_exists(entity_id)

-- Component access
data = engine:get(entity_id, "Movement")
engine:set(entity_id, "Movement", { speed = 5.0 })
engine:remove(entity_id, "Movement")

-- Batch entity iteration (Bevy Query)
engine:query({"Movement", "Jump"}, function(eid)
  local m = engine:get(eid, "Movement")
end)

-- Events (Bevy EventWriter/Reader)
engine:emit("EntityJumped", { entity = id, velocity = 8.0 })
engine:on("EntityJumped", function(event) ... end)
engine:off("EntityJumped")

-- Physics (auto — RigidBody is a component)
engine:apply_impulse(entity_id, {x=0, y=10, z=0})
engine:set_linear_velocity(entity_id, {x=5, y=0, z=0})
pos = engine:get_component(entity_id, "Transform")  -- post-physics position
vel = engine:get_component(entity_id, "Velocity")   -- current velocity
result = engine:raycast(origin, direction, max_dist) → {hit, point, entity_id}

-- Collision events (auto-subscribed — Bevy rapier events route to Lua)
engine:on("CollisionStarted", function(event)
  local a = event.entity_a
  local b = event.entity_b
end)

-- Input (bevy_input)
kb = engine:get_input()          -- currently pressed keys/gamepad buttons
held = engine:is_key_held("Space")
just = engine:is_key_just_pressed("Space")

-- State (Bevy Resources)
engine:get_state(key)
engine:set_state(key, value)
engine:dispatch_action(action_table)

-- Time (bevy_time)
dt = engine:delta_time()
engine:set_time_scale(scale)

-- File I/O
engine:save_snapshot(path)
engine:load_snapshot(path)
data = engine:load_json(path)

-- Hot-reload (bevy_asset)
engine:reload_systems()    -- recompiles Lua files without restarting
```

### 3.5 Bevy Components as Lua Tables

Components are Rust structs (for Bevy's type system) serialized to Lua tables:

```rust
#[derive(Component, Serialize, Deserialize)]
struct Movement {
    speed: f32,
    turn_rate: f32,
    direction: u8,
}
```

```lua
-- Lua side — same data
engine:set(entity_id, "Movement", { speed = 5.0, turn_rate = 720.0, direction = 0 })
local m = engine:get(entity_id, "Movement")
```

**Physics components are Bevy components** — no manual handle bookkeeping:

```lua
-- RigidBody, Collider, Velocity are regular components
engine:spawn({
  type = "PhysicsBody",
  components = {
    Movement = { speed = 5.0 },
    RigidBody = { kind = "Dynamic" },
    Collider = { shape = "Capsule", radius = 0.18, height = 0.5 },
    Transform = { translation = {x=0, y=0, z=0} },
  }
})

-- Post-physics, position is auto-updated
-- Collision events auto-emitted — no custom bridge
```

### 3.6 Bevy Events as Lua Pub/Sub

```rust
// Rust side — any Bevy Event type
#[derive(Event, Serialize)]
struct EntityJumpedEvent {
    entity: u64,
    velocity: f32,
}

// bevy_rapier3d events are auto-routed to Lua:
// CollisionEvent, ContactForceEvent — already exist
```

```lua
-- Lua subscribes same way for any event type
engine:on("EntityJumped", function(event) ... end)
engine:on("CollisionEvent", function(event)
  if event.started then
    -- collision started between event.entity_a and event.entity_b
  end
end)

engine:emit("EntityJumped", { entity = 42, velocity = 8.0 })
```

### 3.7 Lua File Structure

```
lua/
├── init.lua              -- bootstrap, register systems, subscribe to events
├── components/
│   ├── movement.lua      -- Movement defaults
│   ├── health.lua        -- Health defaults
│   ├── jump.lua          -- Jump defaults
│   └── ...
├── systems/
│   ├── s_input_capture.lua       -- InputCapture set
│   ├── s_movement.lua            -- PrePhysics set
│   ├── s_jump.lua                -- CoreMotion set
│   ├── s_gravity.lua             -- CoreMotion set
│   ├── s_align_surface.lua       -- PostMotion set
│   ├── s_direction_facing.lua    -- PostMotion set
│   ├── s_vfx_emitter.lua         -- Feedback set
│   ├── s_audio_emitter.lua       -- Feedback set
│   └── ...
├── entities/
│   ├── player.lua        -- Player entity config
│   ├── npc.lua           -- NPC entity config
│   └── ...
├── rooms/
│   ├── demo_room_01.json -- Room definition
│   └── ...
├── managers/
│   ├── m_spawn_manager.lua
│   ├── m_objectives_manager.lua
│   └── ...
└── config/
    ├── systems.toml      -- System registration manifest (Bevy SystemSet + lua file)
    └── constants.json    -- Scale contract, physics constants
```

## 4. System Registration (Bevy SystemSets)

Systems register via a manifest that maps Lua files to Bevy SystemSets:

```toml
# config/systems.toml
[systems.S_InputCapture]
lua_file = "systems/s_input_capture.lua"
system_set = "InputCapture"
priority = 5

[systems.S_Movement]
lua_file = "systems/s_movement.lua"
system_set = "PrePhysics"
priority = 30

[systems.S_Jump]
lua_file = "systems/s_jump.lua"
system_set = "CoreMotion"
priority = 45

[systems.S_Gravity]
lua_file = "systems/s_gravity.lua"
system_set = "CoreMotion"
priority = 50

[systems.S_AlignSurface]
lua_file = "systems/s_align_surface.lua"
system_set = "PostMotion"
priority = 80

[systems.S_DirectionFacing]
lua_file = "systems/s_direction_facing.lua"
system_set = "PostMotion"
priority = 90

[systems.S_VfxEmitter]
lua_file = "systems/s_vfx_emitter.lua"
system_set = "Feedback"
priority = 120

[systems.S_AudioEmitter]
lua_file = "systems/s_audio_emitter.lua"
system_set = "Feedback"
priority = 130
```

On startup, Bevy reads this manifest and registers one Rust wrapper function per system into the appropriate SystemSet. Bevy auto-parallelizes systems in different sets that don't conflict on component access.

### 4.1 System Priority Bands

| Bevy SystemSet | Old Priority | Purpose | Physics relation |
|---|---|---|---|
| `InputCapture` | 0-9 | Read inputs, write InputComponent | Before everything |
| `PrePhysics` | 10-39 | Derive movement intent, compute velocities | Before physics |
| `CoreMotion` | 40-69 | Apply impulses, set velocities | Before physics step |
| (Physics auto-runs here) | — | Rapier3D integration, collision detection | Bevy Rapier3D StepSimulation |
| `PostMotion` | 70-109 | Read transforms, align surface, update facing | After physics |
| `Feedback` | 110-199 | Emit VFX/audio events, update state | After PostMotion |
| `Diagnostics` | 200+ | Logging, metrics | After everything |

### 4.2 System Interface

```lua
-- Every Lua system implements this interface
local S_Movement = {}

function S_Movement:init(engine)
  -- Called once on startup. Register event listeners, load config.
end

function S_Movement:process(engine, dt)
  -- Called every tick from Bevy wrapper.
  -- engine:query() runs a Bevy Query under the hood.
  -- engine:apply_impulse() modifies Rapier RigidBody.
  
  engine:query({"Movement", "InputComponent", "RigidBody"}, function(eid)
    local movement = engine:get(eid, "Movement")
    local input = engine:get(eid, "InputComponent")
    
    -- Compute force from input direction and speed
    -- Apply via Rapier
    engine:set_linear_velocity(eid, { 
      x = input.move_x * movement.speed, 
      y = 0, 
      z = input.move_y * movement.speed 
    })
  end)
end

return S_Movement
```

## 5. Manager Migration

All 20 managers preserved. Bevy handles entity storage, physics, events, scheduling. Lua handles gameplay logic. TypeScript handles rendering.

### 5.1 Bevy-side Managers (Rust)

| Godot Manager | Bevy Implementation | Notes |
|---|---|---|
| `M_ECSManager` | bevy_ecs::World + App + Schedule | Zero custom code |
| `M_StateStore` | Bevy Resources + reducer systems | `dispatch_action()` exposed to Lua |
| `M_SaveManager` | `engine:save_snapshot()` / `engine:load_snapshot()` | Serializes World entities + Lua state |
| `M_TimeManager` | bevy_time::Time<Fixed> | 30 Hz fixed timestep; exposed via `engine:delta_time()` |
| `M_SceneDirectorManager` | Scene transition resource | Lua calls `engine:load_room()` → despawns/spawns entities |
| `M_RunCoordinatorManager` | Run state Bevy Resource | Playthrough metadata |
| `M_InputProfileManager` | bevy_input + binding config | Input bindings as Bevy resource |
| `M_AudioManager` | Audio event publisher | Routes AudioEvent to transport |
| `M_InputDeviceManager` | bevy_input | KeyCode, Gamepad enums auto-tracked |
| `M_CharacterLightingManager` | Per-entity lighting resource | Emits light config events to transport |
| `U_ServiceLocator` | Bevy World as registry | All services via `engine.*` in Lua |

### 5.2 Lua-side Managers (Gameplay Logic)

| Godot Manager | Lua Implementation | Notes |
|---|---|---|
| `M_SpawnManager` | Lua spawn system | Reads room JSON spawn_points; calls `engine:spawn()` |
| `M_ObjectivesManager` | Lua objectives module | Victory/defeat checks; emits events |
| `M_GameplayInitializerManager` | Room load hook | Room JSON → spawn entities, set initial state |
| `M_CheckpointManager` | Lua checkpoint system | Triggers → save → emit events |
| `M_VFXManager` | VFX event emitter in Lua | Emits VfxSpawn events to transport |
| `M_VCamManager` | vCam state emitter | Emits camera priority/blend events to transport |

### 5.3 Rendering-side Managers (TypeScript)

| Godot Manager | TS Implementation | Receives from engine |
|---|---|---|
| `M_CameraManager` | Three.js Camera + orbit controls | Camera state events |
| `M_AudioManager` | Web Audio API / Howler.js | Audio events |
| `M_VFXManager` | Three.js particle systems | VFX spawn events |
| `M_DisplayManager` | Browser resize + CSS | N/A (local) |
| `M_CursorManager` | CSS cursor + pointer lock | N/A (local) |
| `M_ScreenshotCacheManager` | Canvas toDataURL() | N/A (local) |
| `M_LocalizationManager` | i18n library | N/A (local) |
| `M_SceneManager` | Route-based UI manager | Scene transition events |

## 6. Client/Server Boundary

### 6.1 Architecture Mode Switch

```
┌────────────────────────────────────────────────────────────────────┐
│                    Rust Engine Binary                              │
│  Bevy App (MinimalPlugins) + bevy_rapier3d + bevy_asset + mlua    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Lua Runtime (mlua)                                           │  │
│  │ Systems called from Bevy wrappers; entity configs; rooms     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────┐  ┌──────────────────────────────────┐   │
│  │ Tauri Mode           │  │ Server Mode                      │   │
│  │ Bevy App in-process  │  │ Bevy App standalone              │   │
│  │ IPC → webview        │  │ WebSocket → browser clients      │   │
│  └──────────────────────┘  └──────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

### 6.2 Tauri (Offline Desktop)

```
Tauri Webview (Three.js + React)        Bevy App (MinimalPlugins in-process)
─────────────────────────────────       ─────────────────────────────────────
Input capture (keyboard/gamepad)        Bevy scheduler runs at 30 Hz
  │                                      │
  ├── invoke("send_input", inputs) ──→  PreUpdate: flush input queue
  │                                      Update: Lua systems run (PrePhysics, CoreMotion)
  │                                      bevy_rapier3d: physics step
  │                                      PostUpdate: Lua systems run (PostMotion, Feedback)
  │                                      PostUpdate: emit_snapshot, emit_client_events
  │                                      │
  │ ←── event "sync" ────────────────── Transport serializes to IPC
  │                                      │
Render frame (60 fps)
  Interpolate between snapshots
  Update sprite positions/directions
  Play VFX/audio from events

IPC latency: ~0ms (in-process)
```

### 6.3 Server (Online Browser)

```
Browser (Three.js + React)              Server (Bevy App headless)
─────────────────────────────────       ─────────────────────────────
Input capture (keyboard/gamepad)        Same Bevy schedule as Tauri mode
  │                                      │
  ├── WebSocket send(inputs) ─────────→ PreUpdate: flush input queue
  │                   (tick-stamped)     (same Lua systems, same physics)
  │                                      │
  │ ←── WebSocket receive(msg) ──────── PostUpdate: serialize snaps+events
  │                                      │
Render frame (60 fps)
  Interpolate (2-tick jitter buffer)

Network target: playable ≤150ms RTT, native feel ≤50ms RTT
No client prediction — thin renderer model
```

### 6.4 Tick Rates

```
Bevy fixed timestep:  30 Hz (33ms)    — same across both modes
Client render:         60 fps          — requestAnimationFrame
Input send:            60 Hz           — captured every frame
Snapshot rate:         30 Hz           — one per Bevy tick
Event rate:            per-tick        — batched with snapshot
```

### 6.5 Sync Protocol

```
Client → Engine:
  { tick: u32, inputs: { move: Vec2, jump: bool, sprint: bool } }

Engine → Client:
  Snapshot: { tick: u32, entities: [{ id, pos: Vec3, rotation, state, direction, ... }] }
  Events:   { tick: u32, events: [EntityJumped { id }, VfxSpawn { type, pos },
             AudioEvent { type, entity_id }, UIStateChange { key, value }, ...] }
```

### 6.6 Transport Adapter

```typescript
interface ITransport {
  send(data: ClientInput): void;
  onMessage(callback: (msg: ServerMessage) => void): void;
  connect(): Promise<void>;
  disconnect(): void;
}

class WebSocketTransport implements ITransport { /* native WebSocket */ }
class TauriTransport implements ITransport { /* tauri invoke() + event listen */ }
```

### 6.7 Client Responsibilities

The client has **no ECS, no game logic, no physics**. It is:

1. **Input capturer:** Keyboard, gamepad, touch → tick-stamped messages
2. **Snapshot consumer:** Interpolate entity positions between ticks
3. **Sprite renderer:** `THREE.Sprite` positions, UV offsets for direction/animation
4. **Event consumer:** VFX particles, audio, UI state
5. **Camera controller:** Free yaw at -30° pitch, wall cutout raycasting
6. **UI host:** React menus/overlays/HUD, Zustand state

## 7. 2.5D Rendering in Three.js

### 7.1 Core Approach

- **Sprite billboards:** `THREE.Sprite` with sprite sheet textures (8-direction + animation frames)
- **Camera:** `PerspectiveCamera`, orbit around room center, pitch locked at -30°, yaw freely rotatable
- **Direction facing:** UV offset on sprite material (`offset.x = direction_index / 8`)
- **Camera-relative movement:** Lua computes `movement = cameraBasis * inputVector`, identical to Godot pattern
- **Renderer:** `WebGPURenderer` (Three.js r163+)

### 7.2 Scale Contract (Preserved from Godot)

```
1 tile         = 1 Three.js unit
128px sprite   = 0.5 units wide/tall
Player radius  = 0.18 units
Player height  = 0.5 units
Wall height    = 3.0 units
Camera orbit   = 4.0 units
Camera pitch   = -30 degrees
```

### 7.3 Directional Sprite System

```
Sprite sheet: 8 columns (directions) × N rows (animation frames)
Column index:  0=S, 1=SW, 2=W, 3=NW, 4=N, 5=NE, 6=E, 7=SE (clockwise)
UV offset.x = direction_index / 8.0
UV offset.y = frame_index / total_frames (animated per render frame)

Facing priority: movement vector → interaction target → cutscene override
```

### 7.4 Wall Occlusion

1. Each render frame, raycast from camera to player position
2. Collect all Wall entities intersecting the ray path
3. Fade intersecting walls to ~20% opacity
4. Restore to 100% when no longer obstructing
5. Animate opacity transitions (0.15s lerp)

### 7.5 Scene Graph

```
Scene
├── Room (Group)
│   ├── Floor mesh (textured PlaneGeometry)
│   ├── Wall meshes (BoxGeometry, textured) — opacity for cutouts
│   ├── Decorations (static meshes, imported glTF/glb)
│   └── Triggers (invisible Box3 collider meshes)
├── Entity Sprites (Group)
│   ├── E_Player → Sprite (8-dir sheet, billboarded)
│   │   ├── VFX particles (child Points/ParticleSystem)
│   │   └── Shadow disc (child Sprite, flat on floor)
│   ├── E_NPC_1 → Sprite
│   └── E_NPC_2 → Sprite
├── Camera (PerspectiveCamera)
│   ├── Orbital pivot around room center
│   └── Pitch locked at -30°, yaw freely rotatable
└── Lights
    ├── AmbientLight (scene-wide)
    └── DirectionalLight (per-character)
```

### 7.6 Performance

- 50-200 sprite billboards at 60fps: trivial for Three.js WebGPU
- Bevy `Query<&Transform>` for snapshots: <100μs for 200 entities
- Lua system dispatch at 30 Hz for ~29 systems: <1ms
- Bevy auto-parallelizes non-conflicting systems across CPU cores

## 8. Scene Pipeline & Content Authoring

### 8.1 Room Definition Format (JSON)

```json
{
  "room_id": "demo_room_01",
  "geometry": {
    "floor": "assets/rooms/demo_floor.glb",
    "walls": ["assets/rooms/wall_north.glb", "assets/rooms/wall_east.glb"],
    "decorations": ["assets/rooms/barrel_01.glb"]
  },
  "entities": [
    { "type": "Player", "pos": [2, 0, 3], "facing": 2 },
    { "type": "NPC", "pos": [5, 0, 1], "facing": 6 }
  ],
  "triggers": [
    { "type": "VictoryTrigger", "bounds": { "min": [8, 0, 8], "max": [10, 2, 10] } },
    { "type": "Checkpoint", "pos": [4, 0, 4] }
  ],
  "spawn_points": [
    { "id": "spawn_1", "pos": [1, 0, 2], "facing": 2 }
  ],
  "lighting": {
    "ambient": [0.3, 0.3, 0.4],
    "directional": { "color": [1, 0.8, 0.6], "direction": [-0.5, -1, -0.5] }
  },
  "camera": {
    "orbit_center": [5, 1, 5],
    "bounds": { "min": [-5, -5], "max": [15, 15] }
  },
  "occlusion_walls": ["wall_north", "wall_east"],
  "systems": {
    "enabled": ["S_InputCapture", "S_Movement", "S_Jump", "S_Gravity"],
    "disabled": ["S_Floating"]
  }
}
```

### 8.2 Entity Configuration (Lua)

```lua
-- lua/entities/player.lua
return {
  type = "Player",
  components = {
    Movement = { speed = 5.0, turn_rate = 720.0 },
    Jump = { force = 8.0, coyote_time = 0.1 },
    Health = { max = 100, current = 100 },
    PlayerTag = {},
    RigidBody = { kind = "Dynamic" },
    Collider = { shape = "Capsule", radius = 0.18, height = 0.5 },
  }
}
```

### 8.3 Pipeline Flow

```
Room JSON + Entity Lua → loaded into Bevy World via bevy_asset →
  Lua:room_init() → engine:spawn(config) for each entity →
  Bevy inserts components + Rapier creates rigid bodies →
  RoomSystems resource: enable room-specific systems →
  engine broadcasts initial snapshot (Query<&Transform>) →
  client creates Three.js meshes from geometry references
```

### 8.4 Scene Transition

```
Player triggers door → SceneDirector validates →
  Lua:room_unload() (cleanup, save checkpoint) →
  Bevy World despawns entities (Rapier bodies auto-removed) →
  Bevy World loads new room JSON →
  Lua:room_init() → spawn entities, set RoomSystems →
  engine broadcasts initial world snapshot →
  client: transition event → loading screen → new snapshot → render room
```

## 9. UI System

### 9.1 Framework: React + HTML/CSS

Same widget decomposition philosophy as Godot — small, single-responsibility components, thin controllers (~40-80 lines), isolated per-widget tests.

### 9.2 Widget Mapping

| Godot Widget/Controller | React Component/Utility |
|---|---|
| `BaseMenuScreen.gd` | `BaseMenuScreen.tsx` |
| `W_MotionTargetResolver.gd` | `MotionTargetResolver.ts` |
| `W_SettingsFocusConfigurator.gd` | `SettingsFocusConfigurator.ts` |
| `W_AnalogStickAdapter.gd` | `AnalogStickAdapter.ts` |
| `W_TabStrip.gd` | `TabStrip.tsx` |
| `W_OverlayChrome.gd` | `OverlayChrome.tsx` |
| `W_MenuButtonList.gd` | `MenuButtonList.tsx` |
| `W_BackgroundImage.gd` | `BackgroundImage.tsx` (CSS `image-rendering: pixelated`) |
| `W_BackgroundShader.gd` | `BackgroundShader.tsx` |
| `U_UIMenuBuilder.gd` | `MenuBuilder.ts` |

### 9.3 Screen Routes

| Godot Screen | HTML Route | React Component |
|---|---|---|
| `UI_MainMenu` | `/menu/main` | `MainMenuScreen` |
| `UI_PauseMenu` | `/menu/pause` (overlay) | `PauseMenuScreen` |
| `UI_GameOver` | `/menu/game-over` | `GameOverScreen` |
| `UI_Victory` | `/menu/victory` | `VictoryScreen` |
| `UI_Credits` | `/menu/credits` | `CreditsScreen` |
| `UI_SplashScreen` | `/menu/splash` | `SplashScreen` |
| `UI_SettingsPanel` | `/menu/settings` (overlay) | `SettingsPanel` |
| `UI_HUD` | In-game overlay | `HUDOverlay` |
| `UI_LoadingScreen` | Transition overlay | `LoadingScreen` |
| `UI_SaveLoadMenu` | `/menu/save-load` (overlay) | `SaveLoadMenu` |

### 9.4 UI State

- **UI state:** Zustand store
- **Engine-authored UI events:** Via transport event channel
- **Input routing:** `UIInputHandler` hook/context

### 9.5 Design Rules (Preserved from Godot)

- Widgets are single-responsibility, no shared base class
- Screen controllers ~40-80 lines
- Isolated per-widget Vitest tests
- Composition over inheritance
- Static helpers where state is not needed

## 10. Milestones

### M1: Core Gameplay Loop
- Bevy App with MinimalPlugins, bevy_rapier3d, bevy_asset, bevy_input
- All 22 component structs (Bevy Components) + 29 event types
- mlua integration: engine API surface (spawn, query, get/set, emit, physics, input)
- Rapier3D: RigidBody/Collider/Velocity as components; collision events auto-routed
- Bevy SystemSet ordering: InputCapture → PrePhysics → CoreMotion → Physics → PostMotion → Feedback → Diagnostics
- Lua system wrappers registered into Bevy SystemSets
- Transport adapter (ITransport): WebSocket + Tauri IPC
- Three.js thin client: snapshot interpolation, sprite billboarding
- 2.5D camera with -30° pitch, free yaw rotation
- Wall cutout/occlusion
- Player movement, jumping, gravity, directional facing
- Input capture (keyboard, gamepad, touch → bevy_input)
- All 20 manager stubs
- Single test room (JSON + Lua)
- Tauri desktop app
- Headless server for browser play

### M2: UI & Settings
- React UI shell with screen routing
- All menu screens
- Settings panel with all tabs
- HUD overlay
- Save/load menu
- Localization
- Audio playback (client-side)
- Display/resolution management
- Input rebinding
- Cursor management
- Screenshot cache

### M3: Polish & Effects
- VFX system
- Audio events
- Character lighting
- Gamepad haptics
- Damage flash, screen shake
- Objective tracking
- Checkpoint system
- Scene director (multi-room)
- Run coordinator
- Landing indicators, spawn recovery, death/victory handlers

## 11. Constraints & Compatibility

- **Multiplayer-ready:** Bevy World per-server; entity ownership in component tags
- **Input validation:** All game-affecting inputs validated server-side
- **Offline via Tauri:** Bevy App + Lua runs natively in-process; web app is online-only via WebSocket
- **Architectural continuity:** All 20 managers, 22 components, 29 systems preserved
- **No WASM:** Single native Rust compilation target
- **Bevy ecosystem:** Any Bevy plugin works — `bevy_rapier3d`, `bevy_tweening`, `bevy_mod_picking`, `bevy_inspector_egui`, etc.
- **Hot-reload:** Lua systems reloadable without engine restart; assets hot-reloaded via bevy_asset
- **JSON-configurable:** Room definitions, entity configs, system manifests
- **2.5D contract preserved:** Same scale, pitch, directional conventions
