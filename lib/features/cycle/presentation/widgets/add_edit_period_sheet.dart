// C-43, C-44: AddEditPeriodSheet
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_animated_background.dart';
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
    return '${PersianDigits.toFa(jal.year.toString())}/${PersianDigits.toFa(jal.month.toString().padLeft(2, '0'))}/${PersianDigits.toFa(jal.day.toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoSheetGlassCard(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
            left: 14,
            right: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.period != null
                        ? 'ویرایش تاریخ‌های دوره قاعدگی'
                        : 'افزودن دوره قاعدگی جدید',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.xmark,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_errorText != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_circle_fill,
                        color: colors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorText!,
                          style: TextStyle(color: colors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'تاریخ شروع دوره:',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              InkWell(
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
                    builder: (context, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: colors.primary,
                                onPrimary: Colors.white,
                                surface: colors.surface,
                              ),
                              dialogTheme: DialogThemeData(
                                backgroundColor: colors.surfaceElevated,
                              ),
                            ),
                            child: child!,
                          ),
                        ),
                      );
                    },
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatJalaliDate(_startDate),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
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
              ),
              const SizedBox(height: 16),
              if (!_isOldPeriod) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'این دوره پایان یافته است',
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
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
                const SizedBox(height: 8),
              ],
              if (_hasEndDate || _isOldPeriod) ...[
                Text(
                  'تاریخ پایان دوره:',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                InkWell(
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
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: colors.primary,
                                  onPrimary: Colors.white,
                                  surface: colors.surface,
                                ),
                                dialogTheme: DialogThemeData(
                                  backgroundColor: colors.surfaceElevated,
                                ),
                              ),
                              child: child!,
                            ),
                          ),
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _endDate = picked.toDateTime();
                        _errorText = null;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _endDate != null
                              ? _formatJalaliDate(_endDate!)
                              : 'انتخاب تاریخ',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
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
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
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
                  child: Text(
                    widget.period != null ? 'ذخیره تغییرات' : 'افزودن دوره',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
