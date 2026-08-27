---
name: flutter-performance-optimization
description: >-
  Provides profiling strategies, memory leak prevention, rebuild minimization, 60/120 FPS frame budgeting,
  list virtualization, and render tree optimizations for Flutter applications.
---

# Flutter Performance Optimization Skill

This skill guides the auditing, profiling, and performance tuning of Flutter applications to maintain solid 60/120 FPS, eliminate jank, and minimize memory footprints.

---

## 1. Frame Budget & Jank Elimination

- **Target**: 16.6ms per frame for 60 FPS devices, 8.3ms for 120 FPS high-refresh displays.
- **Rule**: Never run heavy CPU/blocking tasks on the UI isolate. Use `compute()` or `Isolate.run()` for heavy JSON parsing, database migrations, or image filtering.

---

## 2. Rebuild Minimization Rules

1. **Leverage `const` Constructors Everywhere:**
   - `const` widgets are instantiated once at compile time and skipped during render tree diffing.

2. **Granular State Subscriptions:**
   - ❌ Avoid watching entire monolithic state objects in a top-level `build()`.
   - ✅ Use granular builders:
     * `ValueListenableBuilder<T>`
     * `Selector<State, SubProperty>` (Provider)
     * `BlocSelector<Bloc, State, SelectedProperty>` (BLoC)
     * `ref.watch(provider.select((s) => s.specificField))` (Riverpod)

3. **No Side-Effects in `build()`:**
   - ❌ Never trigger HTTP requests, disk writes, or state changes inside `build()`.
   - ✅ Trigger async tasks in `initState()`, controllers, or event handlers.

---

## 3. List & Scroll Performance

1. **Virtualization over Monolithic Lists:**
   - ❌ Never use `Column(children: items.map(...).toList())` inside `SingleChildScrollView` for long lists (renders all items simultaneously).
   - ✅ Always use `ListView.builder` or `CustomScrollView` with `SliverList.builder`.

2. **Fixed Extent Optimizations:**
   - When item heights are known, provide `itemExtent: 72.0` or `prototypeItem: const ItemWidget(...)` to bypass runtime item dimension measurement passes.

---

## 4. Render Tree & GPU Optimizations

1. **`RepaintBoundary` Isolation:**
   - Wrap animated, pulsing, or frequently updated widgets (e.g., custom timers, canvas painters, audio waveforms) in `RepaintBoundary` to prevent repainting their parent/sibling widgets.

2. **Avoid Expensive Shader Passes:**
   - Minimize excessive stacking of `BackdropFilter` or `SaveLayer` calls (e.g. `ColorFiltered`, `ShaderMask`, `ClipRRect` with high anti-aliasing) inside frequently scrolling lists.

---

## 5. Memory Management & Resource Leaks

- **Dispose Checklist**:
  * `TextEditingController.dispose()`
  * `ScrollController.dispose()`
  * `AnimationController.dispose()`
  * `FocusNode.dispose()`
  * `StreamSubscription.cancel()`
  * `Timer.cancel()`
- **Images**: Use `ResizeImage` or `cacheWidth`/`cacheHeight` on `Image.asset` and `Image.network` to avoid holding uncompressed 4K bitmaps in RAM.
