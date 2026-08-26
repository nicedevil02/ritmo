import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/notes/presentation/widgets/module_note_history.dart';
import 'package:ritmo/features/study/data/study_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:ritmo/features/study/domain/study_review_policy.dart';
import 'package:ritmo/features/study/domain/study_stats.dart';
import 'package:ritmo/features/study/presentation/widgets/bulk_topics_sheet.dart';
import 'package:ritmo/features/study/presentation/widgets/session_timer_sheet.dart';
import 'package:ritmo/features/study/presentation/widgets/study_deadlines_section.dart';
import 'package:uuid/uuid.dart';

class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({super.key, required this.subject});

  final StudySubject subject;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StudyTopic> _topics = [];
  List<StudyDeadline> _deadlines = [];
  SubjectStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final topics = await StudyRepository.instance.getTopics(subjectId: widget.subject.id);
      final deadlines = await StudyRepository.instance.getDeadlines(subjectId: widget.subject.id, includeCompleted: true);
      final allStats = await StudyRepository.instance.getAggregatedSubjectStats();
      if (mounted) {
        setState(() {
          _topics = topics;
          _deadlines = deadlines;
          _stats = allStats[widget.subject.id];
        });
      }
    } catch (e, st) {
      debugPrint('[SubjectDetailScreen] Error loading data: $e\n$st');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTopicSingle() async {
    final controller = TextEditingController();
    String? name;
    try {
      name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('افزودن سرفصل جدید', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'نام سرفصل'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: ctx.colors.primary),
              child: const Text('افزودن', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }

    if (name != null && name.isNotEmpty) {
      try {
        final topic = StudyTopic(
          id: const Uuid().v4(),
          subjectId: widget.subject.id,
          name: name,
          orderIndex: _topics.length,
        );
        await StudyRepository.instance.saveTopic(topic);
        await _loadAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  Future<void> _addBulkTopics() async {
    final bulkList = await BulkTopicsSheet.show(context, subjectId: widget.subject.id);
    if (bulkList != null && bulkList.isNotEmpty) {
      try {
        await StudyRepository.instance.saveTopicsBulk(bulkList);
        await _loadAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در ذخیره سرفصل‌ها: $e')),
          );
        }
      }
    }
  }

  Future<void> _advanceMastery(StudyTopic topic) async {
    StudyMastery next;
    int nextReviewCount;
    String? nextReviewDate = topic.nextReviewDateIso;

    if (topic.mastery == StudyMastery.mastered) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('بازنشانی وضعیت تسلط', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('آیا می‌خواهید وضعیت تسلط سرفصل «${topic.name}» به حالت اولیه بازگردد؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: ctx.colors.error),
              child: const Text('بازنشانی', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      next = StudyMastery.notStarted;
      nextReviewCount = 0;
      nextReviewDate = null;
    } else {
      final res = StudyReviewPolicy.evaluate(
        feedback: SessionFeedback.understood,
        currentMastery: topic.mastery,
        reviewCount: topic.reviewCount,
      );
      next = res.nextMastery;
      nextReviewCount = topic.reviewCount + 1;
      final nextDt = DateTime.now().add(Duration(days: res.nextReviewDays));
      nextReviewDate = RitmoDate.dayKey(nextDt);
    }

    final updated = topic.copyWith(
      mastery: next,
      reviewCount: nextReviewCount,
      nextReviewDateIso: nextReviewDate,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    await StudyRepository.instance.saveTopic(updated);
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final totalMinutes = _stats?.totalMinutes ?? 0;
    final totalTests = _stats?.totalTests ?? 0;
    final accuracy = _stats?.accuracyPercentage ?? 0.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.subject.emoji ?? '📚'} ${widget.subject.name}', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
          backgroundColor: colors.surface,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'سرفصل‌ها و مطالعه'),
              Tab(text: 'امتحانات و ددلاین‌ها'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Topics & Stats
                  CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Stats Overview Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text('${RitmoNumber.faInt(totalMinutes)} دقیقه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.primary)),
                                        const SizedBox(height: 2),
                                        Text('مجموع مطالعه', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                      ],
                                    ),
                                    Container(width: 1, height: 32, color: colors.border.withValues(alpha: 0.5)),
                                    Column(
                                      children: [
                                        Text('${RitmoNumber.faInt(totalTests)} تست', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.primary)),
                                        const SizedBox(height: 2),
                                        Text('تست‌های حل‌شده', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                      ],
                                    ),
                                    Container(width: 1, height: 32, color: colors.border.withValues(alpha: 0.5)),
                                    Column(
                                      children: [
                                        Text(RitmoNumber.faPercent(accuracy), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.success)),
                                        const SizedBox(height: 2),
                                        Text('درصد دقت', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _addTopicSingle,
                                      icon: const Icon(Icons.add, color: Colors.white),
                                      label: const Text('افزودن سرفصل', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(backgroundColor: colors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _addBulkTopics,
                                      icon: Icon(Icons.playlist_add, color: colors.primary),
                                      label: Text('افزودن دسته‌جمعی', style: TextStyle(color: colors.primary)),
                                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_topics.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      'هنوز هیچ سرفصلی برای این درس ثبت نشده است.',
                                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_topics.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList.builder(
                            itemCount: _topics.length,
                            itemBuilder: (context, index) {
                              final topic = _topics[index];
                              return _buildTopicTile(topic);
                            },
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              Text('یادداشت‌های این درس', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                              const SizedBox(height: 8),
                              ModuleNoteHistorySection(module: 'study', entityId: widget.subject.id),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Tab 2: Deadlines & Exams
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      StudyDeadlinesSection(
                        deadlines: _deadlines.where((d) => !d.isCompleted).toList(),
                        subjects: [widget.subject],
                        onChanged: _loadAll,
                      ),
                      if (_deadlines.any((d) => d.isCompleted)) ...[
                        const SizedBox(height: 24),
                        Text('موارد انجام‌شده', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textSecondary)),
                        const SizedBox(height: 8),
                        ..._deadlines.where((d) => d.isCompleted).map((d) {
                          return ListTile(
                            leading: Icon(Icons.check_circle, color: colors.success, size: 20),
                            title: Text(d.title, style: TextStyle(decoration: TextDecoration.lineThrough, color: colors.textSecondary, fontSize: 13)),
                            subtitle: Text(StudyDate.formatRelative(d.dueDateIso), style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () async {
                                await StudyRepository.instance.deleteDeadline(d.id);
                                await _loadAll();
                              },
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopicTile(StudyTopic topic) {
    final colors = context.colors;
    String chipLabel;
    Color chipColor;

    switch (topic.mastery) {
      case StudyMastery.notStarted:
        chipLabel = '⚪ نخوانده';
        chipColor = colors.textSecondary;
        break;
      case StudyMastery.learning:
        chipLabel = '🔵 در حال یادگیری';
        chipColor = colors.primary;
        break;
      case StudyMastery.review:
        chipLabel = '🟡 نیاز به مرور';
        chipColor = colors.warning;
        break;
      case StudyMastery.mastered:
        chipLabel = '🟢 مسلط';
        chipColor = colors.success;
        break;
    }

    final lastStudiedText = topic.lastStudiedAtMs != null
        ? StudyDate.formatRelative(RitmoDate.dayKey(DateTime.fromMillisecondsSinceEpoch(topic.lastStudiedAtMs!)))
        : 'هرگز';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${RitmoNumber.faInt(topic.studyCompletedMinutes)} دقیقه مطالعه · آخرین بار: $lastStudiedText',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _advanceMastery(topic),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(chipLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: chipColor)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.play_circle_fill, color: colors.primary, size: 28),
            onPressed: () async {
              await SessionTimerSheet.show(context, subject: widget.subject, topic: topic);
              await _loadAll();
            },
          ),
        ],
      ),
    );
  }
}
