# Builder App UI Refresh Design

**Status:** Approved  
**Date:** 2026-07-24

## Goal

Refresh the Databricks Builder App with a cohesive, Solution
Builder-inspired workspace aesthetic while preserving all existing project,
conversation, skill, and configuration workflows.

## Direction

Use a balanced workspace density:

- compact global navigation and conversation sidebar
- generous space around chat content and the composer
- warm off-white surfaces in light mode
- deep graphite surfaces in dark mode
- Databricks red as a selective action and focus accent
- crisp borders, restrained shadows, and purposeful motion

The result should feel like a professional Databricks building surface rather
than a generic chatbot or decorative landing page.

## Theme architecture

Add a client-side theme provider with three user choices:

- `light`
- `dark`
- `system`

Persist the preference in `localStorage`. Resolve `system` through
`prefers-color-scheme`, listen for OS changes, apply the resolved `.dark` class
to the document root, and set `color-scheme` for native controls. Expose an
accessible theme control in the top bar.

Keep visual values in semantic CSS variables. Components consume semantic
tokens rather than branching on the selected theme.

## Surface scope

1. **Foundation**
   - semantic color, typography, radius, shadow, and focus tokens
   - theme provider and hook
   - reduced-motion and base scrollbar behavior
2. **Shared shell**
   - top bar, product identity, navigation, user identity, theme control
   - main layout backgrounds and responsive behavior
   - conversation sidebar, active states, and collapse behavior
3. **Home**
   - calmer product introduction
   - compact create-project workflow
   - clearer project cards and metadata hierarchy
4. **Project/chat**
   - clearer project and resource context
   - readable message measure and role distinction
   - compact tool/activity presentation
   - anchored, high-quality composer
   - preserve all existing streaming and configuration behavior
5. **Docs and overlays**
   - align documentation navigation/cards with the shared visual system
   - restyle Skills Explorer, loaders, buttons, inputs, and toasts

## Constraints

- No backend or API contract changes.
- No rewrite of ProjectPage state management.
- Preserve local and Databricks Apps behavior.
- Maintain responsive behavior and keyboard accessibility.
- Avoid adding a component framework; reuse Tailwind, Lucide, and existing
  primitives.
- Keep animation subtle and honor `prefers-reduced-motion`.

## Verification

- TypeScript typecheck and production build
- lint for changed frontend files
- visual checks at desktop and narrow viewport widths
- light, dark, and system preference checks, including persistence after reload
- interaction checks for project creation/rename/delete, conversation
  navigation, sidebar collapse, composer, settings, and Skills Explorer
- browser console check for runtime errors

