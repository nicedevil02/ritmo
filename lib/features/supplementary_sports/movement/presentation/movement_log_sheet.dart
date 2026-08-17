// lib/features/supplementary_sports/movement/presentation/movement_log_sheet.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/analytics/movement_load_calculator.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_budget.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_datetime_field.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_kind_selector.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_metric_field.dart';

Future<void> showMovementLogSheet(
  BuildContext context, {
  MovementKind? presetKind,
  DateTime? presetDate,
  int? presetDurationMinutes,
  String? presetVenue,
  VoidCallback? onLogged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MovementLogSheet(
      presetKind: presetKind,
      presetDate: presetDate,
      presetDurationMinutes: presetDurationMinutes,
      presetVenue: presetVenue,
      onLogged: onLogged,
    ),
  );
}

class MovementLogSheet extends StatefulWidget {
  const MovementLogSheet({
    super.key,
    this.presetKind,
    this.presetDate,
    this.presetDurationMinutes,
    this.presetVenue,
    this.onLogged,
  });

  final MovementKind? presetKind;
  final DateTime? presetDate;
  final int? presetDurationMinutes;
  final String? presetVenue;
  final VoidCallback? onLogged;

  @override
  State<MovementLogSheet> createState() => _MovementLogSheetState();
}

class _MovementLogSheetState extends State<MovementLogSheet> {
  MovementKind? _selectedKind;
  bool _kindSelectorExpanded = true;

  late DateTime _selectedDateTime;

  /// null یعنی کاربر هنوز مدت زمان را وارد نکرده؛ بدون آن ذخیره ممکن نیست.
  int? _durationMinutes;

  MovementIntensity _intensity = MovementIntensity.medium;
  String? _feeling;

  // مقادیر اختیاری؛ null یعنی «وارد نشده» و اصلاً ذخیره نمی‌شود.
  double? _distanceKm;
  double? _laps;
  double? _elevationMeters;
  double? _steps;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _companionsController = TextEditingController();

  bool _isSaving = false;
  bool _allowPop = false;
  bool _textDirty = false;

  double _userWeightKg = 70.0;

  /// هدف واقعی هفته از پروفایل کاربر؛ null یعنی هنوز خوانده نشده یا خطا داشته.
  double? _weeklyTarget;
  double _weeklyAchieved = 0.0;

  static const List<String> _feelings = [
    '🔥 عالی',
    '👍 خوب',
    '😓 خسته',
    '💪 سخت بود',
  ];

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.presetKind;
    _kindSelectorExpanded = widget.presetKind == null;
    _durationMinutes = widget.presetDurationMinutes;

    // اگر تاریخِ از پیش‌تعیین‌شده ساعت ندارد (روزِ برنامه)، ساعت فعلی را روی آن می‌گذاریم
    // تا کاربر با ۰۰:۰۰ روبه‌رو نشود.
    final preset = widget.presetDate;
    final now = DateTime.now();
    if (preset == null) {
      _selectedDateTime = now;
    } else if (preset.hour == 0 && preset.minute == 0) {
      _selectedDateTime = DateTime(preset.year, preset.month, preset.day, now.hour, now.minute);
    } else {
      _selectedDateTime = preset;
    }

    if (widget.presetVenue != null) {
      _venueController.text = widget.presetVenue!;
    }

    _noteController.addListener(_markTextDirty);
    _venueController.addListener(_markTextDirty);
    _companionsController.addListener(_markTextDirty);

    _loadInitialData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _venueController.dispose();
    _companionsController.dispose();
    super.dispose();
  }

  void _markTextDirty() {
    // فقط یک بار setState لازم است تا PopScope مقدار تازه را ببیند.
    if (!_textDirty && mounted) setState(() => _textDirty = true);
  }

  Future<void> _loadInitialData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final weight = await MovementLoadCalculator.getUserWeightKg(db);
      if (mounted) setState(() => _userWeightKg = weight);
    } catch (e) {
      debugPrint('[MovementLogSheet] وزن کاربر خوانده نشد: $e');
    }

    try {
      final snapshot = await MovementBudgetService.instance.getCurrentWeekSnapshot();
      if (mounted) {
        setState(() {
          _weeklyTarget = snapshot.weeklyMetMinutesTarget;
          _weeklyAchieved = snapshot.achievedMetMinutes;
        });
      }
    } catch (e) {
      // بدون هدف واقعی، درصد بودجه را نشان نمی‌دهیم — عدد ساختگی بدتر از نبودن است.
      debugPrint('[MovementLogSheet] بودجه هفته خوانده نشد: $e');
    }
  }

  // ── محاسبه‌ها ───────────────────────────────────────────────

  int get _effectiveDuration => _durationMinutes ?? 0;

  double get _calculatedMet {
    final kind = _selectedKind;
    if (kind == null) return 4.0;
    return MovementLoadCalculator.metFor(
      baseMet: kind.baseMet,
      metLow: kind.metLow,
      metHigh: kind.metHigh,
      intensity: _intensity,
    );
  }

  double get _calculatedMetMinutes => MovementLoadCalculator.metMinutes(
        met: _calculatedMet,
        durationMinutes: _effectiveDuration,
      );

  double get _calculatedCalories => MovementLoadCalculator.calories(
        met: _calculatedMet,
        weightKg: _userWeightKg,
        durationMinutes: _effectiveDuration,
      );

  int? get _budgetBeforePercent {
    final target = _weeklyTarget;
    if (target == null || target <= 0) return null;
    return ((_weeklyAchieved / target) * 100).round();
  }

  int? get _budgetAfterPercent {
    final target = _weeklyTarget;
    if (target == null || target <= 0) return null;
    return (((_weeklyAchieved + _calculatedMetMinutes) / target) * 100).round();
  }

  bool get _isFutureTime =>
      _selectedDateTime.isAfter(DateTime.now().add(const Duration(minutes: 2)));

  /// معیارهایی که برای این نوع ورزش معنا دارند (اصلی + فرعی).
  List<MovementMetric> get _activeMetrics {
    final kind = _selectedKind;
    if (kind == null) return const [];
    final out = <MovementMetric>[];
    for (final metric in [kind.primaryMetric, kind.secondaryMetric]) {
      if (metric == MovementMetric.duration ||
          metric == MovementMetric.none ||
          metric == MovementMetric.sets) {
        continue;
      }
      if (!out.contains(metric)) out.add(metric);
    }
    return out;
  }

  String? get _blockingReason {
    if (_selectedKind == null) return 'اول نوع فعالیت را انتخاب کن';
    if (_effectiveDuration <= 0) return 'مدت زمان فعالیت را وارد کن';
    if (_isFutureTime) return 'زمان انتخابی در آینده است';
    return null;
  }

  bool get _canSave => _blockingReason == null && !_isSaving;

  bool get _hasUnsavedInput {
    if (_selectedKind?.code != widget.presetKind?.code) return true;
    if (_durationMinutes != widget.presetDurationMinutes) return true;
    if (_distanceKm != null || _laps != null || _elevationMeters != null || _steps != null) {
      return true;
    }
    if (_feeling != null) return true;
    if (_intensity != MovementIntensity.medium) return true;
    if (_noteController.text.trim().isNotEmpty) return true;
    if (_companionsController.text.trim().isNotEmpty) return true;
    if (_venueController.text.trim() != (widget.presetVenue ?? '').trim()) return true;
    return false;
  }

  // ── کنش‌ها ─────────────────────────────────────────────────

  void _onKindSelected(MovementKind kind) {
    final changed = _selectedKind?.code != kind.code;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedKind = kind;
      _kindSelectorExpanded = false;
      // مقادیر ورزش قبلی برای ورزش جدید بی‌معنا هستند (۳ کیلومتر دوچرخه ≠ شنا).
      if (changed) {
        _distanceKm = null;
        _laps = null;
        _elevationMeters = null;
        _steps = null;
      }
    });
  }

  /// setState را اعمال می‌کند و بعد از بازسازی (که PopScope مقدار تازه را می‌بیند) خارج می‌شود.
  void _popAfterRebuild() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _confirmDiscard() async {
    final colors = context.colors;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RitmoRadius.card),
          ),
          title: Text(
            'ثبت نشده رها شود؟',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'اطلاعاتی که وارد کرده‌ای ذخیره نشده و از بین می‌رود.',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 13.5,
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'ادامهٔ ثبت',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.bold,
                  color: context.modules.sports,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'رها کن',
                style: TextStyle(fontFamily: 'Vazirmatn', color: colors.error),
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldDiscard == true && mounted) _popAfterRebuild();
  }

  Future<void> _saveLog() async {
    final kind = _selectedKind;
    if (kind == null || !_canSave) return;

    setState(() => _isSaving = true);

    final metrics = _activeMetrics;
    final event = MovementEvent(
      id: RitmoIdFactory.movementLog(),
      kindCode: kind.code,
      durationMinutes: _effectiveDuration,
      intensity: _intensity,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      loggedAt: _selectedDateTime.millisecondsSinceEpoch,
      feeling: _feeling,
      distanceMeters: metrics.contains(MovementMetric.distance) && _distanceKm != null
          ? _distanceKm! * 1000
          : null,
      elevationMeters:
          metrics.contains(MovementMetric.elevation) ? _elevationMeters : null,
      laps: metrics.contains(MovementMetric.laps) && _laps != null
          ? _laps!.round()
          : null,
      steps: metrics.contains(MovementMetric.steps) && _steps != null
          ? _steps!.round()
          : null,
      venue: _venueController.text.trim().isNotEmpty ? _venueController.text.trim() : null,
      companions: _companionsController.text.trim().isNotEmpty
          ? _companionsController.text.trim()
          : null,
      sourceModule: 'MOVEMENT',
    );

    try {
      final res = await MovementRepository.instance.logEvent(event);
      unawaited(HapticFeedback.mediumImpact());

      if (!mounted) return;

      final isPr = res['isPr'] as bool? ?? false;
      final colors = context.colors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPr
                ? '🎉 رکورد جدید ثبت شد! عهدی که بستی محکم‌تر شد 🔥'
                : 'فعالیت «${kind.titleFa}» برای ${movementRelativeDayLabel(_selectedDateTime)} ثبت شد ✨',
            style: const TextStyle(fontFamily: 'Vazirmatn'),
          ),
          backgroundColor: isPr ? colors.success : null,
        ),
      );
      widget.onLogged?.call();
      _popAfterRebuild();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ثبت نشد: $e',
              style: const TextStyle(fontFamily: 'Vazirmatn'),
            ),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── ساخت رابط ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = context.modules.sports;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: _allowPop || !_hasUnsavedInput,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RitmoRadius.sheet),
            ),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              const SizedBox(height: RitmoSpacing.md),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: RitmoSpacing.md),

              // سرصفحه
              Padding(
                padding: const EdgeInsets.only(right: RitmoSpacing.lg, left: RitmoSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ثبت فعالیت انجام‌شده',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'بستن',
                      icon: Icon(CupertinoIcons.xmark, size: 20, color: colors.textSecondary),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.divider),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: RitmoSpacing.lg,
                    right: RitmoSpacing.lg,
                    top: RitmoSpacing.lg,
                    bottom: RitmoSpacing.lg + bottomInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ۱) نوع فعالیت
                      _buildKindSection(colors, accent),
                      const SizedBox(height: RitmoSpacing.lg),

                      // ۲) زمان — قبلاً هیچ راهی برای تغییرش نبود
                      MovementDateTimeField(
                        value: _selectedDateTime,
                        accent: accent,
                        onChanged: (dt) => setState(() => _selectedDateTime = dt),
                      ),
                      const SizedBox(height: RitmoSpacing.lg),
                      Divider(height: 1, color: colors.divider),
                      const SizedBox(height: RitmoSpacing.lg),

                      // ۳) مدت زمان (لازم)
                      MovementMetricField(
                        label: 'مدت زمان',
                        unit: 'دقیقه',
                        icon: CupertinoIcons.timer,
                        value: _durationMinutes?.toDouble(),
                        isRequired: true,
                        step: 5,
                        min: 1,
                        max: 600,
                        quickValues: const [15, 30, 45, 60, 90],
                        accent: accent,
                        onChanged: (v) => setState(
                          () => _durationMinutes = v == null ? null : v.round(),
                        ),
                      ),

                      // ۴) معیارهای مخصوص همین ورزش
                      ..._buildMetricFields(accent),

                      const SizedBox(height: RitmoSpacing.lg),

                      // ۵) شدت
                      _buildSectionLabel('شدت تمرین', colors),
                      const SizedBox(height: RitmoSpacing.sm),
                      Row(
                        children: MovementIntensity.values.map((i) {
                          final isSelected = i == _intensity;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: RitmoSpacing.sm),
                              child: _SelectableTile(
                                label: i.titleFa,
                                isSelected: isSelected,
                                accent: accent,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _intensity = i);
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      // ۶) احساس (اختیاری و قابل لغو)
                      Row(
                        children: [
                          _buildSectionLabel('حس‌وحال تمرین', colors),
                          const SizedBox(width: RitmoSpacing.xs),
                          Text(
                            '(اختیاری)',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 11,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: RitmoSpacing.sm),
                      Wrap(
                        spacing: RitmoSpacing.sm,
                        runSpacing: RitmoSpacing.sm,
                        children: _feelings.map((f) {
                          final isSelected = f == _feeling;
                          return _SelectableTile(
                            label: f,
                            isSelected: isSelected,
                            accent: accent,
                            expand: false,
                            // دوباره زدن، انتخاب را برمی‌دارد.
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _feeling = isSelected ? null : f);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      if (_selectedKind?.needsVenue ?? false) ...[
                        TextField(
                          controller: _venueController,
                          style: TextStyle(fontFamily: 'Vazirmatn', color: colors.textPrimary),
                          decoration: _inputDecoration(
                            colors,
                            accent,
                            'نام مکان یا سالن',
                            CupertinoIcons.location_solid,
                          ),
                        ),
                        const SizedBox(height: RitmoSpacing.md),
                      ],

                      if (_selectedKind?.isSocial ?? false) ...[
                        TextField(
                          controller: _companionsController,
                          style: TextStyle(fontFamily: 'Vazirmatn', color: colors.textPrimary),
                          decoration: _inputDecoration(
                            colors,
                            accent,
                            'همراهان',
                            CupertinoIcons.person_2_fill,
                          ),
                        ),
                        const SizedBox(height: RitmoSpacing.md),
                      ],

                      TextField(
                        controller: _noteController,
                        maxLines: 2,
                        style: TextStyle(fontFamily: 'Vazirmatn', color: colors.textPrimary),
                        decoration: _inputDecoration(
                          colors,
                          accent,
                          'یادداشت (اختیاری)',
                          CupertinoIcons.doc_text,
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.md),
                    ],
                  ),
                ),
              ),

              _buildBottomBar(colors, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, RitmoColors colors) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Vazirmatn',
        fontWeight: FontWeight.bold,
        fontSize: 13.5,
        color: colors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(
    RitmoColors colors,
    Color accent,
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 13,
        color: colors.textSecondary,
      ),
      prefixIcon: Icon(icon, size: 18, color: colors.textSecondary),
      filled: true,
      fillColor: colors.surfaceSunken,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RitmoRadius.field),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RitmoRadius.field),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RitmoRadius.field),
      ),
    );
  }

  /// وقتی نوع انتخاب شد، انتخاب‌گر جمع می‌شود تا فرم زیرش دیده شود.
  Widget _buildKindSection(RitmoColors colors, Color accent) {
    final kind = _selectedKind;

    if (kind == null || _kindSelectorExpanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionLabel('چه فعالیتی انجام دادی؟', colors),
          const SizedBox(height: RitmoSpacing.md),
          MovementKindSelector(
            selectedKind: kind,
            onKindSelected: _onKindSelected,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: RitmoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(RitmoRadius.field),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text(kind.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: RitmoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.titleFa,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  kind.family.titleFa,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _kindSelectorExpanded = true),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 44),
              foregroundColor: accent,
            ),
            child: const Text(
              'تغییر',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMetricFields(Color accent) {
    final widgets = <Widget>[];

    for (final metric in _activeMetrics) {
      widgets.add(const SizedBox(height: RitmoSpacing.lg));

      switch (metric) {
        case MovementMetric.distance:
          final distance = _distanceKm;
          final duration = _durationMinutes;
          String? pace;
          if (distance != null && distance > 0 && duration != null && duration > 0) {
            pace = 'سرعت متوسط: '
                '${(duration / distance).toStringAsFixed(1).toPersianDigits()}'
                ' دقیقه برای هر کیلومتر';
          }
          widgets.add(
            MovementMetricField(
              label: 'مسافت',
              unit: metric.unitFa,
              icon: CupertinoIcons.map,
              value: distance,
              step: 0.5,
              min: 0,
              max: 300,
              decimals: 1,
              quickValues: const [1, 3, 5, 10],
              helper: pace,
              accent: accent,
              onChanged: (v) => setState(() => _distanceKm = v),
            ),
          );
          break;

        case MovementMetric.laps:
          final laps = _laps;
          widgets.add(
            MovementMetricField(
              label: 'تعداد طول',
              unit: metric.unitFa,
              icon: CupertinoIcons.repeat,
              value: laps,
              step: 1,
              min: 0,
              max: 400,
              quickValues: const [10, 20, 30, 40],
              helper: (laps != null && laps > 0)
                  ? 'با استخر ۲۵ متری ≈ ${(laps * 25).round().toPersianDigits()} متر'
                  : null,
              accent: accent,
              onChanged: (v) => setState(() => _laps = v),
            ),
          );
          break;

        case MovementMetric.elevation:
          widgets.add(
            MovementMetricField(
              label: 'اختلاف ارتفاع',
              unit: 'متر',
              icon: CupertinoIcons.arrow_up_right,
              value: _elevationMeters,
              step: 50,
              min: 0,
              max: 6000,
              quickValues: const [100, 300, 500, 1000],
              accent: accent,
              onChanged: (v) => setState(() => _elevationMeters = v),
            ),
          );
          break;

        case MovementMetric.steps:
          widgets.add(
            MovementMetricField(
              label: 'تعداد گام',
              unit: metric.unitFa,
              icon: CupertinoIcons.figure_walk,
              value: _steps,
              step: 500,
              min: 0,
              max: 100000,
              quickValues: const [2000, 5000, 8000, 10000],
              accent: accent,
              onChanged: (v) => setState(() => _steps = v),
            ),
          );
          break;

        case MovementMetric.duration:
        case MovementMetric.sets:
        case MovementMetric.none:
          widgets.removeLast();
          break;
      }
    }

    return widgets;
  }

  Widget _buildBottomBar(RitmoColors colors, Color accent) {
    final reason = _blockingReason;
    final before = _budgetBeforePercent;
    final after = _budgetAfterPercent;
    final hasLoad = _effectiveDuration > 0 && _selectedKind != null;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // پیش‌نمایش زنده: فقط وقتی عددی واقعی برای نشان دادن هست.
            if (hasLoad)
              Padding(
                padding: const EdgeInsets.only(bottom: RitmoSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '≈ ${_calculatedCalories.round().toPersianDigits()} کالری',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: accent,
                      ),
                    ),
                    if (before != null && after != null) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(color: colors.textTertiary),
                      ),
                      Text(
                        'بودجهٔ هفته: ${before.toPersianDigits()}٪ ← ${after.toPersianDigits()}٪',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  disabledBackgroundColor: colors.disabled,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: colors.textTertiary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                  ),
                ),
                onPressed: _canSave ? _saveLog : null,
                child: _isSaving
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text(
                        reason ?? 'ثبت فعالیت',
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// کاشی انتخابی یکدست برای شدت و حس‌وحال (به‌جای ChoiceChip با رنگ‌های ناهمگون).
class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.onTap,
    this.expand = true,
  });

  final String label;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RitmoRadius.chip),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          width: expand ? double.infinity : null,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.md,
            vertical: RitmoSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.18) : colors.surfaceSunken,
            borderRadius: BorderRadius.circular(RitmoRadius.chip),
            border: Border.all(
              color: isSelected ? accent : colors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? accent : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
