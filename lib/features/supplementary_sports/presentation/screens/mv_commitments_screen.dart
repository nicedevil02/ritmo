import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../sheets/mv_commitment_edit_sheet.dart';

/// Screen: مدیریت ورزش‌های ثابت و لنگرهای هفتگی (S8-T3 & Decision W-A).
class MvCommitmentsScreen extends StatefulWidget {
  final MvCommitmentUseCase? commitmentUseCase;
  final MvKindUseCase? kindUseCase;
  final MvHubController? controller;

  const MvCommitmentsScreen({
    super.key,
    this.commitmentUseCase,
    this.kindUseCase,
    this.controller,
  });

  @override
  State<MvCommitmentsScreen> createState() => _MvCommitmentsScreenState();
}

class _MvCommitmentsScreenState extends State<MvCommitmentsScreen> {
  late final MvCommitmentUseCase _commitmentUseCase;
  late final MvKindUseCase _kindUseCase;

  List<MvCommitment> _commitments = [];
  Map<String, MvMovementKind> _kindsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _commitmentUseCase = widget.commitmentUseCase ??
        (widget.controller != null
            ? MvCommitmentUseCase(widget.controller!.commitmentRepo)
            : MvCommitmentUseCase());
    _kindUseCase = widget.kindUseCase ??
        (widget.controller != null
            ? MvKindUseCase(widget.controller!.kindRepo)
            : MvKindUseCase());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _commitmentUseCase.getAllCommitments(onlyActive: false);
      final allKinds = await _kindUseCase.getAllKinds();
      if (!mounted) return;

      setState(() {
        _commitments = list;
        _kindsMap = {for (final k in allKinds) k.code: k};
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _dayLabel(int sat0) => MvCalendar.persianWeekdayName(sat0);

  Future<void> _openEditSheet([MvCommitment? commitment]) async {
    await MvCommitmentEditSheet.show(
      context: context,
      commitment: commitment,
      kindUseCase: _kindUseCase,
      onSave: (saved) async {
        if (widget.controller != null) {
          await widget.controller!.saveCommitment(saved);
        } else {
          await _commitmentUseCase.saveCommitment(saved);
        }
        await _loadData();
      },
      onDelete: (id) async {
        if (widget.controller != null) {
          await widget.controller!.deleteCommitment(id);
        } else {
          await _commitmentUseCase.deleteCommitment(id);
        }
        await _loadData();
      },
    );
  }

  Future<void> _toggleActive(MvCommitment commitment, bool active) async {
    if (widget.controller != null) {
      await widget.controller!.toggleCommitmentActive(commitment.id!, active);
    } else {
      await _commitmentUseCase.toggleCommitmentActive(commitment.id!, active);
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg, vertical: metrics.spaceSm),
                child: RitmoGlassHeader(
                  borderRadius: BorderRadius.circular(22),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        l10n.mv_commitments_title,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        key: const ValueKey('mv_commitments_add_btn'),
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () => _openEditSheet(),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _commitments.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: RitmoNeuEmptyCard(
                                icon: Icons.lock_clock_outlined,
                                title: l10n.mv_commitments_title,
                                subtitle: l10n.mv_commitments_empty,
                                actionLabel: l10n.mv_commitment_add,
                                onActionTap: () => _openEditSheet(),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.all(metrics.spaceMd),
                            itemCount: _commitments.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: metrics.spaceSm),
                            itemBuilder: (context, index) {
                              final c = _commitments[index];
                              final kind = _kindsMap[c.kindCode];
                              final emoji = kind?.emoji ?? '🏃';

                              return RitmoCard.neumorphic(
                                key: ValueKey('mv_commitment_card_${c.id}'),
                                onTap: () => _openEditSheet(c),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    RitmoNeuSurface(
                                      width: 44,
                                      height: 44,
                                      radius: 12,
                                      padding: EdgeInsets.zero,
                                      child: Center(
                                        child: Text(
                                          emoji,
                                          style: textTheme.titleMedium,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.titleFa ?? l10n.mv_exercise_fallback,
                                            style: textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l10n.mv_commitment_recurrence_summary(
                                              _dayLabel(c.dayOfWeekSat0),
                                              toPersianDigits(c.startTime),
                                              toPersianDigits(c.durationMinutes.toString()),
                                            ),
                                            style: textTheme.bodySmall?.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      key: ValueKey('mv_commitment_switch_${c.id}'),
                                      value: c.isActive,
                                      activeTrackColor: colors.accent,
                                      onChanged: (val) => _toggleActive(c, val),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
