// lib/features/routines/presentation/widgets/planner_advanced_section.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';

class PlannerAdvancedSection extends StatelessWidget {
  const PlannerAdvancedSection({super.key, required this.controller});
  final PlannerController controller;

  Widget _buildPriorityChip(double value, String label, String iconEmoji, Color badgeColor, RitmoColors colors, bool isDark) {
    final isSelected = controller.priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          controller.priority = value;
          controller.notifyListeners();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? badgeColor.withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? const Color(0xFF1E2235).withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? badgeColor : colors.border.withValues(alpha: 0.1),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(iconEmoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnergyRuleCard({
    required String value,
    required String title,
    required String subtitle,
    required String emoji,
    required Color activeColor,
    required RitmoColors colors,
    required bool isDark,
  }) {
    final isSelected = controller.energyRule == value;
    return GestureDetector(
      onTap: () {
        controller.energyRule = value;
        controller.notifyListeners();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? const Color(0xFF16192E).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : colors.border.withValues(alpha: 0.1),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? colors.textPrimary : colors.textPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: activeColor, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final energyRules = [
      {
        'value': 'NONE',
        'title': 'پایبندی قاطع (بدون قید)',
        'subtitle': 'همیشه در برنامه پیشنهادی روزانه قرار می‌گیرد.',
        'emoji': '🎯',
        'color': colors.primary,
      },
      {
        'value': 'OFFER_LIGHT',
        'title': 'نسخه سبک خودکار در خستگی',
        'subtitle': 'هنگام افت انرژی، نسخه کوتاه و سبک (Light) پیشنهاد می‌شود.',
        'emoji': '⚡',
        'color': const Color(0xffFBBF24),
      },
      {
        'value': 'SKIP',
        'title': 'پرش خودکار هنگام خستگی',
        'subtitle': 'اگر کاربر افت انرژی داشته باشد، خودکار حذف می‌شود.',
        'emoji': '💤',
        'color': const Color(0xff3B82F6),
      },
      {
        'value': 'HIGH_ENERGY_ONLY',
        'title': 'فقط در ساعات اوج انرژی',
        'subtitle': 'فقط در پنجره‌های اوج انرژی فکری یا بدنی پیشنهاد می‌شود.',
        'emoji': '🔥',
        'color': const Color(0xffEF4444),
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF16192E).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            // Collapsible Header
            GestureDetector(
              onTap: () {
                controller.isAdvancedExpanded = !controller.isAdvancedExpanded;
                controller.notifyListeners();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'تنظیمات پیشرفته و هوشمند',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    AnimatedRotation(
                      turns: controller.isAdvancedExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Body
            if (controller.isAdvancedExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // 1. Priority Selector
                    Text(
                      'اولویت کار در برنامه روزانه',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPriorityChip(0.5, 'پایین', '🟢', Colors.green, colors, isDark),
                        const SizedBox(width: 8),
                        _buildPriorityChip(1.0, 'متوسط', '🟡', Colors.amber, colors, isDark),
                        const SizedBox(width: 8),
                        _buildPriorityChip(1.5, 'بالا', '🔴', Colors.red, colors, isDark),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 2. Zone (Realm) Selector
                    Text(
                      'زون مربوطه (قلمرو زندگی)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // Default General Zone
                          GestureDetector(
                            onTap: () {
                              controller.selectedZoneId = null;
                              controller.notifyListeners();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: controller.selectedZoneId == null
                                    ? colors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                                    : (isDark ? const Color(0xFF1E2235).withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.03)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: controller.selectedZoneId == null
                                      ? colors.primary
                                      : colors.border.withValues(alpha: 0.1),
                                  width: controller.selectedZoneId == null ? 1.6 : 1.0,
                                ),
                              ),
                              child: Text(
                                '🌐 عمومی',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: controller.selectedZoneId == null ? FontWeight.bold : FontWeight.normal,
                                  color: controller.selectedZoneId == null ? colors.textPrimary : colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...controller.availableZones.map((z) {
                            final zId = z['id'] as String;
                            final isSelected = controller.selectedZoneId == zId;
                            final emoji = z['emoji'] as String? ?? '📂';
                            final name = z['name'] as String? ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () {
                                  controller.selectedZoneId = zId;
                                  controller.notifyListeners();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                                        : (isDark ? const Color(0xFF1E2235).withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.03)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.1),
                                      width: isSelected ? 1.6 : 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    '$emoji $name',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? colors.textPrimary : colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Smart Energy Rule (نقشه راه انرژی)
                    Text(
                      'مدیریت هوشمند بر اساس سطح انرژی (RIE)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...energyRules.map((rule) {
                      return _buildEnergyRuleCard(
                        value: rule['value'] as String,
                        title: rule['title'] as String,
                        subtitle: rule['subtitle'] as String,
                        emoji: rule['emoji'] as String,
                        activeColor: rule['color'] as Color,
                        colors: colors,
                        isDark: isDark,
                      );
                    }),
                    const SizedBox(height: 16),

                    // 4. Notes / Description Input
                    Text(
                      'توضیحات و یادداشت‌های تکمیلی',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: controller.description,
                      maxLines: 2,
                      style: TextStyle(fontSize: 13, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'جزئیات، لینک‌ها، یا یادداشت‌های مرتبط با این کار...',
                        hintStyle: TextStyle(fontSize: 12, color: colors.textSecondary.withValues(alpha: 0.4)),
                        prefixIcon: Icon(Icons.notes_rounded, size: 20, color: colors.primary.withValues(alpha: 0.7)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2235).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.02),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.border.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.border.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) => controller.description = val,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
