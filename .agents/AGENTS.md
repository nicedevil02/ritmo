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

## 6. Ritmo Canonical Reference System (Cards, Sheets & UI Primitives) — Zero Hardcoding Policy
When building, updating, or refactoring UI components across Ritmo, ALWAYS connect 100% of visual containers to the official canonical design primitives defined in `lib/core/widgets/ritmo/`, `lib/core/widgets/sheet/`, and showcased in `lib/features/settings/presentation/cards_showcase_screen.dart`. Agents MUST only provide the domain `child` content/parameters and NEVER create custom manual containers, custom shadows, or opaque background boxes.

### 🚫 Strict Prohibitions (Zero-Tolerance Anti-Patterns):
1. ❌ **No Manual Sheet Containers**: NEVER wrap sheet bodies in manual `Container(decoration: BoxDecoration(color: colors.surface/surfaceElevated...))` or hardcode opaque backgrounds.
2. ❌ **No Manual BackdropFilter / Glass Reimplementation**: NEVER write custom `BackdropFilter` or `ClipRRect` glass logic outside `RitmoGlassSheet`.
3. ❌ **No Raw Material Cards or AlertDialogs**: NEVER use raw `Card()`, `AlertDialog`, or `showDialog(builder: AlertDialog)`. Always use `RitmoCard.neumorphic` and `RitmoDialog.show(...)`.
4. ❌ **No Manual Sheet Height Math**: NEVER write `MediaQuery.sizeOf(context).height * 0.9`. Always use `RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94)` or `RitmoSheetScaffold.present`.
5. ❌ **No Flat Buttons Inside Cards**: NEVER use flat text/material buttons for main card actions; use `RitmoNeuButton` with physical 3D depression.

---

### 📐 Canonical Reference Primitives & Ready-to-Use Recipes:

#### 1. Canonical Sheets & Modals (Standard Recipe):
```dart
// Option A: Full Sheet Scaffold (Form / Task / Planner) - Recommended
RitmoSheetScaffold.present<bool>(
  context: context,
  title: 'عنوان شیت',
  subtitle: 'توضیحات اختیاری',
  footer: RitmoPrimaryButton(label: 'ثبت نهایی', onPressed: () => submit()),
  builder: (ctx) => MyFormContentWidget(), // Only input fields / body without outer decorations
);

// Option B: Custom / Wizard / Timer Glass Sheet
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (ctx) => Directionality(
    textDirection: TextDirection.rtl,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: RitmoBreakpoints.sheetMaxHeight(ctx, factor: 0.94),
      ),
      child: RitmoGlassSheet(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle (36x4, border.withValues(alpha: 0.6))
            // Symmetrical Header (Leading 34x34 X in RTL, Center Title, Trailing 34x34 Checkmark / Spacer)
            // Divider(color: colors.divider, height: 1)
            // Expanded / Flexible Scrollable Body
          ],
        ),
      ),
    ),
  ),
);

// Option C: Generic Picker Sheet (Search & Select)
final selected = await RitmoPickerSheet.show<MyItem>(
  context: context,
  title: 'انتخاب آیتم',
  options: items.map((i) => PickerOption(label: i.name, value: i)).toList(),
  enableSearch: true,
);
```

#### 2. Canonical Cards & Surfaces:
- **Master Hero Dashboard Card**: `RitmoNeuMasterCard` for top active realm, 24h dial, and time-block hero widgets.
- **Raised Module Cards**: `RitmoCard.neumorphic(onTap: ..., child: Column(children: [RitmoCardHeader(...), RitmoCardTile(...), RitmoCardBadge(...), RitmoCardDivider()]))`.
- **Selectable / Toggle Cards**: `RitmoCard.neumorphic(isSelected: isSelected, onTap: ...)` for multi-option selectors, cycle phases, and calendar day selection.
- **Sunken / Inset Surfaces**: `RitmoCard.neumorphicSunken(child: ...)` for input containers, note boxes, previews, and deep concave wells.
- **Tactile 3D Buttons**: `RitmoNeuButton(onTap: ..., child: ...)` (physical raised-to-sunken depression with haptic feedback).
- **Sunken Progress Bars**: `RitmoNeuProgressBar(progress: 0.75, label: 'پیشرفت', showLabel: true)`.
- **Loading Skeletons**: `RitmoCardSkeleton(height: 120)` during async fetch to guarantee Zero Layout Shift.
- **Empty States**: `RitmoNeuEmptyCard(title: '...', subtitle: '...', actionLabel: '...', onActionTap: ...)` for empty lists/data.
- **Segmented Control**: `RitmoGlassSegmentedControl(items: [...], selectedIndex: ..., onTabChanged: ...)` for 2-4 item timeframe switchers.
- **Luminous Status**: `RitmoLuminousDot` and `RitmoStatusBadge` (with dual-glow neon halo) for real-time status and AI indicators.

#### 3. Canonical Dialogs & Confirmation:
```dart
final confirmed = await RitmoDialog.show(
  context,
  title: 'عنوان دیالوگ',
  content: 'متن توضیحات دیالوگ',
  confirmLabel: 'تأیید',
  cancelLabel: 'انصراف',
  isDestructive: false, // true for delete/reset actions
);
```

---

### 🔍 Pre-Commit UI Architecture Checklist:
- [ ] Are all bottom sheets presented via `RitmoGlassSheet`, `RitmoSheetScaffold.present`, or `RitmoPickerSheet.show`?
- [ ] Is there ZERO manual `BoxDecoration(color: colors.surface...)` on sheet roots?
- [ ] Are all confirmation/alert dialogs using `RitmoDialog.show(...)` with zero raw `AlertDialog`s?
- [ ] Are all cards using `RitmoCard.neumorphic`, `RitmoCard.neumorphicSunken`, or `RitmoNeuMasterCard`?

## 7. 60/120 FPS Performance & Frame Budgeting
- **`const` Widget Trees**: Always use `const` constructors for static widgets, paddings, decorations, and icons to minimize rebuild cycles.
- **Zero Heavy Computations in `build()`**: Never execute parsing, heavy loops, regex evaluations, or unmemoized date formatters inside widget `build()` methods; compute in state managers/cubits or memoize.
- **Isolated Repaints with `RepaintBoundary`**: Wrap high-frequency animating widgets (such as 24h dial gauges, pulsating halos, and progress bars) in `RepaintBoundary` to prevent cascading render tree repaints.
- **List Virtualization**: Always use virtualized list builders (`ListView.builder`, `SliverList`) for dynamic collections and long lists rather than unvirtualized Column children.
- **Zero Layout Shifts**: Match skeleton loading dimensions strictly with real content geometry to prevent jarring layout jumps.

