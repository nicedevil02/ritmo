# 🍏 Apple Morphing Glass Header Skill (Flutter)

A standalone, production-ready skill and reference architecture for building **Apple HIG Dynamic Morphing Glass Capsule Headers** in Flutter.

---

## 📦 What's Inside This Skill Package

- **`SKILL.md`**: Detailed technical guide, mathematical physics formulas, continuous lerp interpolation tables, 120 FPS latency-free rendering rules, and golden guidelines.
- **`lib/apple_morphing_glass_header.dart`**: Complete, self-contained implementation of `AppleMorphingGlassHeader` and `AppleVibrancyActionButton`.
- **`lib/apple_liquid_glass_tabs.dart`**: Clean, segmented control with sliding liquid pill indicator.
- **`examples/example_screen.dart`**: Copy-pasteable complete Flutter screen demo showing gesture routing, breathing room spacing, and elastic overscroll.

---

## 🚀 Key Features

1. **Unified Single Morphing Capsule (`Single Glass Capsule`)**:
   Status bar, header bar, morphing title, live subtitle, trailing action buttons, and segmented tabs live in a single continuous frosted glass container.

2. **Continuous Title Morphing (`Large Title -> Inline Title`)**:
   Large title lerps seamlessly into an inline navigation title without disappearing or popping.

3. **Elastic Rubber-Banding Overscroll (`Overscroll Stretch`)**:
   Pulling down at rest expands the capsule height and dynamically scales the title up with 0ms gesture tracking.

4. **Quick-Return Liquid Tabs (`Forward Scroll Recovery`)**:
   Segmented tabs collapse smoothly when scrolling down and reappear immediately with a subtle upward drag anywhere on the page.

5. **Apple HIG 20pt Breathing Room**:
   Calculated layout spacing (`topPadding + 190.0` with tabs, `topPadding + 130.0` without tabs).

---

## 🛠 Quick Integration

```dart
// 1. Wrap your Stack in NotificationListener
NotificationListener<ScrollNotification>(
  onNotification: (n) {
    if (n.metrics.axis == Axis.vertical) {
      _scrollOffset.value = n.metrics.pixels;
    }
    return false;
  },
  child: ListView.builder(
    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 190.0, 16, 80),
    ...
  ),
)

// 2. Add AppleMorphingGlassHeader to your Stack
Positioned(
  top: 0,
  left: 0,
  right: 0,
  child: AnimatedBuilder(
    animation: _scrollOffset,
    builder: (context, _) => AppleMorphingGlassHeader(
      title: 'My Screen',
      scrollOffset: _scrollOffset.value,
      ...
    ),
  ),
)
```
