import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_personal_record.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// شیت نمایش جزئیات و تاریخچهٔ فعالیت (ActivityDetailsSheet)
/// شامل خلاصه، متریک‌ها، سوابق شخصی واقعی، و دکمه‌های «افزودن به برنامه» و «شروع همین حالا».
class ActivityDetailsSheet extends StatefulWidget {
  const ActivityDetailsSheet({
    super.key,
    required this.activityKind,
    this.occurrenceService,
    this.logService,
    this.progressService,
  });

  final MovementActivityKind activityKind;
  final MovementOccurrenceService? occurrenceService;
  final MovementLogService? logService;
  final MovementProgressService? progressService;

  static Future<void> show(
    BuildContext context, {
    required MovementActivityKind activityKind,
    MovementOccurrenceService? occurrenceService,
    MovementLogService? logService,
    MovementProgressService? progressService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivityDetailsSheet(
        activityKind: activityKind,
        occurrenceService: occurrenceService,
        logService: logService,
        progressService: progressService,
      ),
    );
  }

  @override
  State<ActivityDetailsSheet> createState() => _ActivityDetailsSheetState();
}

class _ActivityDetailsSheetState extends State<ActivityDetailsSheet> {
  late final MovementOccurrenceService _occurrenceService;
  late final MovementLogService _logService;
  late final MovementProgressService _progressService;

  int _sessionCount = 0;
  DateTime? _lastSessionDate;
  MovementPersonalRecord? _bestRecord;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _occurrenceService =
        widget.occurrenceService ?? MovementOccurrenceService();
    _logService = widget.logService ?? MovementLogService();
    _progressService = widget.progressService ?? MovementProgressService();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final logs = await _logService.getLogsForActivityKind(
        widget.activityKind.id,
      );
      final prs = await _progressService.getPersonalRecords();

      final kindPrs = prs
          .where((p) => p.activityKindId == widget.activityKind.id)
          .toList();

      if (mounted) {
        setState(() {
          _sessionCount = logs.length;
          _lastSessionDate = logs.isNotEmpty ? logs.first.createdAt : null;
          _bestRecord = kindPrs.isNotEmpty ? kindPrs.first : null;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  String _formatJalali(DateTime dt) {
    try {
      final j = Jalali.fromDateTime(dt);
      return '${toPersianDigits(j.day)} ${j.formatter.mN} ${toPersianDigits(j.year)}';
    } catch (_) {
      return dt.toIso8601String().substring(0, 10);
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'directions_walk':
        return Icons.directions_walk_rounded;
      case 'directions_run':
        return Icons.directions_run_rounded;
      case 'directions_bike':
        return Icons.directions_bike_rounded;
      case 'pool':
        return Icons.pool_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'hiking':
        return Icons.hiking_rounded;
      case 'self_improvement':
        return Icons.self_improvement_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  void _handleStartNow() {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(
      MovementRoutes.liveSession,
      arguments: {'activityKindId': widget.activityKind.id},
    );
  }

  void _handleAddToPlan() {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(
      MovementRoutes.planEditor,
      arguments: {'activityKindId': widget.activityKind.id},
    );
  }

  Future<void> _handleArchive() async {
    await _occurrenceService.archiveCustomActivityKind(widget.activityKind.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(RitmoRadius.sheet),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(RitmoSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // نوار بالای شیت
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: RitmoSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),
              ),

              // هدر با آیکون و نام
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: sportsColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                    ),
                    child: Icon(
                      _getIconData(widget.activityKind.icon),
                      color: sportsColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activityKind.nameFa,
                          style: RitmoTextStyles.cardTitle(colors.textPrimary),
                        ),
                        if (widget.activityKind.nameEn != null)
                          Text(
                            widget.activityKind.nameEn!,
                            style: RitmoTextStyles.caption(
                              colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.activityKind.isCustom)
                    IconButton(
                      onPressed: _handleArchive,
                      icon: const Icon(Icons.archive_outlined),
                      tooltip: 'بایگانی فعالیت',
                      color: colors.textTertiary,
                    ),
                ],
              ),
              const SizedBox(height: RitmoSpacing.lg),

              // بخش سوابق شخصی واقعی
              Text(
                'سوابق و تاریخچهٔ شما:',
                style: RitmoTextStyles.label(colors.textPrimary),
              ),
              const SizedBox(height: RitmoSpacing.sm),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(RitmoSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                ),
                child: _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'تعداد جلسات انجام‌شده:',
                                style: RitmoTextStyles.caption(
                                  colors.textSecondary,
                                ),
                              ),
                              Text(
                                '${toPersianDigits(_sessionCount)} جلسه',
                                style: RitmoTextStyles.body(
                                  colors.textPrimary,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (_lastSessionDate != null) ...[
                            const SizedBox(height: RitmoSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'آخرین بار:',
                                  style: RitmoTextStyles.caption(
                                    colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  _formatJalali(_lastSessionDate!),
                                  style: RitmoTextStyles.caption(
                                    colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_bestRecord != null) ...[
                            const SizedBox(height: RitmoSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'بهترین رکورد:',
                                  style: RitmoTextStyles.caption(
                                    colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${toPersianDigits(_bestRecord!.value)} ${_bestRecord!.unit}',
                                  style: RitmoTextStyles.caption(
                                    sportsColor,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: RitmoSpacing.xl),

              // دکمه‌های اکشن دوگانه
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleAddToPlan,
                      icon: const Icon(Icons.event_note_outlined, size: 18),
                      label: const Text(MovementStrings.libraryAddToPlan),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          48,
                          MovementLayout.kPrimaryButtonHeight,
                        ),
                        side: BorderSide(color: sportsColor),
                        foregroundColor: sportsColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RitmoRadius.field,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleStartNow,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text(MovementStrings.libraryStartNow),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(
                          48,
                          MovementLayout.kPrimaryButtonHeight,
                        ),
                        backgroundColor: sportsColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RitmoRadius.field,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
