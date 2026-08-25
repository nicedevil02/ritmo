// lib/features/supplementary_sports/movement/presentation/movement_log_sheet.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

// ─── تابع عمومی ─────────────────────────────────────────────────────────────────────────

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

// ─── Widget ────────────────────────────────────────────────────────────────────────────

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
  // ── انتخاب‌ها
  MovementKind? _selectedKind;
  late DateTime _selectedDateTime;

  // ── معیارها — همه null شروع می‌شوند («واردنشده»)
  int? _durationMinutes; // null = وارد نشده
  double? _primaryMetricValue; // null = وارد نشده
  double? _secondaryMetricValue; // null = وارد نشده
  MovementIntensity _intensity = MovementIntensity.medium;
  String? _feeling; // null = انتخاب نشده

  // ── فیلدهای متنی
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _companionsController = TextEditingController();
  bool _textDirty = false;

  // ── وضعیت
  bool _isSaving = false;
  double _userWeightKg = 70.0;
  MovementBudgetSnapshot? _budgetSnapshot;

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
    _selectedDateTime = widget.presetDate ?? DateTime.now();
    _durationMinutes = widget.presetDurationMinutes;
    if (widget.presetVenue != null) {
      _venueController.text = widget.presetVenue!;
    }
    _setupDirtyListeners();
    _loadInitialData();
  }

  void _setupDirtyListeners() {
    void markDirty() {
      if (!_textDirty && mounted) setState(() => _textDirty = true);
    }
    _noteController.addListener(markDirty);
    _venueController.addListener(markDirty);
    _companionsController.addListener(markDirty);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _venueController.dispose();
    _companionsController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final weight = await MovementLoadCalculator.getUserWeightKg(db);
      if (mounted) setState(() => _userWeightKg = weight);
    } catch (_) {}

    try {
      final snapshot =
          await MovementBudgetService.instance.getCurrentWeekSnapshot();
      if (mounted) setState(() => _budgetSnapshot = snapshot);
    } catch (_) {
      // عدد اشتباه بدتر از نبود عدد است — در صورت خطا چیزی نشان نده
    }
  }

  // ── محاسبات ───────────────────────────────────────────────────────────────────────

  double get _calculatedMet {
    if (_selectedKind == null) return 4.0;
    return MovementLoadCalculator.metFor(
      baseMet: _selectedKind!.baseMet,
      metLow: _selectedKind!.metLow,
      metHigh: _selectedKind!.metHigh,
      intensity: _intensity,
    );
  }

  double get _calculatedMetMinutes {
    final dur = _durationMinutes;
    if (dur == null || dur <= 0) return 0;
    return MovementLoadCalculator.metMinutes(
      met: _calculatedMet,
      durationMinutes: dur,
    );
  }

  double get _calculatedCalories {
    final dur = _durationMinutes;
    if (dur == null || dur <= 0) return 0;
    return MovementLoadCalculator.calories(
      met: _calculatedMet,
      weightKg: _userWeightKg,
      durationMinutes: dur,
    );
  }

  // ── بلاککنندهٔ دکمه ────────────────────────────────────────────────────────────

  String? get _blockingReason {
    if (_selectedKind == null) return 'نوع ورزش را انتخاب کن';
    final dur = _durationMinutes;
    if (dur == null || dur <= 0) return 'مدت زمان فعالیت را وارد کن';
    final limit = DateTime.now().add(const Duration(minutes: 2));
    if (_selectedDateTime.isAfter(limit)) return 'زمان آینده مجاز نیست';
    return null;
  }

  bool get _hasData =>
      _textDirty ||
      _selectedKind != null ||
      _durationMinutes != null ||
      _primaryMetricValue != null ||
      _secondaryMetricValue != null ||
      _feeling != null;

  // ── اقدام‌ها ───────────────────────────────────────────────────────────────────────

  Future<bool> _confirmDiscard() async {
    if (!_hasData) return true;
    final colors = context.colors;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RitmoRadius.card),
          ),
          title: Text(
            'بدون ذخیره خارج می‌شوی؟',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'اطلاعات واردشده ذخیره نمی‌شود.',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'بمان',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'خروج',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.bold,
                  color: colors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  void _popAfterRebuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _saveLog() async {
    if (_blockingReason != null || _isSaving) return;

    setState(() => _isSaving = true);

    final kind = _selectedKind!;
    final dur = _durationMinutes!;

    double? distMeters;
    double? elevMeters;
    int? laps;
    int? steps;

    // معیار اصلی — فقط اگر کاربر واقعاً وارد کرده باشد
    final primary = _primaryMetricValue;
    if (primary != null) {
      switch (kind.primaryMetric) {
        case MovementMetric.distance:
          distMeters = primary * 1000; // km → m
          break;
        case MovementMetric.elevation:
          elevMeters = primary;
          break;
        case MovementMetric.laps:
          laps = primary.round();
          break;
        case MovementMetric.steps:
          steps = primary.round();
          break;
        default:
          break;
      }
    }

    // معیار ثانوی — قبلاً کاملاً نادیده گرفته می‌شد
    final secondary = _secondaryMetricValue;
    if (secondary != null && kind.secondaryMetric != MovementMetric.none) {
      switch (kind.secondaryMetric) {
        case MovementMetric.elevation:
          elevMeters ??= secondary;
          break;
        case MovementMetric.distance:
          distMeters ??= secondary * 1000;
          break;
        default:
          break;
      }
    }

    final event = MovementEvent(
      id: RitmoIdFactory.movementLog(),
      kindCode: kind.code,
      durationMinutes: dur,
      intensity: _intensity,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      loggedAt: _selectedDateTime.millisecondsSinceEpoch,
      feeling: _feeling,
      distanceMeters: distMeters,
      elevationMeters: elevMeters,
      laps: laps,
      steps: steps,
      venue: _venueController.text.trim().isNotEmpty
          ? _venueController.text.trim()
          : null,
      companions: _companionsController.text.trim().isNotEmpty
          ? _companionsController.text.trim()
          : null,
      sourceModule: 'MOVEMENT',
    );

    try {
      final res = await MovementRepository.instance.logEvent(event);
      if (mounted) {
        final isPr = res['isPr'] as bool? ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPr
                  ? '🎉 رکورد جدید ثبت شد! عهدی که بستی محکم‌تر شد 🔥'
                  : 'فعالیت با موفقیت ثبت شد ✨',
              style: const TextStyle(fontFamily: 'Vazirmatn'),
            ),
            backgroundColor: isPr ? context.colors.success : null,
          ),
        );
        widget.onLogged?.call();
        _popAfterRebuild();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در ثبت فعالیت: $e',
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

  // ── Build ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = context.modules.sports;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final blocking = _blockingReason;
    final canSave = blocking == null && !_isSaving;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard()) _popAfterRebuild();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.9),
            ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RitmoRadius.sheet),
            ),
            border: Border.all(color: colors.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              // ── هدر ──────────────────────────────────────────────────────────────
              const SizedBox(height: RitmoSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: RitmoSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.lg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ثبت فعالیت حرکتی',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'بستن',
                      icon: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: colors.textSecondary,
                      ),
                      onPressed: () async {
                        if (await _confirmDiscard()) _popAfterRebuild();
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.divider),

              // ── فرم ──────────────────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: RitmoSpacing.lg,
                    right: RitmoSpacing.lg,
                    top: RitmoSpacing.lg,
                    bottom: RitmoSpacing.xl + bottomInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ۱. انتخاب نوع ورزش
                      _SectionLabel('نوع ورزش', colors),
                      const SizedBox(height: RitmoSpacing.sm),
                      MovementKindSelector(
                        selectedKind: _selectedKind,
                        onKindSelected: (k) => setState(() {
                          if (_selectedKind?.code != k.code) {
                            // مقادیر با تغییر نوع پاک می‌شوند تا
                            // «۳ کیلومترِ دوچرخه» به شنا منتقل نشود
                            _primaryMetricValue = null;
                            _secondaryMetricValue = null;
                          }
                          _selectedKind = k;
                        }),
                      ),
                      const SizedBox(height: RitmoSpacing.xl),
                      Divider(color: colors.divider),
                      const SizedBox(height: RitmoSpacing.lg),

                      // ۲. زمان فعالیت — قبلاً اصلاً وجود نداشت (P0)
                      MovementDateTimeField(
                        value: _selectedDateTime,
                        onChanged: (dt) =>
                            setState(() => _selectedDateTime = dt),
                        accent: accent,
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      // ۳. مدت — MovementMetricField جای اسلایدر ۵دقیقه‌ای را گرفت
                      MovementMetricField(
                        label: 'مدت فعالیت',
                        unit: 'دقیقه',
                        value: _durationMinutes?.toDouble(),
                        onChanged: (v) => setState(
                          () => _durationMinutes = v?.round(),
                        ),
                        icon: CupertinoIcons.timer,
                        step: 1,
                        min: 1,
                        max: 480,
                        decimals: 0,
                        quickValues: const [15, 30, 45, 60, 90],
                        accent: accent,
                        isRequired: true,
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      // ۴. معیارهای نوع‌ویژه
                      if (_selectedKind != null) ...[
                        Divider(color: colors.divider),
                        const SizedBox(height: RitmoSpacing.lg),
                        Text(
                          'جزئیات: ${_selectedKind!.emoji} ${_selectedKind!.titleFa}',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: RitmoSpacing.md),
                        _buildPrimaryMetricField(accent),
                        if (_selectedKind!.secondaryMetric != MovementMetric.none) ...[
                          const SizedBox(height: RitmoSpacing.md),
                          _buildSecondaryMetricField(accent),
                        ],
                      ],

                      // ۵. شدت
                      const SizedBox(height: RitmoSpacing.xl),
                      Divider(color: colors.divider),
                      const SizedBox(height: RitmoSpacing.lg),
                      _SectionLabel('شدت تمرین', colors),
                      const SizedBox(height: RitmoSpacing.sm),
                      Row(
                        children: MovementIntensity.values.map((i) {
                          final isSelected = i == _intensity;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: GestureDetector(
                                onTap: () => setState(() => _intensity = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accent.withValues(alpha: 0.18)
                                        : colors.surfaceSunken,
                                    borderRadius: BorderRadius.circular(
                                      RitmoRadius.field,
                                    ),
                                    border: Border.all(
                                      color:
                                          isSelected ? accent : colors.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      i.titleFa,
                                      style: TextStyle(
                                        fontFamily: 'Vazirmatn',
                                        fontSize: 12.5,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? accent
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      // ۶. حس — بدون پیش‌انتخاب، لمس دوباره = لغو
                      _SectionLabel('حس و احساس تمرین (اختیاری)', colors),
                      const SizedBox(height: RitmoSpacing.sm),
                      Wrap(
                        spacing: RitmoSpacing.sm,
                        runSpacing: RitmoSpacing.sm,
                        children: _feelings.map((f) {
                          final isSelected = f == _feeling;
                          return GestureDetector(
                            onTap: () => setState(
                              () => _feeling = isSelected ? null : f,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accent.withValues(alpha: 0.18)
                                    : colors.surfaceSunken,
                                borderRadius:
                                    BorderRadius.circular(RitmoRadius.pill),
                                border: Border.all(
                                  color: isSelected ? accent : colors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 13,
                                    color: isSelected
                                        ? accent
                                        : colors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // ۷. مکان (در صورت نیاز نوع ورزش)
                      if (_selectedKind?.needsVenue == true) ...[
                        const SizedBox(height: RitmoSpacing.lg),
                        TextFormField(
                          controller: _venueController,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontFamily: 'Vazirmatn',
                          ),
                          decoration: InputDecoration(
                            labelText: 'نام مکان / سالن (اختیاری)',
                            prefixIcon: const Icon(
                              CupertinoIcons.location_solid,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(RitmoRadius.field),
                            ),
                          ),
                        ),
                      ],

                      // ۸. همراهان (در صورت اجتماعی‌بودن نوع ورزش)
                      if (_selectedKind?.isSocial == true) ...[
                        const SizedBox(height: RitmoSpacing.lg),
                        TextFormField(
                          controller: _companionsController,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontFamily: 'Vazirmatn',
                          ),
                          decoration: InputDecoration(
                            labelText: 'همراهان (اختیاری)',
                            prefixIcon: const Icon(
                              CupertinoIcons.person_2_fill,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(RitmoRadius.field),
                            ),
                          ),
                        ),
                      ],

                      // ۹. یادداشت
                      const SizedBox(height: RitmoSpacing.lg),
                      TextFormField(
                        controller: _noteController,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontFamily: 'Vazirmatn',
                        ),
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'یادداشت تمرین (اختیاری)',
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(
                            CupertinoIcons.doc_text,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(RitmoRadius.field),
                          ),
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.xl),
                    ],
                  ),
                ),
              ),

              // ── نوار پایین ──────────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(RitmoSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // نمایشگر زنده — فقط وقتی مدت وارد شده
                    if (_durationMinutes != null && _durationMinutes! > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '≈ ${_calculatedCalories.round().toPersianDigits()} کالری',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontWeight: FontWeight.bold,
                              color: accent,
                              fontSize: 13,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '·',
                              style: TextStyle(color: colors.textTertiary),
                            ),
                          ),
                          Text(
                            '${_calculatedMetMinutes.round().toPersianDigits()} بار',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (_budgetSnapshot != null &&
                              _calculatedMetMinutes > 0) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '·',
                                style: TextStyle(color: colors.textTertiary),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _buildBudgetShiftText(_budgetSnapshot!),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontWeight: FontWeight.bold,
                                  color: colors.success,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: RitmoSpacing.md),
                    ],

                    // دکمهٔ ذخیره — دلیل غیرفعال‌بودن روی خودش نوشته می‌شود
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSave ? accent : colors.disabled,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: colors.disabled,
                          disabledForegroundColor: colors.textTertiary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(RitmoRadius.card),
                          ),
                        ),
                        onPressed: canSave ? _saveLog : null,
                        child: _isSaving
                            ? const CupertinoActivityIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                blocking ?? 'ثبت و ذخیره فعالیت',
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: canSave
                                      ? Colors.white
                                      : colors.textTertiary,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),),
    );
  }

  // ── هلپرها ───────────────────────────────────────────────────────────────────────

  Widget _buildPrimaryMetricField(Color accent) {
    final kind = _selectedKind!;
    switch (kind.primaryMetric) {
      case MovementMetric.distance:
        return MovementMetricField(
          label: 'مسافت',
          unit: 'کیلومتر',
          value: _primaryMetricValue,
          onChanged: (v) => setState(() => _primaryMetricValue = v),
          icon: CupertinoIcons.arrow_right_arrow_left,
          step: 0.5,
          min: 0.1,
          max: 200,
          decimals: 1,
          quickValues: const [1, 3, 5, 10, 21.1],
          accent: accent,
        );
      case MovementMetric.laps:
        return MovementMetricField(
          label: 'تعداد طول (استخر ۲۵ متری)',
          unit: 'طول',
          value: _primaryMetricValue,
          onChanged: (v) => setState(() => _primaryMetricValue = v),
          icon: CupertinoIcons.repeat,
          step: 1,
          min: 1,
          max: 200,
          decimals: 0,
          quickValues: const [10, 20, 30, 40, 50],
          accent: accent,
        );
      case MovementMetric.elevation:
        return MovementMetricField(
          label: 'ارتفاع گرفته‌شده',
          unit: 'متر',
          value: _primaryMetricValue,
          onChanged: (v) => setState(() => _primaryMetricValue = v),
          icon: CupertinoIcons.arrow_up_right,
          step: 10,
          min: 10,
          max: 5000,
          decimals: 0,
          quickValues: const [100, 300, 500, 1000],
          accent: accent,
        );
      case MovementMetric.steps:
        return MovementMetricField(
          label: 'تعداد گام',
          unit: 'گام',
          value: _primaryMetricValue,
          onChanged: (v) => setState(() => _primaryMetricValue = v),
          icon: CupertinoIcons.arrow_right,
          step: 100,
          min: 100,
          max: 50000,
          decimals: 0,
          quickValues: const [2000, 5000, 8000, 10000],
          accent: accent,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSecondaryMetricField(Color accent) {
    final kind = _selectedKind!;
    switch (kind.secondaryMetric) {
      case MovementMetric.elevation:
        return MovementMetricField(
          label: 'ارتفاع (ثانوی)',
          unit: 'متر',
          value: _secondaryMetricValue,
          onChanged: (v) => setState(() => _secondaryMetricValue = v),
          icon: CupertinoIcons.arrow_up_right,
          step: 10,
          min: 0,
          max: 5000,
          decimals: 0,
          quickValues: const [50, 100, 300, 500],
          accent: accent,
        );
      case MovementMetric.distance:
        return MovementMetricField(
          label: 'مسافت (ثانوی)',
          unit: 'کیلومتر',
          value: _secondaryMetricValue,
          onChanged: (v) => setState(() => _secondaryMetricValue = v),
          icon: CupertinoIcons.arrow_right_arrow_left,
          step: 0.5,
          min: 0.1,
          max: 100,
          decimals: 1,
          quickValues: const [1, 3, 5, 10],
          accent: accent,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _buildBudgetShiftText(MovementBudgetSnapshot snapshot) {
    final target = snapshot.weeklyMetMinutesTarget;
    if (target <= 0) return '';
    final before =
        (snapshot.achievedMetMinutes / target * 100).round();
    final after =
        ((snapshot.achievedMetMinutes + _calculatedMetMinutes) / target * 100)
            .round();
    return 'بودجه: ${before.toPersianDigits()}٪ ← ${after.toPersianDigits()}٪';
  }
}

// ─── هلپر هدر بخش ───────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.colors);
  final String text;
  final RitmoColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Vazirmatn',
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: colors.textSecondary,
      ),
    );
  }
}
