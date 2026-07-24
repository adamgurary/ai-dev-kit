# Builder App UI Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a cohesive Solution Builder-inspired workspace UI with a persisted light/dark/system theme while preserving every existing Builder App workflow.

**Architecture:** Add a single React theme provider that resolves and persists the user preference, then drive all surfaces through semantic CSS tokens. Refresh shared primitives and layout before restyling Home, Project/chat, Docs, and Skills Explorer; do not rewrite state management or backend contracts.

**Tech Stack:** React 18, TypeScript, Vite, Tailwind CSS, CSS custom properties, Lucide React, localStorage, `matchMedia`

---

### Task 1: Theme state and semantic design tokens

**Files:**
- Create: `client/src/contexts/ThemeContext.tsx`
- Modify: `client/src/main.tsx`
- Modify: `client/src/styles/globals.css`
- Test: `client/src/contexts/ThemeContext.test.tsx` if a test runner is added; otherwise verify with typecheck and browser

**Step 1: Define the theme contract**

Implement:

```ts
export type ThemePreference = 'light' | 'dark' | 'system';
export type ResolvedTheme = 'light' | 'dark';

interface ThemeContextValue {
  preference: ThemePreference;
  resolvedTheme: ResolvedTheme;
  setPreference: (theme: ThemePreference) => void;
}
```

Use the storage key `builder-app-theme`.

**Step 2: Resolve and apply the preference**

On mount:

1. Read and validate the stored preference.
2. Default to `system`.
3. Resolve `system` with `window.matchMedia('(prefers-color-scheme: dark)')`.
4. Toggle `document.documentElement.classList` with `.dark`.
5. Set `document.documentElement.style.colorScheme`.
6. Subscribe to OS changes only while preference is `system`.

**Step 3: Mount the provider**

Wrap the existing providers in `main.tsx` with `ThemeProvider` so the top bar,
toasts, pages, and overlays consume the same resolved state.

**Step 4: Replace global tokens**

Define semantic tokens for canvas, panel, elevated panel, subtle panel, text,
muted text, border, strong border, accent, accent hover, focus, shadows, and
code surfaces for both `:root` and `.dark`.

Add:

- `color-scheme` support
- visible `:focus-visible` treatment
- `prefers-reduced-motion` overrides
- selection and scrollbar styling
- a subtle workspace background texture that remains low contrast

**Step 5: Verify**

Run:

```bash
cd databricks-builder-app/client
npm run build:typecheck
```

Expected: TypeScript and Vite build pass.

---

### Task 2: Theme control and shared UI primitives

**Files:**
- Create: `client/src/components/ThemeSwitcher.tsx`
- Modify: `client/src/components/ui/Button.tsx`
- Modify: `client/src/components/ui/Input.tsx`
- Modify: `client/src/components/layout/TopBar.tsx`
- Modify: `client/src/App.tsx`

**Step 1: Build the three-way theme control**

Use Sun, Moon, and Monitor icons. Implement an accessible compact segmented
control with:

- `aria-label` on the group and each option
- visible selected state
- tooltips through `title`
- no hidden menu state

**Step 2: Refine Button and Input**

Keep existing props and variants. Update visual classes for:

- crisp 8px-ish radii
- reduced shadow use
- strong focus-visible ring
- consistent disabled states
- compact default heights suitable for a builder workspace

**Step 3: Refresh TopBar**

Create a compact product shell:

- Databricks mark + “Builder”
- project breadcrumb
- Projects / Docs navigation
- theme switcher
- compact user identity
- narrow-screen behavior that avoids overflow

**Step 4: Theme toasts**

Pass the resolved theme to Sonner and align toast colors with semantic tokens.

**Step 5: Verify**

Run `npm run build:typecheck`. In the browser, switch all three preferences,
reload, and confirm persistence.

---

### Task 3: Shared layout and conversation sidebar

**Files:**
- Modify: `client/src/components/layout/MainLayout.tsx`
- Modify: `client/src/components/layout/Sidebar.tsx`
- Modify: `client/src/components/FunLoader.tsx`

**Step 1: Refresh the app frame**

Replace flat full-screen fills with semantic canvas/panel layers. Keep existing
fixed-header and overflow behavior.

**Step 2: Restyle Sidebar**

Preserve all props and interactions. Update:

- compact New Chat action
- section label and conversation count
- flatter conversation rows
- clear but restrained active state
- accessible delete and collapse controls
- polished empty/loading states

**Step 3: Refine loader**

Use restrained Databricks-brand motion and honor reduced motion.

**Step 4: Verify**

Check expanded/collapsed sidebar, empty state, active conversation, delete
hover/focus, and light/dark contrast.

---

### Task 4: Home workspace

**Files:**
- Modify: `client/src/pages/HomePage.tsx`

**Step 1: Simplify the hero**

Replace the dominant animated mesh with a restrained workspace introduction.
Keep a subtle branded atmospheric layer, but prioritize project creation and
recent work.

**Step 2: Promote project creation**

Use a compact create-project panel with a clear label, helper text, and primary
action. Preserve form behavior and loading/error handling.

**Step 3: Redesign project cards**

Preserve create, open, rename, delete, sort, and metadata behavior. Use:

- consistent neutral cards
- a small deterministic color marker instead of full gradient decoration
- clearer title / conversation count / timestamp hierarchy
- actions visible on focus as well as hover

**Step 4: Verify**

Exercise create, rename, cancel rename, delete, sort, card navigation, empty
state, and loading state.

---

### Task 5: Project and chat workspace

**Files:**
- Modify: `client/src/pages/ProjectPage.tsx`
- Modify: `client/src/components/SkillsExplorer.tsx`

**Step 1: Refresh project context controls**

Restyle `ResourceDropdown` and `ConfigPanel` with compact semantic controls.
Preserve all selected cluster, warehouse, catalog, schema, and skill behavior.

**Step 2: Refresh message presentation**

Keep streaming/state code unchanged. Update visual hierarchy for:

- user messages
- assistant messages
- markdown/code blocks
- copy actions
- timestamps and status

Use a readable maximum measure rather than full-width chat text.

**Step 3: Refresh tool activity**

Keep `ToolsUsedBadge` and `ActivitySection` behavior. Present Skill, Bash, and
file operations as a compact execution timeline with clear running/error states.

**Step 4: Refresh the composer**

Create an anchored elevated composer with:

- strong focus state
- clear send/stop action
- concise context/status row
- existing keyboard behavior
- responsive width and safe-area spacing

**Step 5: Refresh Skills Explorer**

Align overlay, file tree, content pane, enabled controls, and close behavior
with the shared theme tokens.

**Step 6: Verify**

Test a new conversation, resumed conversation, streaming text, Skill and Bash
activity, stop action, config panel, sidebar selection, Skills Explorer, and
copy controls.

---

### Task 6: Documentation surface and responsive polish

**Files:**
- Modify: `client/src/pages/DocPage.tsx`
- Modify: `client/src/styles/globals.css`

**Step 1: Align Docs with the shared system**

Restyle navigation, architecture cards, code labels, and callouts without
changing the newly corrected CLI-only content.

**Step 2: Add responsive polish**

Verify layouts at approximately 1440px, 1024px, 768px, and 390px. Ensure:

- no top-bar overflow
- sidebars collapse or hide cleanly
- forms remain usable
- chat composer does not cover content
- docs remain navigable

**Step 3: Run static checks**

```bash
cd databricks-builder-app/client
npm run lint
npm run build:typecheck
```

Expected: both pass. If lint exposes pre-existing issues, distinguish those
from changed-file regressions.

**Step 4: Run browser verification**

Use the local app to check:

- light, dark, and system modes
- persisted preference after reload
- console errors
- desktop and mobile screenshots
- Home, Project, Docs, and Skills Explorer

**Step 5: Review the final diff**

Confirm there are no API/backend changes and no accidental behavior removals.
Commit the UI implementation only after browser verification succeeds.

