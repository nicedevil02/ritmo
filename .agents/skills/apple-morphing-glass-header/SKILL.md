---
name: apple-morphing-glass-header
description: >-
  Architectural patterns, mathematical physics, and production-grade implementation for Apple-style
  Dynamic Morphing Glass Capsule Headers in Flutter. Covers continuous lerp morphing (large-to-inline title),
  Apple elastic rubber-banding overscroll, quick-return liquid glass tabs, 120 FPS latency-free gesture tracking,
  and HIG breathing room geometry.
---

# Apple Morphing Glass Capsule Header & Fluid Physics

This skill provides comprehensive architectural patterns, mathematical physics, and production-ready Flutter code for building **Apple HIG Dynamic Morphing Glass Capsule Headers**.

---

## 1. Visual Architecture & State Progression

The Apple Morphing Glass Header unifies the status bar, title, subtitle/live status, trailing control actions, and segmented tabs into a **single continuous frosted glass capsule**.

```
                           [1. RESTING STATE (Top of Screen / scrollOffset = 0)]
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  [<-]                                                                         [✨] [⚙] [➕] │
│                                                                                             │
│  Large Title (Font: 27pt, Bold, Right/Left: 14pt)                                           │
│  Live Subtitle & Status Badges (Font: 12.5pt, Opacity: 1.0)                                 │
│                                                                                             │
│  [        Tab 1                  Tab 2                  Tab 3                  Tab 4       ]│
└─────────────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              │ (Pull Down / scrollOffset < 0)
                                              ▼
                           [2. ELASTIC RUBBER-BANDING OVERSCROLL]
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  [<-]                                                                         [✨] [⚙] [➕] │
│                                                                                             │
│  Large Title (SCALED UP to 1.12x, stretches downward with finger)                           │
│  Live Subtitle (stretches downward with finger)                                             │
│                                                                                             │
│  [        Tab 1                  Tab 2                  Tab 3                  Tab 4       ]│
│  ↕ EXPANDED CAPSULE HEIGHT (+ overscroll * 0.48px)                                          │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              │ (Scroll Down / scrollOffset > 0)
                                              ▼
                           [3. COMPACT CAPSULE (Scrolled State / scrollOffset >= 55)]
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  [<-]   Inline Title (Font: 16.5pt, Right/Left: 52pt)                         [✨] [⚙] [➕] │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              │ (Subtle Forward Scroll / Upward Drag)
                                              ▼
                           [4. QUICK-RETURN EXPANDED CAPSULE]
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  [<-]   Inline Title                                                          [✨] [⚙] [➕] │
│  [        Tab 1                  Tab 2                  Tab 3                  Tab 4       ]│
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Formulas & Physics Algorithms

### A. Positive Scroll Collapse Progress ($t$)
Interpolates the header from large resting layout to compact floating capsule over `collapseDistance` (default: `55.0px`).

$$\text{rawT} = \text{clamp}\left(\frac{\text{scrollOffset}}{\text{collapseDistance}}, 0.0, 1.0\right)$$
$$t = \text{Curves.easeInOutCubic.transform}(\text{rawT})$$

### B. Elastic Rubber-Banding Overscroll (Pull-Down Stretch)
When the user pulls down at rest (`scrollOffset < 0`), the header stretches out elastically:

$$\text{overscrollAmount} = \text{clamp}(-\text{scrollOffset}, 0.0, 200.0)$$
$$\text{elasticStretch} = \text{overscrollAmount} \times 0.48$$
$$\text{elasticScale} = 1.0 + \text{clamp}(\text{overscrollAmount} \times 0.0014, 0.0, 0.12)$$

### C. Continuous Linear Interpolation ($\text{lerp}$)
All visual properties transition smoothly with zero jarring jumps:

| Property | Formula / Interpolation | Description |
|---|---|---|
| **Height** | $\text{lerp}(\text{restingHeight} + \text{elasticStretch}, \text{capsuleHeight}, t)$ | Expands when pulled, collapses on scroll |
| **Horizontal Margin** | $\text{lerp}(0.0, 10.0, t)$ | Full-bleed at top, floating pill when scrolled |
| **Top Margin** | $\text{topInset} + \text{lerp}(2.0, 6.0, t)$ | Adapts cleanly below hardware notch/Dynamic Island |
| **Border Radius** | $\text{lerp}(0.0, 27.0, t)$ | Square full-bleed to pill capsule |
| **Title Top** | $\text{lerp}(50.0 + \text{elasticStretch} \times 0.35, 14.0, t)$ | Morphs directly from large body to header bar |
| **Title Side Offset** | $\text{lerp}(14.0, 52.0, t)$ | Shifts past back button into inline alignment |
| **Title Font Size** | $\text{lerp}(27.0, 16.5, t)$ | Seamless typographic scaling |
| **Subtitle Opacity** | $\text{clamp}(1.0 - 2.4 \times \text{rawT}, 0.0, 1.0)$ | Gracefully fades out early in collapse |
| **Backdrop Blur** | $t \times \text{blurSigma}$ | Crystal clear at top, rich frosted glass when floating |

---

## 3. 120 FPS Rendering & Zero-Latency Performance Rules

1. **Eliminate Gesture Lag During Touch Tracking:**
   During active scrolling or overscroll (`isOverscrolling || t < 0.99`), set `duration: Duration.zero` on the container. Only animate with easing when snapping back or auto-expanding tabs (`isTabsExpanded` toggles).
   ```dart
   AnimatedContainer(
     duration: (isOverscrolling || t < 0.99) ? Duration.zero : const Duration(milliseconds: 260),
     curve: Curves.easeInOutCubic,
     height: targetHeight,
     ...
   )
   ```

2. **Repaint Boundary & Merge Listeners:**
   Wrap the header in `AnimatedBuilder` merging `_scrollOffset` and `_isTabsExpanded` ValueNotifiers:
   ```dart
   AnimatedBuilder(
     animation: Listenable.merge([_scrollOffset, _isTabsExpanded]),
     builder: (context, _) => AppleMorphingGlassHeader(...),
   )
   ```

3. **High Contrast Accessibility Fallback:**
   Always inspect `MediaQuery.of(context).highContrast`. When enabled, bypass `BackdropFilter` and render opaque background with high-contrast borders for accessibility compliance.

---

## 4. Golden Rules for Elastic Rubber-Banding in Flutter

### 🚨 Rule 1: NEVER Wrap Scroll Views in Material `RefreshIndicator` Directly
`RefreshIndicator` intercepts negative pull deltas on Android/iOS, clamping `notification.metrics.pixels >= 0.0`. This completely destroys the overscroll rubber-banding effect.
- **Solution**: Use `SingleChildScrollView`, `ListView`, or `CustomScrollView` directly with bouncing physics.

### 🚨 Rule 2: ALWAYS Set `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())`
By default, Android uses `ClampingScrollPhysics` which cuts off negative overscroll.
- **Solution**: Explicitly set:
  ```dart
  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
  ```

### 🚨 Rule 3: Single Unified Scroll Container (No Fragmented Viewports)
Do NOT place fixed non-scrollable widgets (e.g. Hero cards or banner columns) above the scrollable list inside a `Column`.
- **Solution**: Embed the Hero card as `index == 0` or `SliverToBoxAdapter` inside the scroll view so the entire viewport responds to pull-down gestures.

### 🚨 Rule 4: HIG 20pt Breathing Room
Set top padding of scroll views to ensure the first content card sits with breathing room below the floating capsule:
- **With Tabs**: `contentTopPadding = topPadding + 190.0`
- **Without Tabs**: `contentTopPadding = topPadding + 130.0`

---

## 5. Standard Implementation Recipe

```dart
class MyAppleScreen extends StatefulWidget {
  const MyAppleScreen({super.key});

  @override
  State<MyAppleScreen> createState() => _MyAppleScreenState();
}

class _MyAppleScreenState extends State<MyAppleScreen> {
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isTabsExpanded = ValueNotifier<bool>(true);
  int _selectedTab = 0;

  @override
  void dispose() {
    _scrollOffset.dispose();
    _isTabsExpanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 190.0;

    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: Body Content (Listens to scroll gestures)
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical) {
                  _scrollOffset.value = notification.metrics.pixels;
                  if (notification.metrics.pixels <= 15) {
                    if (!_isTabsExpanded.value) _isTabsExpanded.value = true;
                  } else if (notification is UserScrollNotification) {
                    if (notification.direction == ScrollDirection.reverse) {
                      if (notification.metrics.pixels > 75 && _isTabsExpanded.value) {
                        _isTabsExpanded.value = false;
                      }
                    } else if (notification.direction == ScrollDirection.forward) {
                      if (!_isTabsExpanded.value) {
                        _isTabsExpanded.value = true;
                      }
                    }
                  }
                }
                return false;
              },
              child: ListView.builder(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 80),
                itemCount: 30,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(title: Text('Item $index')),
                  );
                },
              ),
            ),
          ),

          // Layer 2: Apple Dynamic Morphing Glass Capsule Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: Listenable.merge([_scrollOffset, _isTabsExpanded]),
              builder: (context, _) {
                return AppleMorphingGlassHeader(
                  title: 'Apple Experience',
                  subtitle: 'Fluid continuous morphing & rubber-band physics',
                  scrollOffset: _scrollOffset.value,
                  isTabsExpanded: _isTabsExpanded.value,
                  onBack: () => Navigator.maybePop(context),
                  actions: [
                    AppleVibrancyActionButton(
                      icon: CupertinoIcons.sparkles,
                      isSpecialAccent: true,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    AppleVibrancyActionButton(
                      icon: CupertinoIcons.add,
                      onTap: () {},
                    ),
                  ],
                  tabs: AppleLiquidGlassTabs<int>(
                    items: const [
                      AppleTabItem(title: 'Dashboard', icon: CupertinoIcons.home, value: 0),
                      AppleTabItem(title: 'Analytics', icon: CupertinoIcons.chart_bar, value: 1),
                      AppleTabItem(title: 'Settings', icon: CupertinoIcons.gear, value: 2),
                    ],
                    selectedIndex: _selectedTab,
                    onTabChanged: (val) => setState(() => _selectedTab = val),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```
