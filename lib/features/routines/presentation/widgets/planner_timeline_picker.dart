// lib/features/routines/presentation/widgets/planner_timeline_picker.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';

class PlannerTimelinePicker extends StatefulWidget {

  const PlannerTimelinePicker({super.key, required this.controller});
  final PlannerController controller;

  @override
  State<PlannerTimelinePicker> createState() => _PlannerTimelinePickerState();
}

class _PlannerTimelinePickerState extends State<PlannerTimelinePicker> {
  late FixedExtentScrollController _hourScrollController;
  late FixedExtentScrollController _minuteScrollController;

  @override
  void initState() {
    super.initState();
    final currentHour = widget.controller.selectedTime.hour;
    final currentMinute = widget.controller.selectedTime.minute;
    _hourScrollController = FixedExtentScrollController(initialItem: currentHour);
    _minuteScrollController = FixedExtentScrollController(initialItem: currentMinute);
  }

  @override
  void didUpdateWidget(covariant PlannerTimelinePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hour = widget.controller.selectedTime.hour;
    final minute = widget.controller.selectedTime.minute;

    if (_hourScrollController.hasClients && _hourScrollController.selectedItem != hour) {
      _hourScrollController.jumpToItem(hour);
    }
    if (_minuteScrollController.hasClients && _minuteScrollController.selectedItem != minute) {
      _minuteScrollController.jumpToItem(minute);
    }
  }

  @override
  void dispose() {
    _hourScrollController.dispose();
    _minuteScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dateOptions = List<DateTime>.generate(7, (i) => DateTime.now().add(Duration(days: i)));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Date selector capsules row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 16),
                ...dateOptions.map((date) {
                  final jd = Jalali.fromDateTime(date);
                  final isToday = date.day == DateTime.now().day;
                  final isTomorrow = date.day == DateTime.now().add(const Duration(days: 1)).day;
                  
                  var line1 = '';
                  String? line2;
                  final line3 = '${toPersianDigits(jd.day.toString())} ${jd.formatter.mN}';

                  if (isToday) {
                    line1 = 'امروز';
                    line2 = ShamsiWeek.nameOf(jd.weekDay);
                  } else if (isTomorrow) {
                    line1 = 'فردا';
                    line2 = ShamsiWeek.nameOf(jd.weekDay);
                  } else {
                    line1 = ShamsiWeek.nameOf(jd.weekDay);
                    line2 = null;
                  }

                  final isSelected = widget.controller.selectedDate.day == date.day;

                  return GestureDetector(
                    onTap: () => widget.controller.setDate(date),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      width: 72,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  const Color(0xff8B5CF6).withValues(alpha: 0.25),
                                  const Color(0xff8B5CF6).withValues(alpha: 0.15),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75)),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xff8B5CF6).withValues(alpha: 0.5)
                              : colors.border.withValues(alpha: 0.1),
                          width: isSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xff8B5CF6).withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          Text(
                            line1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : colors.textPrimary,
                            ),
                          ),
                          if (line2 != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              line2,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : colors.textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          const SizedBox(height: 1),
                          Text(
                            line3,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : colors.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                        ),
                      ),
                    ),
                  );
                }),
                
                // Calendar trigger card
                GestureDetector(
                  onTap: () async {
                    final picked = await RitmoDatePicker.show(
                      context: context,
                      initialDate: widget.controller.selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      widget.controller.setDate(picked);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 46,
                    height: 76,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border.withValues(alpha: 0.1)),
                    ),
                    child: Center(
                      child: Icon(Icons.calendar_today_rounded, color: colors.textPrimary.withValues(alpha: 0.85), size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Sunrise / Time Picker / Sunset Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sunrise Shortcut
              GestureDetector(
                onTap: () {
                  final sunrise = widget.controller.sunriseTime;
                  _hourScrollController.animateToItem(sunrise.hour, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  _minuteScrollController.animateToItem(sunrise.minute, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Icon(Icons.wb_sunny_rounded, color: Colors.amber.shade500, size: 18),
                ),
              ),
              const SizedBox(width: 12),

              // Hour / Minute Wheel Selector
              Container(
                height: 136,
                width: 160,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xff8B5CF6).withValues(alpha: 0.15)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x408B5CF6),
                            Color(0x268B5CF6),
                          ],
                        ),
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: const Color(0xff8B5CF6).withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Hours (00-23) - Always on Left
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: _hourScrollController,
                              itemExtent: 36,
                              perspective: 0.006,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                widget.controller.setTime(TimeOfDay(
                                  hour: index % 24,
                                  minute: widget.controller.selectedTime.minute,
                                ));
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 24,
                                builder: (context, index) {
                                  final isSelected = widget.controller.selectedTime.hour == index;
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: isSelected ? 20 : 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : colors.textSecondary.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          
                          // Colon Separator
                          Text(
                            ':',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          
                          // Minutes (00-59) - Always on Right
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: _minuteScrollController,
                              itemExtent: 36,
                              perspective: 0.006,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                widget.controller.setTime(TimeOfDay(
                                  hour: widget.controller.selectedTime.hour,
                                  minute: index % 60,
                                ));
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 60,
                                builder: (context, index) {
                                  final isSelected = widget.controller.selectedTime.minute == index;
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: isSelected ? 20 : 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : colors.textSecondary.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Sunset Shortcut
              GestureDetector(
                onTap: () {
                  final sunset = widget.controller.sunsetTime;
                  _hourScrollController.animateToItem(sunset.hour, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  _minuteScrollController.animateToItem(sunset.minute, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.wb_twilight_rounded, color: colors.textSecondary.withValues(alpha: 0.5), size: 18),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 14),
          
          // Conflict warning
          _buildConflictWarning(colors),

          // Suggested slots chips
          _buildSuggestions(colors),

          const SizedBox(height: 6),

          // Miniature 24h bar
          Text(
            'تراکم زمانی امروز (۲۴ ساعت)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: CustomPaint(
              painter: TimeOccupancyPainter(
                occupiedRanges: widget.controller.occupiedRanges,
                selectedTime: widget.controller.selectedTime,
                durationMinutes: widget.controller.targetDuration,
                colors: colors,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '۰۰:۰۰',
                style: TextStyle(fontSize: 9, color: colors.textSecondary.withValues(alpha: 0.5)),
              ),
              Text(
                '۱۲:۰۰',
                style: TextStyle(fontSize: 9, color: colors.textSecondary.withValues(alpha: 0.5)),
              ),
              Text(
                '۲۴:۰۰',
                style: TextStyle(fontSize: 9, color: colors.textSecondary.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConflictWarning(RitmoColors colors) {
    final selectedStart = widget.controller.selectedTime.hour * 60 + widget.controller.selectedTime.minute;
    final selectedEnd = selectedStart + widget.controller.targetDuration;
    
    OccupiedRange? conflict;
    for (final occ in widget.controller.occupiedRanges) {
      if (occ.title != 'خواب' && selectedStart < occ.end && occ.start < selectedEnd) {
        conflict = occ;
        break;
      }
    }
    
    if (conflict == null) return const SizedBox.shrink();

    final nextFreeSlot = widget.controller.suggestedTimeSlots.isNotEmpty
        ? widget.controller.suggestedTimeSlots.first
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.25), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ تداخل زمانی با «${conflict.title}» (${toPersianDigits(conflict.timeStr)})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (nextFreeSlot != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final parts = nextFreeSlot.split(':');
                  final hour = int.parse(parts[0]);
                  final minute = int.parse(parts[1]);
                  widget.controller.setTime(TimeOfDay(hour: hour, minute: minute));
                  if (_hourScrollController.hasClients) {
                    _hourScrollController.animateToItem(
                      hour,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                  if (_minuteScrollController.hasClients) {
                    _minuteScrollController.animateToItem(
                      minute,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'انتقال هوشمند به زمان آزاد (${toPersianDigits(nextFreeSlot)})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(RitmoColors colors) {
    if (widget.controller.suggestedTimeSlots.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'زمان‌های پیشنهادی آزاد:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.controller.suggestedTimeSlots.map((timeStr) {
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    avatar: Icon(Icons.check_circle_outline_rounded, size: 13, color: colors.primary),
                    label: Text(
                      '${toPersianDigits(timeStr)} — وقت آزاد',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colors.textPrimary,
                      ),
                    ),
                    backgroundColor: colors.primary.withValues(alpha: 0.08),
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.15)),
                    onPressed: () {
                      final parts = timeStr.split(':');
                      final hour = int.parse(parts[0]);
                      final minute = int.parse(parts[1]);
                      widget.controller.setTime(TimeOfDay(hour: hour, minute: minute));
                      
                      _hourScrollController.animateToItem(hour, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                      _minuteScrollController.animateToItem(minute, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class TimeOccupancyPainter extends CustomPainter {

  TimeOccupancyPainter({
    required this.occupiedRanges,
    required this.selectedTime,
    required this.durationMinutes,
    required this.colors,
    required this.isDark,
  });
  final List<OccupiedRange> occupiedRanges;
  final TimeOfDay selectedTime;
  final int durationMinutes;
  final RitmoColors colors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Draw background
    paint.color = isDark ? const Color(0xFF1E2235).withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.03);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );
    canvas.drawRRect(bgRect, paint);

    // Draw occupied ranges (RTL-correct: 00:00 is on the right, so x starts from right)
    for (final occ in occupiedRanges) {
      if (occ.title == 'خواب') {
        paint.color = colors.primary.withValues(alpha: 0.15);
      } else {
        paint.color = colors.textSecondary.withValues(alpha: 0.25);
      }
      
      final rightX = size.width - (occ.start / 1440.0) * size.width;
      final leftX = size.width - (occ.end / 1440.0) * size.width;
      
      canvas.drawRect(
        Rect.fromLTRB(leftX.clamp(0.0, size.width), 0, rightX.clamp(0.0, size.width), size.height),
        paint,
      );
    }

    // Draw current selection window
    final selectedStart = selectedTime.hour * 60 + selectedTime.minute;
    final selectedEnd = selectedStart + durationMinutes;
    
    final currentRightX = size.width - (selectedStart / 1440.0) * size.width;
    final currentLeftX = size.width - (selectedEnd / 1440.0) * size.width;
    
    var isConflict = false;
    for (final occ in occupiedRanges) {
      if (occ.title != 'خواب' && selectedStart < occ.end && occ.start < selectedEnd) {
        isConflict = true;
        break;
      }
    }
    
    paint.color = isConflict 
        ? Colors.red.withValues(alpha: 0.6) 
        : colors.primary.withValues(alpha: 0.6);
        
    canvas.drawRect(
      Rect.fromLTRB(currentLeftX.clamp(0.0, size.width), 0, currentRightX.clamp(0.0, size.width), size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant TimeOccupancyPainter oldDelegate) {
    return oldDelegate.occupiedRanges != occupiedRanges ||
        oldDelegate.selectedTime != selectedTime ||
        oldDelegate.durationMinutes != durationMinutes;
  }
}
