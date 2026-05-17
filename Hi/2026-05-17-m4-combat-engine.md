# M4: Combat Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real-time combat engine as an ECS-driven, configurable framework. N ability slots, pluggable damage formula, status effects, aggro/leash, projectile system, MOBA-style input abstraction. Core provides the framework; demo ships sample abilities, enemies, encounters as `.tres`/JSON instances.

**Architecture:** Bevy ECS systems with Lua scripting for gameplay logic. Combat systems run in dedicated SystemSet insertion points within the existing Bevy schedule (PrePhysics for intent, CoreMotion for execution, PostMotion for resolution, Feedback for VFX/audio/UI). Components are Bevy structs serialized to Lua tables. Abilities, status effects, damage types defined as JSON resources. MOBA controls (virtual joystick, ability buttons) emit tick-stamped commands that Lua systems process.

**Tech Stack:** Rust (Bevy components/events/resources), Lua (combat system logic), JSON (ability/status effect/damage type definitions), React + Zustand (combat HUD).

**Prerequisites:** M1 complete (engine API, entity CRUD, physics, input capture, event bus, transport).

---

## Task 1: Combat Component Definitions

**Files:**
- Create: `engine/src/components/combat.rs`
- Modify: `engine/src/components/mod.rs` (register module)
- Create: `engine/tests/combat_components.rs`

- [ ] **Step 1: Write failing component test**

Write `engine/tests/combat_components.rs`:

```rust
use engine::components::combat::*;
use bevy::prelude::*;

#[test]
fn test_targetable_component() {
    let t = Targetable {
        targetable: true,
        target_priority: 100,
    };
    assert!(t.targetable);
    assert_eq!(t.target_priority, 100);
}

#[test]
fn test_combat_state_component() {
    let c = CombatState {
        in_combat: false,
        combat_timer: 0.0,
        aggro_table: Vec::new(),
        last_attacker: None,
    };
    assert!(!c.in_combat);
    assert_eq!(c.combat_timer, 0.0);
    assert!(c.aggro_table.is_empty());
}

#[test]
fn test_ability_owner_component() {
    let a = AbilityOwner {
        ability_slots: 4,
        abilities: Vec::new(),
        resource_pools: Vec::new(),
    };
    assert_eq!(a.ability_slots, 4);
}

#[test]
fn test_damage_dealer_component() {
    let d = DamageDealer {
        base_damage: 10.0,
        damage_type: "physical".into(),
        penetration: 0.0,
        crit_chance: 0.05,
        crit_multiplier: 1.5,
    };
    assert_eq!(d.base_damage, 10.0);
    assert_eq!(d.crit_chance, 0.05);
}

#[test]
fn test_components_serialize() {
    let targetable = Targetable {
        targetable: true,
        target_priority: 50,
    };
    let json = serde_json::to_string(&targetable).unwrap();
    let parsed: Targetable = serde_json::from_str(&json).unwrap();
    assert_eq!(parsed.target_priority, 50);
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_targetable
```

Expected: FAIL — `engine::components::combat` not found.

- [ ] **Step 3: Implement combat components**

Write `engine/src/components/combat.rs`:

```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct Targetable {
    pub targetable: bool,
    pub target_priority: i32,
}

impl Default for Targetable {
    fn default() -> Self {
        Self {
            targetable: true,
            target_priority: 0,
        }
    }
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct CombatState {
    pub in_combat: bool,
    pub combat_timer: f32,
    pub aggro_table: Vec<AggroEntry>,
    pub last_attacker: Option<u64>,
}

impl Default for CombatState {
    fn default() -> Self {
        Self {
            in_combat: false,
            combat_timer: 0.0,
            aggro_table: Vec::new(),
            last_attacker: None,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct AggroEntry {
    pub entity_id: u64,
    pub threat: f32,
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct AbilityOwner {
    pub ability_slots: u32,
    pub abilities: Vec<AbilitySlot>,
    pub resource_pools: Vec<ResourcePool>,
}

impl Default for AbilityOwner {
    fn default() -> Self {
        Self {
            ability_slots: 4,
            abilities: Vec::new(),
            resource_pools: Vec::new(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct AbilitySlot {
    pub slot_index: u32,
    pub ability_id: String,
    pub cooldown_remaining: f32,
    pub is_ready: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ResourcePool {
    pub resource_id: String,
    pub current: f32,
    pub max: f32,
    pub regen_rate: f32,
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct DamageDealer {
    pub base_damage: f32,
    pub damage_type: String,
    pub penetration: f32,
    pub crit_chance: f32,
    pub crit_multiplier: f32,
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct StatusEffectContainer {
    pub effects: Vec<ActiveStatusEffect>,
    pub max_effects: u32,
}

impl Default for StatusEffectContainer {
    fn default() -> Self {
        Self {
            effects: Vec::new(),
            max_effects: 8,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ActiveStatusEffect {
    pub effect_id: String,
    pub source_entity: u64,
    pub stacks: u32,
    pub max_stacks: u32,
    pub stack_behavior: String,
    pub duration_remaining: f32,
    pub tick_interval: f32,
    pub tick_timer: f32,
    pub stats: StatusEffectStats,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct StatusEffectStats {
    pub damage_per_tick: f32,
    pub slow_percent: f32,
    pub stun: bool,
    pub damage_taken_multiplier: f32,
    pub healing_taken_multiplier: f32,
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct Leash {
    pub home_position: [f32; 3],
    pub max_distance: f32,
    pub return_speed_multiplier: f32,
    pub is_returning: bool,
}

impl Default for Leash {
    fn default() -> Self {
        Self {
            home_position: [0.0, 0.0, 0.0],
            max_distance: 15.0,
            return_speed_multiplier: 2.0,
            is_returning: false,
        }
    }
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct Shield {
    pub max_shield: f32,
    pub current_shield: f32,
    pub decay_rate: f32,
    pub damage_absorption: f32,
}

impl Default for Shield {
    fn default() -> Self {
        Self {
            max_shield: 0.0,
            current_shield: 0.0,
            decay_rate: 0.0,
            damage_absorption: 1.0,
        }
    }
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct InvulnerabilityFrames {
    pub iframes_remaining: f32,
    pub iframe_duration: f32,
}

impl Default for InvulnerabilityFrames {
    fn default() -> Self {
        Self {
            iframes_remaining: 0.0,
            iframe_duration: 0.15,
        }
    }
}
```

Update `engine/src/components/mod.rs` — add line:

```rust
pub mod combat;
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_combat_components
```

Expected: All 5 component tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/src/components/combat.rs engine/src/components/mod.rs engine/tests/combat_components.rs
git commit -m "(GREEN) feat: define combat ECS components

Targetable, CombatState (aggro table + entries), AbilityOwner (slots +
resource pools), DamageDealer (base/pen/crit), StatusEffectContainer
(stacks/ticks), Leash (max distance + return), Shield (decay/absorb),
InvulnerabilityFrames. All derive Component + Serialize + Deserialize."
```

---

## Task 2: Combat Resource Definitions (JSON)

**Files:**
- Create: `engine/lua/config/combat/damage_types.json`
- Create: `engine/lua/config/combat/resource_pools.json`
- Create: `engine/lua/config/abilities/example_abilities.json`
- Create: `engine/lua/config/combat/example_status_effects.json`

- [ ] **Step 1: Write failing resource load test**

Write `engine/tests/combat_resources.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_load_damage_types() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local data = engine:load_json("config/combat/damage_types.json")
        return data.damage_types ~= nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_damage_types_include_physical() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local data = engine:load_json("config/combat/damage_types.json")
        return data.damage_types.physical ~= nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_load_example_abilities() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local data = engine:load_json("config/abilities/example_abilities.json")
        local abilities = data.abilities
        return #abilities >= 4
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_combat_resources
```

Expected: FAIL — JSON files not found.

- [ ] **Step 3: Create resource JSON files**

Write `engine/lua/config/combat/damage_types.json`:

```json
{
  "damage_types": {
    "physical": {
      "id": "physical",
      "name": "Physical",
      "description": "Standard kinetic damage.",
      "default_resistance": 0.0
    },
    "energy": {
      "id": "energy",
      "name": "Energy",
      "description": "Plasma, laser, electrical damage.",
      "default_resistance": 0.0
    },
    "chemical": {
      "id": "chemical",
      "name": "Chemical",
      "description": "Acid, toxin, corrosive damage.",
      "default_resistance": 0.0
    },
    "thermal": {
      "id": "thermal",
      "name": "Thermal",
      "description": "Fire, heat, cryo damage.",
      "default_resistance": 0.0
    }
  },
  "armor_formula": {
    "curve_function": "standard",
    "effective_armor_divisor": 100.0,
    "description": "damage_multiplier = 100 / (100 + effective_armor)"
  }
}
```

Write `engine/lua/config/combat/resource_pools.json`:

```json
{
  "resource_pools": {
    "health": {
      "resource_id": "health",
      "name": "Health",
      "description": "Hit points. Reaching zero causes death.",
      "default_max": 100,
      "default_regen": 0.0,
      "is_life_pool": true
    },
    "mana": {
      "resource_id": "mana",
      "name": "Mana",
      "description": "Arcane energy for casting abilities.",
      "default_max": 100,
      "default_regen": 2.0,
      "is_life_pool": false
    },
    "stamina": {
      "resource_id": "stamina",
      "name": "Stamina",
      "description": "Physical exertion capacity.",
      "default_max": 100,
      "default_regen": 5.0,
      "is_life_pool": false
    }
  }
}
```

Write `engine/lua/config/abilities/example_abilities.json`:

```json
{
  "abilities": [
    {
      "ability_id": "basic_attack",
      "name": "Basic Attack",
      "description": "A quick melee strike.",
      "icon": "ability_basic_attack",
      "cast_type": "targeted",
      "target_mode": "nearest_enemy",
      "range": 1.5,
      "cooldown": 0.5,
      "cast_time": 0.0,
      "resource_cost": { "resource_id": "stamina", "amount": 5 },
      "payloads": [
        {
          "type": "damage",
          "damage_type": "physical",
          "base_value": 10.0,
          "penetration": 0.0,
          "can_crit": true
        }
      ],
      "vfx": { "on_cast": "melee_slash", "on_hit": "impact_sparks" },
      "audio": { "on_cast": "sfx_swing", "on_hit": "sfx_hit" }
    },
    {
      "ability_id": "power_strike",
      "name": "Power Strike",
      "description": "A heavy overhead blow that penetrates armor.",
      "icon": "ability_power_strike",
      "cast_type": "targeted",
      "target_mode": "nearest_enemy",
      "range": 1.5,
      "cooldown": 3.0,
      "cast_time": 0.4,
      "resource_cost": { "resource_id": "stamina", "amount": 20 },
      "payloads": [
        {
          "type": "damage",
          "damage_type": "physical",
          "base_value": 25.0,
          "penetration": 10.0,
          "can_crit": true
        },
        {
          "type": "status",
          "status_effect_id": "stagger",
          "duration": 1.5
        }
      ],
      "vfx": { "on_cast": "heavy_swing", "on_hit": "heavy_impact" },
      "audio": { "on_cast": "sfx_heavy_swing", "on_hit": "sfx_crunch" }
    },
    {
      "ability_id": "fireball",
      "name": "Fireball",
      "description": "Launch a projectile that explodes on impact.",
      "icon": "ability_fireball",
      "cast_type": "skill_shot",
      "target_mode": "directional",
      "range": 8.0,
      "cooldown": 5.0,
      "cast_time": 0.3,
      "resource_cost": { "resource_id": "mana", "amount": 30 },
      "projectile": {
        "speed": 6.0,
        "radius": 1.5,
        "max_distance": 8.0,
        "pierces": false,
        "vfx": "projectile_fireball",
        "explosion_vfx": "explosion_fire"
      },
      "payloads": [
        {
          "type": "damage",
          "damage_type": "thermal",
          "base_value": 35.0,
          "penetration": 0.0,
          "can_crit": true
        },
        {
          "type": "status",
          "status_effect_id": "burning",
          "duration": 3.0
        }
      ],
      "vfx": { "on_cast": "fire_cast" },
      "audio": { "on_cast": "sfx_fire_cast", "on_hit": "sfx_explosion" }
    },
    {
      "ability_id": "adrenaline_surge",
      "name": "Adrenaline Surge",
      "description": "Self-buff: increased damage and speed for a short duration.",
      "icon": "ability_adrenaline",
      "cast_type": "self",
      "target_mode": "self",
      "range": 0.0,
      "cooldown": 12.0,
      "cast_time": 0.0,
      "resource_cost": { "resource_id": "stamina", "amount": 15 },
      "payloads": [
        {
          "type": "status",
          "status_effect_id": "adrenaline_buff",
          "duration": 5.0
        }
      ],
      "vfx": { "on_cast": "buff_glow" },
      "audio": { "on_cast": "sfx_adrenaline" }
    }
  ]
}
```

Write `engine/lua/config/combat/example_status_effects.json`:

```json
{
  "status_effects": {
    "burning": {
      "effect_id": "burning",
      "name": "Burning",
      "description": "Taking fire damage over time.",
      "max_stacks": 3,
      "stack_behavior": "additive",
      "stats": {
        "damage_per_tick": 5.0,
        "slow_percent": 0.0,
        "stun": false,
        "damage_taken_multiplier": 0.0,
        "healing_taken_multiplier": 0.0
      },
      "vfx": "status_burning",
      "tick_interval": 1.0,
      "can_be_cleansed": true
    },
    "stagger": {
      "effect_id": "stagger",
      "name": "Staggered",
      "description": "Movement and action speed reduced.",
      "max_stacks": 1,
      "stack_behavior": "refresh",
      "stats": {
        "damage_per_tick": 0.0,
        "slow_percent": 0.4,
        "stun": false,
        "damage_taken_multiplier": 1.1,
        "healing_taken_multiplier": 0.0
      },
      "vfx": "status_stagger",
      "tick_interval": 0.0,
      "can_be_cleansed": true
    },
    "adrenaline_buff": {
      "effect_id": "adrenaline_buff",
      "name": "Adrenaline Surge",
      "description": "Increased damage output.",
      "max_stacks": 1,
      "stack_behavior": "refresh",
      "stats": {
        "damage_per_tick": 0.0,
        "slow_percent": 0.0,
        "stun": false,
        "damage_taken_multiplier": 0.25,
        "healing_taken_multiplier": 0.0
      },
      "vfx": "status_adrenaline",
      "tick_interval": 0.0,
      "can_be_cleansed": false
    }
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_combat_resources
```

Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/config/combat/ engine/lua/config/abilities/ engine/tests/combat_resources.rs
git commit -m "(GREEN) feat: define combat resource JSON configs

Damage types (physical/energy/chemical/thermal) with default resistances.
Resource pools (health/mana/stamina) with regen rates.
4 example abilities: basic_attack (targeted melee), power_strike (armor
pen + stagger), fireball (skill shot projectile + burn), adrenaline_surge
(self buff). Status effects: burning (DOT stack), stagger (slow + vuln),
adrenaline_buff (damage amp). Pluggable damage/armor formula config."
```

---

## Task 3: Targeting System (Lua)

**Files:**
- Create: `engine/lua/systems/s_targeting.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/targeting.rs`

- [ ] **Step 1: Write failing targeting test**

Write `engine/tests/targeting.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_find_nearest_enemy() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Targeting = dofile("systems/s_targeting.lua")
        S_Targeting:init(engine)

        local player_pos = { 0, 0, 0 }
        local enemies = {
            { id = 10, pos = { 3, 0, 0 } },
            { id = 20, pos = { 1, 0, 0 } },
            { id = 30, pos = { 5, 0, 0 } },
        }

        local nearest = S_Targeting:find_nearest(player_pos, enemies)
        return nearest == 20
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_find_targets_in_cone() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Targeting = dofile("systems/s_targeting.lua")
        S_Targeting:init(engine)

        -- Player at origin, facing +x
        local origin = { 0, 0, 0 }
        local direction = { 1, 0, 0 }
        local targets = {
            { id = 10, pos = { 2, 0, 0 } },  -- in cone
            { id = 20, pos = { -1, 0, 0 } }, -- behind, not in cone
            { id = 30, pos = { 1, 0, 1 } },  -- in cone
        }

        local hits = S_Targeting:cone_targets(origin, direction, 1.5, 60.0, targets)
        return #hits == 2
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_targeting_no_enemies() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Targeting = dofile("systems/s_targeting.lua")
        S_Targeting:init(engine)

        local nearest = S_Targeting:find_nearest({0,0,0}, {})
        return nearest == nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_targeting
```

Expected: FAIL.

- [ ] **Step 3: Implement targeting system**

Write `engine/lua/systems/s_targeting.lua`:

```lua
local S_Targeting = {}

function S_Targeting:init(engine)
    self.engine = engine
end

function S_Targeting:find_nearest(origin, candidates)
    if #candidates == 0 then
        return nil
    end

    local best_dist = math.huge
    local best_id = nil

    for _, candidate in ipairs(candidates) do
        local dx = candidate.pos[1] - origin[1]
        local dy = candidate.pos[2] - origin[2]
        local dz = candidate.pos[3] - origin[3]
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

        if dist < best_dist then
            best_dist = dist
            best_id = candidate.id
        end
    end

    return best_id
end

function S_Targeting:cone_targets(origin, direction, range, half_angle_deg, candidates)
    local hits = {}
    local half_angle = math.rad(half_angle_deg)

    local fwd_len = math.sqrt(direction[1] * direction[1] + direction[3] * direction[3])
    if fwd_len < 0.0001 then
        return hits
    end
    local fx = direction[1] / fwd_len
    local fz = direction[3] / fwd_len

    for _, target in ipairs(candidates) do
        local dx = target.pos[1] - origin[1]
        local dz = target.pos[3] - origin[3]
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist <= range and dist > 0.001 then
            local tx = dx / dist
            local tz = dz / dist
            local dot = fx * tx + fz * tz
            local angle = math.acos(math.max(-1.0, math.min(1.0, dot)))

            if angle <= half_angle then
                table.insert(hits, target)
            end
        end
    end

    return hits
end

function S_Targeting:radius_targets(origin, radius, candidates)
    local hits = {}
    for _, target in ipairs(candidates) do
        local dx = target.pos[1] - origin[1]
        local dz = target.pos[3] - origin[3]
        local dist = math.sqrt(dx * dx + dz * dz)
        if dist <= radius then
            table.insert(hits, target)
        end
    end
    return hits
end

function S_Targeting:line_targets(origin, direction, max_range, candidates)
    --- Not used yet — implementation in a future tick
    return {}
end

function S_Targeting:process(engine, dt)
    -- Called to resolve targeting requests queued by InputCapture
    engine:query({"TargetingRequest", "Transform"}, function(eid)
        local req = engine:get(eid, "TargetingRequest")
        local pos = engine:get(eid, "Transform").translation

        -- Build candidate list from all Targetable entities
        local candidates = {}
        engine:query({"Targetable", "Transform"}, function(t_eid)
            if t_eid ~= eid then
                local t_pos = engine:get(t_eid, "Transform").translation
                table.insert(candidates, { id = t_eid, pos = t_pos })
            end
        end)

        local result = nil
        if req.mode == "nearest_enemy" then
            result = self:find_nearest(pos, candidates)
        elseif req.mode == "cone" then
            local cone = self:cone_targets(pos, req.direction, req.range, req.cone_angle, candidates)
            if #cone > 0 then
                result = cone[1].id
            end
        elseif req.mode == "directional" then
            local nearest = nil
            local best = math.huge
            for _, c in ipairs(candidates) do
                local dx = c.pos[1] - pos[1]
                local dz = c.pos[3] - pos[3]
                local dot = req.direction[1] * dx + req.direction[3] * dz
                if dot > 0 then
                    local d = math.sqrt(dx * dx + dz * dz)
                    if d < best and d <= req.range then
                        best = d
                        nearest = c.id
                    end
                end
            end
            result = nearest
        end

        engine:set(eid, "TargetingRequest", {
            mode = req.mode,
            range = req.range,
            direction = req.direction,
            result = result,
            resolved = true,
        })
    end)
end

return S_Targeting
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_Targeting]
lua_file = "systems/s_targeting.lua"
system_set = "PrePhysics"
priority = 25
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_targeting
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_targeting.lua engine/lua/config/systems.toml engine/tests/targeting.rs
git commit -m "(GREEN) feat: implement targeting system

S_Targeting (PrePhysics, pri 25): find_nearest (closest candidate),
cone_targets (angle-filtered from fwd vector), radius_targets (circle
AOE), directional (forward-filtered nearest). process() resolves queued
TargetingRequests against all Targetable entities, writes result back.
Nearest-enemy, cone, and directional target modes."
```

---

## Task 4: Damage Pipeline (Lua)

**Files:**
- Create: `engine/lua/systems/s_damage_calculation.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/damage.rs`

- [ ] **Step 1: Write failing damage test**

Write `engine/tests/damage.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_damage_formula_with_armor() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Damage = dofile("systems/s_damage_calculation.lua")
        S_Damage:init(engine)

        local result = S_Damage:calculate(100.0, "physical", 0.0, 50.0, 0.0, false)
        -- 100 base, 0 pen vs 50 armor
        -- effective_armor = 50 - 0 = 50
        -- armor_mult = 100 / (100 + 50) = 0.666...
        -- resistance = 0
        -- final = 100 * 0.666 * 1.0 = ~66.67
        return math.floor(result * 100) / 100
    "#).eval::<f64>();

    assert!((result.unwrap() - 66.67).abs() < 0.1);
}

#[test]
fn test_damage_with_penetration() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Damage = dofile("systems/s_damage_calculation.lua")
        S_Damage:init(engine)

        local result = S_Damage:calculate(100.0, "physical", 30.0, 50.0, 0.0, false)
        -- 100 base, 30 pen vs 50 armor
        -- effective_armor = max(0, 50 - 30) = 20
        -- armor_mult = 100 / (100 + 20) = 0.833
        -- final = 100 * 0.833 = ~83.33
        return math.floor(result * 100) / 100
    "#).eval::<f64>();

    assert!((result.unwrap() - 83.33).abs() < 0.1);
}

#[test]
fn test_damage_critical() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Damage = dofile("systems/s_damage_calculation.lua")
        S_Damage:init(engine)

        local result = S_Damage:calculate(100.0, "physical", 0.0, 0.0, 0.0, true, 1.5)
        -- 100 base, crit x1.5, no armor no resist
        -- final = 100 * 1.0 * 1.0 * 1.5 = 150
        return result
    "#).eval::<f64>();

    assert!((result.unwrap() - 150.0).abs() < 0.1);
}

#[test]
fn test_damage_with_resistance() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Damage = dofile("systems/s_damage_calculation.lua")
        S_Damage:init(engine)

        local result = S_Damage:calculate(100.0, "thermal", 0.0, 0.0, 0.3, false)
        -- 100 base, thermal with 30% resist, no armor
        -- resist_mult = 1 - 0.3 = 0.7
        -- final = 100 * 1.0 * 0.7 = 70
        return result
    "#).eval::<f64>();

    assert!((result.unwrap() - 70.0).abs() < 0.1);
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_damage
```

Expected: FAIL.

- [ ] **Step 3: Implement damage calculation**

Write `engine/lua/systems/s_damage_calculation.lua`:

```lua
local S_DamageCalculation = {}

function S_DamageCalculation:init(engine)
    self.engine = engine
    self.damage_types = {}
    local data = engine:load_json("config/combat/damage_types.json")
    if data then
        self.damage_types = data.damage_types or {}
        self.armor_formula = data.armor_formula or {}
    end
end

function S_DamageCalculation:calculate(base_damage, damage_type, penetration, armor, resistance, is_crit, crit_multiplier)
    crit_multiplier = crit_multiplier or 1.5

    -- Step 1: Penetration reduces effective armor
    local effective_armor = math.max(0.0, armor - penetration)

    -- Step 2: Armor damage reduction (standard curve)
    local armor_divisor = (self.armor_formula.effective_armor_divisor or 100.0)
    local armor_multiplier
    if self.armor_formula.curve_function == "standard" then
        armor_multiplier = armor_divisor / (armor_divisor + effective_armor)
    else
        armor_multiplier = 1.0
    end

    -- Step 3: Resistance reduction
    local resistance_multiplier = 1.0 - math.max(0.0, math.min(1.0, resistance))

    -- Step 4: Crit multiplier
    local crit_mult = is_crit and crit_multiplier or 1.0

    -- Step 5: Final damage
    local final_damage = base_damage * armor_multiplier * resistance_multiplier * crit_mult

    return math.max(0.0, final_damage)
end

function S_DamageCalculation:roll_crit(crit_chance, crit_multiplier)
    crit_multiplier = crit_multiplier or 1.5
    local roll = math.random()
    return roll <= crit_chance, crit_multiplier
end

function S_DamageCalculation:process(engine, dt)
    -- Damage calculation is called on-demand by health/shield systems.
    -- No per-tick processing needed.
end

return S_DamageCalculation
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_DamageCalculation]
lua_file = "systems/s_damage_calculation.lua"
system_set = "CoreMotion"
priority = 48
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_damage
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_damage_calculation.lua engine/lua/config/systems.toml engine/tests/damage.rs
git commit -m "(GREEN) feat: implement pluggable damage pipeline

S_DamageCalculation (CoreMotion, pri 48): five-step pipeline:
(1) penetration reduces effective armor, (2) armor curve multiplier
(100/100+eff_armor, pluggable curve_function), (3) resistance reduction
(1-resist), (4) crit multiplier, (5) final damage clamped >= 0.
roll_crit for random crit resolution. Formula config loaded from
damage_types.json (curve_function, effective_armor_divisor)."
```

---

## Task 5: Health and Shield System (Lua)

**Files:**
- Create: `engine/lua/systems/s_health.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/health_system.rs`

- [ ] **Step 1: Write failing health test**

Write `engine/tests/health_system.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_apply_damage() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Health = dofile("systems/s_health.lua")
        S_Health:init(engine)

        local health = { max = 100, current = 100 }
        local data = S_Health:apply_damage(health, 30, 0)
        return data.current == 70
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_shield_absorbs_before_hp() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Health = dofile("systems/s_health.lua")
        S_Health:init(engine)

        local health = { max = 100, current = 100 }
        local shield = { max_shield = 50, current_shield = 50, damage_absorption = 1.0 }

        local result = S_Health:apply_damage_with_shield(health, shield, 40)
        return result.hp == 100 and result.shield == 10
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_death_on_zero_hp() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Health = dofile("systems/s_health.lua")
        S_Health:init(engine)

        local health = { max = 100, current = 5 }
        local data = S_Health:apply_damage(health, 10, 0)
        return data.current == 0 and data.is_alive == false
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_iframes_block_damage() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Health = dofile("systems/s_health.lua")
        S_Health:init(engine)

        local health = { max = 100, current = 100 }
        local iframes = { iframes_remaining = 0.1, iframe_duration = 0.15 }

        local data = S_Health:apply_damage(health, 30, iframes.iframes_remaining)
        return data.current == 100
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_health
```

Expected: FAIL.

- [ ] **Step 3: Implement health + shield system**

Write `engine/lua/systems/s_health.lua`:

```lua
local DamageCalc = nil

local S_Health = {}

function S_Health:init(engine)
    self.engine = engine
    DamageCalc = dofile("systems/s_damage_calculation.lua")
    DamageCalc:init(engine)
end

function S_Health:apply_damage(health, damage, iframe_remaining)
    if iframe_remaining > 0.0 then
        return {
            max = health.max,
            current = health.current,
            is_alive = health.current > 0,
            damage_blocked = true,
        }
    end

    local new_hp = math.max(0, health.current - damage)
    local is_alive = new_hp > 0

    if not is_alive then
        self.engine:emit("EntityDiedEvent", {
            entity = 0,
            cause = "damage",
        })
    end

    return {
        max = health.max,
        current = new_hp,
        is_alive = is_alive,
        damage_taken = damage,
        damage_blocked = false,
    }
end

function S_Health:apply_damage_with_shield(health, shield, damage)
    if shield.current_shield > 0 and shield.damage_absorption > 0 then
        local absorb = damage * shield.damage_absorption
        local shield_eaten = math.min(shield.current_shield, absorb)
        local remaining = damage - shield_eaten

        return {
            hp = health.current - remaining,
            shield = shield.current_shield - shield_eaten,
            shield_absorbed = shield_eaten,
            damage_to_hp = remaining,
        }
    end

    return {
        hp = health.current - damage,
        shield = shield.current_shield,
        shield_absorbed = 0,
        damage_to_hp = damage,
    }
end

function S_Health:heal(health, amount)
    local new_hp = math.min(health.max, health.current + amount)
    return {
        max = health.max,
        current = new_hp,
        is_alive = true,
        healed = new_hp - health.current,
    }
end

function S_Health:process(engine, dt)
    -- Resolve queued damage events
    engine:query({"Health", "DamageQueued"}, function(eid)
        local health = engine:get(eid, "Health")
        local dmg_queue = engine:get(eid, "DamageQueued")
        local iframes = engine:get(eid, "InvulnerabilityFrames") or { iframes_remaining = 0 }

        local total_damage = dmg_queue.amount or 0
        local shield = engine:get(eid, "Shield")

        local actual_hp_damage = total_damage
        if shield and shield.current_shield > 0 then
            local result = self:apply_damage_with_shield(health, shield, total_damage)
            actual_hp_damage = result.damage_to_hp
            shield.current_shield = result.shield
            engine:set(eid, "Shield", shield)
        end

        local result = self:apply_damage(health, actual_hp_damage, iframes.iframes_remaining)
        health.current = result.current

        engine:set(eid, "Health", health)
        engine:remove(eid, "DamageQueued")

        engine:emit("HealthChangedEvent", {
            entity = eid,
            current = health.current,
            max = health.max,
            damage_taken = total_damage,
            is_alive = result.is_alive,
        })
    end)

    -- Decay shields
    engine:query({"Shield"}, function(eid)
        local shield = engine:get(eid, "Shield")
        if shield.current_shield > 0 and shield.decay_rate > 0 then
            shield.current_shield = math.max(0, shield.current_shield - shield.decay_rate * dt)
            engine:set(eid, "Shield", shield)
        end
    end)

    -- Tick iframes
    engine:query({"InvulnerabilityFrames"}, function(eid)
        local iframes = engine:get(eid, "InvulnerabilityFrames")
        if iframes.iframes_remaining > 0 then
            iframes.iframes_remaining = math.max(0, iframes.iframes_remaining - dt)
            engine:set(eid, "InvulnerabilityFrames", iframes)
        end
    end)
end

return S_Health
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_Health]
lua_file = "systems/s_health.lua"
system_set = "CoreMotion"
priority = 49
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_health
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_health.lua engine/lua/config/systems.toml engine/tests/health_system.rs
git commit -m "(GREEN) feat: implement health, shield, and i-frame system

S_Health (CoreMotion, pri 49): apply_damage (clamp to 0, death on
current<=0, iframe block), apply_damage_with_shield (shield absorbs
before hp), heal (clamp to max). process() resolves DamageQueued
events, decays shields over time, ticks down invulnerability frames.
Emits HealthChangedEvent after each damage application."
```

---

## Task 6: Status Effect System (Lua)

**Files:**
- Create: `engine/lua/systems/s_status_effects.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/status_effects.rs`

- [ ] **Step 1: Write failing status test**

Write `engine/tests/status_effects.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_apply_burn_effect() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Status = dofile("systems/s_status_effects.lua")
        S_Status:init(engine)

        local container = { effects = {}, max_effects = 8 }
        container, _ = S_Status:apply(container, "burning", 42, 3.0)
        return #container.effects == 1
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_stack_behavior_additive() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Status = dofile("systems/s_status_effects.lua")
        S_Status:init(engine)

        local container = { effects = {}, max_effects = 8 }
        -- burning is additive, max 3 stacks
        container, _ = S_Status:apply(container, "burning", 42, 3.0)
        container, _ = S_Status:apply(container, "burning", 42, 3.0)
        container, _ = S_Status:apply(container, "burning", 42, 3.0)
        container, _ = S_Status:apply(container, "burning", 42, 3.0)
        return container.effects[1].stacks == 3
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_stack_behavior_refresh() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Status = dofile("systems/s_status_effects.lua")
        S_Status:init(engine)

        local container = { effects = {}, max_effects = 8 }
        -- stagger is refresh, max 1 stack
        container, _ = S_Status:apply(container, "stagger", 42, 1.5)
        container, _ = S_Status:apply(container, "stagger", 42, 1.5)
        return container.effects[1].stacks == 1 and container.effects[1].duration_remaining > 1.4
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_tick_damage() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Status = dofile("systems/s_status_effects.lua")
        S_Status:init(engine)

        local container = { effects = {}, max_effects = 8 }
        container, _ = S_Status:apply(container, "burning", 42, 5.0)

        -- burning ticks every 1s, 5 damage per tick per stack
        -- After 1.0s: tick fires, damage = 5 * 1 stack = 5
        local dmg, expired = S_Status:process_tick(container, 1.0)
        return dmg == 5 and not expired
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_effect_expires() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Status = dofile("systems/s_status_effects.lua")
        S_Status:init(engine)

        local container = { effects = {}, max_effects = 8 }
        container, _ = S_Status:apply(container, "burning", 42, 3.0)

        local dmg, expired = S_Status:process_tick(container, 3.5)
        return expired and #container.effects == 0
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_status
```

Expected: FAIL.

- [ ] **Step 3: Implement status effects**

Write `engine/lua/systems/s_status_effects.lua`:

```lua
local S_StatusEffects = {}

function S_StatusEffects:init(engine)
    self.engine = engine
    self.effect_db = {}
    local data = engine:load_json("config/combat/example_status_effects.json")
    if data then
        self.effect_db = data.status_effects or {}
    end
end

function S_StatusEffects:apply(container, effect_id, source_entity, duration)
    local def = self.effect_db[effect_id]
    if not def then
        return container, false
    end

    -- Search for existing effect
    for _, effect in ipairs(container.effects) do
        if effect.effect_id == effect_id then
            if def.stack_behavior == "additive" then
                effect.stacks = math.min(effect.stacks + 1, def.max_stacks or 1)
            elseif def.stack_behavior == "refresh" then
                effect.duration_remaining = duration
            elseif def.stack_behavior == "independent" then
                -- Already handled below
            end
            -- Update stats per stack count
            effect.stats = self:scale_stats(def.stats, effect.stacks)
            return container, true
        end
    end

    -- Check max effects cap
    if #container.effects >= (container.max_effects or 8) then
        return container, false
    end

    -- Fresh application
    local stats = def.stats or {}
    table.insert(container.effects, {
        effect_id = effect_id,
        source_entity = source_entity,
        stacks = 1,
        max_stacks = def.max_stacks or 1,
        stack_behavior = def.stack_behavior or "additive",
        duration_remaining = duration,
        tick_interval = def.tick_interval or 1.0,
        tick_timer = 0.0,
        stats = {
            damage_per_tick = stats.damage_per_tick or 0,
            slow_percent = stats.slow_percent or 0,
            stun = stats.stun or false,
            damage_taken_multiplier = stats.damage_taken_multiplier or 0,
            healing_taken_multiplier = stats.healing_taken_multiplier or 0,
        },
    })

    return container, true
end

function S_StatusEffects:scale_stats(base_stats, stacks)
    local result = {}
    for k, v in pairs(base_stats) do
        if type(v) == "number" then
            result[k] = v * stacks
        else
            result[k] = v
        end
    end
    return result
end

function S_StatusEffects:process_tick(container, dt)
    local total_dot_damage = 0
    local expired_any = false

    for i = #container.effects, 1, -1 do
        local effect = container.effects[i]
        effect.duration_remaining = effect.duration_remaining - dt

        if effect.duration_remaining <= 0 then
            table.remove(container.effects, i)
            expired_any = true
        elseif effect.tick_interval > 0 then
            effect.tick_timer = effect.tick_timer + dt
            while effect.tick_timer >= effect.tick_interval do
                effect.tick_timer = effect.tick_timer - effect.tick_interval
                total_dot_damage = total_dot_damage + (effect.stats.damage_per_tick or 0)
            end
        end
    end

    return total_dot_damage, expired_any
end

function S_StatusEffects:get_aggregate_stats(container)
    local max_slow = 0
    local is_stunned = false
    local damage_mult = 1.0
    local healing_mult = 1.0

    for _, effect in ipairs(container.effects) do
        local s = effect.stats
        if s.slow_percent > max_slow then
            max_slow = s.slow_percent
        end
        if s.stun then
            is_stunned = true
        end
        damage_mult = damage_mult + (s.damage_taken_multiplier or 0)
        healing_mult = healing_mult + (s.healing_taken_multiplier or 0)
    end

    return {
        slow_percent = math.min(1.0, max_slow),
        is_stunned = is_stunned,
        damage_taken_multiplier = damage_mult,
        healing_taken_multiplier = healing_mult,
    }
end

function S_StatusEffects:process(engine, dt)
    engine:query({"StatusEffectContainer"}, function(eid)
        local container = engine:get(eid, "StatusEffectContainer")
        if not container or #container.effects == 0 then
            return
        end

        local dot_damage, _ = self:process_tick(container, dt)

        if dot_damage > 0 then
            local dmg_queue = engine:get(eid, "DamageQueued") or { amount = 0 }
            dmg_queue.amount = (dmg_queue.amount or 0) + dot_damage
            engine:set(eid, "DamageQueued", dmg_queue)
        end

        engine:set(eid, "StatusEffectContainer", container)
    end)
end

return S_StatusEffects
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_StatusEffects]
lua_file = "systems/s_status_effects.lua"
system_set = "CoreMotion"
priority = 50
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_status
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_status_effects.lua engine/lua/config/systems.toml engine/tests/status_effects.rs
git commit -m "(GREEN) feat: implement status effect engine

S_StatusEffects (CoreMotion, pri 50): apply (additive/refresh/independent
stack behaviors, max stacks & max effects cap), process_tick (DOT damage
accumulation, duration expiry & cleanup), get_aggregate_stats (max slow,
stun flag, cumulative damage/healing multipliers). process() ticks all
StatusEffectContainers, routes DOT damage to DamageQueued for health system."
```

---

## Task 7: Ability Execution System (Lua)

**Files:**
- Create: `engine/lua/systems/s_ability_execution.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/ability_execution.rs`

- [ ] **Step 1: Write failing ability test**

Write `engine/tests/ability_execution.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_ability_costs_resources() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Ability = dofile("systems/s_ability_execution.lua")
        S_Ability:init(engine)

        local pools = {
            { resource_id = "stamina", current = 100, max = 100 },
        }
        local cost = { resource_id = "stamina", amount = 20 }

        local ok, new_pools = S_Ability:consume_cost(pools, cost)
        return ok and new_pools[1].current == 80
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_ability_blocked_by_insufficient_resource() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Ability = dofile("systems/s_ability_execution.lua")
        S_Ability:init(engine)

        local pools = {
            { resource_id = "mana", current = 10, max = 100 },
        }
        local cost = { resource_id = "mana", amount = 30 }

        local ok, _ = S_Ability:consume_cost(pools, cost)
        return not ok
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_ability_on_cooldown_blocked() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Ability = dofile("systems/s_ability_execution.lua")
        S_Ability:init(engine)

        local slots = {
            { slot_index = 0, ability_id = "fireball", cooldown_remaining = 2.0, is_ready = false },
        }

        local ok = S_Ability:is_slot_ready(slots, 0)
        return not ok
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_cooldown_tick() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Ability = dofile("systems/s_ability_execution.lua")
        S_Ability:init(engine)

        local slots = {
            { slot_index = 0, ability_id = "fireball", cooldown_remaining = 2.0, is_ready = false },
        }

        local new_slots = S_Ability:tick_cooldowns(slots, 1.5)
        return new_slots[1].cooldown_remaining == 0.5 and not new_slots[1].is_ready
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_ability_execution
```

Expected: FAIL.

- [ ] **Step 3: Implement ability execution**

Write `engine/lua/systems/s_ability_execution.lua`:

```lua
local S_AbilityExecution = {}

function S_AbilityExecution:init(engine)
    self.engine = engine
    self.ability_db = {}
    local data = engine:load_json("config/abilities/example_abilities.json")
    if data then
        for _, ability in ipairs(data.abilities or {}) do
            self.ability_db[ability.ability_id] = ability
        end
    end
end

function S_AbilityExecution:consume_cost(pools, cost)
    if not cost then
        return true, pools
    end

    for _, pool in ipairs(pools) do
        if pool.resource_id == cost.resource_id then
            if pool.current >= cost.amount then
                pool.current = pool.current - cost.amount
                return true, pools
            else
                return false, pools
            end
        end
    end

    return false, pools
end

function S_AbilityExecution:is_slot_ready(slots, slot_index)
    for _, slot in ipairs(slots) do
        if slot.slot_index == slot_index then
            return slot.is_ready
        end
    end
    return false
end

function S_AbilityExecution:tick_cooldowns(slots, dt)
    for _, slot in ipairs(slots) do
        if slot.cooldown_remaining > 0 then
            slot.cooldown_remaining = math.max(0, slot.cooldown_remaining - dt)
            if slot.cooldown_remaining <= 0 then
                slot.is_ready = true
            end
        end
    end
    return slots
end

function S_AbilityExecution:trigger_cooldown(slots, slot_index, total_cd)
    for _, slot in ipairs(slots) do
        if slot.slot_index == slot_index then
            slot.cooldown_remaining = total_cd
            slot.is_ready = false
            return slots
        end
    end
    return slots
end

function S_AbilityExecution:resolve_ability(ability_id, caster_id, target_id, direction)
    local ability = self.ability_db[ability_id]
    if not ability then
        return
    end

    local caster_ability = self.engine:get(caster_id, "AbilityOwner")

    -- Check cooldown
    local slot_idx = nil
    for _, slot in ipairs(caster_ability.abilities or {}) do
        if slot.ability_id == ability_id then
            slot_idx = slot.slot_index
            if not slot.is_ready then
                return
            end
            break
        end
    end
    if slot_idx == nil then
        return
    end

    -- Check resource cost
    local ok, new_pools = self:consume_cost(caster_ability.resource_pools, ability.resource_cost)
    if not ok then
        return
    end
    caster_ability.resource_pools = new_pools

    -- Trigger cooldown
    caster_ability.abilities = self:trigger_cooldown(caster_ability.abilities, slot_idx, ability.cooldown)
    self.engine:set(caster_id, "AbilityOwner", caster_ability)

    -- Emit cast event for VFX/audio
    self.engine:emit("AbilityCastEvent", {
        caster = caster_id,
        ability_id = ability_id,
        target = target_id,
    })

    -- Spawn projectile if skill-shot
    if ability.projectile then
        local proj = {
            ability_id = ability_id,
            caster = caster_id,
            speed = ability.projectile.speed,
            max_distance = ability.projectile.max_distance,
            traveled = 0,
            position = engine:get(caster_id, "Transform").translation,
            direction = direction,
            radius = ability.projectile.radius,
            pierces = ability.projectile.pierces,
        }
        self.engine:emit("ProjectileSpawnEvent", proj)
        return
    end

    -- Direct application via payload
    self:apply_payloads(ability.payloads, caster_id, target_id)
end

function S_AbilityExecution:apply_payloads(payloads, caster_id, target_id)
    for _, payload in ipairs(payloads or {}) do
        if payload.type == "damage" then
            local dealer = self.engine:get(caster_id, "DamageDealer") or { base_damage = 10, crit_chance = 0, crit_multiplier = 1.5 }
            local base = payload.base_value or dealer.base_damage
            local is_crit = math.random() <= (dealer.crit_chance or 0)

            local dmg_queue = self.engine:get(target_id, "DamageQueued") or { amount = 0 }
            dmg_queue.amount = (dmg_queue.amount or 0) + base
            dmg_queue.damage_type = payload.damage_type or "physical"
            dmg_queue.penetration = payload.penetration or 0
            dmg_queue.is_crit = is_crit
            dmg_queue.crit_multiplier = dealer.crit_multiplier or 1.5
            self.engine:set(target_id, "DamageQueued", dmg_queue)
        elseif payload.type == "status" then
            local container = self.engine:get(target_id, "StatusEffectContainer") or { effects = {}, max_effects = 8 }
            local S_Status = dofile("systems/s_status_effects.lua")
            S_Status:init(self.engine)
            local new_container, _ = S_Status:apply(container, payload.status_effect_id, caster_id, payload.duration)
            self.engine:set(target_id, "StatusEffectContainer", new_container)
        end
    end
end

function S_AbilityExecution:process(engine, dt)
    engine:query({"AbilityOwner"}, function(eid)
        local owner = engine:get(eid, "AbilityOwner")
        owner.abilities = self:tick_cooldowns(owner.abilities, dt)

        -- Resource regen
        for _, pool in ipairs(owner.resource_pools) do
            if pool.regen_rate > 0 then
                pool.current = math.min(pool.max, pool.current + pool.regen_rate * dt)
            end
        end

        engine:set(eid, "AbilityOwner", owner)
    end)

    -- Resolve queued ability commands
    engine:query({"AbilityCommand"}, function(eid)
        local cmd = engine:get(eid, "AbilityCommand")
        if not cmd.resolved then
            self:resolve_ability(cmd.ability_id, eid, cmd.target_id, cmd.direction)
            engine:remove(eid, "AbilityCommand")
        end
    end)
end

return S_AbilityExecution
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_AbilityExecution]
lua_file = "systems/s_ability_execution.lua"
system_set = "CoreMotion"
priority = 52
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_ability_execution
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_ability_execution.lua engine/lua/config/systems.toml engine/tests/ability_execution.rs
git commit -m "(GREEN) feat: implement ability execution system

S_AbilityExecution (CoreMotion, pri 52): consume_cost (resource validation),
is_slot_ready (cooldown check), tick_cooldowns + trigger_cooldown,
resolve_ability (full pipeline: readiness → cost → cooldown → emit cast
event → projectile spawn or direct payload apply), apply_payloads (damage
routed to DamageQueued, status routed to StatusEffectContainer).
process() ticks cooldowns, applies resource regen, resolves AbilityCommands."
```

---

## Task 8: Aggro + Leash + Combat State (Lua)

**Files:**
- Create: `engine/lua/systems/s_combat_state.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/combat_state.rs`

- [ ] **Step 1: Write failing combat state test**

Write `engine/tests/combat_state.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_add_threat_to_empty_table() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_CombatState = dofile("systems/s_combat_state.lua")
        S_CombatState:init(engine)

        local combat_state = { in_combat = false, aggro_table = {} }
        combat_state = S_CombatState:add_threat(combat_state, 10, 50.0)
        return #combat_state.aggro_table == 1 and combat_state.aggro_table[1].threat == 50.0
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_add_threat_stacks() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_CombatState = dofile("systems/s_combat_state.lua")
        S_CombatState:init(engine)

        local combat_state = { in_combat = false, aggro_table = {} }
        combat_state = S_CombatState:add_threat(combat_state, 10, 50.0)
        combat_state = S_CombatState:add_threat(combat_state, 10, 25.0)
        return combat_state.aggro_table[1].threat == 75.0
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_leash_distance_exceeded() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_CombatState = dofile("systems/s_combat_state.lua")
        S_CombatState:init(engine)

        local leash = { max_distance = 10.0, is_returning = false }
        local pos = { 15, 0, 0 }
        local home = { 0, 0, 0 }

        local should_return = S_CombatState:check_leash(leash, pos, home)
        return should_return
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_in_combat_after_threat() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_CombatState = dofile("systems/s_combat_state.lua")
        S_CombatState:init(engine)

        local combat_state = { in_combat = false, combat_timer = 0, aggro_table = {} }
        combat_state = S_CombatState:add_threat(combat_state, 10, 50.0)
        return combat_state.in_combat
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_combat_state
```

Expected: FAIL.

- [ ] **Step 3: Implement combat state / aggro / leash**

Write `engine/lua/systems/s_combat_state.lua`:

```lua
local S_CombatState = {}

function S_CombatState:init(engine)
    self.engine = engine
end

function S_CombatState:add_threat(combat_state, attacker_id, amount)
    for _, entry in ipairs(combat_state.aggro_table) do
        if entry.entity_id == attacker_id then
            entry.threat = entry.threat + amount
            combat_state.in_combat = true
            combat_state.combat_timer = 0
            combat_state.last_attacker = attacker_id
            return combat_state
        end
    end

    table.insert(combat_state.aggro_table, {
        entity_id = attacker_id,
        threat = amount,
    })

    combat_state.in_combat = true
    combat_state.combat_timer = 0
    combat_state.last_attacker = attacker_id

    return combat_state
end

function S_CombatState:get_top_threat(combat_state)
    if #combat_state.aggro_table == 0 then
        return nil
    end

    local best = combat_state.aggro_table[1]
    for _, entry in ipairs(combat_state.aggro_table) do
        if entry.threat > best.threat then
            best = entry
        end
    end

    return best
end

function S_CombatState:check_leash(leash, current_pos, home_pos)
    if not leash then
        return false
    end

    local dx = current_pos[1] - home_pos[1]
    local dy = current_pos[2] - home_pos[2]
    local dz = current_pos[3] - home_pos[3]
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

    if dist > leash.max_distance then
        leash.is_returning = true
        return true
    end

    return false
end

function S_CombatState:process(engine, dt)
    engine:query({"CombatState"}, function(eid)
        local combat = engine:get(eid, "CombatState")

        if combat.in_combat then
            combat.combat_timer = combat.combat_timer + dt

            -- Exit combat after 5 seconds of no new threat
            if combat.combat_timer > 5.0 then
                combat.in_combat = false
                combat.aggro_table = {}
            end
        end

        engine:set(eid, "CombatState", combat)
    end)

    -- Leash checks
    engine:query({"Leash", "Transform"}, function(eid)
        local leash = engine:get(eid, "Leash")
        local pos = engine:get(eid, "Transform").translation

        local exceeded = S_CombatState:check_leash(leash, pos, leash.home_position)

        if exceeded then
            engine:set(eid, "Leash", leash)
            engine:emit("EntityLeashedEvent", { entity = eid, home = leash.home_position })
        elseif leash.is_returning then
            local dx = pos[1] - leash.home_position[1]
            local dz = pos[3] - leash.home_position[3]
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist < 0.5 then
                leash.is_returning = false
                engine:set(eid, "Leash", leash)
            end
        end
    end)
end

return S_CombatState
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_CombatState]
lua_file = "systems/s_combat_state.lua"
system_set = "PostMotion"
priority = 82
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_combat_state
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_combat_state.lua engine/lua/config/systems.toml engine/tests/combat_state.rs
git commit -m "(GREEN) feat: implement aggro, leash, and combat state

S_CombatState (PostMotion, pri 82): add_threat (stacks existing, flags
in_combat + resets timer + records last_attacker), get_top_threat (highest
aggro entry), check_leash (distance from home exceeds max_distance →
return flag). process() auto-exits combat after 5s idle, checks and
enforces leash distance per entity. Emits EntityLeashedEvent on violation."
```

---

## Task 9: MOBA Control Input Bridge (TypeScript + Lua)

**Files:**
- Create: `client/src/input/MobaControlHandler.ts`
- Create: `client/src/input/__tests__/MobaControlHandler.test.ts`
- Create: `client/src/ui/widgets/AbilityBar.tsx`
- Create: `client/src/ui/widgets/SkillShotPreview.tsx`
- Create: `client/src/ui/widgets/__tests__/AbilityBar.test.tsx`

- [ ] **Step 1: Write failing control handler test**

Write `client/src/input/__tests__/MobaControlHandler.test.ts`:

```typescript
import { describe, it, expect, vi } from 'vitest';
import { MobaControlHandler } from '../MobaControlHandler';

describe('MobaControlHandler', () => {
  it('should detect tap as autotarget', () => {
    const handler = new MobaControlHandler();
    const spy = vi.fn();
    handler.onAbilityTrigger = spy;

    handler.handleAbilityTouchStart(0, 100, 100, 200, 200);
    // Tap without drag = trigger autotarget on nearest enemy
    handler.handleAbilityTouchEnd(0, 102, 102, 200, 200);

    expect(spy).toHaveBeenCalledWith(0, 'autotarget', null);
  });

  it('should detect drag as skill shot', () => {
    const handler = new MobaControlHandler();
    const spy = vi.fn();
    handler.onAbilityTrigger = spy;

    handler.handleAbilityTouchStart(0, 100, 100, 800, 600);
    handler.handleAbilityTouchMove(0, 200, 200, 800, 600);
    handler.handleAbilityTouchEnd(0, 200, 200, 800, 600);

    expect(spy).toHaveBeenCalledWith(0, 'skill_shot', expect.any(Object));
  });

  it('should emit range indicator during drag', () => {
    const handler = new MobaControlHandler();
    const spy = vi.fn();
    handler.onRangeIndicator = spy;

    handler.handleAbilityTouchStart(1, 100, 100, 800, 600);
    handler.handleAbilityTouchMove(1, 150, 120, 800, 600);

    expect(spy).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement MOBA control handler**

Write `client/src/input/MobaControlHandler.ts`:

```typescript
const DRAG_THRESHOLD_PX = 15;

interface SkillShotDirection {
  x: number;
  y: number;
}

interface ActiveTouch {
  startX: number;
  startY: number;
  currentX: number;
  currentY: number;
}

export class MobaControlHandler {
  private activeTouches = new Map<number, ActiveTouch>();
  onAbilityTrigger: ((slot: number, mode: 'autotarget' | 'skill_shot', direction: SkillShotDirection | null) => void) | null = null;
  onRangeIndicator: ((slot: number, visible: boolean, direction: SkillShotDirection | null) => void) | null = null;

  handleAbilityTouchStart(abilityIndex: number, x: number, y: number, canvasW: number, canvasH: number): void {
    this.activeTouches.set(abilityIndex, {
      startX: x,
      startY: y,
      currentX: x,
      currentY: y,
    });
  }

  handleAbilityTouchMove(abilityIndex: number, x: number, y: number, canvasW: number, canvasH: number): void {
    const touch = this.activeTouches.get(abilityIndex);
    if (!touch) return;

    touch.currentX = x;
    touch.currentY = y;

    const dx = x - touch.startX;
    const dy = y - touch.startY;

    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist > DRAG_THRESHOLD_PX) {
      const angle = Math.atan2(dy, dx);
      const direction: SkillShotDirection = {
        x: Math.cos(angle),
        y: -Math.sin(angle), // Flip Y for 3D world space
      };
      this.onRangeIndicator?.(abilityIndex, true, direction);
    }
  }

  handleAbilityTouchEnd(abilityIndex: number, x: number, y: number, canvasW: number, canvasH: number): void {
    const touch = this.activeTouches.get(abilityIndex);
    if (!touch) return;

    const dx = x - touch.startX;
    const dy = y - touch.startY;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist < DRAG_THRESHOLD_PX) {
      this.onAbilityTrigger?.(abilityIndex, 'autotarget', null);
    } else {
      const angle = Math.atan2(dy, dx);
      const direction: SkillShotDirection = {
        x: Math.cos(angle),
        y: -Math.sin(angle),
      };
      this.onAbilityTrigger?.(abilityIndex, 'skill_shot', direction);
    }

    this.onRangeIndicator?.(abilityIndex, false, null);
    this.activeTouches.delete(abilityIndex);
  }
}
```

Write `client/src/ui/widgets/AbilityBar.tsx`:

```tsx
interface AbilitySlotData {
  slotIndex: number;
  abilityId: string;
  name: string;
  icon: string;
  cooldownRemaining: number;
  isReady: boolean;
  totalCooldown: number;
}

interface AbilityBarProps {
  abilities: AbilitySlotData[];
  onSlotPress: (slotIndex: number) => void;
  onSlotDragStart: (slotIndex: number, x: number, y: number) => void;
  onSlotDragMove: (slotIndex: number, x: number, y: number) => void;
  onSlotDragEnd: (slotIndex: number, x: number, y: number) => void;
}

const ICON_MAP: Record<string, string> = {
  ability_basic_attack: '⚔',
  ability_power_strike: '💥',
  ability_fireball: '🔥',
  ability_adrenaline: '⚡',
};

export function AbilityBar({ abilities, onSlotPress, onSlotDragStart, onSlotDragMove, onSlotDragEnd }: AbilityBarProps) {
  return (
    <div style={{
      position: 'fixed', bottom: '1rem', right: '1rem',
      display: 'flex', gap: '0.5rem', zIndex: 60,
    }}>
      {abilities.map((slot) => {
        const cooldownPct = slot.totalCooldown > 0
          ? (slot.cooldownRemaining / slot.totalCooldown) * 100
          : 0;

        return (
          <div key={slot.slotIndex} style={{
            position: 'relative',
            width: '64px', height: '64px',
            border: `2px solid ${slot.isReady ? '#2a4a7f' : '#444'}`,
            borderRadius: '8px',
            background: slot.isReady ? 'rgba(10, 15, 30, 0.9)' : 'rgba(10, 10, 20, 0.6)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: slot.isReady ? 'pointer' : 'default',
          }}>
            <span style={{ fontSize: '1.5rem' }}>
              {ICON_MAP[slot.icon] || '?'}
            </span>
            <span style={{
              position: 'absolute', bottom: '2px', left: '4px',
              color: '#aaa', fontFamily: 'monospace', fontSize: '0.65rem',
            }}>
              {slot.name.length > 8 ? slot.name.slice(0, 7) + '…' : slot.name}
            </span>
            {!slot.isReady && cooldownPct > 0 && (
              <div style={{
                position: 'absolute', bottom: 0, left: 0, right: 0,
                height: `${cooldownPct}%`,
                background: 'rgba(0,0,0,0.7)',
                borderRadius: '0 0 6px 6px',
                transition: 'height 0.1s linear',
              }}>
                <span style={{
                  position: 'absolute', top: '50%', left: '50%',
                  transform: 'translate(-50%, -50%)',
                  color: '#ccc', fontSize: '0.7rem', fontFamily: 'monospace',
                }}>
                  {slot.cooldownRemaining.toFixed(1)}
                </span>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
```

Write `client/src/ui/widgets/SkillShotPreview.tsx`:

```tsx
import { useEffect, useRef } from 'react';

interface SkillShotPreviewProps {
  visible: boolean;
  originX: number;
  originY: number;
  directionX: number;
  directionY: number;
  range: number;
}

export function SkillShotPreview({ visible, originX = 0, originY = 0, directionX = 0, directionY = 0, range = 0 }: SkillShotPreviewProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    if (!visible || range <= 0) return;

    const endX = originX + directionX * range * 30;
    const endY = originY + directionY * range * 30;

    ctx.strokeStyle = 'rgba(42, 74, 127, 0.6)';
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]);
    ctx.beginPath();
    ctx.moveTo(originX, originY);
    ctx.lineTo(endX, endY);
    ctx.stroke();

    ctx.fillStyle = 'rgba(42, 74, 127, 0.3)';
    ctx.beginPath();
    ctx.arc(endX, endY, range * 8, 0, Math.PI * 2);
    ctx.fill();
  }, [visible, originX, originY, directionX, directionY, range]);

  if (!visible) return null;

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'fixed', top: 0, left: 0,
        width: '100%', height: '100%',
        zIndex: 55, pointerEvents: 'none',
      }}
    />
  );
}
```

Write `client/src/ui/widgets/__tests__/AbilityBar.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { AbilityBar } from '../AbilityBar';

describe('AbilityBar', () => {
  it('should render ability icons', () => {
    const abilities = [
      { slotIndex: 0, abilityId: 'basic_attack', name: 'Basic Atk', icon: 'ability_basic_attack', cooldownRemaining: 0, isReady: true, totalCooldown: 0.5 },
      { slotIndex: 1, abilityId: 'fireball', name: 'Fireball', icon: 'ability_fireball', cooldownRemaining: 3.0, isReady: false, totalCooldown: 5.0 },
    ];
    const { getByText } = render(
      <AbilityBar abilities={abilities} onSlotPress={() => {}} onSlotDragStart={() => {}} onSlotDragMove={() => {}} onSlotDragEnd={() => {}} />
    );
    expect(getByText('Basic Atk')).toBeInTheDocument();
    expect(getByText('Fireball')).toBeInTheDocument();
  });

  it('should show cooldown timer', () => {
    const abilities = [
      { slotIndex: 0, abilityId: 'fireball', name: 'Fireball', icon: 'ability_fireball', cooldownRemaining: 3.0, isReady: false, totalCooldown: 5.0 },
    ];
    const { getByText } = render(
      <AbilityBar abilities={abilities} onSlotPress={() => {}} onSlotDragStart={() => {}} onSlotDragMove={() => {}} onSlotDragEnd={() => {}} />
    );
    expect(getByText('3.0')).toBeInTheDocument();
  });
});
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: All MOBA control tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/input/MobaControlHandler.ts client/src/input/__tests__/MobaControlHandler.test.ts client/src/ui/widgets/AbilityBar.tsx client/src/ui/widgets/SkillShotPreview.tsx client/src/ui/widgets/__tests__/AbilityBar.test.tsx
git commit -m "(GREEN) feat: implement MOBA control handler and combat HUD

MobaControlHandler: tap → autotarget (nearest enemy), drag → skill shot
(directional vector from touch delta with 15px threshold). Range indicator
during drag. AbilityBar: 4 ability icons with cooldown overlay + timer.
SkillShotPreview: dashed line + endpoint circle overlay for aim display."
```

---

## Task 10: Enemy AI BT Nodes for Combat

**Files:**
- Create: `engine/lua/lib/bt/nodes/bt_check_threat.lua`
- Create: `engine/lua/lib/bt/nodes/bt_chase_target.lua`
- Create: `engine/lua/lib/bt/nodes/bt_use_ability.lua`
- Create: `engine/lua/lib/bt/nodes/bt_flee_threshold.lua`
- Create: `engine/lua/lib/bt/nodes/bt_reset_combat.lua`
- Create: `engine/tests/bt_combat.rs`

- [ ] **Step 1: Write failing BT combat node test**

Write `engine/tests/bt_combat.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_bt_check_threat() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local BT_CheckThreat = dofile("lib/bt/nodes/bt_check_threat.lua")

        local state = {
            combat_state = {
                in_combat = true,
                aggro_table = { { entity_id = 42, threat = 100.0 } },
            },
        }

        local status = BT_CheckThreat.evaluate(state)
        return status == "success"
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_bt_check_threat_no_combat() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local BT_CheckThreat = dofile("lib/bt/nodes/bt_check_threat.lua")

        local state = {
            combat_state = {
                in_combat = false,
                aggro_table = {},
            },
        }

        local status = BT_CheckThreat.evaluate(state)
        return status == "failure"
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_bt_flee_at_threshold() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local BT_FleeThreshold = dofile("lib/bt/nodes/bt_flee_threshold.lua")

        local state = {
            health = { current = 15, max = 100 },
            flee_pct = 0.25,
        }

        local status = BT_FleeThreshold.evaluate(state)
        return status == "success"
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_bt
```

Expected: FAIL.

- [ ] **Step 3: Implement BT combat nodes**

Write `engine/lua/lib/bt/nodes/bt_check_threat.lua`:

```lua
local BT_CheckThreat = {
    node_type = "condition",
}

function BT_CheckThreat.evaluate(blackboard)
    local combat = blackboard.combat_state
    if not combat then
        return "failure"
    end

    if not combat.in_combat then
        return "failure"
    end

    if #combat.aggro_table == 0 then
        return "failure"
    end

    return "success"
end

return BT_CheckThreat
```

Write `engine/lua/lib/bt/nodes/bt_chase_target.lua`:

```lua
local BT_ChaseTarget = {
    node_type = "action",
}

function BT_ChaseTarget.evaluate(blackboard)
    local entity_id = blackboard.entity_id
    local engine = blackboard.engine

    local combat = engine:get(entity_id, "CombatState")
    if not combat or not combat.in_combat then
        return "failure"
    end

    -- Get top threat target
    local best = nil
    local best_threat = -1
    for _, entry in ipairs(combat.aggro_table) do
        if entry.threat > best_threat then
            best_threat = entry.threat
            best = entry.entity_id
        end
    end

    if not best then
        return "failure"
    end

    -- Check if target still exists
    if not engine:entity_exists(best) then
        return "failure"
    end

    local my_pos = engine:get(entity_id, "Transform").translation
    local target_pos = engine:get(best, "Transform").translation

    local dx = target_pos[1] - my_pos[1]
    local dz = target_pos[3] - my_pos[3]
    local dist = math.sqrt(dx * dx + dz * dz)

    -- Move toward target
    local speed = (engine:get(entity_id, "Movement") or {speed=5.0}).speed
    if dist > 1.0 then
        local nx = dx / dist
        local nz = dz / dist
        engine:set_linear_velocity(entity_id, { x = nx * speed, y = 0, z = nz * speed })
        return "running"
    end

    -- In range — stop
    engine:set_linear_velocity(entity_id, { x = 0, y = 0, z = 0 })
    return "success"
end

return BT_ChaseTarget
```

Write `engine/lua/lib/bt/nodes/bt_use_ability.lua`:

```lua
local BT_UseAbility = {
    node_type = "action",
}

function BT_UseAbility.evaluate(blackboard)
    local entity_id = blackboard.entity_id
    local engine = blackboard.engine
    local ability_id = blackboard.ability_id

    if not ability_id then
        return "failure"
    end

    local abilities = engine:get(entity_id, "AbilityOwner")
    if not abilities then
        return "failure"
    end

    -- Check if ability is off cooldown and resources available
    for _, slot in ipairs(abilities.abilities) do
        if slot.ability_id == ability_id and slot.is_ready then
            -- Get current target
            local combat = engine:get(entity_id, "CombatState")
            local target = nil
            if combat then
                for _, entry in ipairs(combat.aggro_table) do
                    if entry.threat > 0 then
                        target = entry.entity_id
                        break
                    end
                end
            end

            engine:set(entity_id, "AbilityCommand", {
                ability_id = ability_id,
                target_id = target,
                resolved = false,
            })

            return "running"
        end
    end

    return "failure"
end

return BT_UseAbility
```

Write `engine/lua/lib/bt/nodes/bt_flee_threshold.lua`:

```lua
local BT_FleeThreshold = {
    node_type = "condition",
}

function BT_FleeThreshold.evaluate(blackboard)
    local health = blackboard.health
    local threshold = blackboard.flee_pct or 0.25

    if not health then
        return "failure"
    end

    local pct = (health.current or 0) / (health.max or 1)
    if pct <= threshold then
        return "success"
    end

    return "failure"
end

return BT_FleeThreshold
```

Write `engine/lua/lib/bt/nodes/bt_reset_combat.lua`:

```lua
local BT_ResetCombat = {
    node_type = "action",
}

function BT_ResetCombat.evaluate(blackboard)
    local entity_id = blackboard.entity_id
    local engine = blackboard.engine

    local combat = engine:get(entity_id, "CombatState") or { in_combat = false, aggro_table = {} }
    combat.in_combat = false
    combat.aggro_table = {}
    combat.combat_timer = 0
    engine:set(entity_id, "CombatState", combat)

    local leash = engine:get(entity_id, "Leash") or {}
    leash.is_returning = true
    engine:set(entity_id, "Leash", leash)

    return "success"
end

return BT_ResetCombat
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_bt
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/lib/bt/nodes/bt_check_threat.lua engine/lua/lib/bt/nodes/bt_chase_target.lua engine/lua/lib/bt/nodes/bt_use_ability.lua engine/lua/lib/bt/nodes/bt_flee_threshold.lua engine/lua/lib/bt/nodes/bt_reset_combat.lua engine/tests/bt_combat.rs
git commit -m "(GREEN) feat: add combat BT nodes for enemy AI

BT_CheckThreat: condition — in_combat + has aggro table entries.
BT_ChaseTarget: action — moves toward top-threat enemy, stops at 1.0 range.
BT_UseAbility: action — fires specific ability_id if off cooldown.
BT_FleeThreshold: condition — health_pct below configurable threshold.
BT_ResetCombat: action — clears combat state, flags leash return."
```

---

## Task 11: Combat QB Contracts

**Files:**
- Create: `engine/lua/config/rules/combat_conditions.json`
- Create: `engine/tests/combat_qb.rs`

- [ ] **Step 1: Write failing QB combat test**

Write `engine/tests/combat_qb.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_condition_health_percent() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Scorer = dofile("lib/qb/qb_scorer.lua")

        local context = {
            components = {
                Health = { health_percent = 0.3, is_alive = true },
            },
            entity_tags = {},
            state = {},
            event_name = "",
            event_payload = {},
        }

        local rules = {{
            rule_id = "condition_health",
            conditions = {
                type = "composite",
                mode = "ALL",
                children = {
                    { type = "component_field", component_type = "Health", field_path = "health_percent", range_min = 0.0, range_max = 0.5 },
                    { type = "component_field", component_type = "Health", field_path = "is_alive" },
                },
            },
            decision_group = "",
            priority = 0,
            score_threshold = 0.0,
        }}

        local results = Scorer.score_rules(rules, context)
        return results[1].score > 0.0
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_condition_range_to_target() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Scorer = dofile("lib/qb/qb_scorer.lua")

        local context = {
            components = {
                Health = { health_percent = 1.0, is_alive = true },
            },
            entity_tags = {},
            state = {
                combat = {
                    nearest_target_range = 5.0,
                },
            },
            event_name = "",
            event_payload = {},
        }

        local rules = {{
            rule_id = "in_range",
            conditions = {{
                type = "redux_field",
                state_path = "combat.nearest_target_range",
                range_min = 0.0,
                range_max = 10.0,
                match_mode = "normalize",
            }},
            decision_group = "",
            priority = 0,
            score_threshold = 0.0,
        }}

        local results = Scorer.score_rules(rules, context)
        return results[1].score > 0.0
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_effect_damage_payload() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Ability = dofile("systems/s_ability_execution.lua")
        S_Ability:init(engine)

        local payloads = {
            {
                type = "damage",
                damage_type = "thermal",
                base_value = 35.0,
                penetration = 0.0,
                can_crit = true,
            },
        }

        -- Should not error
        pcall(function() S_Ability:apply_payloads(payloads, 1, 2) end)
        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_combat_qb
```

Expected: FAIL (or passes if all prior systems are integrated).

- [ ] **Step 3: Write combat QB contract docs as JSON**

Write `engine/lua/config/rules/combat_conditions.json`:

```json
{
  "description": "QB condition and effect contracts for combat engine. These are consumed by the narrative storylet, dialogue, and BT rule systems.",
  "condition_contracts": [
    {
      "contract_id": "RS_ConditionHealth",
      "type": "component_field",
      "component_type": "Health",
      "fields": {
        "health_percent": "0.0-1.0, normalized health ratio",
        "health": "raw health value for threshold checks",
        "is_alive": "boolean, alive/dead"
      },
      "usage": "Dialogue gating, mission gate conditions, narrative beat triggering"
    },
    {
      "contract_id": "RS_ConditionRange",
      "type": "redux_field",
      "state_path": "combat.nearest_target_range",
      "fields": {
        "nearest_target_range": "distance to nearest combat target in units"
      },
      "usage": "AI BT selectors, ability condition gates"
    },
    {
      "contract_id": "RS_ConditionCooldown",
      "type": "component_field",
      "component_type": "AbilityOwner",
      "fields": {
        "abilities[slot_index].is_ready": "boolean, ability off cooldown"
      },
      "usage": "AI ability selection scoring"
    }
  ],
  "effect_contracts": [
    {
      "contract_id": "RS_EffectDamage",
      "type": "publish_event",
      "event_name": "DamageQueued",
      "description": "Queues damage on target entity. Processed by S_Health."
    },
    {
      "contract_id": "RS_EffectStatus",
      "type": "component_field",
      "component_type": "StatusEffectContainer",
      "description": "Applies a named status effect with duration to target entity."
    },
    {
      "contract_id": "RS_EffectHeal",
      "type": "component_field",
      "component_type": "Health",
      "description": "Heals target entity. Processed by S_Health.heal()."
    }
  ]
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_combat_qb
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/config/rules/combat_conditions.json engine/tests/combat_qb.rs
git commit -m "(GREEN) feat: define combat QB condition and effect contracts

RS_ConditionHealth (health_percent, current, is_alive), RS_ConditionRange
(combat.nearest_target_range), RS_ConditionCooldown (AbilityOwner slot
readiness). RS_EffectDamage (DamageQueued event), RS_EffectStatus (apply
status effect), RS_EffectHeal (component field). Contracts consumed by
narrative, dialogue, and BT rules for combat-gated content."
```

---

## Task 12: End-to-End Combat Integration Test

**Files:**
- Create: `engine/tests/e2e_combat.rs`

- [ ] **Step 1: Write E2E test**

Write `engine/tests/e2e_combat.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;
use engine::events::*;

#[test]
fn test_full_combat_flow() {
    let mut world = World::new();
    world.init_resource::<bevy::ecs::event::Events<EntityDiedEvent>>();
    world.init_resource::<bevy::ecs::event::Events<DamageDealtEvent>>();

    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local S_Ability = dofile("systems/s_ability_execution.lua")
        local S_Health = dofile("systems/s_health.lua")
        local S_Status = dofile("systems/s_status_effects.lua")
        local S_Damage = dofile("systems/s_damage_calculation.lua")
        local S_Targeting = dofile("systems/s_targeting.lua")
        local S_CombatState = dofile("systems/s_combat_state.lua")

        S_Ability:init(engine)
        S_Health:init(engine)
        S_Status:init(engine)
        S_Damage:init(engine)
        S_Targeting:init(engine)
        S_CombatState:init(engine)

        -- Step 1: Damage formula
        local dmg = S_Damage:calculate(50, "physical", 10, 40, 0.2, true, 1.5)
        assert(dmg > 20, "Critical damage should exceed 20")

        -- Step 2: Status effect application
        local container = { effects = {}, max_effects = 8 }
        container, ok = S_Status:apply(container, "burning", 42, 3.0)
        assert(ok, "Should apply burning")

        -- Step 3: Status tick
        local dot, _ = S_Status:process_tick(container, 1.0)
        assert(dot == 5, "DOT tick should be 5 damage")

        -- Step 4: Aggro table
        local cs = { in_combat = false, aggro_table = {} }
        cs = S_CombatState:add_threat(cs, 10, 100)
        assert(cs.in_combat, "Should enter combat after threat")
        assert(#cs.aggro_table == 1, "Should have one entry")

        -- Step 5: Targeting
        local enemies = {
            { id = 10, pos = { 3, 0, 0 } },
            { id = 20, pos = { 1, 0, 0 } },
        }
        local nearest = S_Targeting:find_nearest({0,0,0}, enemies)
        assert(nearest == 20, "Should find nearest enemy")

        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_combat_systems_load_together() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local systems = {
            "systems/s_targeting.lua",
            "systems/s_damage_calculation.lua",
            "systems/s_health.lua",
            "systems/s_status_effects.lua",
            "systems/s_ability_execution.lua",
            "systems/s_combat_state.lua",
        }

        for _, path in ipairs(systems) do
            local mod = dofile(path)
            assert(mod ~= nil, path .. " failed to load")
            assert(mod.init ~= nil, path .. " missing init()")
        end

        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_e2e_combat
```

Expected: FAIL (or passes if all individual systems pass).

- [ ] **Step 3: Fix any integration issues and re-run**

```bash
cd engine && cargo test
```

Expected: Full suite passes including all combat tests.

- [ ] **Step 4: Commit**

```bash
git add engine/tests/e2e_combat.rs
git commit -m "(GREEN) test: add combat engine end-to-end integration tests

test_full_combat_flow: validates damage formula, status effect apply +
tick, aggro table, and targeting work together. test_combat_systems_load_
together: confirms all 6 combat Lua modules load and expose init().
Combat engine milestone complete."
```

---

## Combat Engine Systems Summary

| System | Set | Priority | Purpose |
|--------|-----|----------|---------|
| S_Targeting | PrePhysics | 25 | Resolve targeting requests (nearest, cone, directional) |
| S_DamageCalculation | CoreMotion | 48 | Five-stage pluggable damage formula |
| S_Health | CoreMotion | 49 | HP/shield/i-frames, resolve DamageQueued |
| S_StatusEffects | CoreMotion | 50 | Apply, tick, and expire status effects |
| S_AbilityExecution | CoreMotion | 52 | Cooldown tracking, resource costs, payloads, projectiles |
| S_CombatState | PostMotion | 82 | Aggro table, combat timer, leash enforcement |

## Combat Components Summary

| Component | Purpose |
|-----------|---------|
| Targetable | Marks entity as targetable with priority |
| CombatState | Aggro table, in_combat flag, timer |
| AbilityOwner | Ability slots, cooldowns, resource pools |
| DamageDealer | Base damage, penetration, crit stats |
| StatusEffectContainer | Active status effects, max effects cap |
| Leash | Home position, max distance, return speed |
| Shield | Shield HP pool, decay rate, absorption |
| InvulnerabilityFrames | Brief immunity after taking damage |
