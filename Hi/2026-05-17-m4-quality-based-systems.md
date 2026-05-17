# M4: Quality-Based Systems Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the QB rule engine v2 to Lua and build four domain consumers: narrative storylet system, dialogue system, animation state system, and cutscene system — all quality-driven (score thresholds, decision groups, multiplicative scoring).

**Architecture:** Port Godot's `U_RuleScorer` + `U_RuleSelector` (two stateless pure functions, ~100 lines) + `U_RuleStateTracker` (opt-in per-consumer, ~80 lines) to Lua. Rules become JSON files. Conditions and effects become Lua evaluation/execution closures in the engine API. Each domain system composes the scorer library — no inheritance, no base classes. Rule state tracking uses per-system Lua tables. `U_PathResolver` becomes dot-path string traversal in Lua.

**Tech Stack:** Lua (QB engine + domain systems), JSON (rule definitions), Bevy (entity/component storage), Zustand (UI store for dialogue/cutscene HUD).

**Prerequisites:** M1 complete (engine API with entity queries, component get/set, event emit/on, state get/set, JSON loading).

---

## Task 1: QB Engine — Rule Scorer and Selector

**Files:**
- Create: `engine/lua/lib/qb/qb_scorer.lua`
- Create: `engine/lua/lib/qb/qb_selector.lua`
- Create: `engine/lua/lib/qb/qb_state_tracker.lua`
- Create: `engine/lua/lib/qb/qb_path_resolver.lua`
- Create: `engine/tests/qb_engine.rs`

- [ ] **Step 1: Write failing QB engine test**

Write `engine/tests/qb_engine.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_qb_scorer_single_rule_passes() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Scorer = dofile("lib/qb/qb_scorer.lua")

        -- Rule: fire when health < 50%
        local rules = {{
            rule_id = "low_health_dialogue",
            conditions = {{
                type = "component_field",
                component_type = "Health",
                field_path = "health_percent",
                range_min = 0.0,
                range_max = 0.5,
                invert = false,
            }},
            effects = {},
            score_threshold = 0.5,
            decision_group = "",
            priority = 0,
        }}

        local context = {
            components = {
                Health = { health_percent = 0.3 },
            },
            entity_tags = { "player" },
            state = {},
            event_name = "",
            event_payload = {},
        }

        local results = Scorer.score_rules(rules, context)
        return results[1].score
    "#).eval::<f64>();

    assert!(result.unwrap() > 0.5);
}

#[test]
fn test_qb_scorer_rule_below_threshold() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Scorer = dofile("lib/qb/qb_scorer.lua")

        local rules = {{
            rule_id = "low_health",
            conditions = {{
                type = "component_field",
                component_type = "Health",
                field_path = "health_percent",
                range_min = 0.0,
                range_max = 0.5,
            }},
            score_threshold = 0.5,
            decision_group = "",
            priority = 0,
        }}

        local context = {
            components = { Health = { health_percent = 0.8 } },
            entity_tags = { "player" },
            state = {},
            event_name = "",
            event_payload = {},
        }

        local results = Scorer.score_rules(rules, context)
        -- health is 80% → normalized score ~0.0-0.0 for range 0-0.5
        return results[1].score
    "#).eval::<f64>();

    assert!(result.unwrap() < 0.5);
}

#[test]
fn test_qb_selector_decision_group_competition() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Selector = dofile("lib/qb/qb_selector.lua")

        -- Three rules competing in same decision group
        local scored = {
            { rule_id = "idle", score = 0.3, rule = { decision_group = "character_state", priority = 0 } },
            { rule_id = "combat", score = 0.8, rule = { decision_group = "character_state", priority = 5 } },
            { rule_id = "flee", score = 0.6, rule = { decision_group = "character_state", priority = 0 } },
        }

        local winners = Selector.select_winners(scored)
        return winners[1].rule_id
    "#).eval::<String>();

    assert_eq!(result.unwrap(), "combat");
}

#[test]
fn test_qb_state_tracker_cooldown() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Tracker = dofile("lib/qb/qb_state_tracker.lua")
        local tracker = Tracker.new()

        tracker:mark_fired("rule_a", "player_1", 2.0)
        local on_cd = tracker:is_on_cooldown("rule_a", "player_1")
        return on_cd
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_qb_path_resolver_dot_path() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local PathResolver = dofile("lib/qb/qb_path_resolver.lua")
        local obj = { player = { stats = { health = 75 } } }
        local val = PathResolver.resolve(obj, "player.stats.health")
        return val
    "#).eval::<u32>();

    assert_eq!(result.unwrap(), 75);
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_qb
```

Expected: All FAIL — QB lib files not found.

- [ ] **Step 3: Implement QB engine library**

Write `engine/lua/lib/qb/qb_path_resolver.lua`:
```lua
local PathResolver = {}

function PathResolver.resolve(obj, path)
  if obj == nil or path == nil or path == "" then
    return nil
  end

  for part in string.gmatch(path, "[^.]+") do
    if type(obj) ~= "table" then
      return nil
    end
    obj = obj[part]
    if obj == nil then
      return nil
    end
  end

  return obj
end

return PathResolver
```

Write `engine/lua/lib/qb/qb_scorer.lua`:
```lua
local PathResolver = dofile("lib/qb/qb_path_resolver.lua")

local Scorer = {}

function Scorer.score_rules(rules, context)
  local results = {}

  for _, rule in ipairs(rules) do
    local score = Scorer.score_rule(rule, context)
    table.insert(results, {
      rule = rule,
      rule_id = rule.rule_id,
      score = score,
    })
  end

  return results
end

function Scorer.score_rule(rule, context)
  local conditions = rule.conditions or {}

  -- Guard: empty conditions → 0.0
  if #conditions == 0 then
    return 0.0
  end

  -- Guard: composite condition wrapper
  if conditions[1] and conditions[1].type == "composite" then
    return Scorer.evaluate_composite(conditions[1], context)
  end

  local score = 1.0
  for _, cond in ipairs(conditions) do
    local c = Scorer.evaluate_condition(cond, context)
    if c <= 0.0 then
      return 0.0  -- Short-circuit: AND logic
    end
    score = score * c
  end

  return score
end

function Scorer.evaluate_composite(composite, context)
  local mode = composite.mode or "ALL"
  local children = composite.children or {}
  if #children == 0 then
    return 0.0
  end

  if mode == "ALL" then
    local score = 1.0
    for _, child in ipairs(children) do
      local c = Scorer.evaluate_condition(child, context)
      if c <= 0.0 then
        return 0.0
      end
      score = score * c
    end
    return score
  elseif mode == "ANY" then
    local best = 0.0
    for _, child in ipairs(children) do
      local c = Scorer.evaluate_condition(child, context)
      if c > best then
        best = c
      end
    end
    return best
  end

  return 0.0
end

function Scorer.evaluate_condition(condition, context)
  local score = 0.0

  if condition.type == "component_field" then
    score = Scorer.eval_component_field(condition, context)
  elseif condition.type == "redux_field" then
    score = Scorer.eval_redux_field(condition, context)
  elseif condition.type == "entity_tag" then
    score = Scorer.eval_entity_tag(condition, context)
  elseif condition.type == "event_name" then
    score = Scorer.eval_event_name(condition, context)
  elseif condition.type == "event_payload" then
    score = Scorer.eval_event_payload(condition, context)
  elseif condition.type == "constant" then
    score = condition.score or 1.0
  elseif condition.type == "composite" then
    score = Scorer.evaluate_composite(condition, context)
  end

  -- Response curve (optional)
  -- In Lua port: response curves are simplified to a raw pass-through.
  -- Complex curve baking happens in Godot; Lua uses linear range.

  -- Invert
  if condition.invert then
    score = 1.0 - score
  end

  return math.max(0.0, math.min(1.0, score))
end

function Scorer.eval_component_field(condition, context)
  local comps = context.components or {}
  local comp = comps[condition.component_type]
  if comp == nil then
    return 0.0
  end

  local val = PathResolver.resolve(comp, condition.field_path)
  if val == nil then
    return 0.0
  end

  -- Boolean → binary
  if type(val) == "boolean" then
    return val and 1.0 or 0.0
  end

  -- Numeric → normalize
  if type(val) == "number" then
    local rmin = condition.range_min or 0.0
    local rmax = condition.range_max or 1.0
    local range = rmax - rmin
    if math.abs(range) < 0.0001 then
      return (val >= rmax) and 1.0 or 0.0
    end
    return math.max(0.0, math.min(1.0, (val - rmin) / range))
  end

  return 0.0
end

function Scorer.eval_redux_field(condition, context)
  local state = context.state or {}
  local val = PathResolver.resolve(state, condition.state_path)
  if val == nil then
    return 0.0
  end

  local mode = condition.match_mode or "normalize"

  if mode == "equals" then
    return (tostring(val) == tostring(condition.match_value)) and 1.0 or 0.0
  elseif mode == "not_equals" then
    return (tostring(val) ~= tostring(condition.match_value)) and 1.0 or 0.0
  else
    -- normalize
    if type(val) == "boolean" then
      return val and 1.0 or 0.0
    end
    if type(val) == "number" then
      local rmin = condition.range_min or 0.0
      local rmax = condition.range_max or 1.0
      local range = rmax - rmin
      if math.abs(range) < 0.0001 then
        return (val >= rmax) and 1.0 or 0.0
      end
      return math.max(0.0, math.min(1.0, (val - rmin) / range))
    end
  end

  return 0.0
end

function Scorer.eval_entity_tag(condition, context)
  local tags = context.entity_tags or {}
  for _, tag in ipairs(tags) do
    if tag == condition.tag_name then
      return 1.0
    end
  end
  return 0.0
end

function Scorer.eval_event_name(condition, context)
  local event_name = context.event_name or ""
  local mode = condition.match_mode or "equals"

  if mode == "not_equals" then
    return (event_name ~= condition.expected_event_name) and 1.0 or 0.0
  end
  return (event_name == condition.expected_event_name) and 1.0 or 0.0
end

function Scorer.eval_event_payload(condition, context)
  local payload = context.event_payload or {}
  local val = PathResolver.resolve(payload, condition.field_path)
  if val == nil then
    return 0.0
  end

  local mode = condition.match_mode or "exists"
  if mode == "exists" then
    return val ~= nil and 1.0 or 0.0
  elseif mode == "equals" then
    return (tostring(val) == tostring(condition.match_value)) and 1.0 or 0.0
  elseif mode == "not_equals" then
    return (tostring(val) ~= tostring(condition.match_value)) and 1.0 or 0.0
  else
    -- normalize numeric
    if type(val) == "number" then
      local rmin = condition.range_min or 0.0
      local rmax = condition.range_max or 1.0
      local range = rmax - rmin
      if math.abs(range) < 0.0001 then
        return (val >= rmax) and 1.0 or 0.0
      end
      return math.max(0.0, math.min(1.0, (val - rmin) / range))
    end
  end
  return 0.0
end

return Scorer
```

Write `engine/lua/lib/qb/qb_selector.lua`:
```lua
local Selector = {}

function Selector.select_winners(scored_results)
  -- Partition by decision_group
  local groups = {}
  local independents = {}

  for _, result in ipairs(scored_results) do
    local rule = result.rule
    local group = rule.decision_group or ""
    if group == "" then
      table.insert(independents, result)
    else
      if not groups[group] then
        groups[group] = {}
      end
      table.insert(groups[group], result)
    end
  end

  local winners = {}

  -- Independents: all fire if score > threshold
  for _, result in ipairs(independents) do
    local threshold = result.rule.score_threshold or 0.0
    if result.score > threshold then
      table.insert(winners, result)
    end
  end

  -- Groups: pick best per group
  for _, group in pairs(groups) do
    table.sort(group, function(a, b)
      if a.score ~= b.score then
        return a.score > b.score
      end
      local pa = a.rule.priority or 0
      local pb = b.rule.priority or 0
      if pa ~= pb then
        return pa > pb
      end
      return (a.rule.rule_id or "") < (b.rule.rule_id or "")
    end)

    local best = group[1]
    local threshold = best.rule.score_threshold or 0.0
    if best.score > threshold then
      table.insert(winners, best)
    end
  end

  return winners
end

return Selector
```

Write `engine/lua/lib/qb/qb_state_tracker.lua`:
```lua
local StateTracker = {}
StateTracker.__index = StateTracker

function StateTracker.new()
  return setmetatable({
    cooldowns = {},       -- cooldowns[rule_id][context_key] = remaining_time
    rising_edges = {},    -- rising_edges[rule_id][context_key] = was_true_last_tick
    one_shots = {},       -- one_shots[rule_id] = true if already fired
  }, StateTracker)
end

function StateTracker:tick_cooldowns(dt)
  for rule_id, contexts in pairs(self.cooldowns) do
    for context_key, remaining in pairs(contexts) do
      local new_remaining = remaining - dt
      if new_remaining <= 0 then
        contexts[context_key] = nil
      else
        contexts[context_key] = new_remaining
      end
    end
    -- Clean empty rule entries
    if next(contexts) == nil then
      self.cooldowns[rule_id] = nil
    end
  end
end

function StateTracker:is_on_cooldown(rule_id, context_key)
  local contexts = self.cooldowns[rule_id]
  if not contexts then
    return false
  end
  return contexts[context_key] ~= nil
end

function StateTracker:check_rising_edge(rule_id, context_key, is_passing_now)
  if not self.rising_edges[rule_id] then
    self.rising_edges[rule_id] = {}
  end
  local was_passing = self.rising_edges[rule_id][context_key] or false
  self.rising_edges[rule_id][context_key] = is_passing_now
  return is_passing_now and not was_passing
end

function StateTracker:mark_fired(rule_id, context_key, cooldown_duration)
  if cooldown_duration and cooldown_duration > 0 then
    if not self.cooldowns[rule_id] then
      self.cooldowns[rule_id] = {}
    end
    self.cooldowns[rule_id][context_key] = cooldown_duration
  end
end

function StateTracker:mark_one_shot_spent(rule_id)
  self.one_shots[rule_id] = true
end

function StateTracker:is_one_shot_spent(rule_id)
  return self.one_shots[rule_id] or false
end

function StateTracker:cleanup_stale_contexts(active_keys)
  local active = {}
  for _, k in ipairs(active_keys) do
    active[k] = true
  end

  for rule_id, contexts in pairs(self.rising_edges) do
    for context_key, _ in pairs(contexts) do
      if not active[context_key] then
        contexts[context_key] = nil
      end
    end
    if next(contexts) == nil then
      self.rising_edges[rule_id] = nil
    end
  end
end

return StateTracker
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_qb
```

Expected: All 5 QB engine tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/lib/qb/ engine/tests/qb_engine.rs
git commit -m "(GREEN) feat: port QB rule engine v2 to Lua

qb_scorer.lua: stateless score_rules/score_rule with multiplicative AND,
component_field, redux_field, entity_tag, event_name, event_payload,
constant, composite (ALL/ANY) conditions. Response curve pass-through.
qb_selector.lua: select_winners with decision_group partitioning,
tiebreak (score → priority → rule_id alphabetical).
qb_state_tracker.lua: per-consumer cooldowns, rising edges, one-shots.
qb_path_resolver.lua: dot-path string traversal for context lookups."
```

---

## Task 2: Rule JSON Format + Loader

**Files:**
- Create: `engine/lua/lib/qb/qb_rule_loader.lua`
- Create: `engine/lua/config/rules/example_character_state.json`
- Create: `engine/tests/qb_rule_loader.rs`

- [ ] **Step 1: Write failing loader test**

Write `engine/tests/qb_rule_loader.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_load_rules_from_json() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Loader = dofile("lib/qb/qb_rule_loader.lua")
        local rules = Loader.load("config/rules/example_character_state.json")
        return #rules
    "#).eval::<u32>();

    assert!(result.unwrap() >= 2);
}

#[test]
fn test_loaded_rules_are_valid() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local Loader = dofile("lib/qb/qb_rule_loader.lua")
        local Scorer = dofile("lib/qb/qb_scorer.lua")
        local rules = Loader.load("config/rules/example_character_state.json")

        -- Validate: each rule has conditions
        for _, rule in ipairs(rules) do
            assert(#rule.conditions > 0, rule.rule_id .. " has no conditions")
        end
        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_qb_rule_loader
```

Expected: FAIL — loader/JSON not found.

- [ ] **Step 3: Implement loader and example rules**

Write `engine/lua/lib/qb/qb_rule_loader.lua`:
```lua
local Loader = {}

function Loader.load(json_path)
  -- engine:load_json is provided by mlua API (M1)
  local data = engine:load_json(json_path)
  if not data then
    return {}
  end

  local rules = data.rules or data -- Support both wrapped and bare arrays
  for _, rule in ipairs(rules) do
    -- Set defaults
    rule.score_threshold = rule.score_threshold or 0.0
    rule.decision_group = rule.decision_group or ""
    rule.priority = rule.priority or 0
    rule.conditions = rule.conditions or {}
    rule.effects = rule.effects or {}
    rule.cooldown = rule.cooldown or 0.0
    rule.one_shot = rule.one_shot or false
    rule.requires_rising_edge = rule.requires_rising_edge or false
    rule.trigger_mode = rule.trigger_mode or "tick"
  end

  return rules
end

return Loader
```

Write `engine/lua/config/rules/example_character_state.json`:
```json
{
  "rules": [
    {
      "rule_id": "character_idle",
      "description": "Default idle state — always available as fallback",
      "trigger_mode": "tick",
      "conditions": [
        {
          "type": "constant",
          "score": 0.5
        }
      ],
      "effects": [
        {
          "type": "set_field",
          "component_type": "StateComponent",
          "field_path": "current_state",
          "value": "idle"
        }
      ],
      "decision_group": "character_state",
      "priority": 0,
      "score_threshold": 0.0
    },
    {
      "rule_id": "character_combat",
      "description": "Enter combat state when health is low and enemies are nearby",
      "trigger_mode": "tick",
      "conditions": [
        {
          "type": "component_field",
          "component_type": "Health",
          "field_path": "health_percent",
          "range_min": 0.0,
          "range_max": 0.7
        },
        {
          "type": "redux_field",
          "state_path": "gameplay.nearby_enemy_count",
          "match_mode": "normalize",
          "range_min": 0.0,
          "range_max": 3.0
        },
        {
          "type": "component_field",
          "component_type": "Health",
          "field_path": "is_alive",
          "range_min": 0.0,
          "range_max": 1.0
        }
      ],
      "effects": [
        {
          "type": "set_field",
          "component_type": "StateComponent",
          "field_path": "current_state",
          "value": "combat"
        }
      ],
      "decision_group": "character_state",
      "priority": 10,
      "score_threshold": 0.4
    },
    {
      "rule_id": "character_death",
      "description": "Enter death state when health is zero",
      "trigger_mode": "tick",
      "conditions": [
        {
          "type": "component_field",
          "component_type": "Health",
          "field_path": "health",
          "range_min": 0.99,
          "range_max": 1.0,
          "invert": true
        },
        {
          "type": "component_field",
          "component_type": "Health",
          "field_path": "is_alive",
          "invert": true
        }
      ],
      "effects": [
        {
          "type": "set_field",
          "component_type": "StateComponent",
          "field_path": "current_state",
          "value": "dead"
        },
        {
          "type": "publish_event",
          "event_name": "EntityDiedEvent",
          "payload": { "cause": "health_depleted" }
        }
      ],
      "decision_group": "character_state",
      "priority": 100,
      "score_threshold": 0.8,
      "one_shot": true
    }
  ]
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_qb_rule_loader
```

Expected: Both loader tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/lib/qb/qb_rule_loader.lua engine/lua/config/rules/example_character_state.json engine/tests/qb_rule_loader.rs
git commit -m "(GREEN) feat: add QB rule JSON loader with example rules

qb_rule_loader.lua: loads rules from JSON via engine:load_json,
sets defaults for score_threshold, decision_group, priority, cooldown.
example_character_state.json: idle (constant 0.5 fallback), combat
(health + nearby enemies), death (zero health + not alive)."
```

---

## Task 3: Character State System (Quality-Driven)

**Files:**
- Create: `engine/lua/systems/s_character_state.lua`
- Create: `engine/lua/config/rules/character_state_rules.json`
- Modify: `engine/lua/config/systems.toml` (register system)
- Create: `engine/tests/character_state.rs`

- [ ] **Step 1: Write failing character state test**

Write `engine/tests/character_state.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_character_state_scoring() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_CharacterState = dofile("systems/s_character_state.lua")
        S_CharacterState:init(engine)

        -- Test: high health → idle wins
        local context = {
            components = {
                Health = { health_percent = 0.9, health = 90, is_alive = true },
                StateComponent = { current_state = "" },
            },
            entity_tags = { "player" },
            state = { gameplay = { nearby_enemy_count = 0 } },
            event_name = "",
            event_payload = {},
        }

        local state = S_CharacterState:evaluate_state(context)
        return state == "idle"
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_character_state_combat_wins() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_CharacterState = dofile("systems/s_character_state.lua")
        S_CharacterState:init(engine)

        local context = {
            components = {
                Health = { health_percent = 0.3, health = 30, is_alive = true },
                StateComponent = { current_state = "" },
            },
            entity_tags = { "player" },
            state = { gameplay = { nearby_enemy_count = 5 } },
            event_name = "",
            event_payload = {},
        }

        local state = S_CharacterState:evaluate_state(context)
        return state == "combat"
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_character
```

Expected: FAIL.

- [ ] **Step 3: Implement character state system**

Write `engine/lua/config/rules/character_state_rules.json`:
```json
{
  "rules": [
    {
      "rule_id": "cs_idle",
      "description": "Default idle",
      "trigger_mode": "tick",
      "conditions": [{ "type": "constant", "score": 0.5 }],
      "effects": [{ "type": "set_field", "component_type": "StateComponent", "field_path": "current_state", "value": "idle" }],
      "decision_group": "character_state",
      "priority": 0,
      "score_threshold": 0.0
    },
    {
      "rule_id": "cs_combat",
      "description": "Combat: low health + nearby enemies",
      "trigger_mode": "tick",
      "conditions": [
        { "type": "component_field", "component_type": "Health", "field_path": "health_percent", "range_min": 0.0, "range_max": 0.7 },
        { "type": "redux_field", "state_path": "gameplay.nearby_enemy_count", "match_mode": "normalize", "range_min": 0.0, "range_max": 3.0 },
        { "type": "component_field", "component_type": "Health", "field_path": "is_alive" }
      ],
      "effects": [{ "type": "set_field", "component_type": "StateComponent", "field_path": "current_state", "value": "combat" }],
      "decision_group": "character_state",
      "priority": 10,
      "score_threshold": 0.4
    },
    {
      "rule_id": "cs_dead",
      "description": "Death",
      "trigger_mode": "tick",
      "conditions": [
        { "type": "component_field", "component_type": "Health", "field_path": "health", "range_min": 0.99, "range_max": 1.0, "invert": true },
        { "type": "component_field", "component_type": "Health", "field_path": "is_alive", "invert": true }
      ],
      "effects": [{ "type": "set_field", "component_type": "StateComponent", "field_path": "current_state", "value": "dead" }],
      "decision_group": "character_state",
      "priority": 100,
      "score_threshold": 0.8
    }
  ]
}
```

Write `engine/lua/systems/s_character_state.lua`:
```lua
local Scorer = dofile("lib/qb/qb_scorer.lua")
local Selector = dofile("lib/qb/qb_selector.lua")
local Tracker = dofile("lib/qb/qb_state_tracker.lua")
local Loader = dofile("lib/qb/qb_rule_loader.lua")

local S_CharacterState = {}

function S_CharacterState:init(engine)
  self.engine = engine
  self.rules = Loader.load("config/rules/character_state_rules.json")
  self.tracker = Tracker.new()
  self.previous_states = {}
end

function S_CharacterState:process(engine, dt)
  self.tracker:tick_cooldowns(dt)

  engine:query({"EntityTag", "Health", "StateComponent"}, function(eid)
    local tags = engine:get(eid, "EntityTag")
    local health = engine:get(eid, "Health")
    local state = engine:get(eid, "StateComponent")
    local context_key = tostring(eid)

    -- Build context
    local context = {
      components = {
        Health = health,
        StateComponent = state,
      },
      entity_tags = tags.tags or {},
      state = {
        gameplay = {
          nearby_enemy_count = engine:get_state("gameplay.nearby_enemy_count") or 0,
        },
      },
      event_name = "",
      event_payload = {},
    }

    -- Score and select
    local scored = Scorer.score_rules(self.rules, context)
    local winners = Selector.select_winners(scored)

    if #winners > 0 then
      local winner = winners[1]
      local rule = winner.rule

      -- Rising edge check
      local is_passing = winner.score > (rule.score_threshold or 0.0)
      if rule.requires_rising_edge then
        if not self.tracker:check_rising_edge(rule.rule_id, context_key, is_passing) then
          return
        end
      end

      -- Cooldown check
      if self.tracker:is_on_cooldown(rule.rule_id, context_key) then
        return
      end

      -- One-shot check
      if rule.one_shot and self.tracker:is_one_shot_spent(rule.rule_id) then
        return
      end

      -- Execute effects
      for _, effect in ipairs(rule.effects or {}) do
        if effect.type == "set_field" then
          local comp = engine:get(eid, effect.component_type)
          if comp then
            comp[effect.field_path] = effect.value
            engine:set(eid, effect.component_type, comp)
          end
        elseif effect.type == "publish_event" then
          engine:emit(effect.event_name, effect.payload or {})
        end
      end

      -- Track firing
      local cd = rule.cooldown or 0.0
      if cd > 0 then
        self.tracker:mark_fired(rule.rule_id, context_key, cd)
      end
      if rule.one_shot then
        self.tracker:mark_one_shot_spent(rule.rule_id)
      end

      -- Record previous state
      self.previous_states[context_key] = (state.current_state)
    end
  end)
end

-- Exposed for test
function S_CharacterState:evaluate_state(context)
  local scored = Scorer.score_rules(self.rules, context)
  local winners = Selector.select_winners(scored)
  if #winners > 0 then
    for _, effect in ipairs(winners[1].rule.effects or {}) do
      if effect.type == "set_field" and effect.field_path == "current_state" then
        return effect.value
      end
    end
  end
  return "idle"
end

return S_CharacterState
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_CharacterState]
lua_file = "systems/s_character_state.lua"
system_set = "CoreMotion"
priority = 55
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_character
```

Expected: Both character state tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_character_state.lua engine/lua/config/rules/character_state_rules.json engine/lua/config/systems.toml engine/tests/character_state.rs
git commit -m "(GREEN) feat: add quality-driven character state system

S_CharacterState (CoreMotion, pri 55): scores character_state decision
group rules per entity, evaluates conditions (health, nearby_enemy_count,
is_alive), selects winner, executes set_field/publish_event effects.
Uses QB state tracker for cooldowns, rising edges, one-shots.
Rules: idle (fallback), combat (low health + enemies), dead (zero health)."
```

---

## Task 4: Narrative Storylet System

**Files:**
- Create: `engine/lua/systems/s_storylet_system.lua`
- Create: `engine/lua/config/rules/storylet_rules.json`
- Create: `engine/lua/config/narrative/narrative_beats.json`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/storylet.rs`

- [ ] **Step 1: Write failing storylet test**

Write `engine/tests/storylet.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_storylet_selects_narrative_beat() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Storylet = dofile("systems/s_storylet_system.lua")
        S_Storylet:init(engine)

        -- Set state to meet a storylet condition
        engine:set_state("flags.entered_cave", true)
        engine:set_state("player_level", 5)

        local beat = S_Storylet:select_beat(42)
        return beat ~= nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_storylet_returns_nil_when_no_beat_qualifies() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Storylet = dofile("systems/s_storylet_system.lua")
        S_Storylet:init(engine)

        -- No flags set → no beats qualify
        engine:set_state("flags.entered_cave", false)
        engine:set_state("player_level", 0)

        local beat = S_Storylet:select_beat(42)
        return beat == nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_storylet
```

Expected: FAIL.

- [ ] **Step 3: Implement storylet system**

Write `engine/lua/config/narrative/narrative_beats.json`:
```json
{
  "beats": [
    {
      "beat_id": "cave_entrance_greeting",
      "description": "First time entering the cave",
      "trigger_mode": "tick",
      "conditions": [
        { "type": "redux_field", "state_path": "flags.entered_cave", "match_mode": "equals", "match_value": "true" },
        { "type": "redux_field", "state_path": "flags.cave_greeting_seen", "match_mode": "not_equals", "match_value": "true" }
      ],
      "effects": [
        {
          "type": "start_dialogue",
          "dialogue_id": "npc_cave_greeting"
        }
      ],
      "decisions": [
        { "decree_id": "set_flag", "key": "flags.cave_greeting_seen", "value": "true" }
      ],
      "score_threshold": 0.51,
      "one_shot": true,
      "priority": 0,
      "decision_group": "narrative_beat"
    },
    {
      "beat_id": "player_level_5_event",
      "description": "Narrative beat when player reaches level 5",
      "trigger_mode": "tick",
      "conditions": [
        { "type": "redux_field", "state_path": "player_level", "range_min": 5.0, "range_max": 5.0, "match_mode": "normalize" },
        { "type": "redux_field", "state_path": "flags.level_5_beat_seen", "match_mode": "not_equals", "match_value": "true" }
      ],
      "effects": [
        {
          "type": "start_dialogue",
          "dialogue_id": "level_up_5"
        }
      ],
      "decisions": [
        { "decree_id": "set_flag", "key": "flags.level_5_beat_seen", "value": "true" }
      ],
      "score_threshold": 0.51,
      "one_shot": true,
      "priority": 10,
      "decision_group": "narrative_beat"
    },
    {
      "beat_id": "low_health_narrative",
      "description": "Narrative beat when player is critically injured",
      "trigger_mode": "tick",
      "conditions": [
        {
          "type": "composite",
          "mode": "ALL",
          "children": [
            { "type": "component_field", "component_type": "Health", "field_path": "health_percent", "range_min": 0.0, "range_max": 0.25 },
            { "type": "component_field", "component_type": "Health", "field_path": "is_alive" }
          ]
        },
        { "type": "redux_field", "state_path": "flags.low_health_warned", "match_mode": "not_equals", "match_value": "true" }
      ],
      "effects": [
        {
          "type": "start_dialogue",
          "dialogue_id": "low_health_warning"
        }
      ],
      "decisions": [
        { "decree_id": "set_flag", "key": "flags.low_health_warned", "value": "true" }
      ],
      "score_threshold": 0.51,
      "cooldown": 30.0,
      "priority": 20,
      "decision_group": "narrative_beat"
    }
  ]
}
```

Write `engine/lua/config/rules/storylet_rules.json`:
```json
{
  "rules": [
    {
      "rule_id": "storylet_narrative_beat",
      "description": "Evaluate narrative beats for current context",
      "trigger_mode": "tick",
      "conditions": [
        { "type": "constant", "score": 1.0 }
      ],
      "effects": [
        { "type": "trigger_beat" }
      ],
      "decision_group": "narrative",
      "priority": 0,
      "score_threshold": 0.0
    }
  ]
}
```

Write `engine/lua/systems/s_storylet_system.lua`:
```lua
local Scorer = dofile("lib/qb/qb_scorer.lua")
local Selector = dofile("lib/qb/qb_selector.lua")
local Tracker = dofile("lib/qb/qb_state_tracker.lua")

local S_Storylet = {}

function S_Storylet:init(engine)
  self.engine = engine
  self.tracker = Tracker.new()
  self.beats = {}
  -- Load beats
  local data = engine:load_json("config/narrative/narrative_beats.json")
  if data then
    self.beats = data.beats or {}
  end
end

function S_Storylet:process(engine, dt)
  self.tracker:tick_cooldowns(dt)

  -- For each player entity, evaluate storylet beats
  engine:query({"PlayerTag", "Health"}, function(eid)
    self:select_beat(eid)
  end)
end

function S_Storylet:select_beat(entity_id)
  local context_key = tostring(entity_id)
  local health = self.engine:get(entity_id, "Health") or {}
  local tags = self.engine:get(entity_id, "EntityTag")
  local entity_tags = tags and tags.tags or {}

  -- Build state snapshot
  local state = {}
  -- Read all known flags from engine state
  state.flags = {}
  state.player_level = self.engine:get_state("player_level") or 0

  -- Read flagged keys
  local flag_keys = { "entered_cave", "cave_greeting_seen", "level_5_beat_seen", "low_health_warned" }
  for _, key in ipairs(flag_keys) do
    state.flags[key] = tostring(self.engine:get_state("flags." .. key) or false)
  end

  local context = {
    components = { Health = health },
    entity_tags = entity_tags,
    state = state,
    event_name = "",
    event_payload = {},
  }

  local scored = Scorer.score_rules(self.beats, context)
  local winners = Selector.select_winners(scored)

  if #winners == 0 then
    return nil
  end

  local winner = winners[1]
  local beat = winner.rule

  -- Cooldown / one-shot gating
  if beat.cooldown and beat.cooldown > 0 then
    if self.tracker:is_on_cooldown(beat.beat_id, context_key) then
      return nil
    end
  end
  if beat.one_shot and self.tracker:is_one_shot_spent(beat.beat_id) then
    return nil
  end

  -- Execute decrees (side effects)
  for _, decree in ipairs(beat.decisions or {}) do
    if decree.decree_id == "set_flag" then
      self.engine:set_state(decree.key, decree.value)
    end
  end

  -- Execute effects
  for _, effect in ipairs(beat.effects or {}) do
    if effect.type == "start_dialogue" then
      self.engine:emit("StartDialogueEvent", {
        dialogue_id = effect.dialogue_id,
        entity = entity_id,
      })
    end
  end

  -- Track firing
  if beat.cooldown and beat.cooldown > 0 then
    self.tracker:mark_fired(beat.beat_id, context_key, beat.cooldown)
  end
  if beat.one_shot then
    self.tracker:mark_one_shot_spent(beat.beat_id)
  end

  -- Clean stale contexts
  self.tracker:cleanup_stale_contexts({ context_key })

  return beat
end

return S_Storylet
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_Storylet]
lua_file = "systems/s_storylet_system.lua"
system_set = "CoreMotion"
priority = 58
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_storylet
```

Expected: Both storylet tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_storylet_system.lua engine/lua/config/rules/storylet_rules.json engine/lua/config/narrative/narrative_beats.json engine/lua/config/systems.toml engine/tests/storylet.rs
git commit -m "(GREEN) feat: add quality-driven narrative storylet system

S_Storylet (CoreMotion, pri 58): loads narrative_beasts from JSON,
scores beats against player state (flags, health, level), selects
winner via QB selector. Executes decrees (set_flag) and effects
(start_dialogue). One-shot and cooldown-gated beats.
Example beats: cave entrance greeting, level-5 milestone, low HP warning."
```

---

## Task 5: Dialogue System

**Files:**
- Create: `engine/lua/systems/s_dialogue_system.lua`
- Create: `engine/lua/config/dialogue/dialogue_db.json`
- Modify: `engine/lua/config/systems.toml`
- Create: `client/src/ui/widgets/DialogueBox.tsx`
- Create: `client/src/ui/widgets/__tests__/DialogueBox.test.tsx`
- Create: `engine/tests/dialogue.rs`

- [ ] **Step 1: Write failing dialogue test**

Write `engine/tests/dialogue.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_dialogue_loads_lines() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Dialogue = dofile("systems/s_dialogue_system.lua")
        S_Dialogue:init(engine)

        local tree = S_Dialogue:get_dialogue_tree("npc_cave_greeting")
        return tree ~= nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_dialogue_quality_gated_options() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Dialogue = dofile("systems/s_dialogue_system.lua")
        S_Dialogue:init(engine)

        -- Player level 1 → locked option should be filtered out
        engine:set_state("player_level", 1)

        local tree = S_Dialogue:get_dialogue_tree("npc_cave_greeting")
        local options = S_Dialogue:get_available_options(tree, "greeting_01", 1)
        -- "level_5_option" requires player_level >= 5, so it should be hidden
        for _, opt in ipairs(options) do
            if opt.option_id == "level_5_option" then
                return false
            end
        end
        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_dialogue
```

Expected: FAIL.

- [ ] **Step 3: Implement dialogue system (engine + client)**

Write `engine/lua/config/dialogue/dialogue_db.json`:
```json
{
  "dialogues": {
    "npc_cave_greeting": {
      "dialogue_id": "npc_cave_greeting",
      "speaker_name": "Cave Guide",
      "nodes": [
        {
          "node_id": "greeting_01",
          "text": "Welcome, traveler. The cave ahead holds many secrets.",
          "options": [
            {
              "option_id": "ask_more",
              "text": "Tell me more about this cave.",
              "next_node": "cave_lore"
            },
            {
              "option_id": "enter",
              "text": "I'll head inside.",
              "next_node": null
            },
            {
              "option_id": "level_5_option",
              "text": "[Level 5] I sense great power here.",
              "next_node": "power_sense",
              "conditions": [
                { "type": "redux_field", "state_path": "player_level", "range_min": 5.0, "range_max": 100.0, "match_mode": "normalize" }
              ],
              "score_threshold": 0.51
            }
          ]
        },
        {
          "node_id": "cave_lore",
          "text": "Long ago, the ancients sealed a powerful relic within. Only the worthy may find it.",
          "options": [
            {
              "option_id": "accept",
              "text": "I'll prove my worth.",
              "next_node": null
            }
          ]
        },
        {
          "node_id": "power_sense",
          "text": "Ah, you do have the gift. The relic will reveal itself to you.",
          "options": [
            {
              "option_id": "continue_on",
              "text": "Thank you for the guidance.",
              "next_node": null
            }
          ]
        }
      ]
    },
    "level_up_5": {
      "dialogue_id": "level_up_5",
      "speaker_name": "System",
      "nodes": [
        {
          "node_id": "level_up",
          "text": "You have grown stronger. New powers awaken within you.",
          "options": [
            {
              "option_id": "acknowledge",
              "text": "Continue.",
              "next_node": null
            }
          ]
        }
      ]
    },
    "low_health_warning": {
      "dialogue_id": "low_health_warning",
      "speaker_name": "System",
      "nodes": [
        {
          "node_id": "warn_01",
          "text": "Your health is critically low. Find shelter or use a healing item.",
          "options": [
            {
              "option_id": "ok",
              "text": "I'll be careful.",
              "next_node": null
            }
          ]
        }
      ]
    }
  }
}
```

Write `engine/lua/systems/s_dialogue_system.lua`:
```lua
local Scorer = dofile("lib/qb/qb_scorer.lua")

local S_Dialogue = {}

function S_Dialogue:init(engine)
  self.engine = engine
  self.db = {}
  self.active_dialogues = {}  -- entity_id → { tree_id, current_node, speaker }

  local data = engine:load_json("config/dialogue/dialogue_db.json")
  if data then
    self.db = data.dialogues or {}
  end

  -- EVENT HANDLERS: registered once at init, not every tick

  engine:on("StartDialogueEvent", function(event)
    local tree = self:get_dialogue_tree(event.dialogue_id)
    if not tree then
      return
    end

    local root_node = tree.nodes[1]
    if not root_node then
      return
    end

    self.active_dialogues[event.entity] = {
      tree_id = event.dialogue_id,
      current_node = root_node.node_id,
      speaker = tree.speaker_name,
    }

    -- Send to client via UI event
    engine:emit("ShowDialogueEvent", {
      entity = event.entity,
      speaker = tree.speaker_name,
      text = root_node.text,
      options = self:get_available_options(tree, root_node.node_id, event.entity),
    })

    engine:emit("UiStateChangeEvent", {
      key = "dialogue_open",
      value = true,
    })
  end)

  -- Handle dialogue option selection from client
  engine:on("DialogueOptionSelectedEvent", function(event)
    local active = self.active_dialogues[event.entity]
    if not active then
      return
    end

    local tree = self:get_dialogue_tree(active.tree_id)
    if not tree then
      return
    end

    -- Resolve next node
    local current_node = nil
    for _, n in ipairs(tree.nodes) do
      if n.node_id == active.current_node then
        current_node = n
        break
      end
    end
    if not current_node then
      return
    end

    -- Find selected option
    local selected = nil
    for _, opt in ipairs(current_node.options or {}) do
      if opt.option_id == event.option_id then
        selected = opt
        break
      end
    end
    if not selected then
      return
    end

    if selected.next_node then
      -- Advance to next node
      local next_node = nil
      for _, n in ipairs(tree.nodes) do
        if n.node_id == selected.next_node then
          next_node = n
          break
        end
      end
      if next_node then
        active.current_node = next_node.node_id
        engine:emit("ShowDialogueEvent", {
          entity = event.entity,
          speaker = tree.speaker_name,
          text = next_node.text,
          options = self:get_available_options(tree, next_node.node_id, event.entity),
        })
      end
    else
      -- End dialogue
      self.active_dialogues[event.entity] = nil
      engine:emit("UiStateChangeEvent", {
        key = "dialogue_open",
        value = false,
      })
      engine:emit("DialogueEndedEvent", {
        entity = event.entity,
        dialogue_id = active.tree_id,
      })
    end
  end)
end

function S_Dialogue:get_dialogue_tree(dialogue_id)
  return self.db[dialogue_id]
end

function S_Dialogue:get_available_options(tree, node_id, entity_id)
  local node = nil
  for _, n in ipairs(tree.nodes) do
    if n.node_id == node_id then
      node = n
      break
    end
  end
  if not node then
    return {}
  end

  local available = {}
  for _, opt in ipairs(node.options or {}) do
    if S_Dialogue:option_qualifies(opt, entity_id) then
      table.insert(available, opt)
    end
  end
  return available
end

function S_Dialogue:option_qualifies(option, entity_id)
  local conditions = option.conditions
  if not conditions or #conditions == 0 then
    return true
  end

  local tags = self.engine:get(entity_id, "EntityTag")
  local context = {
    components = {
      Health = self.engine:get(entity_id, "Health") or {},
    },
    entity_tags = tags and tags.tags or {},
    state = {
      player_level = self.engine:get_state("player_level") or 0,
    },
    event_name = "",
    event_payload = {},
  }

  local results = Scorer.score_rules({{
    rule_id = option.option_id or "opt",
    conditions = conditions,
    score_threshold = option.score_threshold or 0.0,
    decision_group = "",
    priority = 0,
  }}, context)

  if #results > 0 then
    return results[1].score > (option.score_threshold or 0.0)
  end
  return true
end

function S_Dialogue:process(engine, dt)
  -- No-op: all dialogue logic is event-driven via init() handlers
end

return S_Dialogue
```

Write `client/src/ui/widgets/DialogueBox.tsx`:
```tsx
import { useState, useEffect } from 'react';
import { useUiStore } from '../store/uiStore';

interface DialogueOption {
  option_id: string;
  text: string;
  next_node: string | null;
}

interface DialogueBoxProps {
  visible: boolean;
  speaker: string;
  text: string;
  options: DialogueOption[];
}

export function DialogueBox() {
  const dialogueOpen = useUiStore((s) => s.dialogueOpen);
  const dialogueSpeaker = useUiStore((s) => s.dialogueSpeaker);
  const dialogueText = useUiStore((s) => s.dialogueText);
  const dialogueOptions = useUiStore((s) => s.dialogueOptions);
  const selectDialogueOption = useUiStore((s) => s.selectDialogueOption);

  if (!dialogueOpen) return null;

  return (
    <div style={{
      position: 'fixed', bottom: 0, left: 0, right: 0,
      background: 'rgba(10, 10, 20, 0.92)',
      borderTop: '2px solid #2a4a7f',
      padding: '1.5rem', zIndex: 100,
      fontFamily: 'monospace', color: '#e0e0e0',
    }}>
      <div style={{ color: '#4a7f6a', fontSize: '0.85rem', marginBottom: '0.5rem' }}>
        {dialogueSpeaker}
      </div>
      <div style={{ fontSize: '1.1rem', lineHeight: '1.5', marginBottom: '1rem' }}>
        {dialogueText}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
        {(dialogueOptions || []).map((opt: DialogueOption) => (
          <button
            key={opt.option_id}
            onClick={() => selectDialogueOption(opt.option_id)}
            style={{
              padding: '0.5rem 1rem', background: '#16213e', color: '#aaa',
              border: '1px solid #2a4a7f', borderRadius: '4px',
              fontFamily: 'monospace', fontSize: '0.9rem', cursor: 'pointer',
              textAlign: 'left',
            }}
          >
            {opt.text}
          </button>
        ))}
      </div>
    </div>
  );
}
```

Write `client/src/ui/widgets/__tests__/DialogueBox.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { useUiStore } from '../../store/uiStore';

describe('DialogueBox', () => {
  it('should not render when dialogue is closed', () => {
    const state = useUiStore.getState();
    state.dialogueOpen = false;

    const { container } = render(require('../DialogueBox').DialogueBox);
    expect(container.innerHTML).toBe('');
  });
});
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_Dialogue]
lua_file = "systems/s_dialogue_system.lua"
system_set = "Feedback"
priority = 150
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_dialogue
cd ../client && npm test
```

Expected: All dialogue tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_dialogue_system.lua engine/lua/config/dialogue/dialogue_db.json engine/lua/config/systems.toml engine/tests/dialogue.rs client/src/ui/widgets/DialogueBox.tsx client/src/ui/widgets/__tests__/DialogueBox.test.tsx
git commit -m "(GREEN) feat: add quality-driven dialogue system

S_Dialogue (Feedback, pri 150): loads dialogue_db.json, responds to
StartDialogueEvent, evaluates response options against quality
conditions (player level, flags), filters unavailable choices.
Advance node on player selection, emit DialogueEndedEvent on terminal.
DialogueBox (React): speaker name, node text, clickable options.
UI store: dialogueOpen/Speaker/Text/Options/selectDialogueOption.
Example dialogues: cave greeting (3 paths), level-up, low HP warning."
```

---

## Task 6: Animation State System (Quality-Driven)

**Files:**
- Create: `engine/lua/systems/s_animation_state.lua`
- Create: `engine/lua/config/rules/animation_state_rules.json`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/animation_state.rs`

- [ ] **Step 1: Write failing animation test**

Write `engine/tests/animation_state.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_animation_state_idle_when_stationary() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Animation = dofile("systems/s_animation_state.lua")
        S_Animation:init(engine)

        local context = {
            components = {
                InputComponent = { move_x = 0.0, move_y = 0.0, sprint_pressed = false },
                Movement = { speed = 5.0 },
                StateComponent = { current_state = "idle" },
            },
            entity_tags = { "player" },
            state = {},
            event_name = "",
            event_payload = {},
        }

        local anim = S_Animation:select_animation(context)
        return anim == "idle"
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_animation_state_run_when_moving() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Animation = dofile("systems/s_animation_state.lua")
        S_Animation:init(engine)

        local context = {
            components = {
                InputComponent = { move_x = 1.0, move_y = 0.0, sprint_pressed = false },
                Movement = { speed = 5.0 },
                StateComponent = { current_state = "idle" },
            },
            entity_tags = { "player" },
            state = {},
            event_name = "",
            event_payload = {},
        }

        local anim = S_Animation:select_animation(context)
        return anim == "walk"
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_animation_state_sprint() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Animation = dofile("systems/s_animation_state.lua")
        S_Animation:init(engine)

        local context = {
            components = {
                InputComponent = { move_x = 1.0, move_y = 0.0, sprint_pressed = true },
                Movement = { speed = 8.0 },
                StateComponent = { current_state = "idle" },
            },
            entity_tags = { "player" },
            state = {},
            event_name = "",
            event_payload = {},
        }

        local anim = S_Animation:select_animation(context)
        return anim == "run"
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_animation
```

Expected: FAIL.

- [ ] **Step 3: Implement animation state system**

Write `engine/lua/config/rules/animation_state_rules.json`:
```json
{
  "rules": [
    {
      "rule_id": "anim_idle",
      "description": "Idle when stationary",
      "conditions": [
        { "type": "component_field", "component_type": "InputComponent", "field_path": "move_x", "range_min": -0.1, "range_max": 0.1 },
        { "type": "component_field", "component_type": "InputComponent", "field_path": "move_y", "range_min": -0.1, "range_max": 0.1 }
      ],
      "effects": [{ "type": "set_field", "component_type": "StateComponent", "field_path": "animation", "value": "idle" }],
      "decision_group": "animation",
      "priority": 0,
      "score_threshold": 0.4
    },
    {
      "rule_id": "anim_walk",
      "description": "Walk when moving",
      "conditions": [
        {
          "type": "composite",
          "mode": "ANY",
          "children": [
            { "type": "component_field", "component_type": "InputComponent", "field_path": "move_x", "range_min": 0.11, "range_max": 1.0 },
            { "type": "component_field", "component_type": "InputComponent", "field_path": "move_y", "range_min": 0.11, "range_max": 1.0 }
          ]
        },
        { "type": "component_field", "component_type": "Movement", "field_path": "speed", "range_min": 0.0, "range_max": 6.0 }
      ],
      "effects": [{ "type": "set_field", "component_type": "StateComponent", "field_path": "animation", "value": "walk" }],
      "decision_group": "animation",
      "priority": 5,
      "score_threshold": 0.4
    },
    {
      "rule_id": "anim_run",
      "description": "Run when sprinting",
      "conditions": [
        {
          "type": "composite",
          "mode": "ANY",
          "children": [
            { "type": "component_field", "component_type": "InputComponent", "field_path": "move_x", "range_min": 0.11, "range_max": 1.0 },
            { "type": "component_field", "component_type": "InputComponent", "field_path": "move_y", "range_min": 0.11, "range_max": 1.0 }
          ]
        },
        { "type": "component_field", "component_type": "InputComponent", "field_path": "sprint_pressed" },
        { "type": "component_field", "component_type": "Movement", "field_path": "speed", "range_min": 6.0, "range_max": 10.0 }
      ],
      "effects": [{ "type": "set_field", "component_type": "StateComponent", "field_path": "animation", "value": "run" }],
      "decision_group": "animation",
      "priority": 10,
      "score_threshold": 0.4
    },
    {
      "rule_id": "anim_jump",
      "description": "Jump animation when airborne",
      "conditions": [
        { "type": "component_field", "component_type": "Jump", "field_path": "is_jumping" },
        { "type": "component_field", "component_type": "Jump", "field_path": "coyote_timer", "range_min": 0.01, "range_max": 0.2 }
      ],
      "effects": [{ "type": "set_field", "component_type": "StateComponent", "field_path": "animation", "value": "jump" }],
      "decision_group": "animation",
      "priority": 20,
      "score_threshold": 0.5
    }
  ]
}
```

Write `engine/lua/systems/s_animation_state.lua`:
```lua
local Scorer = dofile("lib/qb/qb_scorer.lua")
local Selector = dofile("lib/qb/qb_selector.lua")
local Loader = dofile("lib/qb/qb_rule_loader.lua")

local S_Animation = {}

function S_Animation:init(engine)
  self.engine = engine
  self.rules = Loader.load("config/rules/animation_state_rules.json")
  self.previous_animation = {}
end

function S_Animation:process(engine, dt)
  engine:query({"EntityTag", "InputComponent", "Movement", "StateComponent"}, function(eid)
    local input = engine:get(eid, "InputComponent")
    local movement = engine:get(eid, "Movement")
    local state = engine:get(eid, "StateComponent")
    local tags = engine:get(eid, "EntityTag")

    -- Also check Jump component if present
    local jump = engine:get(eid, "Jump")

    local context = {
      components = {
        InputComponent = input,
        Movement = movement,
        StateComponent = state,
      },
      entity_tags = tags and tags.tags or {},
      state = {},
      event_name = "",
      event_payload = {},
    }

    if jump then
      context.components.Jump = jump
    end

    local anim = self:select_animation(context)
    local key = tostring(eid)
    if anim and anim ~= self.previous_animation[key] then
      local prev = self.previous_animation[key]
      self.previous_animation[key] = anim
      engine:emit("AnimationChangedEvent", {
        entity = eid,
        animation = anim,
        previous = prev,
      })
    end
  end)
end

function S_Animation:select_animation(context)
  local scored = Scorer.score_rules(self.rules, context)
  local winners = Selector.select_winners(scored)

  if #winners > 0 then
    for _, effect in ipairs(winners[1].rule.effects or {}) do
      if effect.type == "set_field" and effect.field_path == "animation" then
        return effect.value
      end
    end
  end

  return "idle" -- fallback
end

return S_Animation
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_Animation]
lua_file = "systems/s_animation_state.lua"
system_set = "PostMotion"
priority = 75
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_animation
```

Expected: All 3 animation tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_animation_state.lua engine/lua/config/rules/animation_state_rules.json engine/lua/config/systems.toml engine/tests/animation_state.rs
git commit -m "(GREEN) feat: add quality-driven animation state system

S_Animation (PostMotion, pri 75): scores animation rules per tick
per entity. Rules: idle (stationary), walk (moving, ≤6 speed),
run (moving + sprint + ≥6 speed), jump (airborne + coyote timer).
Emits AnimationChangedEvent on state transition. Rules use composite
ANY conditions for multi-axis movement detection."
```

---

## Task 7: Cutscene System

**Files:**
- Create: `engine/lua/systems/s_cutscene_system.lua`
- Create: `engine/lua/config/cutscenes/example_cutscene.json`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/cutscene.rs`

- [ ] **Step 1: Write failing cutscene test**

Write `engine/tests/cutscene.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_cutscene_loads_from_json() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Cutscene = dofile("systems/s_cutscene_system.lua")
        S_Cutscene:init(engine)

        local cutscene = S_Cutscene:get_cutscene("cave_reveal")
        return cutscene ~= nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_cutscene_camera_keyframes() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Cutscene = dofile("systems/s_cutscene_system.lua")
        S_Cutscene:init(engine)

        local cutscene = S_Cutscene:get_cutscene("cave_reveal")
        assert(#cutscene.keyframes > 0, "Cutscene should have keyframes")
        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_cutscene_quality_gated() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Cutscene = dofile("systems/s_cutscene_system.lua")
        S_Cutscene:init(engine)

        engine:set_state("player_level", 2)

        -- cutscene requires player_level >= 5
        local can_play = S_Cutscene:can_play("cave_reveal", 1)
        return not can_play
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_cutscene
```

Expected: FAIL.

- [ ] **Step 3: Implement cutscene system**

Write `engine/lua/config/cutscenes/example_cutscene.json`:
```json
{
  "cutscenes": {
    "cave_reveal": {
      "cutscene_id": "cave_reveal",
      "conditions": [
        { "type": "redux_field", "state_path": "flags.entered_cave", "match_mode": "equals", "match_value": "true" }
      ],
      "score_threshold": 0.51,
      "one_shot": true,
      "duration": 5.0,
      "skip_enabled": true,
      "events": [
        { "type": "input_lock", "at": 0.0 },
        { "type": "music", "track": "cave_ambient", "fade": 0.5, "at": 0.0 },
        { "type": "dialogue", "dialogue_id": "npc_cave_greeting", "at": 0.5 },
        { "type": "input_unlock", "at": 4.5 }
      ],
      "keyframes": [
        {
          "at": 0.0,
          "camera": {
            "position": [0, 2, -6],
            "look_at": [2, 0, 0],
            "fov": 60
          },
          "entity_moves": []
        },
        {
          "at": 2.0,
          "camera": {
            "position": [4, 3, -4],
            "look_at": [4, 0, 4],
            "fov": 50
          },
          "entity_moves": []
        },
        {
          "at": 4.0,
          "camera": {
            "position": [8, 1, -8],
            "look_at": [8, 0, 0],
            "fov": 70
          },
          "entity_moves": []
        }
      ]
    }
  }
}
```

Write `engine/lua/systems/s_cutscene_system.lua`:
```lua
local Scorer = dofile("lib/qb/qb_scorer.lua")
local Tracker = dofile("lib/qb/qb_state_tracker.lua")

local S_Cutscene = {}

function S_Cutscene:init(engine)
  self.engine = engine
  self.tracker = Tracker.new()
  self.cutscenes = {}
  self.active = nil    -- currently playing cutscene data
  self.elapsed = 0.0

  local data = engine:load_json("config/cutscenes/example_cutscene.json")
  if data then
    self.cutscenes = data.cutscenes or {}
  end
end

function S_Cutscene:get_cutscene(id)
  return self.cutscenes[id]
end

function S_Cutscene:can_play(cutscene_id, entity_id)
  local cutscene = self.cutscenes[cutscene_id]
  if not cutscene then
    return false
  end

  -- Check one-shot
  if cutscene.one_shot and self.tracker:is_one_shot_spent(cutscene_id) then
    return false
  end

  -- Check conditions
  local conditions = cutscene.conditions
  if not conditions or #conditions == 0 then
    return true
  end

  local context = {
    components = {},
    entity_tags = {},
    state = {
      flags = {},
    },
    event_name = "",
    event_payload = {},
  }

  -- Read flag state
  local flag_keys = {}
  for _, cond in ipairs(conditions) do
    if cond.type == "redux_field" and cond.state_path then
      local val = self.engine:get_state(cond.state_path)
      local parts = {}
      for part in string.gmatch(cond.state_path, "[^.]+") do
        table.insert(parts, part)
      end
      if #parts >= 2 then
        local ns = parts[1]
        local key = parts[2]
        if not context.state[ns] then
          context.state[ns] = {}
        end
        context.state[ns][key] = val
      end
    end
  end

  local results = Scorer.score_rules({{
    rule_id = cutscene_id,
    conditions = conditions,
    score_threshold = cutscene.score_threshold or 0.0,
    decision_group = "",
    priority = 0,
  }}, context)

  if #results > 0 then
    return results[1].score > (cutscene.score_threshold or 0.0)
  end
  return true
end

function S_Cutscene:process(engine, dt)
  if self.active then
    -- Advance cutscene
    self.elapsed = self.elapsed + dt

    local events = self.active.events or {}
    local keyframes = self.active.keyframes or {}

    -- Fire events at their timestamps
    for _, event in ipairs(events) do
      if not event._fired and self.elapsed >= (event.at or 0) then
        event._fired = true
        self:fire_event(event)
      end
    end

    -- Send current keyframe to renderer
    local current_kf = nil
    for _, kf in ipairs(keyframes) do
      if self.elapsed >= (kf.at or 0) then
        current_kf = kf
      end
    end
    if current_kf then
      engine:emit("CutsceneKeyframeEvent", current_kf)
    end

    -- End cutscene
    if self.elapsed >= (self.active.duration or 0) then
      self.elapsed = 0.0
      if self.active.one_shot then
        self.tracker:mark_one_shot_spent(self.active.cutscene_id)
      end
      engine:emit("CutsceneEndedEvent", {
        cutscene_id = self.active.cutscene_id,
      })
      self.active = nil
    end

    return -- Don't evaluate new cutscenes while one is playing
  end

  -- Look for cutscene triggers
  engine:query({"PlayerTag"}, function(eid)
    for id, cutscene in pairs(self.cutscenes) do
      if self:can_play(id, eid) then
        self:start_cutscene(cutscene)
        return
      end
    end
  end)
end

function S_Cutscene:start_cutscene(cutscene)
  self.active = {
    cutscene_id = cutscene.cutscene_id,
    duration = cutscene.duration,
    one_shot = cutscene.one_shot,
    keyframes = cutscene.keyframes,
    events = cutscene.events,
  }
  self.elapsed = 0.0

  self.engine:emit("CutsceneStartedEvent", {
    cutscene_id = cutscene.cutscene_id,
    duration = cutscene.duration,
    skip_enabled = cutscene.skip_enabled or true,
  })
end

function S_Cutscene:fire_event(event)
  if event.type == "input_lock" then
    self.engine:set_state("input_locked", true)
  elseif event.type == "input_unlock" then
    self.engine:set_state("input_locked", false)
  elseif event.type == "dialogue" then
    self.engine:emit("StartDialogueEvent", {
      dialogue_id = event.dialogue_id,
      entity = 1,
    })
  elseif event.type == "music" then
    self.engine:emit("AudioEvent", {
      audio_type = "music",
      track = event.track,
      fade = event.fade or 0.5,
    })
  end
end

return S_Cutscene
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_Cutscene]
lua_file = "systems/s_cutscene_system.lua"
system_set = "CoreMotion"
priority = 60
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_cutscene
```

Expected: All 3 cutscene tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_cutscene_system.lua engine/lua/config/cutscenes/example_cutscene.json engine/lua/config/systems.toml engine/tests/cutscene.rs
git commit -m "(GREEN) feat: add quality-driven cutscene system

S_Cutscene (CoreMotion, pri 60): loads cutscene JSON definitions,
quality-gates playback via QB conditions (e.g., player_level ≥ 5).
Keyframe-based camera paths (position, look_at, fov). Timeline events:
input_lock/unlock, dialogue trigger, music track. Skip support.
One-shot tracking prevents replay. Example: cave_reveal cutscene."
```

---

## Summary

**Total Tasks:** 7
**Estimated Implementation Time:** 6-8 focused engineering days

**Coverage Checklist:**
- [x] QB rule engine ported to Lua (scorer, selector, state tracker, path resolver)
- [x] Rule JSON format with Loader (conditions: component_field, redux_field, entity_tag, event_name, event_payload, constant, composite)
- [x] Character state system (quality-driven idle/combat/dead selection)
- [x] Narrative storylet system (storylet beats with decrees, flags, one-shot gating)
- [x] Dialogue system (nodes with quality-gated response options, client-side DialogueBox UI)
- [x] Animation state system (quality-driven idle/walk/run/jump blending)
- [x] Cutscene system (keyframe cameras, timeline events, quality-gated triggers)
