import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';

/// Smart Unified Sheet: "برنامه‌ریزی و ساخت دورهٔ تمرینی هدف‌دار"
/// Merges sport kind selection, periodization timeline, physical metrics,
/// and live smart phase calculations into a single fluid Apple HIG sheet with zero nested modals.
class MvCreateCampaignSheet extends StatefulWidget {
  final ValueChanged<MvCampaign> onCreate;
  final MvKindUseCase? kindUseCase;

  const MvCreateCampaignSheet({
    super.key,
    required this.onCreate,
    this.kindUseCase,
  });

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<MvCampaign> onCreate,
    MvKindUseCase? kindUseCase,
  }) {
    return MvSheetScaffold.show(
      context: context,
      initialChildSize: 0.90,
      maxChildSize: 0.96,
      builder: (ctx) => MvCreateCampaignSheet(
        onCreate: onCreate,
        kindUseCase: kindUseCase,
      ),
    );
  }

  @override
  State<MvCreateCampaignSheet> createState() => _MvCreateCampaignSheetState();
}

class _MvCreateCampaignSheetState extends State<MvCreateCampaignSheet> {
  late final MvKindUseCase _kindUseCase;
  final _searchController = TextEditingController();
  final _weightController = TextEditingController(text: '75');
  final _packWeightController = TextEditingController(text: '5');

  DateTime _targetDate = DateTime.now().add(const Duration(days: 84)); // 12 weeks
  String _selectedKindCode = MvKindCodes.hiking;
  String _selectedKindTitleFa = 'کوهنوردی و پیمایش';
  String _selectedKindEmoji = '🏔️';
  bool _isOutdoorOrHiking = true;

  bool _isSearching = false;
  List<MvMovementKind> _allKinds = [];
  List<MvMovementKind> _filteredKinds = [];
  Timer? _debounceTimer;
  String? _errorMessage;

  // Prominent Campaign Goal Sports
  static const List<Map<String, String>> _featuredGoalSports = [
    {'code': MvKindCodes.hiking, 'title': 'کوهنوردی و پیمایش', 'emoji': '🏔️'},
    {'code': MvKindCodes.running, 'title': 'دویدن و ماراتن', 'emoji': '🏃'},
    {'code': MvKindCodes.cycling, 'title': 'دوچرخه‌سواری', 'emoji': '🚴'},
    {'code': MvKindCodes.swimming, 'title': 'شنا و سه‌گانه', 'emoji': '🏊'},
    {'code': 'CLIMBING', 'title': 'سنگ‌نوردی', 'emoji': '🧗'},
    {'code': MvKindCodes.football, 'title': 'فوتبال و تیمی', 'emoji': '⚽'},
    {'code': 'MARTIAL_ARTS', 'title': 'هنرهای رزمی', 'emoji': '🥋'},
    {'code': MvKindCodes.bodyweight, 'title': 'بدنسازی و قدرت', 'emoji': '🏋️'},
  ];

  // Timeline Preset Weeks
  static const List<int> _timelinePresets = [8, 12, 16, 24];

  @override
  void initState() {
    super.initState();
    _kindUseCase = widget.kindUseCase ?? MvKindUseCase();
    _loadAllKinds();
  }

  Future<void> _loadAllKinds() async {
    final kinds = await _kindUseCase.getAllKinds();
    if (mounted) {
      setState(() {
        _allKinds = kinds;
        _filteredKinds = kinds;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _weightController.dispose();
    _packWeightController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final q = query.trim().toLowerCase();
      setState(() {
        if (q.isEmpty) {
          _filteredKinds = _allKinds;
        } else {
          _filteredKinds = _allKinds
              .where((k) =>
                  k.titleFa.toLowerCase().contains(q) ||
                  k.code.toLowerCase().contains(q))
              .toList();
        }
      });
    });
  }

  void _selectSport(String code, String titleFa, String emoji) {
    setState(() {
      _selectedKindCode = code;
      _selectedKindTitleFa = titleFa;
      _selectedKindEmoji = emoji;
      _isOutdoorOrHiking = code == MvKindCodes.hiking ||
          code == 'CLIMBING' ||
          code == 'TRAIL_RUNNING' ||
          code.contains('OUTDOOR');
      _isSearching = false;
      _searchController.clear();
      _errorMessage = null;
    });
  }

  void _setPresetWeeks(int weeks) {
    setState(() {
      _targetDate = DateTime.now().add(Duration(days: weeks * 7));
      _errorMessage = null;
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final days = _targetDate.difference(DateTime.now()).inDays;
    final weeks = (days / 7).round();

    if (weeks < 4) {
      setState(() {
        _errorMessage = l10n?.mv_campaign_too_short ??
            'مدت زمان باقی‌مانده تا رویداد باید حداقل ۴ هفته باشد.';
      });
      return;
    }

    final now = DateTime.now();
    final campaign = MvCampaign(
      id: 'camp_${now.millisecondsSinceEpoch}',
      titleFa: l10n?.mv_campaign_hiking_title(_selectedKindCode) ??
          'دورهٔ هدف‌دار: $_selectedKindTitleFa',
      goalCode: _selectedKindCode,
      startDate: MvCalendar.formatDateIso(now),
      weeks: weeks,
      status: 'ACTIVE',
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    widget.onCreate(campaign);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final days = _targetDate.difference(DateTime.now()).inDays;
    final totalWeeks = (days ~/ 7).clamp(1, 52);

    // Calculated Periodization Phases
    final baseWeeks = (totalWeeks * 0.35).round().clamp(1, totalWeeks);
    final buildWeeks = (totalWeeks * 0.40).round().clamp(1, totalWeeks);
    final peakWeeks = (totalWeeks - baseWeeks - buildWeeks).clamp(1, totalWeeks);

    return MvSheetScaffold(
      title: 'برنامه‌ریزی و ساخت دورهٔ تمرینی',
      subtitle: 'طراحی هوشمند بار تمرینی و فازبندی معکوس تا روز رویداد',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── بخش ۱: انتخاب رشتهٔ هدف ورزشی ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '۱. رشتهٔ ورزشی رویداد هدف',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isSearching = !_isSearching),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSearching ? Icons.close_rounded : Icons.search_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSearching ? 'بستن جستجو' : 'سایر رشته‌ها...',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Search Box (if searching)
          if (_isSearching) ...[
            RitmoNeuSurface(
              sunken: true,
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'جستجوی نام ورزش (مثلاً اسکواش، پیلاتس، دوچرخه...)',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _filteredKinds.map((k) {
                    final isSel = k.code == _selectedKindCode;
                    return RitmoNeuSurface(
                      sunken: isSel,
                      radius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      onTap: () => _selectSport(k.code, k.titleFa, k.emoji),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(k.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            k.titleFa,
                            style: textTheme.labelSmall?.copyWith(
                              color: isSel ? colors.primary : colors.textPrimary,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            // Quick Featured Sports Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _featuredGoalSports.map((item) {
                final isSel = item['code'] == _selectedKindCode;
                return RitmoNeuSurface(
                  sunken: isSel,
                  radius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  onTap: () => _selectSport(
                    item['code']!,
                    item['title']!,
                    item['emoji']!,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item['emoji']!, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        item['title']!,
                        style: textTheme.labelMedium?.copyWith(
                          color: isSel ? colors.primary : colors.textPrimary,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      if (isSel) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle_rounded, size: 16, color: colors.primary),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),

          // ── بخش ۲: زمان‌بندی و تاریخ رویداد هدف ──────────────────────────────────
          Text(
            '۲. مدت زمان و تاریخ رویداد هدف',
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),

          // Preset Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _timelinePresets.map((w) {
              final isSel = totalWeeks == w;
              return RitmoNeuSurface(
                sunken: isSel,
                radius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onTap: () => _setPresetWeeks(w),
                child: Text(
                  '${toPersianDigits(w.toString())} هفته (${toPersianDigits((w ~/ 4).toString())} ماه)',
                  style: textTheme.labelMedium?.copyWith(
                    color: isSel ? colors.primary : colors.textSecondary,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Custom Date Picker Card
          RitmoNeuSurface(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate,
                firstDate: DateTime.now().add(const Duration(days: 28)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _targetDate = picked;
                  _errorMessage = null;
                });
              }
            },
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${toPersianDigits(totalWeeks.toString())} هفته باقی‌مانده (تاریخ هدف: ${toPersianDigits(MvCalendar.formatDateIso(_targetDate))})',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.edit_calendar_rounded, size: 18, color: colors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── بخش ۳: مشخصات بدنی و بار تمرینی ─────────────────────────────────────
          Text(
            '۳. پارامترهای فیزیکی',
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // وزن بدن
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وزن بدن (کیلوگرم)',
                      style: textTheme.labelSmall?.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    RitmoNeuSurface(
                      sunken: true,
                      radius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '75',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isOutdoorOrHiking) ...[
                const SizedBox(width: 12),
                // وزن کوله هدف
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'وزن کوله هدف (کیلوگرم)',
                        style: textTheme.labelSmall?.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      RitmoNeuSurface(
                        sunken: true,
                        radius: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: TextField(
                          controller: _packWeightController,
                          keyboardType: TextInputType.number,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: '5',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ── بخش ۴: پیش‌نمایش هوشمند فازبندی دوره ──────────────────────────────────
          Text(
            '۴. فازبندی هوشمند دوره (${toPersianDigits(totalWeeks.toString())} هفته)',
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          RitmoNeuSurface(
            sunken: true,
            radius: 14,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildPhaseSegment(
                      label: 'فاز پایه',
                      weeks: baseWeeks,
                      color: colors.primary,
                      flex: baseWeeks,
                    ),
                    const SizedBox(width: 4),
                    _buildPhaseSegment(
                      label: 'فاز ساخت',
                      weeks: buildWeeks,
                      color: colors.accent,
                      flex: buildWeeks,
                    ),
                    const SizedBox(width: 4),
                    _buildPhaseSegment(
                      label: 'اوج و تیپر',
                      weeks: peakWeeks,
                      color: colors.success,
                      flex: peakWeeks,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'فازبندی معکوس شامل ایجاد ظرفیت هوازی پایه، شبیه‌سازی شیب و بار، و ۲ هفته کاهش حجم نهایی برای ریکاوری است.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
      bottomAction: MvPrimaryAction(
        label: 'ثبت و شروع دورهٔ هدف‌دار ($_selectedKindEmoji $_selectedKindTitleFa)',
        icon: Icons.rocket_launch_rounded,
        onPressed: _submit,
      ),
    );
  }

  Widget _buildPhaseSegment({
    required String label,
    required int weeks,
    required Color color,
    required int flex,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${toPersianDigits(weeks.toString())} هـ',
              style: textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
