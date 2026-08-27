---
name: flutter-advanced-animations
description: >-
  Provides patterns, architectural standards, and performance rules for building fluid,
  60/120 FPS micro-interactions, explicit animations, physics-based springs, hero transitions,
  and staggered animations in Flutter.
---

# Flutter Advanced Animations Skill

This skill guides the design, implementation, and audit of high-performance animations and micro-interactions in Flutter.

---

## 1. Animation Architecture & Decision Tree

Choose the right animation tool based on the interaction complexity:

```
                      Do you need manual control (play, pause, reverse, loop, stagger)?
                                      /                                 \
                                   [No]                                 [Yes]
                                   /                                       \
          Is it a standard property (opacity, size, padding)?       [Explicit Animation]
                   /                      \                          - AnimationController
                [Yes]                     [No]                       - CurvedAnimation
         [Implicit Widgets]     [TweenAnimationBuilder]              - AnimatedBuilder
         - AnimatedContainer                                         - vsync (TickerProvider)
         - AnimatedOpacity
         - AnimatedCrossFade
         - AnimatedPositioned
```

---

## 2. Explicit Animation Rules

1. **Lifecycle & Memory Management:**
   - Always mix in `SingleTickerProviderStateMixin` (for 1 controller) or `TickerProviderStateMixin` (for multiple).
   - **MANDATORY**: Call `controller.dispose()` inside the State's `dispose()` method to prevent memory leaks and background ticker CPU drain.

2. **Rebuild Isolation with `AnimatedBuilder`:**
   - ❌ **Anti-pattern**: Calling `setState()` inside `controller.addListener(...)` (rebuilds the entire widget subtree).
   - ✅ **Best Practice**: Use `AnimatedBuilder` or `ListenableBuilder` and pass static parts to the `child` parameter:
     ```dart
     AnimatedBuilder(
       animation: _curvedAnimation,
       child: const HeavyStaticWidget(), // Won't rebuild on each tick
       builder: (context, child) {
         return Transform.scale(
           scale: _curvedAnimation.value,
           child: child,
         );
       },
     );
     ```

3. **Physics-Based & Spring Simulations:**
   - For realistic, organic gestures (swipes, drag-to-dismiss, bouncy snaps), use `SpringSimulation`:
     ```dart
     final spring = SpringDescription(mass: 1.0, stiffness: 180.0, damping: 20.0);
     final simulation = SpringSimulation(spring, startPosition, targetPosition, velocity);
     _controller.animateWith(simulation);
     ```

---

## 3. Micro-Interactions & Haptic Feedback

- Combine tactile feedback with visual animations:
  * Tap down: Scale down to `0.96` + `HapticFeedback.lightImpact()`
  * Release: Spring back to `1.0`
- Keep duration under `250ms` for interactive feedback, and `350-500ms` for page transitions.

---

## 4. Staggered & Sequence Animations

- Use `Interval(startFraction, endFraction, curve: ...)` on a single `AnimationController` to orchestrate multi-element entrance transitions:
  ```dart
  _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
  );
  _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
    CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)),
  );
  ```

---

## 5. Performance Checklist
- Isolate animated trees inside `RepaintBoundary` when repaints are expensive.
- Avoid animating layout-triggering properties (`width`, `height`, `margin`) when `Transform.scale` or `Transform.translate` can achieve the same effect on the GPU layer.
