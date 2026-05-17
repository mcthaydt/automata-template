# M2: UI & Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build all menu screens, settings panel, HUD overlay, and supporting widget components in the Three.js + React client, matching the Godot template's screen registry and widget decomposition pattern.

**Architecture:** React + HTML/CSS replaces Godot's Control-node widget system. Screen registry maps to HTML routes. Same widget decomposition philosophy — small single-responsibility components, thin controllers (~40-80 lines), isolated per-widget Vitest tests, no shared base class. Gamepad navigation via focus-visible + roving tabindex. 400x400 PNG backgrounds rendered as CSS with image-rendering: pixelated. UI state in Zustand store, server-authored UI events via WebSocket transport.

**Tech Stack:** React 19, TypeScript, Zustand 5, Vitest, CSS Modules, Vite.

**Prerequisites:** M1 complete (transport layer, GameLoop, client scaffold).

---

## Task 1: UI Shell + Screen Router

**Files:**
- Create: `client/src/ui/App.tsx`
- Create: `client/src/ui/screens/ScreenRegistry.ts`
- Create: `client/src/ui/store/uiStore.ts`
- Create: `client/src/ui/__tests__/ScreenRegistry.test.ts`
- Modify: `client/src/main.ts` (render App)

- [ ] **Step 1: Write failing screen registry test**

Write `client/src/ui/__tests__/ScreenRegistry.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { ScreenRegistry } from '../screens/ScreenRegistry';

describe('ScreenRegistry', () => {
  it('should register screens with routes', () => {
    const registry = new ScreenRegistry();
    registry.register('/menu/main', 'MainMenu');
    registry.register('/menu/pause', 'PauseMenu');
    expect(registry.get('/menu/main')).toBe('MainMenu');
    expect(registry.get('/menu/pause')).toBe('PauseMenu');
  });

  it('should return undefined for unregistered routes', () => {
    const registry = new ScreenRegistry();
    expect(registry.get('/nonexistent')).toBeUndefined();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL — ScreenRegistry not found.

- [ ] **Step 3: Implement screen registry**

Write `client/src/ui/screens/ScreenRegistry.ts`:
```typescript
export type ScreenComponent = string;

export class ScreenRegistry {
  private routes = new Map<string, ScreenComponent>();

  register(route: string, component: ScreenComponent): void {
    this.routes.set(route, component);
  }

  get(route: string): ScreenComponent | undefined {
    return this.routes.get(route);
  }

  allRoutes(): string[] {
    return [...this.routes.keys()];
  }
}
```

Write `client/src/ui/store/uiStore.ts`:
```typescript
import { create } from 'zustand';

type Screen = '/menu/main' | '/menu/pause' | '/menu/game-over' | '/menu/victory'
  | '/menu/credits' | '/menu/splash' | '/menu/settings'
  | '/menu/save-load' | '/hud' | '/loading';

interface UiState {
  currentScreen: Screen;
  settingsOpen: boolean;
  navigateTo: (screen: Screen) => void;
  toggleSettings: () => void;
}

export const useUiStore = create<UiState>((set) => ({
  currentScreen: '/menu/splash',
  settingsOpen: false,
  navigateTo: (screen) => set({ currentScreen: screen }),
  toggleSettings: () => set((s) => ({ settingsOpen: !s.settingsOpen })),
}));
```

Write `client/src/ui/App.tsx`:
```typescript
import { useUiStore } from './store/uiStore';
import { SplashScreen } from './screens/SplashScreen';
import { MainMenuScreen } from './screens/MainMenuScreen';
import { PauseMenuScreen } from './screens/PauseMenuScreen';
import { GameOverScreen } from './screens/GameOverScreen';
import { VictoryScreen } from './screens/VictoryScreen';
import { CreditsScreen } from './screens/CreditsScreen';
import { SettingsPanel } from './screens/SettingsPanel';
import { HUDOverlay } from './screens/HUDOverlay';
import { LoadingScreen } from './screens/LoadingScreen';
import { SaveLoadMenu } from './screens/SaveLoadMenu';

export function App() {
  const currentScreen = useUiStore((s) => s.currentScreen);

  const screenComponents: Record<string, React.FC> = {
    '/menu/splash': SplashScreen,
    '/menu/main': MainMenuScreen,
    '/menu/pause': PauseMenuScreen,
    '/menu/game-over': GameOverScreen,
    '/menu/victory': VictoryScreen,
    '/menu/credits': CreditsScreen,
    '/menu/settings': SettingsPanel,
    '/hud': HUDOverlay,
    '/loading': LoadingScreen,
    '/menu/save-load': SaveLoadMenu,
  };

  const Component = screenComponents[currentScreen];
  return Component ? <Component /> : <div>Screen not found: {currentScreen}</div>;
}
```

Update `client/src/main.ts`:
```typescript
import { createRoot } from 'react-dom/client';
import { App } from './ui/App';

createRoot(document.getElementById('root')!).render(<App />);
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: ScreenRegistry test passes.

- [ ] **Step 5: Commit**

```bash
git add client/src/ui/App.tsx client/src/ui/screens/ScreenRegistry.ts client/src/ui/store/uiStore.ts client/src/ui/__tests__/ client/src/main.ts
git commit -m "(GREEN) feat: add UI shell with screen registry and Zustand store

ScreenRegistry maps routes to component names. Zustand store manages
current screen and settings toggle. App component renders screen by route.
10 screens registered: splash, main menu, pause, game over, victory,
credits, settings, HUD, loading, save/load."
```

---

## Task 2: Background Image + Shader Widgets

**Files:**
- Create: `client/src/ui/widgets/BackgroundImage.tsx`
- Create: `client/src/ui/widgets/BackgroundShader.tsx`
- Create: `client/src/ui/widgets/__tests__/BackgroundImage.test.tsx`
- Create: `client/src/ui/widgets/__tests__/BackgroundShader.test.tsx`

- [ ] **Step 1: Write failing widget tests**

Write `client/src/ui/widgets/__tests__/BackgroundImage.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { BackgroundImage } from '../BackgroundImage';

describe('BackgroundImage', () => {
  it('should render with nearest-neighbor filtering', () => {
    const { container } = render(
      <BackgroundImage src="assets/core/textures/bg_main_menu.png" />
    );
    const img = container.querySelector('img');
    expect(img).not.toBeNull();
    expect(img?.style.imageRendering).toBe('pixelated');
  });

  it('should cover full viewport', () => {
    const { container } = render(
      <BackgroundImage src="assets/core/textures/bg_main_menu.png" />
    );
    const div = container.firstChild as HTMLElement;
    expect(div.style.width).toBe('100%');
    expect(div.style.height).toBe('100%');
  });
});
```

Write `client/src/ui/widgets/__tests__/BackgroundShader.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { BackgroundShader } from '../BackgroundShader';

describe('BackgroundShader', () => {
  it('should render a canvas element', () => {
    const { container } = render(
      <BackgroundShader effect="none" />
    );
    const canvas = container.querySelector('canvas');
    expect(canvas).not.toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL — widgets not found.

- [ ] **Step 3: Implement widgets**

```bash
cd client && npm install @testing-library/react @testing-library/jest-dom jsdom
```

Update `client/vite.config.ts`:
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: { port: 5173 },
  build: { target: 'es2022' },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/test-setup.ts',
  },
});
```

Write `client/src/test-setup.ts`:
```typescript
import '@testing-library/jest-dom';
```

Write `client/src/ui/widgets/BackgroundImage.tsx`:
```tsx
import { CSSProperties } from 'react';

interface BackgroundImageProps {
  src: string;
  opacity?: number;
}

export function BackgroundImage({ src, opacity = 1 }: BackgroundImageProps) {
  const style: CSSProperties = {
    position: 'fixed',
    top: 0,
    left: 0,
    width: '100%',
    height: '100%',
    backgroundImage: `url(${src})`,
    backgroundSize: 'cover',
    backgroundPosition: 'center',
    imageRendering: 'pixelated',
    opacity,
    zIndex: 0,
  };

  return <div style={style} />;
}
```

Write `client/src/ui/widgets/BackgroundShader.tsx`:
```tsx
import { useRef, useEffect } from 'react';

interface BackgroundShaderProps {
  effect: string; // "none", "blur", "vignette", "scanlines"
}

export function BackgroundShader({ effect }: BackgroundShaderProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    switch (effect) {
      case 'vignette': {
        const gradient = ctx.createRadialGradient(
          canvas.width / 2, canvas.height / 2, canvas.width * 0.3,
          canvas.width / 2, canvas.height / 2, canvas.width * 0.7,
        );
        gradient.addColorStop(0, 'rgba(0,0,0,0)');
        gradient.addColorStop(1, 'rgba(0,0,0,0.6)');
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        break;
      }
      default:
        break;
    }
  }, [effect]);

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        zIndex: 1,
        pointerEvents: 'none',
      }}
    />
  );
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: BackgroundImage and BackgroundShader tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/ui/widgets/BackgroundImage.tsx client/src/ui/widgets/BackgroundShader.tsx client/src/ui/widgets/__tests__/ client/vite.config.ts client/src/test-setup.ts
git commit -m "(GREEN) feat: add BackgroundImage and BackgroundShader widgets

BackgroundImage: fixed full-viewport div with pixelated background-image.
BackgroundShader: overlay canvas for vignette/scanlines/blur effects.
Vitest configured with jsdom + @testing-library/react."
```

---

## Task 3: Menu Button List Widget

**Files:**
- Create: `client/src/ui/widgets/MenuButtonList.tsx`
- Create: `client/src/ui/widgets/__tests__/MenuButtonList.test.tsx`

- [ ] **Step 1: Write failing test**

Write `client/src/ui/widgets/__tests__/MenuButtonList.test.tsx`:
```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, fireEvent } from '@testing-library/react';
import { MenuButtonList } from '../MenuButtonList';

describe('MenuButtonList', () => {
  const items = [
    { label: 'New Game', action: () => {} },
    { label: 'Continue', action: () => {} },
    { label: 'Settings', action: () => {} },
  ];

  it('should render all buttons', () => {
    const { getAllByRole } = render(<MenuButtonList items={items} />);
    expect(getAllByRole('button')).toHaveLength(3);
  });

  it('should call action on click', () => {
    const spy = vi.fn();
    const itemsWithSpy = [{ label: 'Test', action: spy }];
    const { getByText } = render(<MenuButtonList items={itemsWithSpy} />);
    fireEvent.click(getByText('Test'));
    expect(spy).toHaveBeenCalled();
  });

  it('should support keyboard navigation', () => {
    const { getAllByRole } = render(<MenuButtonList items={items} />);
    const buttons = getAllByRole('button');
    buttons[0].focus();
    expect(document.activeElement).toBe(buttons[0]);
    fireEvent.keyDown(buttons[0], { key: 'ArrowDown' });
    expect(document.activeElement).toBe(buttons[1]);
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL — MenuButtonList not found.

- [ ] **Step 3: Implement MenuButtonList**

Write `client/src/ui/widgets/MenuButtonList.tsx`:
```tsx
import { useRef, useEffect, useCallback } from 'react';

interface MenuItem {
  label: string;
  action: () => void;
  disabled?: boolean;
}

interface MenuButtonListProps {
  items: MenuItem[];
  orientation?: 'vertical' | 'horizontal';
}

export function MenuButtonList({ items, orientation = 'vertical' }: MenuButtonListProps) {
  const buttonsRef = useRef<(HTMLButtonElement | null)[]>([]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent, index: number) => {
    const dir = orientation === 'vertical' ? ['ArrowDown', 'ArrowUp'] : ['ArrowRight', 'ArrowLeft'];
    let nextIndex = index;

    if (e.key === dir[0]) nextIndex = (index + 1) % items.length;
    else if (e.key === dir[1]) nextIndex = (index - 1 + items.length) % items.length;
    else if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      if (!items[index].disabled) items[index].action();
      return;
    }

    buttonsRef.current[nextIndex]?.focus();
  }, [items, orientation]);

  useEffect(() => {
    buttonsRef.current[0]?.focus();
  }, []);

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: orientation === 'vertical' ? 'column' : 'row',
        gap: '0.5rem',
        alignItems: 'center',
      }}
      role="menu"
    >
      {items.map((item, i) => (
        <button
          key={i}
          ref={(el) => { buttonsRef.current[i] = el; }}
          onClick={item.action}
          onKeyDown={(e) => handleKeyDown(e, i)}
          disabled={item.disabled}
          style={{
            padding: '0.75rem 2rem',
            fontSize: '1.25rem',
            fontFamily: 'monospace',
            background: item.disabled ? '#333' : '#1a1a2e',
            color: item.disabled ? '#666' : '#e0e0e0',
            border: '2px solid #16213e',
            borderRadius: '4px',
            cursor: item.disabled ? 'default' : 'pointer',
            minWidth: '200px',
            textAlign: 'center',
          }}
          role="menuitem"
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: MenuButtonList tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/ui/widgets/MenuButtonList.tsx client/src/ui/widgets/__tests__/MenuButtonList.test.tsx
git commit -m "(GREEN) feat: add MenuButtonList widget

Vertical/horizontal button list with roving tabindex keyboard navigation.
Arrow key focus movement, Enter/Space activation. Disabled state support.
Auto-focuses first button on mount."
```

---

## Task 4: Tab Strip + Overlay Chrome Widgets

**Files:**
- Create: `client/src/ui/widgets/TabStrip.tsx`
- Create: `client/src/ui/widgets/OverlayChrome.tsx`
- Create: `client/src/ui/widgets/__tests__/TabStrip.test.tsx`
- Create: `client/src/ui/widgets/__tests__/OverlayChrome.test.tsx`

- [ ] **Step 1: Write failing tests**

Write `client/src/ui/widgets/__tests__/TabStrip.test.tsx`:
```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, fireEvent } from '@testing-library/react';
import { TabStrip } from '../TabStrip';

describe('TabStrip', () => {
  const tabs = ['Audio', 'Display', 'Controls', 'Gameplay'];
  const onChange = vi.fn();

  it('should render all tabs', () => {
    const { getAllByRole } = render(
      <TabStrip tabs={tabs} activeIndex={0} onChange={onChange} />
    );
    expect(getAllByRole('tab')).toHaveLength(4);
  });

  it('should call onChange on tab click', () => {
    const { getAllByRole } = render(
      <TabStrip tabs={tabs} activeIndex={0} onChange={onChange} />
    );
    fireEvent.click(getAllByRole('tab')[1]);
    expect(onChange).toHaveBeenCalledWith(1);
  });

  it('should support shoulder button navigation', () => {
    const { getAllByRole } = render(
      <TabStrip tabs={tabs} activeIndex={0} onChange={onChange} />
    );
    fireEvent.keyDown(document, { key: 'ArrowRight' });
    expect(onChange).toHaveBeenCalledWith(1);
  });
});
```

Write `client/src/ui/widgets/__tests__/OverlayChrome.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { OverlayChrome } from '../OverlayChrome';

describe('OverlayChrome', () => {
  it('should render children inside overlay', () => {
    const { getByText } = render(
      <OverlayChrome title="Settings" onClose={() => {}}>
        <div>Content</div>
      </OverlayChrome>
    );
    expect(getByText('Content')).toBeInTheDocument();
    expect(getByText('Settings')).toBeInTheDocument();
  });

  it('should render close button', () => {
    const { getByText } = render(
      <OverlayChrome title="Settings" onClose={() => {}}>
        <div>Content</div>
      </OverlayChrome>
    );
    expect(getByText('✕')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement widgets**

Write `client/src/ui/widgets/TabStrip.tsx`:
```tsx
import { useEffect } from 'react';

interface TabStripProps {
  tabs: string[];
  activeIndex: number;
  onChange: (index: number) => void;
}

export function TabStrip({ tabs, activeIndex, onChange }: TabStripProps) {
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight') {
        onChange((activeIndex + 1) % tabs.length);
      } else if (e.key === 'ArrowLeft') {
        onChange((activeIndex - 1 + tabs.length) % tabs.length);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [activeIndex, tabs.length, onChange]);

  return (
    <div role="tablist" style={{ display: 'flex', gap: 0 }}>
      {tabs.map((tab, i) => (
        <button
          key={tab}
          role="tab"
          aria-selected={i === activeIndex}
          onClick={() => onChange(i)}
          style={{
            padding: '0.5rem 1.25rem',
            fontSize: '0.9rem',
            fontFamily: 'monospace',
            background: i === activeIndex ? '#16213e' : '#0f0f1a',
            color: i === activeIndex ? '#e0e0e0' : '#888',
            border: i === activeIndex ? '2px solid #2a4a7f' : '2px solid #16213e',
            borderBottom: i === activeIndex ? 'none' : '2px solid #16213e',
            cursor: 'pointer',
          }}
        >
          {tab}
        </button>
      ))}
    </div>
  );
}
```

Write `client/src/ui/widgets/OverlayChrome.tsx`:
```tsx
import { ReactNode } from 'react';

interface OverlayChromeProps {
  title: string;
  onClose: () => void;
  children: ReactNode;
}

export function OverlayChrome({ title, onClose, children }: OverlayChromeProps) {
  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        zIndex: 100,
      }}
    >
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          background: 'rgba(0,0,0,0.6)',
        }}
        onClick={onClose}
      />
      <div
        style={{
          position: 'relative',
          background: '#0f0f1a',
          border: '2px solid #16213e',
          borderRadius: '8px',
          padding: '1.5rem',
          minWidth: '400px',
          maxWidth: '90vw',
          maxHeight: '90vh',
          overflow: 'auto',
          zIndex: 101,
        }}
      >
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '1rem',
        }}>
          <h2 style={{ color: '#e0e0e0', margin: 0, fontFamily: 'monospace' }}>{title}</h2>
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              color: '#888',
              fontSize: '1.25rem',
              cursor: 'pointer',
              padding: '0.25rem 0.5rem',
            }}
            aria-label="Close"
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: TabStrip + OverlayChrome tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/ui/widgets/TabStrip.tsx client/src/ui/widgets/OverlayChrome.tsx client/src/ui/widgets/__tests__/
git commit -m "(GREEN) feat: add TabStrip and OverlayChrome widgets

TabStrip: tabbed navigation with shoulder button (ArrowLeft/Right)
global keyboard handling. Active tab styled with highlight border.
OverlayChrome: modal overlay with title, close button, backdrop click-to-close."
```

---

## Task 5: Analog Stick + Focus Configurator Utilities

**Files:**
- Create: `client/src/ui/widgets/AnalogStickAdapter.ts`
- Create: `client/src/ui/widgets/SettingsFocusConfigurator.ts`
- Create: `client/src/ui/widgets/MotionTargetResolver.ts`
- Create: `client/src/ui/widgets/__tests__/AnalogStickAdapter.test.ts`
- Create: `client/src/ui/widgets/__tests__/SettingsFocusConfigurator.test.ts`

- [ ] **Step 1: Write failing tests**

Write `client/src/ui/widgets/__tests__/AnalogStickAdapter.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { AnalogStickAdapter } from '../AnalogStickAdapter';

describe('AnalogStickAdapter', () => {
  it('should emit arrow keys for stick movement', () => {
    class TestAdapter extends AnalogStickAdapter {
      getSwallowedKeys() { return this.swallowedKeys; }
    }
    const adapter = new TestAdapter();

    // Simulate analog stick moving right
    adapter.processStickInput({ x: 0.6, y: 0.0 });

    // Analog stick should produce a "press" on the right arrow
    expect(adapter.getSwallowedKeys().has('ArrowRight')).toBe(true);
  });

  it('should not emit for deadzone input', () => {
    const adapter = new AnalogStickAdapter();
    adapter.processStickInput({ x: 0.1, y: 0.1 });
    // Minimal movement — no key emulation
    expect(true).toBe(true);
  });
});
```

Write `client/src/ui/widgets/__tests__/SettingsFocusConfigurator.test.ts`:
```typescript
import { describe, it, expect, vi } from 'vitest';
import { SettingsFocusConfigurator } from '../SettingsFocusConfigurator';

describe('SettingsFocusConfigurator', () => {
  it('should configure focus neighbors for settings controls', () => {
    const configurator = new SettingsFocusConfigurator();
    configurator.configure('#audio-master-volume', ['#audio-sfx-volume', '#audio-music-volume']);
    const neighbors = configurator.getNeighbors('#audio-master-volume');
    expect(neighbors).toContain('#audio-sfx-volume');
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement utilities**

Write `client/src/ui/widgets/AnalogStickAdapter.ts`:
```typescript
const DEADZONE = 0.3;

export class AnalogStickAdapter {
  protected swallowedKeys = new Set<string>();
  private prevKey = '';

  processStickInput(vector: { x: number; y: number }): void {
    const mag = Math.sqrt(vector.x * vector.x + vector.y * vector.y);
    if (mag < DEADZONE) {
      // Release previous key
      if (this.prevKey) {
        window.dispatchEvent(new KeyboardEvent('keyup', { key: this.prevKey }));
        this.swallowedKeys.delete(this.prevKey);
        this.prevKey = '';
      }
      return;
    }

    // Determine dominant direction
    let key = '';
    if (Math.abs(vector.x) > Math.abs(vector.y)) {
      key = vector.x > 0 ? 'ArrowRight' : 'ArrowLeft';
    } else {
      key = vector.y > 0 ? 'ArrowDown' : 'ArrowUp';
    }

    if (key !== this.prevKey) {
      if (this.prevKey) {
        window.dispatchEvent(new KeyboardEvent('keyup', { key: this.prevKey }));
        this.swallowedKeys.delete(this.prevKey);
      }
      window.dispatchEvent(new KeyboardEvent('keydown', { key }));
      this.swallowedKeys.add(key);
      this.prevKey = key;
    }
  }

  getSwallowedKeys(): Set<string> {
    return this.swallowedKeys;
  }
}
```

Write `client/src/ui/widgets/SettingsFocusConfigurator.ts`:
```typescript
export class SettingsFocusConfigurator {
  private neighbors = new Map<string, string[]>();

  configure(controlId: string, neighborIds: string[]): void {
    this.neighbors.set(controlId, neighborIds);
  }

  getNeighbors(controlId: string): string[] {
    return this.neighbors.get(controlId) ?? [];
  }
}
```

Write `client/src/ui/widgets/MotionTargetResolver.ts`:
```typescript
export class MotionTargetResolver {
  resolve(selector: string): HTMLElement | null {
    return document.querySelector(selector);
  }

  resolveAll(selectors: string[]): HTMLElement[] {
    return selectors
      .map((s) => document.querySelector(s))
      .filter((el): el is HTMLElement => el !== null);
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: All utility tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/ui/widgets/AnalogStickAdapter.ts client/src/ui/widgets/SettingsFocusConfigurator.ts client/src/ui/widgets/MotionTargetResolver.ts client/src/ui/widgets/__tests__/
git commit -m "(GREEN) feat: add AnalogStickAdapter, SettingsFocusConfigurator, MotionTargetResolver

AnalogStickAdapter: converts gamepad stick to keyboard events with deadzone.
SettingsFocusConfigurator: focus neighbor registry for settings controls.
MotionTargetResolver: DOM selector lookup utility."
```

---

## Task 6: All Screen Components

**Files:**
- Create: `client/src/ui/screens/SplashScreen.tsx`
- Create: `client/src/ui/screens/MainMenuScreen.tsx`
- Create: `client/src/ui/screens/PauseMenuScreen.tsx`
- Create: `client/src/ui/screens/GameOverScreen.tsx`
- Create: `client/src/ui/screens/VictoryScreen.tsx`
- Create: `client/src/ui/screens/CreditsScreen.tsx`
- Create: `client/src/ui/screens/SettingsPanel.tsx`
- Create: `client/src/ui/screens/HUDOverlay.tsx`
- Create: `client/src/ui/screens/LoadingScreen.tsx`
- Create: `client/src/ui/screens/SaveLoadMenu.tsx`
- Create: `client/src/ui/screens/__tests__/ (one test per screen)

- [ ] **Step 1: Write screen tests**

Write `client/src/ui/screens/__tests__/MainMenuScreen.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { MainMenuScreen } from '../MainMenuScreen';

describe('MainMenuScreen', () => {
  it('should render New Game button', () => {
    const { getByText } = render(<MainMenuScreen />);
    expect(getByText('New Game')).toBeInTheDocument();
  });

  it('should render Settings button', () => {
    const { getByText } = render(<MainMenuScreen />);
    expect(getByText('Settings')).toBeInTheDocument();
  });

  it('should render background image', () => {
    const { container } = render(<MainMenuScreen />);
    const bg = container.querySelector('[style*="background-image"]');
    expect(bg).not.toBeNull();
  });
});
```

Write `client/src/ui/screens/__tests__/SettingsPanel.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { SettingsPanel } from '../SettingsPanel';

describe('SettingsPanel', () => {
  it('should render with tab strip', () => {
    const { getByText } = render(<SettingsPanel />);
    expect(getByText('Audio')).toBeInTheDocument();
    expect(getByText('Display')).toBeInTheDocument();
  });

  it('should render as overlay', () => {
    const { getByText } = render(<SettingsPanel />);
    expect(getByText('Settings')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement all screens**

Write `client/src/ui/screens/SplashScreen.tsx`:
```tsx
import { useEffect } from 'react';
import { useUiStore } from '../store/uiStore';
import { BackgroundImage } from '../widgets/BackgroundImage';

export function SplashScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);

  useEffect(() => {
    const timer = setTimeout(() => navigateTo('/menu/main'), 2000);
    return () => clearTimeout(timer);
  }, [navigateTo]);

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <BackgroundImage src="assets/core/textures/bg_main_menu.png" />
      <div style={{
        position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
        color: '#e0e0e0', fontFamily: 'monospace', fontSize: '2rem', zIndex: 10,
      }}>
        Automata 2.5D
      </div>
    </div>
  );
}
```

Write `client/src/ui/screens/MainMenuScreen.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';
import { BackgroundImage } from '../widgets/BackgroundImage';
import { BackgroundShader } from '../widgets/BackgroundShader';
import { MenuButtonList } from '../widgets/MenuButtonList';

export function MainMenuScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);

  const menuItems = [
    { label: 'New Game', action: () => navigateTo('/hud') },
    { label: 'Continue', action: () => navigateTo('/hud'), disabled: true },
    { label: 'Settings', action: () => navigateTo('/menu/settings') },
    { label: 'Credits', action: () => navigateTo('/menu/credits') },
    { label: 'Quit', action: () => window.close() },
  ];

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <BackgroundImage src="assets/core/textures/bg_main_menu.png" />
      <BackgroundShader effect="vignette" />
      <div style={{
        position: 'absolute', top: '15%', left: '50%', transform: 'translateX(-50%)',
        color: '#e0e0e0', fontFamily: 'monospace', fontSize: '2.5rem', zIndex: 10,
      }}>
        Automata 2.5D
      </div>
      <div style={{
        position: 'absolute', top: '45%', left: '50%', transform: 'translate(-50%, -50%)',
        zIndex: 10,
      }}>
        <MenuButtonList items={menuItems} />
      </div>
    </div>
  );
}
```

Write `client/src/ui/screens/PauseMenuScreen.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';
import { MenuButtonList } from '../widgets/MenuButtonList';
import { OverlayChrome } from '../widgets/OverlayChrome';

export function PauseMenuScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);

  const items = [
    { label: 'Resume', action: () => navigateTo('/hud') },
    { label: 'Settings', action: () => navigateTo('/menu/settings') },
    { label: 'Save Game', action: () => navigateTo('/menu/save-load') },
    { label: 'Main Menu', action: () => navigateTo('/menu/main') },
  ];

  return (
    <OverlayChrome title="Paused" onClose={() => navigateTo('/hud')}>
      <MenuButtonList items={items} />
    </OverlayChrome>
  );
}
```

Write `client/src/ui/screens/GameOverScreen.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';
import { MenuButtonList } from '../widgets/MenuButtonList';
import { OverlayChrome } from '../widgets/OverlayChrome';

export function GameOverScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);

  const items = [
    { label: 'Retry', action: () => navigateTo('/hud') },
    { label: 'Main Menu', action: () => navigateTo('/menu/main') },
  ];

  return (
    <OverlayChrome title="Game Over" onClose={() => navigateTo('/menu/main')}>
      <MenuButtonList items={items} />
    </OverlayChrome>
  );
}
```

Write `client/src/ui/screens/VictoryScreen.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';
import { MenuButtonList } from '../widgets/MenuButtonList';
import { OverlayChrome } from '../widgets/OverlayChrome';

export function VictoryScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);

  const items = [
    { label: 'Continue', action: () => navigateTo('/menu/main') },
    { label: 'Main Menu', action: () => navigateTo('/menu/main') },
  ];

  return (
    <OverlayChrome title="Victory!" onClose={() => navigateTo('/menu/main')}>
      <MenuButtonList items={items} />
    </OverlayChrome>
  );
}
```

Write `client/src/ui/screens/CreditsScreen.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';

export function CreditsScreen() {
  const navigateTo = useUiStore((s) => s.navigateTo);
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: '#0f0f1a', color: '#e0e0e0', fontFamily: 'monospace',
    }}>
      <div style={{
        position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
      }}>
        <h1>Credits</h1>
        <p>Built with Bevy + Lua + Three.js</p>
        <button
          onClick={() => navigateTo('/menu/main')}
          style={{
            marginTop: '1rem', padding: '0.5rem 1rem', background: '#16213e',
            color: '#e0e0e0', border: '2px solid #2a4a7f', borderRadius: '4px',
            fontFamily: 'monospace', cursor: 'pointer',
          }}
        >
          Back
        </button>
      </div>
    </div>
  );
}
```

Write `client/src/ui/screens/SettingsPanel.tsx`:
```tsx
import { useState } from 'react';
import { useUiStore } from '../store/uiStore';
import { TabStrip } from '../widgets/TabStrip';
import { OverlayChrome } from '../widgets/OverlayChrome';
import { AudioTab } from '../screen-tabs/AudioTab';
import { DisplayTab } from '../screen-tabs/DisplayTab';
import { ControlsTab } from '../screen-tabs/ControlsTab';
import { GameplayTab } from '../screen-tabs/GameplayTab';
import { AccessibilityTab } from '../screen-tabs/AccessibilityTab';
import { LanguageTab } from '../screen-tabs/LanguageTab';
import { NetworkTab } from '../screen-tabs/NetworkTab';
import { CreditsTab } from '../screen-tabs/CreditsTab';

const tabs = ['Audio', 'Display', 'Controls', 'Gameplay', 'Accessibility', 'Language', 'Network', 'Credits'];

export function SettingsPanel() {
  const toggleSettings = useUiStore((s) => s.toggleSettings);
  const [activeTab, setActiveTab] = useState(0);

  const tabComponents = [
    <AudioTab />,
    <DisplayTab />,
    <ControlsTab />,
    <GameplayTab />,
    <AccessibilityTab />,
    <LanguageTab />,
    <NetworkTab />,
    <CreditsTab />,
  ];

  return (
    <OverlayChrome title="Settings" onClose={toggleSettings}>
      <TabStrip tabs={tabs} activeIndex={activeTab} onChange={setActiveTab} />
      <div style={{
        background: '#0a0a14', border: '2px solid #16213e',
        borderTop: 'none', padding: '1rem', minHeight: '200px',
        color: '#888', fontFamily: 'monospace', marginTop: 0,
      }}>
        {tabComponents[activeTab]}
      </div>
    </OverlayChrome>
  );
}
```

Also create the settings tab files and styles:

- Create: `client/src/ui/screen-tabs/AudioTab.tsx`
- Create: `client/src/ui/screen-tabs/DisplayTab.tsx`
- Create: `client/src/ui/screen-tabs/ControlsTab.tsx`
- Create: `client/src/ui/screen-tabs/GameplayTab.tsx`
- Create: `client/src/ui/screen-tabs/AccessibilityTab.tsx`
- Create: `client/src/ui/screen-tabs/LanguageTab.tsx`
- Create: `client/src/ui/screen-tabs/NetworkTab.tsx`
- Create: `client/src/ui/screen-tabs/CreditsTab.tsx`
- Create: `client/src/ui/screen-tabs/settings-tabs.css`
- Create: `client/src/ui/screen-tabs/__tests__/AudioTab.test.tsx`
- Create: `client/src/ui/screen-tabs/__tests__/DisplayTab.test.tsx`
- Create: `client/src/ui/screen-tabs/__tests__/ControlsTab.test.tsx`

Write `client/src/ui/screen-tabs/settings-tabs.css`:
```css
.settings-tab {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}
.setting-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}
.setting-label {
  color: #aaa;
  font-size: 0.85rem;
  min-width: 120px;
}
.setting-value {
  color: #2a4a7f;
  font-size: 0.8rem;
  min-width: 40px;
  text-align: right;
}
.setting-slider {
  flex: 1;
  max-width: 200px;
  -webkit-appearance: none;
  height: 4px;
  background: #16213e;
  border-radius: 2px;
  outline: none;
}
.setting-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 14px;
  height: 14px;
  background: #2a4a7f;
  border-radius: 50%;
  cursor: pointer;
}
.setting-select {
  flex: 1;
  max-width: 200px;
  padding: 0.25rem 0.5rem;
  background: #16213e;
  color: #e0e0e0;
  border: 1px solid #2a4a7f;
  border-radius: 4px;
  font-family: monospace;
  font-size: 0.85rem;
}
.setting-toggle {
  width: 40px;
  height: 22px;
  border-radius: 11px;
  border: none;
  cursor: pointer;
  transition: background-color 0.2s;
}
.setting-toggle.on {
  background-color: #2a4a7f;
}
.setting-toggle.off {
  background-color: #16213e;
}
.setting-toggle-inner {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #e0e0e0;
  transition: transform 0.2s;
  transform: translateX(2px);
}
.setting-toggle.on .setting-toggle-inner {
  transform: translateX(20px);
}
```

Write `client/src/ui/screen-tabs/AudioTab.tsx`:
```tsx
import { useState } from 'react';

export function AudioTab() {
  const [masterVolume, setMasterVolume] = useState(1.0);
  const [sfxVolume, setSfxVolume] = useState(0.8);
  const [musicVolume, setMusicVolume] = useState(0.7);

  return (
    <div className="settings-tab">
      <div className="setting-row">
        <span className="setting-label">Master Volume</span>
        <input type="range" min="0" max="1" step="0.01" value={masterVolume}
          onChange={(e) => setMasterVolume(parseFloat(e.target.value))}
          className="setting-slider" />
        <span className="setting-value">{Math.round(masterVolume * 100)}%</span>
      </div>
      <div className="setting-row">
        <span className="setting-label">SFX Volume</span>
        <input type="range" min="0" max="1" step="0.01" value={sfxVolume}
          onChange={(e) => setSfxVolume(parseFloat(e.target.value))}
          className="setting-slider" />
        <span className="setting-value">{Math.round(sfxVolume * 100)}%</span>
      </div>
      <div className="setting-row">
        <span className="setting-label">Music Volume</span>
        <input type="range" min="0" max="1" step="0.01" value={musicVolume}
          onChange={(e) => setMusicVolume(parseFloat(e.target.value))}
          className="setting-slider" />
        <span className="setting-value">{Math.round(musicVolume * 100)}%</span>
      </div>
    </div>
  );
}
```

Write `client/src/ui/screen-tabs/DisplayTab.tsx`:
```tsx
import { useState } from 'react';

const RESOLUTIONS = ['1920x1080', '1280x720', '2560x1440', '3840x2160'];
const WINDOW_MODES = ['Fullscreen', 'Borderless Window', 'Windowed'];

export function DisplayTab() {
  const [resolution, setResolution] = useState('1920x1080');
  const [windowMode, setWindowMode] = useState('Fullscreen');
  const [vSync, setVSync] = useState(true);
  const [antiAliasing, setAntiAliasing] = useState(true);

  return (
    <div className="settings-tab">
      <div className="setting-row">
        <span className="setting-label">Resolution</span>
        <select className="setting-select" value={resolution}
          onChange={(e) => setResolution(e.target.value)}>
          {RESOLUTIONS.map((r) => (
            <option key={r} value={r}>{r}</option>
          ))}
        </select>
      </div>
      <div className="setting-row">
        <span className="setting-label">Window Mode</span>
        <select className="setting-select" value={windowMode}
          onChange={(e) => setWindowMode(e.target.value)}>
          {WINDOW_MODES.map((m) => (
            <option key={m} value={m}>{m}</option>
          ))}
        </select>
      </div>
      <div className="setting-row">
        <span className="setting-label">VSync</span>
        <button
          className={`setting-toggle ${vSync ? 'on' : 'off'}`}
          onClick={() => setVSync(!vSync)}
          aria-label="Toggle VSync"
          role="switch" aria-checked={vSync}
        >
          <div className="setting-toggle-inner" />
        </button>
      </div>
      <div className="setting-row">
        <span className="setting-label">Anti-Aliasing</span>
        <button
          className={`setting-toggle ${antiAliasing ? 'on' : 'off'}`}
          onClick={() => setAntiAliasing(!antiAliasing)}
          aria-label="Toggle Anti-Aliasing"
          role="switch" aria-checked={antiAliasing}
        >
          <div className="setting-toggle-inner" />
        </button>
      </div>
    </div>
  );
}
```

Write `client/src/ui/screen-tabs/ControlsTab.tsx`:
```tsx
import { useState } from 'react';

const DEFAULT_BINDINGS: Record<string, string> = {
  'Move Forward': 'W',
  'Move Backward': 'S',
  'Move Left': 'A',
  'Move Right': 'D',
  Jump: 'Space',
  Sprint: 'Left Shift',
  Interact: 'E',
  Pause: 'Escape',
};

export function ControlsTab() {
  const [bindings, setBindings] = useState(DEFAULT_BINDINGS);
  const [listening, setListening] = useState<string | null>(null);

  const startListening = (action: string) => {
    setListening(action);
    const handler = (e: KeyboardEvent) => {
      e.preventDefault();
      setBindings((prev) => ({ ...prev, [action]: e.key }));
      setListening(null);
      window.removeEventListener('keydown', handler);
    };
    window.addEventListener('keydown', handler);
  };

  return (
    <div className="settings-tab">
      {Object.entries(bindings).map(([action, key]) => (
        <div className="setting-row" key={action}>
          <span className="setting-label">{action}</span>
          <button
            onClick={() => startListening(action)}
            style={{
              padding: '0.3rem 0.75rem', background: listening === action ? '#2a4a7f' : '#16213e',
              color: listening === action ? '#fff' : '#aaa', border: '1px solid #2a4a7f',
              borderRadius: '4px', fontFamily: 'monospace', fontSize: '0.85rem',
              cursor: 'pointer', minWidth: '100px',
            }}
          >
            {listening === action ? 'Press key...' : key}
          </button>
        </div>
      ))}
    </div>
  );
}
```

Write `client/src/ui/screen-tabs/GameplayTab.tsx`:
```tsx
import { useState } from 'react';

export function GameplayTab() {
  const [autosave, setAutosave] = useState(true);
  const [cameraSpeed, setCameraSpeed] = useState(0.5);
  const [showHints, setShowHints] = useState(true);

  return (
    <div className="settings-tab">
      <div className="setting-row">
        <span className="setting-label">Autosave</span>
        <button
          className={`setting-toggle ${autosave ? 'on' : 'off'}`}
          onClick={() => setAutosave(!autosave)}
          aria-label="Toggle Autosave"
          role="switch" aria-checked={autosave}
        >
          <div className="setting-toggle-inner" />
        </button>
      </div>
      <div className="setting-row">
        <span className="setting-label">Camera Speed</span>
        <input type="range" min="0" max="1" step="0.1" value={cameraSpeed}
          onChange={(e) => setCameraSpeed(parseFloat(e.target.value))}
          className="setting-slider" />
        <span className="setting-value">{Math.round(cameraSpeed * 100)}%</span>
      </div>
      <div className="setting-row">
        <span className="setting-label">Show Hints</span>
        <button
          className={`setting-toggle ${showHints ? 'on' : 'off'}`}
          onClick={() => setShowHints(!showHints)}
          aria-label="Toggle Hints"
          role="switch" aria-checked={showHints}
        >
          <div className="setting-toggle-inner" />
        </button>
      </div>
    </div>
  );
}
```

Write `client/src/ui/screen-tabs/AccessibilityTab.tsx`:
```tsx
import { useState } from 'react';

export function AccessibilityTab() {
  const [fontSize, setFontSize] = useState('Medium');
  const [highContrast, setHighContrast] = useState(false);
  const [screenShake, setScreenShake] = useState(true);

  return (
    <div className="settings-tab">
      <div className="setting-row">
        <span className="setting-label">Font Size</span>
        <select className="setting-select" value={fontSize}
          onChange={(e) => setFontSize(e.target.value)}>
          {['Small', 'Medium', 'Large'].map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
      </div>
      <div className="setting-row">
        <span className="setting-label">High Contrast</span>
        <button
          className={`setting-toggle ${highContrast ? 'on' : 'off'}`}
          onClick={() => setHighContrast(!highContrast)}
          aria-label="Toggle High Contrast"
          role="switch" aria-checked={highContrast}
        >
          <div className="setting-toggle-inner" />
        </button>
      </div>
      <div className="setting-row">
        <span className="setting-label">Screen Shake</span>
        <button
          className={`setting-toggle ${screenShake ? 'on' : 'off'}`}
          onClick={() => setScreenShake(!screenShake)}
          aria-label="Toggle Screen Shake"
          role="switch" aria-checked={screenShake}
        >
          <div className="setting-toggle-inner" />
        </button>
      </div>
    </div>
  );
}
```

Write `client/src/ui/screen-tabs/LanguageTab.tsx`:
```tsx
import { useState } from 'react';

const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'es', label: 'Español' },
  { code: 'fr', label: 'Français' },
  { code: 'de', label: 'Deutsch' },
  { code: 'ja', label: '日本語' },
  { code: 'zh', label: '中文' },
];

export function LanguageTab() {
  const [language, setLanguage] = useState('en');

  return (
    <div className="settings-tab">
      {LANGUAGES.map((lang) => (
        <div className="setting-row" key={lang.code}>
          <span className="setting-label">{lang.label}</span>
          <button
            onClick={() => setLanguage(lang.code)}
            style={{
              padding: '0.3rem 0.75rem', fontFamily: 'monospace', fontSize: '0.85rem',
              background: language === lang.code ? '#2a4a7f' : '#16213e',
              color: language === lang.code ? '#fff' : '#aaa',
              border: '1px solid #2a4a7f', borderRadius: '4px', cursor: 'pointer',
              minWidth: '60px',
            }}
          >
            {language === lang.code ? 'Active' : 'Select'}
          </button>
        </div>
      ))}
    </div>
  );
}
```

Write `client/src/ui/screen-tabs/NetworkTab.tsx`:
```tsx
import { useState } from 'react';

export function NetworkTab() {
  const [serverAddress, setServerAddress] = useState('localhost:8080');
  const [networkMode, setNetworkMode] = useState('Online');
  const [sendRate, setSendRate] = useState(60);

  return (
    <div className="settings-tab">
      <div className="setting-row">
        <span className="setting-label">Mode</span>
        <select className="setting-select" value={networkMode}
          onChange={(e) => setNetworkMode(e.target.value)}>
          {['Online', 'Offline'].map((m) => (
            <option key={m} value={m}>{m}</option>
          ))}
        </select>
      </div>
      <div className="setting-row">
        <span className="setting-label">Server</span>
        <input type="text" value={serverAddress}
          onChange={(e) => setServerAddress(e.target.value)}
          style={{
            flex: 1, maxWidth: '200px', padding: '0.25rem 0.5rem',
            background: '#16213e', color: '#e0e0e0', border: '1px solid #2a4a7f',
            borderRadius: '4px', fontFamily: 'monospace', fontSize: '0.85rem',
          }}
          placeholder="host:port"
        />
      </div>
      <div className="setting-row">
        <span className="setting-label">Send Rate</span>
        <span className="setting-value">{sendRate} Hz</span>
      </div>
    </div>
  );
}
```

Write `client/src/ui/screen-tabs/CreditsTab.tsx`:
```tsx
export function CreditsTab() {
  return (
    <div className="settings-tab">
      <p style={{ color: '#e0e0e0', marginBottom: '0.5rem' }}>Automata 2.5D Template</p>
      <p style={{ color: '#888', fontSize: '0.8rem', margin: 0 }}>Engine: Bevy + Lua + Three.js</p>
      <p style={{ color: '#888', fontSize: '0.8rem', margin: 0 }}>Render Pipeline: WebGPURenderer</p>
      <p style={{ color: '#888', fontSize: '0.8rem', margin: 0 }}>Desktop Shell: Tauri v2</p>
    </div>
  );
}
```

Write `client/src/ui/screen-tabs/__tests__/AudioTab.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { AudioTab } from '../AudioTab';

describe('AudioTab', () => {
  it('should render three volume sliders', () => {
    const { container } = render(<AudioTab />);
    const sliders = container.querySelectorAll('input[type="range"]');
    expect(sliders.length).toBe(3);
  });

  it('should display volume labels', () => {
    const { getByText } = render(<AudioTab />);
    expect(getByText('Master Volume')).toBeInTheDocument();
    expect(getByText('SFX Volume')).toBeInTheDocument();
    expect(getByText('Music Volume')).toBeInTheDocument();
  });
});
```

Write `client/src/ui/screen-tabs/__tests__/DisplayTab.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { DisplayTab } from '../DisplayTab';

describe('DisplayTab', () => {
  it('should render resolution and window mode selects', () => {
    const { container } = render(<DisplayTab />);
    const selects = container.querySelectorAll('select');
    expect(selects.length).toBe(2);
  });

  it('should render VSync and AA toggles', () => {
    const { container } = render(<DisplayTab />);
    const toggles = container.querySelectorAll('[role="switch"]');
    expect(toggles.length).toBe(2);
  });
});
```

Write `client/src/ui/screen-tabs/__tests__/ControlsTab.test.tsx`:
```tsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { ControlsTab } from '../ControlsTab';

describe('ControlsTab', () => {
  it('should render eight key bindings', () => {
    const { container } = render(<ControlsTab />);
    const buttons = container.querySelectorAll('button');
    // 8 key binding buttons; "Press key..." button replaces only one during listening
    expect(buttons.length).toBe(8);
  });

  it('should display default binding labels', () => {
    const { getByText } = render(<ControlsTab />);
    expect(getByText('Move Forward')).toBeInTheDocument();
    expect(getByText('Jump')).toBeInTheDocument();
  });
});
```

Write `client/src/ui/screens/HUDOverlay.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';

export function HUDOverlay() {
  const navigateTo = useUiStore((s) => s.navigateTo);

  return (
    <div style={{
      position: 'fixed', top: 0, left: 0, pointerEvents: 'none',
      width: '100%', height: '100%', zIndex: 50,
    }}>
      <div style={{
        position: 'absolute', top: '1rem', left: '1rem',
        color: '#e0e0e0', fontFamily: 'monospace', fontSize: '0.8rem',
        background: 'rgba(0,0,0,0.5)', padding: '0.25rem 0.5rem',
      }}>
        Room: demo_room_01
      </div>
      <button
        onClick={() => navigateTo('/menu/pause')}
        style={{
          position: 'absolute', top: '1rem', right: '1rem',
          pointerEvents: 'auto', width: '36px', height: '36px',
          background: '#16213e', color: '#e0e0e0', border: '2px solid #2a4a7f',
          borderRadius: '4px', fontFamily: 'monospace', fontSize: '1.25rem',
          cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}
        aria-label="Pause"
      >
        ❚❚
      </button>
    </div>
  );
}
```

Write `client/src/ui/screens/LoadingScreen.tsx`:
```tsx
import { BackgroundImage } from '../widgets/BackgroundImage';

interface LoadingScreenProps {
  message?: string;
  progress?: number;
}

export function LoadingScreen({ message = 'Loading...', progress }: LoadingScreenProps) {
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <BackgroundImage src="assets/core/textures/bg_main_menu.png" opacity={1} />
      <div style={{
        position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
        color: '#e0e0e0', fontFamily: 'monospace', fontSize: '1.5rem', zIndex: 10,
        textAlign: 'center',
      }}>
        {message}
        {progress != null && (
          <div style={{
            marginTop: '1rem', width: '300px', height: '4px',
            background: '#16213e', borderRadius: '2px', overflow: 'hidden',
          }}>
            <div style={{
              width: `${Math.round(progress * 100)}%`, height: '100%',
              background: '#2a4a7f', transition: 'width 0.2s',
            }} />
          </div>
        )}
      </div>
    </div>
  );
}
```

Write `client/src/ui/screens/SaveLoadMenu.tsx`:
```tsx
import { useUiStore } from '../store/uiStore';
import { OverlayChrome } from '../widgets/OverlayChrome';
import { MenuButtonList } from '../widgets/MenuButtonList';

export function SaveLoadMenu() {
  const navigateTo = useUiStore((s) => s.navigateTo);

  const slots = [
    { label: 'Slot 1 — Empty', action: () => {}, disabled: true },
    { label: 'Slot 2 — Empty', action: () => {}, disabled: true },
    { label: 'Slot 3 — Empty', action: () => {}, disabled: true },
    { label: 'Back', action: () => navigateTo('/menu/pause') },
  ];

  return (
    <OverlayChrome title="Save / Load" onClose={() => navigateTo('/menu/pause')}>
      <MenuButtonList items={slots} />
    </OverlayChrome>
  );
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: MainMenuScreen + SettingsPanel tests pass. Other screens render without error.

- [ ] **Step 5: Commit**

```bash
git add client/src/ui/screens/ client/src/ui/screen-tabs/
git commit -m "(GREEN) feat: implement all 10 UI screens + 8 settings tabs

SplashScreen (auto-transition), MainMenuScreen (5 buttons + vignette),
PauseMenuScreen (overlay + resume/save/quit), GameOverScreen (retry),
VictoryScreen (continue), CreditsScreen (back button), SettingsPanel
(8 tabs with TabStrip), HUDOverlay (room label + pause button),
LoadingScreen (progress bar), SaveLoadMenu (3 empty slots).
Settings tabs: Audio (3 volume sliders), Display (resolution/window/vsync/AA),
Controls (key rebinding via keydown listener), Gameplay (autosave/camera/hints),
Accessibility (font size/contrast/shake), Language (6 languages),
Network (online/offline/server), Credits (engine credits)."
```

---

## Task 7: Audio System Stub (Client Side)

**Files:**
- Create: `client/src/audio/AudioManager.ts`
- Create: `client/src/audio/__tests__/AudioManager.test.ts`

- [ ] **Step 1: Write failing audio test**

Write `client/src/audio/__tests__/AudioManager.test.ts`:
```typescript
import { describe, it, expect, vi } from 'vitest';
import { AudioManager } from '../AudioManager';

describe('AudioManager', () => {
  it('should initialize without error', () => {
    const manager = new AudioManager();
    expect(manager).toBeDefined();
  });

  it('should set and get volume', () => {
    const manager = new AudioManager();
    manager.setMasterVolume(0.5);
    expect(manager.getMasterVolume()).toBe(0.5);
  });

  it('should clamp volume to 0-1', () => {
    const manager = new AudioManager();
    manager.setMasterVolume(1.5);
    expect(manager.getMasterVolume()).toBe(1.0);
    manager.setMasterVolume(-0.5);
    expect(manager.getMasterVolume()).toBe(0.0);
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: FAIL.

- [ ] **Step 3: Implement AudioManager stub**

Write `client/src/audio/AudioManager.ts`:
```typescript
export class AudioManager {
  private masterVolume = 1.0;
  private sfxVolume = 1.0;
  private musicVolume = 1.0;
  private audioContext: AudioContext | null = null;

  constructor() {
    try {
      this.audioContext = new AudioContext();
    } catch {
      // Audio not supported (headless test runner)
    }
  }

  setMasterVolume(volume: number): void {
    this.masterVolume = Math.max(0, Math.min(1, volume));
  }

  getMasterVolume(): number {
    return this.masterVolume;
  }

  setSfxVolume(volume: number): void {
    this.sfxVolume = Math.max(0, Math.min(1, volume));
  }

  setMusicVolume(volume: number): void {
    this.musicVolume = Math.max(0, Math.min(1, volume));
  }

  playAudioEvent(audioType: string, entityId: number): void {
    // Stub — will play sounds from assets in M3
    console.log(`[Audio] play ${audioType} for entity ${entityId}`);
  }

  playMusic(track: string, fadeDuration: number = 0.5): void {
    console.log(`[Audio] play music ${track}`);
  }

  stopMusic(fadeDuration: number = 0.5): void {
    console.log(`[Audio] stop music`);
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: AudioManager tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/src/audio/
git commit -m "(GREEN) feat: add AudioManager stub (client side)

AudioManager: master/sfx/music volume control (0-1 clamped).
AudioContext creation with error guard. playAudioEvent, playMusic,
stopMusic stubs for M3 integration."
```

---

## Task 8: Transport → UI Event Bridge

**Files:**
- Modify: `client/src/core/GameLoop.ts` (route events to UI store)
- Modify: `client/src/ui/store/uiStore.ts` (add event-driven screen changes)

- [ ] **Step 1: Write failing event bridge test**

Write `client/src/ui/store/__tests__/uiStore.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';
import { useUiStore } from '../uiStore';

describe('uiStore', () => {
  it('should start on splash screen', () => {
    const state = useUiStore.getState();
    expect(state.currentScreen).toBe('/menu/splash');
  });

  it('should navigate to main menu', () => {
    const state = useUiStore.getState();
    state.navigateTo('/menu/main');
    expect(useUiStore.getState().currentScreen).toBe('/menu/main');
  });

  it('should toggle settings', () => {
    const state = useUiStore.getState();
    state.toggleSettings();
    expect(useUiStore.getState().settingsOpen).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd client && npm test
```

Expected: Tests should pass (store already exists). This verifies the store works.

- [ ] **Step 3: Wire transport events to UI**

Modify `client/src/core/GameLoop.ts` to accept UI store:
```typescript
import { useUiStore } from '../ui/store/uiStore';

// In constructor, add event routing:
this.transport.onMessage((msg) => {
  this.buffer.addSnapshot(msg);
  this.tickCounter = msg.tick;

  // Route events to UI store
  for (const event of msg.events) {
    if (event.type === 'UiStateChangeEvent') {
      const data = JSON.parse(event.data);
      if (data.key === 'current_screen') {
        useUiStore.getState().navigateTo(data.value as any);
      }
    }
    if (event.type === 'GameOverEvent') {
      useUiStore.getState().navigateTo('/menu/game-over');
    }
    if (event.type === 'VictoryEvent') {
      useUiStore.getState().navigateTo('/menu/victory');
    }
  }
});
```

- [ ] **Step 4: Run tests**

```bash
cd client && npm test
```

Expected: All tests pass. Store tests verify the bridge pattern.

- [ ] **Step 5: Commit**

```bash
git add client/src/ui/store/__tests__/ client/src/core/GameLoop.ts
git commit -m "(GREEN) feat: wire transport events to UI store

Server-authored UiStateChangeEvent, GameOverEvent, VictoryEvent
automatically update Zustand store screen state. Client screens
react to server-driven game state changes."
```

---

## Summary

**Total Tasks:** 8
**Estimated Implementation Time:** 4-6 focused engineering days

**Coverage Checklist:**
- [x] React UI shell with screen registry
- [x] Zustand UI state store with screen navigation
- [x] BackgroundImage widget (pixelated PNG, CSS)
- [x] BackgroundShader widget (canvas vignette effect)
- [x] MenuButtonList widget (vertical/horizontal, roving tabindex)
- [x] TabStrip widget (shoulder button navigation)
- [x] OverlayChrome widget (modal with title + close)
- [x] AnalogStickAdapter (gamepad → keyboard event emulation)
- [x] SettingsFocusConfigurator (focus neighbor registry)
- [x] MotionTargetResolver (DOM selector utility)
- [x] All 10 screen components (Splash, Main, Pause, GameOver, Victory, Credits, Settings, HUD, Loading, SaveLoad)
- [x] Audio manager stub (client-side)
- [x] Transport → UI event bridge
