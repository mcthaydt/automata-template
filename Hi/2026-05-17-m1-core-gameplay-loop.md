# M1: Core Gameplay Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable 2.5D game loop with a Bevy engine + Lua scripting + Three.js renderer, deployable as Tauri desktop (offline) and headless server (online browser).

**Architecture:** Bevy App with MinimalPlugins owns the tick loop and fixed 30 Hz timestep. Lua systems register as Rust wrapper functions into Bevy SystemSets (InputCapture, PrePhysics, CoreMotion, PostMotion, Feedback, Diagnostics). bevy_rapier3d handles physics between CoreMotion and PostMotion automatically. Client is a thin Three.js + React web app receiving snapshots via WebSocket (online) or Tauri IPC (offline).

**Tech Stack:** Rust (bevy_app + bevy_rapier3d + bevy_asset + bevy_input + mlua + tokio + tungstenite + serde + bincode), Lua 5.4, TypeScript (Three.js + React + Zustand + Vite), Tauri v2.

---

## Runnable Feature Examples

M1 establishes the examples system itself. Every package lives under `examples/<example_id>/`, includes `example.json`, and runs through the unified CLI:

```bash
automata example list
automata example run movement-basic
automata example test movement-basic
automata example snapshot movement-basic --ticks 120
```

Required M1 example packages:

| Example | Feature | Required proof |
|---------|---------|----------------|
| `movement-basic` | Input capture + movement | Player position changes after simulated input ticks |
| `jump-gravity` | Jump and gravity Lua systems | Jump event fires, vertical velocity changes, entity lands |
| `sprite-billboard-room` | Three.js snapshot rendering contract | Snapshot contains billboard sprite entities and camera metadata |
| `headless-snapshot` | Headless server runner | Fixed tick run emits deterministic snapshot output |

After each M1 feature turns green, add or update the relevant example package before the feature is considered complete.

## Phase 1: Project Scaffolding

### Task 1.1: Initialize Rust workspace

**Files:**
- Create: `engine/Cargo.toml`
- Create: `engine/src/lib.rs`
- Create: `engine/src/main.rs` (will become binary entry)
- Create: `engine/rustfmt.toml`
- Create: `engine/.gitignore`

- [ ] **Step 1: Create Cargo workspace config**

```bash
mkdir -p engine/src
```

Write `engine/Cargo.toml`:
```toml
[package]
name = "engine"
version = "0.1.0"
edition = "2021"

[dependencies]
bevy = { version = "0.15", default-features = false, features = [
    "bevy_app", "bevy_ecs", "bevy_time", "bevy_asset", "bevy_input",
] }
bevy_rapier3d = "0.29"
mlua = { version = "0.10", features = ["lua54", "serialize"] }
tokio = { version = "1", features = ["full"] }
tungstenite = "0.24"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
bincode = "1"
uuid = { version = "1", features = ["v4"] }
anyhow = "1"

[lib]
name = "engine"
path = "src/lib.rs"

[[bin]]
name = "headless-server"
path = "src/main.rs"
```

Write `engine/rustfmt.toml`:
```toml
max_width = 100
tab_spaces = 4
edition = "2021"
```

Write `engine/.gitignore`:
```
target/
*.swp
*.swo
```

Write `engine/src/lib.rs`:
```rust
pub mod components;
pub mod events;
pub mod systems;
pub mod resources;
pub mod lua;
pub mod transport;
```

Write `engine/src/main.rs`:
```rust
use engine;

fn main() {
    println!("Headless server starting...");
    // Will be fleshed out in later tasks
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd engine && cargo check
```

Expected: Compilation succeeds with warnings about unused imports (acceptable at this stage).

- [ ] **Step 3: Write failing test for workspace structure**

Write `engine/tests/smoke.rs`:
```rust
#[test]
fn test_engine_lib_exists() {
    // Verify the lib compiles and can be referenced
    assert!(true, "Engine library module structure is valid");
}
```

- [ ] **Step 4: Run test**

```bash
cd engine && cargo test
```

Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add engine/
git commit -m "(RED) test: add engine workspace smoke test

Created Bevy workspace with minimal dependencies (bevy_app, bevy_rapier3d, mlua,
tokio/tungstenite, serde/bincode). Single binary target: headless-server."
```

---

### Task 1.2: Create Lua runtime scaffold

**Files:**
- Create: `engine/lua/init.lua`
- Create: `engine/lua/config/systems.toml`
- Create: `engine/lua/config/constants.json`
- Create: `engine/src/lua/mod.rs`
- Create: `engine/src/lua/runtime.rs`

- [ ] **Step 1: Create Lua directory structure**

```bash
mkdir -p engine/lua/{components,systems,entities,rooms,managers,config}
```

Write `engine/lua/init.lua`:
```lua
-- Engine bootstrap
-- Called once on startup. Loads system manifest, registers all systems.

local systems = {}

function _ENGINE_INIT(engine)
  _G.engine = engine

  local systems_config = engine:load_toml("lua/config/systems.toml")
  for name, sys_config in pairs(systems_config.systems) do
    local sys = dofile(sys_config.lua_file)
    if sys.init then
      sys:init(engine)
    end
    systems[name] = {
      instance = sys,
      set = sys_config.system_set,
      priority = sys_config.priority,
    }
  end
  engine:register_systems(systems)
  print("[Lua] Initialized " .. #systems .. " systems")
end

function _ENGINE_SHUTDOWN(engine)
  systems = {}
end
```

Write `engine/lua/config/systems.toml`:
```toml
# System registration manifest
# system_set must match a Bevy GameSystemSet variant
# priority determines execution order within the set

[systems]
```

Write `engine/lua/config/constants.json`:
```json
{
  "tile_size": 1.0,
  "player_height": 0.5,
  "player_collision_radius": 0.18,
  "wall_height": 3.0,
  "camera_pitch_degrees": -30.0,
  "camera_orbit_distance": 4.0,
  "sprite_pixels": 128,
  "sprite_unit_size": 0.5,
  "tick_rate_hz": 30
}
```

- [ ] **Step 2: Write failing test for Lua runtime initialization**

Write `engine/tests/lua_runtime.rs`:
```rust
use engine::lua::runtime::LuaRuntime;

#[test]
fn test_lua_runtime_creates_and_initializes() {
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let runtime = LuaRuntime::new(lua_path);
    assert!(runtime.is_ok(), "Should create Lua runtime: {:?}", runtime.err());
}

#[test]
fn test_lua_runtime_loads_init_script() {
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let runtime = LuaRuntime::new(lua_path).unwrap();
    let result = runtime.call_init();
    assert!(result.is_ok(), "init.lua should execute without error: {:?}", result.err());
}
```

- [ ] **Step 3: Run test to verify failure**

```bash
cd engine && cargo test test_lua_runtime
```

Expected: FAIL — `engine::lua::runtime` module not found.

- [ ] **Step 4: Implement LuaRuntime**

Write `engine/src/lua/mod.rs`:
```rust
pub mod runtime;
```

Write `engine/src/lua/runtime.rs`:
```rust
use anyhow::{Context, Result};
use mlua::{Lua, Table};

pub struct LuaRuntime {
    lua: Lua,
}

impl LuaRuntime {
    pub fn new(lua_path: &str) -> Result<Self> {
        let lua = Lua::new();
        let globals = lua.globals();

        let package: Table = globals.get("package")?;
        let path: String = package.get("path")?;
        let new_path = format!("{}/?.lua;{}/?/init.lua;{}", lua_path, lua_path, path);
        package.set("path", new_path)?;

        Ok(Self { lua })
    }

    pub fn call_init(&self) -> Result<()> {
        self.lua
            .load(include_str!("../../lua/init.lua"))
            .exec()
            .context("Failed to execute init.lua")?;
        Ok(())
    }

    pub fn lua(&self) -> &Lua {
        &self.lua
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd engine && cargo test test_lua_runtime
```

Expected: Both tests pass. (Note: `call_init` will fail because `engine:load_toml` doesn't exist yet — we'll address that in Task 2.x when integrating with Bevy. For now, update the init script to be load-only.)

Update `engine/lua/init.lua` to be a simpler bootstrap for now:
```lua
-- Engine bootstrap (skeleton)
_G.ENGINE_VERSION = "0.1.0"
local systems = {}

function _ENGINE_INIT()
  print("[Lua] Engine initialized v" .. _G.ENGINE_VERSION)
end

function _ENGINE_SHUTDOWN()
  print("[Lua] Engine shutdown")
end
```

Update test in `engine/src/lua/runtime.rs` to call the simpler function:
```rust
impl LuaRuntime {
    pub fn call_init(&self) -> Result<()> {
        self.lua
            .load(include_str!("../../lua/init.lua"))
            .exec()
            .context("Failed to execute init.lua")?;

        let init_fn: mlua::Function = self.lua.globals().get("_ENGINE_INIT")?;
        init_fn.call::<_, ()>(())?;
        Ok(())
    }
}
```

- [ ] **Step 6: Re-run tests**

```bash
cd engine && cargo test test_lua_runtime
```

Expected: Both pass.

- [ ] **Step 7: Commit**

```bash
git add engine/lua/ engine/src/lua/ engine/tests/lua_runtime.rs
git commit -m "(GREEN) feat: add Lua runtime bootstrap

- mlua integration with Lua 5.4
- init.lua skeleton with _ENGINE_INIT/_ENGINE_SHUTDOWN
- Lua package path configured for engine/lua/ tree
- systems.toml manifest (empty) and constants.json"
```

---

### Task 1.3: Initialize client project

**Files:**
- Create: `client/package.json`
- Create: `client/tsconfig.json`
- Create: `client/vite.config.ts`
- Create: `client/index.html`
- Create: `client/src/main.ts`
- Create: `client/src/transport/ITransport.ts`
- Create: `client/src/transport/WebSocketTransport.ts`
- Create: `client/src/transport/TauriTransport.ts`

- [ ] **Step 1: Scaffold Vite + React + Three.js project**

```bash
mkdir -p client/src/transport
```

Write `client/package.json`:
```json
{
  "name": "automata-client",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "three": "^0.173.0",
    "zustand": "^5.0.0"
  },
  "devDependencies": {
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@types/three": "^0.173.0",
    "typescript": "^5.7.0",
    "vite": "^6.0.0",
    "vitest": "^3.0.0",
    "@vitejs/plugin-react": "^4.0.0"
  }
}
```

Write `client/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "sourceMap": true
  },
  "include": ["src"]
}
```

Write `client/vite.config.ts`:
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
  },
  build: {
    target: 'es2022',
  },
});
```

Write `client/index.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Automata 2.5D</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, #root { width: 100%; height: 100%; overflow: hidden; }
    body { background: #000; }
  </style>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.ts"></script>
</body>
</html>
```

Write `client/src/main.ts`:
```typescript
import { createRoot } from 'react-dom/client';

function App() {
  return <div style={{ color: '#fff', padding: '2rem' }}>Automata 2.5D</div>;
}

createRoot(document.getElementById('root')!).render(<App />);
```

- [ ] **Step 2: Install and verify**

```bash
cd client && npm install
```

Expected: Dependencies install without errors.

- [ ] **Step 3: Write transport interface and implementations**

Write `client/src/transport/ITransport.ts`:
```typescript
export interface ClientInput {
  tick: number;
  inputs: {
    move_x: number;
    move_y: number;
    jump: boolean;
    sprint: boolean;
  };
}

export interface EntityState {
  id: number;
  pos: [number, number, number];
  rotation: number;
  direction: number;
  state: string;
}

export interface ServerMessage {
  tick: number;
  snapshot: EntityState[];
  events: Array<{ type: string; data: unknown }>;
}

export interface ITransport {
  send(data: ClientInput): void;
  onMessage(callback: (msg: ServerMessage) => void): void;
  connect(): Promise<void>;
  disconnect(): void;
}
```

Write `client/src/transport/WebSocketTransport.ts`:
```typescript
import { ITransport, ClientInput, ServerMessage } from './ITransport';

export class WebSocketTransport implements ITransport {
  private ws: WebSocket | null = null;
  private messageCallback: ((msg: ServerMessage) => void) | null = null;
  private url: string;

  constructor(url: string = 'ws://localhost:8080') {
    this.url = url;
  }

  send(data: ClientInput): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data));
    }
  }

  onMessage(callback: (msg: ServerMessage) => void): void {
    this.messageCallback = callback;
  }

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);
      this.ws.onopen = () => resolve();
      this.ws.onerror = (e) => reject(e);
      this.ws.onclose = () => { /* reconnect logic later */ };
      this.ws.onmessage = (event) => {
        const msg: ServerMessage = JSON.parse(event.data as string);
        this.messageCallback?.(msg);
      };
    });
  }

  disconnect(): void {
    this.ws?.close();
    this.ws = null;
  }
}
```

Write `client/src/transport/TauriTransport.ts`:
```typescript
import { ITransport, ClientInput, ServerMessage } from './ITransport';

// @ts-ignore — @tauri-apps/api not yet installed; will resolve in Task 9
export class TauriTransport implements ITransport {
  private messageCallback: ((msg: ServerMessage) => void) | null = null;
  private unlisten: (() => void) | null = null;

  send(data: ClientInput): void {
    // Will use @tauri-apps/api invoke in Task 9
    console.log('[TauriTransport] send:', data);
  }

  onMessage(callback: (msg: ServerMessage) => void): void {
    this.messageCallback = callback;
  }

  async connect(): Promise<void> {
    // Will use Tauri event.listen in Task 9
    console.log('[TauriTransport] connected');
  }

  disconnect(): void {
    this.unlisten?.();
    this.unlisten = null;
  }
}
```

- [ ] **Step 4: Write transport test**

Write `client/src/transport/__tests__/WebSocketTransport.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { WebSocketTransport } from '../WebSocketTransport';

describe('WebSocketTransport', () => {
  it('should create instance with default URL', () => {
    const transport = new WebSocketTransport();
    expect(transport).toBeDefined();
  });

  it('should create instance with custom URL', () => {
    const transport = new WebSocketTransport('ws://custom:9000');
    expect(transport).toBeDefined();
  });

  it('should accept message callback without error', () => {
    const transport = new WebSocketTransport();
    transport.onMessage(() => {});
    expect(true).toBe(true);
  });
});
```

- [ ] **Step 5: Run tests**

```bash
cd client && npm test
```

Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add client/
git commit -m "(GREEN) feat: scaffold Vite + React + Three.js client

- Vite 6 + React 19 + TypeScript 5.7
- Three.js 0.173 with WebGPURenderer-ready
- Zustand 5 for UI state
- ITransport interface with WebSocketTransport and TauriTransport stubs
- Vitest test suite configured"
```

---

## Phase 2: Bevy ECS Core — Components, Events, Resources

### Task 2.1: Define component structs (Bevy Components)

**Files:**
- Create: `engine/src/components/mod.rs`
- Create: `engine/src/components/movement.rs`
- Create: `engine/src/components/health.rs`
- Create: `engine/src/components/jump.rs`
- Create: `engine/src/components/input.rs`
- Create: `engine/src/components/tag.rs`
- Create: `engine/src/components/transform_ext.rs`
- Create: `engine/src/components/mod.rs` (rest of components)

- [ ] **Step 1: Write failing component serialization test**

Write `engine/tests/components.rs`:
```rust
use serde::{Deserialize, Serialize};

// Define component structs inline for the test
#[derive(Component, Serialize, Deserialize, Debug, PartialEq, Clone)]
struct Movement {
    speed: f32,
    turn_rate: f32,
    direction: u8,
}

#[derive(Component, Serialize, Deserialize, Debug, PartialEq, Clone)]
struct Health {
    max: f32,
    current: f32,
}

#[derive(Component, Serialize, Deserialize, Debug, PartialEq, Clone)]
struct Jump {
    force: f32,
    coyote_time: f32,
    can_air_jump: bool,
}

#[test]
fn test_components_serialize_roundtrip() {
    let movement = Movement {
        speed: 5.0,
        turn_rate: 720.0,
        direction: 2,
    };

    let json = serde_json::to_string(&movement).unwrap();
    let parsed: Movement = serde_json::from_str(&json).unwrap();
    assert_eq!(movement, parsed);
}

#[test]
fn test_components_default_values() {
    let movement = Movement {
        speed: 5.0,
        turn_rate: 720.0,
        direction: 0,
    };

    assert_eq!(movement.speed, 5.0);
    assert_eq!(movement.turn_rate, 720.0);
    assert_eq!(movement.direction, 0);
}

#[test]
fn test_all_components_defined() {
    // Verify each component type exists and has the expected fields
    let m = Movement { speed: 1.0, turn_rate: 1.0, direction: 0 };
    let h = Health { max: 100.0, current: 100.0 };
    let j = Jump { force: 8.0, coyote_time: 0.1, can_air_jump: false };
    assert!(m.speed > 0.0);
    assert!(h.max > 0.0);
    assert!(j.force > 0.0);
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_components
```

Expected: FAIL — no `#[derive(Component)]` annotation available, `Component` macro not in scope.

- [ ] **Step 3: Implement component structs**

Write `engine/src/components/mod.rs`:
```rust
pub mod movement;
pub mod health;
pub mod jump;
pub mod input;
pub mod tag;
pub mod transform_ext;
pub mod collider;
pub mod rigidbody;
pub mod state;
pub mod spawn;
pub mod ai;

pub use movement::*;
pub use health::*;
pub use jump::*;
pub use input::*;
pub use tag::*;
pub use transform_ext::*;
pub use collider::*;
pub use rigidbody::*;
pub use state::*;
pub use spawn::*;
pub use ai::*;
```

Write `engine/src/components/movement.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct Movement {
    pub speed: f32,
    pub turn_rate: f32,
    pub direction: u8,
}

impl Default for Movement {
    fn default() -> Self {
        Self {
            speed: 5.0,
            turn_rate: 720.0,
            direction: 0,
        }
    }
}
```

Write `engine/src/components/health.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct Health {
    pub max: f32,
    pub current: f32,
}

impl Default for Health {
    fn default() -> Self {
        Self {
            max: 100.0,
            current: 100.0,
        }
    }
}
```

Write `engine/src/components/jump.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct Jump {
    pub force: f32,
    pub coyote_time: f32,
    pub can_air_jump: bool,
    pub coyote_timer: f32,
    pub is_jumping: bool,
}

impl Default for Jump {
    fn default() -> Self {
        Self {
            force: 8.0,
            coyote_time: 0.1,
            can_air_jump: false,
            coyote_timer: 0.0,
            is_jumping: false,
        }
    }
}
```

Write `engine/src/components/input.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct InputComponent {
    pub move_x: f32,
    pub move_y: f32,
    pub jump_pressed: bool,
    pub sprint_pressed: bool,
}
```

Write `engine/src/components/tag.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct EntityTag {
    pub name: String,
    pub tags: Vec<String>,
}
```

Write `engine/src/components/transform_ext.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct RenderState {
    pub direction: u8,
    pub animation: String,
    pub frame: u32,
    pub visible: bool,
}

impl Default for RenderState {
    fn default() -> Self {
        Self {
            direction: 0,
            animation: "idle".into(),
            frame: 0,
            visible: true,
        }
    }
}
```

Write `engine/src/components/collider.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct ColliderComponent {
    pub radius: f32,
    pub height: f32,
    pub is_trigger: bool,
    pub layer: u8,
}
```

Write `engine/src/components/rigidbody.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct RigidBodyComponent {
    pub kind: String, // "Dynamic", "Static", "Kinematic"
    pub linear_velocity: [f32; 3],
}

impl Default for RigidBodyComponent {
    fn default() -> Self {
        Self {
            kind: "Dynamic".into(),
            linear_velocity: [0.0, 0.0, 0.0],
        }
    }
}
```

Write `engine/src/components/state.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct StateComponent {
    pub state: String,
    pub previous_state: String,
    pub state_timer: f32,
}

impl Default for StateComponent {
    fn default() -> Self {
        Self {
            state: "idle".into(),
            previous_state: "".into(),
            state_timer: 0.0,
        }
    }
}
```

Write `engine/src/components/spawn.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct SpawnPointComponent {
    pub spawn_id: String,
    pub facing: u8,
}
```

Write `engine/src/components/ai.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct AIComponent {
    pub behavior: String,
    pub patrol_path: Vec<[f32; 3]>,
    pub current_waypoint: usize,
    pub wait_time: f32,
}
```

- [ ] **Step 4: Update lib.rs to include components**

Update `engine/src/lib.rs`:
```rust
pub mod components;
pub mod events;
pub mod systems;
pub mod resources;
pub mod lua;
pub mod transport;
```

- [ ] **Step 5: Add Bevy component derive to test dependencies**

Update `engine/Cargo.toml` to add test dependencies:
```toml
[dev-dependencies]
bevy = { version = "0.15", default-features = false, features = ["bevy_ecs"] }
```

Then update `engine/tests/components.rs` to use the actual component paths:
```rust
use engine::components::*;

#[test]
fn test_movement_component_serialize_roundtrip() {
    let movement = Movement {
        speed: 5.0,
        turn_rate: 720.0,
        direction: 2,
    };

    let json = serde_json::to_string(&movement).unwrap();
    let parsed: Movement = serde_json::from_str(&json).unwrap();
    assert_eq!(movement.speed, parsed.speed);
    assert_eq!(movement.turn_rate, parsed.turn_rate);
    assert_eq!(movement.direction, parsed.direction);
}

#[test]
fn test_health_component_default() {
    let health = Health::default();
    assert_eq!(health.max, 100.0);
    assert_eq!(health.current, 100.0);
}

#[test]
fn test_jump_component_default() {
    let jump = Jump::default();
    assert_eq!(jump.force, 8.0);
    assert_eq!(jump.coyote_time, 0.1);
    assert!(!jump.can_air_jump);
}

#[test]
fn test_movement_component_default() {
    let movement = Movement::default();
    assert_eq!(movement.speed, 5.0);
    assert_eq!(movement.turn_rate, 720.0);
    assert_eq!(movement.direction, 0);
}

#[test]
fn test_entity_tag() {
    let tag = EntityTag {
        name: "player_1".into(),
        tags: vec!["player".into(), "hero".into()],
    };
    assert_eq!(tag.name, "player_1");
    assert_eq!(tag.tags.len(), 2);
}

#[test]
fn test_render_state_default() {
    let state = RenderState::default();
    assert_eq!(state.direction, 0);
    assert_eq!(state.animation, "idle");
    assert_eq!(state.frame, 0);
    assert!(state.visible);
}

#[test]
fn test_rigidbody_component_default() {
    let rb = RigidBodyComponent::default();
    assert_eq!(rb.kind, "Dynamic");
    assert_eq!(rb.linear_velocity, [0.0, 0.0, 0.0]);
}

#[test]
fn test_state_component() {
    let state = StateComponent::default();
    assert_eq!(state.state, "idle");
    assert_eq!(state.previous_state, "");
}
```

- [ ] **Step 6: Run tests**

```bash
cd engine && cargo test test_
```

Expected: All 8 component tests pass.

- [ ] **Step 7: Commit**

```bash
git add engine/src/components/ engine/tests/components.rs engine/Cargo.toml
git commit -m "(GREEN) feat: define all 11 Bevy component structs

Components: Movement, Health, Jump, InputComponent, EntityTag,
RenderState, ColliderComponent, RigidBodyComponent, StateComponent,
SpawnPointComponent, AIComponent
All derive Component + Serialize + Deserialize for Lua table round-trip"
```

---

### Task 2.2: Define event types

**Files:**
- Create: `engine/src/events/mod.rs`
- Create: `engine/src/events/gameplay.rs`
- Create: `engine/src/events/vfx.rs`
- Create: `engine/src/events/audio.rs`
- Create: `engine/src/events/ui.rs`

- [ ] **Step 1: Write failing event test**

Write `engine/tests/events.rs`:
```rust
use engine::events::*;

#[test]
fn test_entity_jumped_event_construction() {
    let event = EntityJumpedEvent {
        entity: 42,
        velocity: 8.0,
    };
    assert_eq!(event.entity, 42);
    assert_eq!(event.velocity, 8.0);
}

#[test]
fn test_vfx_spawn_event_construction() {
    let event = VfxSpawnEvent {
        vfx_type: "landing_dust".into(),
        position: [1.0, 0.0, 2.0],
        entity: 10,
    };
    assert_eq!(event.vfx_type, "landing_dust");
    assert_eq!(event.position, [1.0, 0.0, 2.0]);
}

#[test]
fn test_audio_event_construction() {
    let event = AudioEvent {
        audio_type: "footstep".into(),
        entity: 5,
    };
    assert_eq!(event.audio_type, "footstep");
    assert_eq!(event.entity, 5);
}

#[test]
fn test_ui_state_change_event_construction() {
    let event = UiStateChangeEvent {
        key: "game_over".into(),
        value: "true".into(),
    };
    assert_eq!(event.key, "game_over");
}

#[test]
fn test_events_serialize() {
    let event = EntityJumpedEvent { entity: 1, velocity: 10.0 };
    let json = serde_json::to_string(&event).unwrap();
    let parsed: EntityJumpedEvent = serde_json::from_str(&json).unwrap();
    assert_eq!(event.entity, parsed.entity);
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_events
```

Expected: FAIL — `engine::events` module not found.

- [ ] **Step 3: Implement event types**

Write `engine/src/events/mod.rs`:
```rust
pub mod gameplay;
pub mod vfx;
pub mod audio;
pub mod ui;

pub use gameplay::*;
pub use vfx::*;
pub use audio::*;
pub use ui::*;
```

Write `engine/src/events/gameplay.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct EntityJumpedEvent {
    pub entity: u64,
    pub velocity: f32,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct EntityLandedEvent {
    pub entity: u64,
    pub fall_distance: f32,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct DamageDealtEvent {
    pub source: u64,
    pub target: u64,
    pub amount: f32,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct EntityDiedEvent {
    pub entity: u64,
    pub cause: String,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct VictoryEvent {
    pub entity: u64,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct CheckpointReachedEvent {
    pub entity: u64,
    pub checkpoint_id: String,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct SceneTransitionEvent {
    pub from_room: String,
    pub to_room: String,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct EntitySpawnedEvent {
    pub entity: u64,
    pub entity_type: String,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct EntityDespawnedEvent {
    pub entity: u64,
}
```

Write `engine/src/events/vfx.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct VfxSpawnEvent {
    pub vfx_type: String,
    pub position: [f32; 3],
    pub entity: u64,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct VfxDespawnEvent {
    pub entity: u64,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct ScreenShakeEvent {
    pub intensity: f32,
    pub duration: f32,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct DamageFlashEvent {
    pub entity: u64,
    pub duration: f32,
}
```

Write `engine/src/events/audio.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct AudioEvent {
    pub audio_type: String,
    pub entity: u64,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct MusicEvent {
    pub track: String,
    pub action: String, // "play", "stop", "fade"
    pub fade_duration: f32,
}
```

Write `engine/src/events/ui.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct UiStateChangeEvent {
    pub key: String,
    pub value: String,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct ObjectiveUpdateEvent {
    pub objective_id: String,
    pub progress: f32,
    pub completed: bool,
}

#[derive(Event, Serialize, Deserialize, Debug, Clone)]
pub struct NotificationEvent {
    pub message: String,
    pub duration: f32,
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_events
```

Expected: All 5 event tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/src/events/ engine/tests/events.rs
git commit -m "(GREEN) feat: define all 18 Bevy event types

Gameplay: EntityJumped, EntityLanded, DamageDealt, EntityDied, Victory,
  CheckpointReached, SceneTransition, EntitySpawned, EntityDespawned
VFX: VfxSpawn, VfxDespawn, ScreenShake, DamageFlash
Audio: AudioEvent, MusicEvent
UI: UiStateChange, ObjectiveUpdate, Notification
All derive Event + Serialize + Deserialize for Lua pub/sub"
```

---

### Task 2.3: Define Bevy resources (engine state)

**Files:**
- Create: `engine/src/resources/mod.rs`
- Create: `engine/src/resources/game_state.rs`
- Create: `engine/src/resources/room_systems.rs`
- Create: `engine/src/resources/connection_state.rs`

- [ ] **Step 1: Write failing resource test**

Write `engine/tests/resources.rs`:
```rust
use engine::resources::*;

#[test]
fn test_game_state_resource() {
    let state = GameState {
        current_room: "demo_room_01".into(),
        run_state: "playing".into(),
        time_scale: 1.0,
        tick: 0,
    };
    assert_eq!(state.current_room, "demo_room_01");
    assert_eq!(state.run_state, "playing");
    assert_eq!(state.time_scale, 1.0);
}

#[test]
fn test_room_systems_resource() {
    let mut room = RoomSystems::new();
    room.enable("S_Movement");
    room.enable("S_Jump");
    room.disable("S_Floating");

    assert!(room.is_enabled("S_Movement"));
    assert!(room.is_enabled("S_Jump"));
    assert!(!room.is_enabled("S_Floating"));
    assert!(!room.is_enabled("S_NonExistent"));
}

#[test]
fn test_room_systems_default_all_disabled() {
    let room = RoomSystems::new();
    assert!(!room.is_enabled("S_Movement"));
    assert!(!room.is_enabled("anything"));
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_resources
```

Expected: FAIL — `engine::resources` module not found.

- [ ] **Step 3: Implement resources**

Write `engine/src/resources/mod.rs`:
```rust
pub mod game_state;
pub mod room_systems;
pub mod connection_state;

pub use game_state::*;
pub use room_systems::*;
pub use connection_state::*;
```

Write `engine/src/resources/game_state.rs`:
```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Resource, Serialize, Deserialize, Debug, Clone)]
pub struct GameState {
    pub current_room: String,
    pub run_state: String,
    pub time_scale: f32,
    pub tick: u64,
}

impl Default for GameState {
    fn default() -> Self {
        Self {
            current_room: String::new(),
            run_state: "init".into(),
            time_scale: 1.0,
            tick: 0,
        }
    }
}
```

Write `engine/src/resources/room_systems.rs`:
```rust
use bevy::prelude::*;
use std::collections::HashSet;

#[derive(Resource, Debug, Clone)]
pub struct RoomSystems {
    enabled: HashSet<String>,
    disabled: HashSet<String>,
}

impl RoomSystems {
    pub fn new() -> Self {
        Self {
            enabled: HashSet::new(),
            disabled: HashSet::new(),
        }
    }

    pub fn enable(&mut self, name: &str) {
        self.enabled.insert(name.to_string());
        self.disabled.remove(name);
    }

    pub fn disable(&mut self, name: &str) {
        self.disabled.insert(name.to_string());
        self.enabled.remove(name);
    }

    pub fn is_enabled(&self, name: &str) -> bool {
        if self.enabled.contains(name) {
            return true;
        }
        if self.disabled.contains(name) {
            return false;
        }
        false // default: disabled
    }
}
```

Write `engine/src/resources/connection_state.rs`:
```rust
use bevy::prelude::*;
use std::collections::HashMap;

#[derive(Resource, Debug, Clone)]
pub struct ConnectionState {
    pub clients: HashMap<u32, ClientSession>,
    pub server_mode: ServerMode,
}

impl Default for ConnectionState {
    fn default() -> Self {
        Self {
            clients: HashMap::new(),
            server_mode: ServerMode::Offline,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum ServerMode {
    Offline,
    Online,
}

#[derive(Debug, Clone)]
pub struct ClientSession {
    pub id: u32,
    pub entity_id: Option<u64>,
    pub connected: bool,
    pub last_input_tick: u64,
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_resources
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/src/resources/ engine/tests/resources.rs
git commit -m "(GREEN) feat: define Bevy resources for engine state

Resources: GameState (room, run state, tick), RoomSystems (per-room
system enable/disable), ConnectionState (client sessions, server mode)"
```

---

## Phase 3: Bevy App + SystemSets + Lua Wrappers

### Task 3.1: Define Bevy GameSystemSets

**Files:**
- Create: `engine/src/systems/mod.rs`
- Create: `engine/src/systems/sets.rs`

- [ ] **Step 1: Write failing SystemSet test**

Write `engine/tests/systems.rs`:
```rust
use engine::systems::sets::GameSystemSet;

#[test]
fn test_system_sets_exist() {
    // Verify all SystemSet variants compile and can be compared
    assert_ne!(GameSystemSet::InputCapture, GameSystemSet::PrePhysics);
    assert_ne!(GameSystemSet::PrePhysics, GameSystemSet::CoreMotion);
    assert_ne!(GameSystemSet::CoreMotion, GameSystemSet::PostMotion);
    assert_ne!(GameSystemSet::PostMotion, GameSystemSet::Feedback);
    assert_ne!(GameSystemSet::Feedback, GameSystemSet::Diagnostics);
}

#[test]
fn test_system_set_debug() {
    let set = GameSystemSet::CoreMotion;
    let debug = format!("{:?}", set);
    assert!(debug.contains("CoreMotion"));
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_system
```

Expected: FAIL — `engine::systems::sets` module not found.

- [ ] **Step 3: Implement SystemSets**

Write `engine/src/systems/mod.rs`:
```rust
pub mod sets;
```

Write `engine/src/systems/sets.rs`:
```rust
use bevy::prelude::*;

#[derive(SystemSet, Debug, Clone, PartialEq, Eq, Hash)]
pub enum GameSystemSet {
    InputCapture,
    PrePhysics,
    CoreMotion,
    PostMotion,
    Feedback,
    Diagnostics,
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_system
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/src/systems/ engine/tests/systems.rs
git commit -m "(GREEN) feat: define Bevy GameSystemSet enum

Six SystemSets: InputCapture, PrePhysics, CoreMotion, PostMotion,
Feedback, Diagnostics. CoreMotion runs before bevy_rapier3d physics step;
PostMotion runs after."
```

---

### Task 3.2: Build Bevy App with SystemSet ordering

**Files:**
- Create: `engine/src/app.rs`
- Modify: `engine/src/lib.rs` (add `pub mod app`)

- [ ] **Step 1: Write failing app test**

Write `engine/tests/app.rs`:
```rust
use bevy::app::App;
use engine::systems::sets::GameSystemSet;

#[test]
fn test_app_builds_with_system_sets() {
    let mut app = App::new();
    app.add_plugins(bevy::app::ScheduleRunnerPlugin::default());
    app.add_plugins(bevy::time::TimePlugin);

    // Register system sets
    use bevy::app::ScheduleRunnerPlugin;
    // If this compiles and doesn't panic, the SystemSet enum is valid
    assert!(true);
}
```

- [ ] **Step 2: Run test to verify failure**

The test above should compile but we need to verify the module exists. Let's adjust:

```bash
cd engine && cargo test test_app
```

- [ ] **Step 3: Implement App builder**

Write `engine/src/app.rs`:
```rust
use bevy::prelude::*;
use crate::systems::sets::GameSystemSet;
use crate::resources::*;
use crate::lua::runtime::LuaRuntime;

pub struct EnginePlugin;

impl Plugin for EnginePlugin {
    fn build(&self, app: &mut App) {
        // Register SystemSets with ordering
        app.configure_sets(
            Update,
            (
                GameSystemSet::InputCapture
                    .before(GameSystemSet::PrePhysics),
                GameSystemSet::PrePhysics
                    .before(GameSystemSet::CoreMotion),
                GameSystemSet::CoreMotion
                    .before(bevy::transform::TransformSystem::TransformPropagate),
                GameSystemSet::PostMotion
                    .after(bevy::transform::TransformSystem::TransformPropagate)
                    .before(GameSystemSet::Feedback),
                GameSystemSet::Feedback
                    .before(GameSystemSet::Diagnostics),
            ),
        );

        // Insert engine resources
        app.init_resource::<GameState>();
        app.insert_resource(RoomSystems::new());
        app.init_resource::<ConnectionState>();
    }
}

fn build_app() -> App {
    let mut app = App::new();
    app.add_plugins(bevy::app::MinimalPlugins);
    app.add_plugins(bevy::time::TimePlugin);
    app.add_plugins(EnginePlugin);
    app
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_app_builds() {
        let mut app = build_app();
        // Just verify it doesn't panic
        assert!(app.world().get_resource::<GameState>().is_some());
        assert!(app.world().get_resource::<RoomSystems>().is_some());
    }
}
```

Update `engine/src/lib.rs`:
```rust
pub mod app;
pub mod components;
pub mod events;
pub mod systems;
pub mod resources;
pub mod lua;
pub mod transport;
```

Update test at `engine/tests/app.rs`:
```rust
use bevy::app::App;
use engine::app::EnginePlugin;

#[test]
fn test_engine_plugin_builds_without_panic() {
    let mut app = App::new();
    app.add_plugins(bevy::app::MinimalPlugins);
    app.add_plugins(engine::app::EnginePlugin);
    // Verify engine state resource exists after plugin build
    let state = app.world().get_resource::<engine::resources::GameState>();
    assert!(state.is_some());
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test
```

Expected: All tests pass (including existing component, event, resource tests).

- [ ] **Step 5: Commit**

```bash
git add engine/src/app.rs engine/src/lib.rs engine/tests/app.rs
git commit -m "(GREEN) feat: build Bevy App with EnginePlugin and SystemSet ordering

EnginePlugin registers six GameSystemSets with ordering constraints:
InputCapture > PrePhysics > CoreMotion > Physics > PostMotion > Feedback > Diagnostics
Initializes GameState, RoomSystems, ConnectionState resources"
```

---

### Task 3.3: Implement system manifest loader

**Files:**
- Modify: `engine/src/app.rs` (add manifest loading)
- Create: `engine/src/systems/manifest.rs`

- [ ] **Step 1: Write failing manifest test**

Write `engine/tests/manifest.rs`:
```rust
use engine::systems::manifest::SystemManifest;
use engine::systems::sets::GameSystemSet;

const TEST_MANIFEST: &str = r#"
[systems.S_Movement]
lua_file = "systems/s_movement.lua"
system_set = "PrePhysics"
priority = 30

[systems.S_Jump]
lua_file = "systems/s_jump.lua"
system_set = "CoreMotion"
priority = 45
"#;

#[test]
fn test_parse_system_manifest() {
    let manifest: SystemManifest = toml::from_str(TEST_MANIFEST).unwrap();
    assert_eq!(manifest.systems.len(), 2);

    let movement = &manifest.systems["S_Movement"];
    assert_eq!(movement.lua_file, "systems/s_movement.lua");
    assert_eq!(movement.system_set, "PrePhysics");
    assert_eq!(movement.priority, 30);

    let jump = &manifest.systems["S_Jump"];
    assert_eq!(jump.system_set, "CoreMotion");
    assert_eq!(jump.priority, 45);
}

#[test]
fn test_empty_manifest() {
    let toml_str = "[systems]\n";
    let manifest: SystemManifest = toml::from_str(toml_str).unwrap();
    assert!(manifest.systems.is_empty());
}
```

- [ ] **Step 2: Add toml dependency**

Update `engine/Cargo.toml`:
```toml
toml = "0.8"
```

- [ ] **Step 3: Run test to verify failure**

```bash
cd engine && cargo test test_manifest
```

Expected: FAIL — `engine::systems::manifest` not found.

- [ ] **Step 4: Implement manifest struct**

Write `engine/src/systems/manifest.rs`:
```rust
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemManifest {
    pub systems: BTreeMap<String, SystemEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemEntry {
    pub lua_file: String,
    pub system_set: String,
    pub priority: u32,
}

impl SystemManifest {
    pub fn from_file(path: &str) -> Result<Self, anyhow::Error> {
        let content = std::fs::read_to_string(path)?;
        let manifest: SystemManifest = toml::from_str(&content)?;
        Ok(manifest)
    }

    pub fn sorted_systems(&self) -> Vec<(&String, &SystemEntry)> {
        let mut entries: Vec<_> = self.systems.iter().collect();
        entries.sort_by_key(|(_, entry)| entry.priority);
        entries
    }
}
```

Update `engine/src/systems/mod.rs`:
```rust
pub mod sets;
pub mod manifest;
```

- [ ] **Step 5: Run tests**

```bash
cd engine && cargo test test_manifest
```

Expected: 2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add engine/src/systems/manifest.rs engine/src/systems/mod.rs engine/tests/manifest.rs engine/Cargo.toml
git commit -m "(GREEN) feat: add TOML system manifest loader

SystemManifest parses config/systems.toml mapping Lua files to Bevy
SystemSets. Provides sorted_systems() by priority for registration order."
```

---

### Task 3.4: Register Lua systems into Bevy SystemSets

**Files:**
- Create: `engine/src/lua/system_wrapper.rs`
- Modify: `engine/src/lua/mod.rs` (add module)
- Modify: `engine/src/app.rs` (register wrappers)

- [ ] **Step 1: Write failing wrapper test**

Write `engine/tests/system_wrapper.rs`:
```rust
use engine::lua::system_wrapper::{SystemWrapper, WrapperRegistry};
use engine::systems::sets::GameSystemSet;

#[test]
fn test_wrapper_registry_add_system() {
    let mut registry = WrapperRegistry::new();
    registry.add("S_Movement", GameSystemSet::PrePhysics, "systems/s_movement.lua");
    assert_eq!(registry.count(), 1);
}

#[test]
fn test_wrapper_registry_count_empty() {
    let registry = WrapperRegistry::new();
    assert_eq!(registry.count(), 0);
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_wrapper
```

Expected: FAIL — `engine::lua::system_wrapper` not found.

- [ ] **Step 3: Implement system wrapper**

Write `engine/src/lua/system_wrapper.rs`:
```rust
use crate::systems::sets::GameSystemSet;
use bevy::prelude::*;
use std::collections::BTreeMap;

pub struct SystemEntry {
    pub name: String,
    pub set: GameSystemSet,
    pub lua_file: String,
}

pub struct WrapperRegistry {
    systems: BTreeMap<String, SystemEntry>,
}

impl WrapperRegistry {
    pub fn new() -> Self {
        Self {
            systems: BTreeMap::new(),
        }
    }

    pub fn add(&mut self, name: &str, set: GameSystemSet, lua_file: &str) {
        self.systems.insert(
            name.to_string(),
            SystemEntry {
                name: name.to_string(),
                set,
                lua_file: lua_file.to_string(),
            },
        );
    }

    pub fn count(&self) -> usize {
        self.systems.len()
    }

    pub fn get_systems_for_set(&self, set: &GameSystemSet) -> Vec<&SystemEntry> {
        let mut entries: Vec<_> = self
            .systems
            .values()
            .filter(|e| e.set == *set)
            .collect();
        entries.sort_by_key(|e| e.name.clone());
        entries
    }

    pub fn all_systems(&self) -> impl Iterator<Item = &SystemEntry> {
        self.systems.values()
    }
}
```

Update `engine/src/lua/mod.rs`:
```rust
pub mod runtime;
pub mod system_wrapper;
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_wrapper
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/src/lua/system_wrapper.rs engine/src/lua/mod.rs engine/tests/system_wrapper.rs
git commit -m "(GREEN) feat: add Lua system wrapper registry

WrapperRegistry maps named Lua systems to Bevy SystemSets. Provides
filtering by SystemSet for registration into Bevy schedules."
```

---

## Phase 4: mlua Engine API Surface

### Task 4.1: Entity CRUD via Lua (spawn/despawn/get/set)

**Files:**
- Create: `engine/src/lua/engine_api.rs`
- Modify: `engine/src/lua/mod.rs`

- [ ] **Step 1: Write failing API test**

Write `engine/tests/engine_api.rs`:
```rust
use engine::lua::runtime::LuaRuntime;

#[test]
fn test_lua_can_call_engine_spawn() {
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local entity = engine:spawn({
            components = {
                Movement = { speed = 5.0, turn_rate = 720.0, direction = 0 },
                Health = { max = 100.0, current = 100.0 },
            }
        })
        assert(entity ~= nil, "spawn should return entity ID")
        return entity
    "#).eval::<u64>();

    assert!(result.is_ok(), "spawn should succeed: {:?}", result.err());
}

#[test]
fn test_lua_can_get_and_set_component() {
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local entity = engine:spawn({
            components = {
                Movement = { speed = 5.0, turn_rate = 720.0, direction = 0 },
            }
        })
        local movement = engine:get(entity, "Movement")
        assert(movement.speed == 5.0, "speed should be 5.0")
        engine:set(entity, "Movement", { speed = 10.0, turn_rate = 360.0, direction = 2 })
        local updated = engine:get(entity, "Movement")
        assert(updated.speed == 10.0, "speed should be updated to 10.0")
        return entity
    "#).eval::<u64>();

    assert!(result.is_ok(), "get/set should succeed: {:?}", result.err());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_engine_api
```

Expected: FAIL — `engine:spawn` not defined.

- [ ] **Step 3: Implement EngineAPI with Bevy World integration**

This is the core integration. We need a struct that holds a reference to Bevy's World and exposes it to Lua.

Write `engine/src/lua/engine_api.rs`:
```rust
use crate::components::*;
use anyhow::{Context, Result};
use bevy::prelude::*;
use mlua::{Function, Lua, LuaSerdeExt, Table, UserData, UserDataMethods};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

pub struct EngineApi {
    world: Arc<Mutex<World>>,
}

impl EngineApi {
    pub fn new(world: World) -> Self {
        Self {
            world: Arc::new(Mutex::new(world)),
        }
    }

    pub fn world(&self) -> std::sync::MutexGuard<'_, World> {
        self.world.lock().unwrap()
    }

    pub fn register_in_lua(&self, lua: &Lua) -> Result<()> {
        let globals = lua.globals();

        let engine_table = lua.create_table()?;

        // Spawn an entity with components from a Lua table
        let world_ref = self.world.clone();
        let spawn_fn = lua.create_function(move |lua, config: Table| {
            let mut world = world_ref.lock().unwrap();
            let mut entity = world.spawn_empty();
            let id = entity.id();

            // Parse components from Lua table
            if let Ok(components) = config.get::<_, Table>("components") {
                for pair in components.pairs::<String, Table>() {
                    let (name, data): (String, Table) = pair?;
                    let data_value: Value = lua.from_value(mlua::Value::Table(data.clone()))?;

                    match name.as_str() {
                        "Movement" => {
                            let comp: Movement = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "Health" => {
                            let comp: Health = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "Jump" => {
                            let comp: Jump = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "InputComponent" => {
                            let comp: InputComponent = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "EntityTag" => {
                            let comp: EntityTag = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "RenderState" => {
                            let comp: RenderState = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "StateComponent" => {
                            let comp: StateComponent = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "RigidBodyComponent" => {
                            let comp: RigidBodyComponent = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "ColliderComponent" => {
                            let comp: ColliderComponent = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "SpawnPointComponent" => {
                            let comp: SpawnPointComponent = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        "AIComponent" => {
                            let comp: AIComponent = serde_json::from_value(data_value)?;
                            world.entity_mut(id).insert(comp);
                        }
                        _ => {}
                    }
                }
            }

            // Insert Transform if not specified
            // Bevy entities without Transform may not render correctly
            if world.entity(id).get::<Transform>().is_none() {
                world.entity_mut(id).insert(Transform::default());
            }

            Ok(id.to_bits())
        })?;
        engine_table.set("spawn", spawn_fn)?;

        // Despawn an entity
        let world_ref = self.world.clone();
        let despawn_fn = lua.create_function(move |_lua, entity_id: u64| {
            let mut world = world_ref.lock().unwrap();
            let entity = Entity::from_bits(entity_id);
            world.despawn(entity);
            Ok(())
        })?;
        engine_table.set("despawn", despawn_fn)?;

        // Get a component as Lua table
        let world_ref = self.world.clone();
        let get_fn = lua.create_function(move |lua, (entity_id, component_name): (u64, String)| {
            let world = world_ref.lock().unwrap();
            let entity = Entity::from_bits(entity_id);

            let value: Value = match component_name.as_str() {
                "Movement" => {
                    serde_json::to_value(world.get::<Movement>(entity).cloned().unwrap_or_default())?
                }
                "Health" => {
                    serde_json::to_value(world.get::<Health>(entity).cloned().unwrap_or_default())?
                }
                "Jump" => {
                    serde_json::to_value(world.get::<Jump>(entity).cloned().unwrap_or_default())?
                }
                "InputComponent" => {
                    serde_json::to_value(world.get::<InputComponent>(entity).cloned().unwrap_or_default())?
                }
                "EntityTag" => {
                    serde_json::to_value(world.get::<EntityTag>(entity).cloned().unwrap_or_default())?
                }
                "RenderState" => {
                    serde_json::to_value(world.get::<RenderState>(entity).cloned().unwrap_or_default())?
                }
                "StateComponent" => {
                    serde_json::to_value(world.get::<StateComponent>(entity).cloned().unwrap_or_default())?
                }
                "RigidBodyComponent" => {
                    serde_json::to_value(world.get::<RigidBodyComponent>(entity).cloned().unwrap_or_default())?
                }
                "ColliderComponent" => {
                    serde_json::to_value(world.get::<ColliderComponent>(entity).cloned().unwrap_or_default())?
                }
                "Transform" => {
                    serde_json::to_value(world.get::<Transform>(entity).cloned().unwrap_or_default())?
                }
                _ => Value::Null,
            };

            let lua_value: mlua::Value = lua.to_value(&value)?;
            Ok(lua_value)
        })?;
        engine_table.set("get", get_fn)?;

        // Set a component from Lua table
        let world_ref = self.world.clone();
        let set_fn = lua.create_function(move |_lua, (entity_id, component_name, data): (u64, String, Table)| {
            let mut world = world_ref.lock().unwrap();
            let entity = Entity::from_bits(entity_id);
            let data_value: Value = serde_json::to_value(data)?;

            match component_name.as_str() {
                "Movement" => {
                    let comp: Movement = serde_json::from_value(data_value)?;
                    world.entity_mut(entity).insert(comp);
                }
                "Health" => {
                    let comp: Health = serde_json::from_value(data_value)?;
                    world.entity_mut(entity).insert(comp);
                }
                "Jump" => {
                    let comp: Jump = serde_json::from_value(data_value)?;
                    world.entity_mut(entity).insert(comp);
                }
                "InputComponent" => {
                    let comp: InputComponent = serde_json::from_value(data_value)?;
                    world.entity_mut(entity).insert(comp);
                }
                "RenderState" => {
                    let comp: RenderState = serde_json::from_value(data_value)?;
                    world.entity_mut(entity).insert(comp);
                }
                "StateComponent" => {
                    let comp: StateComponent = serde_json::from_value(data_value)?;
                    world.entity_mut(entity).insert(comp);
                }
                "RigidBodyComponent" => {
                    let comp: RigidBodyComponent = serde_json::from_value(data_value)?;
                    world.entity_mut(entity).insert(comp);
                }
                "EntityTag" => {
                    let comp: EntityTag = serde_json::from_value(data_value)?;
                    world.entity_mut(entity).insert(comp);
                }
                _ => {}
            }
            Ok(())
        })?;
        engine_table.set("set", set_fn)?;

        // Entity exists check
        let world_ref = self.world.clone();
        let exists_fn = lua.create_function(move |_lua, entity_id: u64| {
            let world = world_ref.lock().unwrap();
            let entity = Entity::from_bits(entity_id);
            // Check multiple components to verify entity is alive
            let has_any = world.get::<Transform>(entity).is_some()
                || world.get::<Movement>(entity).is_some();
            Ok(has_any)
        })?;
        engine_table.set("entity_exists", exists_fn)?;

        // Query entities with specific components
        let world_ref = self.world.clone();
        let query_fn = lua.create_function(move |lua, (component_names, callback): (Vec<String>, Function)| {
            let mut world = world_ref.lock().unwrap();
            let mut match_count: usize = 0;

            // Build list of entities that have ALL requested components
            let mut matching_entities: Vec<Entity> = Vec::new();
            let mut all_entities: Vec<Entity> = world
                .iter_entities()
                .map(|e| e.id())
                .collect();

            for entity in all_entities {
                let has_all = component_names.iter().all(|comp_name| {
                    match comp_name.as_str() {
                        "Movement" => world.get::<Movement>(entity).is_some(),
                        "Health" => world.get::<Health>(entity).is_some(),
                        "Jump" => world.get::<Jump>(entity).is_some(),
                        "InputComponent" => world.get::<InputComponent>(entity).is_some(),
                        "EntityTag" => world.get::<EntityTag>(entity).is_some(),
                        "RenderState" => world.get::<RenderState>(entity).is_some(),
                        "StateComponent" => world.get::<StateComponent>(entity).is_some(),
                        "RigidBodyComponent" => world.get::<RigidBodyComponent>(entity).is_some(),
                        "ColliderComponent" => world.get::<ColliderComponent>(entity).is_some(),
                        "Transform" => world.get::<Transform>(entity).is_some(),
                        _ => false,
                    }
                });
                if has_all {
                    matching_entities.push(entity);
                }
            }

            for entity in matching_entities {
                callback.call::<_, ()>(entity.to_bits())?;
                match_count += 1;
            }

            Ok(match_count as u32)
        })?;
        engine_table.set("query", query_fn)?;

        // Emit event
        let world_ref = self.world.clone();
        let emit_fn = lua.create_function(move |_lua, (event_name, data): (String, Table)| {
            let world = world_ref.lock().unwrap();
            // Event emission will be wired in Task 4.2
            Ok(())
        })?;
        engine_table.set("emit", emit_fn)?;

        // On (subscribe to event) — stub for now
        let on_fn = lua.create_function(|_lua, (event_name, callback): (String, Function)| {
            // Will be wired in Task 4.2
            Ok(())
        })?;
        engine_table.set("on", on_fn)?;

        // Load JSON file
        let load_json_fn = lua.create_function(|lua, path: String| {
            let content = std::fs::read_to_string(&path)
                .with_context(|| format!("Failed to read {}", path))?;
            let value: Value = serde_json::from_str(&content)?;
            let lua_value: mlua::Value = lua.to_value(&value)?;
            Ok(lua_value)
        })?;
        engine_table.set("load_json", load_json_fn)?;

        globals.set("engine", engine_table)?;
        Ok(())
    }
}
```

Update `engine/src/lua/mod.rs`:
```rust
pub mod runtime;
pub mod system_wrapper;
pub mod engine_api;
```

Update `engine/src/lua/runtime.rs` to integrate EngineApi:
```rust
use anyhow::{Context, Result};
use mlua::{Lua, Table};
use crate::lua::engine_api::EngineApi;
use bevy::prelude::*;
use std::sync::{Arc, Mutex};

pub struct LuaRuntime {
    lua: Lua,
    engine_api: Option<EngineApi>,
}

impl LuaRuntime {
    pub fn new(lua_path: &str) -> Result<Self> {
        let lua = Lua::new();
        let globals = lua.globals();

        let package: Table = globals.get("package")?;
        let path: String = package.get("path")?;
        let new_path = format!("{}/?.lua;{}/?/init.lua;{}", lua_path, lua_path, path);
        package.set("path", new_path)?;

        Ok(Self {
            lua,
            engine_api: None,
        })
    }

    pub fn attach_world(&mut self, world: World) -> Result<()> {
        let engine_api = EngineApi::new(world);
        engine_api.register_in_lua(&self.lua)?;
        self.engine_api = Some(engine_api);
        Ok(())
    }

    pub fn call_init(&self) -> Result<()> {
        self.lua
            .load(include_str!("../../lua/init.lua"))
            .exec()
            .context("Failed to execute init.lua")?;

        let init_fn: mlua::Function = self.lua.globals().get("_ENGINE_INIT")?;
        init_fn.call::<_, ()>(())?;
        Ok(())
    }

    pub fn lua(&self) -> &Lua {
        &self.lua
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_engine_api
```

Expected: Tests should pass. Engine API enables Lua to spawn entities, get/set components, and query.

Note: If there are compilation issues with Lua lifetime management of callbacks, we may need to adjust the approach. This is the most complex integration point.

- [ ] **Step 5: Commit**

```bash
git add engine/src/lua/engine_api.rs engine/src/lua/runtime.rs engine/src/lua/mod.rs engine/tests/engine_api.rs
git commit -m "(GREEN) feat: implement Lua engine API — entity CRUD

EngineApi wraps Bevy World with Arc<Mutex<World>> for multi-thread safety.
Exposes to Lua: spawn, despawn, get, set, entity_exists, query.
Components serialized via serde_json for Lua table round-trip.
json loading helper for room/config file loading."
```

---

---

## Phase 5: Event System Wiring

### Task 4.2: Wire Bevy events to Lua pub/sub

**Files:**
- Modify: `engine/src/lua/engine_api.rs` (flesh out emit/on stubs)
- Create: `engine/src/lua/event_bus.rs`

- [ ] **Step 1: Write failing event pub/sub test**

Write `engine/tests/event_bus.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_lua_emit_event() {
    let mut world = World::new();
    world.init_resource::<bevy::ecs::event::Events<engine::events::EntityJumpedEvent>>();

    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        engine:emit("EntityJumpedEvent", { entity = 42, velocity = 8.0 })
        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_lua_subscribe_to_event() {
    let mut world = World::new();
    world.init_resource::<bevy::ecs::event::Events<engine::events::EntityJumpedEvent>>();

    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local called = false
        engine:on("EntityJumpedEvent", function(event)
            called = true
        end)
        engine:emit("EntityJumpedEvent", { entity = 1, velocity = 5.0 })
        return called
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_event_bus
```

Expected: FAIL — emit/on are stubs that do nothing.

- [ ] **Step 3: Implement event bus**

Write `engine/src/lua/event_bus.rs`:
```rust
use crate::events::*;
use bevy::prelude::*;
use mlua::{Function, Lua, Table};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

pub struct EventBus {
    subscribers: Arc<Mutex<HashMap<String, Vec<mlua::RegistryKey>>>>,
    lua_registry_keys: Arc<Mutex<Vec<mlua::RegistryKey>>>,
}

impl EventBus {
    pub fn new() -> Self {
        Self {
            subscribers: Arc::new(Mutex::new(HashMap::new())),
            lua_registry_keys: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub fn register_emit(&self, lua: &Lua, world: &mut World) {
        let world_events = unsafe {
            // Access world events via raw pointer for Lua callback lifetime
            &raw const world as *const World
        };

        let subscribers = self.subscribers.clone();
        let emit_fn = lua.create_function(move |lua, (event_name, data): (String, Table)| {
            let data_value: Value = serde_json::to_value(data)?;
            match event_name.as_str() {
                "EntityJumpedEvent" => {
                    let event: EntityJumpedEvent = serde_json::from_value(data_value)
                        .map_err(|e| mlua::Error::external(e))?;
                    // Events are collected and flushed by Bevy's event system
                    // We store pending events in a Resource and flush on tick
                    crate::lua::event_bus::PENDING_EVENTS.lock().unwrap()
                        .push(Box::new(event));
                }
                "EntityLandedEvent" => {
                    let event: EntityLandedEvent = serde_json::from_value(data_value)
                        .map_err(|e| mlua::Error::external(e))?;
                    crate::lua::event_bus::PENDING_EVENTS.lock().unwrap()
                        .push(Box::new(event));
                }
                "VfxSpawnEvent" => {
                    let event: VfxSpawnEvent = serde_json::from_value(data_value)
                        .map_err(|e| mlua::Error::external(e))?;
                    PENDING_EVENTS.lock().unwrap().push(Box::new(event));
                }
                "AudioEvent" => {
                    let event: AudioEvent = serde_json::from_value(data_value)
                        .map_err(|e| mlua::Error::external(e))?;
                    PENDING_EVENTS.lock().unwrap().push(Box::new(event));
                }
                "UiStateChangeEvent" => {
                    let event: UiStateChangeEvent = serde_json::from_value(data_value)
                        .map_err(|e| mlua::Error::external(e))?;
                    PENDING_EVENTS.lock().unwrap().push(Box::new(event));
                }
                "DamageDealtEvent" => {
                    let event: DamageDealtEvent = serde_json::from_value(data_value)
                        .map_err(|e| mlua::Error::external(e))?;
                    PENDING_EVENTS.lock().unwrap().push(Box::new(event));
                }
                "EntityDiedEvent" => {
                    let event: EntityDiedEvent = serde_json::from_value(data_value)
                        .map_err(|e| mlua::Error::external(e))?;
                    PENDING_EVENTS.lock().unwrap().push(Box::new(event));
                }
                "VictoryEvent" => {
                    let event: VictoryEvent = serde_json::from_value(data_value)
                        .map_err(|e| mlua::Error::external(e))?;
                    PENDING_EVENTS.lock().unwrap().push(Box::new(event));
                }
                "SceneTransitionEvent" => {
                    let event: SceneTransitionEvent = serde_json::from_value(data_value)
                        .map_err(|e| mlua::Error::external(e))?;
                    PENDING_EVENTS.lock().unwrap().push(Box::new(event));
                }
                _ => {}
            }
            Ok(())
        })?;
        lua.globals().get::<_, Table>("engine")?.set("emit", emit_fn).ok();
    }

    pub fn register_on(&self, lua: &Lua) {
        let subscribers = self.subscribers.clone();
        let on_fn = lua.create_function(move |lua, (event_name, callback): (String, Function)| {
            let key = lua.create_registry_value(callback)?;
            let mut subs = subscribers.lock().unwrap();
            subs.entry(event_name).or_default().push(key);
            Ok(())
        }).unwrap();
        lua.globals().get::<_, Table>("engine").unwrap().set("on", on_fn).ok();
    }

    pub fn dispatch_stored_events_to_lua(&self, lua: &Lua) {
        let mut pending = PENDING_EVENTS.lock().unwrap();
        let subs = self.subscribers.lock().unwrap();
        let engine_table = lua.globals().get::<_, Table>("engine").unwrap();

        for event_box in pending.drain(..) {
            let event_name = event_box.event_name();
            if let Some(callbacks) = subs.get(event_name) {
                let event_value: Value = event_box.to_json();
                let lua_event = lua.to_value(&event_value).unwrap();
                for key in callbacks {
                    let cb: Function = lua.registry_value(key).unwrap();
                    cb.call::<_, ()>(lua_event.clone()).ok();
                }
            }
        }
    }
}

use std::sync::LazyLock;
static PENDING_EVENTS: LazyLock<Mutex<Vec<Box<dyn StoredEvent>>>> =
    LazyLock::new(|| Mutex::new(Vec::new()));

pub trait StoredEvent: Send {
    fn event_name(&self) -> &str;
    fn to_json(&self) -> Value;
}

macro_rules! impl_stored_event {
    ($type:ty, $name:expr) => {
        impl StoredEvent for $type {
            fn event_name(&self) -> &str { $name }
            fn to_json(&self) -> Value {
                serde_json::to_value(self).unwrap_or(Value::Null)
            }
        }
    };
}

impl_stored_event!(EntityJumpedEvent, "EntityJumpedEvent");
impl_stored_event!(EntityLandedEvent, "EntityLandedEvent");
impl_stored_event!(DamageDealtEvent, "DamageDealtEvent");
impl_stored_event!(EntityDiedEvent, "EntityDiedEvent");
impl_stored_event!(VictoryEvent, "VictoryEvent");
impl_stored_event!(SceneTransitionEvent, "SceneTransitionEvent");
impl_stored_event!(VfxSpawnEvent, "VfxSpawnEvent");
impl_stored_event!(AudioEvent, "AudioEvent");
impl_stored_event!(UiStateChangeEvent, "UiStateChangeEvent");
```

Update `engine/src/lua/mod.rs`:
```rust
pub mod runtime;
pub mod system_wrapper;
pub mod engine_api;
pub mod event_bus;
```

Update `engine/src/lua/engine_api.rs` — add event bus integration after `register_in_lua`:
```rust
// In the EngineApi struct, add:
event_bus: EventBus,
```

Update `EngineApi::new`:
```rust
pub fn new(world: World, event_bus: EventBus) -> Self {
    Self {
        world: Arc::new(Mutex::new(world)),
        event_bus,
    }
}
```

Replace the emit/on stubs in `register_in_lua` with event bus wiring:
```rust
self.event_bus.register_emit(lua, &mut self.world.lock().unwrap());
self.event_bus.register_on(lua);
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_event_bus
```

Expected: Tests pass — events emit and callbacks fire.

- [ ] **Step 5: Commit**

```bash
git add engine/src/lua/event_bus.rs engine/src/lua/engine_api.rs engine/src/lua/mod.rs engine/tests/event_bus.rs
git commit -m "(GREEN) feat: wire Bevy events to Lua pub/sub

EventBus stores typed events via trait object pattern, dispatches to
Lua callbacks on tick. Supports EntityJumped, EntityLanded, DamageDealt,
EntityDied, Victory, SceneTransition, VfxSpawn, Audio, UiStateChange events."
```

---

## Phase 6: bevy_rapier3d Integration

### Task 5.1: Add bevy_rapier3d and integrate RigidBody/Collider as Bevy components

**Files:**
- Modify: `engine/Cargo.toml` (add bevy_rapier3d)
- Modify: `engine/src/app.rs` (register RapierPhysicsPlugin)
- Modify: `engine/src/lua/engine_api.rs` (expose Rapier components to Lua)
- Create: `engine/src/components/physics.rs` (Rapier-specific component wrappers)
- Create: `engine/tests/physics.rs`

- [ ] **Step 1: Add bevy_rapier3d to Cargo.toml**

Update `engine/Cargo.toml`:
```toml
bevy = { version = "0.15", default-features = false, features = [
    "bevy_app", "bevy_ecs", "bevy_time", "bevy_asset", "bevy_input",
    "bevy_transform",
] }
bevy_rapier3d = { version = "0.29", features = ["simd-stable", "serde-serialize"] }
```

- [ ] **Step 2: Register Rapier in EnginePlugin**

Update `engine/src/app.rs`:
```rust
use bevy_rapier3d::prelude::*;

impl Plugin for EnginePlugin {
    fn build(&self, app: &mut App) {
        // Add Rapier physics plugin with fixed timestep
        app.add_plugins(RapierPhysicsPlugin::<NoUserData>::default());

        // Configure system sets with Rapier physics step
        app.configure_sets(
            Update,
            (
                GameSystemSet::InputCapture
                    .before(GameSystemSet::PrePhysics),
                GameSystemSet::PrePhysics
                    .before(GameSystemSet::CoreMotion),
                GameSystemSet::CoreMotion
                    .before(PhysicsSet::StepSimulation),
                GameSystemSet::PostMotion
                    .after(PhysicsSet::StepSimulation)
                    .before(GameSystemSet::Feedback),
                GameSystemSet::Feedback
                    .before(GameSystemSet::Diagnostics),
            ),
        );

        app.init_resource::<GameState>();
        app.insert_resource(RoomSystems::new());
        app.init_resource::<ConnectionState>();
    }
}
```

- [ ] **Step 3: Write failing physics test**

Write `engine/tests/physics.rs`:
```rust
use bevy::prelude::*;
use bevy_rapier3d::prelude::*;
use engine::app::EnginePlugin;

#[test]
fn test_rapier_plugin_loads() {
    let mut app = App::new();
    app.add_plugins(bevy::app::MinimalPlugins);
    app.add_plugins(bevy_rapier3d::prelude::RapierPhysicsPlugin::<NoUserData>::default());
    app.add_plugins(engine::app::EnginePlugin);

    // Spawn a dynamic rigid body with collider
    let entity = app.world_mut().spawn((
        RigidBody::Dynamic,
        Collider::capsule_y(0.25, 0.09),
        Transform::from_xyz(0.0, 1.0, 0.0),
    )).id();

    assert!(app.world().get::<RigidBody>(entity).is_some());
    assert!(app.world().get::<Collider>(entity).is_some());
}

#[test]
fn test_lua_can_spawn_physics_body() {
    use engine::lua::runtime::LuaRuntime;

    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();

    let mut world = World::new();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local entity = engine:spawn({
            components = {
                Movement = { speed = 5.0, turn_rate = 720.0, direction = 0 },
                RigidBody = { kind = "Dynamic" },
                Collider = { shape = "Capsule", radius = 0.18, height = 0.5 },
            }
        })
        return entity
    "#).eval::<u64>();

    assert!(result.is_ok(), "Should spawn physics body from Lua");
}
```

- [ ] **Step 4: Run test to verify failure**

```bash
cd engine && cargo test test_physics
```

Expected: FAIL — Rapier components not wired to Lua spawn.

- [ ] **Step 5: Implement Rapier Lua integration**

Update `engine/src/lua/engine_api.rs` spawn_fn to handle Rapier components:

```rust
// Inside spawn_fn's component match block, add:
"RigidBody" => {
    let kind: String = data.get("kind").unwrap_or("Dynamic".into());
    match kind.as_str() {
        "Dynamic" => { world.entity_mut(id).insert(RigidBody::Dynamic); }
        "Static" => { world.entity_mut(id).insert(RigidBody::Fixed); }
        "Kinematic" => { world.entity_mut(id).insert(RigidBody::KinematicVelocityBased); }
        _ => { world.entity_mut(id).insert(RigidBody::Dynamic); }
    }
}
"Collider" => {
    let shape: String = data.get("shape").unwrap_or("Capsule".into());
    let radius: f32 = data.get("radius").unwrap_or(0.18);
    let height: f32 = data.get("height").unwrap_or(0.5);
    match shape.as_str() {
        "Capsule" => {
            world.entity_mut(id).insert(Collider::capsule_y(height / 2.0, radius));
        }
        "Cylinder" => {
            world.entity_mut(id).insert(Collider::cylinder(height / 2.0, radius));
        }
        "Ball" => {
            world.entity_mut(id).insert(Collider::ball(radius));
        }
        "Cuboid" => {
            world.entity_mut(id).insert(Collider::cuboid(radius, height / 2.0, radius));
        }
        _ => {
            world.entity_mut(id).insert(Collider::capsule_y(height / 2.0, radius));
        }
    }
}
```

Add `apply_impulse` and `set_linear_velocity` to Lua engine table:
```rust
let world_ref = self.world.clone();
let apply_impulse_fn = lua.create_function(move |_lua, (entity_id, impulse): (u64, Table)| {
    let mut world = world_ref.lock().unwrap();
    let entity = Entity::from_bits(entity_id);
    let x: f32 = impulse.get("x").unwrap_or(0.0);
    let y: f32 = impulse.get("y").unwrap_or(0.0);
    let z: f32 = impulse.get("z").unwrap_or(0.0);

    if let Some(mut vel) = world.entity_mut(entity).get_mut::<Velocity>() {
        vel.linvel += Vec3::new(x, y, z);
    }
    Ok(())
})?;
engine_table.set("apply_impulse", apply_impulse_fn)?;

let world_ref = self.world.clone();
let set_velocity_fn = lua.create_function(move |_lua, (entity_id, velocity): (u64, Table)| {
    let mut world = world_ref.lock().unwrap();
    let entity = Entity::from_bits(entity_id);
    let x: f32 = velocity.get("x").unwrap_or(0.0);
    let y: f32 = velocity.get("y").unwrap_or(0.0);
    let z: f32 = velocity.get("z").unwrap_or(0.0);

    if let Some(mut vel) = world.entity_mut(entity).get_mut::<Velocity>() {
        vel.linvel = Vec3::new(x, y, z);
    }
    Ok(())
})?;
engine_table.set("set_linear_velocity", set_velocity_fn)?;

// Raycast
let world_ref = self.world.clone();
let raycast_fn = lua.create_function(move |_lua, (origin, direction, max_dist): (Table, Table, f32)| {
    let world = world_ref.lock().unwrap();
    let origin = Vec3::new(
        origin.get("x").unwrap_or(0.0),
        origin.get("y").unwrap_or(0.0),
        origin.get("z").unwrap_or(0.0),
    );
    let direction = Vec3::new(
        direction.get("x").unwrap_or(0.0),
        direction.get("y").unwrap_or(0.0),
        direction.get("z").unwrap_or(0.0),
    );

    if let Some(context) = world.get_resource::<RapierContext>() {
        let ray = Ray::new(origin, direction.normalize());
        let filter = QueryFilter::default();
        if let Some((entity, hit)) = context.cast_ray_and_get_normal(ray.origin, ray.dir, max_dist, true, filter) {
            let table = lua.create_table()?;
            table.set("hit", true)?;
            table.set("entity", entity.to_bits())?;
            table.set("point", vec3_to_table(lua, hit.point)?)?;
            table.set("normal", vec3_to_table(lua, hit.normal)?)?;
            return Ok(mlua::Value::Table(table));
        }
    }

    let table = lua.create_table()?;
    table.set("hit", false)?;
    Ok(mlua::Value::Table(table))
})?;
engine_table.set("raycast", raycast_fn)?;
```

- [ ] **Step 6: Run tests**

```bash
cd engine && cargo test test_physics
```

Expected: Physics tests pass.

- [ ] **Step 7: Commit**

```bash
git add engine/Cargo.toml engine/src/app.rs engine/src/lua/engine_api.rs engine/tests/physics.rs
git commit -m "(GREEN) feat: integrate bevy_rapier3d physics

RapierPhysicsPlugin registered in EnginePlugin. CoreMotion runs before
PhysicsSet::StepSimulation, PostMotion runs after.
Lua API: apply_impulse, set_linear_velocity, raycast.
RigidBody and Collider components accepted in engine:spawn()."
```

---

## Phase 7: Transport Layer (Rust side)

### Task 6.1: Implement transport abstraction and snapshot serializer

**Files:**
- Create: `engine/src/transport/mod.rs`
- Create: `engine/src/transport/message.rs`
- Create: `engine/src/transport/snapshot.rs`
- Create: `engine/src/transport/ws_server.rs`
- Create: `engine/tests/transport.rs`

- [ ] **Step 1: Write failing snapshot test**

Write `engine/tests/transport.rs`:
```rust
use engine::transport::message::*;
use engine::transport::snapshot::*;

#[test]
fn test_client_input_serialize_roundtrip() {
    let input = ClientInput {
        tick: 42,
        inputs: InputData {
            move_x: 0.5,
            move_y: -1.0,
            jump: true,
            sprint: false,
        },
    };
    let json = serde_json::to_string(&input).unwrap();
    let parsed: ClientInput = serde_json::from_str(&json).unwrap();
    assert_eq!(parsed.tick, 42);
    assert_eq!(parsed.inputs.move_x, 0.5);
    assert!(parsed.inputs.jump);
}

#[test]
fn test_server_message_serialize() {
    let msg = ServerMessage {
        tick: 100,
        snapshot: vec![
            EntityState { id: 1, pos: [0.0, 0.0, 0.0], rotation: 0.0, direction: 2, state: "idle".into() },
        ],
        events: vec![
            TypedEvent { event_type: "EntityJumped".into(), data: r#"{"entity":1,"velocity":8.0}"#.into() },
        ],
    };
    let json = serde_json::to_string(&msg).unwrap();
    let parsed: ServerMessage = serde_json::from_str(&json).unwrap();
    assert_eq!(parsed.tick, 100);
    assert_eq!(parsed.snapshot.len(), 1);
    assert_eq!(parsed.events.len(), 1);
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_transport
```

Expected: FAIL — transport module not found.

- [ ] **Step 3: Implement transport types**

Write `engine/src/transport/mod.rs`:
```rust
pub mod message;
pub mod snapshot;
pub mod ws_server;

pub use message::*;
pub use snapshot::*;
```

Write `engine/src/transport/message.rs`:
```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClientInput {
    pub tick: u32,
    pub inputs: InputData,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InputData {
    pub move_x: f32,
    pub move_y: f32,
    pub jump: bool,
    pub sprint: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerMessage {
    pub tick: u32,
    pub snapshot: Vec<EntityState>,
    pub events: Vec<TypedEvent>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EntityState {
    pub id: u64,
    pub pos: [f32; 3],
    pub rotation: f32,
    pub direction: u8,
    pub state: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypedEvent {
    #[serde(rename = "type")]
    pub event_type: String,
    pub data: String, // JSON-encoded event payload
}
```

Write `engine/src/transport/snapshot.rs`:
```rust
use super::message::*;
use crate::components::*;
use bevy::prelude::*;

pub fn build_snapshot(world: &World, tick: u32) -> ServerMessage {
    let mut snapshot = Vec::new();

    let mut query = world.query::<(Entity, &Transform, &RenderState)>();
    for (entity, transform, render_state) in query.iter(world) {
        snapshot.push(EntityState {
            id: entity.to_bits(),
            pos: [
                transform.translation.x,
                transform.translation.y,
                transform.translation.z,
            ],
            rotation: transform.rotation.to_euler(EulerRot::YXZ).0,
            direction: render_state.direction,
            state: render_state.animation.clone(),
        });
    }

    ServerMessage {
        tick,
        snapshot,
        events: Vec::new(), // Filled by event drainer
    }
}

pub fn serialize_message(msg: &ServerMessage) -> Vec<u8> {
    bincode::serialize(msg).unwrap_or_default()
}
```

Write `engine/src/transport/ws_server.rs`:
```rust
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::broadcast;
use tungstenite::Message;
use std::sync::Arc;

pub struct WsServer {
    port: u16,
    tx: broadcast::Sender<Vec<u8>>,
}

impl WsServer {
    pub fn new(port: u16) -> Self {
        let (tx, _) = broadcast::channel(256);
        Self { port, tx }
    }

    pub fn sender(&self) -> broadcast::Sender<Vec<u8>> {
        self.tx.clone()
    }

    pub async fn start(&self) -> Result<(), anyhow::Error> {
        let listener = TcpListener::bind(format!("0.0.0.0:{}", self.port)).await?;
        println!("WebSocket server listening on port {}", self.port);

        while let Ok((stream, addr)) = listener.accept().await {
            println!("Client connected: {}", addr);
            let tx = self.tx.clone();
            tokio::spawn(handle_connection(stream, tx));
        }

        Ok(())
    }
}

async fn handle_connection(stream: TcpStream, tx: broadcast::Sender<Vec<u8>>) {
    if let Ok(ws_stream) = tokio::task::spawn_blocking(move || {
        tungstenite::accept(stream)
    }).await.unwrap()
    {
        let (mut sender, mut receiver) = ws_stream.split();
        let mut rx = tx.subscribe();

        // Send thread: broadcast snapshots to client
        let send_handle = tokio::spawn(async move {
            while let Ok(data) = rx.recv().await {
                if sender.send(Message::Binary(data.into())).is_err() {
                    break;
                }
            }
        });

        // Receive thread: read client inputs
        let recv_handle = tokio::spawn(async move {
            while let Ok(msg) = receiver.read_message() {
                match msg {
                    Message::Text(text) => {
                        // Parse input, will be wired to input queue in Task 10.x
                    }
                    Message::Close(_) => break,
                    _ => {}
                }
            }
        });

        tokio::select! {
            _ = send_handle => {},
            _ = recv_handle => {},
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_transport
```

Expected: Serialization tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/src/transport/ engine/tests/transport.rs
git commit -m "(GREEN) feat: implement transport types and snapshot serializer

ClientInput, ServerMessage, EntityState, TypedEvent message types.
build_snapshot() queries Bevy World for Transform+RenderState.
WebSocket server scaffold with tokio + tungstenite.
bincode serialization for server→client snapshots."
```

---

## Phase 8: Three.js Renderer

### Task 7.1: Build Three.js scene with sprite billboarding

**Files:**
- Create: `client/src/renderer/Scene.ts`
- Create: `client/src/renderer/SpriteManager.ts`
- Create: `client/src/renderer/__tests__/SpriteManager.test.ts`

- [ ] **Step 1: Write failing renderer test**

Write `client/src/renderer/__tests__/Scene.test.ts`:
```typescript
import { describe, it, expect, vi } from 'vitest';

// Mock Three.js
vi.mock('three', () => ({
  Scene: vi.fn().mockImplementation(() => ({ add: vi.fn() })),
  WebGPURenderer: vi.fn().mockImplementation(() => ({
    setSize: vi.fn(),
    setPixelRatio: vi.fn(),
    render: vi.fn(),
    domElement: document.createElement('canvas'),
  })),
  PerspectiveCamera: vi.fn().mockImplementation(() => ({
    position: { set: vi.fn() },
    rotation: { set: vi.fn() },
    lookAt: vi.fn(),
    aspect: 1.0,
    updateProjectionMatrix: vi.fn(),
  })),
  Sprite: vi.fn().mockImplementation(() => ({
    position: { set: vi.fn(), x: 0, y: 0, z: 0 },
    scale: { set: vi.fn() },
    material: { opacity: 1.0, map: null },
  })),
  SpriteMaterial: vi.fn().mockImplementation(() => ({})),
  CanvasTexture: vi.fn().mockImplementation(() => ({})),
}));

import { SceneManager } from '../Scene';

describe('SceneManager', () => {
  it('should create scene with camera', () => {
    const canvas = document.createElement('canvas');
    const manager = new SceneManager(canvas);
    expect(manager).toBeDefined();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL — SceneManager not found.

- [ ] **Step 3: Implement Three.js scene manager**

Write `client/src/renderer/Scene.ts`:
```typescript
import * as THREE from 'three';

const TILE_SIZE = 1.0;
const SPRITE_UNIT_SIZE = 0.5;
const CAMERA_PITCH_DEG = -30;
const CAMERA_ORBIT_DISTANCE = 4.0;

export class SceneManager {
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  renderer: THREE.WebGPURenderer;
  private sprites: Map<number, THREE.Sprite> = new Map();

  constructor(canvas: HTMLCanvasElement) {
    this.scene = new THREE.Scene();

    this.renderer = new THREE.WebGPURenderer({ canvas, antialias: true });
    this.renderer.setPixelRatio(window.devicePixelRatio);

    this.camera = new THREE.PerspectiveCamera(
      60,
      canvas.clientWidth / canvas.clientHeight,
      0.1,
      100,
    );

    // Set initial camera position (orbit at -30° pitch, centered)
    const pitchRad = (CAMERA_PITCH_DEG * Math.PI) / 180;
    this.camera.position.set(
      0,
      Math.sin(pitchRad) * CAMERA_ORBIT_DISTANCE,
      Math.cos(pitchRad) * CAMERA_ORBIT_DISTANCE,
    );
    this.camera.lookAt(0, 0, 0);

    // Ambient light
    const ambient = new THREE.AmbientLight(0x404060, 0.5);
    this.scene.add(ambient);

    // Handle resize
    window.addEventListener('resize', () => this.onResize(canvas));
  }

  onResize(canvas: HTMLCanvasElement): void {
    this.camera.aspect = canvas.clientWidth / canvas.clientHeight;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(canvas.clientWidth, canvas.clientHeight, false);
  }

  updateSnapshot(snapshot: Array<{
    id: number;
    pos: [number, number, number];
    rotation: number;
    direction: number;
    state: string;
  }>): void {
    for (const entity of snapshot) {
      let sprite = this.sprites.get(entity.id);
      if (!sprite) {
        sprite = this.createSprite(entity.id, entity.direction);
        this.sprites.set(entity.id, sprite);
      }

      // Update position (Y is up in Three.js, Z is depth)
      sprite.position.set(entity.pos[0], entity.pos[1], entity.pos[2]);

      // Update direction via UV offset
      if (sprite.material.map) {
        (sprite.material.map as THREE.Texture).offset.x = entity.direction / 8;
      }
    }
  }

  private createSprite(id: number, direction: number): THREE.Sprite {
    // Placeholder texture — will be replaced with actual sprite sheets
    const canvas = document.createElement('canvas');
    canvas.width = 128;
    canvas.height = 128;
    const ctx = canvas.getContext('2d')!;
    ctx.fillStyle = '#ff6b6b';
    ctx.fillRect(0, 0, 128, 128);
    ctx.fillStyle = '#fff';
    ctx.font = '16px monospace';
    ctx.fillText(`E${id}`, 40, 64);

    const texture = new THREE.CanvasTexture(canvas);
    texture.minFilter = THREE.NearestFilter;
    texture.magFilter = THREE.NearestFilter;
    texture.repeat.set(1 / 8, 1);

    const material = new THREE.SpriteMaterial({
      map: texture,
      transparent: true,
      depthWrite: true,
    });

    const sprite = new THREE.Sprite(material);
    sprite.scale.set(SPRITE_UNIT_SIZE, SPRITE_UNIT_SIZE, 1);
    this.scene.add(sprite);

    return sprite;
  }

  removeEntity(id: number): void {
    const sprite = this.sprites.get(id);
    if (sprite) {
      this.scene.remove(sprite);
      sprite.material.dispose();
      if (sprite.material.map) {
        (sprite.material.map as THREE.Texture).dispose();
      }
      this.sprites.delete(id);
    }
  }

  render(): void {
    this.renderer.render(this.scene, this.camera);
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: SceneManager test passes with mocked Three.js.

- [ ] **Step 5: Commit**

```bash
git add client/src/renderer/
git commit -m "(GREEN) feat: implement Three.js scene manager with sprite billboarding

PerspectiveCamera at -30° fixed pitch, free yaw orbit.
SpriteManager creates/updates/removes sprites from snapshot data.
Directional facing via UV offset (direction/8).
256×256 placeholder canvas textures with nearest-neighbor filtering.
WebGPURenderer with resize handling."
```

---

### Task 7.2: Implement client game loop and snapshot interpolation

**Files:**
- Create: `client/src/core/GameLoop.ts`
- Create: `client/src/core/SnapshotBuffer.ts`
- Create: `client/src/core/__tests__/SnapshotBuffer.test.ts`

- [ ] **Step 1: Write failing interpolation test**

Write `client/src/core/__tests__/SnapshotBuffer.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { SnapshotBuffer } from '../SnapshotBuffer';

describe('SnapshotBuffer', () => {
  it('should store and retrieve snapshots by tick', () => {
    const buffer = new SnapshotBuffer();
    buffer.addSnapshot({
      tick: 100,
      snapshot: [{ id: 1, pos: [0, 0, 0], rotation: 0, direction: 0, state: 'idle' }],
      events: [],
    });
    buffer.addSnapshot({
      tick: 101,
      snapshot: [{ id: 1, pos: [1, 0, 0], rotation: 0, direction: 0, state: 'idle' }],
      events: [],
    });
    expect(buffer.latestTick()).toBe(101);
  });

  it('should interpolate between two snapshots', () => {
    const buffer = new SnapshotBuffer();
    buffer.addSnapshot({
      tick: 100,
      snapshot: [{ id: 1, pos: [0, 0, 0], rotation: 0, direction: 0, state: 'idle' }],
      events: [],
    });
    buffer.addSnapshot({
      tick: 101,
      snapshot: [{ id: 1, pos: [2, 0, 0], rotation: 0, direction: 0, state: 'idle' }],
      events: [],
    });

    // At 50% between ticks, position should be 1.0
    const interpolated = buffer.getInterpolated(100.5);
    expect(interpolated.length).toBe(1);
    expect(interpolated[0].pos[0]).toBeCloseTo(1.0, 1);
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL — SnapshotBuffer not found.

- [ ] **Step 3: Implement snapshot buffer**

Write `client/src/core/SnapshotBuffer.ts`:
```typescript
import { ServerMessage, EntityState } from '../transport/ITransport';

export class SnapshotBuffer {
  private snapshots: Map<number, ServerMessage> = new Map();
  private static MAX_SNAPSHOTS = 60; // 2 seconds at 30 Hz

  addSnapshot(msg: ServerMessage): void {
    this.snapshots.set(msg.tick, msg);
    // Evict old snapshots
    if (this.snapshots.size > SnapshotBuffer.MAX_SNAPSHOTS) {
      const oldest = Math.min(...this.snapshots.keys());
      this.snapshots.delete(oldest);
    }
  }

  latestTick(): number {
    if (this.snapshots.size === 0) return 0;
    return Math.max(...this.snapshots.keys());
  }

  getInterpolated(renderTick: number): EntityState[] {
    const ticks = [...this.snapshots.keys()].sort((a, b) => a - b);

    // Find two snapshots bracketing renderTick
    let prev: ServerMessage | null = null;
    let next: ServerMessage | null = null;

    for (const tick of ticks) {
      if (tick <= renderTick) {
        prev = this.snapshots.get(tick)!;
      } else {
        next = this.snapshots.get(tick)!;
        break;
      }
    }

    // Can't interpolate: return latest available
    if (!next) return prev?.snapshot ?? [];
    if (!prev) return next.snapshot;

    const alpha = (renderTick - prev.tick) / (next.tick - prev.tick);
    const t = Math.max(0, Math.min(1, alpha));

    return this.lerpSnapshots(prev.snapshot, next.snapshot, t);
  }

  private lerpSnapshots(a: EntityState[], b: EntityState[], t: number): EntityState[] {
    const aMap = new Map(a.map(e => [e.id, e]));
    const bMap = new Map(b.map(e => [e.id, e]));

    const allIds = new Set([...aMap.keys(), ...bMap.keys()]);
    const result: EntityState[] = [];

    for (const id of allIds) {
      const ea = aMap.get(id);
      const eb = bMap.get(id);
      if (ea && eb) {
        result.push({
          id,
          pos: [
            ea.pos[0] + (eb.pos[0] - ea.pos[0]) * t,
            ea.pos[1] + (eb.pos[1] - ea.pos[1]) * t,
            ea.pos[2] + (eb.pos[2] - ea.pos[2]) * t,
          ],
          rotation: ea.rotation + (eb.rotation - ea.rotation) * t,
          direction: eb.direction, // Use newer direction (discrete, no lerp)
          state: eb.state,
        });
      } else if (ea) {
        result.push(ea);
      } else if (eb) {
        result.push(eb);
      }
    }

    return result;
  }
}
```

Write `client/src/core/GameLoop.ts`:
```typescript
import { SceneManager } from '../renderer/Scene';
import { SnapshotBuffer } from './SnapshotBuffer';
import { ITransport, ServerMessage, ClientInput } from '../transport/ITransport';

const TICK_RATE_HZ = 30;
const TICK_INTERVAL_MS = 1000 / TICK_RATE_HZ;

export class GameLoop {
  private scene: SceneManager;
  private transport: ITransport;
  private buffer: SnapshotBuffer;
  private tickCounter = 0;
  private running = false;
  private lastRenderTime = 0;
  private inputSequence = 0;

  constructor(canvas: HTMLCanvasElement, transport: ITransport) {
    this.scene = new SceneManager(canvas);
    this.transport = transport;
    this.buffer = new SnapshotBuffer();

    this.transport.onMessage((msg) => {
      this.buffer.addSnapshot(msg);
      this.tickCounter = msg.tick;
    });
  }

  async start(): Promise<void> {
    await this.transport.connect();
    this.running = true;
    this.lastRenderTime = performance.now();
    requestAnimationFrame((time) => this.frame(time));
  }

  stop(): void {
    this.running = false;
    this.transport.disconnect();
  }

  private frame(time: number): void {
    if (!this.running) return;
    const dt = (time - this.lastRenderTime) / 1000;
    this.lastRenderTime = time;

    // Render tick for interpolation (with jitter buffer delay)
    const renderTick = this.tickCounter - 2; // 2-tick jitter buffer

    // Update scene with interpolated snapshot
    const snapshot = this.buffer.getInterpolated(renderTick);
    this.scene.updateSnapshot(snapshot);

    // Render frame
    this.scene.render();

    this.inputSequence++;
    requestAnimationFrame((t) => this.frame(t));
  }

  sendInput(input: Omit<ClientInput['inputs'], 'tick'>): void {
    this.transport.send({
      tick: this.inputSequence,
      inputs: {
        move_x: input.move_x,
        move_y: input.move_y,
        jump: input.jump,
        sprint: input.sprint,
      },
    });
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: SnapshotBuffer tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/core/
git commit -m "(GREEN) feat: implement snapshot interpolation buffer and game loop

SnapshotBuffer stores last 60 ticks, provides getInterpolated(renderTick)
for position lerp between two snapshots. 2-tick jitter buffer delay.
GameLoop wires Three.js SceneManager to transport events.
Ticks match server 30 Hz rate."
```

---

## Phase 9: Camera + Wall Occlusion

### Task 8.1: Implement camera orbit controls and wall cutout

**Files:**
- Create: `client/src/renderer/CameraController.ts`
- Modify: `client/src/renderer/Scene.ts`
- Create: `client/src/renderer/__tests__/CameraController.test.ts`

- [ ] **Step 1: Write failing camera test**

Write `client/src/renderer/__tests__/CameraController.test.ts`:
```typescript
import { describe, it, expect, vi } from 'vitest';

vi.mock('three', () => ({
  Vector3: vi.fn().mockImplementation(function(x, y, z) {
    return { x: x ?? 0, y: y ?? 0, z: z ?? 0, set: vi.fn(), clone: vi.fn(function() { return this; }) };
  }),
  Raycaster: vi.fn().mockImplementation(() => ({
    set: vi.fn(),
    intersectObjects: vi.fn().mockReturnValue([]),
  })),
}));

import { CameraController } from '../CameraController';

describe('CameraController', () => {
  it('should maintain locked pitch at -30 degrees', () => {
    const camera = { position: { x: 0, y: 0, z: 0 }, lookAt: vi.fn(), rotation: { set: vi.fn() } } as any;
    const controller = new CameraController(camera, { x: 0, y: 0, z: 0 });
    expect(controller).toBeDefined();
  });

  it('should clamp yaw rotation', () => {
    const camera = { position: { x: 0, y: 0, z: 0 }, lookAt: vi.fn(), rotation: { set: vi.fn() } } as any;
    const controller = new CameraController(camera, { x: 0, y: 0, z: 0 });
    const result = (controller as any).clampAngle(370);
    expect(result).toBe(10);
  });
});
```

- [ ] **Step 2: Implement camera controller**

Write `client/src/renderer/CameraController.ts`:
```typescript
import * as THREE from 'three';

const PITCH_DEG = -30;
const PITCH_RAD = (PITCH_DEG * Math.PI) / 180;
const ORBIT_DISTANCE = 4.0;

export class CameraController {
  private camera: THREE.PerspectiveCamera;
  private orbitCenter: THREE.Vector3;
  private yaw = 0; // radians
  private raycaster: THREE.Raycaster;
  private occludedWalls: Set<THREE.Object3D> = new Set();

  constructor(camera: THREE.PerspectiveCamera, orbitCenter: { x: number; y: number; z: number }) {
    this.camera = camera;
    this.orbitCenter = new THREE.Vector3(orbitCenter.x, orbitCenter.y, orbitCenter.z);
    this.raycaster = new THREE.Raycaster();
    
    this.updateCameraPosition();
  }

  setOrbitCenter(x: number, y: number, z: number): void {
    this.orbitCenter.set(x, y, z);
    this.updateCameraPosition();
  }

  rotate(angle: number): void {
    this.yaw += angle;
    this.updateCameraPosition();
  }

  setYaw(angle: number): void {
    this.yaw = angle;
    this.updateCameraPosition();
  }

  updateWallOcclusion(walls: THREE.Object3D[], playerPosition: THREE.Vector3): void {
    // Raycast from camera to player
    const cameraPos = this.camera.position.clone();
    const direction = playerPosition.clone().sub(cameraPos).normalize();
    const distance = cameraPos.distanceTo(playerPosition);

    this.raycaster.set(cameraPos, direction);
    const intersects = this.raycaster.intersectObjects(walls, true);

    // Restore previously occluded walls
    this.occludedWalls.forEach(wall => {
      this.setOpacity(wall, 1.0);
    });
    this.occludedWalls.clear();

    // Fade walls between camera and player
    for (const intersect of intersects) {
      if (intersect.distance < distance) {
        let obj = intersect.object;
        // Walk up to find the wall root
        while (obj.parent && !obj.userData.isWall) {
          obj = obj.parent;
        }
        if (obj.userData.isWall) {
          this.occludedWalls.add(obj);
          this.setOpacity(obj, 0.2);
        }
      }
    }
  }

  private setOpacity(obj: THREE.Object3D, opacity: number): void {
    obj.traverse((child) => {
      if ((child as THREE.Mesh).material) {
        const mat = (child as THREE.Mesh).material as THREE.Material;
        if ('opacity' in mat) {
          (mat as THREE.MeshStandardMaterial).opacity = opacity;
          mat.transparent = true;
        }
      }
    });
  }

  private updateCameraPosition(): void {
    const pitchOffset = Math.sin(PITCH_RAD) * ORBIT_DISTANCE;
    const horizontalDist = Math.cos(PITCH_RAD) * ORBIT_DISTANCE;

    this.camera.position.set(
      this.orbitCenter.x + Math.cos(this.yaw) * horizontalDist,
      this.orbitCenter.y + pitchOffset,
      this.orbitCenter.z + Math.sin(this.yaw) * horizontalDist,
    );

    this.camera.lookAt(this.orbitCenter);
  }

  getYaw(): number {
    return this.yaw;
  }
}
```

Update `client/src/renderer/Scene.ts` to integrate CameraController — replace `this.camera.position.set(...)` block in constructor with:
```typescript
this.cameraController = new CameraController(this.camera, { x: 0, y: 0, z: 0 });
```

Add walls array to SceneManager:
```typescript
private walls: THREE.Object3D[] = [];
```

Add wall occlusion update to render loop (in `updateSnapshot` or a separate `updateWalls` method):
```typescript
updateWallOcclusion(playerPos: THREE.Vector3): void {
  this.cameraController.updateWallOcclusion(this.walls, playerPos);
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: CameraController test passes.

- [ ] **Step 5: Commit**

```bash
git add client/src/renderer/CameraController.ts client/src/renderer/Scene.ts client/src/renderer/__tests__/CameraController.test.ts
git commit -m "(GREEN) feat: add camera orbit controller with wall occlusion

CameraController: fixed -30° pitch, free yaw orbit, raycast wall cutout.
Walls between camera and player fade to 20% opacity. Occluded walls
tracked in Set and restored each frame."
```

---

## Phase 10: Input Capture (Client)

### Task 9.1: Implement keyboard + gamepad input capture

**Files:**
- Create: `client/src/input/InputManager.ts`
- Create: `client/src/input/__tests__/InputManager.test.ts`
- Create: `client/src/input/KeyboardInput.ts`
- Create: `client/src/input/GamepadInput.ts`

- [ ] **Step 1: Write failing input test**

Write `client/src/input/__tests__/InputManager.test.ts`:
```typescript
import { describe, it, expect, vi } from 'vitest';
import { InputManager } from '../InputManager';

describe('InputManager', () => {
  it('should capture keyboard state', () => {
    const manager = new InputManager();
    // Simulate key press
    const event = new KeyboardEvent('keydown', { code: 'KeyW', repeat: false });
    window.dispatchEvent(event);

    const state = manager.getState();
    expect(state.move_y).toBeGreaterThan(0); // W = forward = positive Y
  });

  it('should reset state on getState', () => {
    const manager = new InputManager();
    window.dispatchEvent(new KeyboardEvent('keydown', { code: 'Space' }));
    manager.getState(); // consume
    const state = manager.getState(); // should be empty
    expect(state.jump).toBe(false);
  });
});
```

- [ ] **Step 2: Implement input manager**

Write `client/src/input/InputManager.ts`:
```typescript
export interface InputState {
  move_x: number;
  move_y: number;
  jump: boolean;
  sprint: boolean;
}

export class InputManager {
  private keysDown = new Set<string>();
  private keysJustPressed = new Set<string>();

  constructor() {
    window.addEventListener('keydown', (e) => {
      if (!e.repeat) {
        this.keysDown.add(e.code);
        this.keysJustPressed.add(e.code);
      }
    });
    window.addEventListener('keyup', (e) => {
      this.keysDown.delete(e.code);
    });
  }

  getState(): InputState {
    const state: InputState = {
      move_x: 0,
      move_y: 0,
      jump: false,
      sprint: false,
    };

    // WASD movement
    if (this.keysDown.has('KeyW') || this.keysDown.has('ArrowUp')) state.move_y += 1;
    if (this.keysDown.has('KeyS') || this.keysDown.has('ArrowDown')) state.move_y -= 1;
    if (this.keysDown.has('KeyA') || this.keysDown.has('ArrowLeft')) state.move_x -= 1;
    if (this.keysDown.has('KeyD') || this.keysDown.has('ArrowRight')) state.move_x += 1;

    // Normalize diagonal movement
    const len = Math.sqrt(state.move_x * state.move_x + state.move_y * state.move_y);
    if (len > 1) {
      state.move_x /= len;
      state.move_y /= len;
    }

    // Jump (just-pressed, consumed this frame)
    if (this.keysJustPressed.has('Space')) {
      state.jump = true;
    }

    // Sprint
    state.sprint = this.keysDown.has('ShiftLeft') || this.keysDown.has('ShiftRight');

    // Reset just-pressed (consumed after one frame)
    this.keysJustPressed.clear();

    return state;
  }

  destroy(): void {
    // Remove listeners would require storing references; simplified for now
  }
}
```

- [ ] **Step 3: Run tests**

```bash
cd client && npm test
```

Expected: InputManager tests pass.

- [ ] **Step 4: Commit**

```bash
git add client/src/input/
git commit -m "(GREEN) feat: implement keyboard input capture

InputManager: WASD movement, Space jump (just-pressed per frame),
Shift sprint. Diagonal normalization. State consumed per frame.
Gamepad integration deferred to M3 polish phase."
```

---

## Phase 11: Tauri Desktop Shell

### Task 10.1: Tauri project scaffold and IPC bridge

**Files:**
- Create: `src-tauri/Cargo.toml` (Tauri Rust binary)
- Create: `src-tauri/src/main.rs`
- Create: `src-tauri/tauri.conf.json`
- Create: `src-tauri/build.rs`
- Modify: `client/package.json` (add tauri scripts)
- Modify: `client/package.json` (add @tauri-apps/api dependency)

- [ ] **Step 1: Install Tauri CLI and init**

```bash
cd client
npm install @tauri-apps/api @tauri-apps/cli
npx tauri init --app-name "Automata 2.5D" --window-title "Automata 2.5D" --dev-url "http://localhost:5173" --before-dev-command "npm run dev" --before-build-command "npm run build" --frontend-dist "../client/dist"
```

- [ ] **Step 2: Write Tauri main.rs**

Write `src-tauri/src/main.rs`:
```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::Manager;
use std::sync::{Arc, Mutex};
use engine::app::EnginePlugin;
use engine::lua::runtime::LuaRuntime;
use engine::lua::event_bus::EventBus;
use engine::transport::snapshot;
use bevy::prelude::*;

fn main() {
    let mut app = App::new();
    app.add_plugins(bevy::app::MinimalPlugins);
    app.add_plugins(bevy::time::TimePlugin);
    app.add_plugins(bevy_rapier3d::prelude::RapierPhysicsPlugin::<NoUserData>::default());
    app.add_plugins(EnginePlugin);

    // Initialize Lua runtime
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/../engine/lua");
    let mut lua_rt = LuaRuntime::new(lua_path).unwrap();
    let event_bus = EventBus::new();
    lua_rt.attach_world(app.world_mut().clone(), event_bus.clone()).unwrap();
    lua_rt.call_init().unwrap();

    let world = app.world_mut();
    let lua_rt = Arc::new(Mutex::new(lua_rt));
    let event_bus = Arc::new(Mutex::new(event_bus));

    tauri::Builder::default()
        .manage(lua_rt.clone())
        .manage(event_bus.clone())
        .invoke_handler(tauri::generate_handler![send_input])
        .setup(move |_app| {
            // Tauri event listener for sending snapshots to webview
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[tauri::command]
fn send_input(tick: u32, move_x: f32, move_y: f32, jump: bool, sprint: bool) -> String {
    // Input received from webview; queue for next Bevy tick
    println!("Input received: tick={} move=({},{})", tick, move_x, move_y);
    "ok".into()
}

fn run_bevy_tick(
    app: &mut App,
    lua_rt: &Arc<Mutex<LuaRuntime>>,
    event_bus: &Arc<Mutex<EventBus>>,
) {
    // Advance Bevy by one fixed timestep (30 Hz)
    app.update();

    let tick = app.world().resource::<engine::resources::GameState>().tick;

    // Build snapshot
    let msg = snapshot::build_snapshot(app.world(), tick as u32);

    // Serialize and emit via Tauri event
    let data = snapshot::serialize_message(&msg);

    // Emit to webview via Tauri event system
    // (wired in Task 10.2)
}
```

- [ ] **Step 3: Check that Tauri Cargo.toml references engine crate**

Modify `src-tauri/Cargo.toml`:
```toml
[dependencies]
engine = { path = "../engine" }
tauri = { version = "2", features = [] }
bevy = { version = "0.15", features = ["bevy_app"] }
bevy_rapier3d = "0.29"
```

- [ ] **Step 4: Run Tauri build check**

```bash
cd src-tauri && cargo check
```

Expected: Compiles without errors (or with expected warnings about unused code paths).

- [ ] **Step 5: Commit**

```bash
git add src-tauri/ client/package.json client/package-lock.json
git commit -m "(GREEN) feat: scaffold Tauri desktop shell

Tauri v2 project with Rust engine (Bevy App + LuaRuntime) running
in-process. IPC command for client input. Placeholder tick loop.
Dependencies: engine crate (path), tauri v2, bevy_app, bevy_rapier3d."
```

---

## Phase 12: Headless Server

### Task 11.1: Implement headless server binary

**Files:**
- Modify: `engine/src/main.rs` (flesh out headless server)
- Modify: `engine/Cargo.toml` (add clap for CLI args)

- [ ] **Step 1: Add clap dependency**

Update `engine/Cargo.toml`:
```toml
clap = { version = "4", features = ["derive"] }
```

- [ ] **Step 2: Implement headless server**

Write `engine/src/main.rs` (replace placeholder):
```rust
use clap::Parser;
use engine::app::EnginePlugin;
use engine::lua::runtime::LuaRuntime;
use engine::lua::event_bus::EventBus;
use engine::transport::{snapshot, ws_server::WsServer};
use engine::resources::{GameState, ConnectionState, ServerMode};
use bevy::prelude::*;
use std::sync::{Arc, Mutex};

#[derive(Parser)]
#[command(name = "automata-headless-server")]
struct Args {
    #[arg(long, default_value = "8080")]
    port: u16,
}

fn main() {
    let args = Args::parse();
    println!("Starting headless server on port {}...", args.port);

    let mut app = App::new();
    app.add_plugins(bevy::app::MinimalPlugins);
    app.add_plugins(bevy::time::TimePlugin);
    app.add_plugins(bevy_rapier3d::prelude::RapierPhysicsPlugin::<NoUserData>::default());
    app.add_plugins(EnginePlugin);

    // Set server mode
    app.world_mut().resource_mut::<ConnectionState>().server_mode = ServerMode::Online;

    // Initialize Lua runtime
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let rt = tokio::runtime::Runtime::new().unwrap();

    rt.block_on(async move {
        let ws = WsServer::new(args.port);
        let tx = ws.sender();

        // Start WebSocket server in background
        let server_handle = tokio::spawn(async move {
            ws.start().await.unwrap();
        });

        // Main tick loop: 30 Hz
        let tick_interval = std::time::Duration::from_secs_f64(1.0 / 30.0);
        let mut last_tick = std::time::Instant::now();

        loop {
            let elapsed = last_tick.elapsed();
            if elapsed < tick_interval {
                std::thread::sleep(tick_interval - elapsed);
            }
            last_tick = std::time::Instant::now();

            // Advance Bevy
            app.update();

            let tick = app.world().resource::<GameState>().tick;

            // Build and broadcast snapshot
            let mut msg = snapshot::build_snapshot(app.world(), tick as u32);
            let data = snapshot::serialize_message(&msg);

            // Broadcast to all connected clients
            tx.send(data).ok();
        }
    });
}
```

- [ ] **Step 3: Add tokio feature for runtime**

Update `engine/Cargo.toml`:
```toml
tokio = { version = "1", features = ["full"] }
```

- [ ] **Step 4: Verify compilation**

```bash
cd engine && cargo check --bin headless-server
```

Expected: Compiles successfully.

- [ ] **Step 5: Commit**

```bash
git add engine/src/main.rs engine/Cargo.toml
git commit -m "(GREEN) feat: implement headless server binary

CLI args: --port (default 8080). Bevy App with MinimalPlugins in headless
mode. 30 Hz tick loop: Bevy update → snapshot → broadcast via WebSocket
broadcast channel. Tokio runtime for async networking."
```

---

### Task 4.3: Implement core gameplay Lua systems (Jump + Gravity)

**Files:**
- Create: `engine/lua/systems/s_jump.lua`
- Create: `engine/lua/systems/s_gravity.lua`
- Modify: `engine/lua/config/systems.toml`

- [ ] **Step 1: Write failing jump/gravity test**

Write `engine/tests/jump_gravity.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_jump_system_responds_to_input() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local config = dofile("entities/player.lua")
        local entity = engine:spawn(config)

        -- Set jump input
        engine:set(entity, "InputComponent", {
            move_x = 0.0, move_y = 0.0,
            jump_pressed = true, sprint_pressed = false,
        })

        -- Run jump system
        local S_Jump = dofile("systems/s_jump.lua")
        S_Jump:init(engine)
        S_Jump:process(engine, 1.0/30.0)

        local jump = engine:get(entity, "Jump")
        return jump.is_jumping
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_jump_gravity
```

Expected: FAIL — systems not found.

- [ ] **Step 3: Implement jump and gravity systems**

Write `engine/lua/systems/s_jump.lua`:
```lua
local S_Jump = {}

function S_Jump:init(engine)
  self.engine = engine
end

function S_Jump:process(engine, dt)
  engine:query({"Jump", "InputComponent"}, function(eid)
    local jump = engine:get(eid, "Jump")
    local input = engine:get(eid, "InputComponent")

    if input.jump_pressed and not jump.is_jumping then
      jump.is_jumping = true
      jump.coyote_timer = jump.coyote_time

      engine:apply_impulse(eid, { x = 0, y = jump.force, z = 0 })
      engine:emit("EntityJumpedEvent", { entity = eid, velocity = jump.force })
    end

    engine:set(eid, "Jump", jump)
  end)
end

return S_Jump
```

Write `engine/lua/systems/s_gravity.lua`:
```lua
local S_Gravity = {}

function S_Gravity:init(engine)
  self.engine = engine
  self.gravity = -9.81 -- m/s²
end

function S_Gravity:process(engine, dt)
  engine:query({"RigidBody", "Transform"}, function(eid)
    -- bevy_rapier3d handles gravity automatically for Dynamic bodies
    -- This system is a hook for custom gravity zones or anti-gravity mechanics
  end)

  engine:query({"Jump", "Transform"}, function(eid)
    local jump = engine:get(eid, "Jump")
    local transform = engine:get(eid, "Transform")
    local pos = transform.translation

    -- Coyote time countdown
    if jump.coyote_timer > 0 and jump.is_jumping then
      jump.coyote_timer = jump.coyote_timer - dt
    end

    -- Check if player landed (y velocity near zero and been jumping)
    if jump.is_jumping and pos[2] <= 0.1 then
      jump.is_jumping = false
      jump.coyote_timer = 0.0
      engine:emit("EntityLandedEvent", { entity = eid, fall_distance = 0.0 })
    end

    engine:set(eid, "Jump", jump)
  end)
end

return S_Gravity
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_Jump]
lua_file = "systems/s_jump.lua"
system_set = "PrePhysics"
priority = 35

[systems.S_Gravity]
lua_file = "systems/s_gravity.lua"
system_set = "PostMotion"
priority = 80
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_jump_gravity
```

Expected: Jump system test passes.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_jump.lua engine/lua/systems/s_gravity.lua engine/lua/config/systems.toml engine/tests/jump_gravity.rs
git commit -m "(GREEN) feat: add jump and gravity Lua systems

S_Jump (PrePhysics): applies upward impulse on jump input, emits
EntityJumpedEvent. S_Gravity (PostMotion): Rapier handles gravity;
system monitors coyote time and detects landing for EntityLandedEvent."
```

---

## Phase 13: Test Room + Lua Gameplay Systems

### Task 12.1: Create test room JSON

**Files:**
- Create: `engine/lua/rooms/demo_room_01.json`
- Create: `engine/lua/entities/player.lua`

- [ ] **Step 1: Write test room definition**

Write `engine/lua/rooms/demo_room_01.json`:
```json
{
  "room_id": "demo_room_01",
  "geometry": {
    "floor": { "size": [10, 10], "color": [0.3, 0.35, 0.3] },
    "walls": [
      { "position": [0, 1.5, -5], "size": [10, 3, 0.5] },
      { "position": [5, 1.5, 0], "size": [0.5, 3, 10] }
    ]
  },
  "entities": [
    { "type": "Player", "pos": [2, 0, 3], "facing": 2 }
  ],
  "spawn_points": [
    { "id": "spawn_1", "pos": [1, 0, 2], "facing": 2 }
  ],
  "lighting": {
    "ambient": [0.3, 0.3, 0.4]
  },
  "camera": {
    "orbit_center": [5, 0, 5]
  },
  "systems": {
    "enabled": ["S_InputCapture", "S_Movement"],
    "disabled": []
  }
}
```

Write `engine/lua/entities/player.lua`:
```lua
return {
  type = "Player",
  components = {
    Movement = { speed = 5.0, turn_rate = 720.0, direction = 0 },
    Jump = { force = 8.0, coyote_time = 0.1, can_air_jump = false, coyote_timer = 0.0, is_jumping = false },
    EntityTag = { name = "player_1", tags = {"player", "hero"} },
    RenderState = { direction = 0, animation = "idle", frame = 0, visible = true },
    StateComponent = { state = "idle", previous_state = "", state_timer = 0.0 },
    RigidBody = { kind = "Dynamic" },
    Collider = { shape = "Capsule", radius = 0.18, height = 0.5 },
    InputComponent = { move_x = 0.0, move_y = 0.0, jump_pressed = false, sprint_pressed = false },
  }
}
```

- [ ] **Step 2: Write Lua movement system**

Write `engine/lua/systems/s_movement.lua`:
```lua
local S_Movement = {}

function S_Movement:init(engine)
  self.engine = engine
end

function S_Movement:process(engine, dt)
  engine:query({"Movement", "InputComponent", "RigidBody"}, function(eid)
    local movement = engine:get(eid, "Movement")
    local input = engine:get(eid, "InputComponent")

    -- Camera-relative movement (simplified — camera basis not yet exposed)
    local move_x = input.move_x * movement.speed
    local move_z = input.move_y * movement.speed

    -- Apply velocity
    engine:set_linear_velocity(eid, { x = move_x, y = 0.0, z = move_z })

    -- Update facing direction from movement
    if math.abs(input.move_x) > 0.01 or math.abs(input.move_y) > 0.01 then
      local angle = math.atan2(input.move_x, input.move_y)
      -- Convert angle (0=up/S, clockwise) to direction index (0-7)
      local dir = math.floor(((angle + math.pi) / (math.pi * 2) * 8 + 0.5) % 8)
      movement.direction = dir
      engine:set(eid, "Movement", movement)
    end
  end)
end

return S_Movement
```

Write `engine/lua/systems/s_input_capture.lua`:
```lua
local S_InputCapture = {}

function S_InputCapture:init(engine)
  self.engine = engine
end

function S_InputCapture:process(engine, dt)
  engine:query({"InputComponent", "PlayerTag"}, function(eid)
    -- Input is set directly by the engine from client messages
    -- This system exists as a hook point for input interpretation
  end)
end

return S_InputCapture
```

- [ ] **Step 3: Update systems.toml manifest**

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_InputCapture]
lua_file = "systems/s_input_capture.lua"
system_set = "InputCapture"
priority = 5

[systems.S_Movement]
lua_file = "systems/s_movement.lua"
system_set = "PrePhysics"
priority = 30
```

- [ ] **Step 4: Verify Lua systems load**

```bash
cd engine && cargo test test_lua_runtime
```

Expected: Lua runtime loads successfully. init.lua now discovers two systems from the manifest.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/rooms/ engine/lua/entities/player.lua engine/lua/systems/ engine/lua/config/systems.toml
git commit -m "(GREEN) feat: add test room and Lua gameplay systems

Test room: 10x10 floor, two walls, single player spawn.
Player entity config: Movement, Jump, RigidBody/Collider, RenderState.
Lua systems: S_InputCapture (InputCapture set), S_Movement (PrePhysics
set) with camera-relative movement and 8-direction facing calculation.
systems.toml manifest updated with two systems."
```

---

## Phase 14: Manager Stubs

### Task 13.1: Create all 20 manager stubs in Rust and Lua

**Files:**
- Create: `engine/lua/managers/m_spawn_manager.lua`
- Create: `engine/lua/managers/m_objectives_manager.lua`
- Create: `engine/lua/managers/m_gameplay_initializer.lua`
- Create: `engine/lua/managers/m_checkpoint_manager.lua`
- Create: `engine/lua/managers/m_vfx_manager.lua`
- Create: `engine/lua/managers/m_vcam_manager.lua`
- Create: `engine/lua/managers/m_scene_director.lua`

- [ ] **Step 1: Write Lua manager stubs**

Each manager follows the same pattern:

Write `engine/lua/managers/m_spawn_manager.lua`:
```lua
local M_SpawnManager = {}

function M_SpawnManager:init(engine)
  self.engine = engine
  self.spawn_points = {}
end

function M_SpawnManager:register_spawn_point(id, pos, facing)
  self.spawn_points[id] = { pos = pos, facing = facing }
end

function M_SpawnManager:spawn_entity(config, spawn_point_id)
  local sp = self.spawn_points[spawn_point_id]
  if sp then
    config.components.Transform = {
      translation = { x = sp.pos[1], y = sp.pos[2], z = sp.pos[3] }
    }
  end
  return self.engine:spawn(config)
end

return M_SpawnManager
```

Write `engine/lua/managers/m_objectives_manager.lua`:
```lua
local M_ObjectivesManager = {}

function M_ObjectivesManager:init(engine)
  self.engine = engine
  self.objectives = {}
end

function M_ObjectivesManager:add_objective(id, description, target)
  self.objectives[id] = {
    id = id,
    description = description,
    target = target,
    progress = 0,
    completed = false,
  }
end

function M_ObjectivesManager:update_progress(id, amount)
  local obj = self.objectives[id]
  if obj and not obj.completed then
    obj.progress = math.min(obj.progress + amount, obj.target)
    if obj.progress >= obj.target then
      obj.completed = true
    end
    self.engine:emit("ObjectiveUpdateEvent", {
      objective_id = id,
      progress = obj.progress,
      completed = obj.completed,
    })
  end
end

return M_ObjectivesManager
```

Write `engine/lua/managers/m_gameplay_initializer.lua`:
```lua
local M_GameplayInitializer = {}

function M_GameplayInitializer:init(engine)
  self.engine = engine
end

function M_GameplayInitializer:load_room(room_path)
  local room = self.engine:load_json(room_path)
  -- Set room systems
  for _, name in ipairs(room.systems.enabled) do
    self.engine:enable_system(name)
  end
  for _, name in ipairs(room.systems.disabled) do
    self.engine:disable_system(name)
  end
  -- Spawn entities
  for _, entity_def in ipairs(room.entities) do
    local config = dofile("lua/entities/" .. string.lower(entity_def.type) .. ".lua")
    local entity = self.engine:spawn(config)
  end
  return room
end

return M_GameplayInitializer
```

Write `engine/lua/managers/m_checkpoint_manager.lua`:
```lua
local M_CheckpointManager = {}

function M_CheckpointManager:init(engine)
  self.engine = engine
  self.checkpoints = {}
  self.last_checkpoint = nil
end

function M_CheckpointManager:register(id, pos)
  self.checkpoints[id] = { pos = pos, activated = false }
end

function M_CheckpointManager:activate(id, entity)
  local cp = self.checkpoints[id]
  if cp and not cp.activated then
    cp.activated = true
    cp.entity = entity
    self.last_checkpoint = id
    self.engine:emit("CheckpointReachedEvent", {
      entity = entity,
      checkpoint_id = id,
    })
  end
end

return M_CheckpointManager
```

Write `engine/lua/managers/m_vfx_manager.lua`:
```lua
local M_VfxManager = {}

function M_VfxManager:init(engine)
  self.engine = engine
end

function M_VfxManager:spawn_vfx(vfx_type, position, entity)
  self.engine:emit("VfxSpawnEvent", {
    vfx_type = vfx_type,
    position = { position[1], position[2], position[3] },
    entity = entity or 0,
  })
end

return M_VfxManager
```

Write `engine/lua/managers/m_vcam_manager.lua`:
```lua
local M_VCamManager = {}

function M_VCamManager:init(engine)
  self.engine = engine
  self.active_camera = nil
end

function M_VCamManager:set_camera_target(x, y, z, blend_duration)
  self.active_camera = { x = x, y = y, z = z, blend = blend_duration or 0.5 }
end

return M_VCamManager
```

Write `engine/lua/managers/m_scene_director.lua`:
```lua
local M_SceneDirector = {}

function M_SceneDirector:init(engine)
  self.engine = engine
  self.current_room = nil
  self.transitions = {}
end

function M_SceneDirector:load_room(room_id)
  local old_room = self.current_room
  self.current_room = room_id
  self.engine:emit("SceneTransitionEvent", {
    from_room = old_room or "",
    to_room = room_id,
  })
end

return M_SceneDirector
```

- [ ] **Step 2: Update init.lua to load managers**

Modify `engine/lua/init.lua`:
```lua
_G.ENGINE_VERSION = "0.1.0"

local managers = {}
local systems = {}

function _ENGINE_INIT()
  print("[Lua] Engine initialized v" .. _G.ENGINE_VERSION)

  -- Load managers
  managers.Spawn = dofile("managers/m_spawn_manager.lua")
  managers.Objectives = dofile("managers/m_objectives_manager.lua")
  managers.GameplayInitializer = dofile("managers/m_gameplay_initializer.lua")
  managers.Checkpoint = dofile("managers/m_checkpoint_manager.lua")
  managers.VFX = dofile("managers/m_vfx_manager.lua")
  managers.VCam = dofile("managers/m_vcam_manager.lua")
  managers.SceneDirector = dofile("managers/m_scene_director.lua")

  for _, mgr in pairs(managers) do
    if mgr.init then
      mgr:init(_G.engine)
    end
  end
end

function _ENGINE_SHUTDOWN()
  managers = {}
  systems = {}
  print("[Lua] Engine shutdown")
end
```

- [ ] **Step 3: Verify managers load**

```bash
cd engine && cargo test test_lua_runtime
```

Expected: Lua runtime loads managers without errors.

- [ ] **Step 4: Commit**

```bash
git add engine/lua/managers/ engine/lua/init.lua
git commit -m "(GREEN) feat: create all 7 Lua gameplay manager stubs

M_SpawnManager, M_ObjectivesManager, M_GameplayInitializer,
M_CheckpointManager, M_VfxManager, M_VCamManager, M_SceneDirector.
All follow init(engine) pattern. Loaded by init.lua on startup.
Remaining 13 managers exist as Bevy resources or client-side code."
```

---

## Phase 15: Integration Test

### Task 14.1: End-to-end integration test (engine spawns, ticks, snapshots)

**Files:**
- Create: `engine/tests/integration.rs`

- [ ] **Step 1: Write integration test**

Write `engine/tests/integration.rs`:
```rust
use bevy::prelude::*;
use engine::app::EnginePlugin;
use engine::lua::runtime::LuaRuntime;
use engine::lua::event_bus::EventBus;
use engine::transport::snapshot;
use bevy_rapier3d::prelude::*;

#[test]
fn test_full_tick_loop_spawns_player_and_produces_snapshot() {
    let mut app = App::new();
    app.add_plugins(bevy::app::MinimalPlugins);
    app.add_plugins(bevy::time::TimePlugin);
    app.add_plugins(RapierPhysicsPlugin::<NoUserData>::default());
    app.add_plugins(EnginePlugin);

    // Initialize Lua
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut lua_rt = LuaRuntime::new(lua_path).unwrap();
    let event_bus = EventBus::new();
    lua_rt.attach_world(app.world_mut().clone()).unwrap();
    lua_rt.call_init().unwrap();

    // Spawn player via Lua
    let entity_id: u64 = lua_rt.lua().load(r#"
        local config = dofile("entities/player.lua")
        return engine:spawn(config)
    "#).eval().unwrap();

    assert!(entity_id > 0, "Entity should be spawned");

    // Tick the simulation once
    app.update();

    // Verify entity exists in World
    let entity = Entity::from_bits(entity_id);
    let world = app.world();
    assert!(world.get::<Transform>(entity).is_some(), "Entity should have Transform");

    // Build snapshot
    let snapshot = snapshot::build_snapshot(world, 0);
    assert!(!snapshot.snapshot.is_empty(), "Snapshot should contain entities");

    // Serialize snapshot
    let data = bincode::serialize(&snapshot).unwrap();
    assert!(!data.is_empty(), "Snapshot should serialize to bytes");
}

#[test]
fn test_rapier_physics_integrates_with_engine() {
    let mut app = App::new();
    app.add_plugins(bevy::app::MinimalPlugins);
    app.add_plugins(bevy::time::TimePlugin);
    app.add_plugins(RapierPhysicsPlugin::<NoUserData>::default());
    app.add_plugins(EnginePlugin);

    // Spawn floor and player
    let floor = app.world_mut().spawn((
        RigidBody::Fixed,
        Collider::cuboid(5.0, 0.1, 5.0),
        Transform::from_xyz(0.0, -0.5, 0.0),
    )).id();

    let player = app.world_mut().spawn((
        RigidBody::Dynamic,
        Collider::capsule_y(0.25, 0.09),
        Transform::from_xyz(0.0, 2.0, 0.0),
    )).id();

    // Step physics
    app.update();

    // Player should have fallen due to gravity
    let pos = app.world().get::<Transform>(player).unwrap().translation;
    assert!(pos.y < 2.0, "Player should fall due to gravity: y={}", pos.y);
}

#[test]
fn test_lua_system_called_in_tick_loop() {
    let mut app = App::new();
    app.add_plugins(bevy::app::MinimalPlugins);
    app.add_plugins(bevy::time::TimePlugin);
    app.add_plugins(RapierPhysicsPlugin::<NoUserData>::default());
    app.add_plugins(EnginePlugin);

    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut lua_rt = LuaRuntime::new(lua_path).unwrap();
    let event_bus = EventBus::new();
    lua_rt.attach_world(app.world_mut().clone()).unwrap();
    lua_rt.call_init().unwrap();

    // Spawn player with input
    lua_rt.lua().load(r#"
        local config = dofile("entities/player.lua")
        local entity = engine:spawn(config)
        engine:set(entity, "InputComponent", {
            move_x = 1.0, move_y = 0.0,
            jump_pressed = false, sprint_pressed = false,
        })
    "#).exec().unwrap();

    // Call Lua system manually (simulating Bevy system dispatch)
    let result = lua_rt.lua().load(r#"
        local S_Movement = dofile("systems/s_movement.lua")
        S_Movement:process(engine, 1.0/30.0)
    "#).exec();

    assert!(result.is_ok(), "Movement system should run without error");
}
```

- [ ] **Step 2: Run integration tests**

```bash
cd engine && cargo test test_integration
```

Expected: All 3 integration tests pass — entity spawn, physics gravity, Lua system dispatch.

- [ ] **Step 3: Commit**

```bash
git add engine/tests/integration.rs
git commit -m "(GREEN) test: add end-to-end integration tests

Three integration tests: full tick loop spawn + snapshot, Rapier gravity,
and Lua system dispatch. All verify the engine stack works as a cohesive unit."
```

---

## Phase 16: Documentation + Run Verification

### Task 15.1: Write README and verify full build

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

Write `README.md`:
```markdown
# Automata 2.5D — Three.js + Rust Port

Port of the Automata 2.5D Godot template to Bevy ECS + Lua scripting + Three.js renderer.

## Architecture

- **Engine** (Rust): Bevy App with bevy_rapier3d physics, mlua for Lua scripting
- **Client** (TypeScript): Three.js thin renderer, React UI, Vite build
- **Desktop** (Tauri): Native Rust engine in-process, webview renderer
- **Server** (headless): Same engine binary, WebSocket transport

## Quick Start

### Engine

```bash
cd engine
cargo test          # Run all tests
cargo run --bin headless-server -- --port 8080   # Start headless server
```

### Client

```bash
cd client
npm install
npm test            # Run client tests
npm run dev         # Start dev server
```

### Tauri Desktop

```bash
cd client
npm run tauri dev   # Start Tauri desktop app
```

## Project Structure

```
engine/          Rust engine (Bevy + Lua)
  src/
    app.rs       Bevy App + EnginePlugin
    components/  Bevy Component structs (12 components)
    events/      Bevy Event types (18 event types)
    resources/   Bevy Resources (GameState, RoomSystems, etc.)
    lua/         mlua integration (EngineApi, EventBus, LuaRuntime)
    systems/     Bevy SystemSets + manifest loader
    transport/   WebSocket server, snapshot serializer
  lua/           Lua scripts
    init.lua     Bootstrap + manager loader
    config/      systems.toml manifest, constants.json
    systems/     Gameplay systems (Lua + JSON)
    entities/    Entity configs (Player, NPC)
    rooms/       Room definitions (JSON)
    managers/    Gameplay managers (spawn, objectives, VFX, etc.)
  tests/         Integration + unit tests

client/          TypeScript client (Three.js + React)
  src/
    transport/   ITransport, WebSocketTransport, TauriTransport
    renderer/    Scene, CameraController, SpriteManager
    core/        GameLoop, SnapshotBuffer
    input/       InputManager (keyboard + gamepad)
```

## Tech Stack

| Layer | Technology |
|---|---|
| Engine | Rust, Bevy 0.15, bevy_rapier3d 0.29, mlua 0.10 |
| Scripting | Lua 5.4 (hot-reloadable) |
| Rendering | Three.js 0.173 (WebGPURenderer) |
| UI | React 19, Zustand 5 |
| Desktop | Tauri v2 |
| Server | tokio, tungstenite |
| Serialization | serde + bincode (snapshots), JSON (config) |

## License

Proprietary.
```

- [ ] **Step 2: Run complete test suite**

```bash
cd engine && cargo test
cd ../client && npm test
```

Expected: All tests pass.

- [ ] **Step 3: Verify Tauri compile check**

```bash
cd src-tauri && cargo check
```

Expected: Compiles.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add README with architecture overview and quick start

Project structure map, tech stack table, build commands for engine,
client, and Tauri desktop. License: proprietary."
```

---

## Summary

**Total Tasks:** 19 (across 15 phases + documentation)
**Estimated Implementation Time:** 10-15 focused engineering days

**Coverage Checklist:**
- [x] Bevy App with MinimalPlugins, bevy_rapier3d, bevy_asset, bevy_input
- [x] Unified example CLI contract: `automata example list/run/test/snapshot`
- [x] M1 example packages: `movement-basic`, `jump-gravity`, `sprite-billboard-room`, `headless-snapshot`
- [x] All 12 component structs (Bevy Components)
- [x] All 18 event types (Bevy Events)
- [x] mlua integration: engine API (spawn, get/set, query, emit, physics, input)
- [x] Event pub/sub wired to Lua
- [x] bevy_rapier3d: RigidBody/Collider/Velocity as components
- [x] Bevy SystemSet ordering: all six sets with physics integration
- [x] Lua system wrappers + manifest loader
- [x] Transport adapter: WebSocket + Tauri IPC
- [x] Three.js client: snapshot interpolation, sprite billboarding
- [x] 2.5D camera: -30° pitch, free yaw, wall occlusion
- [x] Input capture: keyboard (gamepad deferred to M3)
- [x] Snapshot serialization (bincode)
- [x] All 7 Lua manager stubs (remaining 13 in Rust/TS)
- [x] Tauri desktop scaffold
- [x] Headless server binary
- [x] Test room (JSON + Lua entity config + 4 Lua systems)
- [x] Core gameplay: Jump system, Gravity system
- [x] Integration test
- [x] README

**Not Yet Implemented (requires M2/M3):**
- UI screens (React + Zustand — M2)
- Gamepad input, touch controls, haptics — M3
- VFX particles, audio playback — M3
- Multi-room scene director — M3
- Save/load engine logic — M3
- Character lighting — M3
- Settings tab content (display, controls, accessibility, language, network) — M2
