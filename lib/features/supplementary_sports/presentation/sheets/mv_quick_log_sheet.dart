import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';
import 'mv_kind_picker_sheet.dart';

/// Sheet: Quick Log Sheet ("ثبت سریع" — Section 5.9, S1-T6 & N-01).
///
/// 1 required field (duration in minutes) with 4 quick kind presets + "بیشتر..." picker.
class MvQuickLogSheet extends StatefulWidget {
  final String initialKindCode;
  final int initialDuration;
  final MvKindUseCase? kindUseCase;
  final Future<void> Function(
    String kindCode,
    int durationMinutes,
    MvSessionFeeling? feeling,
    String? note,
  )
  onSave;

  const MvQuickLogSheet({
    super.key,
    this.initialKindCode = 'WALKING',
    this.initialDuration = 20,
    this.kindUseCase,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    String initialKindCode = 'WALKING',
    int initialDuration = 20,
    MvKindUseCase? kindUseCase,
    Future<void> Function(
      String kindCode,
      int durationMinutes,
      MvSessionFeeling? feeling,
      String? note,
    )?
    onSave,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvQuickLogSheet(
        initialKindCode: initialKindCode,
        initialDuration: initialDuration,
        kindUseCase: kindUseCase,
        onSave:
            onSave ??
            (kindCode, durationMinutes, feeling, note) async {
              await MvQuickLogUseCase().execute(
                kindCode: kindCode,
                durationMinutes: durationMinutes,
                feeling: feeling,
                note: note,
              );
            },
      ),
    );
  }

  @override
  State<MvQuickLogSheet> createState() => _MvQuickLogSheetState();
}

class _MvQuickLogSheetState extends State<MvQuickLogSheet> {
  late final MvKindUseCase _kindUseCase;
  late String _selectedKind;
  late int _duration;
  MvSessionFeeling? _feeling;
  final _noteController = TextEditingController();
  bool _isLoading = false;

  List<Map<String, String>> _quickKinds = [
    {'code': 'WALKING', 'title': 'پیاده‌روی', 'emoji': '🚶'},
    {'code': 'RUNNING', 'title': 'دویدن', 'emoji': '🏃'},
    {'code': 'CYCLING', 'title': 'دوچرخه‌سواری', 'emoji': '🚴'},
    {'code': 'SWIMMING', 'title': 'شنا', 'emoji': '🏊'},
  ];

  final List<int> _durationPresets = const [10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _kindUseCase = widget.kindUseCase ?? MvKindUseCase();
    _selectedKind = widget.initialKindCode;
    _duration = widget.initialDuration;
    _loadRecentKinds();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentKinds() async {
    try {
      final recent = await _kindUseCase.getRecentKinds(limit: 4);
      if (recent.isNotEmpty && mounted) {
        final List<Map<String, String>> items = recent
            .map((k) => {'code': k.code, 'title': k.titleFa, 'emoji': k.emoji})
            .toList();

        // If fewer than 4, fill with fallback
        const fallback = [
          {'code': 'WALKING', 'title': 'پیاده‌روی', 'emoji': '🚶'},
          {'code': 'RUNNING', 'title': 'دویدن', 'emoji': '🏃'},
          {'code': 'CYCLING', 'title': 'دوچرخه‌سواری', 'emoji': '🚴'},
          {'code': 'SWIMMING', 'title': 'شنا', 'emoji': '🏊'},
        ];

        for (final fb in fallback) {
          if (items.length >= 4) break;
          if (!items.any((it) => it['code'] == fb['code'])) {
            items.add(fb);
          }
        }

        setState(() {
          _quickKinds = items;
        });
      }
    } catch (_) {}
  }

  Future<void> _openKindPicker() async {
    List<MvMovementKind>? allKinds;
    try {
      allKinds = await _kindUseCase.getAllKinds();
    } catch (_) {}

    if (!mounted) return;

    final picked = await MvKindPickerSheet.show(
      context: context,
      useCase: _kindUseCase,
      initialCode: _selectedKind,
      initialKinds: allKinds,
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedKind = picked.code;
        if (!_quickKinds.any((k) => k['code'] == picked.code)) {
          _quickKinds = [
            {
              'code': picked.code,
              'title': picked.titleFa,
              'emoji': picked.emoji,
            },
            ..._quickKinds.take(3),
          ];
        }
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      await widget.onSave(
        _selectedKind,
        _duration,
        _feeling,
        _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return MvSheetScaffold(
      title: 'ثبت سریع فعالیت',
      subtitle: 'مدت‌زمان فعالیتت را مشخص کن تا در آمار هفتگی ثبت شود.',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Kind Selector
            Text(
              'نوع فعالیت',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),
            Wrap(
              spacing: metrics.spaceSm,
              runSpacing: metrics.spaceSm,
              children: [
                ..._quickKinds.map((k) {
                  final isSel = k['code'] == _selectedKind;
                  return MvChip(
                    key: ValueKey('kind_chip_${k['code']}'),
                    label: k['title']!,
                    icon: Text(
                      k['emoji']!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    isSelected: isSel,
                    onTap: () => setState(() => _selectedKind = k['code']!),
                  );
                }),
                // 5th Chip: "بیشتر..."
                MvChip(
                  key: const ValueKey('quick_log_more_kinds'),
                  label: 'بیشتر...',
                  icon: const Icon(Icons.apps_rounded, size: 16),
                  isSelected: false,
                  onTap: _openKindPicker,
                ),
              ],
            ),
            SizedBox(height: metrics.spaceLg),

            // 2. Duration Presets
            Text(
              'مدت‌زمان (دقیقه)',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),
            Wrap(
              spacing: metrics.spaceSm,
              runSpacing: metrics.spaceSm,
              children: _durationPresets.map((d) {
                final isSel = d == _duration;
                return MvChip(
                  key: ValueKey('duration_$d'),
                  label: '$d دقیقه',
                  isSelected: isSel,
                  onTap: () => setState(() => _duration = d),
                );
              }).toList(),
            ),
            SizedBox(height: metrics.spaceLg),

            // 3. Optional Feeling
            Text(
              'احساس چطور بود؟ (اختیاری)',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),
            Row(
              children: [
                _buildFeelingOption(
                  MvSessionFeeling.easy,
                  '😊',
                  'راحت / جا داشتم',
                ),
                SizedBox(width: metrics.spaceSm),
                _buildFeelingOption(
                  MvSessionFeeling.good,
                  '💪',
                  'خوب و متناسب',
                ),
                SizedBox(width: metrics.spaceSm),
                _buildFeelingOption(MvSessionFeeling.hard, '🥵', 'سخت و چالشی'),
              ],
            ),
            SizedBox(height: metrics.spaceLg),
          ],
        ),
      ),
      bottomAction: MvPrimaryAction(
        key: const ValueKey('quick_log_save_action'),
        label: 'ثبت فعالیت ($_duration دقیقه)',
        icon: Icons.check_circle_outline_rounded,
        isLoading: _isLoading,
        onPressed: _handleSave,
      ),
    );
  }

  Widget _buildFeelingOption(
    MvSessionFeeling feeling,
    String emoji,
    String label,
  ) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final isSelected = _feeling == feeling;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('feeling_${feeling.name}'),
          onTap: () => setState(() => _feeling = isSelected ? null : feeling),
          borderRadius: BorderRadius.circular(metrics.radiusCard),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: metrics.spaceSm,
              horizontal: 4,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.12)
                  : colors.surface,
              borderRadius: BorderRadius.circular(metrics.radiusCard),
              border: Border.all(
                color: isSelected ? colors.primary : colors.border,
              ),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                SizedBox(height: metrics.spaceXs),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: isSelected ? colors.primary : colors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
