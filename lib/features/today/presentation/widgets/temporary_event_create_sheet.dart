import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/services/snapshot_sync_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

class TemporaryEventCreateSheet extends StatefulWidget {
  const TemporaryEventCreateSheet({
    super.key,
    required this.onSaved,
    this.initialDate,
  });

  final VoidCallback onSaved;
  final DateTime? initialDate;

  static Future<T?> show<T>({
    required BuildContext context,
    required VoidCallback onSaved,
    DateTime? initialDate,
  }) {
    RitmoHaptics.selection();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TemporaryEventCreateSheet(
        onSaved: onSaved,
        initialDate: initialDate,
      ),
    );
  }

  @override
  State<TemporaryEventCreateSheet> createState() => _TemporaryEventCreateSheetState();
}

class _TemporaryEventCreateSheetState extends State<TemporaryEventCreateSheet> {
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();

  late DateTime _selectedDate;
  TimeOfDay _startTime = TimeOfDay.now();
  int _durationMinutes = 60;
  bool _isAllDay = false;
  bool _isLocked = true;
  int _reminderOffsetMinutes = 15; // default 15 min before
  bool _isSaving = false;
  bool _hasTitleError = false;

  final List<int> _durations = [15, 30, 45, 60, 90, 120, 180];

  final List<Map<String, dynamic>> _quickPresets = [
    {'title': 'جلسه کاری', 'icon': Icons.business_center_rounded, 'color': const Color(0xff3B82F6)},
    {'title': 'پزشک و سلامت', 'icon': Icons.medical_services_rounded, 'color': const Color(0xffEF4444)},
    {'title': 'کلاس و وبینار', 'icon': Icons.school_rounded, 'color': const Color(0xff8B5CF6)},
    {'title': 'قرار ملاقات', 'icon': Icons.coffee_rounded, 'color': const Color(0xffF59E0B)},
    {'title': 'مهمانی و جشن', 'icon': Icons.celebration_rounded, 'color': const Color(0xffEC4899)},
    {'title': 'شخصی و ضروری', 'icon': Icons.bookmark_rounded, 'color': const Color(0xff10B981)},
  ];

  final List<Map<String, dynamic>> _reminderOptions = [
    {'label': 'بدون یادآوری', 'value': -1},
    {'label': 'همزمان با شروع', 'value': 0},
    {'label': '۱۵ دقیقه قبل', 'value': 15},
    {'label': '۳۰ دقیقه قبل', 'value': 30},
    {'label': '۱ ساعت قبل', 'value': 60},
    {'label': '۱ روز قبل', 'value': 1440},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applyPreset(String presetTitle) {
    RitmoHaptics.selection();
    setState(() {
      _titleController.text = presetTitle;
      _hasTitleError = false;
    });
  }

  void _setDatePreset(int dayOffset) {
    RitmoHaptics.selection();
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
    });
  }

  bool _isDateSelected(int dayOffset) {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
    return _selectedDate.year == target.year &&
        _selectedDate.month == target.month &&
        _selectedDate.day == target.day;
  }

  Future<void> _selectCustomDate(BuildContext context) async {
    RitmoHaptics.selection();
    final now = DateTime.now();
    final picked = await RitmoDatePicker.show(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    RitmoHaptics.selection();
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xff5B8AF5),
                    onPrimary: Colors.white,
                    surface: Color(0xff1C1F2E),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: colors.primary,
                    surface: colors.sheetBackground,
                    onSurface: colors.cardTitle,
                  ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  void _showDurationManualDialog(BuildContext context, RitmoColors colors) {
    RitmoHaptics.selection();
    final textController = TextEditingController(text: _durationMinutes.toString());
    showDialog(
      context: context,
      builder: (context) {
        return RitmoCustomDialog(
          title: 'مدت زمان سفارشی',
          icon: CupertinoIcons.time,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'مدت زمان رویداد را به دقیقه وارد کنید:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.primary),
                decoration: InputDecoration(
                  suffixText: 'دقیقه',
                  suffixStyle: TextStyle(fontSize: 12, color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.inputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          actions: [
            RitmoSecondaryButton(
              label: 'لغو',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            RitmoPrimaryButton(
              label: 'تأیید',
              onPressed: () {
                final val = int.tryParse(textController.text);
                if (val != null && val > 0) {
                  setState(() {
                    _durationMinutes = val;
                  });
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showReminderPicker(BuildContext context, RitmoColors colors) {
    RitmoHaptics.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_active_rounded, size: 20, color: colors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'تنظیم زمان یادآوری رویداد',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._reminderOptions.map((opt) {
                  final isSelected = _reminderOffsetMinutes == opt['value'];
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: isSelected ? colors.primary.withValues(alpha: 0.08) : null,
                    title: Text(
                      opt['label']! as String,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? colors.primary : colors.textPrimary,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: colors.primary) : null,
                    onTap: () {
                      RitmoHaptics.selection();
                      setState(() {
                        _reminderOffsetMinutes = opt['value']! as int;
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getReminderLabel() {
    final match = _reminderOptions.firstWhere(
      (opt) => opt['value'] == _reminderOffsetMinutes,
      orElse: () => {'label': '$_reminderOffsetMinutes دقیقه قبل'},
    );
    return match['label'] as String;
  }

  String _formatCalculatedEndTime() {
    final startTotalMin = _startTime.hour * 60 + _startTime.minute;
    final endTotalMin = startTotalMin + _durationMinutes;
    final endHour = (endTotalMin ~/ 60) % 24;
    final endMin = endTotalMin % 60;
    final hourStr = endHour.toString().padLeft(2, '0');
    final minStr = endMin.toString().padLeft(2, '0');
    return '$hourStr:$minStr'.toPersianDigits();
  }

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      RitmoHaptics.error();
      setState(() {
        _hasTitleError = true;
      });
      _focusNode.requestFocus();
      return;
    }

    setState(() {
      _isSaving = true;
      _hasTitleError = false;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final yearStr = _selectedDate.year.toString().padLeft(4, '0');
      final monthStr = _selectedDate.month.toString().padLeft(2, '0');
      final dayStr = _selectedDate.day.toString().padLeft(2, '0');
      final dateStr = '$yearStr-$monthStr-$dayStr';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final eventId = 'temp_$nowMs';

      String? startTimeStr;
      String? endTimeStr;
      int effectiveDuration = _durationMinutes;

      if (_isAllDay) {
        startTimeStr = null;
        endTimeStr = null;
        effectiveDuration = 1440;
      } else {
        final startHourStr = _startTime.hour.toString().padLeft(2, '0');
        final startMinStr = _startTime.minute.toString().padLeft(2, '0');
        startTimeStr = '$startHourStr:$startMinStr';

        // Safe end time calculation
        final startTotalMin = _startTime.hour * 60 + _startTime.minute;
        final endTotalMin = startTotalMin + _durationMinutes;
        final endHour = (endTotalMin ~/ 60) % 24;
        final endMin = endTotalMin % 60;
        endTimeStr = '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
      }

      await db.insert('temporary_events', {
        'id': eventId,
        'title': title,
        'date': dateStr,
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'durationMinutes': effectiveDuration,
        'isLocked': _isLocked ? 1 : 0,
        'createdAt': nowMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Notification & Reminder Scheduling
      if (!_isAllDay && _reminderOffsetMinutes >= 0) {
        final eventStartDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _startTime.hour,
          _startTime.minute,
        );
        final reminderTimeMs = eventStartDateTime.millisecondsSinceEpoch - (_reminderOffsetMinutes * 60 * 1000);

        if (reminderTimeMs > nowMs) {
          final reminderId = 'event_alarm_$nowMs';
          await db.insert('pending_reminders', {
            'id': reminderId,
            'routineId': null,
            'scheduleId': null,
            'originalTime': reminderTimeMs,
            'scheduledTime': reminderTimeMs,
            'title': 'رویداد: $title',
            'body': 'شروع در ساعت ${startTimeStr?.toPersianDigits() ?? ''}',
            'channel': 'routine',
            'privacy': 'none',
            'state': 'SCHEDULED',
            'deferCount': 0,
            'createdAt': nowMs,
            'updatedAt': nowMs,
            'ownerModule': 'temporary_events',
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          try {
            await NotificationGateway.schedule(
              NotificationRequest(
                id: reminderId,
                channel: NotificationChannelId.planning,
                scheduledAt: DateTime.fromMillisecondsSinceEpoch(reminderTimeMs),
                title: 'رویداد: $title',
                body: 'ساعت شروع: ${startTimeStr?.toPersianDigits() ?? ''}',
                sourceSystem: 'events',
                entityId: eventId,
              ),
            );
            await SnapshotSyncService.syncAll();
          } catch (notifErr) {
            debugPrint('Notification schedule error: $notifErr');
          }
        }
      }

      DayAgendaService.instance.invalidateAll();
      RitmoEvents.notifyRoutineChanged();
      RitmoEventBus().fire(RitmoEvent(
        type: 'EventCreated',
        timestamp: DateTime.now(),
        payload: {
          'id': eventId,
          'date': dateStr,
        },
      ));

      RitmoHaptics.success();
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving event: $e');
      RitmoHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ذخیره رویداد: $e', style: const TextStyle(fontFamily: 'Vazirmatn')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _formatJalaliDate(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    return '${ShamsiWeek.nameOf(j.weekDay)}، ${j.day} ${j.formatter.mN} ${j.year}'.toPersianDigits();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff141724) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).viewInsets.bottom + 18),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // iOS-style Drag Handle Pill
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.event_available_rounded, size: 22, color: colors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ثبت رویداد جدید',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.cardTitle,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تنظیم زمان رویداد و همگام‌سازی با مسیر روز',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 11.5,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(CupertinoIcons.xmark_circle_fill, color: colors.iconSecondary.withValues(alpha: 0.7), size: 24),
                        onPressed: () {
                          RitmoHaptics.selection();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Quick Presets Wrap
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _quickPresets.map((preset) {
                        final title = preset['title'] as String;
                        final icon = preset['icon'] as IconData;
                        final pColor = preset['color'] as Color;
                        final isSelected = _titleController.text.trim() == title;

                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () => _applyPreset(title),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? pColor.withValues(alpha: 0.18)
                                    : (isDark ? const Color(0xff1C2033) : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? pColor : colors.glassBorder.withValues(alpha: 0.3),
                                  width: isSelected ? 1.4 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 14, color: isSelected ? pColor : colors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? pColor : colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title Input Field
                  TextField(
                    controller: _titleController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.done,
                    onChanged: (v) {
                      if (_hasTitleError && v.trim().isNotEmpty) {
                        setState(() {
                          _hasTitleError = false;
                        });
                      }
                    },
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: colors.cardTitle,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'عنوان رویداد (مثلاً: جلسه هیئت مدیره، ویزیت دکتر)',
                      hintStyle: TextStyle(
                        fontFamily: 'Vazirmatn',
                        color: colors.textSecondary.withValues(alpha: 0.5),
                        fontSize: 12.5,
                      ),
                      prefixIcon: Icon(Icons.edit_note_rounded, size: 22, color: _hasTitleError ? Colors.redAccent : colors.primary),
                      suffixIcon: _titleController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _titleController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      fillColor: isDark ? const Color(0xff1C2033) : colors.inputBackground,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      errorText: _hasTitleError ? 'وارد کردن عنوان رویداد الزامی است' : null,
                      errorStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Colors.redAccent),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _hasTitleError ? Colors.redAccent : colors.glassBorder,
                          width: _hasTitleError ? 1.5 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _hasTitleError ? Colors.redAccent : colors.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date Selection Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1C2033).withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.025),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.glassBorder.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(CupertinoIcons.calendar, size: 16, color: colors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'تاریخ رویداد:',
                                  style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.cardTitle,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatJalaliDate(_selectedDate),
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildDateQuickChip(label: 'امروز', isSelected: _isDateSelected(0), onTap: () => _setDatePreset(0)),
                            const SizedBox(width: 8),
                            _buildDateQuickChip(label: 'فردا', isSelected: _isDateSelected(1), onTap: () => _setDatePreset(1)),
                            const SizedBox(width: 8),
                            _buildDateQuickChip(label: 'پس‌فردا', isSelected: _isDateSelected(2), onTap: () => _setDatePreset(2)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectCustomDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: colors.cardFill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: colors.glassBorder),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.date_range_rounded, size: 14, color: colors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'تقویم',
                                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: colors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // All-Day Switch & Time Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1C2033).withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.025),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.glassBorder.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.wb_sunny_outlined, size: 17, color: colors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'رویداد تمام‌روز (بدون ساعت مشخص)',
                                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.cardTitle),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: _isAllDay,
                              activeThumbColor: colors.primary,
                              activeTrackColor: colors.primary.withValues(alpha: 0.35),
                              onChanged: (val) {
                                RitmoHaptics.selection();
                                setState(() {
                                  _isAllDay = val;
                                });
                              },
                            ),
                          ],
                        ),
                        if (!_isAllDay) ...[
                          const Divider(height: 16, thickness: 0.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(CupertinoIcons.clock, size: 16, color: colors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ساعت شروع:',
                                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.cardTitle),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => _selectTime(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _startTime.format(context).toPersianDigits(),
                                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.bold, color: colors.primary),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.access_time_rounded, size: 15, color: colors.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Duration Selector (when not all-day)
                  if (!_isAllDay) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff1C2033).withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.025),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.glassBorder.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.timelapse_rounded, size: 16, color: colors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'مدت زمان رویداد:',
                                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.cardTitle),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: () {
                                      if (_durationMinutes > 15) {
                                        RitmoHaptics.selection();
                                        setState(() {
                                          _durationMinutes -= 15;
                                        });
                                      }
                                    },
                                    color: colors.primary,
                                  ),
                                  GestureDetector(
                                    onTap: () => _showDurationManualDialog(context, colors),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$_durationMinutes دقیقه'.toPersianDigits(),
                                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primary),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: () {
                                      RitmoHaptics.selection();
                                      setState(() {
                                        _durationMinutes += 15;
                                      });
                                    },
                                    color: colors.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _durations.map((dur) {
                              final isSelected = _durationMinutes == dur;
                              return GestureDetector(
                                onTap: () {
                                  RitmoHaptics.selection();
                                  setState(() {
                                    _durationMinutes = dur;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? colors.primary.withValues(alpha: 0.15) : colors.cardFill,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? colors.primary.withValues(alpha: 0.5) : colors.glassBorder,
                                    ),
                                  ),
                                  child: Text(
                                    '$dur د'.toPersianDigits(),
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? colors.primary : colors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '⏰ پایان در ساعت: ${_formatCalculatedEndTime()}',
                                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Reminder & Lock Options Row
                  Row(
                    children: [
                      // Reminder Pill Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showReminderPicker(context, colors),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xff1C2033).withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.025),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.glassBorder.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.notifications_active_rounded, size: 16, color: colors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'هشدار یادآوری',
                                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getReminderLabel(),
                                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.cardTitle),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: colors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Smart Lock Pill Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            RitmoHaptics.selection();
                            setState(() {
                              _isLocked = !_isLocked;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isLocked
                                  ? colors.primary.withValues(alpha: isDark ? 0.14 : 0.08)
                                  : (isDark ? const Color(0xff1C2033).withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.025)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isLocked ? colors.primary.withValues(alpha: 0.4) : colors.glassBorder.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                                  size: 16,
                                  color: _isLocked ? colors.primary : colors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'برنامه‌ریزی هوشمند',
                                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isLocked ? 'زمان قفل‌شده' : 'زمان منعطف',
                                        style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _isLocked ? colors.primary : colors.cardTitle,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 4,
                      shadowColor: colors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isSaving ? null : _saveEvent,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'ثبت و ذخیره رویداد',
                                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateQuickChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withValues(alpha: 0.15) : colors.cardFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.primary : colors.glassBorder,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

