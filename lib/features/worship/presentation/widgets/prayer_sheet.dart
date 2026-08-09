import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/completion/completion_gateway.dart';
import 'package:ritmo/core/domain/completion/completion_request.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/worship/domain/prayer_log_quality.dart';
import 'package:ritmo/features/worship/domain/prayer_target.dart';
import 'package:ritmo/features/worship/logic/fadhilat.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';

class PrayerSheet extends StatefulWidget {
  final PrayerTarget target;
  
  const PrayerSheet({super.key, required this.target});

  static Future<void> show(BuildContext context, PrayerTarget target) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PrayerSheet(target: target),
    );
  }

  @override
  State<PrayerSheet> createState() => _PrayerSheetState();
}

class _PrayerSheetState extends State<PrayerSheet> {
  bool _isLoading = true;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isFuture = false;

  @override
  void initState() {
    super.initState();
    _initQuality();
  }

  Future<void> _initQuality() async {
    final now = DateTime.now();
    final pTimes = await WorshipEngine.instance.prayerTimes(widget.target.date);
    
    // Always group Dhuhr/Asr together and Maghrib/Isha together for time windows
    if (widget.target.groupKey.contains('FAJR')) {
      _startTime = pTimes.fajr;
      _endTime = pTimes.sunrise;
    } else if (widget.target.groupKey.contains('DHUHR') || widget.target.groupKey.contains('ASR')) {
      _startTime = pTimes.dhuhr;
      _endTime = pTimes.maghrib;
    } else if (widget.target.groupKey.contains('MAGHRIB') || widget.target.groupKey.contains('ISHA')) {
      _startTime = pTimes.maghrib;
      _endTime = pTimes.midnightShari;
    } else {
      _startTime = widget.target.date;
      _endTime = widget.target.date.add(const Duration(hours: 4));
    }
    
    if (now.isBefore(_startTime!)) {
      _isFuture = true;
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _submitQuality(PrayerLogQuality quality) {
    if (_isFuture) return;
    HapticFeedback.mediumImpact();
    
    for (final pId in widget.target.practiceIds) {
      final completion = PrayerCompletion(
        prayerKey: pId,
        dateStr: widget.target.date.toIso8601String().substring(0, 10),
        mode: quality.name.toUpperCase(),
      );
      CompletionGateway.instance.submit(completion);
    }
    
    Navigator.of(context).pop(true);
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return toPersianDigits('$h:$m');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final borderRadius = const BorderRadius.vertical(top: Radius.circular(32));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121824).withValues(alpha: 0.94) : colors.surfaceElevated,
        borderRadius: borderRadius,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : colors.border.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle Bar
                  Container(
                    width: 42,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),

                  // Header Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ثبت وضعیت ${widget.target.titleFa}',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _startTime != null ? 'اذان: ${_formatTime(_startTime)}' : 'ثبت مستقیم با لمس گزینه',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surfaceSunken,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    )
                  else if (_isFuture)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'وقت این نماز هنوز نرسیده است',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'زمان اذان: ${_formatTime(_startTime)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _buildOptionCard(
                      context,
                      quality: PrayerLogQuality.onTime,
                      title: 'اول وقت (فضیلت)',
                      subtitle: 'خوندن در بازه زمانی طلایی فضیلت اول وقت',
                      icon: Icons.stars_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 10),
                    _buildOptionCard(
                      context,
                      quality: PrayerLogQuality.inTime,
                      title: 'در وقت مقرر',
                      subtitle: 'خوندن ادا قبل از پایان زمان شرعی',
                      icon: Icons.check_circle_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    if (_endTime != null && DateTime.now().isAfter(_endTime!)) ...[
                      const SizedBox(height: 10),
                      _buildOptionCard(
                        context,
                        quality: PrayerLogQuality.qada,
                        title: 'نماز قضا',
                        subtitle: 'ثبت به عنوان نماز قضاشده بعد از وقت',
                        icon: Icons.history_rounded,
                        accentColor: const Color(0xFFEF4444),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required PrayerLogQuality quality,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _submitQuality(quality),
        borderRadius: BorderRadius.circular(16),
        splashColor: accentColor.withValues(alpha: 0.15),
        highlightColor: accentColor.withValues(alpha: 0.08),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSunken.withValues(alpha: 0.7) : colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
