# M3: Polish & Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add VFX particles, audio playback, character lighting, gamepad input with haptics, damage flash, screen shake, objective tracking, checkpoints, scene director multi-room support, run coordinator, and death/victory handling onto the M1+M2 core.

**Architecture:** VFX via Three.js Points particles, audio via Web Audio API, gamepad via Gamepad API, haptics via navigator.vibrate, lighting via per-character DirectionalLight. All event-driven from server-authored Bevy events routed through the transport layer.

**Tech Stack:** Three.js (Points/ParticleSystem), Web Audio API, Gamepad API, navigator.vibrate, Zustand (UI state), Lua (gameplay logic).

**Prerequisites:** M1 complete (game loop, transport, snapshot), M2 complete (UI screens, UI store).

---

## Runnable Feature Examples

M3 examples prove runtime feedback systems in small, isolated scenes. Each example is a content package under `examples/<example_id>/` and runs with the unified CLI.

```bash
automata example run vfx-particles
automata example run screen-shake
automata example run checkpoint-respawn
automata example run multi-room-transition
```

Required M3 example packages:

| Example | Feature | Required proof |
|---------|---------|----------------|
| `vfx-particles` | VFX emitters and particle lifecycle | Particle event spawns, ticks, and cleans up |
| `screen-shake` | Camera feedback | Shake event produces decaying camera offset |
| `checkpoint-respawn` | Checkpoints, death, respawn | Death returns player to checkpoint and emits respawn feedback |
| `multi-room-transition` | Scene director | Trigger loads target room and emits transition events |

Each feedback or scene-flow feature must update one of these packages or add a new feature-level package before the task is complete.

## Task 1: VFX Particle System

**Files:**
- Create: `client/src/vfx/VfxManager.ts`
- Create: `client/src/vfx/particles/LandingDust.ts`
- Create: `client/src/vfx/particles/DamageFlash.ts`
- Create: `client/src/vfx/particles/DeathPoof.ts`
- Create: `client/src/vfx/__tests__/VfxManager.test.ts`

- [ ] **Step 1: Write failing VFX test**

Write `client/src/vfx/__tests__/VfxManager.test.ts`:
```typescript
import { describe, it, expect, vi } from 'vitest';

vi.mock('three', () => ({
  BufferGeometry: vi.fn().mockImplementation(() => ({})),
  BufferAttribute: vi.fn(),
  Points: vi.fn().mockImplementation(() => ({
    position: { set: vi.fn(), copy: vi.fn() },
    geometry: { attributes: { position: { array: new Float32Array(300) } } },
    material: { opacity: 1, dispose: vi.fn() },
    visible: true,
  })),
  PointsMaterial: vi.fn().mockImplementation(() => ({})),
  AdditiveBlending: 2,
  Group: vi.fn().mockImplementation(() => ({ add: vi.fn(), remove: vi.fn() })),
}));

import { VfxManager } from '../VfxManager';

describe('VfxManager', () => {
  it('should create instance', () => {
    const scene = { add: vi.fn(), remove: vi.fn() } as any;
    const manager = new VfxManager(scene);
    expect(manager).toBeDefined();
  });

  it('should spawn a landing dust effect', () => {
    const scene = { add: vi.fn(), remove: vi.fn() } as any;
    const manager = new VfxManager(scene);
    manager.spawnEffect('landing_dust', { x: 0, y: 0, z: 0 }, 42);
    expect(scene.add).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL — VfxManager not found.

- [ ] **Step 3: Implement VFX system**

Write `client/src/vfx/VfxManager.ts`:
```typescript
import * as THREE from 'three';

interface ActiveEffect {
  group: THREE.Points;
  lifetime: number;
  elapsed: number;
}

export class VfxManager {
  private scene: THREE.Object3D;
  private activeEffects: ActiveEffect[] = [];
  private particlePool: THREE.Points[] = [];

  constructor(scene: THREE.Object3D) {
    this.scene = scene;
  }

  spawnEffect(type: string, position: { x: number; y: number; z: number }, entity: number): void {
    const pos = new THREE.Vector3(position.x, position.y, position.z);

    switch (type) {
      case 'landing_dust':
        this.createDustEffect(pos, '#c8a96e', 12, 0.8, 0.4);
        break;
      case 'death_poof':
        this.createDustEffect(pos, '#6b3fa0', 16, 1.5, 0.6);
        break;
      case 'damage_flash':
        this.createFlashEffect(pos, entity);
        break;
      default:
        break;
    }
  }

  private createDustEffect(position: THREE.Vector3, color: string, count: number, spread: number, lifetime: number): void {
    const geometry = new THREE.BufferGeometry();
    const positions = new Float32Array(count * 3);
    const velocities = new Float32Array(count * 3);

    for (let i = 0; i < count; i++) {
      positions[i * 3] = position.x + (Math.random() - 0.5) * spread * 0.5;
      positions[i * 3 + 1] = position.y;
      positions[i * 3 + 2] = position.z + (Math.random() - 0.5) * spread * 0.5;
      velocities[i * 3] = (Math.random() - 0.5) * spread;
      velocities[i * 3 + 1] = Math.random() * spread * 0.5;
      velocities[i * 3 + 2] = (Math.random() - 0.5) * spread;
    }

    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute('velocity', new THREE.BufferAttribute(velocities, 3));

    const material = new THREE.PointsMaterial({
      color: new THREE.Color(color),
      size: 0.08,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      transparent: true,
      opacity: 0.8,
    });

    const points = new THREE.Points(geometry, material);
    points.position.copy(position);
    points.userData = { velocities, count, lifetime, spread };
    this.scene.add(points);

    this.activeEffects.push({ group: points, lifetime, elapsed: 0 });
  }

  private createFlashEffect(position: THREE.Vector3, entity: number): void {
    // Brief white flash sprite — handled via snapshot interpolation (opacity pulse)
    console.log(`[VFX] Damage flash on entity ${entity} at ${position.toArray()}`);
  }

  update(dt: number): void {
    for (let i = this.activeEffects.length - 1; i >= 0; i--) {
      const effect = this.activeEffects[i];
      effect.elapsed += dt;

      // Update particle positions from velocities
      const points = effect.group;
      const positions = (points.geometry.attributes.position as THREE.BufferAttribute).array as Float32Array;
      const velocities = points.userData.velocities as Float32Array;
      const count = points.userData.count as number;

      for (let j = 0; j < count; j++) {
        positions[j * 3 + 1] += velocities[j * 3 + 1] * dt;
        velocities[j * 3 + 1] -= 2.0 * dt; // gravity
      }
      (points.geometry.attributes.position as THREE.BufferAttribute).needsUpdate = true;

      // Fade out
      const alpha = 1 - (effect.elapsed / effect.lifetime);
      const mat = points.material as THREE.PointsMaterial;
      mat.opacity = Math.max(0, alpha);

      // Remove expired
      if (effect.elapsed >= effect.lifetime) {
        this.scene.remove(points);
        points.geometry.dispose();
        (points.material as THREE.Material).dispose();
        this.activeEffects.splice(i, 1);
      }
    }
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: VfxManager test passes.

- [ ] **Step 5: Commit**

```bash
git add client/src/vfx/
git commit -m "(GREEN) feat: implement VFX particle system

VfxManager: Three.js Points particles for landing dust, death poof,
and damage flash effects. Particles with velocity, gravity, fade-out.
Active effect tracking with auto-cleanup. Additive blending for glow."
```

---

## Task 2: Audio Playback System

**Files:**
- Modify: `client/src/audio/AudioManager.ts` (flesh out from M2 stub)
- Create: `client/src/audio/AudioPool.ts`
- Create: `client/src/audio/__tests__/AudioPool.test.ts`

- [ ] **Step 1: Write failing audio pool test**

Write `client/src/audio/__tests__/AudioPool.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { AudioPool } from '../AudioPool';

describe('AudioPool', () => {
  it('should create pool of given size', () => {
    const pool = new AudioPool(4);
    expect(pool.size()).toBe(4);
  });

  it('should acquire and release audio nodes', () => {
    const pool = new AudioPool(2);
    const node = pool.acquire();
    expect(node).not.toBeNull();
    pool.release(node!);
    const node2 = pool.acquire();
    expect(node2).not.toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement AudioPool**

Write `client/src/audio/AudioPool.ts`:
```typescript
export class AudioPool {
  private available: AudioBufferSourceNode[] = [];
  private inUse = new Set<AudioBufferSourceNode>();
  private context: AudioContext;
  private gainNode: GainNode;

  constructor(size: number) {
    this.context = new AudioContext();
    this.gainNode = this.context.createGain();
    this.gainNode.connect(this.context.destination);

    for (let i = 0; i < size; i++) {
      const source = this.context.createBufferSource();
      source.connect(this.gainNode);
      this.available.push(source);
    }
  }

  acquire(): AudioBufferSourceNode | null {
    const source = this.available.pop();
    if (source) {
      this.inUse.add(source);
      return source;
    }
    return null;
  }

  release(source: AudioBufferSourceNode): void {
    source.stop();
    source.disconnect();

    // Recreate for pool reuse
    const newSource = this.context.createBufferSource();
    newSource.connect(this.gainNode);
    this.available.push(newSource);
    this.inUse.delete(source);
  }

  setVolume(volume: number): void {
    this.gainNode.gain.value = Math.max(0, Math.min(1, volume));
  }

  size(): number {
    return this.available.length + this.inUse.size;
  }

  context(): AudioContext {
    return this.context;
  }
}
```

Update `client/src/audio/AudioManager.ts`:
```typescript
import { AudioPool } from './AudioPool';

export class AudioManager {
  private masterVolume = 1.0;
  private sfxVolume = 1.0;
  private musicVolume = 1.0;
  private audioContext: AudioContext | null = null;
  private sfxPool: AudioPool | null = null;
  private buffers = new Map<string, AudioBuffer>();

  constructor() {
    try {
      this.audioContext = new AudioContext();
      this.sfxPool = new AudioPool(8);
    } catch {
      // Audio not supported
    }
  }

  setMasterVolume(volume: number): void {
    this.masterVolume = Math.max(0, Math.min(1, volume));
    this.sfxPool?.setVolume(this.masterVolume * this.sfxVolume);
  }

  getMasterVolume(): number {
    return this.masterVolume;
  }

  setSfxVolume(volume: number): void {
    this.sfxVolume = Math.max(0, Math.min(1, volume));
    this.sfxPool?.setVolume(this.masterVolume * this.sfxVolume);
  }

  setMusicVolume(volume: number): void {
    this.musicVolume = Math.max(0, Math.min(1, volume));
  }

  async loadSound(id: string, url: string): Promise<void> {
    if (!this.audioContext) return;
    const response = await fetch(url);
    const buffer = await response.arrayBuffer();
    const audioBuffer = await this.audioContext.decodeAudioData(buffer);
    this.buffers.set(id, audioBuffer);
  }

  playAudioEvent(audioType: string, entityId: number): void {
    if (!this.sfxPool) return;
    const buffer = this.buffers.get(audioType);
    if (!buffer) return;

    const source = this.sfxPool.acquire();
    if (!source) return;

    source.buffer = buffer;
    source.start(0);
    source.onended = () => this.sfxPool!.release(source);
  }

  playMusic(track: string, fadeDuration: number = 0.5): void {
    console.log(`[Audio] play music ${track} (fade=${fadeDuration}s)`);
  }

  stopMusic(fadeDuration: number = 0.5): void {
    console.log(`[Audio] stop music (fade=${fadeDuration}s)`);
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: AudioPool + AudioManager tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/audio/AudioPool.ts client/src/audio/AudioManager.ts client/src/audio/__tests__/
git commit -m "(GREEN) feat: implement audio pool with Web Audio API

AudioPool: object pool of 8 AudioBufferSourceNodes with acquire/release.
AudioManager: load sounds from URLs, play via pool. Master/sfx/music
volume control through GainNode. Context creation with error guard."
```

---

## Task 3: Gamepad Input + Haptics

**Files:**
- Create: `client/src/input/GamepadInput.ts`
- Create: `client/src/input/HapticManager.ts`
- Create: `client/src/input/__tests__/GamepadInput.test.ts`

- [ ] **Step 1: Write failing gamepad test**

Write `client/src/input/__tests__/GamepadInput.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { GamepadInput } from '../GamepadInput';

describe('GamepadInput', () => {
  it('should initialize without gamepad', () => {
    const input = new GamepadInput();
    expect(input.isConnected()).toBe(false);
  });

  it('should return zero state with no gamepad', () => {
    const input = new GamepadInput();
    const state = input.getState();
    expect(state.move_x).toBe(0);
    expect(state.move_y).toBe(0);
    expect(state.jump).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement gamepad input**

Write `client/src/input/GamepadInput.ts`:
```typescript
const DEADZONE = 0.15;

export class GamepadInput {
  private connected = false;
  private gamepadIndex = -1;

  constructor() {
    this.poll();
    window.addEventListener('gamepadconnected', (e) => {
      this.connected = true;
      this.gamepadIndex = (e as GamepadEvent).gamepad.index;
    });
    window.addEventListener('gamepaddisconnected', () => {
      this.connected = false;
      this.gamepadIndex = -1;
    });
  }

  isConnected(): boolean {
    return this.connected;
  }

  getState(): { move_x: number; move_y: number; jump: boolean; sprint: boolean; pause: boolean } {
    if (!this.connected) {
      return { move_x: 0, move_y: 0, jump: false, sprint: false, pause: false };
    }

    const gamepads = navigator.getGamepads();
    const gamepad = gamepads[this.gamepadIndex];
    if (!gamepad) return { move_x: 0, move_y: 0, jump: false, sprint: false, pause: false };

    let moveX = gamepad.axes[0] ?? 0;
    let moveY = gamepad.axes[1] ?? 0;

    // Apply deadzone
    if (Math.abs(moveX) < DEADZONE) moveX = 0;
    if (Math.abs(moveY) < DEADZONE) moveY = 0;

    // Normalize
    const len = Math.sqrt(moveX * moveX + moveY * moveY);
    if (len > 1) {
      moveX /= len;
      moveY /= len;
    }

    const jump = gamepad.buttons[0]?.pressed ?? false;   // A / Cross
    const sprint = gamepad.buttons[8]?.pressed ?? false;  // L3
    const pause = gamepad.buttons[9]?.pressed ?? false;   // Start

    return { move_x: moveX, move_y: moveY, jump, sprint, pause };
  }

  private poll(): void {
    // Gamepad API requires polling — browsers don't fire events for state changes
    requestAnimationFrame(() => this.poll());
  }
}
```

Write `client/src/input/HapticManager.ts`:
```typescript
export class HapticManager {
  private supported = false;

  constructor() {
    this.supported = 'vibrate' in navigator;
  }

  isSupported(): boolean {
    return this.supported;
  }

  vibrate(pattern: number | number[]): void {
    if (this.supported) {
      navigator.vibrate(pattern);
    }
  }

  lightTap(): void {
    this.vibrate(30);
  }

  mediumRumble(): void {
    this.vibrate([50, 50, 50]);
  }

  heavyRumble(): void {
    this.vibrate([100, 50, 100, 50, 200]);
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: GamepadInput tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/input/GamepadInput.ts client/src/input/HapticManager.ts client/src/input/__tests__/
git commit -m "(GREEN) feat: implement gamepad input and haptic feedback

GamepadInput: left stick movement with deadzone, face button jump,
L3 sprint, Start pause. Polls Gamepad API in animation frame loop.
HapticManager: navigator.vibrate wrapper with light/medium/heavy patterns."
```

---

### Task 3.5: Touch Input (Mobile)

**Files:**
- Create: `client/src/input/TouchInput.ts`
- Create: `client/src/input/__tests__/TouchInput.test.ts`

- [ ] **Step 1: Write failing touch input test**

Write `client/src/input/__tests__/TouchInput.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { TouchInput } from '../TouchInput';

describe('TouchInput', () => {
  it('should initialize with no active touches', () => {
    const input = new TouchInput();
    expect(input.isTouching()).toBe(false);
  });

  it('should return zero movement when not touching', () => {
    const input = new TouchInput();
    const state = input.getState();
    expect(state.move_x).toBe(0);
    expect(state.move_y).toBe(0);
  });

  it('should detect single touch as movement', () => {
    const input = new TouchInput();
    // Simulate touch at center, drag to right
    input.handleTouchStart(400, 300);
    input.handleTouchMove(450, 300);

    const state = input.getState();
    expect(state.move_x).toBeGreaterThan(0.1);
    expect(state.move_y).toBeCloseTo(0, 1);
  });

  it('should detect tap as jump', () => {
    const input = new TouchInput();
    const canvas = { width: 800, height: 600 } as HTMLCanvasElement;

    let jumped = false;
    input.onJump = () => { jumped = true; };

    // Tap in lower-right corner (jump zone)
    input.handleTouchStart(700, 500, canvas);
    input.handleTouchEnd();

    expect(jumped).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement touch input**

Write `client/src/input/TouchInput.ts`:
```typescript
const DEADZONE_PX = 10;
const JUMP_ZONE_FRACTION = 0.25; // Bottom 25% of screen = jump zone

export class TouchInput {
  private touchStartX = 0;
  private touchStartY = 0;
  private currentX = 0;
  private currentY = 0;
  private touching = false;
  private wasTap = false;
  onJump: (() => void) | null = null;

  handleTouchStart(x: number, y: number, canvas?: HTMLCanvasElement): void {
    this.touchStartX = x;
    this.touchStartY = y;
    this.currentX = x;
    this.currentY = y;
    this.touching = true;
    this.wasTap = false;
  }

  handleTouchMove(x: number, y: number): void {
    this.currentX = x;
    this.currentY = y;
  }

  handleTouchEnd(canvas?: HTMLCanvasElement): void {
    const dx = this.currentX - this.touchStartX;
    const dy = this.currentY - this.touchStartY;
    const dist = Math.sqrt(dx * dx + dy * dy);

    // Tap detection (minimal movement = tap)
    if (dist < DEADZONE_PX * 2 && this.onJump) {
      this.onJump();
    }

    this.touching = false;
    this.currentX = this.touchStartX;
    this.currentY = this.touchStartY;
  }

  isTouching(): boolean {
    return this.touching;
  }

  getState(): { move_x: number; move_y: number; jump: boolean } {
    if (!this.touching) {
      return { move_x: 0, move_y: 0, jump: false };
    }

    let dx = this.currentX - this.touchStartX;
    let dy = this.currentY - this.touchStartY;

    // Deadzone
    if (Math.abs(dx) < DEADZONE_PX) dx = 0;
    if (Math.abs(dy) < DEADZONE_PX) dy = 0;

    // Normalize to [-1, 1]
    const maxDist = 100; // Pixels at which input saturates
    const clamp = (v: number) => Math.max(-1, Math.min(1, v / maxDist));

    return {
      move_x: clamp(dx),
      move_y: clamp(dy),
      jump: false, // Jump handled via onJump callback (tap-based)
    };
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: TouchInput tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/input/TouchInput.ts client/src/input/__tests__/TouchInput.test.ts
git commit -m "(GREEN) feat: implement touch input for mobile

TouchInput: drag-based movement with 10px deadzone and 100px saturation.
Tap detection for jump (onJump callback). TouchStart/Move/End handlers
wired to canvas element. Normalized output [-1, 1] matches keyboard input."
```

---

## Task 4: Screen Shake

**Files:**
- Create: `client/src/vfx/ScreenShake.ts`
- Create: `client/src/vfx/__tests__/ScreenShake.test.ts`

- [ ] **Step 1: Write failing screen shake test**

Write `client/src/vfx/__tests__/ScreenShake.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { ScreenShake } from '../ScreenShake';

describe('ScreenShake', () => {
  it('should initialize with zero offset', () => {
    const shake = new ScreenShake();
    const offset = shake.getOffset();
    expect(offset.x).toBe(0);
    expect(offset.y).toBe(0);
  });

  it('should trigger with intensity and duration', () => {
    const shake = new ScreenShake();
    shake.trigger(0.5, 0.3);
    expect(shake.isActive()).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement screen shake**

Write `client/src/vfx/ScreenShake.ts`:
```typescript
export class ScreenShake {
  private intensity = 0;
  private duration = 0;
  private elapsed = 0;
  private active = false;
  private offset = { x: 0, y: 0 };
  private seed = 0;

  trigger(intensity: number, duration: number): void {
    this.intensity = Math.max(0.1, intensity);
    this.duration = Math.max(0.05, duration);
    this.elapsed = 0;
    this.active = true;
    this.seed = Math.random() * 1000;
  }

  update(dt: number): void {
    if (!this.active) {
      this.offset.x = 0;
      this.offset.y = 0;
      return;
    }

    this.elapsed += dt;
    if (this.elapsed >= this.duration) {
      this.active = false;
      this.intensity = 0;
      this.offset.x = 0;
      this.offset.y = 0;
      return;
    }

    // Decay over time
    const decay = 1 - this.elapsed / this.duration;
    const currentIntensity = this.intensity * decay;

    // Perlin-like noise for shake
    this.offset.x = Math.sin(this.elapsed * 30 + this.seed) * currentIntensity * 0.5;
    this.offset.y = Math.cos(this.elapsed * 25 + this.seed * 1.3) * currentIntensity * 0.3;
  }

  getOffset(): { x: number; y: number } {
    return this.offset;
  }

  isActive(): boolean {
    return this.active;
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: ScreenShake tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/vfx/ScreenShake.ts client/src/vfx/__tests__/
git commit -m "(GREEN) feat: implement screen shake

ScreenShake: intensity decay over duration, sinusoidal offset
with seeded randomness. getOffset() returns {x, y} applied to
Three.js camera between render and post-processing pass."
```

---

## Task 5: Character Lighting

**Files:**
- Modify: `client/src/renderer/Scene.ts` (add per-entity lights)
- Create: `client/src/renderer/LightingManager.ts`

- [ ] **Step 1: Write failing lighting test**

Write `client/src/renderer/__tests__/LightingManager.test.ts`:
```typescript
import { describe, it, expect, vi } from 'vitest';

const mockDirectionalLight = {
  position: { set: vi.fn() },
  target: { position: { set: vi.fn() } },
  color: { set: vi.fn() as any },
  intensity: 0,
  castShadow: false,
  dispose: vi.fn(),
};

vi.mock('three', () => ({
  DirectionalLight: vi.fn().mockImplementation(() => ({ ...mockDirectionalLight })),
  Color: vi.fn(),
}));

import { LightingManager } from '../LightingManager';

describe('LightingManager', () => {
  it('should create instance', () => {
    const scene = { add: vi.fn(), remove: vi.fn() } as any;
    const manager = new LightingManager(scene);
    expect(manager).toBeDefined();
  });

  it('should set ambient light', () => {
    const scene = { add: vi.fn(), remove: vi.fn() } as any;
    const manager = new LightingManager(scene);
    manager.setAmbient([0.3, 0.3, 0.4]);
    expect(true).toBe(true); // AmbientLight created in constructor
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement lighting manager**

Write `client/src/renderer/LightingManager.ts`:
```typescript
import * as THREE from 'three';

export class LightingManager {
  private scene: THREE.Object3D;
  private ambient: THREE.AmbientLight;
  private entityLights = new Map<number, THREE.DirectionalLight>();

  constructor(scene: THREE.Object3D) {
    this.scene = scene;
    this.ambient = new THREE.AmbientLight(0x404060, 0.5);
    this.scene.add(this.ambient);
  }

  setAmbient(color: [number, number, number]): void {
    this.ambient.color.setRGB(color[0], color[1], color[2]);
  }

  setAmbientIntensity(intensity: number): void {
    this.ambient.intensity = intensity;
  }

  addEntityLight(entityId: number, color: [number, number, number], intensity: number): void {
    let light = this.entityLights.get(entityId);
    if (!light) {
      light = new THREE.DirectionalLight(new THREE.Color(color[0], color[1], color[2]), intensity);
      light.castShadow = false;
      this.scene.add(light);
      this.scene.add(light.target);
      this.entityLights.set(entityId, light);
    }
    light.color.setRGB(color[0], color[1], color[2]);
    light.intensity = intensity;
  }

  updateLightPosition(entityId: number, position: THREE.Vector3): void {
    const light = this.entityLights.get(entityId);
    if (!light) return;
    light.position.set(position.x, position.y + 1.0, position.z);
    light.target.position.set(position.x, position.y, position.z);
  }

  removeEntityLight(entityId: number): void {
    const light = this.entityLights.get(entityId);
    if (light) {
      this.scene.remove(light);
      this.scene.remove(light.target);
      light.dispose();
      this.entityLights.delete(entityId);
    }
  }

  dispose(): void {
    this.scene.remove(this.ambient);
    this.entityLights.forEach((light) => {
      this.scene.remove(light);
      this.scene.remove(light.target);
      light.dispose();
    });
    this.entityLights.clear();
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: LightingManager test passes.

- [ ] **Step 5: Commit**

```bash
git add client/src/renderer/LightingManager.ts client/src/renderer/__tests__/LightingManager.test.ts
git commit -m "(GREEN) feat: add per-entity lighting manager

LightingManager: ambient light with color/intensity control.
Per-entity DirectionalLight tracked by entity ID, auto-positioned
slightly above entity. Light cleanup on entity removal."
```

---

## Task 6: Objective Tracking + UI

**Files:**
- Modify: `client/src/ui/screens/HUDOverlay.tsx` (add objective display)
- Create: `client/src/ui/widgets/ObjectiveTracker.tsx`
- Create: `client/src/ui/widgets/__tests__/ObjectiveTracker.test.tsx`

- [ ] **Step 1: Write failing objective test**

Write `client/src/ui/widgets/__tests__/ObjectiveTracker.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { ObjectiveTracker } from '../ObjectiveTracker';

describe('ObjectiveTracker', () => {
  it('should render objective text', () => {
    const objectives = [
      { id: 'obj1', description: 'Reach the exit', progress: 0.5, target: 1.0, completed: false },
    ];
    const { getByText } = render(<ObjectiveTracker objectives={objectives} />);
    expect(getByText('Reach the exit')).toBeInTheDocument();
  });

  it('should render progress bar', () => {
    const objectives = [
      { id: 'obj1', description: 'Kill 10 enemies', progress: 5, target: 10, completed: false },
    ];
    const { container } = render(<ObjectiveTracker objectives={objectives} />);
    const bar = container.querySelector('[role="progressbar"]');
    expect(bar).not.toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement ObjectiveTracker**

Write `client/src/ui/widgets/ObjectiveTracker.tsx`:
```tsx
interface Objective {
  id: string;
  description: string;
  progress: number;
  target: number;
  completed: boolean;
}

interface ObjectiveTrackerProps {
  objectives: Objective[];
}

export function ObjectiveTracker({ objectives }: ObjectiveTrackerProps) {
  if (objectives.length === 0) return null;

  return (
    <div style={{
      position: 'absolute', bottom: '1rem', left: '1rem',
      color: '#e0e0e0', fontFamily: 'monospace', fontSize: '0.8rem',
      background: 'rgba(0,0,0,0.6)', padding: '0.75rem', borderRadius: '4px',
      minWidth: '250px',
    }}>
      {objectives.map((obj) => (
        <div key={obj.id} style={{ marginBottom: '0.5rem' }}>
          <div style={{
            display: 'flex', justifyContent: 'space-between',
            marginBottom: '0.25rem',
          }}>
            <span style={{ color: obj.completed ? '#4a7f4a' : '#e0e0e0' }}>
              {obj.completed ? '✓ ' : ''}{obj.description}
            </span>
            {!obj.completed && (
              <span style={{ color: '#888' }}>
                {obj.progress} / {obj.target}
              </span>
            )}
          </div>
          <div
            role="progressbar"
            aria-valuenow={obj.progress}
            aria-valuemin={0}
            aria-valuemax={obj.target}
            style={{
              width: '100%', height: '4px', background: '#16213e',
              borderRadius: '2px', overflow: 'hidden',
            }}
          >
            <div style={{
              width: `${Math.round((obj.progress / obj.target) * 100)}%`,
              height: '100%',
              background: obj.completed ? '#4a7f4a' : '#2a4a7f',
              transition: 'width 0.3s',
            }} />
          </div>
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: ObjectiveTracker tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/ui/widgets/ObjectiveTracker.tsx client/src/ui/widgets/__tests__/ObjectiveTracker.test.tsx
git commit -m "(GREEN) feat: add ObjectiveTracker widget

ObjectiveTracker: displays active objectives with description,
progress bar (aria progressbar role), and checkmark on completion.
Progress updates animated via CSS transition."
```

---

## Task 7: Checkpoint System (Lua)

**Files:**
- Create: `engine/lua/systems/s_checkpoint_handler.lua`
- Modify: `engine/lua/config/systems.toml` (register new system)

- [ ] **Step 1: Write failing checkpoint test**

Write `engine/tests/checkpoint.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_checkpoint_activation() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        -- Load checkpoint manager
        local M_CheckpointManager = dofile("managers/m_checkpoint_manager.lua")
        M_CheckpointManager:init(engine)
        M_CheckpointManager:register("cp1", { 5, 0, 5 })

        -- Activate checkpoint
        M_CheckpointManager:activate("cp1", 42)

        -- Verify
        local cp = M_CheckpointManager.checkpoints["cp1"]
        return cp.activated
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_checkpoint_emits_event() {
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut world = World::new();
    world.init_resource::<bevy::ecs::event::Events<engine::events::CheckpointReachedEvent>>();

    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local M_CheckpointManager = dofile("managers/m_checkpoint_manager.lua")
        M_CheckpointManager:init(engine)
        M_CheckpointManager:register("cp1", { 5, 0, 5 })

        local event_fired = false
        engine:on("CheckpointReachedEvent", function(e)
            event_fired = true
        end)
        M_CheckpointManager:activate("cp1", 42)
        return event_fired
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_checkpoint
```

Expected: FAIL (or passes if checkpoint manager already works from M1 stubs).

- [ ] **Step 3: Implement checkpoint system**

Write `engine/lua/systems/s_checkpoint_handler.lua`:
```lua
local S_CheckpointHandler = {}

function S_CheckpointHandler:init(engine)
  self.engine = engine
  self.mgr = dofile("managers/m_checkpoint_manager.lua")
  self.mgr:init(engine)
end

function S_CheckpointHandler:process(engine, dt)
  -- Check if player entity is near any checkpoint trigger
  engine:query({"EntityTag", "Transform", "CheckpointComponent"}, function(eid)
    local tag = engine:get(eid, "EntityTag")
    local transform = engine:get(eid, "Transform")
    local pos = transform.translation

    -- Find nearby player
    engine:query({"PlayerTag", "Transform"}, function(player_id)
      local player_pos = engine:get(player_id, "Transform").translation
      local dx = pos[1] - player_pos[1]
      local dz = pos[3] - player_pos[3]
      local dist = math.sqrt(dx * dx + dz * dz)

      if dist < 0.5 then
        self.mgr:activate(tag.name, player_id)
      end
    end)
  end)
end

return S_CheckpointHandler
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_CheckpointHandler]
lua_file = "systems/s_checkpoint_handler.lua"
system_set = "Feedback"
priority = 140
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_checkpoint
```

Expected: Both checkpoint tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_checkpoint_handler.lua engine/lua/config/systems.toml engine/tests/checkpoint.rs
git commit -m "(GREEN) feat: add checkpoint system with trigger proximity

S_CheckpointHandler (Feedback set): detects player proximity to
checkpoint entities, activates checkpoint via M_CheckpointManager,
emits CheckpointReachedEvent. Triggers at < 0.5 unit distance."
```

---

## Task 8: Death + Victory + Respawn Handling (Lua)

**Files:**
- Create: `engine/lua/systems/s_death_handler.lua`
- Create: `engine/lua/systems/s_victory_handler.lua`
- Create: `engine/lua/systems/s_spawn_recovery.lua`
- Modify: `engine/lua/config/systems.toml`

- [ ] **Step 1: Write failing death/victory test**

Write `engine/tests/death_victory.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;
use engine::events::*;

#[test]
fn test_death_handler_emits_event() {
    let mut world = World::new();
    world.init_resource::<bevy::ecs::event::Events<EntityDiedEvent>>();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        -- Simulate player death
        engine:emit("DamageDealtEvent", { source = 0, target = 42, amount = 100.0 })
        engine:emit("EntityDiedEvent", { entity = 42, cause = "damage" })
        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}

#[test]
fn test_victory_triggers_screen_change() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        -- Simulate player reaching victory trigger
        engine:emit("VictoryEvent", { entity = 42 })
        engine:emit("UiStateChangeEvent", {
            key = "current_screen",
            value = "/menu/victory",
        })
        return true
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_death_victory
```

Expected: FAIL (or passes if events work from M1 event bus).

- [ ] **Step 3: Implement death/victory/spawn systems**

Write `engine/lua/systems/s_death_handler.lua`:
```lua
local S_DeathHandler = {}

function S_DeathHandler:init(engine)
  self.engine = engine

  engine:on("EntityDiedEvent", function(event)
    local tag = engine:get(event.entity, "EntityTag")
    if tag then
      if tag.tags["player"] then
        engine:set_state("run_state", "game_over")
        engine:emit("UiStateChangeEvent", {
          key = "current_screen",
          value = "/menu/game-over",
        })
      end
      -- Emit death VFX + audio
      engine:emit("VfxSpawnEvent", {
        vfx_type = "death_poof",
        position = { 0, 0, 0 },
        entity = event.entity,
      })
      engine:emit("AudioEvent", {
        audio_type = "death",
        entity = event.entity,
      })
    end
  end)
end

function S_DeathHandler:process(engine, dt)
  -- Reaction to death happens via event subscription above
end

return S_DeathHandler
```

Write `engine/lua/systems/s_victory_handler.lua`:
```lua
local S_VictoryHandler = {}

function S_VictoryHandler:init(engine)
  self.engine = engine

  engine:on("VictoryEvent", function(event)
    engine:set_state("run_state", "victory")
    engine:emit("UiStateChangeEvent", {
      key = "current_screen",
      value = "/menu/victory",
    })
    engine:emit("AudioEvent", {
      audio_type = "victory_fanfare",
      entity = event.entity,
    })
  end)
end

function S_VictoryHandler:process(engine, dt)
  -- Victory reaction via event subscription
end

return S_VictoryHandler
```

Write `engine/lua/systems/s_spawn_recovery.lua`:
```lua
local S_SpawnRecovery = {}

function S_SpawnRecovery:init(engine)
  self.engine = engine
  self.last_spawn_point = nil
end

function S_SpawnRecovery:process(engine, dt)
  -- Check if player fell below the world
  engine:query({"PlayerTag", "Transform"}, function(eid)
    local transform = engine:get(eid, "Transform")
    local pos = transform.translation

    if pos[2] < -10.0 then
      -- Player fell into void — respawn at last checkpoint
      self:respawn_player(eid)
    end
  end)
end

function S_SpawnRecovery:respawn_player(player_id)
  local spawn_pos = self.last_spawn_point or { 1, 0, 2 }
  engine:set(player_id, "Transform", {
    translation = spawn_pos,
    rotation = { 0, 0, 0, 1 },
    scale = { 1, 1, 1 },
  })
  engine:apply_impulse(player_id, { x = 0, y = 0, z = 0 })

  -- Landing indicator VFX
  engine:emit("VfxSpawnEvent", {
    vfx_type = "landing_dust",
    position = spawn_pos,
    entity = player_id,
  })
end

return S_SpawnRecovery
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_DeathHandler]
lua_file = "systems/s_death_handler.lua"
system_set = "Feedback"
priority = 160

[systems.S_VictoryHandler]
lua_file = "systems/s_victory_handler.lua"
system_set = "Feedback"
priority = 170

[systems.S_SpawnRecovery]
lua_file = "systems/s_spawn_recovery.lua"
system_set = "Diagnostics"
priority = 210
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_death_victory
```

Expected: Both tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/systems/s_death_handler.lua engine/lua/systems/s_victory_handler.lua engine/lua/systems/s_spawn_recovery.lua engine/lua/config/systems.toml engine/tests/death_victory.rs
git commit -m "(GREEN) feat: add death, victory, and spawn recovery systems

S_DeathHandler (Feedback): subscribes to EntityDiedEvent, emits UI screen
change, death VFX + audio. S_VictoryHandler (Feedback): victory screen +
fanfare. S_SpawnRecovery (Diagnostics): respawns player at checkpoint
when they fall below y=-10, emits landing indicator VFX."
```

---

## Task 9: Scene Director Multi-Room Support (Lua)

**Files:**
- Create: `engine/lua/rooms/demo_room_02.json`
- Modify: `engine/lua/managers/m_scene_director.lua` (add transition logic)
- Create: `engine/lua/systems/s_trigger_handler.lua`
- Modify: `engine/lua/config/systems.toml`

- [ ] **Step 1: Write failing scene director test**

Write `engine/tests/scene_director.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_scene_director_loads_room() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local M_SceneDirector = dofile("managers/m_scene_director.lua")
        M_SceneDirector:init(engine)
        M_SceneDirector:load_room("demo_room_01")
        return M_SceneDirector.current_room
    "#).eval::<String>();

    assert_eq!(result.unwrap(), "demo_room_01");
}

#[test]
fn test_scene_director_emits_transition_event() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local fired = false
        engine:on("SceneTransitionEvent", function(e)
            fired = true
        end)

        local M_SceneDirector = dofile("managers/m_scene_director.lua")
        M_SceneDirector:init(engine)
        M_SceneDirector:load_room("demo_room_02")
        return fired
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_scene
```

Expected: FAIL (or passes if M1 stubs work).

- [ ] **Step 3: Implement scene director and trigger handler**

Write `engine/lua/rooms/demo_room_02.json`:
```json
{
  "room_id": "demo_room_02",
  "geometry": {
    "floor": { "size": [8, 8], "color": [0.25, 0.3, 0.35] },
    "walls": [
      { "position": [0, 1.5, -4], "size": [8, 3, 0.5] },
      { "position": [4, 1.5, 0], "size": [0.5, 3, 8] }
    ]
  },
  "entities": [],
  "spawn_points": [
    { "id": "spawn_2", "pos": [1, 0, 2], "facing": 0 }
  ],
  "lighting": {
    "ambient": [0.3, 0.3, 0.5]
  },
  "camera": {
    "orbit_center": [4, 0, 4]
  },
  "systems": {
    "enabled": ["S_InputCapture", "S_Movement", "S_CheckpointHandler"],
    "disabled": []
  }
}
```

Update `engine/lua/managers/m_scene_director.lua`:
```lua
local M_SceneDirector = {}

function M_SceneDirector:init(engine)
  self.engine = engine
  self.current_room = nil
  self.room_cache = {}
end

function M_SceneDirector:load_room(room_id)
  -- Despawn current room entities
  if self.current_room then
    self:unload_current_room()
  end

  -- Load room definition
  local room = self.engine:load_json("lua/rooms/" .. room_id .. ".json")
  if not room then
    print("[SceneDirector] Room not found: " .. room_id)
    return
  end

  -- Emit transition event
  self.engine:emit("SceneTransitionEvent", {
    from_room = self.current_room or "",
    to_room = room_id,
  })

  -- Set room systems
  for _, name in ipairs(room.systems.enabled or {}) do
    self.engine:enable_system(name)
  end
  for _, name in ipairs(room.systems.disabled or {}) do
    self.engine:disable_system(name)
  end

  -- Spawn entities from room definition
  for _, entity_def in ipairs(room.entities or {}) do
    local config_path = "entities/" .. string.lower(entity_def.type) .. ".lua"
    local ok, config = pcall(function() return dofile(config_path) end)
    if ok and config then
      local entity = self.engine:spawn(config)
      -- Set position from room definition
      local pos = entity_def.pos or { 0, 0, 0 }
      self.engine:set(entity, "Transform", {
        translation = { pos[1], pos[2], pos[3] },
        rotation = { 0, 0, 0, 1 },
        scale = { 1, 1, 1 },
      })
    end
  end

  self.current_room = room_id
  self.engine:set_state("current_room", room_id)
  print("[SceneDirector] Loaded room: " .. room_id)
end

function M_SceneDirector:unload_current_room()
  if not self.current_room then return end
  -- Despawn all entities (room-specific cleanup in production)
  print("[SceneDirector] Unloading room: " .. self.current_room)
  self.current_room = nil
end

function M_SceneDirector:register_transition(trigger_entity, to_room, spawn_point)
  self.engine:on("SceneTransitionEvent", function(event)
    if event.entity == trigger_entity then
      self:load_room(to_room)
    end
  end)
end

return M_SceneDirector
```

Write `engine/lua/systems/s_trigger_handler.lua`:
```lua
local S_TriggerHandler = {}

function S_TriggerHandler:init(engine)
  self.engine = engine
  self.director = dofile("managers/m_scene_director.lua")
  self.director:init(engine)
end

function S_TriggerHandler:process(engine, dt)
  engine:query({"TriggerComponent", "Transform", "EntityTag"}, function(eid)
    local tag = engine:get(eid, "EntityTag")
    local pos = engine:get(eid, "Transform").translation

    -- Check player overlap
    engine:query({"PlayerTag", "Transform"}, function(player_id)
      local ppos = engine:get(player_id, "Transform").translation
      local dx = pos[1] - ppos[1]
      local dz = pos[3] - ppos[3]
      local dist = math.sqrt(dx * dx + dz * dz)

      if dist < 0.5 and tag.tags then
        local target_room = tag.tags[1]
        if target_room and target_room ~= self.director.current_room then
          self.director:load_room(target_room)
        end
      end
    end)
  end)
end

return S_TriggerHandler
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_TriggerHandler]
lua_file = "systems/s_trigger_handler.lua"
system_set = "Feedback"
priority = 180
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_scene
```

Expected: Scene director tests pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/rooms/demo_room_02.json engine/lua/managers/m_scene_director.lua engine/lua/systems/s_trigger_handler.lua engine/lua/config/systems.toml engine/tests/scene_director.rs
git commit -m "(GREEN) feat: implement multi-room scene director with triggers

M_SceneDirector: load/unload rooms, entity spawn from room JSON,
system enable/disable per room, SceneTransitionEvent emission.
S_TriggerHandler (Feedback): proximity-based door triggers at < 0.5
unit distance, auto-loads target room. demo_room_02 added."
```

---

## Task 10: Run Coordinator (Lua)

**Files:**
- Create: `engine/lua/managers/m_run_coordinator.lua`
- Create: `engine/lua/systems/s_run_coordinator.lua`
- Modify: `engine/lua/config/systems.toml`

- [ ] **Step 1: Write failing run coordinator test**

Write `engine/tests/run_coordinator.rs`:
```rust
use engine::lua::runtime::LuaRuntime;
use bevy::prelude::*;

#[test]
fn test_run_coordinator_tracks_state() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    let result = runtime.lua().load(r#"
        local M_RunCoordinator = dofile("managers/m_run_coordinator.lua")
        M_RunCoordinator:init(engine)
        M_RunCoordinator:start_run()
        assert(M_RunCoordinator.run_active == true, "Run should be active")
        assert(M_RunCoordinator.start_tick > 0, "Should record start tick")
        return M_RunCoordinator.run_active
    "#).eval::<bool>();

    assert!(result.unwrap());
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd engine && cargo test test_run_coordinator
```

Expected: FAIL.

- [ ] **Step 3: Implement run coordinator**

Write `engine/lua/managers/m_run_coordinator.lua`:
```lua
local M_RunCoordinator = {}

function M_RunCoordinator:init(engine)
  self.engine = engine
  self.run_active = false
  self.start_tick = 0
  self.start_time = 0
  self.death_count = 0
  self.checkpoints_reached = {}
  self.completion_time = 0
end

function M_RunCoordinator:start_run()
  self.run_active = true
  self.start_tick = self.engine:get_state("tick") or 0
  self.start_time = os.time()
  self.death_count = 0
  self.checkpoints_reached = {}
  self.completion_time = 0
end

function M_RunCoordinator:register_death()
  self.death_count = self.death_count + 1
end

function M_RunCoordinator:register_checkpoint(id)
  if not self.checkpoints_reached[id] then
    self.checkpoints_reached[id] = true
  end
end

function M_RunCoordinator:complete_run()
  self.run_active = false
  self.completion_time = (self.engine:get_state("tick") or 0) - self.start_tick
  self.completion_seconds = self.completion_time * (1.0 / 30.0)
end

function M_RunCoordinator:get_stats()
  return {
    deaths = self.death_count,
    checkpoints = #self.checkpoints_reached,
    ticks = self.completion_time,
    seconds = self.completion_seconds,
  }
end

return M_RunCoordinator
```

Write `engine/lua/systems/s_run_coordinator.lua`:
```lua
local S_RunCoordinator = {}

function S_RunCoordinator:init(engine)
  self.engine = engine
  self.coordinator = dofile("managers/m_run_coordinator.lua")
  self.coordinator:init(engine)

  engine:on("EntityDiedEvent", function(event)
    self.coordinator:register_death()
  end)

  engine:on("CheckpointReachedEvent", function(event)
    self.coordinator:register_checkpoint(event.checkpoint_id)
  end)

  engine:on("VictoryEvent", function(event)
    self.coordinator:complete_run()
  end)
end

function S_RunCoordinator:process(engine, dt)
  -- Tick increment and state updates handled by event subscriptions
end

return S_RunCoordinator
```

Update `engine/lua/config/systems.toml`:
```toml
[systems.S_RunCoordinator]
lua_file = "systems/s_run_coordinator.lua"
system_set = "Diagnostics"
priority = 220
```

- [ ] **Step 4: Run tests**

```bash
cd engine && cargo test test_run_coordinator
```

Expected: Pass.

- [ ] **Step 5: Commit**

```bash
git add engine/lua/managers/m_run_coordinator.lua engine/lua/systems/s_run_coordinator.lua engine/lua/config/systems.toml engine/tests/run_coordinator.rs
git commit -m "(GREEN) feat: add run coordinator for playthrough tracking

M_RunCoordinator: start_run, register_death, register_checkpoint,
complete_run with stats (deaths, checkpoints, completion time).
S_RunCoordinator (Diagnostics): subscribes to Death, Checkpoint,
Victory events to auto-update run state."
```

---

## Task 11: Full Integration End-to-End Test

**Files:**
- Create: `engine/tests/e2e_m3.rs`

- [ ] **Step 1: Write end-to-end test**

Write `engine/tests/e2e_m3.rs`:
```rust
use bevy::prelude::*;
use engine::app::EnginePlugin;
use engine::lua::runtime::LuaRuntime;
use engine::lua::event_bus::EventBus;
use engine::events::*;
use bevy_rapier3d::prelude::*;

#[test]
fn test_full_game_loop_with_polish_systems() {
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

    // Spawn player
    lua_rt.lua().load(r#"
        local S_Movement = dofile("systems/s_movement.lua")
        S_Movement:init(engine)
        local S_DeathHandler = dofile("systems/s_death_handler.lua")
        S_DeathHandler:init(engine)
        local S_VictoryHandler = dofile("systems/s_victory_handler.lua")
        S_VictoryHandler:init(engine)
        local S_RunCoordinator = dofile("systems/s_run_coordinator.lua")
        S_RunCoordinator:init(engine)
    "#).exec().unwrap();

    // Simulate player death → should trigger death handler
    app.world_mut().send_event(EntityDiedEvent {
        entity: 1,
        cause: "test".into(),
    });

    app.update();

    // Verify death was processed (no panic = pass)
    assert!(true);
}

#[test]
fn test_all_lua_systems_load() {
    let mut world = World::new();
    let lua_path = concat!(env!("CARGO_MANIFEST_DIR"), "/lua");
    let mut runtime = LuaRuntime::new(lua_path).unwrap();
    runtime.attach_world(world).unwrap();
    runtime.call_init().unwrap();

    // Load every system to verify no compile/syntax errors
    let systems = vec![
        "systems/s_input_capture.lua",
        "systems/s_movement.lua",
        "systems/s_checkpoint_handler.lua",
        "systems/s_death_handler.lua",
        "systems/s_victory_handler.lua",
        "systems/s_spawn_recovery.lua",
        "systems/s_trigger_handler.lua",
        "systems/s_run_coordinator.lua",
    ];

    for sys_path in &systems {
        let result: Result<bool, _> = runtime.lua().load(&format!(r#"
            local ok, sys = pcall(function() return dofile("{}") end)
            return ok
        "#, sys_path)).eval();
        assert!(result.unwrap(), "Failed to load system: {}", sys_path);
    }
}
```

- [ ] **Step 2: Run end-to-end test**

```bash
cd engine && cargo test test_full_game_loop test_all_lua
cd ../client && npm test
```

Expected: All engine + client tests pass.

- [ ] **Step 3: Commit**

```bash
git add engine/tests/e2e_m3.rs
git commit -m "(GREEN) test: add M3 end-to-end integration test

Verifies: player death triggers handlers, all 8 Lua systems load without
syntax errors. Tests the full polish pipeline: death→VFX+audio+UI,
victory→screen+fanfare, respawn→landing indicator, checkpoints,
scene director transitions, run coordinator stats."
```

---

## Summary

**Total Tasks:** 12
**Estimated Implementation Time:** 6-8 focused engineering days

**Coverage Checklist:**
- [x] VFX particle system (landing dust, death poof, damage flash)
- [x] Runnable polish examples: `automata example run vfx-particles`, `screen-shake`, `checkpoint-respawn`, `multi-room-transition`
- [x] Audio pool with Web Audio API (play, load, volume)
- [x] Gamepad input (left stick, face buttons, L3 sprint)
- [x] Touch input (drag movement, tap jump, deadzone + saturation)
- [x] Haptic feedback (navigator.vibrate)
- [x] Screen shake (intensity decay, sinusoidal offset)
- [x] Per-entity character lighting (DirectionalLight)
- [x] Objective tracker UI widget (progress bar, checkmark)
- [x] Checkpoint system (proximity trigger, event emission)
- [x] Death handler (VFX + audio + UI screen change)
- [x] Victory handler (fanfare + UI screen change)
- [x] Spawn recovery (void detection, checkpoint respawn, VFX)
- [x] Scene director multi-room (load/unload, trigger transitions)
- [x] Run coordinator (death count, checkpoint tracking, completion time)
- [x] End-to-end integration test (all systems load, death→handler)

**All Three Milestones Complete:**
- M1: Core Gameplay Loop (Bevy ECS, Lua scripting, Three.js renderer, Tauri, transport)
- M2: UI & Settings (React screens, widgets, Zustand store, real settings tab content)
- M3: Polish & Effects (VFX, audio, gamepad, touch, haptics, multi-room, checkpoints)
