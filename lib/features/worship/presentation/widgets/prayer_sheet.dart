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
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return toPersianDigits('$h:$m');
  }

  Future<void> _submitQuality(PrayerLogQuality quality) async {
    final nav = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final dateStr = widget.target.date.toIso8601String().substring(0, 10);
    
    for (final practiceId in widget.target.practiceIds) {
      final req = PrayerCompletion(
        prayerKey: practiceId,
        dateStr: dateStr,
        mode: quality.code,
      );

      final res = await CompletionGateway.instance.submit(req);
      if (!res.isSuccess) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(res.errorMessage ?? 'خطا در ثبت وضعیت')),
        );
        return;
      }
    }

    WorshipEngine.instance.invalidate();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: colors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 30,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.target.titleFa,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
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
                          padding: EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: colors.primary),
                    )
                  else ...[
                    if (_isExempt)
                      Container(
                        padding: EdgeInsets.all(14),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_rounded, color: colors.primary, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'وضعیت معافیت شرعی فعال است',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                      fontFamily: 'Vazirmatn',
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'در این دوران خواندن نماز تکلیف شرعی ندارد.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: colors.primary,
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
                        padding: EdgeInsets.all(14),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: colors.primary, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'هنوز وقت این نماز نرسیده است',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                      fontFamily: 'Vazirmatn',
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'زمان اذان: ${_formatTime(_startTime)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: colors.primary.withValues(alpha: 0.8),
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
                      accentColor: colors.success,
                      isDisabled: _isFuture,
                      disabledReason: 'وقت اذان نرسیده',
                    ),
                    SizedBox(height: 10),
                    _buildOptionCard(
                      context,
                      quality: PrayerLogQuality.inTime,
                      title: 'در وقت مقرر',
                      subtitle: 'خوندن ادا قبل از پایان زمان شرعی',
                      icon: Icons.check_circle_rounded,
                      accentColor: colors.warning,
                      isDisabled: _isFuture,
                      disabledReason: 'وقت اذان نرسیده',
                    ),
                    SizedBox(height: 10),
                    _buildOptionCard(
                      context,
                      quality: PrayerLogQuality.qada,
                      title: 'نماز قضا',
                      subtitle: _isDeadlinePassed
                          ? 'ثبت به عنوان نماز قضاشده بعد از وقت'
                          : 'هنوز وقت خواندن نماز باقیست (مهلت: ${_formatTime(_deadlineTime)})',
                      icon: Icons.history_rounded,
                      accentColor: colors.error,
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
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                SizedBox(width: 14),
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
                      SizedBox(height: 2),
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
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
