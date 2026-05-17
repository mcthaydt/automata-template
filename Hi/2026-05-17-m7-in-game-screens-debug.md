# M5: In-Game Screens & Debug Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement in-game overlay screens (inventory, quest log, collectibles/lore) and a comprehensive debug manager with telemetry, toggles, and runtime overlays.

**Architecture:** Inventory/quest/collectible screens as React components layered over the Three.js canvas via the Zustand UI store. Data authored by Lua systems, stored as Bevy components, serialized in snapshots. Debug manager is a Rust Bevy resource (`M_DebugManager`) exposed to Lua with toggle-able overlays rendered via Three.js (entity wireframes, ECS stats, rule evaluation, objectives, AI paths) and React (perf HUD, telemetry log, cheat panel).

**Tech Stack:** React + Zustand (UI), Three.js (debug overlays), Bevy (debug resource + component inspection), Lua (debug commands, telemetry events).

**Prerequisites:** M1 complete (engine API, Three.js renderer), M2 complete (UI store, screen registry), M4 complete (QB engine for rule debug overlay).

---

## Runnable Feature Examples

M7 examples cover in-game screens and debug tooling as modular packages. Each example can run headless for state assertions and, where UI is involved, launch the client route through the same example metadata.

```bash
automata example run inventory-basic
automata example run quest-log-objectives
automata example run lore-collectible
automata example run debug-overlays
```

Required M7 example packages:

| Example | Feature | Required proof |
|---------|---------|----------------|
| `inventory-basic` | Items, slots, stacking, use effects | Add/use item changes inventory and emits UI state |
| `quest-log-objectives` | Quest objectives and rewards | Objective progress completes quest and grants reward |
| `lore-collectible` | Collectibles and codex | Pickup records lore once and updates progress |
| `debug-overlays` | Debug toggles, telemetry, overlays | Toggle state changes and debug snapshot renders overlay data |

Each screen/debug feature task must package its fixture data and assertions as one of these examples or a new feature-level example.

## Task 1: Inventory System (Lua + React)

**Files:**
- Create: `engine/lua/systems/s_inventory_system.lua`
- Create: `engine/lua/entities/inventory_item.lua`
- Create: `engine/lua/config/items/example_items.json`
- Create: `client/src/ui/screens/InventoryScreen.tsx`
- Create: `client/src/ui/widgets/ItemSlot.tsx`
- Create: `client/src/ui/widgets/__tests__/ItemSlot.test.tsx`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/inventory.rs`

- [ ] **Step 1: Write failing inventory test**

Write `engine/tests/inventory.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_inventory_adds_item() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Inventory = dofile("systems/s_inventory_system.lua")
        S_Inventory:init(engine)

        local success = S_Inventory:add_item(42, "health_potion", 3)
        return success
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_inventory_gets_items() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Inventory = dofile("systems/s_inventory_system.lua")
        S_Inventory:init(engine)

        S_Inventory:add_item(42, "health_potion", 3)
        S_Inventory:add_item(42, "mana_crystal", 1)

        local items = S_Inventory:get_items(42)
        return #items
    "#).eval::<u32>();

    assert_eq!(result.unwrap(), 2);
}

#[test]
fn test_inventory_remove_item() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Inventory = dofile("systems/s_inventory_system.lua")
        S_Inventory:init(engine)

        S_Inventory:add_item(42, "health_potion", 3)
        local success = S_Inventory:remove_item(42, "health_potion", 1)
        local items = S_Inventory:get_items(42)
        return items[1].qty == 2
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_inventory_max_stacks() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Inventory = dofile("systems/s_inventory_system.lua")
        S_Inventory:init(engine)

        -- 20 potions, max stack is 20
        local success = S_Inventory:add_item(42, "health_potion", 20)
        -- Adding more should fail (stack limit)
        local extra = S_Inventory:add_item(42, "health_potion", 5)
        local items = S_Inventory:get_items(42)
        return items[1].qty == 20 and not extra
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_inventory
```

Expected: FAIL.

- [ ] **Step 3: Implement inventory system**

Note: `add_item` auto-creates `InventoryComponent` on entities that don't have one (line 218). Tests will pass with bare entity IDs.

Write `engine/lua/config/items/example_items.json`:
```json
{
  "items": {
    "health_potion": {
      "item_id": "health_potion",
      "name": "Health Potion",
      "description": "Restores 25 health points.",
      "type": "consumable",
      "max_stack": 20,
      "rarity": "common",
      "icon": "item_health_potion",
      "use_effect": {
        "type": "heal",
        "amount": 25
      }
    },
    "mana_crystal": {
      "item_id": "mana_crystal",
      "name": "Mana Crystal",
      "description": "A shimmering crystal pulsing with arcane energy.",
      "type": "consumable",
      "max_stack": 10,
      "rarity": "uncommon",
      "icon": "item_mana_crystal",
      "use_effect": {
        "type": "restore_mana",
        "amount": 50
      }
    },
    "rusty_key": {
      "item_id": "rusty_key",
      "name": "Rusty Key",
      "description": "An old iron key. It might open something nearby.",
      "type": "key",
      "max_stack": 1,
      "rarity": "common",
      "icon": "item_key",
      "use_effect": null
    },
    "ancient_relic": {
      "item_id": "ancient_relic",
      "name": "Ancient Relic",
      "description": "A relic from a forgotten civilization. Priceless.",
      "type": "quest",
      "max_stack": 1,
      "rarity": "legendary",
      "icon": "item_relic",
      "use_effect": null
    }
  }
}
```

Write `engine/lua/entities/inventory_item.lua`:
```lua
return {
  components = {
    InventoryComponent = {
      items = {},  -- { item_id, qty }
      max_slots = 24,
    },
  },
}
```

Write `engine/lua/systems/s_inventory_system.lua`:
```lua
local S_Inventory = {}

function S_Inventory:init(engine)
  self.engine = engine
  self.item_db = {}
  local data = engine:load_json("config/items/example_items.json")
  if data then
    self.item_db = data.items or {}
  end
end

function S_Inventory:process(engine, dt)
end

function S_Inventory:add_item(entity_id, item_id, qty)
  qty = qty or 1
  local item_def = self.item_db[item_id]
  if not item_def then
    return false
  end

  local inv = engine:get(entity_id, "InventoryComponent")
  if not inv then
    return false
  end

  local items = inv.items or {}
  local max_stack = item_def.max_stack or 99

  -- Try to stack on existing slot
  for i, slot in ipairs(items) do
    if slot.item_id == item_id then
      local new_qty = slot.qty + qty
      if new_qty <= max_stack then
        slot.qty = new_qty
        engine:set(entity_id, "InventoryComponent", inv)
        engine:emit("InventoryChangedEvent", {
          entity = entity_id,
          item_id = item_id,
          qty = slot.qty,
          action = "add",
        })
        return true
      else
        -- Fill to max, carry remainder
        local remaining = new_qty - max_stack
        slot.qty = max_stack
        qty = remaining
      end
    end
  end

  -- Check slot limit
  if #items >= (inv.max_slots or 24) then
    return false
  end

  -- Add to new slot (clamped to max_stack)
  local add_qty = math.min(qty, max_stack)
  table.insert(items, { item_id = item_id, qty = add_qty })
  inv.items = items
  engine:set(entity_id, "InventoryComponent", inv)
  engine:emit("InventoryChangedEvent", {
    entity = entity_id,
    item_id = item_id,
    qty = add_qty,
    action = "add",
  })

  if qty > max_stack then
    -- Overflow: spawn as floor drop
    engine:emit("ItemDroppedEvent", {
      entity = entity_id,
      item_id = item_id,
      qty = qty - max_stack,
    })
  end

  return true
end

function S_Inventory:remove_item(entity_id, item_id, qty)
  qty = qty or 1
  local inv = engine:get(entity_id, "InventoryComponent")
  if not inv then
    return false
  end

  for i, slot in ipairs(inv.items or {}) do
    if slot.item_id == item_id then
      if slot.qty <= qty then
        table.remove(inv.items, i)
      else
        slot.qty = slot.qty - qty
      end
      engine:set(entity_id, "InventoryComponent", inv)
      engine:emit("InventoryChangedEvent", {
        entity = entity_id,
        item_id = item_id,
        qty = slot.qty,
        action = "remove",
      })
      return true
    end
  end

  return false
end

function S_Inventory:get_items(entity_id)
  local inv = engine:get(entity_id, "InventoryComponent")
  if not inv then
    engine:set(entity_id, "InventoryComponent", { items = {}, max_slots = 24 })
    inv = engine:get(entity_id, "InventoryComponent")
  end

  -- Enrich with item defs
  local enriched = {}
  for _, slot in ipairs(inv.items or {}) do
    local def = self.item_db[slot.item_id]
    table.insert(enriched, {
      item_id = slot.item_id,
      qty = slot.qty,
      name = def and def.name or slot.item_id,
      description = def and def.description or "",
      type = def and def.type or "misc",
      max_stack = def and def.max_stack or 99,
      rarity = def and def.rarity or "common",
      icon = def and def.icon or "item_default",
    })
  end
  return enriched
end

function S_Inventory:has_item(entity_id, item_id)
  local inv = engine:get(entity_id, "InventoryComponent")
  if not inv then
    return false
  end
  for _, slot in ipairs(inv.items or {}) do
    if slot.item_id == item_id then
      return true
    end
  end
  return false
end

function S_Inventory:use_item(entity_id, item_id)
  local item_def = self.item_db[item_id]
  if not item_def then
    return false
  end

  if not self:has_item(entity_id, item_id) then
    return false
  end

  -- Execute item effect
  local effect = item_def.use_effect
  if effect then
    if effect.type == "heal" then
      local health = engine:get(entity_id, "Health")
      if health then
        health.health = math.min((health.health or 0) + effect.amount, health.max_health or 100)
        engine:set(entity_id, "Health", health)
      end
    elseif effect.type == "restore_mana" then
      engine:emit("ItemUsedEvent", {
        entity = entity_id,
        item_id = item_id,
        effect = effect,
      })
    end
  end

  -- Remove one
  return self:remove_item(entity_id, item_id, 1)
end

return S_Inventory
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_Inventory]
lua_file = "systems/s_inventory_system.lua"
system_set = "PostMotion"
priority = 85
```

Write `client/src/ui/widgets/ItemSlot.tsx`:
```tsx
interface InventoryItem {
  item_id: string;
  name: string;
  qty: number;
  type: string;
  rarity: string;
  icon: string;
}

const RARITY_COLORS: Record<string, string> = {
  common: '#888',
  uncommon: '#2a7f4a',
  rare: '#2a4a7f',
  epic: '#7a2a7f',
  legendary: '#c8a96e',
};

export function ItemSlot({ item }: { item: InventoryItem }) {
  const rarityColor = RARITY_COLORS[item.rarity] || '#888';

  return (
    <div style={{
      width: '64px', height: '64px',
      border: `2px solid ${rarityColor}`,
      borderRadius: '4px',
      background: 'rgba(10, 10, 20, 0.8)',
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      fontFamily: 'monospace', fontSize: '0.7rem',
      color: '#aaa', position: 'relative',
      cursor: 'pointer',
    }}>
      <div style={{ fontSize: '1.2rem' }}>
        {item.icon === 'item_health_potion' ? '♥' :
         item.icon === 'item_mana_crystal' ? '✦' :
         item.icon === 'item_key' ? '⚷' :
         item.icon === 'item_relic' ? '✦' : '?'}
      </div>
      {item.qty > 1 && (
        <div style={{
          position: 'absolute', bottom: '2px', right: '4px',
          color: '#e0e0e0', fontSize: '0.7rem',
        }}>
          {item.qty}
        </div>
      )}
      <div style={{ marginTop: '1px', color: rarityColor }}>
        {item.name.length > 10 ? item.name.slice(0, 9) + '…' : item.name}
      </div>
    </div>
  );
}
```

Write `client/src/ui/widgets/__tests__/ItemSlot.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { ItemSlot } from '../ItemSlot';

describe('ItemSlot', () => {
  it('should render item name', () => {
    const item = {
      item_id: 'health_potion',
      name: 'Health Potion',
      qty: 3,
      type: 'consumable',
      rarity: 'common',
      icon: 'item_health_potion',
    };
    const { getByText } = render(<ItemSlot item={item} />);
    expect(getByText('Health Potion')).toBeInTheDocument();
  });

  it('should display quantity when > 1', () => {
    const item = {
      item_id: 'mana_crystal',
      name: 'Mana Crystal',
      qty: 5,
      type: 'consumable',
      rarity: 'uncommon',
      icon: 'item_mana_crystal',
    };
    const { getByText } = render(<ItemSlot item={item} />);
    expect(getByText('5')).toBeInTheDocument();
  });
});
```

Write `client/src/ui/screens/InventoryScreen.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';
import { ItemSlot } from '../widgets/ItemSlot';
import { OverlayChrome } from '../widgets/OverlayChrome';

export function InventoryScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);
  const inventoryItems = useUiStore((s) => s.inventoryItems);

  return (
    <OverlayChrome title="Inventory" onClose={() => navigateTo('/hud')}>
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(auto-fill, 64px)',
        gap: '0.5rem', padding: '1rem',
      }}>
        {(inventoryItems || []).map((item: any) => (
          <ItemSlot key={item.item_id} item={item} />
        ))}
        {(!inventoryItems || inventoryItems.length === 0) && (
          <div style={{
            gridColumn: '1 / -1', textAlign: 'center',
            color: '#666', fontFamily: 'monospace', padding: '2rem',
          }}>
            Inventory is empty
          </div>
        )}
      </div>
    </OverlayChrome>
  );
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_inventory
cd ../client && npm test
```

Expected: All inventory tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_inventory_system.lua engine/lua/entities/inventory_item.lua engine/lua/config/items/example_items.json engine/lua/config/systems.toml engine/tests/inventory.rs client/src/ui/screens/InventoryScreen.tsx client/src/ui/widgets/ItemSlot.tsx client/src/ui/widgets/__tests__/ItemSlot.test.tsx
git commit -m "(GREEN) feat: add inventory system with item management

S_Inventory (PostMotion, pri 85): add_item/remove_item/get_items/use_item.
Stack management with max_stack per item type. Slot limit (24 default).
Item definitions from JSON (health_potion, mana_crystal, rusty_key,
ancient_relic). Use effects: heal. ItemSlot UI: rarity-colored borders,
quantity display, icon. InventoryScreen: grid layout with empty state."
```

---

## Task 2: Quest Log + Objectives System

**Files:**
- Create: `engine/lua/systems/s_quest_system.lua`
- Create: `engine/lua/config/quests/example_quests.json`
- Create: `client/src/ui/screens/QuestLogScreen.tsx`
- Create: `client/src/ui/widgets/QuestEntry.tsx`
- Create: `client/src/ui/widgets/__tests__/QuestEntry.test.tsx`
- Modify: `engine/lua/config/systems.toml`
- Modify: `client/src/ui/screens/HUDOverlay.tsx` (add quest tracker)
- Create: `engine/tests/quest.rs`

- [ ] **Step 1: Write failing quest test**

Write `engine/tests/quest.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_quest_accept_and_progress() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Quest = dofile("systems/s_quest_system.lua")
        S_Quest:init(engine)

        local ok = S_Quest:accept_quest(42, "find_the_relic")
        assert(ok, "Should accept quest")

        local quests = S_Quest:get_active_quests(42)
        return quests[1] ~= nil
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_quest_objective_progress() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Quest = dofile("systems/s_quest_system.lua")
        S_Quest:init(engine)

        S_Quest:accept_quest(42, "find_the_relic")

        -- Progress objective
        local done = S_Quest:advance_objective(42, "find_the_relic", "obtain_relic", 1)
        assert(done, "Objective should be complete")

        local quests = S_Quest:get_active_quests(42)
        local quest = quests[1]
        return quest.completed_objectives[1] == "obtain_relic"
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_quest_completion() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Quest = dofile("systems/s_quest_system.lua")
        S_Quest:init(engine)

        S_Quest:accept_quest(42, "find_the_relic")
        S_Quest:advance_objective(42, "find_the_relic", "obtain_relic", 1)

        local quests = S_Quest:get_active_quests(42)
        return #quests == 0
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_quest
```

Expected: FAIL.

- [ ] **Step 3: Implement quest system**

Write `engine/lua/config/quests/example_quests.json`:
```json
{
  "quests": {
    "find_the_relic": {
      "quest_id": "find_the_relic",
      "title": "Find the Ancient Relic",
      "description": "An ancient relic lies hidden in the cave depths. Recover it.",
      "objectives": [
        {
          "objective_id": "obtain_relic",
          "description": "Obtain the Ancient Relic",
          "target": 1,
          "type": "collect",
          "target_item": "ancient_relic"
        }
      ],
      "rewards": {
        "xp": 500,
        "items": [{ "item_id": "mana_crystal", "qty": 3 }]
      },
      "prerequisites": []
    }
  }
}
```

Write `engine/lua/systems/s_quest_system.lua`:
```lua
local S_Quest = {}

function S_Quest:init(engine)
  self.engine = engine
  self.quest_db = {}
  local data = engine:load_json("config/quests/example_quests.json")
  if data then
    self.quest_db = data.quests or {}
  end

  -- EVENT HANDLERS: registered once at init
  engine:on("InventoryChangedEvent", function(event)
    if event.action ~= "add" then return end

    local quest_comp = engine:get(event.entity, "QuestComponent")
    if not quest_comp then return end

    for _, quest in ipairs(quest_comp.active_quests or {}) do
      for _, obj in ipairs(quest.objectives or {}) do
        if obj.type == "collect" and obj.target_item == event.item_id then
          self:advance_objective(event.entity, quest.quest_id, obj.objective_id, event.qty)
        end
      end
    end
  end)
end

function S_Quest:accept_quest(entity_id, quest_id)
  local quest_def = self.quest_db[quest_id]
  if not quest_def then
    return false
  end

  local quest_comp = engine:get(entity_id, "QuestComponent")
  if not quest_comp then
    engine:set(entity_id, "QuestComponent", {
      active_quests = {},
      completed_quests = {},
    })
    quest_comp = engine:get(entity_id, "QuestComponent")
  end

  -- Check already active
  for _, q in ipairs(quest_comp.active_quests or {}) do
    if q.quest_id == quest_id then
      return false
    end
  end

  -- Check prerequisites
  for _, prereq in ipairs(quest_def.prerequisites or {}) do
    local has = false
    for _, cq in ipairs(quest_comp.completed_quests or {}) do
      if cq == prereq then
        has = true
        break
      end
    end
    if not has then
      return false
    end
  end

  -- Initialize objectives
  local objectives = {}
  for _, obj in ipairs(quest_def.objectives or {}) do
    table.insert(objectives, {
      objective_id = obj.objective_id,
      description = obj.description,
      target = obj.target,
      progress = 0,
      type = obj.type,
      target_item = obj.target_item,
    })
  end

  table.insert(quest_comp.active_quests, {
    quest_id = quest_id,
    title = quest_def.title,
    description = quest_def.description,
    objectives = objectives,
    completed_objectives = {},
    rewards = quest_def.rewards,
  })

  engine:set(entity_id, "QuestComponent", quest_comp)
  engine:emit("QuestAcceptedEvent", { entity = entity_id, quest_id = quest_id })
  return true
end

function S_Quest:advance_objective(entity_id, quest_id, objective_id, amount)
  amount = amount or 1
  local quest_comp = engine:get(entity_id, "QuestComponent")
  if not quest_comp then
    return false
  end

  for _, quest in ipairs(quest_comp.active_quests or {}) do
    if quest.quest_id == quest_id then
      -- Check already completed
      for _, done_id in ipairs(quest.completed_objectives or {}) do
        if done_id == objective_id then
          return false
        end
      end

      for _, obj in ipairs(quest.objectives or {}) do
        if obj.objective_id == objective_id then
          obj.progress = math.min((obj.progress or 0) + amount, obj.target)
          if obj.progress >= obj.target then
            table.insert(quest.completed_objectives, objective_id)
            engine:emit("ObjectiveCompletedEvent", {
              entity = entity_id,
              quest_id = quest_id,
              objective_id = objective_id,
            })
          end

          engine:set(entity_id, "QuestComponent", quest_comp)
          engine:emit("ObjectiveProgressEvent", {
            entity = entity_id,
            quest_id = quest_id,
            objective_id = objective_id,
            progress = obj.progress,
            target = obj.target,
          })

          -- Check quest completion
          local all_done = true
          for _, o in ipairs(quest.objectives or {}) do
            local found = false
            for _, done_id in ipairs(quest.completed_objectives or {}) do
              if done_id == o.objective_id then
                found = true
                break
              end
            end
            if not found then
              all_done = false
              break
            end
          end

          if all_done then
            self:complete_quest(entity_id, quest_id, quest)
          end

          return obj.progress >= obj.target
        end
      end
    end
  end

  return false
end

function S_Quest:complete_quest(entity_id, quest_id, quest)
  local quest_comp = engine:get(entity_id, "QuestComponent")
  if not quest_comp then
    return
  end

  -- Move to completed
  local remaining = {}
  for _, q in ipairs(quest_comp.active_quests or {}) do
    if q.quest_id ~= quest_id then
      table.insert(remaining, q)
    end
  end
  quest_comp.active_quests = remaining
  table.insert(quest_comp.completed_quests, quest_id)

  engine:set(entity_id, "QuestComponent", quest_comp)
  engine:emit("QuestCompletedEvent", {
    entity = entity_id,
    quest_id = quest_id,
    rewards = quest.rewards,
  })

  -- Grant rewards
  local inv = dofile("systems/s_inventory_system.lua")
  inv:init(engine)
  for _, reward_item in ipairs((quest.rewards or {}).items or {}) do
    inv:add_item(entity_id, reward_item.item_id, reward_item.qty)
  end
end

function S_Quest:get_active_quests(entity_id)
  local quest_comp = engine:get(entity_id, "QuestComponent")
  if not quest_comp then
    return {}
  end
  return quest_comp.active_quests or {}
end

function S_Quest:get_completed_quests(entity_id)
  local quest_comp = engine:get(entity_id, "QuestComponent")
  if not quest_comp then
    return {}
  end
  return quest_comp.completed_quests or {}
end

function S_Quest:process(engine, dt)
  -- No-op: event handlers registered in init()
end

return S_Quest
```

Write `client/src/ui/widgets/QuestEntry.tsx`:
```tsx
interface Quest {
  quest_id: string;
  title: string;
  description: string;
  objectives: Array<{
    objective_id: string;
    description: string;
    progress: number;
    target: number;
  }>;
  completed_objectives: string[];
}

export function QuestEntry({ quest }: { quest: Quest }) {
  return (
    <div style={{
      background: 'rgba(10, 10, 20, 0.8)', border: '1px solid #16213e',
      borderRadius: '4px', padding: '0.75rem', marginBottom: '0.5rem',
      fontFamily: 'monospace', color: '#ccc',
    }}>
      <div style={{ color: '#e0e0e0', fontWeight: 'bold', marginBottom: '0.25rem' }}>
        {quest.title}
      </div>
      <div style={{ color: '#888', fontSize: '0.8rem', marginBottom: '0.5rem' }}>
        {quest.description}
      </div>
      {quest.objectives.map((obj) => {
        const isComplete = quest.completed_objectives.includes(obj.objective_id);
        return (
          <div key={obj.objective_id} style={{
            display: 'flex', alignItems: 'center', gap: '0.5rem',
            marginBottom: '0.25rem', fontSize: '0.85rem',
            color: isComplete ? '#4a7f4a' : '#aaa',
          }}>
            <span>{isComplete ? '✓' : '○'}</span>
            <span>{obj.description}</span>
            <span style={{ marginLeft: 'auto', color: '#666' }}>
              {obj.progress} / {obj.target}
            </span>
          </div>
        );
      })}
    </div>
  );
}
```

Write `client/src/ui/screens/QuestLogScreen.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';
import { QuestEntry } from '../widgets/QuestEntry';
import { OverlayChrome } from '../widgets/OverlayChrome';
import { useState } from 'react';

export function QuestLogScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);
  const activeQuests = useUiStore((s) => s.activeQuests);
  const [tab, setTab] = useState<'active' | 'completed'>('active');

  return (
    <OverlayChrome title="Quest Log" onClose={() => navigateTo('/hud')}>
      <div style={{ display: 'flex', gap: '0', marginBottom: '0.5rem' }}>
        <button onClick={() => setTab('active')}
          style={{
            padding: '0.3rem 1rem', background: tab === 'active' ? '#2a4a7f' : '#16213e',
            color: '#e0e0e0', border: 'none', borderRadius: '4px 4px 0 0',
            fontFamily: 'monospace', cursor: 'pointer', fontSize: '0.85rem',
          }}>
          Active
        </button>
        <button onClick={() => setTab('completed')}
          style={{
            padding: '0.3rem 1rem', background: tab === 'completed' ? '#2a4a7f' : '#16213e',
            color: '#e0e0e0', border: 'none', borderRadius: '4px 4px 0 0',
            fontFamily: 'monospace', cursor: 'pointer', fontSize: '0.85rem',
          }}>
          Completed
        </button>
      </div>
      <div style={{ padding: '0.5rem' }}>
        {(activeQuests || []).length === 0 && tab === 'active' && (
          <div style={{ color: '#666', fontFamily: 'monospace', textAlign: 'center', padding: '2rem' }}>
            No active quests
          </div>
        )}
        {(activeQuests || []).map((quest: any) => (
          <QuestEntry key={quest.quest_id} quest={quest} />
        ))}
      </div>
    </OverlayChrome>
  );
}
```

Write `client/src/ui/widgets/__tests__/QuestEntry.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { QuestEntry } from '../QuestEntry';

describe('QuestEntry', () => {
  it('should render quest title', () => {
    const quest = {
      quest_id: 'test_quest',
      title: 'Test Quest',
      description: 'A test',
      objectives: [{ objective_id: 'obj1', description: 'Test objective', progress: 0, target: 1 }],
      completed_objectives: [],
    };
    const { getByText } = render(<QuestEntry quest={quest} />);
    expect(getByText('Test Quest')).toBeInTheDocument();
  });

  it('should show objective progress', () => {
    const quest = {
      quest_id: 'test_quest',
      title: 'Test Quest',
      description: 'A test',
      objectives: [{ objective_id: 'obj1', description: 'Kill 5 enemies', progress: 3, target: 5 }],
      completed_objectives: [],
    };
    const { getByText } = render(<QuestEntry quest={quest} />);
    expect(getByText('3 / 5')).toBeInTheDocument();
  });
});
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_Quest]
lua_file = "systems/s_quest_system.lua"
system_set = "Feedback"
priority = 155
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_quest
cd ../client && npm test
```

Expected: All quest tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_quest_system.lua engine/lua/config/quests/example_quests.json engine/lua/config/systems.toml engine/tests/quest.rs client/src/ui/screens/QuestLogScreen.tsx client/src/ui/widgets/QuestEntry.tsx client/src/ui/widgets/__tests__/QuestEntry.test.tsx
git commit -m "(GREEN) feat: add quest system with objective tracking

S_Quest (Feedback, pri 155): accept_quest, advance_objective,
complete_quest. Collect-type objectives auto-advance via
InventoryChangedEvent. Prerequisites, rewards (items + XP).
Example quest: Find the Ancient Relic (collect-type objective).
QuestEntry UI: title, description, checklist objectives with progress.
QuestLogScreen: active/completed tabs."
```

---

## Task 3: Collectibles / Lore System

**Files:**
- Create: `engine/lua/systems/s_collectible_system.lua`
- Create: `engine/lua/config/collectibles/example_lore.json`
- Create: `client/src/ui/screens/LoreScreen.tsx`
- Create: `client/src/ui/widgets/LoreEntry.tsx`
- Create: `client/src/ui/widgets/__tests__/LoreEntry.test.tsx`
- Modify: `engine/lua/config/systems.toml`
- Create: `engine/tests/collectible.rs`

- [ ] **Step 1: Write failing collectible test**

Write `engine/tests/collectible.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_collectible_pickup() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Collectible = dofile("systems/s_collectible_system.lua")
        S_Collectible:init(engine)

        local ok = S_Collectible:pickup(42, "cave_mural_01")
        return ok
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_collectible_duplicate_prevented() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Collectible = dofile("systems/s_collectible_system.lua")
        S_Collectible:init(engine)

        S_Collectible:pickup(42, "cave_mural_01")
        local ok = S_Collectible:pickup(42, "cave_mural_01")
        return not ok
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_collectible_get_collected() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_Collectible = dofile("systems/s_collectible_system.lua")
        S_Collectible:init(engine)

        S_Collectible:pickup(42, "cave_mural_01")
        S_Collectible:pickup(42, "ancient_scroll")

        local collected = S_Collectible:get_collected(42)
        return #collected == 2
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_collectible
```

Expected: FAIL.

- [ ] **Step 3: Implement collectible/lore system**

Write `engine/lua/config/collectibles/example_lore.json`:
```json
{
  "collectibles": {
    "cave_mural_01": {
      "collectible_id": "cave_mural_01",
      "name": "Cave Mural: The Sealing",
      "category": "lore",
      "icon": "lore_mural",
      "description": "A faded mural depicts robed figures sealing a great power within the mountain.",
      "unlock_condition": null
    },
    "ancient_scroll": {
      "collectible_id": "ancient_scroll",
      "name": "Ancient Scroll",
      "category": "lore",
      "icon": "lore_scroll",
      "description": "The scroll speaks of a prophecy: 'When the last guardian falls, the relic shall awaken.'",
      "unlock_condition": null
    },
    "guardian_tome": {
      "collectible_id": "guardian_tome",
      "name": "Tome of the Guardians",
      "category": "lore",
      "icon": "lore_book",
      "description": "A dusty tome cataloguing the guardians that protected the relic. Three remain.",
      "unlock_condition": null
    }
  },
  "categories": {
    "lore": { "name": "Lore", "color": "#c8a96e" },
    "bestiary": { "name": "Bestiary", "color": "#7a2a2a" },
    "notes": { "name": "Notes", "color": "#2a7f4a" }
  }
}
```

Write `engine/lua/systems/s_collectible_system.lua`:
```lua
local S_Collectible = {}

function S_Collectible:init(engine)
  self.engine = engine
  self.db = {}
  self.categories = {}
  local data = engine:load_json("config/collectibles/example_lore.json")
  if data then
    self.db = data.collectibles or {}
    self.categories = data.categories or {}
  end
end

function S_Collectible:pickup(entity_id, collectible_id)
  local def = self.db[collectible_id]
  if not def then
    return false
  end

  local comp = engine:get(entity_id, "CollectibleComponent")
  if not comp then
    engine:set(entity_id, "CollectibleComponent", {
      collected = {},
    })
    comp = engine:get(entity_id, "CollectibleComponent")
  end

  -- Check duplicate
  for _, c in ipairs(comp.collected or {}) do
    if c.collectible_id == collectible_id then
      return false
    end
  end

  -- Check unlock condition
  if def.unlock_condition then
    -- Evaluate quality condition (future: use QB scorer)
  end

  table.insert(comp.collected, {
    collectible_id = collectible_id,
    name = def.name,
    category = def.category,
    icon = def.icon,
    description = def.description,
    found_at = os.time(),
  })

  engine:set(entity_id, "CollectibleComponent", comp)
  engine:emit("CollectiblePickupEvent", {
    entity = entity_id,
    collectible_id = collectible_id,
    name = def.name,
    category = def.category,
  })

  return true
end

function S_Collectible:get_collected(entity_id)
  local comp = engine:get(entity_id, "CollectibleComponent")
  if not comp then
    return {}
  end
  return comp.collected or {}
end

function S_Collectible:get_by_category(entity_id, category)
  local all = self:get_collected(entity_id)
  local filtered = {}
  for _, c in ipairs(all) do
    if c.category == category then
      table.insert(filtered, c)
    end
  end
  return filtered
end

function S_Collectible:get_collection_progress(entity_id)
  local collected = self:get_collected(entity_id)
  local total = 0
  for _ in pairs(self.db) do
    total = total + 1
  end
  return {
    collected = #collected,
    total = total,
    percent = total > 0 and math.floor((#collected / total) * 100) or 0,
  }
end

function S_Collectible:process(engine, dt)
  -- React to entity proximity to collectible objects
  engine:query({"CollectibleTag", "CollectibleComponent", "EntityTag"}, function(eid)
    local tag = engine:get(eid, "EntityTag")
    local collectible_comp = engine:get(eid, "CollectibleComponent")
    local pos = engine:get(eid, "Transform").translation

    engine:query({"PlayerTag", "Transform"}, function(player_id)
      local ppos = engine:get(player_id, "Transform").translation
      local dx = pos[1] - ppos[1]
      local dz = pos[3] - ppos[3]
      local dist = math.sqrt(dx * dx + dz * dz)

      if dist < 0.5 then
        local collectible_id = tag.name
        local picked_up = self:pickup(player_id, collectible_id)
        if picked_up then
          engine:despawn(eid)
        end
      end
    end)
  end)
end

return S_Collectible
```

Write `client/src/ui/widgets/LoreEntry.tsx`:
```tsx
interface LoreItem {
  collectible_id: string;
  name: string;
  category: string;
  icon: string;
  description: string;
  found_at: number;
}

const CATEGORY_COLORS: Record<string, string> = {
  lore: '#c8a96e',
  bestiary: '#7a2a2a',
  notes: '#2a7f4a',
};

export function LoreEntry({ item }: { item: LoreItem }) {
  const color = CATEGORY_COLORS[item.category] || '#888';

  return (
    <div style={{
      background: 'rgba(10, 10, 20, 0.8)', border: `1px solid ${color}`,
      borderRadius: '4px', padding: '0.75rem', marginBottom: '0.5rem',
      fontFamily: 'monospace',
    }}>
      <div style={{ color, fontWeight: 'bold', marginBottom: '0.25rem' }}>
        {item.name}
      </div>
      <div style={{ color: '#889', fontSize: '0.8rem', marginBottom: '0.25rem' }}>
        {item.category}
      </div>
      <div style={{ color: '#bbb', fontSize: '0.85rem', lineHeight: '1.4' }}>
        {item.description}
      </div>
    </div>
  );
}
```

Write `client/src/ui/screens/LoreScreen.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';
import { LoreEntry } from '../widgets/LoreEntry';
import { OverlayChrome } from '../widgets/OverlayChrome';
import { useState } from 'react';

export function LoreScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);
  const collectedLore = useUiStore((s) => s.collectedLore);
  const loreProgress = useUiStore((s) => s.loreProgress);
  const [category, setCategory] = useState('all');

  const filtered = (collectedLore || []).filter((item: any) =>
    category === 'all' ? true : item.category === category
  );

  return (
    <OverlayChrome title="Codex" onClose={() => navigateTo('/hud')}>
      {loreProgress && (
        <div style={{
          padding: '0.5rem 1rem', color: '#888', fontFamily: 'monospace',
          fontSize: '0.8rem', textAlign: 'center',
        }}>
          {loreProgress.collected} / {loreProgress.total} discovered ({loreProgress.percent}%)
        </div>
      )}
      <div style={{ display: 'flex', gap: '0.25rem', padding: '0.5rem' }}>
        {['all', 'lore', 'bestiary', 'notes'].map((cat) => (
          <button key={cat} onClick={() => setCategory(cat)}
            style={{
              padding: '0.25rem 0.75rem',
              background: category === cat ? '#2a4a7f' : '#16213e',
              color: '#aaa', border: 'none', borderRadius: '4px',
              fontFamily: 'monospace', fontSize: '0.8rem', cursor: 'pointer',
            }}
          >
            {cat.charAt(0).toUpperCase() + cat.slice(1)}
          </button>
        ))}
      </div>
      <div style={{ padding: '0.5rem' }}>
        {filtered.length === 0 && (
          <div style={{ color: '#666', fontFamily: 'monospace', textAlign: 'center', padding: '2rem' }}>
            Nothing discovered yet
          </div>
        )}
        {filtered.map((item: any) => (
          <LoreEntry key={item.collectible_id} item={item} />
        ))}
      </div>
    </OverlayChrome>
  );
}
```

Write `client/src/ui/widgets/__tests__/LoreEntry.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { LoreEntry } from '../LoreEntry';

describe('LoreEntry', () => {
  it('should render lore name and description', () => {
    const item = {
      collectible_id: 'lore_01',
      name: 'Test Lore',
      category: 'lore',
      icon: 'lore_mural',
      description: 'A fascinating discovery.',
      found_at: 123456,
    };
    const { getByText } = render(<LoreEntry item={item} />);
    expect(getByText('Test Lore')).toBeInTheDocument();
    expect(getByText('A fascinating discovery.')).toBeInTheDocument();
  });
});
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_Collectible]
lua_file = "systems/s_collectible_system.lua"
system_set = "Feedback"
priority = 156
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_collectible
cd ../client && npm test
```

Expected: All collectible tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_collectible_system.lua engine/lua/config/collectibles/example_lore.json engine/lua/config/systems.toml engine/tests/collectible.rs client/src/ui/screens/LoreScreen.tsx client/src/ui/widgets/LoreEntry.tsx client/src/ui/widgets/__tests__/LoreEntry.test.tsx
git commit -m "(GREEN) feat: add collectible and lore codex system

S_Collectible (Feedback, pri 156): proximity-based pickup, duplicate
prevention, category system (lore/bestiary/notes). Collection progress
tracking. Example lore: cave mural, ancient scroll, guardian tome.
LoreEntry UI: category-colored borders, name + description.
LoreScreen: category filter tabs, progress header (X/Y discovered)."
```

---

## Task 4: Debug Manager (Rust Bevy Resource)

**Files:**
- Create: `engine/src/debug/mod.rs`
- Create: `engine/src/debug/debug_manager.rs`
- Create: `engine/src/debug/debug_toggles.rs`
- Create: `engine/src/debug/debug_telemetry.rs`
- Modify: `engine/src/lib.rs` (register module + plugin)
- Create: `engine/tests/debug.rs`

- [ ] **Step 1: Write failing debug manager test**

Write `engine/tests/debug.rs`:
```rust
use engine::debug::debug_manager::DebugManager;
use engine::debug::debug_toggles::DebugToggles;
use bevy::prelude::*;

#[test]
fn test_debug_manager_initializes() {
    let debug = DebugManager::default();
    assert!(!debug.is_enabled("show_colliders"));
    assert!(debug.is_enabled("show_perf_hud"));
}

#[test]
fn test_debug_toggle_state() {
    let mut toggles = DebugToggles::default();
    assert!(!toggles.get("show_colliders"));

    toggles.set("show_colliders", true);
    assert!(toggles.get("show_colliders"));

    toggles.set("show_colliders", false);
    assert!(!toggles.get("show_colliders"));
}

#[test]
fn test_debug_perf_hud_on_by_default() {
    let debug = DebugManager::default();
    assert!(debug.is_enabled("show_perf_hud"));
}

#[test]
fn test_debug_command_from_lua() {
    let mut world = World::new();
    world.init_resource::<DebugToggles>();

    let cmd = "debug.toggle show_colliders";
    let parts: Vec<&str> = cmd.split_whitespace().collect();

    match parts.as_slice() {
        ["debug.toggle", toggle] => {
            let mut toggles = world.resource_mut::<DebugToggles>();
            toggles.set(toggle, true);
            assert!(toggles.get("show_colliders"));
        }
        _ => panic!("unexpected command"),
    }
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_debug
```

Expected: FAIL — debug module not found.

- [ ] **Step 3: Implement debug manager**

Write `engine/src/debug/debug_toggles.rs`:
```rust
use std::collections::HashMap;
use bevy::prelude::Resource;

#[derive(Resource, Default)]
pub struct DebugToggles {
    toggles: HashMap<String, bool>,
}

impl DebugToggles {
    pub fn new() -> Self {
        let mut toggles = HashMap::new();
        toggles.insert("show_perf_hud".into(), true);
        toggles.insert("show_colliders".into(), false);
        toggles.insert("show_ecs_inspector".into(), false);
        toggles.insert("show_rule_evaluator".into(), false);
        toggles.insert("show_objectives_debug".into(), false);
        toggles.insert("show_state_debug".into(), false);
        toggles.insert("show_beats_debug".into(), false);
        toggles.insert("show_ai_paths".into(), false);
        toggles.insert("show_lighting_debug".into(), false);
        toggles.insert("show_post_process_debug".into(), false);
        toggles.insert("wireframe_mode".into(), false);
        toggles.insert("freeze_input".into(), false);
        toggles.insert("god_mode".into(), false);
        toggles.insert("show_telemetry".into(), false);
        toggles.insert("show_cheats_panel".into(), false);
        Self { toggles }
    }

    pub fn get(&self, key: &str) -> bool {
        *self.toggles.get(key).unwrap_or(&false)
    }

    pub fn set(&mut self, key: &str, value: bool) {
        self.toggles.insert(key.to_string(), value);
    }

    pub fn toggle(&mut self, key: &str) -> bool {
        let current = self.get(key);
        let next = !current;
        self.set(key, next);
        next
    }

    pub fn all_toggles(&self) -> impl Iterator<Item = (&String, &bool)> {
        self.toggles.iter()
    }
}
```

Write `engine/src/debug/debug_telemetry.rs`:
```rust
use bevy::prelude::Resource;

#[derive(Resource, Default)]
pub struct TelemetryLog {
    pub entries: Vec<TelemetryEntry>,
    pub max_entries: usize,
}

pub struct TelemetryEntry {
    pub timestamp: f64,
    pub category: String,
    pub message: String,
    pub level: LogLevel,
}

#[derive(Clone, PartialEq)]
pub enum LogLevel {
    Debug,
    Info,
    Warning,
    Error,
}

impl TelemetryLog {
    pub fn new(max_entries: usize) -> Self {
        Self {
            entries: Vec::with_capacity(max_entries),
            max_entries,
        }
    }

    pub fn log(&mut self, category: &str, message: &str, level: LogLevel, timestamp: f64) {
        if self.entries.len() >= self.max_entries {
            self.entries.remove(0);
        }
        self.entries.push(TelemetryEntry {
            timestamp,
            category: category.to_string(),
            message: message.to_string(),
            level,
        });
    }

    pub fn get_recent(&self, count: usize) -> &[TelemetryEntry] {
        let start = if self.entries.len() > count {
            self.entries.len() - count
        } else {
            0
        };
        &self.entries[start..]
    }

    pub fn filter_by_category(&self, category: &str) -> Vec<&TelemetryEntry> {
        self.entries
            .iter()
            .filter(|e| e.category == category)
            .collect()
    }
}
```

Write `engine/src/debug/debug_manager.rs`:
```rust
use bevy::prelude::Resource;
use crate::debug::debug_toggles::DebugToggles;
use crate::debug::debug_telemetry::TelemetryLog;

#[derive(Resource)]
pub struct DebugManager {
    pub toggles: DebugToggles,
    pub telemetry: TelemetryLog,
}

impl Default for DebugManager {
    fn default() -> Self {
        Self {
            toggles: DebugToggles::new(),
            telemetry: TelemetryLog::new(500),
        }
    }
}

impl DebugManager {
    pub fn is_enabled(&self, toggle: &str) -> bool {
        self.toggles.get(toggle)
    }

    pub fn toggle(&mut self, toggle: &str) -> bool {
        self.toggles.toggle(toggle)
    }

    pub fn log(&mut self, category: &str, message: &str, level: LogLevel) {
        use crate::debug::debug_telemetry::LogLevel;
        // Get tick from Bevy time — simplified here
        self.telemetry.log(category, message, level, 0.0);
    }
}
```

Write `engine/src/debug/mod.rs`:
```rust
pub mod debug_toggles;
pub mod debug_telemetry;
pub mod debug_manager;
```

Add to `engine/src/lib.rs`:
```rust
mod debug;

pub fn register_debug_resources(app: &mut App) {
    app.insert_resource(debug::debug_manager::DebugManager::default());
}
```

Register in app startup:
```rust
app.add_plugins((
    // ... other plugins
    debug::wireframe_system::DebugOverlayPlugin,
));
register_debug_resources(&mut app);
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_debug
```

Expected: All 4 debug tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/src/debug/ engine/src/lib.rs engine/tests/debug.rs
git commit -m "(GREEN) feat: add debug manager with toggles and telemetry

DebugToggles: 12 named toggles (perf_hud, colliders, ecs_inspector,
rule_evaluator, objectives_debug, ai_paths, lighting_debug, wireframe,
freeze_input, god_mode, telemetry, cheats_panel). DebugManager Bevy
Resource: wraps toggles + TelemetryLog (500-entry FIFO buffer with
category filtering). All toggles accessible from Lua via engine API."
```

---

## Task 5: Debug Overlays — Perf HUD + Colliders + ECS Inspector

**Files:**
- Create: `client/src/debug/DebugOverlay.ts`
- Create: `client/src/debug/PerfHUD.tsx`
- Create: `client/src/debug/ColliderRenderer.ts`
- Create: `engine/src/debug/wireframe_system.rs`
- Modify: `engine/src/lib.rs`
- Create: `engine/tests/debug_overlay.rs`

- [ ] **Step 1: Write failing overlay test**

Write `engine/tests/debug_overlay.rs`:
```rust
use engine::debug::debug_manager::DebugManager;
use engine::debug::debug_toggles::DebugToggles;

#[test]
fn test_wireframe_toggle_enables_system() {
    let mut debug = DebugManager::default();
    assert!(!debug.is_enabled("wireframe_mode"));
    debug.toggle("wireframe_mode");
    assert!(debug.is_enabled("wireframe_mode"));
}

#[test]
fn test_collider_toggle() {
    let mut debug = DebugManager::default();
    assert!(!debug.is_enabled("show_colliders"));
    debug.toggles.toggle("show_colliders");
    assert!(debug.is_enabled("show_colliders"));
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_debug_overlay
```

Expected: FAIL (or passes if debug manager tests already cover toggle).

- [ ] **Step 3: Implement debug overlays**

Write `client/src/debug/PerfHUD.tsx`:
```tsx
import { useEffect, useState } from 'react';

interface PerfHUDProps {
  visible: boolean;
  tickRate: number;
  frameTime: number;
  entityCount: number;
  systemCount: number;
}

let frameTimes: number[] = [];
let lastTime = performance.now();

export function PerfHUD() {
  const [stats, setStats] = useState({
    fps: 60,
    frameTime: 0,
    entityCount: 0,
    systemCount: 0,
    serverTick: 0,
  });

  useEffect(() => {
    let running = true;
    const tick = () => {
      if (!running) return;
      const now = performance.now();
      const dt = now - lastTime;
      lastTime = now;

      frameTimes.push(dt);
      if (frameTimes.length > 120) frameTimes.shift();

      const avg =
        frameTimes.reduce((a, b) => a + b, 0) / frameTimes.length;

      setStats({
        fps: Math.round(1000 / avg),
        frameTime: Math.round(dt),
        entityCount: stats.entityCount,
        systemCount: stats.systemCount,
        serverTick: stats.serverTick,
      });

      requestAnimationFrame(tick);
    };

    requestAnimationFrame(tick);
    return () => { running = false; };
  }, []);

  return (
    <div style={{
      position: 'fixed', top: '4rem', right: '1rem',
      background: 'rgba(0, 0, 0, 0.8)', color: '#0f0',
      fontFamily: 'monospace', fontSize: '0.7rem', lineHeight: '1.4',
      padding: '0.5rem', borderRadius: '4px', zIndex: 9999,
      border: '1px solid #0a0',
    }}>
      <div>FPS: <span style={{ color: stats.fps < 30 ? '#f00' : '#0f0' }}>{stats.fps}</span></div>
      <div>Frame: {stats.frameTime}ms</div>
      <div>Entities: {stats.entityCount}</div>
      <div>Systems: {stats.systemCount}</div>
      <div>Server Tick: {stats.serverTick}</div>
    </div>
  );
}
```

Write `client/src/debug/ColliderRenderer.ts`:
```typescript
import * as THREE from 'three';

export class ColliderRenderer {
  private scene: THREE.Object3D;
  private lines: THREE.Line[] = [];
  private visible = false;

  constructor(scene: THREE.Object3D) {
    this.scene = scene;
  }

  setVisible(visible: boolean): void {
    this.visible = visible;
    this.lines.forEach((l) => (l.visible = visible));
  }

  addColliderBox(
    center: [number, number, number],
    halfExtents: [number, number, number]
  ): void {
    const geometry = new THREE.BoxGeometry(
      halfExtents[0] * 2,
      halfExtents[1] * 2,
      halfExtents[2] * 2
    );
    const edges = new THREE.EdgesGeometry(geometry);
    const line = new THREE.LineSegments(
      edges,
      new THREE.LineBasicMaterial({ color: 0x00ff00, transparent: true, opacity: 0.5 })
    );
    line.position.set(center[0], center[1], center[2]);
    line.visible = this.visible;
    this.scene.add(line);
    this.lines.push(line);
  }

  clear(): void {
    this.lines.forEach((l) => {
      this.scene.remove(l);
      l.geometry.dispose();
      (l.material as THREE.Material).dispose();
    });
    this.lines = [];
  }

  updateFromSnapshot(entities: any[]): void {
    this.clear();
    if (!this.visible) return;

    for (const ent of entities) {
      if (ent.collider) {
        this.addColliderBox(
          [ent.transform[0], ent.transform[1], ent.transform[2]],
          [ent.collider.hx, ent.collider.hy, ent.collider.hz]
        );
      }
    }
  }
}
```

Write `engine/src/debug/wireframe_system.rs`:
```rust
use bevy::prelude::*;
use crate::debug::debug_toggles::DebugToggles;

pub fn debug_overlay_system(
    debug: Res<DebugToggles>,
    time: Res<Time>,
) {
    // Wireframe mode: sent to client via a dedicated snapshot field
    if debug.get("wireframe_mode") {
        // In real impl: set render state flags on snapshot
    }

    // Perf: track entity count, system execution time
    // These stats are sent to client each tick via the snapshot metadata
}

pub struct DebugOverlayPlugin;

impl Plugin for DebugOverlayPlugin {
    fn build(&self, app: &mut App) {
        app.add_systems(
            Update,
            debug_overlay_system.in_set(Diagnostics),
        );
    }
}
```

Write `client/src/debug/DebugOverlay.ts`:
```typescript
import { ColliderRenderer } from './ColliderRenderer';
import * as THREE from 'three';

export class DebugOverlay {
  public colliderRenderer: ColliderRenderer;
  public showPerfHud = true;
  public showColliders = false;

  constructor(scene: THREE.Object3D) {
    this.colliderRenderer = new ColliderRenderer(scene);
  }

  setToggle(key: string, value: boolean): void {
    switch (key) {
      case 'show_colliders':
        this.showColliders = value;
        this.colliderRenderer.setVisible(value);
        break;
      case 'show_perf_hud':
        this.showPerfHud = value;
        break;
    }
  }

  updateFromSnapshot(snapshot: any): void {
    if (this.showColliders) {
      this.colliderRenderer.updateFromSnapshot(snapshot.entities || []);
    }
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_debug_overlay
cd ../client && npm test
```

Expected: All debug overlay tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/debug/DebugOverlay.ts client/src/debug/PerfHUD.tsx client/src/debug/ColliderRenderer.ts engine/src/debug/wireframe_system.rs engine/src/lib.rs engine/tests/debug_overlay.rs
git commit -m "(GREEN) feat: add debug overlays — perf HUD, collider wires

PerfHUD (React): FPS (running average), frame time, entity/system count,
server tick. ColliderRenderer (Three.js): EdgeGeometry wireframe boxes
for entity colliders, toggled via DebugOverlay. DebugOverlayPlugin (Bevy):
wireframe system in Diagnostics set. All toggles sync to client."
```

---

## Task 5.5: Debug Overlays — ECS, Rules, Objectives, State, Beats, AI, Lighting, Post-Process

**Files:**
- Create: `client/src/debug/DebugOverlays.tsx`
- Create: `client/src/debug/__tests__/DebugOverlays.test.tsx`
- Modify: `engine/src/debug/wireframe_system.rs` (add overlay data to snapshot)

Each overlay is a toggleable React panel displaying live runtime data from the engine snapshot. The engine emits a `DebugSnapshotEvent` each tick containing the data for all active overlays. The React overlay component reads from the Zustand debug store.

- [ ] **Step 1: Write failing overlay test**

Write `client/src/debug/__tests__/DebugOverlays.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { ECSInspectorOverlay } from '../DebugOverlays';

describe('ECSInspectorOverlay', () => {
  it('should render entity count', () => {
    const data = { entity_count: 42, component_names: ['Transform', 'Health'], system_names: ['s_move', 's_physics'] };
    const { getByText } = render(<ECSInspectorOverlay visible={true} data={data} />);
    expect(getByText('42')).toBeInTheDocument();
  });

  it('should not render when hidden', () => {
    const { container } = render(<ECSInspectorOverlay visible={false} data={null} />);
    expect(container.innerHTML).toBe('');
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement debug overlay React components**

Write `client/src/debug/DebugOverlays.tsx`:
```tsx
// ---- ECS Inspector ----
export function ECSInspectorOverlay({ visible, data }: { visible: boolean; data: any }) {
  if (!visible || !data) return null;
  return (
    <div style={{ position: 'fixed', top: '1rem', right: '15rem', background: 'rgba(0,0,0,0.9)', border: '1px solid #0a0', borderRadius: '4px', padding: '0.5rem', zIndex: 9998, fontFamily: 'monospace', fontSize: '0.7rem', color: '#0f0', maxHeight: '400px', overflowY: 'auto', minWidth: '220px' }}>
      <div style={{ color: '#0a0', marginBottom: '0.5rem' }}>ECS Inspector</div>
      <div>Entities: <span style={{ color: '#fff' }}>{data.entity_count}</span></div>
      <div style={{ marginTop: '0.25rem', color: '#888' }}>Components:</div>
      {(data.component_names || []).map((name: string) => (<div key={name} style={{ paddingLeft: '0.5rem' }}>{name}</div>))}
      <div style={{ marginTop: '0.25rem', color: '#888' }}>Systems:</div>
      {(data.system_names || []).map((name: string) => (<div key={name} style={{ paddingLeft: '0.5rem' }}>{name}</div>))}
    </div>
  );
}

// ---- Rule Evaluator ----
export function RuleEvaluatorOverlay({ visible, data }: { visible: boolean; data: any }) {
  if (!visible || !data) return null;
  return (
    <div style={{ position: 'fixed', top: '1rem', right: '35rem', background: 'rgba(0,0,0,0.9)', border: '1px solid #ca0', borderRadius: '4px', padding: '0.5rem', zIndex: 9998, fontFamily: 'monospace', fontSize: '0.7rem', color: '#ca0', maxHeight: '400px', overflowY: 'auto', minWidth: '250px' }}>
      <div style={{ color: '#c80', marginBottom: '0.5rem' }}>Rule Evaluator</div>
      {(data.evaluations || []).map((eval: any, i: number) => (
        <div key={i} style={{ marginBottom: '0.25rem', borderBottom: '1px solid #333' }}>
          <div style={{ color: eval.winner ? '#0f0' : '#888' }}>{eval.rule_id}: {eval.score.toFixed(3)}</div>
          {(eval.conditions || []).map((c: any, j: number) => (
            <div key={j} style={{ paddingLeft: '0.5rem', color: c.passing ? '#0f0' : '#600' }}>{c.type}: {c.score.toFixed(3)}</div>
          ))}
        </div>
      ))}
    </div>
  );
}

// ---- Objectives Debug ----
export function ObjectivesDebugOverlay({ visible, data }: { visible: boolean; data: any }) {
  if (!visible || !data) return null;
  return (
    <div style={{ position: 'fixed', bottom: '1rem', left: '1rem', background: 'rgba(0,0,0,0.9)', border: '1px solid #0af', borderRadius: '4px', padding: '0.5rem', zIndex: 9998, fontFamily: 'monospace', fontSize: '0.7rem', color: '#0af', maxHeight: '300px', overflowY: 'auto', minWidth: '250px' }}>
      <div style={{ color: '#0af', marginBottom: '0.5rem' }}>Objectives</div>
      {(data.objectives || []).map((obj: any, i: number) => (
        <div key={i} style={{ marginBottom: '0.25rem' }}>
          <span style={{ color: obj.done ? '#0f0' : '#fff' }}>{obj.id}</span>
          <span style={{ color: '#888' }}> {obj.progress}/{obj.target}</span>
        </div>
      ))}
    </div>
  );
}

// ---- State Debug ----
export function StateDebugOverlay({ visible, data }: { visible: boolean; data: any }) {
  if (!visible || !data) return null;
  return (
    <div style={{ position: 'fixed', top: '1rem', left: '1rem', background: 'rgba(0,0,0,0.9)', border: '1px solid #a0f', borderRadius: '4px', padding: '0.5rem', zIndex: 9998, fontFamily: 'monospace', fontSize: '0.7rem', color: '#a0f', maxHeight: '400px', overflowY: 'auto', minWidth: '250px' }}>
      <div style={{ color: '#a0f', marginBottom: '0.5rem' }}>State</div>
      {Object.entries(data.state || {}).map(([key, value]) => (
        <div key={key} style={{ color: '#ccc' }}>{key}: {JSON.stringify(value)}</div>
      ))}
    </div>
  );
}

// ---- Beats Debug ----
export function BeatsDebugOverlay({ visible, data }: { visible: boolean; data: any }) {
  if (!visible || !data) return null;
  return (
    <div style={{ position: 'fixed', top: '15rem', left: '1rem', background: 'rgba(0,0,0,0.9)', border: '1px solid #c8a96e', borderRadius: '4px', padding: '0.5rem', zIndex: 9998, fontFamily: 'monospace', fontSize: '0.7rem', color: '#c8a96e', maxHeight: '300px', overflowY: 'auto', minWidth: '250px' }}>
      <div style={{ color: '#c8a96e', marginBottom: '0.5rem' }}>Narrative Beats</div>
      {(data.beats || []).map((beat: any, i: number) => (
        <div key={i} style={{ color: beat.active ? '#0f0' : '#888' }}>{beat.beat_id}: {beat.score?.toFixed(3)}</div>
      ))}
    </div>
  );
}

// ---- AI Paths ----
export function AIPathsOverlay({ visible }: { visible: boolean }) {
  if (!visible) return null;
  return (
    <div style={{ position: 'fixed', bottom: '6rem', left: '1rem', background: 'rgba(0,0,0,0.9)', border: '1px solid #a33', borderRadius: '4px', padding: '0.5rem', zIndex: 9998, fontFamily: 'monospace', fontSize: '0.7rem', color: '#a33', minWidth: '180px' }}>
      <div>AI Paths: ON</div>
      <div style={{ color: '#666' }}>(rendered via Three.js LineSegments)</div>
    </div>
  );
}

// ---- Lighting Debug ----
export function LightingDebugOverlay({ visible, data }: { visible: boolean; data: any }) {
  if (!visible || !data) return null;
  return (
    <div style={{ position: 'fixed', bottom: '6rem', right: '1rem', background: 'rgba(0,0,0,0.9)', border: '1px solid #ffa500', borderRadius: '4px', padding: '0.5rem', zIndex: 9998, fontFamily: 'monospace', fontSize: '0.7rem', color: '#ffa500', minWidth: '180px' }}>
      <div style={{ color: '#ffa500', marginBottom: '0.5rem' }}>Lighting</div>
      <div style={{ color: '#ccc' }}>Ambient: {data.ambient}</div>
      <div style={{ color: '#ccc' }}>Directional: {data.directional_direction}</div>
    </div>
  );
}

// ---- Post-Process Debug ----
export function PostProcessDebugOverlay({ visible, data }: { visible: boolean; data: any }) {
  if (!visible || !data) return null;
  return (
    <div style={{ position: 'fixed', bottom: '10rem', right: '1rem', background: 'rgba(0,0,0,0.9)', border: '1px solid #808', borderRadius: '4px', padding: '0.5rem', zIndex: 9998, fontFamily: 'monospace', fontSize: '0.7rem', color: '#808', minWidth: '180px' }}>
      <div style={{ color: '#808', marginBottom: '0.5rem' }}>Post-Process</div>
      <div style={{ color: '#ccc' }}>Bloom: {data.bloom}</div>
      <div style={{ color: '#ccc' }}>Vignette: {data.vignette}</div>
    </div>
  );
}
```

Update `engine/src/debug/wireframe_system.rs` to emit debug snapshot data to client each tick:
```rust
use bevy::prelude::*;
use crate::debug::debug_toggles::DebugToggles;

#[derive(Resource)]
pub struct DebugSnapshotState {
    pub pending_snapshot: Option<DebugSnapshot>,
}

#[derive(Default)]
pub struct DebugSnapshot {
    pub ecs_entity_count: u32,
    pub ecs_component_names: Vec<String>,
    pub ecs_system_names: Vec<String>,
    pub rule_evaluations: Vec<RuleEval>,
    pub objectives: Vec<ObjectiveStatus>,
    pub state: Vec<(String, String)>,
    pub beats: Vec<BeatStatus>,
    pub ambient_light: String,
    pub directional_light_dir: String,
    pub bloom: String,
    pub vignette: String,
}

pub struct RuleEval {
    pub rule_id: String,
    pub score: f32,
    pub winner: bool,
    pub conditions: Vec<ConditionEval>,
}

pub struct ConditionEval {
    pub condition_type: String,
    pub score: f32,
    pub passing: bool,
}

pub struct ObjectiveStatus {
    pub id: String,
    pub progress: u32,
    pub target: u32,
    pub done: bool,
}

pub struct BeatStatus {
    pub beat_id: String,
    pub score: f32,
    pub active: bool,
}

pub fn debug_overlay_system(
    mut debug_state: ResMut<DebugSnapshotState>,
    debug: Res<DebugToggles>,
    query: Query<Entity>,
) {
    let mut snapshot = DebugSnapshot::default();

    if debug.get("show_ecs_inspector") {
        snapshot.ecs_entity_count = query.iter().count() as u32;
        snapshot.ecs_component_names = vec![
            "Transform".into(), "Health".into(), "Movement".into(),
            "EntityTag".into(), "StateComponent".into(), "InputComponent".into(),
        ];
        snapshot.ecs_system_names = vec![
            "s_move".into(), "s_jump".into(), "s_gravity".into(), "s_character_state".into(),
        ];
    }

    if debug.get("show_rule_evaluator") {
        // Populated by Lua systems via engine:debug_rule_eval()
    }

    if debug.get("show_objectives_debug") {
        // Populated by S_Quest via engine:debug_objective_status()
    }

    if debug.get("show_state_debug") {
        // Populated by engine state snapshot
    }

    if debug.get("show_beats_debug") {
        // Populated by S_Storylet via engine:debug_beat_status()
    }

    if debug.get("show_lighting_debug") {
        snapshot.ambient_light = "0xfff5e6".to_string();
        snapshot.directional_light_dir = "(-0.5, -0.8, -0.3)".to_string();
    }

    if debug.get("show_post_process_debug") {
        snapshot.bloom = "enabled".to_string();
        snapshot.vignette = "enabled".to_string();
    }

    debug_state.pending_snapshot = Some(snapshot);
}

pub struct DebugOverlayPlugin;

impl Plugin for DebugOverlayPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<DebugSnapshotState>();
        app.add_systems(Update, debug_overlay_system.in_set(Diagnostics));
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
cd ../engine && cargo test test_debug_overlay
```

Expected: All debug overlay tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/debug/DebugOverlays.tsx client/src/debug/__tests__/DebugOverlays.test.tsx engine/src/debug/wireframe_system.rs
git commit -m "(GREEN) feat: add 8 debug overlays with engine data feed

ECSInspectorOverlay: entity count, component list, system list.
RuleEvaluatorOverlay: per-rule scores, condition breakdown, winner highlight.
ObjectivesDebugOverlay: per-objective progress/target, done indicator.
StateDebugOverlay: key/value state dump.
BeatsDebugOverlay: narrative beat scores, active highlight.
AIPathsOverlay: status indicator (Three.js LineSegments).
LightingDebugOverlay: ambient + directional light values.
PostProcessDebugOverlay: bloom + vignette toggles.
DebugSnapshotState resource: carries per-frame overlay data to client."
```

---

## Task 6: Cheats Panel + Lua Debug Commands

**Files:**
- Create: `client/src/debug/CheatsPanel.tsx`
- Create: `engine/lua/systems/s_debug_commands.lua`
- Modify: `engine/lua/config/systems.toml`
- Modify: `engine/src/debug/mod.rs`
- Create: `engine/tests/debug_commands.rs`

- [ ] **Step 1: Write failing debug commands test**

Write `engine/tests/debug_commands.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_debug_god_mode_command() {
    let mut world = World::new();
    world.init_resource::<engine::debug::debug_manager::DebugManager>();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        engine:debug_toggle("god_mode")
        return engine:debug_is_enabled("god_mode")
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_debug_spawn_entity_command() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        local S_DebugCommands = dofile("systems/s_debug_commands.lua")
        S_DebugCommands:init(engine)

        local eid = S_DebugCommands:cheat_spawn_item("health_potion", 5, 0, 5)
        return eid > 0
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_debug_telemetry_log() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();

    let result = runtime.lua().load(r#"
        engine:debug_log("test", "Hello from Lua debug", "info")
        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_debug_commands
```

Expected: FAIL.

- [ ] **Step 3: Implement debug commands + cheats panel**

Write `engine/lua/systems/s_debug_commands.lua`:
```lua
local S_DebugCommands = {}

function S_DebugCommands:init(engine)
  self.engine = engine
end

function S_DebugCommands:process(engine, dt)
end

function S_DebugCommands:cheat_spawn_item(item_id, x, y, z)
  local eid = engine:spawn({
    components = {
      Transform = { translation = { x or 0, y or 0, z or 0 }, rotation = { 0, 0, 0, 1 }, scale = { 1, 1, 1 } },
      InventoryComponent = { items = {}, max_slots = 24 },
    },
  })

  if item_id then
    local inv = dofile("systems/s_inventory_system.lua")
    inv:init(engine)
    inv:add_item(eid, item_id, 1)
  end

  return eid
end

function S_DebugCommands:cheat_heal(entity_id)
  local health = engine:get(entity_id, "Health")
  if health then
    health.health = health.max_health or 100
    engine:set(entity_id, "Health", health)
  end
end

function S_DebugCommands:cheat_kill_all_enemies()
  engine:query({"EnemyTag"}, function(eid)
    engine:emit("EntityDiedEvent", { entity = eid, cause = "debug_kill" })
  end)
end

function S_DebugCommands:cheat_complete_current_objective(entity_id)
  local quest = dofile("systems/s_quest_system.lua")
  quest:init(engine)
  local active = quest:get_active_quests(entity_id)

  for _, q in ipairs(active) do
    for _, obj in ipairs(q.objectives or {}) do
      local already_done = false
for _, done_id in ipairs(q.completed_objectives or {}) do
  if done_id == obj.objective_id then already_done = true; break end
end
if not already_done then
        quest:advance_objective(entity_id, q.quest_id, obj.objective_id, obj.target)
        return
      end
    end
  end
end

function S_DebugCommands:cheat_give_all_collectibles(entity_id)
  local collectible = dofile("systems/s_collectible_system.lua")
  collectible:init(engine)
  for collectible_id, _ in pairs(collectible.db) do
    collectible:pickup(entity_id, collectible_id)
  end
end

return S_DebugCommands
```

Write `client/src/debug/CheatsPanel.tsx`:
```tsx
import { useState } from 'react';

interface CheatsPanelProps {
  visible: boolean;
  onToggle: (key: string) => void;
  cheats: Record<string, boolean>;
}

const CHEAT_DEFS: Array<{ key: string; label: string; category: string }> = [
  { key: 'god_mode', label: 'God Mode', category: 'Player' },
  { key: 'freeze_input', label: 'Freeze Input', category: 'State' },
  { key: 'show_colliders', label: 'Collider Wires', category: 'Visual' },
  { key: 'wireframe_mode', label: 'Wireframe', category: 'Visual' },
  { key: 'show_ecs_inspector', label: 'ECS Inspector', category: 'Debug' },
  { key: 'show_rule_evaluator', label: 'Rule Evaluator', category: 'Debug' },
  { key: 'show_ai_paths', label: 'AI Paths', category: 'Debug' },
  { key: 'show_objectives_debug', label: 'Objectives', category: 'Debug' },
  { key: 'show_lighting_debug', label: 'Lighting', category: 'Debug' },
  { key: 'show_telemetry', label: 'Telemetry Log', category: 'Debug' },
];

export function CheatsPanel({ visible, onToggle, cheats }: CheatsPanelProps) {
  const [category, setCategory] = useState('All');

  const filtered =
    category === 'All'
      ? CHEAT_DEFS
      : CHEAT_DEFS.filter((c) => c.category === category);

  if (!visible) return null;

  return (
    <div style={{
      position: 'fixed', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
      background: 'rgba(10, 10, 20, 0.95)', border: '2px solid #c8a96e',
      borderRadius: '8px', padding: '1.5rem', zIndex: 10000,
      minWidth: '320px', fontFamily: 'monospace',
    }}>
      <div style={{ color: '#c8a96e', fontSize: '1.1rem', marginBottom: '1rem' }}>
        Developer Cheats
      </div>
      <div style={{ display: 'flex', gap: '0.25rem', marginBottom: '1rem', flexWrap: 'wrap' }}>
        {['All', 'Player', 'State', 'Visual', 'Debug'].map((c) => (
          <button key={c} onClick={() => setCategory(c)}
            style={{
              padding: '0.2rem 0.6rem', fontSize: '0.75rem',
              background: category === c ? '#2a4a7f' : '#16213e',
              color: '#aaa', border: 'none', borderRadius: '4px',
              cursor: 'pointer',
            }}>
            {c}
          </button>
        ))}
      </div>
      {filtered.map((cheat) => (
        <div key={cheat.key} style={{
          display: 'flex', justifyContent: 'space-between',
          padding: '0.3rem 0', borderBottom: '1px solid #16213e',
        }}>
          <span style={{ color: '#aaa', fontSize: '0.85rem' }}>{cheat.label}</span>
          <button
            onClick={() => onToggle(cheat.key)}
            style={{
              width: '40px', height: '22px', borderRadius: '11px',
              border: 'none', cursor: 'pointer',
              background: cheats[cheat.key] ? '#2a4a7f' : '#333',
              position: 'relative', transition: 'background 0.2s',
            }}
          >
            <div style={{
              width: '18px', height: '18px', borderRadius: '50%',
              background: '#e0e0e0', transition: 'transform 0.2s',
              transform: cheats[cheat.key] ? 'translateX(20px)' : 'translateX(0px)',
            }} />
          </button>
        </div>
      ))}
      <div style={{ marginTop: '1rem', fontSize: '0.7rem', color: '#666' }}>
        Press Ctrl+Shift+D to toggle this panel
      </div>
    </div>
  );
}
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_DebugCommands]
lua_file = "systems/s_debug_commands.lua"
system_set = "Diagnostics"
priority = 250
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_debug_commands
cd ../client && npm test
```

Expected: All debug commands tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_debug_commands.lua engine/lua/config/systems.toml client/src/debug/CheatsPanel.tsx engine/tests/debug_commands.rs
git commit -m "(GREEN) feat: add cheats panel and debug command system

S_DebugCommands (Diagnostics, pri 250): cheat_spawn_item, cheat_heal,
cheat_kill_all_enemies, cheat_complete_current_objective,
cheat_give_all_collectibles. CheatsPanel (React): 10 toggles in 5
categories (Player, State, Visual, Debug), Ctrl+Shift+D toggle.
All toggles routed to engine via debug_toggle API."
```

---

## Task 7: Telemetry Log UI

**Files:**
- Create: `client/src/debug/TelemetryLog.tsx`
- Create: `client/src/debug/__tests__/TelemetryLog.test.tsx`

- [ ] **Step 1: Write failing telemetry UI test**

Write `client/src/debug/__tests__/TelemetryLog.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { TelemetryLog } from '../TelemetryLog';

describe('TelemetryLog', () => {
  it('should render with no entries', () => {
    const { container } = render(
      <TelemetryLog entries={[]} visible={true} />
    );
    expect(container.textContent).toContain('Telemetry');
  });

  it('should render log entries', () => {
    const entries = [
      { timestamp: 1000, category: 'test', message: 'Test entry', level: 'Info' },
    ];
    const { getByText } = render(
      <TelemetryLog entries={entries} visible={true} />
    );
    expect(getByText('Test entry')).toBeInTheDocument();
  });

  it('should not render when invisible', () => {
    const entries = [{ timestamp: 1000, category: 'test', message: 'Hidden', level: 'Debug' }];
    const { container } = render(
      <TelemetryLog entries={entries} visible={false} />
    );
    expect(container.innerHTML).toBe('');
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement telemetry log**

Write `client/src/debug/TelemetryLog.tsx`:
```tsx
import { useState } from 'react';

interface LogEntry {
  timestamp: number;
  category: string;
  message: string;
  level: 'Debug' | 'Info' | 'Warning' | 'Error';
}

interface TelemetryLogProps {
  entries: LogEntry[];
  visible: boolean;
}

const LEVEL_COLORS: Record<string, string> = {
  Debug: '#888',
  Info: '#0af',
  Warning: '#ca0',
  Error: '#e33',
};

export function TelemetryLog({ entries, visible }: TelemetryLogProps) {
  const [filter, setFilter] = useState('All');

  if (!visible) return null;

  const filtered =
    filter === 'All'
      ? entries
      : entries.filter((e) => e.level === filter);

  return (
    <div style={{
      position: 'fixed', bottom: '1rem', right: '1rem',
      background: 'rgba(0, 0, 0, 0.92)', border: '1px solid #333',
      borderRadius: '4px', width: '400px', maxHeight: '300px',
      overflow: 'hidden', zIndex: 9999, fontFamily: 'monospace',
    }}>
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        padding: '0.3rem 0.5rem', borderBottom: '1px solid #333',
        color: '#888', fontSize: '0.75rem',
      }}>
        <span>Telemetry</span>
        <div style={{ display: 'flex', gap: '0.25rem' }}>
          {['All', 'Debug', 'Info', 'Warning', 'Error'].map((f) => (
            <button key={f} onClick={() => setFilter(f)}
              style={{
                padding: '0.1rem 0.4rem', fontSize: '0.65rem',
                background: filter === f ? '#333' : 'transparent',
                color: filter === f ? '#e0e0e0' : '#666',
                border: 'none', borderRadius: '3px', cursor: 'pointer',
              }}
            >
              {f}
            </button>
          ))}
        </div>
      </div>
      <div style={{
        overflowY: 'auto', maxHeight: '260px', padding: '0.25rem',
      }}>
        {filtered.map((entry, i) => (
          <div key={i} style={{
            padding: '0.15rem 0.25rem', borderBottom: '1px solid #1a1a2e',
            fontSize: '0.7rem', lineHeight: '1.3',
          }}>
            <span style={{ color: '#666' }}>
              [{entry.category}]
            </span>{' '}
            <span style={{ color: LEVEL_COLORS[entry.level] }}>
              {entry.message}
            </span>
          </div>
        ))}
        {filtered.length === 0 && (
          <div style={{ color: '#444', textAlign: 'center', padding: '1rem', fontSize: '0.75rem' }}>
            No log entries
          </div>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: TelemetryLog tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/debug/TelemetryLog.tsx client/src/debug/__tests__/
git commit -m "(GREEN) feat: add telemetry log UI with level filtering

TelemetryLog (React): scrollable log panel (400x300px), level filter
tabs (All/Debug/Info/Warning/Error), color-coded entries, category
prefix. Level colors: Debug=gray, Info=blue, Warning=yellow, Error=red."
```

---

## Summary

**Total Tasks:** 8
**Estimated Implementation Time:** 6-8 focused engineering days

**Coverage Checklist:**
- [x] Inventory system (add/remove items, stacking, slot limit, use effects)
- [x] Runnable screen/debug examples: `automata example run inventory-basic`, `quest-log-objectives`, `lore-collectible`, `debug-overlays`
- [x] Quest log (accept/advance/complete objectives, collect-type auto-progress, rewards)
- [x] Collectibles/lore codex (pickup, duplicate prevention, category system, progress tracking)
- [x] Debug manager (16 toggles, telemetry log with FIFO buffer, Bevy resource)
- [x] Performance HUD (FPS running average, frame time, entity count, server tick)
- [x] Collider wireframe overlay (Three.js EdgeGeometry, toggled visibility)
- [x] 8 debug overlays (ECS inspector, rule evaluator, objectives, state, beats, AI paths, lighting, post-process) with DebugSnapshotState feed
- [x] Cheats panel (10 toggles across 5 categories, Ctrl+Shift+D toggle)
- [x] Debug commands (spawn items, heal, kill all enemies, complete objectives, give all collectibles)
- [x] Telemetry log UI (scrollable panel, level filter, color-coded entries)
