import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/goals/logic/planning_controller.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/models/goal_models.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:ritmo/features/goals/presentation/widgets/create_commitment_sheet.dart';

class MonthPlanSection extends StatelessWidget {
  const MonthPlanSection({
    super.key,
    required this.controller,
    this.upcomingTimeline = const [],
  });

  final PlanningController controller;
  final List<dynamic> upcomingTimeline;

  Future<void> _showAddSkippedItemDialog(BuildContext context, PlanningCycle cycle) async {
    final textController = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('افزودن به لیست «عمداً انجام نمی‌دهم»', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 16)),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'مثلاً: پروژه فرعی، آزمون‌های آزمایشی اضافی...',
              hintStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, textController.text.trim()),
              child: const Text('افزودن'),
            ),
          ],
        ),
      ),
    );

    if (res != null && res.isNotEmpty) {
      final themeData = cycle.theme != null
          ? Map<String, dynamic>.from(jsonDecode(cycle.theme!) as Map)
          : <String, dynamic>{};
      final skipList = ((themeData['intentionallySkipped'] as List?)?.cast<String>() ?? []).toList();
      skipList.add(res);
      themeData['intentionallySkipped'] = skipList;

      await PlanningRepository.instance.updateCycleTheme(cycle.id, jsonEncode(themeData));
      controller.loadHorizon(PlanningHorizon.month);
      if (context.mounted) RitmoToast.show(context, 'به لیست رهاشده‌ها اضافه شد 🚫');
    }
  }

  Future<void> _removeSkippedItem(BuildContext context, PlanningCycle cycle, String itemToRemove) async {
    final themeData = cycle.theme != null
        ? Map<String, dynamic>.from(jsonDecode(cycle.theme!) as Map)
        : <String, dynamic>{};
    final skipList = ((themeData['intentionallySkipped'] as List?)?.cast<String>() ?? []).toList();
    skipList.remove(itemToRemove);
    themeData['intentionallySkipped'] = skipList;

    await PlanningRepository.instance.updateCycleTheme(cycle.id, jsonEncode(themeData));
    controller.loadHorizon(PlanningHorizon.month);
    if (context.mounted) RitmoToast.show(context, 'از لیست حذف شد');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final cycle = controller.activeCycle;
    final themeData = cycle?.theme != null
        ? jsonDecode(cycle!.theme!) as Map<String, dynamic>?
        : null;
    final skipItems =
        (themeData?['intentionallySkipped'] as List?)?.cast<String>() ?? [];

    final monthCommitments = controller.commitments;
    final totalCommitmentMinutes =
        monthCommitments.fold<int>(0, (acc, c) => acc + c.effortMinutes);
    final totalCommitmentHours = (totalCommitmentMinutes / 60).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Fixed Realities of Month (U-10 timeline integration)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note, color: colors.goldAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'واقعیت‌های قطعی این ماه',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (upcomingTimeline.isEmpty)
                  Text(
                    'سررسید یا رویداد قفل‌شده‌ای برای این ماه ثبت نشده است.',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  )
                else
                  Column(
                    children: upcomingTimeline.take(4).map((item) {
                      final title =
                          item is Goal ? item.title : (item.toString());
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 13,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Month Focuses
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تمرکزهای اصلی ماه (حداکثر ۳ مورد)',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (monthCommitments.length < 3)
                      TextButton.icon(
                        onPressed: () {
                          CreateCommitmentSheet.show(
                            context,
                            initialHorizon: PlanningHorizon.month,
                            onSaved: () => controller.loadHorizon(PlanningHorizon.month),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('افزودن تمرکز', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (monthCommitments.isEmpty)
                  Text(
                    'هنوز تمرکز ماهانه‌ای تعریف نشده است. اهداف فعال به عنوان پیش‌فرض در نظر گرفته می‌شوند.',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  )
                else
                  Column(
                    children: monthCommitments.take(3).map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildFocusTile(
                          context,
                          c,
                          'اولویت: ${c.importance.name.toUpperCase()}',
                          '${PersianDigits.toPersian((c.effortMinutes / 60).toStringAsFixed(1))} ساعت',
                          colors,
                        ),
                      );
                    }).toList(),
                  ),
                const Divider(height: 24),
                Text(
                  'نگهداری زندگی (بدون سقف)',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ورزش، خواب منظم، روتین‌های روزانه',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Month Budget
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بودجهٔ ماهانه در برابر ظرفیت',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalCommitmentHours > 0
                        ? (totalCommitmentHours / 120.0).clamp(0.0, 1.0)
                        : 0.2,
                    minHeight: 10,
                    backgroundColor: colors.bg,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'بودجه تعهدشده: ${PersianDigits.toPersian(totalCommitmentHours.toString())} ساعت',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      'ظرفیت برآوردی ماه: ${PersianDigits.toPersian('120')} ساعت',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Week by Week
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هفته‌به‌هفته',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildWeekRow(context, 'هفته اول', 'فعال', colors),
                _buildWeekRow(context, 'هفته دوم', 'پیش‌نویس', colors),
                _buildWeekRow(context, 'هفته سوم', 'برنامه‌ریزی‌نشده', colors),
                _buildWeekRow(context, 'هفته چهارم', 'برنامه‌ریزی‌نشده', colors),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5. Intentionally Skipped List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'این ماه عمداً انجام نمی‌دهم 🚫',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (cycle != null)
                      TextButton.icon(
                        onPressed: () => _showAddSkippedItemDialog(context, cycle),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('افزودن مورد', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (skipItems.isEmpty)
                  Text(
                    'هیچ کاری عمداً کنار گذاشته نشده است.',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  )
                else
                  Column(
                    children: skipItems.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              if (cycle != null)
                                IconButton(
                                  icon: Icon(Icons.close, color: colors.error, size: 16),
                                  onPressed: () => _removeSkippedItem(context, cycle, item),
                                )
                              else
                                Icon(Icons.close, color: colors.error, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusTile(
    BuildContext context,
    PlanningCommitment commitment,
    String subtitle,
    String hours,
    RitmoColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commitment.title,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                hours,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 16),
                onSelected: (val) async {
                  if (val == 'drop') {
                    await PlanningRepository.instance.dropCommitment(
                      commitment.id,
                      reason: 'حذف از تمرکزهای ماه',
                      nowMs: DateTime.now().millisecondsSinceEpoch,
                    );
                    controller.loadHorizon(PlanningHorizon.month);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'drop', child: Text('حذف از تمرکز ماه')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekRow(
    BuildContext context,
    String weekName,
    String status,
    RitmoColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            weekName,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              color: status == 'فعال' ? colors.primary : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
