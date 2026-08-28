import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/study/data/study_repository.dart';
import 'package:ritmo/features/study/data/study_settings_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:ritmo/features/study/domain/study_planner.dart';
import 'package:ritmo/features/study/domain/study_stats.dart';
import 'package:ritmo/features/study/domain/study_validation.dart';
import 'package:ritmo/features/study/presentation/study_settings_sheet.dart';
import 'package:ritmo/features/study/presentation/subject_detail_screen.dart';
import 'package:ritmo/features/study/presentation/widgets/manual_session_sheet.dart';
import 'package:ritmo/features/study/presentation/widgets/session_timer_sheet.dart';
import 'package:ritmo/features/study/presentation/widgets/study_deadlines_section.dart';
import 'package:ritmo/features/study/presentation/widgets/study_week_heatmap.dart';
import 'package:ritmo/features/study/study_module_entry.dart';
import 'package:uuid/uuid.dart';

class StudyHomeScreen extends StatefulWidget {
  const StudyHomeScreen({super.key});

  @override
  State<StudyHomeScreen> createState() => _StudyHomeScreenState();
}

class _StudyHomeScreenState extends State<StudyHomeScreen> {
  StudySettings? _settings;
  List<StudySubject> _subjects = [];
  List<StudySession> _todaySessions = [];
  List<StudyDeadline> _upcomingDeadlines = [];
  Map<String, SubjectStats> _subjectStats = {};
  Map<String, int> _weeklyHeatmapData = {};
  StudyRecommendation? _topRecommendation;
  bool _isLoading = true;
  String? _errorMessage;
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollOffset.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final settings = await StudySettingsRepository.instance.load();
      final isKonkur = settings.konkurMode;
      final subjects = await StudyRepository.instance.getSubjects(isKonkurMode: isKonkur);
      final topics = await StudyRepository.instance.getTopics(isKonkurMode: isKonkur);
      final deadlines = await StudyRepository.instance.getUpcomingDeadlines(daysLimit: 30);

      final todayIso = RitmoDate.dayKey(DateTime.now());
      final todaySessions = await StudyRepository.instance.getSessions(dateIso: todayIso);
      final allSessions = await StudyRepository.instance.getSessions(limit: 500);

      final stats = await StudyRepository.instance.getAggregatedSubjectStats();

      final recs = StudyPlanner.evaluate(
        subjects: subjects,
        topics: topics,
        todaySessions: todaySessions,
        today: DateTime.now(),
        dailyCapacityMinutes: settings.dailyTargetMinutes,
        reviewEnabled: settings.reviewEnabled,
      );

      final heatmapData = <String, int>{};
      for (final s in allSessions) {
        heatmapData[s.dateIso] = (heatmapData[s.dateIso] ?? 0) + s.durationMinutes;
      }

      if (mounted) {
        setState(() {
          _settings = settings;
          _subjects = subjects;
          _todaySessions = todaySessions;
          _upcomingDeadlines = deadlines;
          _subjectStats = stats;
          _weeklyHeatmapData = heatmapData;
          _topRecommendation = recs.isNotEmpty ? recs.first : null;
        });
      }
    } catch (e, st) {
      debugPrint('[StudyHomeScreen] Error loading study data: $e\n$st');
      if (mounted) {
        setState(() {
          _errorMessage = 'خطا در بارگذاری داده‌های مطالعه. لطفاً دوباره تلاش کنید.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addSubject() async {
    final controller = TextEditingController();
    String? name;
    try {
      name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('افزودن درس جدید', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'نام درس (مثلاً: زبان انگلیسی)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف', style: TextStyle())),
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
        StudyValidator.validateSubjectName(name, existingSubjects: _subjects);
        final subject = StudySubject(
          id: const Uuid().v4(),
          name: name,
          orderIndex: _subjects.length,
        );
        await StudyRepository.instance.saveSubject(subject);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  Future<StudySubject?> _showSubjectPicker() async {
    final colors = context.colors;
    return showModalBottomSheet<StudySubject>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('انتخاب درس برای مطالعه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _subjects.length,
                itemBuilder: (ctx, i) {
                  final s = _subjects[i];
                  return ListTile(
                    leading: Text(s.emoji ?? '📚', style: const TextStyle(fontSize: 22)),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () => Navigator.pop(ctx, s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final todayMinutes = _todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final targetMinutes = _settings?.dailyTargetMinutes ?? 90;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 130.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Stack(
          children: [
            // Layer 1: Body Content
            Positioned.fill(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.primary))
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: colors.error),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, style: TextStyle(fontSize: 14, color: colors.textPrimary), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadData,
                                  icon: const Icon(Icons.refresh, color: Colors.white),
                                  label: const Text('تلاش مجدد', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.axis == Axis.vertical) {
                                _scrollOffset.value = notification.metrics.pixels;
                              }
                              return false;
                            },
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 100),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_topRecommendation != null) _buildNextUpCard(_topRecommendation!),
                                  const SizedBox(height: 16),
                                  _buildTodayProgressCard(todayMinutes, targetMinutes),
                                  const SizedBox(height: 16),
                                  StudyDeadlinesSection(
                                    deadlines: _upcomingDeadlines,
                                    subjects: _subjects,
                                    onChanged: _loadData,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('دروس من', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                                      TextButton.icon(
                                        onPressed: _addSubject,
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('درس جدید', style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_subjects.isEmpty)
                                    _buildEmptyState()
                                  else
                                    ..._subjects.map((subject) {
                                      final stats = _subjectStats[subject.id];
                                      return _buildSubjectCard(subject, stats);
                                    }),
                                  const SizedBox(height: 16),
                                  StudyWeekHeatmap(sessionsByDate: _weeklyHeatmapData),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),

            // Layer 2: Apple Dynamic Large Title Morphing Glass Header (Unified Single Capsule)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _scrollOffset,
                builder: (context, _) {
                  return RitmoAppleMorphingGlassHeader(
                    title: 'درس و مطالعه',
                    subtitle: 'برنامه‌ریزی هوشمند، مرور لایتنر و تمرکز مطالعاتی',
                    scrollOffset: _scrollOffset.value,
                    collapseDistance: 55.0,
                    onBack: () => Navigator.maybePop(context),
                    statusBadge: _subjects.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '${RitmoNumber.toFa(_subjects.length)} درس',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    actions: [
                      RitmoVibrancyActionButton(
                        icon: Icons.school_outlined,
                        iconColor: const Color(0xFF8B5CF6),
                        tooltip: 'تغییر به حالت کنکور',
                        onTap: () async {
                          await StudyModuleEntry.switchMode(context, konkur: true);
                        },
                      ),
                      const SizedBox(width: 8),
                      RitmoVibrancyActionButton(
                        icon: CupertinoIcons.settings,
                        iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                        tooltip: 'تنظیمات مطالعه',
                        onTap: () async {
                          if (_settings != null) {
                            final newKonkur = await StudySettingsSheet.show(context, settings: _settings!);
                            if (newKonkur != null && newKonkur != _settings!.konkurMode && context.mounted) {
                              await StudyModuleEntry.switchMode(context, konkur: newKonkur);
                            } else {
                              await _loadData();
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      RitmoVibrancyActionButton(
                        icon: CupertinoIcons.plus,
                        iconColor: isDark ? Colors.white : const Color(0xFF1D2129),
                        tooltip: 'درس جدید',
                        onTap: _addSubject,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            if (_subjects.isEmpty) {
              await _addSubject();
            } else if (_subjects.length == 1) {
              await SessionTimerSheet.show(context, subject: _subjects.first);
              await _loadData();
            } else {
              final chosenSubject = await _showSubjectPicker();
              if (chosenSubject != null && context.mounted) {
                await SessionTimerSheet.show(context, subject: chosenSubject);
                await _loadData();
              }
            }
          },
          backgroundColor: colors.primary,
          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          label: const Text('شروع مطالعه', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildNextUpCard(StudyRecommendation rec) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colors.primary, size: 18),
              const SizedBox(width: 8),
              Text('الان چی بخونم؟', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${rec.subject.name} — ${rec.topic.name}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 4),
          Text('دلیل: ${rec.reason}', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              await SessionTimerSheet.show(context, subject: rec.subject, topic: rec.topic);
              await _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            label: const Text('شروع جلسه', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayProgressCard(int todayMinutes, int targetMinutes) {
    final colors = context.colors;
    final progress = targetMinutes > 0 ? (todayMinutes / targetMinutes).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('مطالعه امروز', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
              TextButton.icon(
                onPressed: () async {
                  await ManualSessionSheet.show(context, subjects: _subjects);
                  await _loadData();
                },
                icon: const Icon(Icons.edit_calendar, size: 16),
                label: const Text('ثبت دستی', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${RitmoNumber.faInt(todayMinutes)} از ${RitmoNumber.faInt(targetMinutes)} دقیقه',
            style: TextStyle(fontSize: 13, color: colors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.surfaceElevated,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(StudySubject subject, SubjectStats? stats) {
    final colors = context.colors;
    final totalHours = (stats?.totalMinutes ?? 0) / 60.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: colors.surfaceSunken,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SubjectDetailScreen(subject: subject)),
          );
          await _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(subject.emoji ?? '📚', style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      '${RitmoNumber.fa(totalHours.toStringAsFixed(1))} ساعت مطالعه · ${StudyDate.formatRelative(stats?.lastStudiedDateIso)}',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_stories_outlined, size: 48, color: colors.textSecondary),
          const SizedBox(height: 12),
          Text('اولین درس خود را اضافه کنید', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 4),
          Text('با افزودن درس و سرفصل‌ها، پیشنهاد مطالعه روزانه فعال می‌شود.', style: TextStyle(fontSize: 12, color: colors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addSubject,
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('افزودن اولین درس', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
