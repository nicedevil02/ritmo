import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/features/routines/presentation/quick_add_parser.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';
import 'package:ritmo/features/search/presentation/global_search_screen.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/data/task_step_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_attachment_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/domain/task_bucket.dart';
import 'package:ritmo/features/simple_tasks/logic/task_bucketing.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/task_bucket_section.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/task_detail_sheet.dart';

class SimpleTasksScreen extends StatefulWidget {
  const SimpleTasksScreen({super.key, this.focusAddField = false});

  final bool focusAddField;

  @override
  State<SimpleTasksScreen> createState() => _SimpleTasksScreenState();
}

class _SimpleTasksScreenState extends State<SimpleTasksScreen> {
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

  Map<TaskBucket, List<SimpleTask>> _buckets = {};
  Map<String, (int done, int total)> _stepCounts = {};
  Map<String, int> _attachmentCounts = {};
  final Map<TaskBucket, bool> _bucketExpandedState = {};

  bool _isLoading = true;

  String get _todayIso => DayKey.from(DateTime.now()).value;

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndTasks();
    if (widget.focusAddField) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPreferencesAndTasks() async {
    for (final b in TaskBucket.values) {
      final expanded = await TaskPreferences.isBucketExpanded(b);
      _bucketExpandedState[b] = expanded;
    }
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final buckets = await SimpleTaskRepository.instance.buckets(_todayIso);

      final allTaskIds = <String>[];
      for (final list in buckets.values) {
        allTaskIds.addAll(list.map((t) => t.id));
      }
      final stepCounts = await TaskStepRepository.instance.countsFor(allTaskIds);
      final attachmentCounts = await TaskAttachmentRepository.instance.countsFor(allTaskIds);

      if (mounted) {
        setState(() {
          _buckets = buckets;
          _stepCounts = stepCounts;
          _attachmentCounts = attachmentCounts;
        });
      }
    } catch (e, st) {
      debugPrint('[SimpleTasksScreen] Error loading tasks: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleBucketExpanded(TaskBucket bucket) async {
    final currentState = _bucketExpandedState[bucket] ?? true;
    final newState = !currentState;
    setState(() {
      _bucketExpandedState[bucket] = newState;
    });
    await TaskPreferences.setBucketExpanded(bucket, newState);
  }

  Future<void> _addTask() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    final result = QuickAddParser.parse(text);

    String? dueDate;
    String? dueTime;

    if (result.daysOffset != null) {
      final targetDate = DateTime.now().add(Duration(days: result.daysOffset!));
      dueDate = DayKey.from(targetDate).value;
    }

    if (result.timeOfDay != null) {
      final hh = result.timeOfDay!.hour.toString().padLeft(2, '0');
      final mm = result.timeOfDay!.minute.toString().padLeft(2, '0');
      dueTime = '$hh:$mm';
    }

    final titleToSave = result.title.isNotEmpty ? result.title : text;

    if (result.itemType == 'ROUTINE') {
      _addController.clear();
      _addFocusNode.unfocus();
      await UniversalPlannerSheet.show(
        context: context,
        prefilledTitle: text,
      );
      await _loadTasks();
      return;
    }

    final created = await SimpleTaskRepository.instance.create(
      title: titleToSave,
      dueDate: dueDate,
      dueTime: dueTime,
    );

    if (result.itemType == 'REMINDER' && result.timeOfDay != null) {
      final now = DateTime.now();
      final targetDate = now.add(Duration(days: result.daysOffset ?? 0));
      var at = DateTime(targetDate.year, targetDate.month, targetDate.day, result.timeOfDay!.hour, result.timeOfDay!.minute);
      if (at.isBefore(now)) at = at.add(const Duration(days: 1)); // adjust if time has passed today

      final targetMs = at.millisecondsSinceEpoch;
      final reminderId = 'rem_${created.id}';
      
      // Request permission if needed
      if (!await sl<AlarmPlatform>().checkExactAlarmPermission()) {
        await sl<AlarmPlatform>().requestExactAlarmPermission();
      }

      await sl<AlarmPlatform>().cancelAlarm(reminderId);
      
      await SimpleTaskRepository.instance.addPendingReminder(
        reminderId: reminderId,
        title: 'یادآور کار: ${created.title}',
        body: created.note ?? '',
        scheduledTimeMs: targetMs,
        taskId: created.id,
      );
      
      final updated = created.copyWith(reminderAtMs: targetMs, reminderId: reminderId);
      await SimpleTaskRepository.instance.updateTask(updated);
      
      await sl<AlarmPlatform>().scheduleExactAlarm(
        id: reminderId,
        timeMsUTC: targetMs,
        title: created.title,
        isEssential: false,
      );
      await AlarmSchedulerService.scheduleNextAlarms();
    }

    _addController.clear();
    _addFocusNode.requestFocus();
    await _loadTasks();

    if (mounted && dueDate != null) {
      final dateLabel = result.daysOffset == 1
          ? 'فردا'
          : (result.daysOffset == 0 ? 'امروز' : dueDate);
      RitmoToast.show(
        context,
        'برای $dateLabel ثبت شد',
        actionLabel: 'بدون تاریخ',
        onAction: () async {
          await SimpleTaskRepository.instance.updateTask(created.copyWith(dueDate: null, dueTime: null));
          unawaited(_loadTasks());
        },
      );
    }
  }

  Future<void> _playSoundIfEnabled() async {
    final soundEnabled = await TaskPreferences.isCompletionSoundEnabled();
    if (soundEnabled) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _toggleDone(SimpleTask task) async {
    RitmoHaptics.tap();
    final newDoneState = !task.isDone;
    if (newDoneState) {
      unawaited(_playSoundIfEnabled());
    }
    
    setState(() {
      final allTasks = _buckets.values.expand((e) => e).toList();
      final idx = allTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        allTasks[idx] = task.copyWith(
          isDone: newDoneState, 
          doneAt: newDoneState ? DateTime.now() : null
        );
        _buckets = groupTasks(allTasks, now: DateTime.now());
      }
    });

    unawaited(SimpleTaskRepository.instance.setDone(task.id, done: newDoneState).then((_) {
      if (mounted) _loadTasks();
    }));

    if (mounted) {
      RitmoToast.show(
        context,
        newDoneState ? 'انجام شد' : 'بازگردانی شد',
        actionLabel: 'برگردان',
        onAction: () async {
          setState(() {
            final allTasks = _buckets.values.expand((e) => e).toList();
            final idx = allTasks.indexWhere((t) => t.id == task.id);
            if (idx != -1) {
              allTasks[idx] = task.copyWith(
                isDone: !newDoneState, 
                doneAt: !newDoneState ? DateTime.now() : null
              );
              _buckets = groupTasks(allTasks, now: DateTime.now());
            }
          });
          unawaited(SimpleTaskRepository.instance.setDone(task.id, done: !newDoneState).then((_) {
            if (mounted) _loadTasks();
          }));
        },
      );
    }
  }

  Future<void> _toggleStar(SimpleTask task) async {
    RitmoHaptics.tap();
    final newState = !task.isImportant;
    
    setState(() {
      final allTasks = _buckets.values.expand((e) => e).toList();
      final idx = allTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        allTasks[idx] = task.copyWith(
          isImportant: newState,
          importantAt: newState ? DateTime.now() : null,
        );
        _buckets = groupTasks(allTasks, now: DateTime.now());
      }
    });

    unawaited(SimpleTaskRepository.instance.setImportant(task.id, important: newState).then((_) {
      if (mounted) _loadTasks();
    }));
  }

  void _openTaskDetails(SimpleTask task) {
    TaskDetailSheet.show(
      context,
      task: task,
      onTaskUpdated: _loadTasks,
      onTaskDeleted: _loadTasks,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final totalTasks = _buckets.values.fold(0, (prev, list) => prev + list.length);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Title & Search Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'کارها',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      
                    ),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.search, color: colors.textSecondary, size: 22),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GlobalSearchScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Sticky Inline Add Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addController,
                        focusNode: _addFocusNode,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textPrimary,
                          
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTask(),
                        decoration: InputDecoration(
                          hintText: 'یک کار بنویس…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary.withValues(alpha: 0.6),
                            
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(CupertinoIcons.add_circled_solid, color: colors.primary, size: 28),
                      onPressed: _addTask,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Main List View of Buckets
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.primary))
                  : totalTasks == 0
                      ? Center(
                          child: Text(
                            'هیچ کاری ثبت نشده است.\nیک کار جدید اضافه کنید!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              
                              color: colors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverMainAxisGroup(
                                slivers: TaskBucket.values.map((bucket) {
                                  final tasks = _buckets[bucket] ?? [];
                                  final isExpanded = _bucketExpandedState[bucket] ?? true;

                                  return TaskBucketSection(
                                    bucket: bucket,
                                    tasks: tasks,
                                    stepCounts: _stepCounts,
                                    attachmentCounts: _attachmentCounts,
                                    isExpanded: isExpanded,
                                    onToggleExpand: () => _toggleBucketExpanded(bucket),
                                    onTaskTap: _openTaskDetails,
                                    onToggleDone: _toggleDone,
                                    onToggleStar: _toggleStar,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
