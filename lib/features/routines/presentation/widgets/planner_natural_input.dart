// lib/features/routines/presentation/widgets/planner_natural_input.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';
import 'package:shamsi_date/shamsi_date.dart';

class PlannerNaturalInput extends StatefulWidget {

  const PlannerNaturalInput({super.key, required this.controller});
  final PlannerController controller;

  @override
  State<PlannerNaturalInput> createState() => _PlannerNaturalInputState();
}

class _PlannerNaturalInputState extends State<PlannerNaturalInput> {
  Timer? _debounce;
  Timer? _placeholderTimer;
  int _placeholderIndex = 0;

  static const _placeholders = [
    'مثلاً: هر روز ساعت ۸ صبح مطالعه ۲۰ دقیقه',
    'مثلاً: فردا ساعت ۱۸ باشگاه چهل و پنج دقیقه',
    'مثلاً: هر روز ساعت ۱۳ خوردن ویتامین c',
    'مثلاً: شنبه تا چهارشنبه ساعت ۲۳ خواب',
    'مثلاً: امروز ساعت ۲۰ پیاده‌روی نیم ساعت',
  ];

  @override
  void initState() {
    super.initState();
    _placeholderTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (mounted && widget.controller.inputController.text.isEmpty) {
        setState(() {
          _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _placeholderTimer?.cancel();
    super.dispose();
  }

  String _getTimeDateChipLabel() {
    final date = widget.controller.selectedDate;
    final time = widget.controller.selectedTime;
    final now = DateTime.now();
    
    var dateStr = '';
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      dateStr = 'امروز';
    } else if (date.day == now.add(const Duration(days: 1)).day && date.month == now.add(const Duration(days: 1)).month && date.year == now.add(const Duration(days: 1)).year) {
      dateStr = 'فردا';
    } else if (date.day == now.add(const Duration(days: 2)).day && date.month == now.add(const Duration(days: 2)).month && date.year == now.add(const Duration(days: 2)).year) {
      dateStr = 'پس‌فردا';
    } else {
      final jd = Jalali.fromDateTime(date);
      dateStr = '${jd.day} ${jd.formatter.mN}';
    }
    
    final hour = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '🕐 $dateStr $hour:$min';
  }

  String _getRecurrenceChipLabel() {
    final type = widget.controller.recurrenceType;
    if (type == 'WORKDAYS') return '🔁 شنبه تا چهارشنبه';
    if (type == 'EVERY_DAY') return '🔁 هر روز';
    if (type == 'CUSTOM_DAYS') return '🔁 روزهای خاص';
    if (type == 'INTERVAL_DAYS') return '🔁 هر چند روز';
    if (type == 'INTERVAL_HOURS') return '🔁 هر چند ساعت';
    return '🔁 تکرار';
  }

  String _getDurationChipLabel() {
    return '⏱ ${widget.controller.targetDuration} دقیقه';
  }

  Widget _buildChip({
    required String label,
    required VoidCallback onDelete,
    required BuildContext context,
  }) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2235).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.goldAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            toPersianDigits(label),
            style: TextStyle(
              fontSize: 11.5,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: colors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2235).withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.controller.inputController,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: _placeholders[_placeholderIndex],
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onFieldSubmitted: (text) {
                      _debounce?.cancel();
                      widget.controller.onInputTextChanged(text, immediate: true);
                    },
                    onChanged: (text) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 350), () {
                        widget.controller.onInputTextChanged(text);
                      });
                    },
                  ),
                ),
                if (widget.controller.isAiParsing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xff8B5CF6)),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      _debounce?.cancel();
                      HapticFeedback.selectionClick();
                      widget.controller.onInputTextChanged(widget.controller.inputController.text, immediate: true);
                    },
                    child: Icon(Icons.check_circle_outline_rounded, color: colors.primary, size: 22),
                  ),
              ],
            ),
          ),
          
          // Live NLP Preview Card (P2) & Quick-Save Action (P1)
          if (widget.controller.title.trim().isNotEmpty &&
              (widget.controller.isTimeParsed ||
                  widget.controller.isRecurrenceParsed ||
                  widget.controller.isDurationParsed)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF16192E).withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome_rounded,
                            size: 16, color: colors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.controller.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.goldAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'پیش‌نمایش زنده ✨',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.goldAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.controller.isTimeParsed)
                        _buildChip(
                          label: _getTimeDateChipLabel(),
                          onDelete: () {
                            HapticFeedback.lightImpact();
                            widget.controller.removeParsedEntity('time');
                          },
                          context: context,
                        ),
                      if (widget.controller.isRecurrenceParsed)
                        _buildChip(
                          label: _getRecurrenceChipLabel(),
                          onDelete: () {
                            HapticFeedback.lightImpact();
                            widget.controller.removeParsedEntity('recurrence');
                          },
                          context: context,
                        ),
                      if (widget.controller.isDurationParsed)
                        _buildChip(
                          label: _getDurationChipLabel(),
                          onDelete: () {
                            HapticFeedback.lightImpact();
                            widget.controller.removeParsedEntity('duration');
                          },
                          context: context,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Slide-to-Save Quick Action
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.controller.save(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.primary.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'ثبت سریع با همین اطلاعات ⚡',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // AI Parse Fallback Button
          if (widget.controller.showAiParseAction && !widget.controller.isAiParsing) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => widget.controller.parseWithAI(context),
                icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xff8B5CF6)),
                label: const Text(
                  '✨ تحلیل با هوش مصنوعی',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xff8B5CF6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  backgroundColor: const Color(0xff8B5CF6).withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
