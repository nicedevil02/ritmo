import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class RealmTemplate {
  const RealmTemplate({
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
  });

  final String name;
  final String icon;
  final String colorHex;
  final RealmMode mode;
  final String startTime;
  final String endTime;
  final Set<int> daysOfWeek;
}

class RealmEditFormSheet extends StatefulWidget {
  const RealmEditFormSheet({
    super.key,
    this.initialRealm,
    this.initialSchedules,
    required this.onSave,
  });

  final RealmData? initialRealm;
  final List<RealmScheduleData>? initialSchedules;
  final Future<void> Function(RealmData realm, List<RealmScheduleData> schedules) onSave;

  static const List<RealmTemplate> readyTemplates = [
    RealmTemplate(
      name: 'کار و تمرکز عمیق',
      icon: '💼',
      colorHex: '#3B82F6',
      mode: RealmMode.focus,
      startTime: '08:30',
      endTime: '16:30',
      daysOfWeek: {6, 7, 1, 2, 3}, // شنبه تا چهارشنبه
    ),
    RealmTemplate(
      name: 'ورزش و تندرستی',
      icon: '🏋️',
      colorHex: '#EF4444',
      mode: RealmMode.focus,
      startTime: '17:00',
      endTime: '18:30',
      daysOfWeek: {6, 1, 3}, // فرد: شنبه، دوشنبه، چهارشنبه
    ),
    RealmTemplate(
      name: 'مطالعه و یادگیری',
      icon: '📚',
      colorHex: '#8B5CF6',
      mode: RealmMode.focus,
      startTime: '20:00',
      endTime: '21:30',
      daysOfWeek: {6, 7, 1, 2, 3, 4},
    ),
    RealmTemplate(
      name: 'استراحت و خانواده',
      icon: '🏡',
      colorHex: '#10B981',
      mode: RealmMode.normal,
      startTime: '19:00',
      endTime: '22:30',
      daysOfWeek: {5}, // جمعه
    ),
    RealmTemplate(
      name: 'خواب شبانه',
      icon: '🌙',
      colorHex: '#6366F1',
      mode: RealmMode.silent,
      startTime: '23:30',
      endTime: '07:00',
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7}, // هر شب
    ),
  ];

  static const List<String> iconPickerOptions = [
    '🎯', '💻', '📚', '🌙', '🏃‍♂️', '⚡', '☕', '🎧', '🎨', '🧘‍♂️', '⚙️', '💡', '🔥', '🌱', '⭐', '❤️'
  ];

  static const List<String> colorPaletteHex = [
    '#6366F1', '#8B5CF6', '#EC4899', '#10B981', '#F59E0B', '#EF4444', '#3B82F6', '#14B8A6'
  ];

  @override
  State<RealmEditFormSheet> createState() => _RealmEditFormSheetState();
}

class _RealmEditFormSheetState extends State<RealmEditFormSheet> {
  late TextEditingController _nameController;
  late FocusNode _nameFocusNode;
  late DraggableScrollableController _sheetController;
  late String _selectedIcon;
  late String _selectedColorHex;
  late RealmMode _selectedMode;

  late Set<int> _selectedDays; // 1: Mon ... 7: Sun
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  // Dirty State & Discard Guard
  late String _initialName;
  late String _initialIcon;
  late String _initialColorHex;
  late RealmMode _initialMode;
  late Set<int> _initialDays;
  late TimeOfDay _initialStartTime;
  late TimeOfDay _initialEndTime;

  double _lastReportedSize = 0.60;
  String? _nameError;
  String? _daysError;
  bool _isSubmitting = false;

  bool get isEditing => widget.initialRealm != null;

  bool get _isDirty {
    if (_nameController.text.trim() != _initialName) return true;
    if (_selectedIcon != _initialIcon) return true;
    if (_selectedColorHex != _initialColorHex) return true;
    if (_selectedMode != _initialMode) return true;
    if (_selectedDays.length != _initialDays.length ||
        !_selectedDays.containsAll(_initialDays)) {
      return true;
    }
    if (_startTime != _initialStartTime || _endTime != _initialEndTime) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final r = widget.initialRealm;
    final sched = (widget.initialSchedules != null && widget.initialSchedules!.isNotEmpty)
        ? widget.initialSchedules!.first
        : null;

    _nameController = TextEditingController(text: r?.name ?? '');
    _nameFocusNode = FocusNode();
    _sheetController = DraggableScrollableController();

    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        _expandSheetToMax();
      }
    });

    // Snap Haptics (Item 1)
    _sheetController.addListener(() {
      if (!_sheetController.isAttached) return;
      final currentSize = _sheetController.size;
      if ((_lastReportedSize < 0.77 && currentSize >= 0.77) ||
          (_lastReportedSize > 0.77 && currentSize <= 0.77)) {
        HapticFeedback.selectionClick();
      }
      _lastReportedSize = currentSize;
    });

    _selectedIcon = r?.icon ?? '🎯';
    _selectedColorHex = r?.colorHex ?? '#6366F1';
    _selectedMode = r?.mode ?? RealmMode.focus;
    _selectedDays = sched != null ? Set.from(sched.daysOfWeek) : {6, 7, 1, 2, 3, 4};

    // Smart Auto-Time (Item 5)
    if (sched != null) {
      _startTime = _parseTimeOfDay(sched.startTime);
      _endTime = _parseTimeOfDay(sched.endTime);
    } else {
      final now = DateTime.now();
      final nextHour = (now.minute >= 30 ? now.hour + 1 : now.hour) % 24;
      final endHour = (nextHour + 2) % 24;
      _startTime = TimeOfDay(hour: nextHour, minute: 0);
      _endTime = TimeOfDay(hour: endHour, minute: 0);
    }

    // Capture initial values for Discard Guard
    _initialName = _nameController.text.trim();
    _initialIcon = _selectedIcon;
    _initialColorHex = _selectedColorHex;
    _initialMode = _selectedMode;
    _initialDays = Set.from(_selectedDays);
    _initialStartTime = _startTime;
    _initialEndTime = _endTime;
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _sheetController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _expandSheetToMax() {
    if (_sheetController.isAttached && _sheetController.size < 0.95) {
      _sheetController.animateTo(
        0.95,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _applyTemplate(RealmTemplate template) {
    setState(() {
      _nameController.text = template.name;
      _selectedIcon = template.icon;
      _selectedColorHex = template.colorHex;
      _selectedMode = template.mode;
      _startTime = _parseTimeOfDay(template.startTime);
      _endTime = _parseTimeOfDay(template.endTime);
      _selectedDays = Set.from(template.daysOfWeek);

      _nameError = null;
      _daysError = null;
    });
  }

  void _validateAndSave() async {
    final name = _nameController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'لطفاً نام قلمرو را وارد کنید' : null;
      _daysError = _selectedDays.isEmpty ? 'لطفاً حداقل یک روز را انتخاب کنید' : null;
    });

    if (_nameError != null || _daysError != null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final realmId = widget.initialRealm?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final realm = RealmData(
        id: realmId,
        name: name,
        colorHex: _selectedColorHex,
        icon: _selectedIcon,
        mode: _selectedMode,
        isDefault: widget.initialRealm?.isDefault ?? false,
        createdAt: widget.initialRealm?.createdAt,
      );

      final scheduleId = (widget.initialSchedules != null && widget.initialSchedules!.isNotEmpty)
          ? widget.initialSchedules!.first.id
          : '${realmId}_sched_1';

      final schedule = RealmScheduleData(
        id: scheduleId,
        zoneId: realmId,
        daysOfWeek: _selectedDays,
        startTime: _formatTimeOfDay(_startTime),
        endTime: _formatTimeOfDay(_endTime),
      );

      await widget.onSave(realm, [schedule]);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _isConfirmationShowing = false;
  bool _isDismissing = false;

  Future<bool> _handleDiscardConfirmation() async {
    if (!_isDirty || _isSubmitting) return true;
    if (_isConfirmationShowing) return false;

    _isConfirmationShowing = true;
    final shouldDiscard = await RitmoGlassActionSheet.showDiscard(
      context: context,
      title: 'تغییرات ذخیره نشده‌اند',
      message: 'آیا از خروج و حذف تغییرات اطمینان دارید؟',
      discardLabel: 'حذف تغییرات',
      continueEditingLabel: 'ادامه ویرایش',
    );
    _isConfirmationShowing = false;

    return shouldDiscard ?? false;
  }

  void _onCancelPressed() async {
    if (_isDismissing) return;
    if (!_isDirty) {
      _isDismissing = true;
      Navigator.of(context).pop();
      return;
    }
    final canDismiss = await _handleDiscardConfirmation();
    if (!mounted) return;
    if (canDismiss) {
      _isDismissing = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));

    Widget buildSheetContainer(ScrollController scrollController) {
      final sheetContent = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Apple Grabber Handle & Pinned Header with Swipe-to-Dismiss Interceptor
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) async {
              if (details.primaryVelocity != null && details.primaryVelocity! > 180 && !_isDismissing) {
                if (!_isDirty) {
                  _isDismissing = true;
                  Navigator.of(this.context).pop();
                  return;
                }
                final canDismiss = await _handleDiscardConfirmation();
                if (!mounted) return;
                if (canDismiss) {
                  _isDismissing = true;
                  Navigator.of(this.context).pop();
                } else if (_sheetController.isAttached) {
                  unawaited(_sheetController.animateTo(
                    0.60,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  ));
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: colors.textPrimary.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Leading (Right in RTL): Cancel action with Discard Guard
                      TextButton(
                        onPressed: _onCancelPressed,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'انصراف',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),

                    // Center: Modal Title + Live Morphing Preview Chip (Item 3)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(int.parse(_selectedColorHex.replaceAll('#', '0xFF'))),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(int.parse(_selectedColorHex.replaceAll('#', '0xFF'))).withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _selectedIcon,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEditing ? 'ویرایش قلمرو' : 'ساخت قلمرو جدید',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    // Trailing (Left in RTL): Save/Create action
                    _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: _validateAndSave,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              isEditing ? 'ذخیره' : 'ایجاد',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? colors.border : colors.divider),

          // 2. Scrollable Form Content (Connected with DraggableScrollableSheet controller)
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo is ScrollUpdateNotification &&
                    scrollInfo.metrics.pixels < -35 &&
                    (scrollInfo.scrollDelta ?? 0) < -4 &&
                    !_isDismissing) {
                  if (!_isDirty) {
                    _isDismissing = true;
                    Navigator.of(this.context).pop();
                  } else if (!_isConfirmationShowing) {
                    _handleDiscardConfirmation().then((canDismiss) {
                      if (!mounted) return;
                      if (canDismiss) {
                        _isDismissing = true;
                        Navigator.of(this.context).pop();
                      }
                    });
                  }
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 14,
                  left: 16,
                  right: 16,
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Templates Bar (Visible on creation)
                  if (!isEditing) ...[
                    Text(
                      'الگوهای آماده:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: RealmEditFormSheet.readyTemplates.map((template) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ActionChip(
                              avatar: Text(template.icon, style: const TextStyle(fontSize: 14)),
                              label: Text(template.name, style: const TextStyle(fontSize: 12)),
                              onPressed: () => _applyTemplate(template),
                              backgroundColor: colors.textPrimary.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Name Field & Icon Picker
                  Text(
                    'نام و آیکون قلمرو:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Selected Icon Container
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.textPrimary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
                        ),
                        child: Text(_selectedIcon, style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          onTap: _expandSheetToMax,
                          style: TextStyle(fontSize: 14, color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'مثلاً: کار عمیق، مطالعات شبانه...',
                            hintStyle: TextStyle(fontSize: 13, color: colors.textTertiary),
                            filled: true,
                            fillColor: colors.textPrimary.withValues(alpha: 0.04),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (_) {
                            if (_nameError != null) setState(() => _nameError = null);
                          },
                        ),
                      ),
                    ],
                  ),

                  // Inline Name Validation Error (ق-۱۹)
                  if (_nameError != null) ...[
                    const SizedBox(height: 4),
                    Text(_nameError!, style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                  ],

                  const SizedBox(height: 16),

                  // Icon Grid Picker (ق-۲۱)
                  Text('انتخاب آیکون:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: RealmEditFormSheet.iconPickerOptions.map((icon) {
                      final isSelected = icon == _selectedIcon;
                      return InkWell(
                        onTap: () => setState(() => _selectedIcon = icon),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: colors.primary, width: 1.5) : null,
                          ),
                          child: Text(icon, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Color Picker
                  Text('رنگ قلمرو:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: RealmEditFormSheet.colorPaletteHex.map((hex) {
                      final isSelected = hex.toLowerCase() == _selectedColorHex.toLowerCase();
                      final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                      return InkWell(
                        onTap: () => setState(() => _selectedColorHex = hex),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Realm Mode (ق-۲۰)
                  Text('حالت و سطح تمرکز قلمرو:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.textPrimary.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        _buildModeOption(RealmMode.focus, 'تمرکز عمیق', colors),
                        _buildModeOption(RealmMode.silent, 'بی‌صدا', colors),
                        _buildModeOption(RealmMode.normal, 'عادی', colors),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),
                  Text(
                    _selectedMode == RealmMode.focus
                        ? '⚡ فقط روتین‌های ضروری (اصلی) اجازه اعلان و نمایش دارند.'
                        : (_selectedMode == RealmMode.silent
                            ? '🌙 تمام اعلان‌های صوتی این قلمرو قطع خواهند بود.'
                            : '✨ تمام روتین‌ها طبق زمان‌بندی معمول نمایش داده می‌شوند.'),
                    style: TextStyle(fontSize: 11, color: colors.textTertiary),
                  ),

                  const SizedBox(height: 20),

                  // Active Days Row (ق-۲۲)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('روزهای فعال:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _selectedDays = {1, 2, 3, 4, 5, 6, 7}),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                            child: Text('همه روزها', style: TextStyle(fontSize: 11, color: colors.primary)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _selectedDays = {6, 7, 1, 2, 3, 4}),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                            child: Text('روزهای کاری', style: TextStyle(fontSize: 11, color: colors.primary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Expanded(child: _buildDayChip('ش', 6)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildDayChip('ی', 7)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildDayChip('د', 1)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildDayChip('س', 2)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildDayChip('چ', 3)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildDayChip('پ', 4)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildDayChip('ج', 5)),
                    ],
                  ),

                  if (_daysError != null) ...[
                    const SizedBox(height: 4),
                    Text(_daysError!, style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                  ],

                  const SizedBox(height: 20),

                  // Time Range Pickers
                  Text('بازه زمانی فعالیت در طول روز:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _startTime);
                            if (picked != null) setState(() => _startTime = picked);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: colors.textPrimary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('شروع:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                                Text(_formatTimeOfDay(_startTime), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _endTime);
                            if (picked != null) setState(() => _endTime = picked);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: colors.textPrimary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('پایان:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                                Text(_formatTimeOfDay(_endTime), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Save Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _validateAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              isEditing ? 'ذخیره تغییرات' : 'ایجاد قلمرو',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

      return RitmoGlassSheet(
        borderRadius: sheetRadius,
        child: sheetContent,
      );
    }

    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _expandSheetToMax();
      });
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_isDirty || _isSubmitting,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final canDismiss = await _handleDiscardConfirmation();
          if (canDismiss && mounted) {
            Navigator.of(this.context).pop();
          }
        },
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (notification.extent <= 0.48 && !_isDismissing) {
              if (_isDirty) {
                if (!_isConfirmationShowing) {
                  if (_sheetController.isAttached) {
                    unawaited(_sheetController.animateTo(
                      0.60,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    ));
                  }
                  _handleDiscardConfirmation().then((canDismiss) {
                    if (!mounted) return;
                    if (canDismiss) {
                      _isDismissing = true;
                      Navigator.of(this.context).pop();
                    }
                  });
                }
              } else {
                _isDismissing = true;
                Navigator.of(this.context).pop();
              }
            }
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.60,
            minChildSize: 0.20,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.60, 0.95],
            expand: false,
            builder: (context, scrollController) {
              return buildSheetContainer(scrollController);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, int weekday) {
    final isSelected = _selectedDays.contains(weekday);
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedDays.remove(weekday);
            } else {
              _selectedDays.add(weekday);
            }
            if (_daysError != null && _selectedDays.isNotEmpty) {
              _daysError = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary
                : colors.textPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.textPrimary.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? Colors.white : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption(RealmMode mode, String label, RitmoColors colors) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
