# Automata Engine

### TL;DR

Automata Engine is a mobile-first, browser and desktop-compatible 2.5D (sprite-in-3D) Western RPG game engine designed for solo developers and small teams. It is open source, AI-first, and enables fast, modular development of games that blend real-time MOBA combat, deep narrative, and seamless cross-platform play. The engine is tailored for games with a look akin to Xenogears but combat inspired by League of Legends/Wild Rift, with modular builder tools and a focus on extensibility, debugability, and content-driven pipelines.

---

## Goals

### Business Goals

* Enable rapid creation of fully functional Western RPGs with MOBA-style combat for solo devs and small teams.
* Achieve full cross-platform compatibility (mobile, browser, desktop) using a single codebase and predictable JSON/Lua workflows.
* Foster an ecosystem of extendable, mod-friendly, and AI-authorable games/tools via open source licensing.
* Support automated and AI-driven testing, debugging, and iterative workflow to minimize manual regression.
* Ensure every deliverable is accessible, well-documented, and has at least one minimal working example.

### User Goals

* Build, play, and share visually distinct 2.5D RPGs and action games with minimal barrier to entry.
* Hot-reload game logic, assets, or content and receive clear, actionable errors.
* Leverage builder tools and extensive debug/QA overlays to speed iteration and experimentation.
* Extend and mod games safely through data, not code, with no risk to engine stability.
* Develop games that run smoothly on mobile devices, in browsers, and on desktop with consistent quality.

### Non-Goals

* Support for AAA-scale production values, asset pipelines, or highly complex 3D rendering/shader effects.
* Real-time code modding or plugin/script injection at runtime (modding is data/content only).
* Server orchestration, NAT traversal, or built-in matchmaking beyond cloud hosting basics.

---

## User Stories

* As a solo developer, I want to quickly assemble a working RPG in a week, so that I can validate my game idea with minimal code.
* As an AI builder, I want to create and edit JSON/Lua content and verify engine acceptance/errors in CLI/headless mode, so that I can automate playtests and QA.
* As a player, I want a game that runs consistently on my phone and laptop without downloads or configuration.
* As a modder, I want to add items and new quests via data files and see instant results, so that I can experiment without breaking the core game.
* As a technical writer or content creator, I want schema documentation and minimal working examples so that I can learn the pipeline quickly.

---

## Functional Requirements

* Core Gameplay Loop (Priority: Highest)
  * Real-time "MOBA-like" movement, ability cooldowns, and interactive combat systems.
  * Quality-based state machines for narrative, AI, and progression (scored rule engine).
  * Full 3D world (locked vertical camera, 8-directional sprite billboarding, WASD/gamepad/touch input).
  * AI-first pipeline: step/run headless, output snapshots, and surface actionable errors to CLI.
* Content & Builder Integration (Priority: High)
  * Modular builder tools (Level/Narrative/Cutscene/AI/Character/UI); output JSON or Lua, strictly schema-validated at load time.
  * Minimal mod manager: boot-time directory mounting, self-contained content folders.
  * Schema versioning and clear fail-fast on load mismatch, with error logs for human/AI/CI.
* Multiplayer & Networking (Priority: High)
  * Synchronous real-time multiplayer, client-server, up to 32 concurrent players; cloud-first server design.
  * Thin client model (no prediction), all game-affecting actions validated on server.
* Debug, Telemetry, and Playtesting (Priority: High)
  * In-game debug overlay (cheats, perf HUD, ECS inspector, state, AI tracing, objectives, lighting, VFX).
  * Structured telemetry/log output: crash logs, CLI errors, automated regression output.
  * Automated test runner: load scenes, step simulation, check assertions, dump pass/fail.
* UI & Accessibility (Priority: High)
  * PWA-ready, responsive design, strict mobile-first layout.
  * Full accessibility: keyboard/gamepad/touch, color contrast, ARIA tags, scalable fonts, basic screen reader support.
* Performance, Save/Load, & Examples (Priority: High)
  * Minimum spec: 30fps floor, VFX and animation auto-throttle if needed on low-end devices.
  * Local save/load support, static; cloud/game-managed save deferred for now, but engine is pluggable.
  * Engine ships with a minimal, documented example game; example tests must pass for every engine/build release.
  * Every completed engine feature ships a raylib-style runnable example package that can be listed, run, tested, and snapshotted from the CLI.

## Runnable Examples Contract

Automata examples are first-class content packages, not ad hoc snippets. Each package is a self-contained folder under `examples/<example_id>/` with metadata, JSON/Lua config, optional assets, optional README, and deterministic pass/fail assertions. Examples are grouped by feature so a developer can learn the engine incrementally, similar to raylib's small runnable examples.

**Package layout:**

```text
examples/<example_id>/
  example.json
  config/
  lua/
  assets/        # optional
  README.md      # optional
```

**Required metadata in `example.json`:**

- `id`, `title`, `feature`, `milestone`, and `entry_room`
- `systems`: enabled systems required by the example
- `expected_events`: events that prove the feature ran
- `success_assertions`: headless checks used by `automata example test`

**Unified CLI:**

```bash
automata example list
automata example run movement-basic
automata example test movement-basic
automata example snapshot movement-basic --ticks 120
```

The CLI discovers packages from `examples/`, validates metadata and schemas before boot, runs examples through the same engine path used by the game, and fails fast with structured errors when a package is incomplete.

---

## User Experience

**Entry Point & First-Time User Experience**

* Users access via browser/mobile or download desktop PWA/standalone (Tauri/desktop shell).
* Opening the engine for the first time prompts a project picker (example, new project, or import mod/content pack).
* Fast onboarding with an interactive tutorial and guided CLI tools for build, playtest, and debug workflows.
* Runnable examples are a separate first-run path from new projects and imported content packs.

**Core Experience**

* Step 1: Project selection or new game creation via builder suite.
  * Builder tools generate JSON/Lua cases, validated immediately. Errors shown in both GUI and log.
* Step 2: Content import (level, entities, AI, quests, dialogue), with hot reload or restart as needed.
  * Clear version/schema checks, auto-documentation, and intro example templates.
* Step 3: Live play/test, either in graphical mode or CLI-driven/automated mode.
  * Entities, systems, and combat run in real time; full debug overlays and event logs are available.
* Step 4: Save, export, and optionally mod or extend game. Mod manager allows additional content directories at boot.
* Step 5: Deploy (host) in browser, PWA, or desktop (Tauri/other shell); multiplayer games are launched by pointing clients at hosted server (cloud, not LAN).

**Advanced Features & Edge Cases**

* Power users and AI can invoke CLI mode: load any project, run N ticks headless, verify assertions, dump logs, and auto-compare to baseline for regression.
* Power users and AI can invoke example mode: run one feature package, all packages for a milestone, or the full example suite in CI.
* Schema version mismatches, corrupted assets, or unreachable builder content fail-fast and emit structured error logs.
* Multiplayer sessions exceeding player count or running in low-RAM environments degrade gracefully or signal clear errors.
* Mod manager strictly prevents script/runtime injection—only data content is supported for mods.

**UI/UX Highlights**

* Responsive, mobile-first design; PWA and native-feel input on all platforms.
* High-contrast themes, scalable sprites/fonts, ARIA roles, and screen reader cues for all core screens.
* Minimal, actionable error reporting and debug overlays for every major function (ECS, VFX, networking, etc.).
* Consistent onboarding experience—interactive example game is always available.

---

## Narrative

Imagine a solo developer with a vision for a modern Western RPG—blending a nostalgic 2.5D look with fast, action-oriented combat and deep branching storylines. In most engines, crafting such games demands wrestling with tools built for other genres, complex pipelines, or large teams. With Automata Engine, this developer spins up a new project, assembles maps and quests in the content builders, and fine-tunes the combat using instant, hot-reloadable logic—all while playtesting on a phone, a browser, and a desktop. When a tweak fails, actionable errors and a robust debug overlay point to what broke. Multiplayer and mod support are just a config away, letting friends and testers join instantly. As the project evolves, regression, performance, and accessibility are never afterthoughts: every build auto-tests baseline playability and clarity for players regardless of device. The result is a game that looks polished, runs anywhere, and maintains the creative control and speed that modern solo developers need.

---

## Success Metrics

### User-Centric Metrics

* Number of solo devs/small teams that create and ship a full playable demo with engine-provided examples.
* User satisfaction: First-run and playtest users rate onboarding/tutorial clarity ≥90% positive.
* Number of successful hot-reload/error-free content builder runs.
* Accessibility: All UI tested passes mobile and desktop WCAG AA checks.

### Business Metrics

* Open source repo stars, forks, and unique downloads/installations.
* Ratio of mods/extensions created by users outside original author.
* External games or products shipped using Automata Engine.

### Technical Metrics

* Engine performance: 30fps@200 sprites on mid-tier mobile browsers; degradation/fallback rates logged.
* Automated regression test pass-rate (scenes, combat, and narrative pipelines).
* Multiplayer sessions: number of unique 32-player games running in a given week/month.
* Mean time to actionable error: time from content/builder failure, crash, or bug to surfacing clear logged error.

### Tracking Plan

* Track project creation, builder tool launches, schema validation errors, hot reloads.
* Track number of times example or baseline games used for either play or automated test.
* Collect anonymized, opt-in usage stats for error rates/skipped frames/assertion failures.
* Telemetry on mod loading, multiplayer session start/failure, and CLI/automated test invocations.
* Accessibility checks and UI event metrics for mobile and desktop usage.

---

## Technical Considerations

### Technical Needs

* Modular engine core (Rust/Bevy) with Lua scripting layer for gameplay logic; TypeScript+Three.js for renderer, React+Zustand for UI.
* Builder tools (web/PWA) with strict schema for output; engine auto-validates and logs errors.
* Client-server networking (WebSocket transport); no LAN/P2P/matchmaking beyond address config.
* Thin client (browser/mobile/desktop): no client-side ECS, physics, or predictors; snapshot interpolation only.
* Automated CLI runner for content validation, regression, and AI-driven scripting/testing.

### Integration Points

* Open APIs for builder tools (content, dialogue, narrative, cutscenes, AI scripts, UI, animation).
* Minimal mod manager: mount content folders at boot; no dynamic runtime mods.
* Plug-in hooks for cloud save (file-based for now), analytics (deferred unless user extends).

### Data Storage & Privacy

* Local filesystem or browser storage for saves; all user data portable and deletable.
* No built-in analytics, telemetry is opt-in and anonymized.
* No personal data required; multiplayer session/server config is explicit per deploy.

### Scalability & Performance

* Designed for cloud-hosted multiplayer servers, up to 32 simultaneous players per session.
* Minimal memory/CPU footprint: degrade/fallback on low-end hardware, log warnings.
* Hot-reload of content and assets (JSON/Lua); engine restarts for structural or version schema changes.

### Potential Challenges

* Complexity of schema and mod management could raise onboarding curve; mitigated by robust tutorial/docs.
* Accessibility and minimum performance guarantees may require additional QA tooling as mobile devices/standards evolve.
* Security: Strictly limit mod/plugin execution to data to prevent scripting exploits.
* Multiplayer scalability/routing (matchmaking, NAT traversal) is out of scope for MVP; deferred as ecosystem grows.

---

## Milestones & Sequencing

### Project Estimate

* Medium: 2–4 weeks for baseline MVP, with full core gameplay, builder suite integration, baseline automation/regression, debug overlays, and first playable demo.

### Team Size & Composition

* Extra-small: 1 person (full stack dev, builder, content/UX, and docs).

### Suggested Phases

**Phase 1: Engine Core & Pipeline Foundation (1 week)**

* Deliverables: Rust+Lua engine core, headless CLI, web-based builder scaffolds, strict schema/checks, automated scenario runner.
* Dependencies: Bevy, mlua, TypeScript+Three.js, React, Vite, Tauri.

**Phase 2: Gameplay, UI & Debug Loops (5–7 days)**

* Deliverables: All core gameplay systems, input capture (touch/pad/keyboard), MOBA combat, narrative logic, quality rule systems, debug overlays, baseline automated tests.
* Dependencies: Phase 1 deliverables; builder tool sample outputs.

**Phase 3: Multiplayer, Mod, and Deployment (3–5 days)**

* Deliverables: Cloud server config, client-server sync, up to 32-player sessions, minimal mod manager, PWA/desktop packaging, onboarding flow, structured docs/example game, accessibility checks.
* Dependencies: Phase 2, server infra/cloud deploy scripts.

**Phase 4: Polish, QA, and Documentation (2–3 days)**

* Deliverables: Full example project, schema and content migration support, regression/pass/fail assertions, accessibility polish, beginner and builder docs, "failure to working game" onboarding flow.
* Dependencies: All previous phases.
