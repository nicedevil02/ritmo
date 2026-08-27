---
name: design-systems-hig-m3
description: >-
  Provides guidelines and implementation patterns for Apple Human Interface Guidelines (Cupertino / iOS HIG)
  and Google Material 3 (Material You / M3) design systems in Flutter, including adaptive platform widgets,
  dynamic color tokens, tonal elevation, and frosted glass/blur effects.
---

# Design Systems: Apple HIG & Google Material 3

This skill guides the design, cross-platform adaptation, and implementation of interfaces adhering strictly to **Apple Human Interface Guidelines (HIG)** and **Google Material 3 (M3)**.

---

## 1. Material 3 (Google M3) Standards

### A. Dynamic Color Schemes & Semantic Tokens
- Use `ColorScheme.fromSeed(seedColor: ...)` to generate tonal palettes.
- Never hardcode arbitrary hex colors for surface/background; rely on semantic tokens:
  * `Theme.of(context).colorScheme.surfaceContainer` (standard cards/sheets)
  * `Theme.of(context).colorScheme.surfaceContainerHigh` (dialogs/elevated sheets)
  * `Theme.of(context).colorScheme.primary` / `onPrimary`
  * `Theme.of(context).colorScheme.outlineVariant` (subtle borders)

### B. Tonal Elevation (No Drop-Shadows in M3)
- M3 achieves depth through **color tone layering** rather than harsh black drop shadows. Higher elevation = slightly lighter tinted surface.

### C. Modern M3 Widgets
- Use `NavigationBar` instead of legacy `BottomNavigationBar`.
- Use `FloatingActionButton.extended` or `FilledButton` / `FilledButton.tonal`.
- Use `SegmentedButton<T>` for multi-option selection filters.
- Use `SearchAnchor` and `SearchBar` for search flows.

---

## 2. Apple Human Interface Guidelines (Apple HIG / Cupertino)

### A. Visual Aesthetics & Physics
- **Clarity, Deference, Depth**: Keep content front and center; UI elements are subtle and translucent.
- **Frosted Glass (Vibrancy & Blur)**:
  ```dart
  ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context).withOpacity(0.7),
        child: child,
      ),
    ),
  );
  ```
- **Physics**: Use `BouncingScrollPhysics()` on iOS to provide the signature bounce edge behavior.

### B. Cupertino Navigation & Modals
- `CupertinoPageScaffold` with `CupertinoNavigationBar` (large title or inline title).
- Modals: Use `showCupertinoModalPopup` with `CupertinoActionSheet` for destructive/action menus.
- Date/Time selection: Use `CupertinoDatePicker` in wheel mode.

---

## 3. Platform Adaptive Architecture

For cross-platform apps, adapt key elements automatically:

```dart
Widget buildAdaptiveSwitch({
  required BuildContext context,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS ||
      Theme.of(context).platform == TargetPlatform.macOS;

  if (isIOS) {
    return CupertinoSwitch(
      value: value,
      activeColor: CupertinoColors.activeGreen,
      onChanged: onChanged,
    );
  }
  return Switch(
    value: value,
    onChanged: onChanged,
  );
}
```

---

## 4. RTL & Typography Harmonization
- Ensure typography scales smoothly with Persian fonts (e.g. Vazirmatn, Shabnam) while respecting standard M3 / HIG body and headline proportion scales.
