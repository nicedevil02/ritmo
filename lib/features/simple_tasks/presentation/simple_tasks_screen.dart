import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/routines/presentation/quick_add_parser.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_attachment_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/data/task_step_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/domain/task_bucket.dart';
import 'package:ritmo/features/simple_tasks/logic/my_day_service.dart';
import 'package:ritmo/features/simple_tasks/logic/my_day_suggestions.dart';
import 'package:ritmo/features/simple_tasks/logic/task_bucketing.dart';
import 'package:ritmo/features/simple_tasks/presentation/task_strings.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/my_day_section.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/simple_tasks_app_bar.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/task_bucket_section.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/task_detail_sheet.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/task_inline_add_bar.dart';

class SimpleTasksScreen extends StatefulWidget {
  const SimpleTasksScreen({
    super.key,
    this.focusAddField = false,
    this.focusTrigger,
  });

  final bool focusAddField;
  final ValueListenable<int>? focusTrigger;

  @override
  State<SimpleTasksScreen> createState() => _SimpleTasksScreenState();
}

class _SimpleTasksScreenState extends State<SimpleTasksScreen> with WidgetsBindingObserver {
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

  List<SimpleTask> _myDayTasks = [];
  List<MyDaySuggestion> _myDaySuggestions = [];
  List<String> _activeTags = [];
  String? _selectedTag;
  TaskSortMode _sortMode = TaskSortMode.smart;
  bool _hideCompleted = false;
  Map<TaskBucket, List<SimpleTask>> _buckets = {};
  Map<String, (int done, int total)> _stepCounts = {};
  Map<String, int> _attachmentCounts = {};
  final Map<TaskBucket, bool> _bucketExpandedState = {};

  bool _isLoading = true;

  String get _todayIso => DayKey.from(DateTime.now()).value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferencesAndTasks();
    widget.focusTrigger?.addListener(_onFocusTrigger);
    if (widget.focusAddField) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addFocusNode.requestFocus();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTasks();
    }
  }

  void _onFocusTrigger() {
    if (mounted) {
      _addFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.focusTrigger?.removeListener(_onFocusTrigger);
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
      await MyDayService.instance.resetIfNewDay();

      final sortModeRaw = await TaskPreferences.getSortMode();
      final sortMode = TaskSortMode.values.firstWhere((e) => e.name == sortModeRaw, orElse: () => TaskSortMode.smart);
      final hideCompleted = await TaskPreferences.isHideCompleted();

      final myDayList = await MyDayService.instance.myDayTasks();
      final suggestionsList = await buildSuggestions(now: DateTime.now());
      final buckets = await SimpleTaskRepository.instance.buckets(
        todayIso: _todayIso,
        sortMode: sortMode,
        hideCompleted: hideCompleted,
      );
      final activeTags = await SimpleTaskRepository.instance.getActiveTags(limit: 8);

      if (_selectedTag != null && !activeTags.contains(_selectedTag)) {
        _selectedTag = null;
      }

      var displayMyDay = myDayList;
      var displayBuckets = buckets;

      if (_selectedTag != null) {
        displayMyDay = myDayList.where((t) => t.tags.contains(_selectedTag)).toList();
        displayBuckets = {
          for (final entry in buckets.entries)
            entry.key: entry.value.where((t) => t.tags.contains(_selectedTag)).toList(),
        };
      }

      final allTaskIds = <String>[];
      allTaskIds.addAll(displayMyDay.map((t) => t.id));
      allTaskIds.addAll(suggestionsList.map((s) => s.task.id));
      for (final list in displayBuckets.values) {
        allTaskIds.addAll(list.map((t) => t.id));
      }

      final stepCounts = await TaskStepRepository.instance.countsFor(allTaskIds);
      final attachmentCounts = await TaskAttachmentRepository.instance.countsFor(allTaskIds);

      if (mounted) {
        setState(() {
          _sortMode = sortMode;
          _hideCompleted = hideCompleted;
          _activeTags = activeTags;
          _myDayTasks = displayMyDay;
          _myDaySuggestions = suggestionsList;
          _buckets = displayBuckets;
          _stepCounts = stepCounts;
          _attachmentCounts = attachmentCounts;
        });
      }
    } catch (e, st) {
      RitmoLog.error('SimpleTasksScreen', 'Error loading tasks', e, st);
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

      await NotificationGateway.cancel(reminderId);
      await NotificationGateway.schedule(
        NotificationRequest(
          id: reminderId,
          channel: NotificationChannelId.planning,
          scheduledAt: at,
          title: 'یادآور کار: ${created.title}',
          body: created.note ?? '',
          sourceSystem: 'tasks',
          entityId: created.id,
        ),
      );

      await SimpleTaskRepository.instance.addPendingReminder(
        reminderId: reminderId,
        title: 'یادآور کار: ${created.title}',
        body: created.note ?? '',
        scheduledTimeMs: targetMs,
        taskId: created.id,
      );
      
      final updated = created.copyWith(reminderAtMs: targetMs, reminderId: reminderId);
      await SimpleTaskRepository.instance.updateTask(updated);
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
    final newDoneState = !task.isDone;
    if (newDoneState) {
      RitmoHaptics.tap();
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

  Future<void> _handleAddToMyDay(SimpleTask task) async {
    await MyDayService.instance.addToMyDay(task.id);
    if (!mounted) return;
    await _loadTasks();
    if (!mounted) return;
    RitmoToast.show(context, TaskStrings.addedToMyDay);
  }

  Future<void> _handleRemoveFromMyDay(SimpleTask task) async {
    await MyDayService.instance.removeFromMyDay(task.id);
    if (!mounted) return;
    await _loadTasks();
    if (!mounted) return;
    RitmoToast.show(
      context,
      TaskStrings.removedFromMyDay,
      actionLabel: TaskStrings.undo,
      onAction: () async {
        await MyDayService.instance.addToMyDay(task.id);
        if (mounted) {
          unawaited(_loadTasks());
        }
      },
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
            SimpleTasksAppBar(
              sortMode: _sortMode,
              hideCompleted: _hideCompleted,
              onPreferencesChanged: _loadTasks,
            ),

            TaskInlineAddBar(
              controller: _addController,
              focusNode: _addFocusNode,
              onSubmitted: _addTask,
            ),

            if (_activeTags.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _activeTags.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final tag = _activeTags[index];
                    final isSelected = _selectedTag == tag;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedTag = isSelected ? null : tag;
                        });
                        _loadTasks();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.primary : colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Main List View of Buckets & My Day
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.primary))
                  : (totalTasks == 0 && _myDayTasks.isEmpty && _myDaySuggestions.isEmpty)
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
                            SliverToBoxAdapter(
                              child: MyDaySection(
                                tasks: _myDayTasks,
                                suggestions: _myDaySuggestions,
                                onToggleDone: _toggleDone,
                                onTaskTap: _openTaskDetails,
                                onAddToMyDay: _handleAddToMyDay,
                                onRemoveFromMyDay: _handleRemoveFromMyDay,
                                onNewTask: () {
                                  _addFocusNode.requestFocus();
                                },
                                stepCounts: _stepCounts,
                                attachmentCounts: _attachmentCounts,
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
