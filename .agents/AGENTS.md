# Project & Senior Engineering Rules

## 1. 5-Fold Deep Analysis & Rigor
- Before performing any code modifications or operations, analyze all requirements, edge cases, potential side effects, and architectural impacts 5 times deeply.
- Act as a senior, highly skilled, creative, and rigorous software engineer at all times.
- Proactively anticipate and resolve potential runtime bugs, lint warnings, layout overflows, and data anomalies.

## 2. Iterative 3-Cycle Roadmap Refinement
- For non-trivial engineering tasks:
  1. Draft an initial roadmap/plan.
  2. Evaluate and audit the plan with a strict, creative senior developer lens.
  3. Repeat the **Draft → Evaluate → Rewrite** cycle **3 times** until the implementation plan is fully optimized.
  4. Execute the refined plan with maximum precision.

## 3. No Laziness & Full Completion
- Fulfill 100% of user directives without cutting corners, skipping tasks, or using placeholder code.
- Always run static analysis (`flutter analyze`) and verify zero errors/warnings after making changes.

## 4. Surgical Edits & UI Preservation
- Always use targeted diffs/edits instead of full-file rewrites.
- Never overwrite, delete, or revert previously customized UI, merged components, or domain logic.

## 5. Safe & Targeted Git Commits (Multi-Agent Safe)
- After verifying changes with `flutter analyze`, commit the modified files with a clear, descriptive Git message.
- **Targeted Staging Only**: ALWAYS stage only the specific files modified by the task (e.g. `git add path/to/file.dart`). NEVER run blanket staging commands like `git add .`, `git add -A`, or `git commit -a` so ongoing work by other concurrent agents or human dev is never polluted or committed prematurely.
- **Strictly No Destructive Commands**: NEVER run `git reset --hard`, `git checkout .`, `git restore .`, or `git clean -fd` as they destroy uncommitted work from concurrent agents.

## 6. Ritmo Canonical Reference System (Cards, Sheets & UI Primitives)
When building, updating, or refactoring UI components across Ritmo, ALWAYS use the official canonical design primitives defined in `lib/core/widgets/ritmo/` and showcased in `lib/features/settings/presentation/cards_showcase_screen.dart`:
- **Master Hero Dashboard Card**: Use `RitmoNeuMasterCard` for top active realm, 24h dial, and time-block hero widgets (maintains the 3.2s ambient breathing halo).
- **Raised Module Cards**: Use `RitmoCard.neumorphic` with atomic sub-widgets (`RitmoCardHeader`, `RitmoCardTile`, `RitmoCardBadge`, `RitmoCardDivider`) for data modules and routines.
- **Selectable / Toggle Cards**: Use `RitmoCard.neumorphic(isSelected: isSelected)` for multi-option selectors, cycle phases, and calendar day selection.
- **Sunken / Inset Surfaces**: Use `RitmoCard.neumorphicSunken` for input containers, note boxes, previews, and deep concave wells.
- **Tactile 3D Buttons**: Use `RitmoNeuButton` (with physical raised-to-sunken depression and haptic feedback) instead of flat material buttons.
- **Sunken Progress Bars**: Use `RitmoNeuProgressBar` for goal progress, energy charge, habits, and time intervals.
- **Loading Skeletons**: Use `RitmoCardSkeleton` during async/database/AI fetch to prevent layout shifts (Zero Layout Shift).
- **Empty States**: Use `RitmoNeuEmptyCard` with sunken circle icon and clear Call-To-Action button for empty lists/data.
- **Canonical Glass Sheets & Modals**: ALWAYS present bottom sheets via `RitmoGlassSheet` (live blur, ambient glow halo, Apple top drag handle) or `RitmoPickerSheet` for search/pickers.
- **Canonical Glass Dialogs**: ALWAYS present confirmation/alert modals via `RitmoGlassDialog.show(...)` with sigma 20 live blur and tactile buttons. Never use raw, flat `AlertDialog` widgets.
- **Apple Liquid Glass Segmented Switcher**: Use `RitmoGlassSegmentedControl` for 2-4 item timeframe switchers (daily/weekly/monthly) and horizontal tabbed filters.
- **Luminous Status Indicators**: Use `RitmoLuminousDot` and `RitmoStatusBadge` (with dual-glow neon halo) for real-time connection, status, and AI indicators.

## 7. 60/120 FPS Performance & Frame Budgeting
- **`const` Widget Trees**: Always use `const` constructors for static widgets, paddings, decorations, and icons to minimize rebuild cycles.
- **Zero Heavy Computations in `build()`**: Never execute parsing, heavy loops, regex evaluations, or unmemoized date formatters inside widget `build()` methods; compute in state managers/cubits or memoize.
- **Isolated Repaints with `RepaintBoundary`**: Wrap high-frequency animating widgets (such as 24h dial gauges, pulsating halos, and progress bars) in `RepaintBoundary` to prevent cascading render tree repaints.
- **List Virtualization**: Always use virtualized list builders (`ListView.builder`, `SliverList`) for dynamic collections and long lists rather than unvirtualized Column children.
- **Zero Layout Shifts**: Match skeleton loading dimensions strictly with real content geometry to prevent jarring layout jumps.

