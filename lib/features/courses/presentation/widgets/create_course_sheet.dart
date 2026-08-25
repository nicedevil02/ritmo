import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/courses/logic/course_validation.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/courses/presentation/widgets/course_formatters.dart';

class CreateCourseSheet extends StatefulWidget {
  const CreateCourseSheet({
    super.key,
    this.editingCourse,
    this.initialValues,
    required this.onCourseCreated,
  });

  final Course? editingCourse;
  final Map<String, dynamic>? initialValues;
  final VoidCallback onCourseCreated;

  @override
  State<CreateCourseSheet> createState() => _CreateCourseSheetState();
}

class _CreateCourseSheetState extends State<CreateCourseSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _totalSessionsController;
  late TextEditingController _durationController;
  late TextEditingController _unitLabelController;
  late TextEditingController _providerController;

  CourseType _selectedType = CourseType.video;
  int _weeklyTarget = 3;
  CourseEnergyRule _energyRule = CourseEnergyRule.all;
  bool _reviewEnabled = false;

  // Saturday=6, Sunday=0, Monday=1, Tuesday=2, Wednesday=3, Thursday=4, Friday=5
  final List<int> _preferredDays = [];

  bool _reminderEnabled = false;
  TimeOfDay _preferredTime = const TimeOfDay(hour: 16, minute: 30);

  String? _linkedGoalId;
  List<Map<String, dynamic>> _activeGoals = [];
  bool _isAdvancedExpanded = false;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _dayOptions = [
    {'name': 'شنبه', 'value': 6},
    {'name': 'یکشنبه', 'value': 0},
    {'name': 'دوشنبه', 'value': 1},
    {'name': 'سه‌شنبه', 'value': 2},
    {'name': 'چهارشنبه', 'value': 3},
    {'name': 'پنجشنبه', 'value': 4},
    {'name': 'جمعه', 'value': 5},
  ];

  @override
  void initState() {
    super.initState();

    final c = widget.editingCourse;
    final iv = widget.initialValues;

    _titleController = TextEditingController(text: c?.title ?? (iv?['title'] as String?) ?? '');
    _totalSessionsController = TextEditingController(text: c?.totalSessions.toString() ?? iv?['totalSessions']?.toString() ?? '10');
    _durationController = TextEditingController(text: c?.sessionDurationMinutes.toString() ?? iv?['sessionDurationMinutes']?.toString() ?? '45');
    _unitLabelController = TextEditingController(text: c?.unitLabel ?? (iv?['unitLabel'] as String?) ?? '');
    _providerController = TextEditingController(text: c?.provider ?? (iv?['provider'] as String?) ?? '');

    if (c != null) {
      _selectedType = c.courseType;
      _weeklyTarget = c.weeklyTargetSessions;
      _energyRule = c.energyRule;
      _reviewEnabled = c.reviewEnabled;
      _preferredDays.addAll(c.preferredDays);
      _reminderEnabled = c.reminderEnabled;
      if (c.preferredTime != null && c.preferredTime!.contains(':')) {
        final parts = c.preferredTime!.split(':');
        final h = int.tryParse(parts[0]) ?? 16;
        final m = int.tryParse(parts[1]) ?? 30;
        _preferredTime = TimeOfDay(hour: h, minute: m);
      }
      _linkedGoalId = c.linkedGoalId;
    } else {
      if (iv?['courseType'] != null) {
        _selectedType = CourseTypeExtension.fromString(iv?['courseType'] as String);
      }
      if (iv?['weeklyTargetSessions'] != null) {
        _weeklyTarget = iv?['weeklyTargetSessions'] as int;
      }
      if (iv?['energyRule'] != null) {
        _energyRule = CourseEnergyRuleExtension.fromString(iv?['energyRule'] as String?);
      }
      if (iv?['reviewEnabled'] != null) {
        _reviewEnabled = iv?['reviewEnabled'] as bool;
      }
      if (iv?['preferredDays'] != null) {
        final days = iv?['preferredDays'] as List<dynamic>;
        _preferredDays.addAll(days.cast<int>());
      } else {
        _preferredDays.addAll([6, 1, 3]); // Saturday, Monday, Wednesday default
      }
      if (iv?['reminderEnabled'] != null) {
        _reminderEnabled = iv?['reminderEnabled'] as bool;
      }
      if (iv?['linkedGoalId'] != null) {
        _linkedGoalId = iv?['linkedGoalId'] as String;
      }
    }

    _unitLabelController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadActiveGoals();
  }

  Future<void> _loadActiveGoals() async {
    try {
      final goals = await CoursesRepository.instance.getActiveGoalsList();
      final goalList = List<Map<String, dynamic>>.from(goals);
      if (_linkedGoalId != null && _linkedGoalId!.isNotEmpty) {
        final alreadyPresent = goalList.any((g) => g['id'] == _linkedGoalId);
        if (!alreadyPresent) {
          final info = await CoursesRepository.instance.getLinkedGoalInfo(_linkedGoalId!);
          if (info != null) {
            final title = (info['title'] as String?) ?? 'هدف متصل';
            goalList.add({
              'id': _linkedGoalId,
              'title': '$title (آرشیوشده یا خصوصی)',
              'isDisabled': true,
            });
          } else {
            _linkedGoalId = null;
          }
        }
      }
      if (mounted) {
        setState(() {
          _activeGoals = goalList;
        });
      }
    } catch (e, st) {
      RitmoLog.error('COURSES', 'Error loading active goals in CreateCourseSheet', e, st);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalSessionsController.dispose();
    _durationController.dispose();
    _unitLabelController.dispose();
    _providerController.dispose();
    super.dispose();
  }

  String get _currentUnitLabel {
    if (_selectedType == CourseType.custom) {
      final text = _unitLabelController.text.trim();
      return text.isNotEmpty ? text : 'واحد';
    }
    return _selectedType.defaultUnitLabel;
  }

  void _toggleDay(int val) {
    setState(() {
      if (_preferredDays.contains(val)) {
        _preferredDays.remove(val);
      } else {
        _preferredDays.add(val);
      }
    });
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              helpTextStyle: TextStyle(),
              hourMinuteTextStyle: TextStyle(fontSize: 24),
              dayPeriodTextStyle: TextStyle(),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _preferredTime = picked;
      });
    }
  }

  Future<void> _saveCourse() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final rawTotalStr = RitmoNumber.toEn(_totalSessionsController.text.trim());
    final totalSessions = int.tryParse(rawTotalStr) ?? 1;
    if (totalSessions < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعداد کل جلسات باید حداقل ۱ جلسه باشد.')),
      );
      return;
    }
    final rawDurationStr = RitmoNumber.toEn(_durationController.text.trim());
    final duration = (int.tryParse(rawDurationStr) ?? 45).clamp(5, 480);
    final unitLabel = _unitLabelController.text.trim().isEmpty ? null : _unitLabelController.text.trim();
    final provider = _providerController.text.trim().isEmpty ? null : _providerController.text.trim();

    final isEditing = widget.editingCourse != null;
    final now = DateTime.now();

    final timeStr = _reminderEnabled
        ? '${_preferredTime.hour.toString().padLeft(2, '0')}:${_preferredTime.minute.toString().padLeft(2, '0')}'
        : null;

    final Course courseToSave;
    if (isEditing) {
      final old = widget.editingCourse!;
      // Only rhythm-affecting fields trigger a reschedule of pending sessions —
      // this must mirror CoursesRepository.updateCourse's needsReschedule check.
      // Reminder toggle / reminder time changes are applied without touching
      // planned dates, so they must NOT prompt this confirmation either.
      final needsReschedule = old.weeklyTargetSessions != _weeklyTarget ||
          !listEquals(old.preferredDays, _preferredDays) ||
          old.totalSessions != totalSessions;

      if (needsReschedule) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xff1C1F2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'تغییر ریتم برنامه‌ریزی',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            content: const Text(
              'تغییر هدف هفتگی، روزها یا تعداد جلسات باعث زمان‌بندی مجدد جلسات آینده می‌شود. آیا ادامه می‌دهید؟',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff5B8AF5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأیید و ذخیره', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }

      courseToSave = old.copyWith(
        title: title,
        totalSessions: totalSessions,
        sessionDurationMinutes: duration,
        courseType: _selectedType,
        unitLabel: unitLabel,
        provider: provider,
        weeklyTargetSessions: _weeklyTarget,
        energyRule: _energyRule,
        preferredDays: _preferredDays.isEmpty ? [6, 1, 3] : _preferredDays,
        reminderEnabled: _reminderEnabled,
        preferredTime: timeStr,
        linkedGoalId: _linkedGoalId,
        reviewEnabled: _reviewEnabled,
        updatedAt: now.millisecondsSinceEpoch,
      );
    } else {
      courseToSave = Course(
        id: 'course_${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch % 10000}',
        title: title,
        totalSessions: totalSessions,
        sessionDurationMinutes: duration,
        courseType: _selectedType,
        unitLabel: unitLabel,
        provider: provider,
        weeklyTargetSessions: _weeklyTarget,
        energyRule: _energyRule,
        preferredDays: _preferredDays.isEmpty ? [6, 1, 3] : _preferredDays,
        reminderEnabled: _reminderEnabled,
        preferredTime: timeStr,
        linkedGoalId: _linkedGoalId,
        reviewEnabled: _reviewEnabled,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await CoursesRepository.instance.saveCourse(courseToSave, isNew: !isEditing);
      widget.onCourseCreated();
      if (mounted) {
        RitmoToast.show(
          context,
          isEditing ? 'تغییرات دوره "$title" ذخیره شد.' : 'دوره "$title" با موفقیت ثبت شد.',
          iconColor: const Color(0xff10B981),
        );
        Navigator.pop(context);
      }
    } on CourseValidationException catch (e) {
      if (mounted) {
        RitmoToast.show(
          context,
          e.messageFa,
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.amber,
        );
      }
    } catch (e, st) {
      RitmoLog.error('COURSES', 'Error saving course', e, st);
      if (mounted) {
        RitmoToast.show(
          context,
          'خطایی در ذخیره دوره رخ داد. لطفاً مجدداً تلاش کنید.',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    final isEditing = widget.editingCourse != null;
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(30));

    final content = Container(
      constraints: BoxConstraints(
        maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.9),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'ویرایش دوره آموزشی' : 'ایجاد دوره آموزشی جدید',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.xmark_circle_fill, color: colors.textSecondary.withValues(alpha: 0.5)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 16),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Course Title
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      decoration: RitmoTheme.inputDecoration(
                        context,
                        label: 'عنوان دوره آموزشی *',
                        icon: CupertinoIcons.book,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'لطفاً عنوان دوره را وارد کنید';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Course Type Selector
                    Text(
                      'نوع دوره:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CourseType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return ChoiceChip(
                          label: Text(
                            '${type.defaultEmoji} ${type.label}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : colors.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: colors.primary,
                          backgroundColor: colors.card,
                          side: BorderSide(
                            color: isSelected ? colors.primary : colors.border,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedType = type;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Total units & Duration
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _totalSessionsController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: colors.textPrimary, fontSize: 13),
                            decoration: RitmoTheme.inputDecoration(
                              context,
                              label: 'تعداد کل $_currentUnitLabel‌ها',
                              icon: CupertinoIcons.number,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'لطفاً تعداد کل جلسات را وارد کنید';
                              }
                              final enVal = RitmoNumber.toEn(value.trim());
                              final numVal = int.tryParse(enVal);
                              if (numVal == null || numVal < CourseLimits.minTotalSessions || numVal > CourseLimits.maxTotalSessions) {
                                return 'عددی بین ${CourseLimits.minTotalSessions} تا ${CourseLimits.maxTotalSessions} وارد کنید';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: colors.textPrimary, fontSize: 13),
                            decoration: RitmoTheme.inputDecoration(
                              context,
                              label: 'مدت هر $_currentUnitLabel (دقیقه)',
                              icon: CupertinoIcons.time,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'لطفاً مدت هر جلسه را وارد کنید';
                              }
                              final enVal = RitmoNumber.toEn(value.trim());
                              final numVal = int.tryParse(enVal);
                              if (numVal == null || numVal < CourseLimits.minSessionDurationMinutes || numVal > CourseLimits.maxSessionDurationMinutes) {
                                return 'عددی بین ${CourseLimits.minSessionDurationMinutes} تا ${CourseLimits.maxSessionDurationMinutes} دقیقه وارد کنید';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Weekly Target
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تعداد جلسات در هفته:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(CupertinoIcons.minus_circle, size: 20),
                              onPressed: _weeklyTarget > 1
                                  ? () => setState(() => _weeklyTarget--)
                                  : null,
                            ),
                            Text(
                              toPersianDigits('$_weeklyTarget جلسه'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(CupertinoIcons.plus_circle, size: 20),
                              onPressed: _weeklyTarget < CourseLimits.maxWeeklyTarget
                                  ? () => setState(() => _weeklyTarget++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Preferred Days Selector
                    Text(
                      'روزهای ترجیحی مطالعه:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _dayOptions.map((opt) {
                        final val = opt['value'] as int;
                        final name = opt['name'] as String;
                        final isSelected = _preferredDays.contains(val);
                        return _WeekdayChip(
                          label: name,
                          isSelected: isSelected,
                          onTap: () => _toggleDay(val),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Advanced Settings Expansion
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(
                          'تنظیمات پیشرفته (اختیاری)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        leading: Icon(CupertinoIcons.gear_alt, color: colors.primary, size: 20),
                        initiallyExpanded: _isAdvancedExpanded,
                        onExpansionChanged: (exp) => setState(() => _isAdvancedExpanded = exp),
                        children: [
                          if (_selectedType == CourseType.custom) ...[
                            TextFormField(
                              controller: _unitLabelController,
                              style: TextStyle(color: colors.textPrimary, fontSize: 13),
                              decoration: RitmoTheme.inputDecoration(
                                context,
                                label: 'نام واحد سفارشی (مثلاً: پودمان، مبحث)',
                                icon: CupertinoIcons.tag,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Provider
                          TextFormField(
                            controller: _providerController,
                            style: TextStyle(color: colors.textPrimary, fontSize: 13),
                            decoration: RitmoTheme.inputDecoration(
                              context,
                              label: 'پلتفرم / استاد (مثلاً: یوتیوب، استاد رضایی)',
                              icon: CupertinoIcons.person_2,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Energy Match Rule
                          Text(
                            'قانون تطابق انرژی با مود:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<CourseEnergyRule>(
                                value: _energyRule,
                                isExpanded: true,
                                dropdownColor: isDarkMode ? const Color(0xff1A1D29) : Colors.white,
                                items: CourseEnergyRule.values.map((rule) {
                                  return DropdownMenuItem<CourseEnergyRule>(
                                    value: rule,
                                    child: Text(
                                      rule.labelFa,
                                      style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _energyRule = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Link to Goal
                          Text(
                            'اتصال یک‌طرفه به هدف (اختیاری):',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _linkedGoalId,
                                isExpanded: true,
                                hint: Text(
                                  'انتخاب هدف برای ارسال درصد پیشرفت...',
                                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                                ),
                                dropdownColor: isDarkMode ? const Color(0xff1A1D29) : Colors.white,
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      'بدون اتصال به هدف',
                                      style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                                    ),
                                  ),
                                  ..._activeGoals.map((goal) {
                                    final isDis = goal['isDisabled'] == true;
                                    return DropdownMenuItem<String?>(
                                      value: goal['id'] as String,
                                      enabled: !isDis,
                                      child: Text(
                                        goal['title'] as String,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDis ? colors.textSecondary : colors.textPrimary,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _linkedGoalId = val;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Reminders Switch
                          SwitchListTile(
                            title: Text(
                              'فعال‌سازی یادآور مطالعه',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                            subtitle: Text(
                              'ارسال نوتیفیکیشن در ساعت تعیین‌شده',
                              style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                            ),
                            value: _reminderEnabled,
                            onChanged: (val) {
                              setState(() {
                                _reminderEnabled = val;
                              });
                            },
                            activeThumbColor: colors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),

                          if (_reminderEnabled) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ساعت یادآوری:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textPrimary.withValues(alpha: 0.85),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _selectTime,
                                  icon: const Icon(CupertinoIcons.clock, size: 16),
                                  label: Text(
                                    toPersianDigits('${_preferredTime.hour.toString().padLeft(2, '0')}:${_preferredTime.minute.toString().padLeft(2, '0')}'),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // SM-2 Spaced Repetition Switch (Fixes H6)
                          SwitchListTile(
                            title: Text(
                              'فعال‌سازی مرور فاصله‌دار (SM-2)',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                            subtitle: Text(
                              'برنامه‌ریزی خودکار جلسات مرور بر اساس میزان تسلط و سختی جلسات',
                              style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                            ),
                            value: _reviewEnabled,
                            onChanged: (val) {
                              setState(() {
                                _reviewEnabled = val;
                              });
                            },
                            activeThumbColor: colors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveCourse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? CupertinoActivityIndicator(color: colors.onPrimary)
                    : Text(
                        isEditing ? 'ذخیره تغییرات' : 'ذخیره و ایجاد دوره',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );

    final sheetBody = Material(
      type: MaterialType.transparency,
      child: content,
    );

    if (!isGlass) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDarkMode ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    }

    return ClipRRect(
      borderRadius: sheetRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.glassTint,
            borderRadius: sheetRadius,
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: 1.0,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: sheetRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.20),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: sheetBody,
          ),
        ),
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xff8B5CF6), Color(0xffEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : colors.border.withValues(alpha: 0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xff8B5CF6).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : colors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
