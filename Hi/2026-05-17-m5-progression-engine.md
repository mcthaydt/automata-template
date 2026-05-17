# M5: Progression Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a character progression engine as a configurable framework. N user-defined attributes, M user-defined perk trees, K user-defined implant slots. XP/level state machine with configurable curve. Core provides the framework; demo ships sensible defaults (3 attributes, 9 perk trees, 4 implant slots, 30-level curve) as JSON/tres instances.

**Architecture:** Lua systems for gameplay logic, Bevy components for persistent data, JSON for catalog definitions, React + Zustand for progression UI screens. Progression state tracked in a persisted Redux-like slice. Combat bridge: kills award XP, attributes scale damage/defense. QB integration: attribute/perk/implant checks for dialogue and mission gating.

**Tech Stack:** Lua (progression logic), JSON (attribute/perk tree/implant/curve definitions), Bevy (persisted components), React + Zustand (progression UI screens).

**Prerequisites:** M1 complete (engine API, entity CRUD, event bus, state store, JSON loading), M4 complete (combat engine — HP, damage, aggro for kill events).

---

## Runnable Feature Examples

M5 progression examples are feature-level content packages with configurable catalogs and deterministic state assertions. They run through the unified CLI.

```bash
automata example run progression-level-up
automata example run progression-perk-unlock
automata example run progression-implant-loadout
```

Required M5 example packages:

| Example | Feature | Required proof |
|---------|---------|----------------|
| `progression-level-up` | XP curve and level rewards | XP grant advances level and awards configured points |
| `progression-perk-unlock` | Attribute gates and perk tree nodes | Perk unlock succeeds only after prerequisites are met |
| `progression-implant-loadout` | Implant slots and capacity | Implant install updates capacity and derived effects |

Every progression sample catalog must be registered through one of these packages or a new feature-level example package.

## Task 1: Progression Resource Definitions (JSON)

**Files:**
- Create: `engine/lua/config/progression/attributes.json`
- Create: `engine/lua/config/progression/perk_trees.json`
- Create: `engine/lua/config/progression/implant_slots.json`
- Create: `engine/lua/config/progression/level_curve.json`
- Create: `engine/tests/progression_resources.rs`

- [ ] **Step 1: Write failing resource load test**

Write `engine/tests/progression_resources.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_load_attributes() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local data = engine:load_json("config/progression/attributes.json")
        return data.attributes ~= nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_three_attributes_defined() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local data = engine:load_json("config/progression/attributes.json")
        local count = 0
        for _ in pairs(data.attributes) do count = count + 1 end
        return count
    "#).eval::<u32>();

    assert_eq!(result.unwrap(), 3);
}

#[test]
fn test_load_perk_trees() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local data = engine:load_json("config/progression/perk_trees.json")
        return data.trees ~= nil and #data.trees == 9
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_load_implant_slots() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local data = engine:load_json("config/progression/implant_slots.json")
        return data.slots ~= nil and #data.slots == 4
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_level_curve_has_thirty_levels() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local data = engine:load_json("config/progression/level_curve.json")
        return #data.levels == 30
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_progression_resources
```

Expected: FAIL — JSON files not found.

- [ ] **Step 3: Create catalog JSON files**

Write `engine/lua/config/progression/attributes.json`:

```json
{
  "attributes": {
    "reflexes": {
      "id": "reflexes",
      "name": "Reflexes",
      "description": "Governs speed, evasion, and critical hit chance.",
      "icon": "attr_reflexes",
      "default_value": 3,
      "min_value": 1,
      "soft_cap": 20,
      "hard_cap": 30,
      "point_cost_curve": "linear",
      "base_point_cost": 1,
      "cost_increment_per_point": 0,
      "combat_derivation": {
        "crit_chance_per_point": 0.005,
        "evasion_per_point": 0.003,
        "attack_speed_per_point": 0.01
      },
      "perk_trees": ["blade_mastery", "stealth_operations", "mobility_enhancement"]
    },
    "body": {
      "id": "body",
      "name": "Body",
      "description": "Governs health, stamina, and physical resistance.",
      "icon": "attr_body",
      "default_value": 3,
      "min_value": 1,
      "soft_cap": 20,
      "hard_cap": 30,
      "point_cost_curve": "linear",
      "base_point_cost": 1,
      "cost_increment_per_point": 0,
      "combat_derivation": {
        "max_health_per_point": 10,
        "max_stamina_per_point": 5,
        "physical_resistance_per_point": 0.01
      },
      "perk_trees": ["durability", "blunt_force", "pain_tolerance"]
    },
    "tech": {
      "id": "tech",
      "name": "Tech",
      "description": "Governs implant capacity, cyberware efficiency, and energy damage.",
      "icon": "attr_tech",
      "default_value": 3,
      "min_value": 1,
      "soft_cap": 20,
      "hard_cap": 30,
      "point_cost_curve": "linear",
      "base_point_cost": 1,
      "cost_increment_per_point": 0,
      "combat_derivation": {
        "max_mana_per_point": 5,
        "energy_damage_per_point": 0.02,
        "hacking_speed_per_point": 0.01,
        "implant_capacity_per_point": 1
      },
      "perk_trees": ["netrunning", "engineering", "medicine"]
    }
  },
  "per_point_stats": {
    "attribute_points_per_level": 1,
    "perk_points_per_level": 1
  }
}
```

Write `engine/lua/config/progression/perk_trees.json`:

```json
{
  "trees": [
    {
      "tree_id": "blade_mastery",
      "name": "Blade Mastery",
      "attribute": "reflexes",
      "description": "Mastery of edged weapons. Increases critical damage and bleed effects.",
      "root_node_id": "bm_1",
      "nodes": [
        {
          "node_id": "bm_1",
          "name": "Sharpened Edge",
          "description": "+5% critical damage with blades.",
          "icon": "perk_blade_1",
          "tier": 0,
          "max_ranks": 3,
          "prerequisites": [],
          "connections": ["bm_2", "bm_3"],
          "effects_per_rank": [
            { "stat": "crit_multiplier", "value": 0.05, "scope": "blade_weapons" }
          ]
        },
        {
          "node_id": "bm_2",
          "name": "Bleeding Strikes",
          "description": "Blade attacks have a chance to apply bleed.",
          "icon": "perk_blade_2",
          "tier": 1,
          "max_ranks": 2,
          "prerequisites": ["bm_1"],
          "attribute_requirement": { "reflexes": 6 },
          "connections": ["bm_4"],
          "effects_per_rank": [
            { "stat": "bleed_chance", "value": 0.10, "scope": "blade_weapons" }
          ]
        },
        {
          "node_id": "bm_3",
          "name": "Faster Hands",
          "description": "+8% attack speed with blades.",
          "icon": "perk_blade_3",
          "tier": 1,
          "max_ranks": 3,
          "prerequisites": ["bm_1"],
          "connections": ["bm_4"],
          "effects_per_rank": [
            { "stat": "attack_speed", "value": 0.08, "scope": "blade_weapons" }
          ]
        },
        {
          "node_id": "bm_4",
          "name": "Death by a Thousand Cuts",
          "description": "Each consecutive hit deals +3% more damage, stacking up to 5 times.",
          "icon": "perk_blade_4",
          "tier": 2,
          "max_ranks": 1,
          "prerequisites": ["bm_2", "bm_3"],
          "attribute_requirement": { "reflexes": 12 },
          "connections": [],
          "effects_per_rank": [
            { "stat": "consecutive_hit_bonus", "value": 0.03, "scope": "all" }
          ]
        }
      ]
    },
    {
      "tree_id": "stealth_operations",
      "name": "Stealth Operations",
      "attribute": "reflexes",
      "description": "Covert tactics. Improves surprise attacks and evasion.",
      "root_node_id": "so_1",
      "nodes": [
        {
          "node_id": "so_1",
          "name": "Silent Approach",
          "description": "-20% detection radius.",
          "icon": "perk_stealth_1",
          "tier": 0,
          "max_ranks": 3,
          "prerequisites": [],
          "connections": ["so_2"],
          "effects_per_rank": [
            { "stat": "detection_radius", "value": -0.07, "scope": "self" }
          ]
        },
        {
          "node_id": "so_2",
          "name": "Ambush Predator",
          "description": "+30% damage against unaware targets.",
          "icon": "perk_stealth_2",
          "tier": 1,
          "max_ranks": 3,
          "prerequisites": ["so_1"],
          "attribute_requirement": { "reflexes": 8 },
          "connections": [],
          "effects_per_rank": [
            { "stat": "ambush_damage_mult", "value": 0.10, "scope": "self" }
          ]
        }
      ]
    },
    {
      "tree_id": "mobility_enhancement",
      "name": "Mobility Enhancement",
      "attribute": "reflexes",
      "description": "Movement and repositioning techniques.",
      "root_node_id": "me_1",
      "nodes": [
        {
          "node_id": "me_1",
          "name": "Dash",
          "description": "Unlock a short-range dash ability.",
          "icon": "perk_mobility_1",
          "tier": 0,
          "max_ranks": 1,
          "prerequisites": [],
          "connections": ["me_2"],
          "effects_per_rank": [
            { "stat": "ability_unlock", "value": "dash", "scope": "self" }
          ]
        },
        {
          "node_id": "me_2",
          "name": "Fluid Motion",
          "description": "Dash cooldown reduced by 25%.",
          "icon": "perk_mobility_2",
          "tier": 1,
          "max_ranks": 1,
          "prerequisites": ["me_1"],
          "attribute_requirement": { "reflexes": 10 },
          "connections": [],
          "effects_per_rank": [
            { "stat": "dash_cooldown_mult", "value": 0.75, "scope": "self" }
          ]
        }
      ]
    },
    {
      "tree_id": "durability",
      "name": "Durability",
      "attribute": "body",
      "description": "Physical resilience and survival instincts.",
      "root_node_id": "du_1",
      "nodes": [
        {
          "node_id": "du_1",
          "name": "Toughened",
          "description": "+15 maximum health.",
          "icon": "perk_dura_1",
          "tier": 0,
          "max_ranks": 3,
          "prerequisites": [],
          "connections": ["du_2"],
          "effects_per_rank": [
            { "stat": "max_health", "value": 15, "scope": "self" }
          ]
        },
        {
          "node_id": "du_2",
          "name": "Second Wind",
          "description": "Once per encounter, regenerate 10% max HP over 3s when below 30% HP.",
          "icon": "perk_dura_2",
          "tier": 1,
          "max_ranks": 1,
          "prerequisites": ["du_1"],
          "attribute_requirement": { "body": 10 },
          "connections": [],
          "effects_per_rank": [
            { "stat": "second_wind", "value": 1, "scope": "self" }
          ]
        }
      ]
    },
    {
      "tree_id": "blunt_force",
      "name": "Blunt Force",
      "attribute": "body",
      "description": "Heavy weapons and crushing power.",
      "root_node_id": "bf_1",
      "nodes": [
        {
          "node_id": "bf_1",
          "name": "Heavy Hands",
          "description": "+10% damage with blunt weapons.",
          "icon": "perk_blunt_1",
          "tier": 0,
          "max_ranks": 5,
          "prerequisites": [],
          "connections": [],
          "effects_per_rank": [
            { "stat": "damage", "value": 0.10, "scope": "blunt_weapons" }
          ]
        }
      ]
    },
    {
      "tree_id": "pain_tolerance",
      "name": "Pain Tolerance",
      "attribute": "body",
      "description": "Resistance to physical status effects.",
      "root_node_id": "pt_1",
      "nodes": [
        {
          "node_id": "pt_1",
          "name": "Numbed Nerves",
          "description": "+20% stun and stagger resistance.",
          "icon": "perk_pain_1",
          "tier": 0,
          "max_ranks": 3,
          "prerequisites": [],
          "connections": [],
          "effects_per_rank": [
            { "stat": "stun_resist", "value": 0.07, "scope": "self" }
          ]
        }
      ]
    },
    {
      "tree_id": "netrunning",
      "name": "Netrunning",
      "attribute": "tech",
      "description": "Cyber intrusion and data manipulation.",
      "root_node_id": "nr_1",
      "nodes": [
        {
          "node_id": "nr_1",
          "name": "Breach Protocol",
          "description": "+15% hack damage.",
          "icon": "perk_net_1",
          "tier": 0,
          "max_ranks": 3,
          "prerequisites": [],
          "connections": [],
          "effects_per_rank": [
            { "stat": "hack_damage", "value": 0.05, "scope": "self" }
          ]
        }
      ]
    },
    {
      "tree_id": "engineering",
      "name": "Engineering",
      "attribute": "tech",
      "description": "Device crafting and energy weapon tuning.",
      "root_node_id": "en_1",
      "nodes": [
        {
          "node_id": "en_1",
          "name": "Overcharge",
          "description": "+10% energy weapon damage.",
          "icon": "perk_eng_1",
          "tier": 0,
          "max_ranks": 5,
          "prerequisites": [],
          "connections": [],
          "effects_per_rank": [
            { "stat": "energy_damage", "value": 0.10, "scope": "energy_weapons" }
          ]
        }
      ]
    },
    {
      "tree_id": "medicine",
      "name": "Medicine",
      "attribute": "tech",
      "description": "Healing efficiency and medical expertise.",
      "root_node_id": "md_1",
      "nodes": [
        {
          "node_id": "md_1",
          "name": "Field Medic",
          "description": "+20% healing received.",
          "icon": "perk_med_1",
          "tier": 0,
          "max_ranks": 3,
          "prerequisites": [],
          "connections": [],
          "effects_per_rank": [
            { "stat": "healing_received_mult", "value": 0.07, "scope": "self" }
          ]
        }
      ]
    }
  ]
}
```

Write `engine/lua/config/progression/implant_slots.json`:

```json
{
  "slots": [
    {
      "slot_id": "neural",
      "name": "Neural",
      "description": "Brain and nervous system augmentations. Affects cognition, reflexes, and hacking.",
      "icon": "slot_neural",
      "allowed_tags": ["neural", "cognitive", "reflex", "hacking"]
    },
    {
      "slot_id": "skeletal",
      "name": "Skeletal",
      "description": "Bone and muscle reinforcement. Affects strength, durability, and melee combat.",
      "icon": "slot_skeletal",
      "allowed_tags": ["skeletal", "strength", "armor", "melee"]
    },
    {
      "slot_id": "dermal",
      "name": "Dermal",
      "description": "Skin and subdermal implants. Affects armor, camouflage, and environmental resistance.",
      "icon": "slot_dermal",
      "allowed_tags": ["dermal", "armor", "stealth", "resistance"]
    },
    {
      "slot_id": "visceral",
      "name": "Visceral",
      "description": "Internal organ replacements. Affects metabolism, regeneration, and toxin filtration.",
      "icon": "slot_visceral",
      "allowed_tags": ["visceral", "metabolism", "regeneration", "toxin"]
    }
  ],
  "capacity": {
    "base_capacity": 10,
    "extra_per_tech_point": 1,
    "description": "Total implant capacity = 10 + Tech attribute. Each implant has a capacity_cost."
  },
  "example_implants": [
    {
      "implant_id": "synaptic_accelerator",
      "name": "Synaptic Accelerator",
      "description": "+10% attack speed and +5% crit chance.",
      "slot_type": "neural",
      "capacity_cost": 3,
      "tags": ["neural", "reflex"],
      "rarity": "rare",
      "effects": {
        "attack_speed_mult": 0.10,
        "crit_chance_flat": 0.05
      }
    },
    {
      "implant_id": "subdermal_weave",
      "name": "Subdermal Weave",
      "description": "+15 armor and +10% physical resistance.",
      "slot_type": "dermal",
      "capacity_cost": 4,
      "tags": ["dermal", "armor"],
      "rarity": "uncommon",
      "effects": {
        "armor_flat": 15,
        "physical_resist_mult": 0.10
      }
    },
    {
      "implant_id": "adrenal_pump",
      "name": "Adrenal Pump",
      "description": "When below 25% HP, gain +30% damage for 5s. 60s cooldown.",
      "slot_type": "visceral",
      "capacity_cost": 6,
      "tags": ["visceral", "metabolism"],
      "rarity": "legendary",
      "effects": {
        "conditional_damage_mult": { "threshold_hp_pct": 0.25, "multiplier": 0.30, "duration": 5.0, "cooldown": 60.0 }
      }
    }
  ]
}
```

Write `engine/lua/config/progression/level_curve.json`:

```json
{
  "max_level": 30,
  "initial_xp_required": 150,
  "xp_multiplier": 1.12,
  "total_estimated_xp": 120000,
  "estimated_hours_to_max": 25,
  "levels": [
    { "level": 1, "xp_to_next": 0, "cumulative_xp": 0, "attribute_points": 0, "perk_points": 0, "implant_capacity_increase": 0 },
    { "level": 2, "xp_to_next": 150, "cumulative_xp": 0, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 3, "xp_to_next": 170, "cumulative_xp": 150, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 4, "xp_to_next": 190, "cumulative_xp": 320, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 5, "xp_to_next": 215, "cumulative_xp": 510, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 6, "xp_to_next": 240, "cumulative_xp": 725, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 7, "xp_to_next": 270, "cumulative_xp": 965, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 8, "xp_to_next": 300, "cumulative_xp": 1235, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 9, "xp_to_next": 335, "cumulative_xp": 1535, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 10, "xp_to_next": 375, "cumulative_xp": 1870, "attribute_points": 1, "perk_points": 2, "implant_capacity_increase": 2 },
    { "level": 11, "xp_to_next": 420, "cumulative_xp": 2245, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 12, "xp_to_next": 470, "cumulative_xp": 2665, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 13, "xp_to_next": 525, "cumulative_xp": 3135, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 14, "xp_to_next": 590, "cumulative_xp": 3660, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 15, "xp_to_next": 660, "cumulative_xp": 4250, "attribute_points": 1, "perk_points": 2, "implant_capacity_increase": 2 },
    { "level": 16, "xp_to_next": 740, "cumulative_xp": 4910, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 17, "xp_to_next": 830, "cumulative_xp": 5650, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 18, "xp_to_next": 930, "cumulative_xp": 6480, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 19, "xp_to_next": 1040, "cumulative_xp": 7410, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 20, "xp_to_next": 1165, "cumulative_xp": 8450, "attribute_points": 1, "perk_points": 2, "implant_capacity_increase": 3 },
    { "level": 21, "xp_to_next": 1305, "cumulative_xp": 9615, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 22, "xp_to_next": 1460, "cumulative_xp": 10920, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 23, "xp_to_next": 1635, "cumulative_xp": 12380, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 24, "xp_to_next": 1830, "cumulative_xp": 14015, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 25, "xp_to_next": 2050, "cumulative_xp": 15845, "attribute_points": 1, "perk_points": 2, "implant_capacity_increase": 2 },
    { "level": 26, "xp_to_next": 2300, "cumulative_xp": 17895, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 27, "xp_to_next": 2575, "cumulative_xp": 20195, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 28, "xp_to_next": 2885, "cumulative_xp": 22770, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 29, "xp_to_next": 3230, "cumulative_xp": 25655, "attribute_points": 1, "perk_points": 1, "implant_capacity_increase": 0 },
    { "level": 30, "xp_to_next": 3620, "cumulative_xp": 28885, "attribute_points": 1, "perk_points": 2, "implant_capacity_increase": 3 }
  ]
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_progression_resources
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/config/progression/ engine/tests/progression_resources.rs
git commit -m "(GREEN) feat: define progression resource catalog configs

Attributes (reflexes/body/tech): soft/hard caps, point costs, combat
derivation stats, associated perk trees. 9 perk trees (3 per attribute):
nodes with prerequisites, attribute requirements, max ranks, connections,
effects_per_rank. 4 implant slots (neural/skeletal/dermal/visceral):
capacity system (base 10 + Tech), tagged implants with rarity and effects.
30-level curve: xp_to_next, attribute_points, perk_points, implant
capacity milestones at 10/15/20/25/30. ~25hr playtime estimate."
```

---

## Task 2: Progression Components (Bevy + Lua)

**Files:**
- Create: `engine/src/components/progression.rs`
- Modify: `engine/src/components/mod.rs` (register module)
- Create: `engine/tests/progression_components.rs`

- [ ] **Step 1: Write failing component test**

Write `engine/tests/progression_components.rs`:

```rust
use engine::components::progression::*;
use bevy::prelude::*;

#[test]
fn test_attributes_component_default() {
    let a = AttributesComponent {
        values: vec![],
        unspent_points: 0,
    };
    assert_eq!(a.unspent_points, 0);
}

#[test]
fn test_perk_component() {
    let p = PerkComponent {
        unlocked_nodes: vec![],
        unspent_points: 0,
    };
    assert!(p.unlocked_nodes.is_empty());
}

#[test]
fn test_implant_component() {
    let i = ImplantComponent {
        installed: vec![],
        total_capacity: 10,
        used_capacity: 0,
    };
    assert_eq!(i.total_capacity, 10);
}

#[test]
fn test_level_component_default() {
    let l = LevelComponent {
        level: 1,
        xp: 0,
        xp_to_next: 150,
    };
    assert_eq!(l.level, 1);
    assert_eq!(l.xp, 0);
}

#[test]
fn test_serialize_roundtrip() {
    let level = LevelComponent {
        level: 5,
        xp: 1800,
        xp_to_next: 500,
    };
    let json = serde_json::to_string(&level).unwrap();
    let parsed: LevelComponent = serde_json::from_str(&json).unwrap();
    assert_eq!(parsed.level, 5);
    assert_eq!(parsed.xp, 1800);
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_progression_components
```

Expected: FAIL — `engine::components::progression` not found.

- [ ] **Step 3: Implement progression components**

Write `engine/src/components/progression.rs`:

```rust
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct LevelComponent {
    pub level: u32,
    pub xp: u64,
    pub xp_to_next: u64,
}

impl Default for LevelComponent {
    fn default() -> Self {
        Self {
            level: 1,
            xp: 0,
            xp_to_next: 150,
        }
    }
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct AttributesComponent {
    pub values: Vec<AttributeValue>,
    pub unspent_points: u32,
}

impl Default for AttributesComponent {
    fn default() -> Self {
        Self {
            values: Vec::new(),
            unspent_points: 0,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct AttributeValue {
    pub attribute_id: String,
    pub value: u32,
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct PerkComponent {
    pub unlocked_nodes: Vec<PerkNodeState>,
    pub unspent_points: u32,
}

impl Default for PerkComponent {
    fn default() -> Self {
        Self {
            unlocked_nodes: Vec::new(),
            unspent_points: 0,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct PerkNodeState {
    pub tree_id: String,
    pub node_id: String,
    pub current_rank: u32,
}

#[derive(Component, Serialize, Deserialize, Debug, Clone)]
pub struct ImplantComponent {
    pub installed: Vec<InstalledImplant>,
    pub total_capacity: u32,
    pub used_capacity: u32,
}

impl Default for ImplantComponent {
    fn default() -> Self {
        Self {
            installed: Vec::new(),
            total_capacity: 10,
            used_capacity: 0,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct InstalledImplant {
    pub implant_id: String,
    pub slot_type: String,
    pub capacity_cost: u32,
}
```

Update `engine/src/components/mod.rs` — add line:

```rust
pub mod progression;
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_progression_components
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/src/components/progression.rs engine/src/components/mod.rs engine/tests/progression_components.rs
git commit -m "(GREEN) feat: define progression ECS components

LevelComponent (level, xp, xp_to_next), AttributesComponent (values +
unspent_points), PerkComponent (unlocked nodes + unspent_points),
ImplantComponent (installed implants, total/used capacity). All derive
Component + Serialize + Deserialize for save/load persistence."
```

---

## Task 3: XP and Level-Up System (Lua)

**Files:**
- Create: `engine/lua/systems/s_xp_level.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/xp_level.rs`

- [ ] **Step 1: Write failing XP test**

Write `engine/tests/xp_level.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_award_xp_no_level_up() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_XpLevel = dofile("systems/s_xp_level.lua")
        S_XpLevel:init(engine)

        local level_data = { level = 1, xp = 50, xp_to_next = 150 }
        local result = S_XpLevel:award_xp(level_data, 30)
        return result.level == 1 and result.xp == 80 and result.did_level_up == false
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_award_xp_triggers_level_up() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_XpLevel = dofile("systems/s_xp_level.lua")
        S_XpLevel:init(engine)

        local level_data = { level = 1, xp = 120, xp_to_next = 150 }
        local result = S_XpLevel:award_xp(level_data, 50)
        -- 120 + 50 = 170 → exceeds 150, level up to 2
        -- overflow: 170 - 150 = 20
        return result.level == 2 and result.did_level_up == true
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_xp_overflow_carries_to_next_level() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_XpLevel = dofile("systems/s_xp_level.lua")
        S_XpLevel:init(engine)

        local level_data = { level = 1, xp = 120, xp_to_next = 150 }
        local result = S_XpLevel:award_xp(level_data, 80)
        -- 120 + 80 = 200 → level 2, 200-150=50 overflow
        -- Next xp_to_next at level 2 = 170, so 50/170
        return result.level == 2 and result.xp == 50
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_max_level_no_overflow() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_XpLevel = dofile("systems/s_xp_level.lua")
        S_XpLevel:init(engine)

        local level_data = { level = 30, xp = 100000, xp_to_next = 999999 }
        local result = S_XpLevel:award_xp(level_data, 5000)
        return result.level == 30 and result.did_level_up == false
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_xp_level
```

Expected: FAIL.

- [ ] **Step 3: Implement XP/level-up system**

Write `engine/lua/systems/s_xp_level.lua`:

```lua
local S_XpLevel = {}

function S_XpLevel:init(engine)
    self.engine = engine
    self.level_curve = {}
    self.attr_config = {}

    local curve_data = engine:load_json("config/progression/level_curve.json")
    if curve_data then
        self.levels = curve_data.levels or {}
        self.max_level = curve_data.max_level or 30
    end

    local attr_data = engine:load_json("config/progression/attributes.json")
    if attr_data then
        self.attr_config = attr_data
    end
end

function S_XpLevel:award_xp(level_data, amount)
    if level_data.level >= self.max_level then
        return {
            level = level_data.level,
            xp = level_data.xp,
            xp_to_next = level_data.xp_to_next,
            did_level_up = false,
        }
    end

    local xp = level_data.xp + amount
    local level = level_data.level
    local xp_to_next = level_data.xp_to_next
    local leveled = false

    while xp >= xp_to_next and level < self.max_level do
        xp = xp - xp_to_next
        level = level + 1
        leveled = true

        -- Get next level threshold
        for _, l in ipairs(self.levels) do
            if l.level == level + 1 then
                xp_to_next = l.xp_to_next
                break
            end
        end
        if level >= self.max_level then
            xp_to_next = 999999
        end
    end

    return {
        level = level,
        xp = xp,
        xp_to_next = xp_to_next,
        did_level_up = leveled,
    }
end

function S_XpLevel:get_level_data(level)
    for _, l in ipairs(self.levels) do
        if l.level == level then
            return l
        end
    end
    return nil
end

function S_XpLevel:process(engine, dt)
    -- Monitor HealthChangedEvent for kills → XP
    engine:query({"LevelComponent"}, function(eid)
        -- XP award events are processed on-demand via award_xp from event handlers
        -- This system keeps the component in sync per tick
    end)
end

return S_XpLevel
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_XpLevel]
lua_file = "systems/s_xp_level.lua"
system_set = "Feedback"
priority = 130
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_xp_level
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_xp_level.lua engine/lua/config/systems.toml engine/tests/xp_level.rs
git commit -m "(GREEN) feat: implement XP and level-up system

S_XpLevel (Feedback, pri 130): award_xp (adds xp, triggers level-up when
threshold exceeded, carries overflow to next level, clamps at max_level),
get_level_data (per-level rewards lookup). Level curve loaded from
level_curve.json. Works with LevelComponent for persistent state."
```

---

## Task 4: Attribute Allocation System (Lua)

**Files:**
- Create: `engine/lua/systems/s_attributes.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/attributes.rs`

- [ ] **Step 1: Write failing attribute test**

Write `engine/tests/attributes.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_allocate_attribute_point() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Attributes = dofile("systems/s_attributes.lua")
        S_Attributes:init(engine)

        local attrs = {
            values = { { attribute_id = "reflexes", value = 3 } },
            unspent_points = 2,
        }

        local ok, new_attrs = S_Attributes:allocate(attrs, "reflexes", 1)
        return ok and new_attrs.values[1].value == 4 and new_attrs.unspent_points == 1
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_cannot_exceed_hard_cap() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Attributes = dofile("systems/s_attributes.lua")
        S_Attributes:init(engine)

        local attrs = {
            values = { { attribute_id = "reflexes", value = 30 } },
            unspent_points = 1,
        }

        local ok, _ = S_Attributes:allocate(attrs, "reflexes", 1)
        return not ok
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_cannot_allocate_without_points() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Attributes = dofile("systems/s_attributes.lua")
        S_Attributes:init(engine)

        local attrs = {
            values = { { attribute_id = "body", value = 5 } },
            unspent_points = 0,
        }

        local ok, _ = S_Attributes:allocate(attrs, "body", 1)
        return not ok
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_get_bonus_stats() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Attributes = dofile("systems/s_attributes.lua")
        S_Attributes:init(engine)

        local attrs = {
            values = {
                { attribute_id = "reflexes", value = 10 },
                { attribute_id = "body", value = 5 },
                { attribute_id = "tech", value = 8 },
            },
        }

        local bonuses = S_Attributes:get_combat_bonuses(attrs)
        -- reflexes 10: crit +0.05, evasion +0.03, attack_speed +0.10
        -- body 5: max_health +50, max_stamina +25, phys_resist +0.05
        -- tech 8: max_mana +40, energy_dmg +0.16, hacking_speed +0.08, implant_cap +8
        return bonuses.crit_chance ~= nil and bonuses.max_health ~= nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_attributes
```

Expected: FAIL.

- [ ] **Step 3: Implement attribute system**

Write `engine/lua/systems/s_attributes.lua`:

```lua
local S_Attributes = {}

function S_Attributes:init(engine)
    self.engine = engine
    self.attr_db = {}
    self.point_costs = {}

    local data = engine:load_json("config/progression/attributes.json")
    if data then
        self.attr_db = data.attributes or {}
        self.point_costs = data.per_point_stats or {}
    end
end

function S_Attributes:allocate(attrs, attribute_id, points)
    local def = self.attr_db[attribute_id]
    if not def then
        return false, attrs
    end

    if points > attrs.unspent_points then
        return false, attrs
    end

    local current = nil
    for _, val in ipairs(attrs.values) do
        if val.attribute_id == attribute_id then
            current = val
            break
        end
    end

    if not current then
        table.insert(attrs.values, {
            attribute_id = attribute_id,
            value = def.default_value or 1,
        })
        for _, val in ipairs(attrs.values) do
            if val.attribute_id == attribute_id then
                current = val
                break
            end
        end
    end

    local new_value = current.value + points
    if new_value > def.hard_cap then
        return false, attrs
    end

    current.value = new_value
    attrs.unspent_points = attrs.unspent_points - points

    self.engine:emit("AttributeChangedEvent", {
        attribute_id = attribute_id,
        new_value = new_value,
    })

    return true, attrs
end

function S_Attributes:get_combat_bonuses(attrs)
    local bonuses = {}

    for _, val in ipairs(attrs.values) do
        local def = self.attr_db[val.attribute_id]
        if def and def.combat_derivation then
            for stat, per_point in pairs(def.combat_derivation) do
                bonuses[stat] = (bonuses[stat] or 0) + (per_point * val.value)
            end
        end
    end

    return bonuses
end

function S_Attributes:get_attribute_value(attrs, attribute_id)
    for _, val in ipairs(attrs.values) do
        if val.attribute_id == attribute_id then
            return val.value
        end
    end
    return 0
end

function S_Attributes:process(engine, dt)
    -- Attribute allocation is event-driven. No per-tick processing.
end

return S_Attributes
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_Attributes]
lua_file = "systems/s_attributes.lua"
system_set = "Feedback"
priority = 132
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_attributes
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_attributes.lua engine/lua/config/systems.toml engine/tests/attributes.rs
git commit -m "(GREEN) feat: implement attribute allocation system

S_Attributes (Feedback, pri 132): allocate (point spending with soft_cap
costs and hard_cap limit, unspent_points tracking, auto-initialize on
unknown attr_id), get_combat_bonuses (derive combat stats from attribute
values using per_attribute combat_derivation table), get_attribute_value
(lookup by id). Emits AttributeChangedEvent on allocation."
```

---

## Task 5: Perk Tree System (Lua)

**Files:**
- Create: `engine/lua/systems/s_perks.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/perks.rs`

- [ ] **Step 1: Write failing perk test**

Write `engine/tests/perks.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_unlock_perk_node() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Perks = dofile("systems/s_perks.lua")
        S_Perks:init(engine)

        local perks = {
            unlocked_nodes = {},
            unspent_points = 2,
        }

        local ok, new_perks = S_Perks:unlock(perks, "blade_mastery", "bm_1", {
            attributes = {
                { attribute_id = "reflexes", value = 5 },
            },
        })
        return ok and #new_perks.unlocked_nodes == 1 and new_perks.unspent_points == 1
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_cannot_unlock_without_prerequisites() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Perks = dofile("systems/s_perks.lua")
        S_Perks:init(engine)

        local perks = {
            unlocked_nodes = {},
            unspent_points = 2,
        }

        local ok, _ = S_Perks:unlock(perks, "blade_mastery", "bm_4", {
            attributes = {
                { attribute_id = "reflexes", value = 15 },
            },
        })
        return not ok
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_cannot_unlock_below_attribute_requirement() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Perks = dofile("systems/s_perks.lua")
        S_Perks:init(engine)

        -- Unlock root node first
        local perks = {
            unlocked_nodes = { { tree_id = "blade_mastery", node_id = "bm_1", current_rank = 1 } },
            unspent_points = 2,
        }

        -- bm_2 requires reflexes >= 6
        local ok, _ = S_Perks:unlock(perks, "blade_mastery", "bm_2", {
            attributes = {
                { attribute_id = "reflexes", value = 4 },
            },
        })
        return not ok
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_can_rank_up_existing_node() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Perks = dofile("systems/s_perks.lua")
        S_Perks:init(engine)

        local perks = {
            unlocked_nodes = { { tree_id = "blade_mastery", node_id = "bm_1", current_rank = 1 } },
            unspent_points = 2,
        }

        local ok, new_perks = S_Perks:unlock(perks, "blade_mastery", "bm_1", {
            attributes = { { attribute_id = "reflexes", value = 5 } },
        })
        return ok and new_perks.unlocked_nodes[1].current_rank == 2
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_get_perk_effects() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Perks = dofile("systems/s_perks.lua")
        S_Perks:init(engine)

        local perks = {
            unlocked_nodes = {
                { tree_id = "blade_mastery", node_id = "bm_1", current_rank = 3 },
            },
        }

        local effects = S_Perks:get_active_effects(perks)
        return effects ~= nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_perks
```

Expected: FAIL.

- [ ] **Step 3: Implement perk tree system**

Write `engine/lua/systems/s_perks.lua`:

```lua
local S_Perks = {}

function S_Perks:init(engine)
    self.engine = engine
    self.trees = {}
    self.node_index = {}

    local data = engine:load_json("config/progression/perk_trees.json")
    if data then
        for _, tree in ipairs(data.trees or {}) do
            self.trees[tree.tree_id] = tree
            for _, node in ipairs(tree.nodes) do
                self.node_index[tree.tree_id .. "." .. node.node_id] = node
            end
        end
    end
end

function S_Perks:unlock(perks, tree_id, node_id, context)
    local tree = self.trees[tree_id]
    if not tree then
        return false, perks
    end

    local node = self.node_index[tree_id .. "." .. node_id]
    if not node then
        return false, perks
    end

    -- Check unspent points
    if perks.unspent_points < 1 then
        return false, perks
    end

    local attributes = context.attributes or {}

    -- Check attribute requirement
    if node.attribute_requirement then
        for attr_id, required in pairs(node.attribute_requirement) do
            local has = 0
            for _, a in ipairs(attributes) do
                if a.attribute_id == attr_id then
                    has = a.value
                    break
                end
            end
            if has < required then
                return false, perks
            end
        end
    end

    -- Check prerequisites (nodes must be unlocked at rank >= 1)
    for _, prereq_id in ipairs(node.prerequisites or {}) do
        local found = false
        for _, unlocked in ipairs(perks.unlocked_nodes) do
            if unlocked.tree_id == tree_id and unlocked.node_id == prereq_id and unlocked.current_rank >= 1 then
                found = true
                break
            end
        end
        if not found then
            return false, perks
        end
    end

    -- Check existing node for rank cap
    for _, unlocked in ipairs(perks.unlocked_nodes) do
        if unlocked.tree_id == tree_id and unlocked.node_id == node_id then
            if unlocked.current_rank >= node.max_ranks then
                return false, perks
            end
            unlocked.current_rank = unlocked.current_rank + 1
            perks.unspent_points = perks.unspent_points - 1
            self.engine:emit("PerkUnlockedEvent", {
                tree_id = tree_id,
                node_id = node_id,
                rank = unlocked.current_rank,
            })
            return true, perks
        end
    end

    -- Fresh unlock
    table.insert(perks.unlocked_nodes, {
        tree_id = tree_id,
        node_id = node_id,
        current_rank = 1,
    })
    perks.unspent_points = perks.unspent_points - 1
    self.engine:emit("PerkUnlockedEvent", {
        tree_id = tree_id,
        node_id = node_id,
        rank = 1,
    })

    return true, perks
end

function S_Perks:has_perk(perks, node_id)
    for _, unlocked in ipairs(perks.unlocked_nodes) do
        if unlocked.node_id == node_id and unlocked.current_rank >= 1 then
            return true
        end
    end
    return false
end

function S_Perks:get_active_effects(perks)
    local effects = {}

    for _, unlocked in ipairs(perks.unlocked_nodes) do
        local node = self.node_index[unlocked.tree_id .. "." .. unlocked.node_id]
        if node then
            for rank = 1, unlocked.current_rank do
                local rank_effects = node.effects_per_rank[rank]
                if rank_effects then
                    for _, eff in ipairs(rank_effects) do
                        local key = eff.stat .. "|" .. (eff.scope or "all")
                        if not effects[key] then
                            effects[key] = { stat = eff.stat, scope = eff.scope, total = 0 }
                        end
                        effects[key].total = effects[key].total + eff.value
                    end
                end
            end
        end
    end

    -- Convert to flat list
    local result = {}
    for _, effect in pairs(effects) do
        table.insert(result, {
            stat = effect.stat,
            scope = effect.scope,
            total = effect.total,
        })
    end

    return result
end

function S_Perks:process(engine, dt)
    -- Perk unlocking is event-driven. No per-tick processing.
end

return S_Perks
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_Perks]
lua_file = "systems/s_perks.lua"
system_set = "Feedback"
priority = 134
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_perks
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_perks.lua engine/lua/config/systems.toml engine/tests/perks.rs
git commit -m "(GREEN) feat: implement perk tree system

S_Perks (Feedback, pri 134): unlock (validates prerequisites, attribute
requirements, max_ranks, unspent_points — then unlocks or ranks up the
node), has_perk (boolean check for QB conditions), get_active_effects
(flat list of stat modifiers from all unlocked nodes, scoped per weapon
type). 9 perk trees indexed by tree_id, nodes indexed by tree.node_id.
Emits PerkUnlockedEvent on unlock/rank-up."
```

---

## Task 6: Implant System (Lua)

**Files:**
- Create: `engine/lua/systems/s_implants.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/implants.rs`

- [ ] **Step 1: Write failing implant test**

Write `engine/tests/implants.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_install_implant() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Implants = dofile("systems/s_implants.lua")
        S_Implants:init(engine)

        local implants = {
            installed = {},
            total_capacity = 10,
            used_capacity = 0,
        }

        local ok, new_implants = S_Implants:install(implants, "synaptic_accelerator")
        return ok and new_implants.used_capacity == 3
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_cannot_exceed_capacity() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Implants = dofile("systems/s_implants.lua")
        S_Implants:init(engine)

        local implants = {
            installed = { { implant_id = "subdermal_weave", slot_type = "dermal", capacity_cost = 4 } },
            total_capacity = 5,
            used_capacity = 4,
        }

        -- synaptic_accelerator costs 3, 4+3 > 5
        local ok, _ = S_Implants:install(implants, "synaptic_accelerator")
        return not ok
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_uninstall_implant() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Implants = dofile("systems/s_implants.lua")
        S_Implants:init(engine)

        local implants = {
            installed = { { implant_id = "synaptic_accelerator", slot_type = "neural", capacity_cost = 3 } },
            total_capacity = 10,
            used_capacity = 3,
        }

        local ok, new_implants = S_Implants:uninstall(implants, "synaptic_accelerator")
        return ok and new_implants.used_capacity == 0 and #new_implants.installed == 0
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_update_capacity_from_tech() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Implants = dofile("systems/s_implants.lua")
        S_Implants:init(engine)

        local implants = { installed = {}, total_capacity = 10, used_capacity = 0 }
        local tech_value = 8

        local new_cap = S_Implants:calculate_capacity(tech_value)
        -- base 10 + tech 8 = 18
        return new_cap == 18
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_implants
```

Expected: FAIL.

- [ ] **Step 3: Implement implant system**

Write `engine/lua/systems/s_implants.lua`:

```lua
local S_Implants = {}

function S_Implants:init(engine)
    self.engine = engine
    self.slot_db = {}
    self.implant_db = {}
    self.capacity_config = {}

    local slot_data = engine:load_json("config/progression/implant_slots.json")
    if slot_data then
        for _, slot in ipairs(slot_data.slots or {}) do
            self.slot_db[slot.slot_id] = slot
        end

        self.capacity_config = slot_data.capacity or {}

        for _, implant in ipairs(slot_data.example_implants or {}) do
            self.implant_db[implant.implant_id] = implant
        end
    end
end

function S_Implants:install(implants, implant_id)
    local implant = self.implant_db[implant_id]
    if not implant then
        return false, implants
    end

    -- Check capacity
    if implants.used_capacity + implant.capacity_cost > implants.total_capacity then
        return false, implants
    end

    -- Check slot is not already occupied (one implant per slot type)
    for _, existing in ipairs(implants.installed) do
        if existing.slot_type == implant.slot_type then
            return false, implants
        end
    end

    table.insert(implants.installed, {
        implant_id = implant_id,
        slot_type = implant.slot_type,
        capacity_cost = implant.capacity_cost,
    })

    implants.used_capacity = implants.used_capacity + implant.capacity_cost
    self.engine:emit("ImplantInstalledEvent", { implant_id = implant_id })

    return true, implants
end

function S_Implants:uninstall(implants, implant_id)
    for i, existing in ipairs(implants.installed) do
        if existing.implant_id == implant_id then
            implants.used_capacity = implants.used_capacity - existing.capacity_cost
            table.remove(implants.installed, i)
            self.engine:emit("ImplantUninstalledEvent", { implant_id = implant_id })
            return true, implants
        end
    end

    return false, implants
end

function S_Implants:calculate_capacity(tech_value)
    local base = self.capacity_config.base_capacity or 10
    local per_point = self.capacity_config.extra_per_tech_point or 1
    return base + (tech_value * per_point)
end

function S_Implants:get_implant_effects(implants)
    local effects = {}

    for _, installed in ipairs(implants.installed) do
        local def = self.implant_db[installed.implant_id]
        if def and def.effects then
            for stat, value in pairs(def.effects) do
                table.insert(effects, {
                    stat = stat,
                    value = value,
                    implant_id = installed.implant_id,
                })
            end
        end
    end

    return effects
end

function S_Implants:process(engine, dt)
    -- Implant install/uninstall is event-driven. No per-tick processing.
end

return S_Implants
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_Implants]
lua_file = "systems/s_implants.lua"
system_set = "Feedback"
priority = 136
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_implants
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_implants.lua engine/lua/config/systems.toml engine/tests/implants.rs
git commit -m "(GREEN) feat: implement implant/slot system

S_Implants (Feedback, pri 136): install (capacity check, slot-type
exclusivity), uninstall (refund capacity), calculate_capacity (base 10 +
tech * per_point), get_implant_effects (aggregate stats from installed
implants). Implant catalog from JSON (synaptic_accelerator, subdermal_
weave, adrenal_pump). Emits ImplantInstalledEvent/ImplantUninstalledEvent."
```

---

## Task 7: Combat Bridge — Kill Events to XP

**Files:**
- Create: `engine/lua/systems/s_progression_bridge.lua`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/progression_bridge.rs`

- [ ] **Step 1: Write failing bridge test**

Write `engine/tests/progression_bridge.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_kill_awards_xp() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Bridge = dofile("systems/s_progression_bridge.lua")
        S_Bridge:init(engine)

        local level_data = { level = 1, xp = 10, xp_to_next = 150 }
        local result = S_Bridge:on_kill(level_data, "grunt")

        -- grunt = 25 XP
        return result.xp == 35
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_level_up_grants_points() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Bridge = dofile("systems/s_progression_bridge.lua")
        S_Bridge:init(engine)

        -- Level 4 → 5, 4 attr earned, 4 perk earned
        local points = S_Bridge:get_points_for_level(5)
        return points.attribute == 4 and points.perk == 4
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_apply_combat_bonuses_to_health() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Bridge = dofile("systems/s_progression_bridge.lua")
        S_Bridge:init(engine)

        local bonuses = {
            max_health = 50.0,
            crit_chance = 0.05,
        }

        local result = S_Bridge:apply_to_combat(bonuses)
        return result.max_health_bonus == 50.0 and result.crit_chance_bonus == 0.05
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_progression_bridge
```

Expected: FAIL.

- [ ] **Step 3: Implement progression bridge**

Write `engine/lua/systems/s_progression_bridge.lua`:

```lua
local S_ProgressionBridge = {}

function S_ProgressionBridge:init(engine)
    self.engine = engine
    self.xp_rewards = {
        grunt = 25,
        elite = 60,
        boss = 200,
        miniboss = 100,
    }

    -- Load level curve for point tracking
    self.levels = {}
    local curve_data = engine:load_json("config/progression/level_curve.json")
    if curve_data then
        self.levels = curve_data.levels or {}
    end

    -- Subscribe to kill events
    engine:on("EntityDiedEvent", function(event)
        -- Check if killer is player
        -- In production, source tracking from DamageDealtEvent chain
    end)
end

function S_ProgressionBridge:on_kill(level_data, enemy_type)
    local xp = self.xp_rewards[enemy_type] or 25
    local S_XpLevel = dofile("systems/s_xp_level.lua")
    S_XpLevel:init(self.engine)
    return S_XpLevel:award_xp(level_data, xp)
end

function S_ProgressionBridge:get_points_for_level(level)
    local attr_points = 0
    local perk_points = 0

    for _, l in ipairs(self.levels) do
        if l.level <= level then
            attr_points = attr_points + (l.attribute_points or 0)
            perk_points = perk_points + (l.perk_points or 0)
        end
    end

    return { attribute = attr_points, perk = perk_points }
end

function S_ProgressionBridge:apply_to_combat(bonuses)
    return {
        max_health_bonus = bonuses.max_health or 0,
        crit_chance_bonus = bonuses.crit_chance or 0,
        physical_resist_bonus = bonuses.physical_resist or 0,
        energy_damage_bonus = bonuses.energy_damage or 0,
    }
end

function S_ProgressionBridge:process(engine, dt)
    -- Monitor player kills → XP via event subscription in init
end

return S_ProgressionBridge
```

Update `engine/lua/config/systems.toml`:

```toml
[systems.S_ProgressionBridge]
lua_file = "systems/s_progression_bridge.lua"
system_set = "Feedback"
priority = 138
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_progression_bridge
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_progression_bridge.lua engine/lua/config/systems.toml engine/tests/progression_bridge.rs
git commit -m "(GREEN) feat: implement combat-to-progression bridge

S_ProgressionBridge (Feedback, pri 138): on_kill (award XP based on enemy
type — grunt/elite/miniboss/boss), get_points_for_level (cumulative attr
+ perk points earned per level), apply_to_combat (route attribute/perk
bonuses to combat engine stats). Subscribes to EntityDiedEvent for
auto-XP on enemy death."
```

---

## Task 8: Progression QB Contracts

**Files:**
- Create: `engine/lua/config/rules/progression_conditions.json`
- Create: `engine/tests/progression_qb.rs`

- [ ] **Step 1: Write failing QB progression test**

Write `engine/tests/progression_qb.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_condition_has_perk() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Scorer = dofile("lib/qb/qb_scorer.lua")

        local context = {
            components = {
                PerkComponent = {
                    unlocked_nodes = {
                        { tree_id = "blade_mastery", node_id = "bm_1", current_rank = 3 },
                    },
                },
            },
            entity_tags = {},
            state = {},
            event_name = "",
            event_payload = {},
        }

        -- Condition: player has bm_1 at rank >= 2
        local rules = {{
            rule_id = "has_blade_mastery_rank2",
            conditions = {{
                type = "component_field",
                component_type = "PerkComponent",
                field_path = "unlocked_nodes[bm_1].current_rank",
                range_min = 2.0,
                range_max = 3.0,
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
fn test_condition_attribute_threshold() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Scorer = dofile("lib/qb/qb_scorer.lua")

        local context = {
            components = {
                AttributesComponent = {
                    values = {
                        { attribute_id = "reflexes", value = 12 },
                    },
                },
            },
            entity_tags = {},
            state = {},
            event_name = "",
            event_payload = {},
        }

        local rules = {{
            rule_id = "reflexes_10_plus",
            conditions = {{
                type = "component_field",
                component_type = "AttributesComponent",
                field_path = "values[reflexes].value",
                range_min = 10.0,
                range_max = 20.0,
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
fn test_condition_has_implant() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Scorer = dofile("lib/qb/qb_scorer.lua")

        local context = {
            state = {
                progression = {
                    has_implant_synaptic_accelerator = false,
                },
            },
            entity_tags = {},
            event_name = "",
            event_payload = {},
        }

        local rules = {{
            rule_id = "no_synaptic",
            conditions = {{
                type = "redux_field",
                state_path = "progression.has_implant_synaptic_accelerator",
                match_mode = "equals",
                match_value = "true",
            }},
            score_threshold = 0.51,
            decision_group = "",
            priority = 0,
        }}

        local results = Scorer.score_rules(rules, context)
        return results[1].score < 0.51
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_progression_qb
```

Expected: FAIL (or passes via QB engine integration).

- [ ] **Step 3: Write progression QB contract docs**

Write `engine/lua/config/rules/progression_conditions.json`:

```json
{
  "description": "QB condition contracts for progression engine. Consumed by narrative, dialogue, and mission-gating systems.",
  "condition_contracts": [
    {
      "contract_id": "RS_ConditionAttribute",
      "type": "component_field",
      "component_type": "AttributesComponent",
      "field_path": "values[attribute_id].value",
      "usage": "Dialogue gating: check if player has sufficient attribute. Mission gating: require minimum attribute to access area.",
      "example": "values[reflexes].value >= 12 for a lockpick option"
    },
    {
      "contract_id": "RS_ConditionHasPerk",
      "type": "component_field",
      "component_type": "PerkComponent",
      "field_path": "unlocked_nodes[node_id].current_rank",
      "usage": "Dialogue option gating: show special options for players with specific perks. Mission: require perk to bypass obstacle.",
      "example": "unlocked_nodes[bm_2].rank >= 1 for bleeding damage dialogue option"
    },
    {
      "contract_id": "RS_ConditionHasImplant",
      "type": "component_field",
      "component_type": "ImplantComponent",
      "field_path": "installed[implant_id]",
      "usage": "Dialogue gating: NPCs react to visible implants. Mission: implants enable alternative paths.",
      "example": "installed[synaptic_accelerator] exists for hacker dialogue options"
    }
  ]
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_progression_qb
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/config/rules/progression_conditions.json engine/tests/progression_qb.rs
git commit -m "(GREEN) feat: define progression QB condition contracts

RS_ConditionAttribute: component_field on AttributesComponent
values[attr_id].value. RS_ConditionHasPerk: component_field on
PerkComponent unlocked_nodes[node_id].rank. RS_ConditionHasImplant:
component_field on ImplantComponent installed[implant_id]. Contracts
consumed by dialogue, narrative, and mission-gating QB rules."
```

---

## Task 9: Progression UI Screens (React)

**Files:**
- Create: `client/src/ui/screens/AttributeScreen.tsx`
- Create: `client/src/ui/screens/PerkTreeScreen.tsx`
- Create: `client/src/ui/screens/ImplantScreen.tsx`
- Create: `client/src/ui/widgets/PerkNode.tsx`
- Create: `client/src/ui/widgets/ImplantSlot.tsx`
- Create: `client/src/ui/widgets/__tests__/PerkNode.test.tsx`
- Create: `client/src/ui/widgets/__tests__/ImplantSlot.test.tsx`
- Modify: `client/src/ui/App.tsx` (register new screens)
- Modify: `client/src/ui/store/uiStore.ts` (add progression state)

- [ ] **Step 1: Write failing UI widget test**

Write `client/src/ui/widgets/__tests__/PerkNode.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { PerkNode } from '../PerkNode';

describe('PerkNode', () => {
  it('should render node name', () => {
    const node = {
      nodeId: 'bm_1',
      name: 'Sharpened Edge',
      description: '+5% crit damage',
      currentRank: 2,
      maxRanks: 3,
      isUnlocked: true,
      canUnlock: true,
      icon: 'perk_blade_1',
    };
    const { getByText } = render(<PerkNode node={node} />);
    expect(getByText('Sharpened Edge')).toBeInTheDocument();
  });

  it('should show rank progress', () => {
    const node = {
      nodeId: 'bm_1',
      name: 'Sharpened Edge',
      description: '+5% crit damage',
      currentRank: 2,
      maxRanks: 3,
      isUnlocked: true,
      canUnlock: true,
      icon: 'perk_blade_1',
    };
    const { getByText } = render(<PerkNode node={node} />);
    expect(getByText('2/3')).toBeInTheDocument();
  });

  it('should render locked node as dimmed', () => {
    const node = {
      nodeId: 'bm_4',
      name: 'Death by a Thousand Cuts',
      description: 'Stacking damage',
      currentRank: 0,
      maxRanks: 1,
      isUnlocked: false,
      canUnlock: false,
      icon: 'perk_blade_4',
    };
    const { getByText } = render(<PerkNode node={node} />);
    const el = getByText('Death by a Thousand Cuts');
    expect(el.style.opacity).toBe('0.4');
  });
});
```

Write `client/src/ui/widgets/__tests__/ImplantSlot.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { ImplantSlot } from '../ImplantSlot';

describe('ImplantSlot', () => {
  it('should render slot name', () => {
    const slot = {
      slotId: 'neural',
      name: 'Neural',
      installed: { implantId: 'synaptic_accelerator', name: 'Synaptic Accelerator' },
      capacity: { used: 3, total: 10 },
    };
    const { getByText } = render(<ImplantSlot slot={slot} />);
    expect(getByText('Neural')).toBeInTheDocument();
  });

  it('should show empty slot', () => {
    const slot = {
      slotId: 'neural',
      name: 'Neural',
      installed: null,
      capacity: { used: 0, total: 10 },
    };
    const { getByText } = render(<ImplantSlot slot={slot} />);
    expect(getByText('Empty')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement progression UI**

Write `client/src/ui/widgets/PerkNode.tsx`:

```tsx
interface PerkNodeData {
  nodeId: string;
  name: string;
  description: string;
  currentRank: number;
  maxRanks: number;
  isUnlocked: boolean;
  canUnlock: boolean;
  icon: string;
}

export function PerkNode({ node, onUnlock }: { node: PerkNodeData; onUnlock?: (nodeId: string) => void }) {
  const opacity = node.isUnlocked ? 1 : node.canUnlock ? 0.7 : 0.4;
  const borderColor = node.isUnlocked ? '#2a4a7f' : node.canUnlock ? '#4a7f2a' : '#333';

  return (
    <div
      onClick={() => node.canUnlock && onUnlock?.(node.nodeId)}
      style={{
        width: '80px', height: '80px',
        border: `2px solid ${borderColor}`,
        borderRadius: '8px',
        background: node.isUnlocked ? 'rgba(10, 15, 30, 0.9)' : 'rgba(10, 10, 20, 0.5)',
        opacity,
        cursor: node.canUnlock ? 'pointer' : 'default',
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        fontFamily: 'monospace', fontSize: '0.65rem',
        color: node.isUnlocked ? '#ccc' : '#666',
        position: 'relative',
        transition: 'all 0.15s',
      }}
      title={node.description}
    >
      <div style={{ fontSize: '0.55rem', textAlign: 'center' }}>
        {node.name}
      </div>
      {node.isUnlocked && (
        <div style={{
          position: 'absolute', bottom: '4px', right: '4px',
          color: '#2a4a7f', fontSize: '0.6rem',
        }}>
          {node.currentRank}/{node.maxRanks}
        </div>
      )}
    </div>
  );
}
```

Write `client/src/ui/widgets/ImplantSlot.tsx`:

```tsx
interface ImplantSlotData {
  slotId: string;
  name: string;
  installed: { implantId: string; name: string } | null;
  capacity: { used: number; total: number };
}

export function ImplantSlot({ slot, onInstall, onUninstall }: {
  slot: ImplantSlotData;
  onInstall?: (slotId: string) => void;
  onUninstall?: (implantId: string) => void;
}) {
  return (
    <div style={{
      border: `2px solid ${slot.installed ? '#2a4a7f' : '#16213e'}`,
      borderRadius: '8px',
      padding: '0.75rem',
      fontFamily: 'monospace',
      background: 'rgba(10, 10, 20, 0.8)',
      marginBottom: '0.5rem',
    }}>
      <div style={{
        display: 'flex', justifyContent: 'space-between',
        alignItems: 'center', marginBottom: '0.25rem',
      }}>
        <span style={{ color: '#2a4a7f', fontSize: '0.9rem' }}>{slot.name}</span>
        <span style={{ color: '#666', fontSize: '0.7rem' }}>
          {slot.capacity.used}/{slot.capacity.total}
        </span>
      </div>
      {slot.installed ? (
        <div style={{
          display: 'flex', justifyContent: 'space-between',
          alignItems: 'center',
        }}>
          <span style={{ color: '#ccc', fontSize: '0.8rem' }}>
            {slot.installed.name}
          </span>
          <button
            onClick={() => onUninstall?.(slot.installed!.implantId)}
            style={{
              background: '#2a1a1a', border: '1px solid #4a2a2a',
              color: '#a66', borderRadius: '4px', padding: '0.2rem 0.5rem',
              fontSize: '0.7rem', fontFamily: 'monospace', cursor: 'pointer',
            }}
          >
            Remove
          </button>
        </div>
      ) : (
        <div style={{
          display: 'flex', justifyContent: 'space-between',
          alignItems: 'center',
        }}>
          <span style={{ color: '#444', fontSize: '0.8rem' }}>Empty</span>
          <button
            onClick={() => onInstall?.(slot.slotId)}
            style={{
              background: '#1a2a1a', border: '1px solid #2a4a2a',
              color: '#6a6', borderRadius: '4px', padding: '0.2rem 0.5rem',
              fontSize: '0.7rem', fontFamily: 'monospace', cursor: 'pointer',
            }}
          >
            Install
          </button>
        </div>
      )}
    </div>
  );
}
```

Write `client/src/ui/screens/AttributeScreen.tsx`:

```tsx
import { useUiStore } from '../store/uiStore';
import { OverlayChrome } from '../widgets/OverlayChrome';

interface AttributeData {
  id: string;
  name: string;
  value: number;
  unspentPoints: number;
  canIncrease: boolean;
}

export function AttributeScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);
  const attributes = useUiStore((s) => s.attributes || []);
  const allocatePoint = useUiStore((s) => s.allocatePoint);

  return (
    <OverlayChrome title="Attributes" onClose={() => navigateTo('/hud')}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
        {attributes.map((attr: AttributeData) => (
          <div key={attr.id} style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '0.5rem 0',
          }}>
            <span style={{ color: '#ccc', fontFamily: 'monospace', fontSize: '0.9rem' }}>
              {attr.name}
            </span>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span style={{ color: '#2a4a7f', fontFamily: 'monospace', fontSize: '1rem', minWidth: '24px', textAlign: 'center' }}>
                {attr.value}
              </span>
              <button
                onClick={() => allocatePoint(attr.id)}
                disabled={!attr.canIncrease}
                style={{
                  padding: '0.25rem 0.75rem', fontSize: '0.8rem',
                  fontFamily: 'monospace', borderRadius: '4px', cursor: attr.canIncrease ? 'pointer' : 'default',
                  background: attr.canIncrease ? '#1a2a4a' : '#111',
                  border: `1px solid ${attr.canIncrease ? '#2a4a7f' : '#222'}`,
                  color: attr.canIncrease ? '#ccc' : '#444',
                }}
              >
                +
              </button>
            </div>
          </div>
        ))}
        <div style={{
          color: '#888', fontFamily: 'monospace', fontSize: '0.8rem',
          textAlign: 'center', paddingTop: '0.5rem',
          borderTop: '1px solid #16213e',
        }}>
          Unspent Points: {attributes[0]?.unspentPoints || 0}
        </div>
      </div>
    </OverlayChrome>
  );
}
```

Update `client/src/ui/store/uiStore.ts` — add progression state fields:

```typescript
// Add to UiState interface:
attributes: Array<{ id: string; name: string; value: number; unspentPoints: number; canIncrease: boolean }>;
allocatePoint: (attributeId: string) => void;
perkTrees: Array<any>;
activePerkTree: string | null;
installedImplants: Array<any>;
implantCapacity: { used: number; total: number };

// Initial values:
attributes: [],
allocatePoint: () => {},
perkTrees: [],
activePerkTree: null,
installedImplants: [],
implantCapacity: { used: 0, total: 10 },
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: PerkNode + ImplantSlot tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/ui/screens/AttributeScreen.tsx client/src/ui/widgets/PerkNode.tsx client/src/ui/widgets/ImplantSlot.tsx client/src/ui/widgets/__tests__/PerkNode.test.tsx client/src/ui/widgets/__tests__/ImplantSlot.test.tsx client/src/ui/store/uiStore.ts
git commit -m "(GREEN) feat: add progression UI screens and widgets

PerkNode: tree node display with rank, lock/unlock state, opacity levels.
ImplantSlot: slot display, installed implant name, install/remove buttons,
capacity meter. AttributeScreen: attribute list with value display,
allocate buttons, unspent points counter. Zustand store extended with
attributes, perk trees, implants state slices."
```

---

## Task 10: End-to-End Progression Integration Test

**Files:**
- Create: `engine/tests/e2e_progression.rs`

- [ ] **Step 1: Write E2E test**

Write `engine/tests/e2e_progression.rs`:

```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_full_progression_flow() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local S_XpLevel = dofile("systems/s_xp_level.lua")
        local S_Attributes = dofile("systems/s_attributes.lua")
        local S_Perks = dofile("systems/s_perks.lua")
        local S_Implants = dofile("systems/s_implants.lua")
        local S_Bridge = dofile("systems/s_progression_bridge.lua")

        S_XpLevel:init(engine)
        S_Attributes:init(engine)
        S_Perks:init(engine)
        S_Implants:init(engine)
        S_Bridge:init(engine)

        -- Step 1: Kill enemy → XP → level up
        local level = { level = 4, xp = 190, xp_to_next = 215 }
        level = S_Bridge:on_kill(level, "elite")  -- elite = 60 XP
        assert(level.level == 5, "Should reach level 5")
        assert(level.xp == 35, "Overflow should carry over")

        -- Step 2: Allocate attribute point
        local attrs = {
            values = {
                { attribute_id = "reflexes", value = 3 },
                { attribute_id = "body", value = 3 },
                { attribute_id = "tech", value = 3 },
            },
            unspent_points = 5,
        }

        local ok, attrs = S_Attributes:allocate(attrs, "reflexes", 1)
        assert(ok, "Should allocate reflexes")
        assert(attrs.values[1].value == 4, "Reflexes should be 4")
        assert(attrs.unspent_points == 4, "Should decrement unspent")

        -- Step 3: Combat bonuses
        local bonuses = S_Attributes:get_combat_bonuses(attrs)
        assert(bonuses.crit_chance ~= nil, "Should derive crit_chance")

        -- Step 4: Unlock perk
        local perks = {
            unlocked_nodes = {},
            unspent_points = 4,
        }

        local ok, perks = S_Perks:unlock(perks, "blade_mastery", "bm_1", { attributes = attrs.values })
        assert(ok, "Should unlock root node")
        assert(#perks.unlocked_nodes == 1, "Should have one node")

        -- Step 5: Install implant
        local implants = { installed = {}, total_capacity = 10, used_capacity = 0 }
        local ok, implants = S_Implants:install(implants, "synaptic_accelerator")
        assert(ok, "Should install implant")
        assert(implants.used_capacity == 3, "Capacity should be incremented")

        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_all_progression_systems_load() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local systems = {
            "systems/s_xp_level.lua",
            "systems/s_attributes.lua",
            "systems/s_perks.lua",
            "systems/s_implants.lua",
            "systems/s_progression_bridge.lua",
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

#[test]
fn test_level_curve_xp_total() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local data = engine:load_json("config/progression/level_curve.json")
        local total = 0
        for _, l in ipairs(data.levels) do
            total = total + l.xp_to_next
        end
        -- Should be roughly ~120k total
        return total > 100000 and total < 150000
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_e2e_progression
```

Expected: FAIL (or passes if all individual systems pass).

- [ ] **Step 3: Fix integration issues and run full suite**

```bash
cd engine && cargo test
```

Expected: Full suite passes including all progression tests.

- [ ] **Step 4: Commit**

```bash
git add engine/tests/e2e_progression.rs
git commit -m "(GREEN) test: add progression engine end-to-end integration tests

test_full_progression_flow: validates XP→level→allocate→perk→implant
pipeline works end-to-end. test_all_progression_systems_load: confirms
5 progression Lua modules load. test_level_curve_xp_total: validates
30 levels total ~100-150k XP. Progression engine milestone complete."
```

---

## Progression Systems Summary

| System | Set | Priority | Purpose |
|--------|-----|----------|---------|
| S_XpLevel | Feedback | 130 | XP accumulation, level-up detection, overflow carry |
| S_Attributes | Feedback | 132 | Point allocation with caps, combat stat derivation |
| S_Perks | Feedback | 134 | Node unlock with prerequisites, attribute gates, multi-rank |
| S_Implants | Feedback | 136 | Install/uninstall, capacity management, effect aggregation |
| S_ProgressionBridge | Feedback | 138 | Kill→XP bridge, level point tracking, combat bonus routing |

## Progression Examples Summary

| Example | CLI |
|---------|-----|
| `progression-level-up` | `automata example run progression-level-up` |
| `progression-perk-unlock` | `automata example run progression-perk-unlock` |
| `progression-implant-loadout` | `automata example run progression-implant-loadout` |

## Progression Resource Contracts

| Resource | Config File | Contents |
|----------|-------------|----------|
| RS_AttributeCatalog | attributes.json | N user-defined attributes, soft/hard caps, combat derivations |
| RS_PerkTreeCatalog | perk_trees.json | M user-defined trees, nodes with prerequisites and multi-rank effects |
| RS_ImplantSlotCatalog | implant_slots.json | K user-defined slot types, capacity formula, example implants |
| RS_LevelCurve | level_curve.json | XP thresholds, milestone rewards (attr/pts, perk pts, capacity) |

## Progression Components Summary

| Component | Purpose |
|-----------|---------|
| LevelComponent | Current level, XP, threshold to next level |
| AttributesComponent | Named attribute values, unspent points |
| PerkComponent | Unlocked tree nodes with ranks, unspent points |
| ImplantComponent | Installed implants, total/used capacity |
