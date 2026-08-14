import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/completion/completion_gateway.dart';
import 'package:ritmo/core/domain/completion/completion_request.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_snackbar.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/worship/domain/prayer_log_quality.dart';
import 'package:ritmo/features/worship/domain/prayer_target.dart';
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
  DateTime? _deadlineTime;
  bool _isFuture = false;
  bool _isDeadlinePassed = false;
  bool _isExempt = false;

  @override
  void initState() {
    super.initState();
    _initQuality();
  }

  Future<void> _initQuality() async {
    final now = DateTime.now();
    final pTimes = await WorshipEngine.instance.prayerTimes(widget.target.date);
    final dayCtx = await WorshipEngine.instance.dayContext(widget.target.date);
    _isExempt = dayCtx.prayerExempt;
    
    // Always group Dhuhr/Asr together and Maghrib/Isha together for time windows
    if (widget.target.groupKey.contains('FAJR')) {
      _startTime = pTimes.fajr;
      _deadlineTime = pTimes.sunrise;
    } else if (widget.target.groupKey.contains('DHUHR') || widget.target.groupKey.contains('ASR')) {
      _startTime = pTimes.dhuhr;
      _deadlineTime = pTimes.sunset;
    } else if (widget.target.groupKey.contains('MAGHRIB') || widget.target.groupKey.contains('ISHA')) {
      _startTime = pTimes.maghrib;
      _deadlineTime = pTimes.midnightShari;
    } else {
      _startTime = widget.target.date;
      _deadlineTime = null;
    }
    
    if (now.isBefore(_startTime!)) {
      _isFuture = true;
    }
    
    // Check if the prayer deadline has passed (can mark as qada)
    if (_deadlineTime != null && now.isAfter(_deadlineTime!)) {
      _isDeadlinePassed = true;
    }
    // For past days (not today), deadline is always passed
    final today = DateTime.now();
    final targetDay = widget.target.date;
    if (targetDay.year < today.year ||
        (targetDay.year == today.year && targetDay.month < today.month) ||
        (targetDay.year == today.year && targetDay.month == today.month && targetDay.day < today.day)) {
      _isDeadlinePassed = true;
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _submitQuality(PrayerLogQuality quality) async {
    final dateStr = widget.target.date.toIso8601String().substring(0, 10);
    bool allSuccess = true;
    String? errorMsg;

    for (final pId in widget.target.practiceIds) {
      final completion = PrayerCompletion(
        prayerKey: pId,
        dateStr: dateStr,
        mode: quality.code,
      );
      final outcome = await CompletionGateway.instance.submit(completion);
      if (!outcome.isSuccess) {
        allSuccess = false;
        errorMsg = outcome.errorMessage ?? 'خطا در ثبت کیفیت نماز';
        break;
      }
    }

    if (!mounted) return;

    if (allSuccess) {
      Navigator.of(context).pop(true);
    } else {
      RitmoSnackbar.warning(context, errorMsg ?? 'ثبت انجام نشد.');
    }
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
        color: isDark ? const Color(0xFF151A18).withValues(alpha: 0.96) : const Color(0xFFFFFEFB).withValues(alpha: 0.98),
        borderRadius: borderRadius,
        border: Border.all(
          color: isDark ? const Color(0xFF25443A) : const Color(0xFFE8E0CD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
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
                  else ...[
                    if (_isExempt)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_moon_rounded, color: Color(0xFF8B5CF6), size: 24),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'معافیت شرعی (پریود) ثبت شده است',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B5CF6),
                                      fontFamily: 'Vazirmatn',
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'برای این روز نیازی به خواندن یا قضای نمازهای واجب نیست.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF8B5CF6),
                                      fontFamily: 'Vazirmatn',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_isFuture)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'هنوز وقت این نماز نرسیده است',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontFamily: 'Vazirmatn',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'زمان اذان: ${_formatTime(_startTime)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.blue.withValues(alpha: 0.8),
                                      fontFamily: 'Vazirmatn',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildOptionCard(
                      context,
                      quality: PrayerLogQuality.onTime,
                      title: 'اول وقت (فضیلت)',
                      subtitle: 'خوندن در بازه زمانی طلایی فضیلت اول وقت',
                      icon: Icons.stars_rounded,
                      accentColor: const Color(0xFF10B981),
                      isDisabled: _isFuture,
                      disabledReason: 'وقت اذان نرسیده',
                    ),
                    const SizedBox(height: 10),
                    _buildOptionCard(
                      context,
                      quality: PrayerLogQuality.inTime,
                      title: 'در وقت مقرر',
                      subtitle: 'خوندن ادا قبل از پایان زمان شرعی',
                      icon: Icons.check_circle_rounded,
                      accentColor: const Color(0xFFF59E0B),
                      isDisabled: _isFuture,
                      disabledReason: 'وقت اذان نرسیده',
                    ),
                    const SizedBox(height: 10),
                    _buildOptionCard(
                      context,
                      quality: PrayerLogQuality.qada,
                      title: 'نماز قضا',
                      subtitle: _isDeadlinePassed
                          ? 'ثبت به عنوان نماز قضاشده بعد از وقت'
                          : 'هنوز وقت خواندن نماز باقیست (مهلت: ${_formatTime(_deadlineTime)})',
                      icon: Icons.history_rounded,
                      accentColor: const Color(0xFFEF4444),
                      isDisabled: !_isDeadlinePassed,
                      disabledReason: 'هنوز وقت خواندن نماز باقیست',
                    ),
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
    bool isDisabled = false,
    String? disabledReason,
  }) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = isDisabled ? colors.textTertiary : accentColor;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : () => _submitQuality(quality),
          borderRadius: BorderRadius.circular(16),
          splashColor: isDisabled ? null : accentColor.withValues(alpha: 0.15),
          highlightColor: isDisabled ? null : accentColor.withValues(alpha: 0.08),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSunken.withValues(alpha: 0.7) : colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: effectiveColor.withValues(alpha: isDisabled ? 0.15 : 0.35),
                width: 1.2,
              ),
              boxShadow: isDisabled ? null : [
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
                    color: effectiveColor.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    isDisabled ? Icons.lock_outline_rounded : icon,
                    color: effectiveColor,
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
                          color: isDisabled ? colors.textTertiary : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          color: isDisabled ? colors.textTertiary : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isDisabled ? Icons.lock_outline_rounded : Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: isDisabled ? colors.textTertiary : colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
