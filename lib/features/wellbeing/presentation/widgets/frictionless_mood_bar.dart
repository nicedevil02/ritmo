import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/wellbeing/logic/wellbeing_log_gateway.dart';

class FrictionlessMoodBar extends StatefulWidget {
  const FrictionlessMoodBar({super.key, required this.onLogChanged});

  final VoidCallback onLogChanged;

  @override
  State<FrictionlessMoodBar> createState() => _FrictionlessMoodBarState();
}

class _FrictionlessMoodBarState extends State<FrictionlessMoodBar> {
  int _todayLogCount = 0;
  String? _lastLogTimeFa;
  String? _lastLoggedId;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
  }

  Future<void> _loadTodayStats() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final todayMs = RitmoDate.startOfDayMillis(DateTime.now());
      final rows = await db.query(
        'mood_logs',
        where: 'loggedAt >= ?',
        whereArgs: [todayMs],
        orderBy: 'loggedAt DESC',
      );
      if (rows.isNotEmpty && mounted) {
        final lastTime = DateTime.fromMillisecondsSinceEpoch(
          rows.first['loggedAt'] as int,
        );
        final hour = lastTime.hour.toString().padLeft(2, '0');
        final minute = lastTime.minute.toString().padLeft(2, '0');
        setState(() {
          _todayLogCount = rows.length;
          _lastLogTimeFa = RitmoNumber.fa('$hour:$minute');
          _lastLoggedId = rows.first['id'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _logMood(int valence, String label) async {
    RitmoHapticsPolicy.tap();
    final loggedId = await WellbeingLogGateway.instance.logMood(
      score: valence,
      source: 'QUICK_BAR',
    );

    if (loggedId != null) {
      final now = DateTime.now();
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');

      setState(() {
        _lastLoggedId = loggedId;
        _todayLogCount += 1;
        _lastLogTimeFa = RitmoNumber.fa('$hour:$minute');
      });

      widget.onLogChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حال شما ثبت شد ($label)'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'برگردان',
              onPressed: () async {
                if (_lastLoggedId != null) {
                  await WellbeingLogGateway.instance.deleteMood(_lastLoggedId!);
                  if (mounted) {
                    await _loadTodayStats();
                    widget.onLogChanged();
                  }
                }
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final subtext = _todayLogCount > 0
        ? 'آخرین ثبت: $_lastLogTimeFa (${RitmoNumber.faInt(_todayLogCount)} ثبت امروز)'
        : 'ثبت لحظه‌ای حال روحی';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: RitmoSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الان در چه حالی؟',
                style: RitmoTextStyles.body(colors.textPrimary).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtext,
                style: RitmoTextStyles.caption(colors.textSecondary).copyWith(fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _moodButton(context, 1, Icons.sentiment_very_dissatisfied_rounded, 'خیلی بد', const Color(0xffF43F5E)),
              _moodButton(context, 2, Icons.sentiment_dissatisfied_rounded, 'کمی خسته', const Color(0xffF97316)),
              _moodButton(context, 3, Icons.sentiment_neutral_rounded, 'معمولی', const Color(0xffF59E0B)),
              _moodButton(context, 4, Icons.sentiment_satisfied_rounded, 'خوب', const Color(0xff10B981)),
              _moodButton(context, 5, Icons.sentiment_very_satisfied_rounded, 'عالی', const Color(0xff06B6D4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moodButton(
    BuildContext context,
    int valence,
    IconData icon,
    String label,
    Color color,
  ) {
    return Semantics(
      button: true,
      label: 'ثبت حال: $label',
      child: InkWell(
        onTap: () => _logMood(valence, label),
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
