import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/presentation/common/confirm_dialog.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_danger_row.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_group.dart';

/// صفحهٔ تنظیمات حرکت (MovementSettingsScreen) — حداکثر ۲۰۰ خط طبق D-39 و P-18
class MovementSettingsScreen extends StatefulWidget {
  const MovementSettingsScreen({super.key, this.preferencesService});

  final MovementPreferencesService? preferencesService;

  @override
  State<MovementSettingsScreen> createState() => _MovementSettingsScreenState();
}

class _MovementSettingsScreenState extends State<MovementSettingsScreen> {
  late final MovementPreferencesService _service;
  bool _isLoading = true;

  int _weeklyGoalSessions = 3;
  List<int> _preferredDays = [0, 2, 4];
  int? _reminderHour = 8;
  MovementTier _currentTier = MovementTier.one;

  @override
  void initState() {
    super.initState();
    _service = widget.preferencesService ?? MovementPreferencesService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final goal = await _service.getWeeklyGoalSessions();
    final days = await _service.getPreferredDays();
    final hour = await _service.getReminderHour();
    final tier = await _service.resolveTier();

    if (mounted) {
      setState(() {
        _weeklyGoalSessions = goal;
        _preferredDays = days;
        _reminderHour = hour;
        _currentTier = tier;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateWeeklyGoal(int val) async {
    setState(() => _weeklyGoalSessions = val);
    await _service.setWeeklyGoalSessions(val);
  }

  Future<void> _toggleDay(int dayIdx) async {
    final updated = List<int>.from(_preferredDays);
    if (updated.contains(dayIdx)) {
      if (updated.length > 1) updated.remove(dayIdx);
    } else {
      updated.add(dayIdx);
      updated.sort();
    }
    setState(() => _preferredDays = updated);
    await _service.setPreferredDays(updated);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour ?? 8, minute: 0),
    );
    if (picked != null) {
      setState(() => _reminderHour = picked.hour);
      await _service.setReminderHour(picked.hour);
    }
  }

  Future<void> _onToggleStrengthTier(bool enable) async {
    if (enable) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => const MovementConfirmDialog(
          title: 'فعال‌سازی تمرین قدرتی',
          message: 'بخش قدرتی امکانات بیشتری داره — مثل برنامهٔ وزنه و RIR. مطمئنی؟',
          confirmLabel: 'فعال‌سازی',
        ),
      );
      if (confirmed == true && mounted) {
        await _service.setTier(MovementTier.three);
        setState(() => _currentTier = MovementTier.three);
      }
    } else {
      await _service.setTier(MovementTier.two);
      setState(() => _currentTier = MovementTier.two);
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const MovementConfirmDialog(
        title: 'حذف تمام داده‌های حرکت',
        message:
            'آیا از حذف تمام تاریخچه، جلسات و برنامه‌های حرکت اطمینان دارید؟ این عمل غیرقابل‌بازگشت است.',
        destructive: true,
        confirmLabel: 'حذف دائمی',
      ),
    );

    if (confirmed == true && mounted) {
      await _service.deleteAllMovementData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمام داده‌های حرکت پاک شدند.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const dayNames = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    return MovementScreenShell(
      title: 'تنظیمات حرکت',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(RitmoSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ۱. سطح تمرین و بخش پیشرفته
                  SettingsGroup(
                    title: 'امکانات پیشرفته',
                    children: [
                      SwitchListTile(
                        title: Text(
                          'تمرین قدرتی (پیشرفته)',
                          style: RitmoTextStyles.body(colors.textPrimary),
                        ),
                        subtitle: Text(
                          'برنامهٔ وزنه، ثبت ست و RIR',
                          style: RitmoTextStyles.caption(colors.textSecondary),
                        ),
                        value: _currentTier == MovementTier.three,
                        onChanged: _onToggleStrengthTier,
                      ),
                    ],
                  ),
                  const SizedBox(height: RitmoSpacing.lg),

                  // ۲. هدف هفتگی
                  SettingsGroup(
                    title: 'هدف هفتگی',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(RitmoSpacing.md),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تعداد جلسات در هفته',
                              style: RitmoTextStyles.body(colors.textPrimary),
                            ),
                            DropdownButton<int>(
                              value: _weeklyGoalSessions,
                              dropdownColor: colors.surfaceElevated,
                              underline: const SizedBox.shrink(),
                              items: List.generate(7, (i) => i + 1).map((n) {
                                return DropdownMenuItem(
                                  value: n,
                                  child: Text(
                                    '${toPersianDigits(n)} جلسه',
                                    style: RitmoTextStyles.body(
                                      colors.textPrimary,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) _updateWeeklyGoal(val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RitmoSpacing.lg),

                  // ۳. روزهای ترجیحی
                  SettingsGroup(
                    title: 'روزهای ترجیحی تمرین',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(RitmoSpacing.md),
                        child: Wrap(
                          spacing: RitmoSpacing.sm,
                          children: List.generate(7, (i) {
                            final isSelected = _preferredDays.contains(i);
                            return FilterChip(
                              label: Text(dayNames[i]),
                              selected: isSelected,
                              onSelected: (_) => _toggleDay(i),
                              selectedColor: colors.primary,
                              labelStyle: RitmoTextStyles.label(
                                isSelected
                                    ? colors.onPrimary
                                    : colors.textPrimary,
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RitmoSpacing.lg),

                  // ۴. یادآور روزانه
                  SettingsGroup(
                    title: 'یادآور روزانه',
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          title: Text(
                            'ساعت یادآوری',
                            style: RitmoTextStyles.body(colors.textPrimary),
                          ),
                          subtitle: Text(
                            _reminderHour != null
                                ? 'ساعت ${toPersianDigits(_reminderHour)}:۰۰'
                                : 'غیرفعال',
                            style: RitmoTextStyles.caption(colors.textSecondary),
                          ),
                          trailing: const Icon(Icons.access_time_rounded),
                          onTap: _pickReminderTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RitmoSpacing.xl),

                  // ۵. منطقهٔ خطر: حذف تمام داده‌ها
                  SettingsDangerRow(
                    title: 'حذف تمام داده‌های حرکت',
                    explanation:
                        'پاکسازی کامل جلسات، لاگ‌ها و پیشرفت‌های ثبت‌شده',
                    buttonLabel: 'پاکسازی داده‌ها',
                    onTap: _confirmDeleteAll,
                  ),
                ],
              ),
            ),
    );
  }
}
