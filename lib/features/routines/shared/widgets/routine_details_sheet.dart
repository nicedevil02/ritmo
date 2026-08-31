import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/routines/shared/routine_category_helper.dart';
import 'package:shamsi_date/shamsi_date.dart';

class RoutineDetailsSheet extends StatelessWidget {

  const RoutineDetailsSheet({
    super.key,
    required this.routine,
    required this.parentContext,
    this.targetDate,
    this.onReverted,
  });
  final Routine routine;
  final String? targetDate;
  final VoidCallback? onReverted;
  final BuildContext parentContext;

  static Future<T?> show<T>({
    required BuildContext context,
    required Routine routine,
    String? targetDate,
    VoidCallback? onReverted,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => RoutineDetailsSheet(
        routine: routine,
        parentContext: context,
        targetDate: targetDate,
        onReverted: onReverted,
      ),
    );
  }

  Future<void> _confirmAndUndo(BuildContext context, RitmoColors colors) async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final isToday = targetDate == todayStr;
    final dateLabel = isToday ? 'امروز' : 'تاریخ $targetDate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.card,
          title: Text(
            'لغو ثبت انجام',
            style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          content: Text(
            'آیا از لغو ثبت انجام این روتین برای $dateLabel اطمینان دارید؟',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text('خیر', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text('بله، لغو شود', style: TextStyle(color: colors.medicalRed, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed ?? false) {
      await AlarmSchedulerService.undoCompletion(routine.id, targetDate!);
      RitmoEvents.notifyRoutineChanged();
      if (parentContext.mounted) {
        RitmoToast.show(
          parentContext,
          'ثبت انجام روتین با موفقیت لغو شد.',
          iconColor: const Color(0xff10B981),
        );
      }
      onReverted?.call();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadCompletions() async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'routine_completions',
      where: 'routineId = ?',
      whereArgs: [routine.id],
      orderBy: 'completionTime DESC',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadCompletions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.all(32),
              child: const SizedBox(
                height: 180,
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
          );
        }

        final completions = snapshot.data ?? [];
        final totalCompletions = completions.length;
        final currentStreak = RoutineCategoryHelper.calculateStreak(completions);
        final hasCompletionOnTargetDate = targetDate != null && completions.any((c) => c['completionDate'] == targetDate);

        final textColor = colors.textPrimary;
        final subtitleColor = colors.textSecondary;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: RitmoGlassSheet(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: isDarkMode ? 0.30 : 0.22),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Text(
                  'جزئیات روتین: ${routine.title}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('$totalCompletions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                        Text('کل انجام‌ها', style: TextStyle(fontSize: 12, color: subtitleColor)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('🔥 $currentStreak', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.warning)),
                        Text('تداوم فعلی', style: TextStyle(fontSize: 12, color: subtitleColor)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (completions.isEmpty)
                  const Center(child: Text('تاکنون هیچ انجام شدنی ثبت نشده است.', style: TextStyle(fontSize: 12, color: Colors.grey)))
                else ...[
                  const Text('آخرین انجام‌ها:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: completions.length > 5 ? 5 : completions.length,
                      itemBuilder: (context, index) {
                        final c = completions[index];
                        final date = c['completionDate'] as String;
                        final time = DateTime.fromMillisecondsSinceEpoch(c['completionTime'] as int);
                        final timeStr = PersianDigits.convert('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
                        final type = c['resultType'] as String == 'LIGHT' ? 'نسخه سبک' : 'نسخه کامل';
                        final noteText = (c['note'] as String?)?.trim();

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatJalaliDateWithWeekday(date),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                  ),
                                  Text(
                                    '$timeStr ($type)',
                                    style: TextStyle(fontSize: 11, color: subtitleColor),
                                  ),
                                ],
                              ),
                              if (noteText != null && noteText.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  noteText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subtitleColor.withValues(alpha: 0.9),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const Divider(height: 8, thickness: 0.5),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (hasCompletionOnTargetDate) ...[
                  ElevatedButton.icon(
                    onPressed: () => _confirmAndUndo(context, colors),
                    icon: const Icon(Icons.undo_rounded, size: 16, color: Colors.white),
                    label: const Text('لغو ثبت انجام این تاریخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.medicalRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('بستن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getDayOfWeekName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'شنبه';
      case DateTime.sunday:
        return 'یکشنبه';
      case DateTime.monday:
        return 'دوشنبه';
      case DateTime.tuesday:
        return 'سه‌شنبه';
      case DateTime.wednesday:
        return 'چهارشنبه';
      case DateTime.thursday:
        return 'پنج‌شنبه';
      case DateTime.friday:
        return 'جمعه';
      default:
        return '';
    }
  }

  String _formatJalaliDateWithWeekday(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final jal = Jalali.fromDateTime(dt);
      final weekdayName = _getDayOfWeekName(dt.weekday);
      
      final yr = PersianDigits.convert(jal.year.toString());
      final mo = PersianDigits.convert(jal.month.toString().padLeft(2, '0'));
      final dy = PersianDigits.convert(jal.day.toString().padLeft(2, '0'));
      
      return '$weekdayName $yr/$mo/$dy';
    } catch (_) {
      return dateStr;
    }
  }
}
