import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
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
    int? initialDurationMinutes,
    MvKindUseCase? kindUseCase,
    VoidCallback? onSessionLogged,
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
        initialDuration: initialDurationMinutes ?? initialDuration,
        kindUseCase: kindUseCase,
        onSave: (kindCode, durationMinutes, feeling, note) async {
          if (onSave != null) {
            await onSave(kindCode, durationMinutes, feeling, note);
          } else {
            await MvQuickLogUseCase().execute(
              kindCode: kindCode,
              durationMinutes: durationMinutes,
              feeling: feeling,
              note: note,
            );
          }
          onSessionLogged?.call();
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
    {'code': 'WALKING', 'title': '', 'emoji': '🚶'},
    {'code': 'RUNNING', 'title': '', 'emoji': '🏃'},
    {'code': 'CYCLING', 'title': '', 'emoji': '🚴'},
    {'code': 'SWIMMING', 'title': '', 'emoji': '🏊'},
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
      final allKinds = await _kindUseCase.getAllKinds();
      final kindMap = {for (final k in allKinds) k.code: k};

      final recent = await _kindUseCase.getRecentKinds(limit: 4);
      final List<Map<String, String>> items = [];

      if (recent.isNotEmpty) {
        for (final k in recent) {
          items.add({'code': k.code, 'title': k.titleFa, 'emoji': k.emoji});
        }
      }

      // If fewer than 4, fill with fallback
      const fallbackCodes = [
        {'code': 'WALKING', 'emoji': '🚶'},
        {'code': 'RUNNING', 'emoji': '🏃'},
        {'code': 'CYCLING', 'emoji': '🚴'},
        {'code': 'SWIMMING', 'emoji': '🏊'},
      ];

      for (final fb in fallbackCodes) {
        if (items.length >= 4) break;
        if (!items.any((it) => it['code'] == fb['code'])) {
          final resolved = kindMap[fb['code']];
          items.add({
            'code': fb['code']!,
            'title': resolved?.titleFa ?? fb['code']!,
            'emoji': resolved?.emoji ?? fb['emoji']!,
          });
        }
      }

      if (mounted) {
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

    final selected = await MvKindPickerSheet.show(
      context: context,
      useCase: _kindUseCase,
      initialCode: _selectedKind,
      initialKinds: allKinds,
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedKind = selected.code;
        if (!_quickKinds.any((k) => k['code'] == selected.code)) {
          _quickKinds.insert(0, {
            'code': selected.code,
            'title': selected.titleFa,
            'emoji': selected.emoji,
          });
          if (_quickKinds.length > 4) {
            _quickKinds = _quickKinds.sublist(0, 4);
          }
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isLoading) return;
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

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return MvSheetScaffold(
      title: l10n.mv_quick_log_title,
      subtitle: l10n.mv_quick_log_subtitle,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Kind Selector
            Text(
              l10n.mv_quick_log_kind,
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
                    label: k['title']?.isNotEmpty == true
                        ? k['title']!
                        : k['code']!,
                    icon: Text(
                      k['emoji'] ?? '🏃',
                      style: textTheme.bodyMedium,
                    ),
                    isSelected: isSel,
                    onTap: () => setState(() => _selectedKind = k['code']!),
                  );
                }),
                // 5th Chip: "بیشتر..."
                MvChip(
                  key: const ValueKey('quick_log_more_kinds'),
                  label: l10n.mv_quick_log_more,
                  icon: Icon(Icons.apps_rounded, size: metrics.iconSm),
                  isSelected: false,
                  onTap: _openKindPicker,
                ),
              ],
            ),
            SizedBox(height: metrics.spaceLg),

            // 2. Duration Presets
            Text(
              l10n.mv_quick_log_duration,
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
                  label: l10n.mv_quick_log_duration_min(d),
                  isSelected: isSel,
                  onTap: () => setState(() => _duration = d),
                );
              }).toList(),
            ),
            SizedBox(height: metrics.spaceLg),

            // 3. Optional Feeling
            Text(
              l10n.mv_quick_log_feeling_prompt,
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
                  l10n.mv_quick_log_feeling_easy,
                ),
                SizedBox(width: metrics.spaceSm),
                _buildFeelingOption(
                  MvSessionFeeling.good,
                  '💪',
                  l10n.mv_quick_log_feeling_good,
                ),
                SizedBox(width: metrics.spaceSm),
                _buildFeelingOption(
                  MvSessionFeeling.hard,
                  '🥵',
                  l10n.mv_quick_log_feeling_hard,
                ),
              ],
            ),
            SizedBox(height: metrics.spaceLg),
          ],
        ),
      ),
      bottomAction: MvPrimaryAction(
        key: const ValueKey('quick_log_save_action'),
        label: l10n.mv_quick_log_submit(_duration),
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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final isSelected = _feeling == feeling;

    return Expanded(
      child: RitmoCard.neumorphic(
        key: ValueKey('feeling_${feeling.name}'),
        onTap: () => setState(() => _feeling = isSelected ? null : feeling),
        isSelected: isSelected,
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 4,
        ),
        child: Column(
          children: [
            Text(emoji, style: textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: isSelected ? colors.primary : colors.textSecondary,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
