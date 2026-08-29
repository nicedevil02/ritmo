import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_finish_session_use_case.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/player/templates/mv_distance_template.dart';
import 'package:ritmo/features/supplementary_sports/presentation/player/templates/mv_timed_template.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_hub_screen.dart';

class PhaseWorkoutOption {
  final String label;
  final String emoji;
  final String kindCode;
  final MvSessionMode mode;

  const PhaseWorkoutOption({
    required this.label,
    required this.emoji,
    required this.kindCode,
    required this.mode,
  });
}

class CycleWorkoutCard extends StatelessWidget {
  const CycleWorkoutCard({
    super.key,
    required this.phase,
    this.onNavigateToWorkout,
  });

  final CyclePhase phase;
  final VoidCallback? onNavigateToWorkout;

  void _openWorkoutHub(BuildContext context) {
    if (onNavigateToWorkout != null) {
      onNavigateToWorkout!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MvHubScreen()),
      );
    }
  }

  Future<void> _startSpecificWorkout(
    BuildContext context,
    PhaseWorkoutOption option,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = MvSession(
      id: 'cycle_${now}_${option.kindCode}',
      kindCode: option.kindCode,
      sessionMode: option.mode,
      status: MvSessionStatus.active,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    MvSessionFeeling deriveFeeling(int rpe) {
      if (rpe <= 4) return MvSessionFeeling.easy;
      if (rpe <= 7) return MvSessionFeeling.good;
      return MvSessionFeeling.hard;
    }

    Widget playerWidget;
    if (option.mode == MvSessionMode.distance) {
      playerWidget = MvDistanceTemplate(
        session: session,
        onFinish: (elapsedSeconds, distanceM, rpe1To10) async {
          final endNow = DateTime.now().millisecondsSinceEpoch;
          final finished = session.copyWith(
            distanceM: distanceM,
            rpe1To10: rpe1To10,
            status: MvSessionStatus.completed,
            endedAt: elapsedSeconds > 0
                ? (session.startedAt + (elapsedSeconds * 1000))
                : endNow,
          );
          try {
            await MvFinishSessionUseCase().execute(
              session: finished,
              setLogs: const [],
              feeling: deriveFeeling(rpe1To10),
              rpe1To10: rpe1To10,
              distanceM: distanceM,
            );
          } catch (e) {
            debugPrint('Failed to finish workout: $e');
          }
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تمرین ${option.label} با موفقیت ثبت شد و به انرژی امروز اضافه گردید! ⚡',
                  style: const TextStyle(fontFamily: 'Vazirmatn'),
                ),
                backgroundColor: Colors.teal.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );
    } else {
      playerWidget = MvTimedTemplate(
        session: session,
        onFinish: (elapsedSeconds, rpe1To10) async {
          final endNow = DateTime.now().millisecondsSinceEpoch;
          final finished = session.copyWith(
            rpe1To10: rpe1To10,
            status: MvSessionStatus.completed,
            endedAt: elapsedSeconds > 0
                ? (session.startedAt + (elapsedSeconds * 1000))
                : endNow,
          );
          try {
            await MvFinishSessionUseCase().execute(
              session: finished,
              setLogs: const [],
              feeling: deriveFeeling(rpe1To10),
              rpe1To10: rpe1To10,
            );
          } catch (e) {
            debugPrint('Failed to finish workout: $e');
          }
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تمرین ${option.label} با موفقیت ثبت شد و به انرژی امروز اضافه گردید! ⚡',
                  style: const TextStyle(fontFamily: 'Vazirmatn'),
                ),
                backgroundColor: Colors.teal.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => playerWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var title = '';
    var description = '';
    var intensityLabel = '';
    var goldenWindow = '';
    var options = <PhaseWorkoutOption>[];
    var icon = CupertinoIcons.sparkles;
    var phaseColor = colors.primary;

    switch (phase) {
      case CyclePhase.menstrual:
        title = 'ورزش: کشش و ریکاوری';
        description =
            'با توجه به فاز قاعدگی، امروز تمرینات سبک را انتخاب کنید تا بدن آرامش و ریکاوری کامل داشته باشد.';
        intensityLabel = 'سبک و آرام 🌸';
        goldenWindow = '۱۰:۰۰ تا ۱۲:۰۰ (نور ملایم صبحگاهی)';
        options = const [
          PhaseWorkoutOption(label: 'یوگا', emoji: '🧘‍♀️', kindCode: 'YOGA', mode: MvSessionMode.timed),
          PhaseWorkoutOption(label: 'کشش ملایم', emoji: '🌿', kindCode: 'STRETCHING', mode: MvSessionMode.timed),
          PhaseWorkoutOption(label: 'پیاده‌روی', emoji: '🚶‍♀️', kindCode: 'WALKING', mode: MvSessionMode.distance),
        ];
        icon = CupertinoIcons.heart_fill;
        phaseColor = colors.primary;
      case CyclePhase.ovulation:
        title = 'ورزش: قدرت و استقامت';
        description =
            'شما در فاز تخمک‌گذاری و اوج انرژی ماهانه هستید. بهترین زمان برای تمرینات پرفشار و چالش عضلات است.';
        intensityLabel = 'حداکثر توان 🔥';
        goldenWindow = '۱۷:۰۰ تا ۱۹:۰۰ (اوج قدرت عضلانی)';
        options = const [
          PhaseWorkoutOption(label: 'وزنه', emoji: '🏋️‍♀️', kindCode: 'BODYWEIGHT', mode: MvSessionMode.timed),
          PhaseWorkoutOption(label: 'اینتروال', emoji: '⏱️', kindCode: 'RUNNING', mode: MvSessionMode.distance),
          PhaseWorkoutOption(label: 'پرتوان', emoji: '💥', kindCode: 'BODYWEIGHT', mode: MvSessionMode.timed),
        ];
        icon = CupertinoIcons.flame_fill;
        phaseColor = colors.warning;
      case CyclePhase.luteal:
        title = 'ورزش: پیلاتس و تعادل';
        description =
            'در فاز لوتئال با افزایش پروژسترون، تمرینات با شدت متوسط، ورزش‌های تعادلی و روتین‌های کششی آرام‌بخش توصیه می‌شوند.';
        intensityLabel = 'متوسط و متمرکز 🧘‍♀️';
        goldenWindow = '۰۸:۰۰ تا ۱۰:۰۰ (پرهیز از دمای بالا)';
        options = const [
          PhaseWorkoutOption(label: 'پیلاتس', emoji: '🧘‍♀️', kindCode: 'PILATES', mode: MvSessionMode.timed),
          PhaseWorkoutOption(label: 'شنا', emoji: '🏊', kindCode: 'SWIMMING', mode: MvSessionMode.timed),
          PhaseWorkoutOption(label: 'پیاده‌روی', emoji: '🚶‍♀️', kindCode: 'WALKING', mode: MvSessionMode.distance),
        ];
        icon = CupertinoIcons.waveform_path_ecg;
        phaseColor = colors.primary;
      case CyclePhase.follicular:
        title = 'ورزش: کاردیو و هوازی';
        description =
            'در فاز فولیکولار سطح انرژی رو به افزایش است. زمان عالی برای ورزش‌های هوازی، دویدن و بالا بردن ضربان قلب است.';
        intensityLabel = 'پرانرژی و پویا ⚡';
        goldenWindow = '۱۶:۰۰ تا ۱۹:۰۰ (اوج متابولیسم و تنفس)';
        options = const [
          PhaseWorkoutOption(label: 'دویدن', emoji: '🏃‍♀️', kindCode: 'RUNNING', mode: MvSessionMode.distance),
          PhaseWorkoutOption(label: 'دوچرخه', emoji: '🚴', kindCode: 'CYCLING', mode: MvSessionMode.distance),
          PhaseWorkoutOption(label: 'ایروبیک', emoji: '💃', kindCode: 'BODYWEIGHT', mode: MvSessionMode.timed),
        ];
        icon = CupertinoIcons.bolt_fill;
        phaseColor = colors.accent;
      case CyclePhase.pregnancy:
        title = 'ورزش دوران بارداری';
        description =
            'تمرینات تنفسی، پیاده‌روی سبک و حرکات تقویتی مجاز دوران بارداری با نظر پزشک توصیه می‌شود.';
        intensityLabel = 'ایمن و ملایم 🤰';
        goldenWindow = 'صبح یا ساعات خنک عصر';
        options = const [
          PhaseWorkoutOption(label: 'پیاده‌روی', emoji: '🚶‍♀️', kindCode: 'WALKING', mode: MvSessionMode.distance),
          PhaseWorkoutOption(label: 'تنفس', emoji: '🌬️', kindCode: 'YOGA', mode: MvSessionMode.timed),
          PhaseWorkoutOption(label: 'یوگا', emoji: '🧘‍♀️', kindCode: 'YOGA', mode: MvSessionMode.timed),
        ];
        icon = CupertinoIcons.heart_circle_fill;
        phaseColor = colors.accent;
      case CyclePhase.dataStale:
      case CyclePhase.noData:
        title = 'ورزش متناسب با ریتم';
        description =
            'با ثبت اطلاعات دوره، برنامه و حرکات پیشنهادی ورزشی شما به طور خودکار متناسب با فاز چرخه بدنتان همگام می‌شود.';
        intensityLabel = 'متعادل 🌿';
        goldenWindow = 'زمان دلخواه متناسب با انرژی روز';
        options = const [
          PhaseWorkoutOption(label: 'پیاده‌روی', emoji: '🚶‍♀️', kindCode: 'WALKING', mode: MvSessionMode.distance),
          PhaseWorkoutOption(label: 'نرمش', emoji: '🧘‍♀️', kindCode: 'STRETCHING', mode: MvSessionMode.timed),
          PhaseWorkoutOption(label: 'هوازی', emoji: '🏃‍♀️', kindCode: 'RUNNING', mode: MvSessionMode.distance),
        ];
        icon = CupertinoIcons.sparkles;
        phaseColor = colors.textSecondary;
    }

    final primaryOption = options.isNotEmpty
        ? options.first
        : const PhaseWorkoutOption(
            label: 'ورزش',
            emoji: '⚡',
            kindCode: 'WALKING',
            mode: MvSessionMode.distance,
          );

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ۱. هدر: آیکون گرد فاز + عنوان ورزش + بج شدت فاز
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: phaseColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: phaseColor.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(icon, color: phaseColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: phaseColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: phaseColor.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    intensityLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: phaseColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ۲. ساعت طلایی تمرین
            Row(
              children: [
                Icon(
                  CupertinoIcons.clock,
                  size: 13.5,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'ساعت بهینه:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    goldenWindow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ۳. توضیحات علمی و هورمونی
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),

            // ۴. چیپ‌های تمرینات پیشنهادی (لمس هر کدام مستقیماً پلیر همان ورزش را باز می‌کند)
            Row(
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _startSpecificWorkout(context, options[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : colors.border.withValues(alpha: 0.7),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '${options[i].label} ${options[i].emoji}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // ۵. نوار فوتر: شروع مستقیم تمرین شاخص + لینک به ماژول کامل
            const SizedBox(height: 8),
            Divider(
              color: colors.border.withValues(alpha: 0.6),
              height: 16,
            ),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _startSpecificWorkout(context, primaryOption),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.play_circle_fill,
                            size: 18,
                            color: phaseColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'شروع ${primaryOption.label} (${primaryOption.emoji})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openWorkoutHub(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ماژول ورزش',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          CupertinoIcons.chevron_left,
                          size: 13,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
