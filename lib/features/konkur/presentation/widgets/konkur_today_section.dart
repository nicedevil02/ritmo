import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_color.dart';
import 'package:ritmo/core/domain/models/energy_context.dart';
import 'package:ritmo/features/konkur/logic/konkur_planner.dart';
import 'package:ritmo/features/konkur/logic/konkur_replan_service.dart';
import 'package:ritmo/features/konkur/logic/konkur_repository.dart';
import 'package:ritmo/features/konkur/models/konkur_models.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_formatters.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_study_sheet.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_today_progress_bar.dart';

class KonkurTodaySection extends StatefulWidget {
  const KonkurTodaySection({
    super.key,
    required this.subjects,
    required this.topics,
    required this.todayPlanItems,
    required this.onRefresh,
    this.energyContext,
  });

  final List<KonkurSubject> subjects;
  final List<KonkurTopic> topics;
  final List<KonkurPlanItem> todayPlanItems;
  final VoidCallback onRefresh;
  final EnergyContext? energyContext;

  @override
  State<KonkurTodaySection> createState() => _KonkurTodaySectionState();
}

class _KonkurTodaySectionState extends State<KonkurTodaySection> {
  String _energyLevel = 'MEDIUM'; // HIGH, MEDIUM, LOW
  int _daysBehindCount = 0;
  bool _isReplanning = false;

  int _todayPlannedMinutes = 0;
  int _todayActualMinutes = 0;
  int _todayCompletedItems = 0;
  int _todayTotalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadEnergyAndScheduleStats();
  }

  @override
  void didUpdateWidget(covariant KonkurTodaySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todayPlanItems.length != widget.todayPlanItems.length) {
      _loadEnergyAndScheduleStats();
    }
  }

  Future<void> _loadEnergyAndScheduleStats() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // 1. Fetch latest energy level
      final energyLogs = await db.query('energy_logs', orderBy: 'loggedAt DESC', limit: 1);
      String energy = 'MEDIUM';
      if (energyLogs.isNotEmpty) {
        energy = energyLogs.first['energyLevel'] as String? ?? 'MEDIUM';
      }

      // 2. Fetch today metrics & all plan items for daysBehind
      final repo = KonkurRepository.instance;
      final results = await Future.wait([
        repo.getTodayPlannedMinutes(),
        repo.getTodayActualMinutes(),
        repo.getTodayCompletedItemCount(),
        repo.getTodayTotalItemCount(),
        repo.getPlanItems(),
      ]);

      final plannedMins = results[0] as int;
      final actualMins = results[1] as int;
      final compCount = results[2] as int;
      final totCount = results[3] as int;
      final allPlanItems = results[4] as List<KonkurPlanItem>;

      final behind = KonkurPlanner.daysBehind(planItems: allPlanItems, today: DateTime.now());
      
      if (mounted) {
        setState(() {
          _energyLevel = energy;
          _todayPlannedMinutes = plannedMins;
          _todayActualMinutes = actualMins;
          _todayCompletedItems = compCount;
          _todayTotalItems = totCount;
          _daysBehindCount = behind;
        });
      }
    } catch (_) {}
  }

  Future<void> _quickComplete(KonkurPlanItem item) async {
    final result = await _QuickCompleteDialog.show(context);
    if (result == null) return;

    try {
      final repo = KonkurRepository.instance;
      int mins = 0;
      if (result != 'JUST_CHECK') {
        mins = int.tryParse(result) ?? 0;
      }
      if (mins < 0) mins = 0;

      if (mins > 0) {
        final session = KonkurStudySession(
          id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
          topicId: item.topicId,
          subjectId: item.subjectId,
          dateIso: DateTime.now().toIso8601String().substring(0, 10),
          durationMinutes: mins,
          note: 'ثبت سریع از صفحه داشبورد امروز کنکور',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await repo.insertStudySession(session);
      }

      await repo.updatePlanItemStatus(item.id, 'DONE');
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'جلسه مطالعه با موفقیت ثبت شد! خدا قوت 🌟',
              style: TextStyle(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در ثبت سریع: $e',
              style: const TextStyle(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _replanSchedule() async {
    setState(() {
      _isReplanning = true;
    });

    try {
      final repo = KonkurRepository.instance;
      final settings = await repo.getAppSettings();
      final examDateStr = settings['konkur_exam_date'] ?? '';

      if (examDateStr.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'لطفاً ابتدا تاریخ کنکور را در تنظیمات تعیین کنید.',
                style: TextStyle(),
              ),
            ),
          );
        }
        return;
      }

      await const KonkurReplanService().rebuildFuturePlan(
        repository: repo,
        today: DateTime.now(),
        preserveToday: true,
        preserveLocked: true,
        preserveUserEdited: true,
        energyContext: widget.energyContext,
      );
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'برنامه از فردا به روز شد — برنامه امروز دست نخورد 📅',
              style: TextStyle(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در بازچینش برنامه: $e',
              style: const TextStyle(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReplanning = false;
        });
      }
    }
  }

  void _showReasonExplanationSheet(KonkurPlanItem item, KonkurTopic topic) {
    final colors = context.colors;
    final reasonText = item.planningReason ?? 'انتخاب شده بر اساس اولویت‌بندی هوشمند الگوریتم';
    final modeLabel = switch (item.plannedMode) {
      'STUDY' => 'یادگیری مفهومی 📚',
      'TEST' => 'تمرین و تست‌زنی 📝',
      'REVIEW' => 'مرور و تثبیت 🔁',
      _ => 'مطالعه 📖',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: colors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'چرا این مبحث برنامه‌ریزی شد؟',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'مبحث: ${topic.name}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'حالت پیشنهادی: $modeLabel',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reasonText,
                  style: TextStyle(fontSize: 13, color: colors.textPrimary, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openStudySheet(KonkurTopic topic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return KonkurStudySheet(
          initialTopic: topic,
          subjects: widget.subjects,
          topics: widget.topics,
          onSaved: widget.onRefresh,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Today Planned vs Actual Progress Bar
          KonkurTodayProgressBar(
            plannedMinutes: _todayPlannedMinutes,
            actualMinutes: _todayActualMinutes,
            completedItems: _todayCompletedItems,
            totalItems: _todayTotalItems,
            colors: colors,
          ),
          const SizedBox(height: 16),

          // Quick Action Strip
          _buildQuickActionStrip(colors),
          const SizedBox(height: 16),

          // Header / Replanning card
          _buildSummaryCard(colors),
          const SizedBox(height: 16),

          // Low energy warning card
          if (_energyLevel.toUpperCase() == 'LOW') ...[
            _buildEnergyWarningCard(colors),
            const SizedBox(height: 16),
          ],

          // List of today's plan items
          if (widget.todayPlanItems.isEmpty)
            _buildEmptyState(colors)
          else ...[
            Text(
              'برنامه مطالعاتی امروز:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.todayPlanItems.length,
              itemBuilder: (context, index) {
                final item = widget.todayPlanItems[index];
                final subject = widget.subjects.firstWhere((s) => s.id == item.subjectId);
                final topic = widget.topics.firstWhere((t) => t.id == item.topicId);
                return _buildPlanItemRow(item, subject, topic, colors);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(RitmoColors colors) {
    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.todayPlanItems.isEmpty
                      ? 'امروز برنامه مطالعاتی ندارید'
                      : 'برنامه امروز شما شامل ${toPersianDigits(widget.todayPlanItems.length)} مبحث است',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (_daysBehindCount > 0)
                  Text(
                    '${toPersianDigits(_daysBehindCount)} مبحث از برنامه‌ عقب هستید! ⚠️',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    'کاملاً طبق برنامه پیش می‌روید. عالیه! 🌟',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isReplanning ? null : _replanSchedule,
            icon: const Icon(Icons.shuffle, size: 16, color: Colors.white),
            label: _isReplanning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                  )
                : const Text(
                    'بازچینش برنامه',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyWarningCard(RitmoColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.battery_alert, color: colors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'انرژی شما پایین است؛ برای جلوگیری از خستگی مفرط پیشنهاد می‌کنیم مباحث سبک‌تر را مطالعه کنید 🌿',
              style: TextStyle(
                fontSize: 11,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(RitmoColors colors) {
    return RitmoCard.neumorphic(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.eco, size: 44, color: Colors.green),
            const SizedBox(height: 14),
            Text(
              'امروز برنامه‌ای نیست — یه مبحث انتخاب کن 🌿',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanItemRow(
    KonkurPlanItem item,
    KonkurSubject subject,
    KonkurTopic topic,
    RitmoColors colors,
  ) {
    return RitmoCard.neumorphic(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: RitmoColor.fromHex(
                            subject.colorHex,
                            fallback: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          subject.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showReasonExplanationSheet(item, topic),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.help_outline, size: 11, color: colors.primary),
                              const SizedBox(width: 2),
                              Text(
                                'چرا این؟',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topic.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'زمان برنامه‌ریزی شده: ${formatDuration(item.plannedMinutes)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openStudySheet(topic),
                  icon: Icon(Icons.play_arrow, size: 14, color: colors.onPrimary),
                  label: const Text(
                    'شروع',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () => _quickComplete(item),
                  icon: Icon(Icons.check, size: 14, color: colors.success),
                  label: Text(
                    'انجام',
                    style: TextStyle(fontSize: 11, color: colors.success, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    side: BorderSide(color: colors.success),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildQuickActionStrip(RitmoColors colors) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (ctx) => KonkurStudySheet(
                  subjects: widget.subjects,
                  topics: widget.topics,
                  onSaved: widget.onRefresh,
                  initialMode: 'STUDY',
                ),
              );
            },
            icon: const Icon(Icons.play_circle_fill, size: 16),
            label: const Text('+ مطالعه', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (ctx) => KonkurStudySheet(
                  subjects: widget.subjects,
                  topics: widget.topics,
                  onSaved: widget.onRefresh,
                  initialMode: 'TEST',
                ),
              );
            },
            icon: const Icon(Icons.assignment_turned_in, size: 16),
            label: const Text('+ آزمون', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber.shade900,
              padding: const EdgeInsets.symmetric(vertical: 8),
              side: BorderSide(color: Colors.amber.shade700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isReplanning ? null : _replanSchedule,
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: Text(_isReplanning ? 'تنظیم...' : '⚡ بازتنظیم', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _QuickCompleteDialog extends StatefulWidget {
  const _QuickCompleteDialog();

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const _QuickCompleteDialog(),
    );
  }

  @override
  State<_QuickCompleteDialog> createState() => _QuickCompleteDialogState();
}

class _QuickCompleteDialogState extends State<_QuickCompleteDialog> {
  late final TextEditingController _minutesController;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RitmoCustomDialog(
      title: 'ثبت سریع',
      icon: Icons.timer_outlined,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'چند دقیقه واقعاً مطالعه کردی؟',
            style: TextStyle(
              fontSize: 13.5,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'زمان واقعی مطالعه (دقیقه)',
              hintText: '0',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            style: TextStyle(color: colors.textPrimary),
            onSubmitted: (val) => Navigator.pop(context, val.trim()),
          ),
        ],
      ),
      actions: [
        RitmoSecondaryButton(
          label: 'فقط تیک بزن',
          onPressed: () => Navigator.pop(context, 'JUST_CHECK'),
        ),
        const SizedBox(width: 10),
        RitmoPrimaryButton(
          label: 'ثبت زمان و تیک',
          onPressed: () => Navigator.pop(context, _minutesController.text.trim()),
        ),
      ],
    );
  }
}

