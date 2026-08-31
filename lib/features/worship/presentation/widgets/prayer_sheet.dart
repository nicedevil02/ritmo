import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/completion/completion_gateway.dart';
import 'package:ritmo/core/domain/completion/completion_request.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/worship/domain/prayer_log_quality.dart';
import 'package:ritmo/features/worship/domain/prayer_target.dart';
import 'package:ritmo/features/worship/logic/worship_cache_bus.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';

class PrayerSheet extends StatefulWidget {
  final PrayerTarget target;
  
  const PrayerSheet({super.key, required this.target});

  static Future<bool?> show(BuildContext context, PrayerTarget target) {
    return showModalBottomSheet<bool>(
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
    try {
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
    } catch (e) {
      debugPrint('Error initializing prayer quality: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    WorshipEngine.instance.invalidate(date: widget.target.date);
    WorshipCacheBus.invalidateAll(dateStr: dateStr);
    nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
        ),
        child: RitmoGlassSheet(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Canonical Symmetrical Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Leading (Right in RTL): Circular Tactile Close (X) Button
                    GestureDetector(
                      onTap: () {
                        RitmoHapticsPolicy.tap();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceElevated.withValues(alpha: 0.85)
                              : colors.textPrimary.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? colors.border.withValues(alpha: 0.35)
                                : colors.border.withValues(alpha: 0.15),
                            width: 0.85,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 15,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),

                    // Center: Title & Subtitle
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.target.titleFa,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _startTime != null ? 'اذان: ${_formatTime(_startTime)}' : 'ثبت مستقیم با لمس گزینه',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Trailing (Left in RTL): Symmetrical Spacer
                    const SizedBox(width: 34, height: 34),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                else ...[
                  if (_isExempt)
                    RitmoCard.neumorphicSunken(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.shield_rounded, color: colors.primary, size: 22),
                          const SizedBox(width: 10),
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
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'در این دوران خواندن نماز تکلیف شرعی ندارد.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isFuture)
                    RitmoCard.neumorphicSunken(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: colors.primary, size: 22),
                          const SizedBox(width: 10),
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
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'زمان اذان: ${_formatTime(_startTime)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.primary.withValues(alpha: 0.8),
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
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 10),
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
      ],
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
    final effectiveColor = isDisabled ? colors.textTertiary : accentColor;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: RitmoCard.neumorphic(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: isDisabled ? null : () => _submitQuality(quality),
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDisabled ? colors.textTertiary : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
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
    );
  }
}
