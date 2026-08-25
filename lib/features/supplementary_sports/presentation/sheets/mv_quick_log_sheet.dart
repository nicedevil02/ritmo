import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Sheet 2: Quick Log Sheet ("ثبت سریع" — Section 5.9 & N-01).
/// 1 required field (duration in minutes) with preset chips.
class MvQuickLogSheet extends StatefulWidget {
  final String initialKindCode;
  final int initialDuration;
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
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    String initialKindCode = 'WALKING',
    int initialDuration = 20,
    required Future<void> Function(
      String kindCode,
      int durationMinutes,
      MvSessionFeeling? feeling,
      String? note,
    )
    onSave,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvQuickLogSheet(
        initialKindCode: initialKindCode,
        initialDuration: initialDuration,
        onSave: onSave,
      ),
    );
  }

  @override
  State<MvQuickLogSheet> createState() => _MvQuickLogSheetState();
}

class _MvQuickLogSheetState extends State<MvQuickLogSheet> {
  late String _selectedKind;
  late int _duration;
  MvSessionFeeling? _feeling;
  final _noteController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _quickKinds = const [
    {'code': 'WALKING', 'title': 'پیاده‌روی', 'emoji': '🚶'},
    {'code': 'RUNNING', 'title': 'دویدن', 'emoji': '🏃'},
    {'code': 'CYCLING', 'title': 'دوچرخه‌سواری', 'emoji': '🚴'},
    {'code': 'BODYWEIGHT', 'title': 'تمرین خانگی', 'emoji': '🏋️'},
    {'code': 'FOOTBALL', 'title': 'فوتبال / تیمی', 'emoji': '⚽'},
    {'code': 'STRETCHING', 'title': 'کشش و یوگا', 'emoji': '🧘'},
  ];

  final List<int> _durationPresets = const [10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.initialKindCode;
    _duration = widget.initialDuration;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
              children: _quickKinds.map((k) {
                final isSel = k['code'] == _selectedKind;
                return MvChip(
                  label: k['title'] as String,
                  icon: Text(
                    k['emoji'] as String,
                    style: const TextStyle(fontSize: 14),
                  ),
                  isSelected: isSel,
                  onTap: () =>
                      setState(() => _selectedKind = k['code'] as String),
                );
              }).toList(),
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
