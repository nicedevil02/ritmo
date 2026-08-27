# Flutter Responsive UI Patterns & Best Practices

This reference guide provides code patterns and architectural recommendations for building responsive layouts in Flutter.

---

## 1. Responsive Layout Strategy

### A. Responsive Builder Widget

Use a `ResponsiveBuilder` (or `LayoutBuilder`) to conditionally switch UI representations:

```dart
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600 &&
      MediaQuery.sizeOf(context).width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 600) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}
```

---

## 2. Dynamic Adaptive Navigation

Switch between standard bottom navigation on mobile and a side navigation rail on tablet/desktop:

```dart
Widget buildAdaptiveScaffold(BuildContext context, int selectedIndex, ValueChanged<int> onDestinationSelected) {
  final isExpanded = MediaQuery.sizeOf(context).width >= 600;

  if (!isExpanded) {
    return Scaffold(
      body: currentScreen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.task_outlined), selectedIcon: Icon(Icons.task), label: 'وظایف'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'تنظیمات'),
        ],
      ),
    );
  }

  return Scaffold(
    body: Row(
      children: [
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('خانه')),
            NavigationRailDestination(icon: Icon(Icons.task_outlined), selectedIcon: Icon(Icons.task), label: Text('وظایف')),
            NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('تنظیمات')),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: currentScreen),
      ],
    ),
  );
}
```

---

## 3. Handling Keyboard and Safe Areas

Always wrap forms with safe insets:

```dart
Scaffold(
  body: SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const Text('ورود به حساب'),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('ادامه'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ),
);
```
