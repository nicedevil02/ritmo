import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// فرم ایجاد فعالیت سفارشی توسط کاربر با اعتبارسنجی نام یکتا و عدم پذیرش نام تکراری
class CustomActivityFormSheet extends StatefulWidget {
  const CustomActivityFormSheet({
    super.key,
    required this.existingNames,
    required this.onSubmit,
  });

  final List<String> existingNames;
  final Future<MovementActivityKind> Function({
    required String nameFa,
    required String family,
    required String primaryMetric,
    required String icon,
  }) onSubmit;

  static Future<MovementActivityKind?> show(
    BuildContext context, {
    required List<String> existingNames,
    required Future<MovementActivityKind> Function({
      required String nameFa,
      required String family,
      required String primaryMetric,
      required String icon,
    }) onSubmit,
  }) {
    return showModalBottomSheet<MovementActivityKind>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: CustomActivityFormSheet(
          existingNames: existingNames,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  @override
  State<CustomActivityFormSheet> createState() => _CustomActivityFormSheetState();
}

class _CustomActivityFormSheetState extends State<CustomActivityFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedFamily = 'running';
  String _selectedPrimaryMetric = 'مدت زمان';
  String _selectedIcon = 'directions_run';
  bool _isSaving = false;
  String? _errorMessage;

  final List<Map<String, String>> _families = [
    {'key': 'running', 'title': 'دویدن و پیاده‌روی', 'icon': 'directions_run'},
    {'key': 'cycling', 'title': 'دوچرخه‌سواری', 'icon': 'directions_bike'},
    {'key': 'swimming', 'title': 'شنا و ورزش‌های آبی', 'icon': 'pool'},
    {'key': 'strength', 'title': 'تمرین قدرتی و بدنسازی', 'icon': 'fitness_center'},
    {'key': 'mobility', 'title': 'کشش و انعطاف‌پذیری', 'icon': 'self_improvement'},
    {'key': 'racket', 'title': 'ورزش‌های راکتی', 'icon': 'sports_tennis'},
    {'key': 'team', 'title': 'ورزش‌های تیمی', 'icon': 'sports_soccer'},
    {'key': 'martial', 'title': 'هنرهای رزمی', 'icon': 'sports_kabaddi'},
    {'key': 'hiking', 'title': 'کوهنوردی و طبیعت‌گردی', 'icon': 'terrain'},
    {'key': 'other', 'title': 'سایر فعالیت‌ها', 'icon': 'sports_score'},
  ];

  final List<String> _metrics = [
    'مدت زمان',
    'مسافت (کیلومتر)',
    'کالری',
    'تعداد ست و تکرار',
    'تعداد دور',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final trimmedName = _nameController.text.trim();
    if (widget.existingNames.any((n) => n.toLowerCase() == trimmedName.toLowerCase())) {
      setState(() {
        _errorMessage = MovementStrings.customActivityDuplicateError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final created = await widget.onSubmit(
        nameFa: trimmedName,
        family: _selectedFamily,
        primaryMetric: _selectedPrimaryMetric,
        icon: _selectedIcon,
      );

      if (mounted) {
        Navigator.of(context).pop(created);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // دستگیره شیت
              Center(
                child: Container(
                  width: MovementLayout.kSheetHandleSize.width,
                  height: MovementLayout.kSheetHandleSize.height,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              // سربرگ شیت
              Text(
                MovementStrings.customActivityTitle,
                style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              // فیلد نام فعالیت
              Text(
                '${MovementStrings.customActivityName} *',
                style: RitmoTextStyles.label(colors.textSecondary),
              ),
              const SizedBox(height: RitmoSpacing.xs),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: RitmoTextStyles.body(colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'مثال: اسکیت‌برد، صخره‌نوردی سالنی...',
                  hintStyle: RitmoTextStyles.body(colors.textTertiary),
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: sportsColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return MovementStrings.customActivityNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: RitmoSpacing.md),

              // انتخاب خانواده ورزشی
              Text(
                MovementStrings.customActivityCategory,
                style: RitmoTextStyles.label(colors.textSecondary),
              ),
              const SizedBox(height: RitmoSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _selectedFamily,
                items: _families.map((f) {
                  return DropdownMenuItem(
                    value: f['key'],
                    child: Text(f['title']!, style: RitmoTextStyles.body(colors.textPrimary)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final found = _families.firstWhere((f) => f['key'] == val);
                    setState(() {
                      _selectedFamily = val;
                      _selectedIcon = found['icon']!;
                    });
                  }
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.md),

              // انتخاب شاخص اصلی
              Text(
                MovementStrings.customActivityMetric,
                style: RitmoTextStyles.label(colors.textSecondary),
              ),
              const SizedBox(height: RitmoSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _selectedPrimaryMetric,
                items: _metrics.map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(m, style: RitmoTextStyles.body(colors.textPrimary)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPrimaryMetric = val);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),

              // نمایش پیام خطا
              if (_errorMessage != null) ...[
                const SizedBox(height: RitmoSpacing.sm),
                Text(
                  _errorMessage!,
                  style: RitmoTextStyles.caption(colors.error),
                ),
              ],
              const SizedBox(height: RitmoSpacing.xl),

              // دکمهٔ ذخیره
              SizedBox(
                width: double.infinity,
                height: MovementLayout.kFieldMinHeight,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sportsColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          MovementStrings.customActivitySubmit,
                          style: RitmoTextStyles.label(Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
