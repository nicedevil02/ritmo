// C-43, C-44: AddEditPeriodSheet
import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:shamsi_date/shamsi_date.dart';

class AddEditPeriodSheet extends StatefulWidget {
  const AddEditPeriodSheet({
    super.key,
    this.period,
    required this.onValidate,
    required this.onSave,
  });

  final Map<String, dynamic>? period;
  final String? Function(DateTime startDate, DateTime? endDate) onValidate;
  final Function(DateTime startDate, DateTime? endDate) onSave;

  @override
  State<AddEditPeriodSheet> createState() => _AddEditPeriodSheetState();
}

class _AddEditPeriodSheetState extends State<AddEditPeriodSheet> {
  late DateTime _startDate;
  DateTime? _endDate;
  bool _hasEndDate = false;
  String? _errorText;

  bool get _isOldPeriod {
    final cleanToday = CycleDateContract.cleanDate(CycleClock.now);
    final cleanStart = CycleDateContract.cleanDate(_startDate);
    return CycleDateContract.daysBetween(cleanStart, cleanToday) > 15;
  }

  @override
  void initState() {
    super.initState();
    if (widget.period != null) {
      _startDate =
          CycleDateContract.parseDayKey(
            widget.period!['startDate']?.toString(),
          ) ??
          CycleClock.now;
      final endStr = widget.period!['endDate'] as String?;
      if (endStr != null) {
        _endDate = CycleDateContract.parseDayKey(endStr);
      }
    } else {
      _startDate = CycleClock.now;
      _endDate = null;
    }

    if (_isOldPeriod) {
      _hasEndDate = true;
      _endDate ??= _startDate.add(const Duration(days: 5));
    } else {
      _hasEndDate = _endDate != null;
    }
  }

  String _formatJalaliDate(DateTime dt) {
    final jal = Jalali.fromDateTime(dt);
    return '${RitmoNumber.faInt(jal.year)}/${RitmoNumber.faInt(jal.month).padLeft(2, '۰')}/${RitmoNumber.faInt(jal.day).padLeft(2, '۰')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
        ),
        child: RitmoGlassSheet(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + RitmoSpacing.lg,
            top: RitmoSpacing.sm,
            left: RitmoSpacing.lg,
            right: RitmoSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Symmetrical Header
                Row(
                  children: [
                    RitmoNeuButton(
                      padding: const EdgeInsets.all(8),
                      radius: 10,
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.period != null
                            ? 'ویرایش تاریخ‌های دوره'
                            : 'افزودن دوره جدید',
                        textAlign: TextAlign.center,
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 34), // Symmetrical balancing
                  ],
                ),
                const SizedBox(height: 16),

                if (_errorText != null) ...[
                  RitmoCard.neumorphicSunken(
                    padding: const EdgeInsets.all(RitmoSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle_fill,
                          color: colors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Text(
                  'تاریخ شروع دوره:',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                RitmoCard.neumorphic(
                  onTap: () async {
                    final picked = await RitmoDatePicker.showJalali(
                      context: context,
                      initialDate: Jalali.fromDateTime(_startDate),
                      firstDate: Jalali.fromDateTime(
                        CycleClock.now.subtract(const Duration(days: 365)),
                      ),
                      lastDate: Jalali.fromDateTime(
                        CycleClock.now.add(const Duration(days: 30)),
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked.toDateTime();
                        if (_isOldPeriod) {
                          _hasEndDate = true;
                          if (_endDate == null || _endDate!.isBefore(_startDate)) {
                            _endDate = _startDate.add(const Duration(days: 5));
                          }
                        } else if (_endDate != null &&
                            _endDate!.isBefore(_startDate)) {
                          _endDate = _startDate.add(const Duration(days: 5));
                        }
                        _errorText = null;
                      });
                    }
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatJalaliDate(_startDate),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        CupertinoIcons.calendar,
                        color: colors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (!_isOldPeriod) ...[
                  RitmoCard.neumorphic(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'این دوره پایان یافته است',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        CupertinoSwitch(
                          value: _hasEndDate,
                          activeTrackColor: colors.primary,
                          onChanged: (v) {
                            setState(() {
                              _hasEndDate = v;
                              if (v && _endDate == null) {
                                _endDate = _startDate.add(const Duration(days: 5));
                              }
                              _errorText = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_hasEndDate || _isOldPeriod) ...[
                  Text(
                    'تاریخ پایان دوره:',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  RitmoCard.neumorphic(
                    onTap: () async {
                      final picked = await RitmoDatePicker.showJalali(
                        context: context,
                        initialDate: Jalali.fromDateTime(
                          (_endDate == null || _endDate!.isBefore(_startDate))
                              ? _startDate
                              : _endDate!,
                        ),
                        firstDate: Jalali.fromDateTime(_startDate),
                        lastDate: Jalali.fromDateTime(
                          CycleClock.now.add(const Duration(days: 30)),
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _endDate = picked.toDateTime();
                          _errorText = null;
                        });
                      }
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _endDate != null
                              ? _formatJalaliDate(_endDate!)
                              : 'انتخاب تاریخ پایان',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          CupertinoIcons.calendar,
                          color: colors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 12),
                RitmoPrimaryButton(
                  label: widget.period != null ? 'ذخیره تغییرات' : 'افزودن دوره',
                  onPressed: () {
                    final effectiveEndDate =
                        (_isOldPeriod || _hasEndDate) ? _endDate : null;
                    if (_isOldPeriod && effectiveEndDate == null) {
                      setState(() {
                        _errorText = 'ثبت تاریخ پایان برای دوره‌های گذشته الزامی است.';
                      });
                      return;
                    }
                    final error = widget.onValidate(
                      _startDate,
                      effectiveEndDate,
                    );
                    if (error != null) {
                      setState(() {
                        _errorText = error;
                      });
                      return;
                    }
                    widget.onSave(_startDate, effectiveEndDate);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
