---
name: flutter-responsive-ui
description: >-
  Provides comprehensive architecture, responsive breakpoints, adaptive layout patterns,
  multi-screen support (mobile, tablet, desktop, foldable), safe area handling, keyboard
  overflow prevention, and RTL/LTR internationalization for Flutter apps. Use whenever designing,
  refactoring, or auditing Flutter UI components and screens for responsiveness and adaptability.
---

# Flutter Responsive & Adaptive UI Skill

This skill guides the design, implementation, and audit of responsive, adaptive, and scalable Flutter user interfaces across phones, tablets, foldables, and desktops.

---

## 1. Breakpoint Standards

Use standardized breakpoints across all screens:

| Device Tier | Width Range (`width`) | Typical Navigation / Layout Strategy |
| :--- | :--- | :--- |
| **Compact (Mobile)** | `< 600 dp` | Single-column, `BottomNavigationBar` / `NavigationBar`, Modal bottom sheets |
| **Medium (Tablet / Foldable unfolded)** | `600 dp` – `1024 dp` | Master-detail split view or 2-column grid, `NavigationRail`, Side sheets |
| **Expanded (Desktop / Web / Ultra-wide)** | `> 1024 dp` | Multi-column dashboard, permanent Navigation Drawer / Sidebar, Centered max-width content container (e.g. `1200 dp` max) |

---

## 2. Layout & State Efficiency Rules

1. **Targeted MediaQuery Queries (Flutter 3.10+ & Dart 3):**
   - ❌ Never use generic `MediaQuery.of(context)` when only size/insets are needed (causes unnecessary rebuilds).
   - ✅ Always use targeted accessors:
     * `MediaQuery.sizeOf(context)`
     * `MediaQuery.viewInsetsOf(context)` (keyboard appearance)
     * `MediaQuery.paddingOf(context)` (safe area insets)
     * `MediaQuery.orientationOf(context)`

2. **Parent Constraints Over Screen Sizes:**
   - Prefer `LayoutBuilder` when a component should respond to its parent container's width/height rather than the global device window.

3. **Overflow Prevention:**
   - Wrap vertical forms and interactive pages in `SingleChildScrollView` with `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`.
   - Use `Flexible` or `Expanded` inside `Row`/`Column` with `Text(..., overflow: TextOverflow.ellipsis)` to prevent `RenderFlex overflowed by X pixels`.

4. **Adaptive Grids:**
   - Use `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: ...)` instead of hardcoded `crossAxisCount` so grids scale automatically from 1 column on phones to 4+ columns on tablets/desktops.

---

## 3. Directional & RTL Support (Persian / Internationalization)

For apps supporting RTL languages (such as Persian / Farsi):
* ❌ Avoid `EdgeInsets.only(left: ..., right: ...)`.
* ✅ Always use `EdgeInsetsDirectional.only(start: ..., end: ...)`.
* ❌ Avoid `Alignment.topLeft` / `Alignment.topRight`.
* ✅ Always use `AlignmentDirectional.topStart` / `AlignmentDirectional.topEnd`.
* Ensure icon buttons with arrows (e.g. back navigation or forward carets) respect `Directionality.of(context)` or use `Icons.arrow_back` / `Icons.arrow_forward` with mirrored behavior.

---

## 4. Architectural Patterns & Directory Structure

When implementing responsive UI, use the helper components in:
- [Responsive Patterns Guide](./references/responsive_patterns.md)
- [Responsive Layout Helper Example](./examples/responsive_scaffold_example.dart)

---

## 5. Verification & Audit Checklist

Before finalizing any UI implementation:
1. **Screen Sizes:** Test on small phone (320x640), standard phone (390x844), tablet (800x1280), and wide landscape.
2. **Keyboard Interaction:** Open soft keyboard on forms to ensure inputs remain visible and no overflow banners appear.
3. **Orientation:** Rotate between portrait and landscape.
4. **Static Analysis:** Run `flutter analyze` to ensure 0 lint errors, no deprecated APIs, and all `const` modifiers are present.
