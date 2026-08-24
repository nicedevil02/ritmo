import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
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
  int? _selectedValence;
  String? _justLoggedLabel;
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    _eventSub = RitmoEventBus().onEvents.listen((event) {
      if (event.type == RitmoEventType.moodLogged.code && mounted) {
        _loadTodayStats();
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
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
        final val = rows.first['valence'] as int?;
        setState(() {
          _selectedValence = val;
          _todayLogCount = rows.length;
          _lastLogTimeFa = RitmoNumber.fa('$hour:$minute');
        });
      }
    } catch (_) {}
  }

  Future<void> _logMood(int valence, String label) async {
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _selectedValence = valence;
      _justLoggedLabel = label;
    });

    final loggedId = await WellbeingLogGateway.instance.logMood(
      score: valence,
      source: 'QUICK_BAR',
    );

    if (loggedId != null) {
      await _loadTodayStats();
      widget.onLogChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final subtext = _justLoggedLabel != null
        ? 'ثبت شد: $_justLoggedLabel ✓'
        : (_todayLogCount > 0
              ? 'آخرین ثبت: $_lastLogTimeFa (${RitmoNumber.faInt(_todayLogCount)} ثبت امروز)'
              : 'ثبت لحظه‌ای حال روحی');

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xffEC4899).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.heart_fill,
                      color: Color(0xffEC4899),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'الان در چه حالی؟',
                    style: RitmoTextStyles.body(
                      colors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(
                  horizontal: _justLoggedLabel != null ? 8 : 4,
                  vertical: _justLoggedLabel != null ? 3 : 1,
                ),
                decoration: BoxDecoration(
                  color: _justLoggedLabel != null
                      ? const Color(0xff10B981).withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: _justLoggedLabel != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _justLoggedLabel != null
                        ? const Color(0xff10B981)
                        : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _moodButton(
                context,
                1,
                Icons.sentiment_very_dissatisfied_rounded,
                'خیلی بد',
                const Color(0xffF43F5E),
              ),
              _moodButton(
                context,
                2,
                Icons.sentiment_dissatisfied_rounded,
                'کمی خسته',
                const Color(0xffF97316),
              ),
              _moodButton(
                context,
                3,
                Icons.sentiment_neutral_rounded,
                'معمولی',
                const Color(0xffF59E0B),
              ),
              _moodButton(
                context,
                4,
                Icons.sentiment_satisfied_rounded,
                'خوب',
                const Color(0xff10B981),
              ),
              _moodButton(
                context,
                5,
                Icons.sentiment_very_satisfied_rounded,
                'عالی',
                const Color(0xff06B6D4),
              ),
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
    final isSelected = _selectedValence == valence;
    final colors = context.colors;

    return Semantics(
      button: true,
      label: 'ثبت حال: $label ${isSelected ? '(انتخاب‌شده)' : ''}',
      child: InkWell(
        onTap: () => _logMood(valence, label),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedScale(
          scale: isSelected ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? color : color.withValues(alpha: 0.09),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.28),
                        width: isSelected ? 2.2 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 14,
                                spreadRadius: 2,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : color,
                      size: isSelected ? 26 : 23,
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Center(
                          child: Icon(Icons.check, size: 10, color: color),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? color : colors.textSecondary,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
