import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/data/models/ss_user_profile_model.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_program_builder.dart';
import 'package:ritmo/features/supplementary_sports/presentation/widgets/shared/primary_button.dart';
import 'package:ritmo/features/supplementary_sports/presentation/widgets/ss_program_diff_sheet.dart';

class SsProgramSettingsScreen extends StatefulWidget {
  const SsProgramSettingsScreen({super.key});

  @override
  State<SsProgramSettingsScreen> createState() =>
      _SsProgramSettingsScreenState();
}

class _SsProgramSettingsScreenState extends State<SsProgramSettingsScreen> {
  bool _isLoading = true;
  SsUserProfile? _profile;

  // Working state
  List<int> _trainingDays = [];
  String _splitPattern = 'AUTO';
  String _defaultIntensity = 'MODERATE';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'ss_user_profile',
        where: 'id = ?',
        whereArgs: ['default'],
      );
      if (rows.isNotEmpty) {
        final profile = SsUserProfile.fromMap(rows.first);
        setState(() {
          _profile = profile;
          _trainingDays = List.from(profile.trainingDays);
          _splitPattern = profile.splitPattern;
          _defaultIntensity = profile.defaultIntensity;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndRebuild() async {
    if (_profile == null || _trainingDays.isEmpty) return;

    // First show diff sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SsProgramDiffSheet(
        messageFa:
            'تغییر تنظیمات برنامه باعث می‌شود نسخه‌های تمرینی آینده شما (از فردا به بعد) مجدداً محاسبه و جایگزین شوند. آیا موافقید؟',
        addedCount: 0,
        removedCount: 0,
        updatedCount: 0,
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // Update profile
      final newProfile = _profile!.copyWith(
        trainingDays: _trainingDays.toList(),
        splitPattern: _splitPattern,
        defaultIntensity: _defaultIntensity,
      );

      final updatedProfile = newProfile.toMap();
      updatedProfile['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        'ss_user_profile',
        updatedProfile,
        where: 'id = ?',
        whereArgs: ['default'],
      );

      // Trigger rebuild starting from tomorrow
      await SsProgramBuilder.apply(
        ProgramBuildRequest(
          fromDate: DateTime.now().add(const Duration(days: 1)),
          profile: newProfile,
          respectLocks: false, // We want to clear unfinished past/future
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'برنامه با موفقیت به‌روزرسانی شد.',
              style: TextStyle(),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleDay(int dayNum) {
    setState(() {
      if (_trainingDays.contains(dayNum)) {
        if (_trainingDays.length > 1) {
          _trainingDays.remove(dayNum);
        }
      } else {
        if (_trainingDays.length < 6) {
          // Max 6 days
          _trainingDays.add(dayNum);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsAccent = context.modules.sports;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.surface,
        body: Center(child: CircularProgressIndicator(color: sportsAccent)),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'تنظیمات برنامه تمرینی',
          style: TextStyle(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'روزهای تمرین در هفته',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'حداقل یک روز برای استراحت باید خالی بماند.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDayChip(6, 'شنبه', context),
                  _buildDayChip(7, 'یکشنبه', context),
                  _buildDayChip(1, 'دوشنبه', context),
                  _buildDayChip(2, 'سه شنبه', context),
                  _buildDayChip(3, 'چهارشنبه', context),
                  _buildDayChip(4, 'پنجشنبه', context),
                  _buildDayChip(5, 'جمعه', context),
                ],
              ),
              const SizedBox(height: 32),

              const Text(
                'الگوی تقسیم عضلات (Split)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _splitPattern,
                dropdownColor: colors.surfaceSunken,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: colors.textPrimary),
                items: const [
                  DropdownMenuItem(
                    value: 'AUTO',
                    child: Text('هوشمند (پیشنهادی ریتمو)'),
                  ),
                  DropdownMenuItem(
                    value: 'FULL_BODY',
                    child: Text('فول بادی (تمام بدن)'),
                  ),
                  DropdownMenuItem(
                    value: 'UPPER_LOWER',
                    child: Text('بالاتنه / پایین‌تنه'),
                  ),
                  DropdownMenuItem(
                    value: 'PUSH_PULL_LEGS',
                    child: Text('هل دادن / کشیدن / پا'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _splitPattern = val);
                },
              ),
              const SizedBox(height: 32),

              const Text(
                'شدت پیش‌فرض (Intensity)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _defaultIntensity,
                dropdownColor: colors.surfaceSunken,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: colors.textPrimary),
                items: const [
                  DropdownMenuItem(
                    value: 'LIGHT',
                    child: Text('سبک (ریکاوری بیشتر)'),
                  ),
                  DropdownMenuItem(
                    value: 'MODERATE',
                    child: Text('متوسط (تعادل استاندارد)'),
                  ),
                  DropdownMenuItem(
                    value: 'HARD',
                    child: Text('سنگین (تمرکز بر حجم)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _defaultIntensity = val);
                },
              ),

              const SizedBox(height: 48),

              PrimaryButton(
                label: 'ذخیره و بازسازی تقویم',
                onPressed: _saveAndRebuild,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(int dayNum, String label, BuildContext context) {
    final colors = context.colors;
    final sportsAccent = context.modules.sports;
    final isSelected = _trainingDays.contains(dayNum);

    return FilterChip(
      label: Text(label, style: const TextStyle()),
      selected: isSelected,
      onSelected: (_) => _toggleDay(dayNum),
      selectedColor: sportsAccent.withValues(alpha: 0.2),
      backgroundColor: colors.surfaceSunken,
      labelStyle: TextStyle(
        color: isSelected ? sportsAccent : colors.textSecondary,
      ),
      showCheckmark: false,
    );
  }
}
