import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../lib/apple_morphing_glass_header.dart';
import '../lib/apple_liquid_glass_tabs.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AppleMorphingExampleScreen(),
  ));
}

class AppleMorphingExampleScreen extends StatefulWidget {
  const AppleMorphingExampleScreen({super.key});

  @override
  State<AppleMorphingExampleScreen> createState() => _AppleMorphingExampleScreenState();
}

class _AppleMorphingExampleScreenState extends State<AppleMorphingExampleScreen> {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;

    // Apple HIG Standard 20pt Breathing Room:
    // With tabs: topPadding + 190.0
    // Without tabs: topPadding + 130.0
    final contentTopPadding = topPadding + 190.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // -------------------------------------------------------------
          // Layer 1: Body Content (NotificationListener)
          // -------------------------------------------------------------
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
                itemCount: 25,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222D) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _selectedTab == 0
                                ? CupertinoIcons.sparkles
                                : (_selectedTab == 1 ? CupertinoIcons.chart_bar : CupertinoIcons.gear),
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Card Item #${index + 1} (Tab $_selectedTab)',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pull down at the top to experience Apple elastic overscroll!',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // -------------------------------------------------------------
          // Layer 2: Apple Dynamic Morphing Glass Header
          // -------------------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: Listenable.merge([_scrollOffset, _isTabsExpanded]),
              builder: (context, _) {
                return AppleMorphingGlassHeader(
                  title: 'Apple Experience',
                  subtitle: 'Live status summary & continuous fluid morphing',
                  scrollOffset: _scrollOffset.value,
                  isTabsExpanded: _isTabsExpanded.value,
                  onBack: () => Navigator.maybePop(context),
                  actions: [
                    AppleVibrancyActionButton(
                      icon: CupertinoIcons.sparkles,
                      isSpecialAccent: true,
                      tooltip: 'AI Magic',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('AI Assistant tapped!')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    AppleVibrancyActionButton(
                      icon: CupertinoIcons.add,
                      tooltip: 'Add item',
                      onTap: () {},
                    ),
                  ],
                  tabs: AppleLiquidGlassTabs<int>(
                    items: const [
                      AppleTabItem(title: 'Overview', icon: CupertinoIcons.home, value: 0),
                      AppleTabItem(title: 'Trends', icon: CupertinoIcons.chart_bar, value: 1),
                      AppleTabItem(title: 'Settings', icon: CupertinoIcons.gear, value: 2),
                    ],
                    selectedValue: _selectedTab,
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
