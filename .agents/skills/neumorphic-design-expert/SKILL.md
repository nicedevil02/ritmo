---
name: neumorphic-design-expert
description: >-
  Provides guidelines, light-source physics, dual-shadow algorithms, convex/concave embossing,
  and accessibility rules for creating modern Neumorphic (Soft UI) designs in Flutter.
---

# Neumorphic (Soft UI) Design Skill

This skill guides the implementation of **Neumorphic (Soft UI)** visual design in Flutter, balancing aesthetic depth with accessibility (A11y) and rendering performance.

---

## 1. Neumorphic Physics & Lighting Model

Neumorphism creates the illusion that UI elements are sculpted directly out of the background material.

### Core Principles
1. **Identical Surface & Background Color**: The element's base color MUST match or closely harmonize with the canvas background (e.g., `#E0E5EC` for Light, `#24272C` for Dark).
2. **Dual Opposing Shadows (Light Source at Top-Left / `135°`):**
   * **Highlight Shadow (Top-Left)**: Lighter than background, offset `(-x, -y)`, blur `b`.
   * **Diffuse Shadow (Bottom-Right)**: Darker than background, offset `(+x, +y)`, blur `b`.

---

## 2. Standard Neumorphic States

### A. Raised / Convex (Default Card or Button)
```dart
BoxDecoration(
  color: backgroundColor, // e.g. Color(0xFFE0E5EC)
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    // Top-Left Light Highlight
    BoxShadow(
      color: Colors.white.withOpacity(0.9),
      offset: const Offset(-5, -5),
      blurRadius: 10,
    ),
    // Bottom-Right Dark Shadow
    BoxShadow(
      color: const Color(0xFFA3B1C6).withOpacity(0.6),
      offset: const Offset(5, 5),
      blurRadius: 10,
    ),
  ],
)
```

### B. Inset / Pressed (Active Button or Input Field)
For pressed or concave states, invert the light source or create an inner shadow / gradient effect:
```dart
BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFA3B1C6).withOpacity(0.3), // Darker edge top-left
      Colors.white.withOpacity(0.5),      // Lighter edge bottom-right
    ],
  ),
  borderRadius: BorderRadius.circular(16),
)
```

---

## 3. Dark Mode Neumorphism (Midnight Neumorphic)

In dark mode, stark white highlights appear harsh. Use balanced slate/midnight tones:
* **Background Canvas**: `Color(0xFF1E2125)`
* **Dark Shadow**: `Color(0xFF121417)` with `0.8` opacity, offset `(6, 6)`.
* **Light Highlight**: `Color(0xFF2C3036)` with `0.7` opacity, offset `(-6, -6)`.
* **Accent Details**: Use vibrant neon/glow accents (cyan `#00E5FF`, violet `#7C4DFF`, or emerald `#00E676`) for active indicators and iconography to ensure high visibility.

---

## 4. Accessibility (A11y) & Usability Safeguards

Neumorphism often suffers from low contrast if not carefully audited:
* ⚠️ **Rule 1 - Text & Icon Contrast**: Text and icons must have at least **4.5:1 WCAG contrast** against the surface. Never use subtle gray text on gray neumorphic buttons.
* ⚠️ **Rule 2 - State Clarity**: For toggle buttons and checkboxes, always accompany the shape change with a distinct accent color or icon transformation so users with visual impairments can easily distinguish active states.

---

## 5. Performance Guidelines
- Avoid nesting multi-layered blurred containers inside high-speed scrolling lists.
- For fixed-shape neumorphic buttons, encapsulate them as reusable, `const`-friendly widgets.
