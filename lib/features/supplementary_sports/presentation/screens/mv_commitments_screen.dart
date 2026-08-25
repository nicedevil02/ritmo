import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import '../sheets/mv_commitment_edit_sheet.dart';

/// Screen: مدیریت ورزش‌های ثابت و لنگرهای هفتگی (S8-T3 & Decision W-A).
class MvCommitmentsScreen extends StatefulWidget {
  final MvCommitmentRepository? commitmentRepo;
  final MvKindRepository? kindRepo;
  final MvHubController? controller;

  const MvCommitmentsScreen({
    super.key,
    this.commitmentRepo,
    this.kindRepo,
    this.controller,
  });

  @override
  State<MvCommitmentsScreen> createState() => _MvCommitmentsScreenState();
}

class _MvCommitmentsScreenState extends State<MvCommitmentsScreen> {
  late final MvCommitmentRepository _commitmentRepo;
  late final MvKindRepository _kindRepo;

  List<MvCommitment> _commitments = [];
  Map<String, MvMovementKind> _kindsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _commitmentRepo = widget.commitmentRepo ?? MvCommitmentRepositoryImpl();
    _kindRepo = widget.kindRepo ?? MvKindRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await _commitmentRepo.getAll(onlyActive: false);
    final allKinds = await _kindRepo.getAll();
    if (!mounted) return;

    setState(() {
      _commitments = list;
      _kindsMap = {for (final k in allKinds) k.code: k};
      _isLoading = false;
    });
  }

  String _dayLabel(int sat0) {
    switch (sat0) {
      case 0:
        return 'شنبه';
      case 1:
        return 'یکشنبه';
      case 2:
        return 'دوشنبه';
      case 3:
        return 'سه‌شنبه';
      case 4:
        return 'چهارشنبه';
      case 5:
        return 'پنجشنبه';
      case 6:
        return 'جمعه';
      default:
        return '';
    }
  }

  Future<void> _openEditSheet([MvCommitment? commitment]) async {
    await MvCommitmentEditSheet.show(
      context: context,
      commitment: commitment,
      onSave: (saved) async {
        if (widget.controller != null) {
          await widget.controller!.saveCommitment(saved);
        } else {
          await _commitmentRepo.upsert(saved);
        }
        await _loadData();
      },
      onDelete: (id) async {
        if (widget.controller != null) {
          await widget.controller!.deleteCommitment(id);
        } else {
          await _commitmentRepo.delete(id);
        }
        await _loadData();
      },
    );
  }

  Future<void> _toggleActive(MvCommitment commitment, bool active) async {
    await _commitmentRepo.toggleActive(commitment.id!, active);
    if (widget.controller != null) {
      await widget.controller!.loadAllData();
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          l10n.mv_commitments_title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('mv_add_commitment_fab'),
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        onPressed: () => _openEditSheet(),
        child: Icon(Icons.add, size: metrics.iconMd),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _commitments.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(metrics.spaceLg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MvInsufficientData(
                        title: l10n.mv_commitments_title,
                        requirementDescription: l10n.mv_commitments_empty,
                      ),
                      SizedBox(height: metrics.spaceLg),
                      ElevatedButton.icon(
                        key: const ValueKey('mv_add_commitment_empty_btn'),
                        icon: Icon(Icons.add, size: metrics.iconSm),
                        label: Text(l10n.mv_commitment_add),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: metrics.spaceLg,
                            vertical: metrics.spaceSm,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(metrics.radiusCard),
                          ),
                        ),
                        onPressed: () => _openEditSheet(),
                      ),
                    ],
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

                    return InkWell(
                      key: ValueKey('mv_commitment_card_${c.id}'),
                      onTap: () => _openEditSheet(c),
                      borderRadius: BorderRadius.circular(metrics.radiusCard),
                      child: Container(
                        padding: EdgeInsets.all(metrics.spaceMd),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius:
                              BorderRadius.circular(metrics.radiusCard),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                emoji,
                                style: textTheme.titleMedium,
                              ),
                            ),
                            SizedBox(width: metrics.spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.titleFa ?? 'ورزش',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: metrics.spaceXs),
                                  Text(
                                    'هر ${_dayLabel(c.dayOfWeekSat0)} ساعت ${c.startTime} • ${c.durationMinutes} دقیقه',
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
                      ),
                    );
                  },
                ),
    );
  }
}
