import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_snapshot_builder.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/features/calendar/data/day_mark_repository.dart';
import 'package:ritmo/features/calendar/data/day_template_repository.dart';
import 'package:ritmo/features/calendar/presentation/logic/gap_finder.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_snapping.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// Calendar view scale. `agenda` is the primary view ("what's next?").
/// `week` and `year` are overflow-menu-only — shown in the ⋯ button.
enum JourneyScale { agenda, day, week, month, year }

class JourneyController extends ChangeNotifier {
  static const Duration agendaLoadBudget = Duration(milliseconds: 250);
  static const int agendaFastWindowDays = 3;
  static const int agendaWindowDaysBack = 14;
  static const int agendaWindowDaysForward = 45;
  static const int agendaExpandedDaysBack = 365;

  JourneyController({
    DayAgendaService? agendaService,
    DayAgendaSnapshotBuilder? snapshotBuilder,
    RitmoEventBus? eventBus,
    AgendaActionHandler? actionHandler,
    RitmoExecutionKernel? kernel,
    OccurrenceOverrideRepository? overrideRepo,
    DayMarkRepository? dayMarkRepo,
  })  : _agendaService = agendaService ?? DayAgendaService.instance,
        _snapshotBuilder = snapshotBuilder ?? const DayAgendaSnapshotBuilder(),
        _eventBus = eventBus ?? RitmoEventBus(),
        _actionHandler = actionHandler ?? AgendaActionHandler.instance,
        _kernel = kernel ?? RitmoExecutionKernel.instance,
        _overrideRepo = overrideRepo ?? const SqliteOccurrenceOverrideRepository(),
        _dayMarkRepo = dayMarkRepo ?? DayMarkRepository.instance {
    _subscription = _eventBus.onEvents.listen(_handleEvent);
    RitmoEvents.routineChangedNotifier.addListener(_onRoutineChangedNotification);
  }

  final DayAgendaService _agendaService;
  final DayAgendaSnapshotBuilder _snapshotBuilder;
  final RitmoEventBus _eventBus;
  final AgendaActionHandler _actionHandler;
  final RitmoExecutionKernel _kernel;
  final OccurrenceOverrideRepository _overrideRepo;
  final DayMarkRepository _dayMarkRepo;
  StreamSubscription<RitmoEvent>? _subscription;

  bool _isDisposed = false;
  int _loadGeneration = 0;
  /// همیشه نیمه‌شب محلی. هیچ‌وقت ساعت را در _selectedDate نگه نداریم.
  DateTime _selectedDate = DateKey.dayOf(DateTime.now());
  JourneyScale _activeScale = JourneyScale.agenda; // overridden by loadDefaultScale()
  bool _isLoading = false;
  bool _isExecutingAction = false;
  DayAgendaSnapshot? _snapshot;
  Map<String, DayAgendaSnapshot> _rangeSnapshots = {};
  String? _errorMessage;
  String? _warningMessage;
  TimeSlot? _suggestedSlot;
  String? _highlightedItemId;
  int? _focusedMinutes;
  String? _manipulatingItemId;
  bool _isDragging = false;
  bool _isResizing = false;
  String? _previewTimeOfDay;
  int? _previewDurationMinutes;

  DateTime? _windowStart;
  DateTime? _windowEnd;
  int _olderOverdueCount = 0;
  DayMarkKind _currentDayMark = DayMarkKind.normal;

  bool _scaleExplicitlySet = false;

  DateTime get selectedDate => _selectedDate;
  JourneyScale get activeScale => _activeScale;
  DayMarkKind get currentDayMark => _currentDayMark;
  DateTime? get windowStart => _windowStart;
  DateTime? get windowEnd => _windowEnd;
  int get olderOverdueCount => _olderOverdueCount;
  bool get isLoading => _isLoading;
  bool get isExecutingAction => _isExecutingAction;
  DayAgendaSnapshot? get snapshot => _snapshot;
  Map<String, DayAgendaSnapshot> get rangeSnapshots => _rangeSnapshots;
  String? get errorMessage => _errorMessage;
  String? get warningMessage => _warningMessage;
  TimeSlot? get suggestedSlot => _suggestedSlot;
  bool get canUndo => CommandStack.instance.canUndo;
  bool get canRedo => CommandStack.instance.canRedo;
  String? get lastUndoDescription => CommandStack.instance.lastUndoDescription;
  String? get lastRedoDescription => CommandStack.instance.lastRedoDescription;
  String? get highlightedItemId => _highlightedItemId;
  int? get focusedMinutes => _focusedMinutes;
  String? get manipulatingItemId => _manipulatingItemId;
  bool get isDragging => _isDragging;
  bool get isResizing => _isResizing;
  String? get previewTimeOfDay => _previewTimeOfDay;
  int? get previewDurationMinutes => _previewDurationMinutes;
  bool get isDisposed => _isDisposed;
  @visibleForTesting
  int get loadGeneration => _loadGeneration;
  @visibleForTesting
  bool get scaleExplicitlySet => _scaleExplicitlySet;
  AgendaLoadStatus get agendaLoadStatus => _agendaService.lastLoadStatus;
  Set<AgendaDomain> get activeDegradedSources {
    if (_snapshot != null && _snapshot!.degradedSources.isNotEmpty) {
      return _snapshot!.degradedSources;
    }
    final all = <AgendaDomain>{};
    for (final snap in _rangeSnapshots.values) {
      all.addAll(snap.degradedSources);
    }
    return all;
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  void highlightItem(String? itemId) {
    if (_isDisposed) return;
    _highlightedItemId = itemId;
    notifyListeners();
  }

  void focusMinutes(int? minutes) {
    if (_isDisposed) return;
    _focusedMinutes = minutes;
    notifyListeners();
  }

  void clearFocusAndHighlight() {
    if (_isDisposed) return;
    _highlightedItemId = null;
    _focusedMinutes = null;
    _warningMessage = null;
    notifyListeners();
  }

  static String scaleToString(JourneyScale s) => s.name;

  void setScale(JourneyScale scale, {SettingsService? settingsService}) {
    if (_isDisposed || _activeScale == scale) return;
    _activeScale = scale;
    // دادهٔ مقیاس قبلی برای مقیاس جدید معنا ندارد؛ نگه‌داشتنش نمای غلط می‌سازد.
    _rangeSnapshots = const {};
    _snapshot = null;
    _windowStart = null;
    _windowEnd = null;
    _isLoading = true;
    notifyListeners();
    (settingsService ?? SettingsService.instance)
        .setString('calendar_default_scale', scale.name)
        .catchError((e, st) {
      RitmoLog.error('JourneyController', 'persist scale failed', e, st);
      return false;
    });
    loadForActiveScale();
  }

  void selectDate(DateTime date, {JourneyScale? scaleToSet}) {
    if (_isDisposed) return;
    _selectedDate = DateKey.dayOf(date);
    if (scaleToSet != null) {
      _scaleExplicitlySet = true;
      if (scaleToSet != _activeScale) {
        _activeScale = scaleToSet;
        _rangeSnapshots = const {};
        _snapshot = null;
        _windowStart = null;
        _windowEnd = null;
        _isLoading = true;
        notifyListeners();
      }
    }
    loadForActiveScale();
  }

  void navigatePeriod(int offset) {
    if (_isDisposed) return;
    switch (_activeScale) {
      case JourneyScale.agenda:
        // Agenda navigates in 7-day blocks (same as week)
        _selectedDate = DateKey.addDays(_selectedDate, 7 * offset);
        break;
      case JourneyScale.day:
        _selectedDate = DateKey.addDays(_selectedDate, offset);
        break;
      case JourneyScale.week:
        _selectedDate = DateKey.addDays(_selectedDate, 7 * offset);
        break;
      case JourneyScale.month:
        final j = Jalali.fromDateTime(_selectedDate);
        final nextJ = j.addMonths(offset);
        _selectedDate = DateKey.dayOf(nextJ.toDateTime());
        break;
      case JourneyScale.year:
        final j = Jalali.fromDateTime(_selectedDate);
        final targetYear = j.year + offset;
        final maxDay = Jalali(targetYear, j.month, 1).monthLength;
        final nextJ = Jalali(targetYear, j.month, j.day.clamp(1, maxDay));
        _selectedDate = DateKey.dayOf(nextJ.toDateTime());
        break;
    }
    loadForActiveScale();
  }

  Future<void> loadForActiveScale({bool isBackgroundRefresh = false}) async {
    if (_isDisposed) return;

    // K21: Agenda scale uses its own dedicated range loader
    if (_activeScale == JourneyScale.agenda) {
      await loadAgendaRange(
        anchorDate: _selectedDate,
        isBackgroundRefresh: isBackgroundRefresh,
      );
      return;
    }

    final gen = ++_loadGeneration;

    if (!isBackgroundRefresh && _snapshot == null) {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final range = _calculateDateRangeForScale(_activeScale, _selectedDate);
      final daysMap = await _agendaService.agendaForRange(range.start, range.end);
      if (_isDisposed || gen != _loadGeneration) return;

      final newSnapshots = <String, DayAgendaSnapshot>{};
      for (final entry in daysMap.entries) {
        newSnapshots[entry.key] = _snapshotBuilder.buildSnapshot(entry.value);
      }

      _rangeSnapshots = newSnapshots;
      _snapshot = _snapshotForSelectedDate();
      _windowStart = range.start;
      _windowEnd = range.end;

      final mark = await _dayMarkRepo.getMark(DateKey.of(_selectedDate));
      _currentDayMark = mark?.kind ?? DayMarkKind.normal;

      // Cleanup stale highlights or manipulation state if item no longer exists
      if (_snapshot != null) {
        final currentItemIds = _snapshot!.items.map((i) => i.id).toSet();
        if (_highlightedItemId != null && !currentItemIds.contains(_highlightedItemId)) {
          _highlightedItemId = null;
        }
        if (_manipulatingItemId != null && !currentItemIds.contains(_manipulatingItemId)) {
          _manipulatingItemId = null;
          _isDragging = false;
          _isResizing = false;
          _previewTimeOfDay = null;
          _previewDurationMinutes = null;
        }
      }
    } catch (e, stackTrace) {
      if (_isDisposed || gen != _loadGeneration) return;
      _errorMessage = CalendarMessagesFa.load;
      RitmoLog.error('JourneyController', 'loadForActiveScale failed', e, stackTrace);
    } finally {
      if (!_isDisposed && gen == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> completeItem(
    AgendaItem item, {
    String resultType = OccurrenceResultType.full,
    int? actualDurationMinutes,
  }) async {
    if (_isDisposed || _isExecutingAction) return;
    _isExecutingAction = true;
    notifyListeners();

    try {
      final effectiveDuration = actualDurationMinutes ?? item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes;
      if (item.domain == AgendaDomain.routine) {
        await _kernel.execute(CompleteOccurrenceCommand(
          routineId: item.sourceId,
          dateStr: item.dateStr,
          resultType: resultType,
          durationMinutes: effectiveDuration,
        ));
      } else {
        await _actionHandler.toggleAgendaItem(item: item, isDone: true);
      }
      await refresh();
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      _errorMessage = CalendarMessagesFa.complete;
      RitmoLog.error('JourneyController', 'completeItem failed', e, stackTrace);
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        notifyListeners();
      }
    }
  }

  static const _nonPostponableDomains = {
    AgendaDomain.prayer,
    AgendaDomain.worshipDebt,
    AgendaDomain.cycle,
  };

  Future<void> postponeItem(AgendaItem item, {int days = 1}) async {
    if (_isDisposed || _isExecutingAction) return;

    if (_nonPostponableDomains.contains(item.domain)) {
      _errorMessage = CalendarMessagesFa.notSupported;
      notifyListeners();
      return;
    }

    _isExecutingAction = true;
    notifyListeners();

    try {
      final command = _PostponeItemCommand(
        item: item,
        days: days,
        overrideRepo: _overrideRepo,
      );
      await command.execute();
      CommandStack.instance.push(command);
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      _errorMessage = CalendarMessagesFa.postpone;
      RitmoLog.error('JourneyController', 'postponeItem failed', e, stackTrace);
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        notifyListeners();
      }
    }
  }

  Future<void> skipItem(AgendaItem item) async {
    if (_isDisposed || _isExecutingAction) return;
    _isExecutingAction = true;
    notifyListeners();

    try {
      final _CalendarCommand command;
      if (item.domain == AgendaDomain.routine) {
        command = _SkipRoutineCommand(
          item: item,
          kernel: _kernel,
        );
      } else {
        command = _SkipItemCommand(
          item: item,
          overrideRepo: _overrideRepo,
        );
      }
      await command.execute();
      CommandStack.instance.push(command);
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      _errorMessage = CalendarMessagesFa.skip;
      RitmoLog.error('JourneyController', 'skipItem failed', e, stackTrace);
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        notifyListeners();
      }
    }
  }

  void startItemDrag(AgendaItem item) {
    if (_isDisposed) return;
    _manipulatingItemId = item.id;
    _isDragging = true;
    _isResizing = false;
    _previewTimeOfDay = item.timeOfDay;
    _previewDurationMinutes = item.durationMinutes;
    notifyListeners();
  }

  void updateDragPreview(String timeOfDay) {
    if (_isDisposed || _previewTimeOfDay == timeOfDay) return;
    _previewTimeOfDay = timeOfDay;
    notifyListeners();
  }

  /// null یعنی معتبر؛ در غیر این صورت پیام فارسی برمی‌گرداند.
  String? _validatePlacement({
    required AgendaItem item,
    required int startMinutes,
    required int durationMinutes,
    required bool allowOverlap,
  }) {
    if (startMinutes < 0 || startMinutes > 1439) return CalendarMessagesFa.invalidTime;
    if (durationMinutes < CalendarDefaults.minDurationMinutes) return CalendarMessagesFa.invalidTime;
    if (startMinutes + durationMinutes > 1440) return CalendarMessagesFa.invalidTime;
    if (!allowOverlap) {
      final others = (_snapshot?.items ?? const <AgendaItem>[])
          .where((o) => o.id != item.id && o.isTimed);
      for (final o in others) {
        final s = TimeOfDayMinutes.tryParse(o.timeOfDay);
        if (s == null) continue;
        final d = DurationBounds.sanitize(o.durationMinutes);
        if (startMinutes < s + d && startMinutes + durationMinutes > s) {
          return CalendarMessagesFa.overlap;
        }
      }
    }
    return null;
  }

  Future<void> commitItemDrag(
    AgendaItem item,
    String newTimeOfDay, {
    CalendarEditScope scope = CalendarEditScope.thisDayOnly,
  }) async {
    if (_isDisposed || _isExecutingAction) return;
    _isExecutingAction = true;
    _warningMessage = null;
    notifyListeners();

    final raw = TimeOfDayMinutes.tryParse(newTimeOfDay);
    if (raw == null) {
      _errorMessage = CalendarMessagesFa.invalidTime;
      _isExecutingAction = false;
      cancelManipulation();
      notifyListeners();
      return;
    }

    final dur = DurationBounds.sanitize(item.durationMinutes);
    final snapped = TimelineSnappingHelper.snapStartMinutes(raw, durationMinutes: dur);
    final boundsErr = _validatePlacement(item: item, startMinutes: snapped, durationMinutes: dur, allowOverlap: true);
    if (boundsErr != null) {
      _errorMessage = boundsErr;
      _isExecutingAction = false;
      cancelManipulation();
      notifyListeners();
      return;
    }

    final overlapWarn = _validatePlacement(item: item, startMinutes: snapped, durationMinutes: dur, allowOverlap: false);
    if (overlapWarn != null) {
      _warningMessage = overlapWarn;
      final gaps = GapFinder.findFreeGaps(
        _snapshot?.items ?? const <AgendaItem>[],
        minDurationMinutes: dur,
        preferredStartMinutes: snapped,
        excludeItemId: item.id,
      );
      _suggestedSlot = gaps.isNotEmpty ? gaps.first : null;
    } else {
      _suggestedSlot = null;
    }

    final finalTime = TimeOfDayMinutes.format(snapped);
    final oldTimeOfDay = item.timeOfDay ?? CalendarDefaults.fallbackTimeOfDay;

    try {
      final command = _MoveItemCommand(
        actionHandler: _actionHandler,
        item: item,
        oldTimeOfDay: oldTimeOfDay,
        newTimeOfDay: finalTime,
        scope: scope,
        overrideRepo: _overrideRepo,
      );
      await command.execute();
      CommandStack.instance.push(command);
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      _errorMessage = CalendarMessagesFa.move;
      RitmoLog.error('JourneyController', 'commitItemDrag failed', e, stackTrace);
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        cancelManipulation();
      }
    }
  }

  Future<void> commitItemResize(
    AgendaItem item,
    int newDurationMinutes, {
    CalendarEditScope scope = CalendarEditScope.thisDayOnly,
  }) async {
    if (_isDisposed || _isExecutingAction) return;
    _isExecutingAction = true;
    _warningMessage = null;
    notifyListeners();

    final start = TimeOfDayMinutes.tryParse(item.timeOfDay) ?? TimeOfDayMinutes.parse(CalendarDefaults.fallbackTimeOfDay);
    final sanitizedDur = DurationBounds.sanitize(newDurationMinutes);
    final snappedDur = TimelineSnappingHelper.snapDurationMinutes(sanitizedDur, startMinutes: start);

    if (snappedDur == null) {
      _errorMessage = CalendarMessagesFa.invalidTime;
      _isExecutingAction = false;
      cancelManipulation();
      notifyListeners();
      return;
    }

    final boundsErr = _validatePlacement(item: item, startMinutes: start, durationMinutes: snappedDur, allowOverlap: true);
    if (boundsErr != null) {
      _errorMessage = boundsErr;
      _isExecutingAction = false;
      cancelManipulation();
      notifyListeners();
      return;
    }

    final overlapWarn = _validatePlacement(item: item, startMinutes: start, durationMinutes: snappedDur, allowOverlap: false);
    if (overlapWarn != null) {
      _warningMessage = overlapWarn;
      final gaps = GapFinder.findFreeGaps(
        _snapshot?.items ?? const <AgendaItem>[],
        minDurationMinutes: snappedDur,
        preferredStartMinutes: start,
        excludeItemId: item.id,
      );
      _suggestedSlot = gaps.isNotEmpty ? gaps.first : null;
    } else {
      _suggestedSlot = null;
    }

    final oldDuration = item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes;
    try {
      final command = _ResizeItemCommand(
        actionHandler: _actionHandler,
        item: item,
        oldDuration: oldDuration,
        newDuration: snappedDur,
        scope: scope,
        overrideRepo: _overrideRepo,
      );
      await command.execute();
      CommandStack.instance.push(command);
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      _errorMessage = CalendarMessagesFa.resize;
      RitmoLog.error('JourneyController', 'commitItemResize failed', e, stackTrace);
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        cancelManipulation();
      }
    }
  }

  Future<bool> undoLastAction() async {
    if (_isDisposed) return false;
    final success = await CommandStack.instance.undoLast();
    if (success) {
      await refresh();
    }
    return success;
  }

  Future<bool> redoLastAction() async {
    if (_isDisposed) return false;
    final success = await CommandStack.instance.redoLast();
    if (success) {
      await refresh();
    }
    return success;
  }

  void cancelManipulation() {
    if (_isDisposed) return;
    _manipulatingItemId = null;
    _isDragging = false;
    _isResizing = false;
    _previewTimeOfDay = null;
    _previewDurationMinutes = null;
    notifyListeners();
  }

  Future<void> loadDate(DateTime date) async {
    selectDate(date);
  }

  /// K22 — Reads `calendar_default_scale` from SettingsService and applies it.
  /// EXCEPTION: if the caller sets scaleToSet on selectDate (e.g. via initialItemId
  /// or a push notification), that takes priority and this method must NOT override it.
  /// This comment is intentional — do not remove without reading 067.md §K22.
  Future<void> loadDefaultScale({SettingsService? settingsService}) async {
    if (_isDisposed || _scaleExplicitlySet) return;
    try {
      final service = settingsService ?? SettingsService.instance;
      final val = service.getString('calendar_default_scale') ?? 'agenda';
      final scale = _scaleFromString(val);
      if (!_isDisposed && !_scaleExplicitlySet && scale != _activeScale) {
        _activeScale = scale;
        _rangeSnapshots = const {};
        _snapshot = null;
        _windowStart = null;
        _windowEnd = null;
        _isLoading = true;
        notifyListeners();
        await loadForActiveScale();
      }
    } catch (e, st) {
      if (_isDisposed) return;
      RitmoLog.error('JourneyController', 'loadDefaultScale failed', e, st);
    }
  }

  static JourneyScale _scaleFromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'agenda': return JourneyScale.agenda;
      case 'day':    return JourneyScale.day;
      case 'week':   return JourneyScale.week;
      case 'month':  return JourneyScale.month;
      case 'year':   return JourneyScale.year;
      default:
        RitmoLog.error('JourneyController', 'Invalid calendar scale string in settings: "$val"');
        return JourneyScale.agenda;
    }
  }

  /// K21 — Loads a date range for the Agenda scale.
  ///
  /// Performance target: < 250ms for the initial load.
  /// Uses a single agendaForRange call — NOT one query per day.
  /// Must start with if (_isDisposed) return; — guaranteed by spec (067.md §K21).
  Future<void> _loadWindow(
    int gen, {
    required DateTime start,
    required DateTime end,
    required bool isBackgroundRefresh,
  }) async {
    if (_isDisposed || gen != _loadGeneration) return;

    if (!isBackgroundRefresh && _snapshot == null) {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final sw = Stopwatch()..start();
      final daysMap = await _agendaService.agendaForRange(start, end);
      if (_isDisposed || gen != _loadGeneration) return;

      final newSnapshots = <String, DayAgendaSnapshot>{};
      for (final entry in daysMap.entries) {
        newSnapshots[entry.key] = _snapshotBuilder.buildSnapshot(entry.value);
      }
      _rangeSnapshots = Map<String, DayAgendaSnapshot>.from(_rangeSnapshots)..addAll(newSnapshots);
      _snapshot = _snapshotForSelectedDate();
      _windowStart = _windowStart == null ? start : (start.isBefore(_windowStart!) ? start : _windowStart);
      _windowEnd = _windowEnd == null ? end : (end.isAfter(_windowEnd!) ? end : _windowEnd);

      sw.stop();
      if (sw.elapsed > agendaLoadBudget) {
        RitmoLog.warning(
          'JourneyController',
          'بارگذاری اجندا از بودجه گذشت: ${sw.elapsedMilliseconds}ms (بودجه ${agendaLoadBudget.inMilliseconds}ms)',
        );
      }
      RitmoLog.debug('JourneyController', '_loadWindow (${DateKey.of(start)}..${DateKey.of(end)}): ${sw.elapsedMilliseconds}ms');
      _errorMessage = null;
    } catch (e, st) {
      if (_isDisposed || gen != _loadGeneration) return;
      _errorMessage = CalendarMessagesFa.load;
      RitmoLog.error('JourneyController', '_loadWindow failed', e, st);
    } finally {
      if (!_isDisposed && gen == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// K21 / CAL-39 — Loads a date range for the Agenda scale in 2 stages:
  /// Stage 1: Fast immediate window (-3..+3 days) for instant interactive render.
  /// Stage 2: Background full window without spinner.
  Future<void> loadAgendaRange({
    DateTime? anchorDate,
    int daysBack = agendaWindowDaysBack,
    int daysForward = agendaWindowDaysForward,
    bool isBackgroundRefresh = false,
  }) async {
    if (_isDisposed) return;
    final gen = ++_loadGeneration;

    final anchor = DateKey.dayOf(anchorDate ?? _selectedDate);

    // مرحلهٔ ۱: پنجرهٔ کوچک، سریع، برای رندر فوری
    await _loadWindow(
      gen,
      start: DateKey.addDays(anchor, -agendaFastWindowDays),
      end: DateKey.addDays(anchor, agendaFastWindowDays),
      isBackgroundRefresh: isBackgroundRefresh,
    );
    if (_isDisposed || gen != _loadGeneration) return;

    // مرحلهٔ ۲: بقیهٔ پنجره در پس‌زمینه، بدون اسپینر
    await _loadWindow(
      gen,
      start: DateKey.addDays(anchor, -daysBack),
      end: DateKey.addDays(anchor, daysForward),
      isBackgroundRefresh: true,
    );
    if (_isDisposed || gen != _loadGeneration) return;

    // بارگذاری تعداد معوقه‌های قدیمی‌تر خارج از کل پنجره بارگذاری‌شده
    final fullStart = DateKey.addDays(anchor, -daysBack);
    _olderOverdueCount = await _agendaService.countOverdueBefore(fullStart);
    if (!_isDisposed && gen == _loadGeneration) {
      notifyListeners();
    }
  }

  /// Expands agenda range backwards up to 365 days to show all historical overdue items.
  Future<void> expandAgendaOverdue() async {
    await loadAgendaRange(daysBack: agendaExpandedDaysBack);
  }

  Future<void> refresh() async {
    await loadForActiveScale(isBackgroundRefresh: true);
  }

  /// Events that indicate a database mutation requiring calendar re-fetch.
  /// Keep in sync with DayAgendaService._cacheInvalidatingEvents.
  static const Set<String> _refreshTriggeringEvents = {
    'RoutineCompleted',
    'RoutineSkipped',
    'RoutineUpdated',
    'RoutineCreated',
    'RoutineEdited',
    'RoutineChanged',
    'RoutineDeleted',
    'DataImported',
    'DayRolledOver',
    'PrayerCompleted',
    'WorshipUpdated',
    'WorshipPracticeChanged',
    'CourseSessionCompleted',
    'CourseCreated',
    'CourseUpdated',
    'AgendaItemToggled',
    'TaskToggled',
    'TaskUpdated',
    'TaskCreated',
    'task_created',
    'task_updated',
    'GoalStepToggled',
    'GoalUpdated',
    'completion_recorded',
    'ReshuffleApplied',
    'commitmentChanged',
    'planningCycleActivated',
    'ReflectionChanged',
  };

  Timer? _refreshDebounce;
  static const Duration _refreshDebounceDuration = Duration(milliseconds: 250);

  void _requestRefresh() {
    if (_isDisposed) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(_refreshDebounceDuration, () {
      if (_isDisposed) return;
      refresh();
    });
  }

  void _onRoutineChangedNotification() {
    if (_isDisposed) return;
    _requestRefresh();
  }

  void _handleEvent(RitmoEvent event) {
    if (_isDisposed) return;
    if (!_refreshTriggeringEvents.contains(event.type)) return;

    final payload = event.payload;
    final d = (payload['date'] ?? payload['dateStr']) as String?;
    if (d != null && _windowStart != null && _windowEnd != null) {
      final parsed = DateKey.parse(d);
      if (parsed != null && (parsed.isBefore(_windowStart!) || parsed.isAfter(_windowEnd!))) {
        return; // Out of currently loaded window; skip expensive reload
      }
    }
    _requestRefresh();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    RitmoEvents.routineChangedNotifier.removeListener(_onRoutineChangedNotification);
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }

  DayAgendaSnapshot _snapshotForSelectedDate() {
    final key = DateKey.of(_selectedDate);
    return _rangeSnapshots[key] ??
        _snapshotBuilder.buildSnapshot(DayAgenda(dateStr: key, items: const []));
  }

  @visibleForTesting
  static ({DateTime start, DateTime end}) calculateDateRangeForScale(JourneyScale scale, DateTime date) =>
      _calculateDateRangeForScale(scale, date);

  static ({DateTime start, DateTime end}) _calculateDateRangeForScale(JourneyScale scale, DateTime date) {
    final dateOnly = DateKey.dayOf(date);
    final j = Jalali.fromDateTime(dateOnly);
    switch (scale) {
      case JourneyScale.agenda:
        // مقیاس اجندا بازهٔ خودش را دارد (loadAgendaRange) و هرگز به اینجا نمی‌رسد.
        /// معوقه فقط تا agendaWindowDaysBack روز عقب دیده می‌شود. CAL-38 سقف را برمی‌دارد.
        throw StateError('agenda scale must use loadAgendaRange');
      case JourneyScale.day:
        return (start: dateOnly, end: dateOnly);
      case JourneyScale.week:
        final sat = ShamsiWeek.saturdayOf(dateOnly);
        final fri = DateKey.addDays(sat, 6);
        return (start: sat, end: fri);
      case JourneyScale.month:
        final startJ = Jalali(j.year, j.month, 1);
        final endJ = Jalali(j.year, j.month, startJ.monthLength);
        return (start: startJ.toDateTime(), end: endJ.toDateTime());
      case JourneyScale.year:
        final startJ = Jalali(j.year, 1, 1);
        final endJ = Jalali(j.year, 12, Jalali(j.year, 12, 1).monthLength);
        return (start: startJ.toDateTime(), end: endJ.toDateTime());
    }
  }

  Future<void> scheduleItem(AgendaItem item, int startMinutes, int durationMinutes) async {
    if (_isDisposed || _isExecutingAction) return;
    _isExecutingAction = true;
    notifyListeners();

    final newTimeStr = TimeOfDayMinutes.format(startMinutes);
    try {
      final command = _ScheduleItemCommand(
        actionHandler: _actionHandler,
        item: item,
        newTimeOfDay: newTimeStr,
        newDurationMinutes: durationMinutes,
      );
      await command.execute();
      CommandStack.instance.push(command);
      RitmoHapticsPolicy.success();
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      _errorMessage = CalendarMessagesFa.schedule;
      RitmoLog.error('JourneyController', 'scheduleItem failed', e, stackTrace);
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        cancelManipulation();
      }
    }
  }

  Future<void> unscheduleItem(AgendaItem item) async {
    if (_isDisposed || _isExecutingAction) return;
    _isExecutingAction = true;
    notifyListeners();

    try {
      final command = _UnscheduleItemCommand(
        actionHandler: _actionHandler,
        item: item,
        oldTimeOfDay: item.timeOfDay,
        oldDurationMinutes: item.durationMinutes,
      );
      await command.execute();
      CommandStack.instance.push(command);
      RitmoHapticsPolicy.success();
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      _errorMessage = CalendarMessagesFa.unschedule;
      RitmoLog.error('JourneyController', 'unscheduleItem failed', e, stackTrace);
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        cancelManipulation();
      }
    }
  }

  Future<void> moveItemToDate(AgendaItem item, DateTime targetDate) async {
    if (_isDisposed || _isExecutingAction) return;
    final targetDateStr = DateKey.of(targetDate);
    if (targetDateStr == item.dateStr) return;

    _isExecutingAction = true;
    notifyListeners();

    try {
      final command = _MoveItemToDateCommand(
        item: item,
        targetDate: targetDate,
        overrideRepo: _overrideRepo,
      );
      await command.execute();
      CommandStack.instance.push(command);
      RitmoHapticsPolicy.success();
      await refresh();
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      _errorMessage = 'خطا در انتقال رویداد به تاریخ دیگر';
      RitmoLog.error('JourneyController', 'moveItemToDate failed', e, stackTrace);
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        notifyListeners();
      }
    }
  }

  Future<void> setDayMark(DayMarkKind kind, {DayMarkRepository? dayMarkRepo}) async {
    if (_isDisposed || _isExecutingAction) return;
    final dateStr = DateKey.of(_selectedDate);
    final prevKind = _currentDayMark;
    if (prevKind == kind) return;

    _isExecutingAction = true;
    notifyListeners();

    try {
      final repo = dayMarkRepo ?? _dayMarkRepo;
      final command = _SetDayMarkCommand(
        dayMarkRepo: repo,
        dateStr: dateStr,
        newKind: kind,
        previousKind: prevKind,
      );
      await command.execute();
      _currentDayMark = kind;
      CommandStack.instance.push(command);
      RitmoHapticsPolicy.success();
      await refresh();
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      _errorMessage = 'خطا در تغییر وضعیت روز';
      RitmoLog.error('JourneyController', 'setDayMark failed', e, stackTrace);
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        notifyListeners();
      }
    }
  }

  Future<DayTemplate?> saveCurrentDayAsTemplate(String templateName, {DayTemplateRepository? templateRepo}) async {
    if (_snapshot == null || _snapshot!.items.isEmpty) return null;
    final timedItems = _snapshot!.items.where((i) => i.isTimed).toList();
    if (timedItems.isEmpty) return null;

    final slots = timedItems.map((item) {
      return DayTemplateSlot(
        title: item.title,
        timeOfDay: item.timeOfDay ?? CalendarDefaults.fallbackTimeOfDay,
        durationMinutes: DurationBounds.sanitize(item.durationMinutes),
        domainName: item.domain.name,
        kindName: item.kind.name,
        categoryName: item.category.name,
        sourceId: item.sourceId,
      );
    }).toList();

    final template = DayTemplate(
      id: 'dt_${DateTime.now().millisecondsSinceEpoch}',
      name: templateName.trim().isEmpty ? 'قالب بدون نام' : templateName.trim(),
      slots: slots,
      createdAt: DateTime.now(),
    );

    final repo = templateRepo ?? DayTemplateRepository();
    await repo.saveTemplate(template);
    return template;
  }

  Future<bool> applyTemplate(DayTemplate template) async {
    if (_isDisposed || _isExecutingAction) return false;
    _isExecutingAction = true;
    notifyListeners();

    try {
      final dateStr = DateKey.of(_selectedDate);
      final currentItems = _snapshot?.items ?? const <AgendaItem>[];
      if (currentItems.isEmpty || template.slots.isEmpty) {
        _isExecutingAction = false;
        notifyListeners();
        return false;
      }

      final mutations = <({AgendaItem item, String newTimeOfDay, int newDurationMinutes, _TemplateItemRestoreState restore})>[];

      for (final slot in template.slots) {
        AgendaItem? match;
        for (final i in currentItems) {
          if ((slot.sourceId != null && i.sourceId == slot.sourceId) ||
              (i.title == slot.title && (slot.domainName == null || i.domain.name == slot.domainName))) {
            match = i;
            break;
          }
        }

        if (match == null) continue;

        OccurrenceOverride? prevOverride;
        if (match.domain == AgendaDomain.routine) {
          prevOverride = await _overrideRepo.readOne(
            match.domain.name,
            match.sourceId,
            dateStr,
          );
        }

        final restore = _TemplateItemRestoreState(
          item: match,
          previousTimeOfDay: match.timeOfDay,
          previousDurationMinutes: match.durationMinutes,
          previousOverride: prevOverride,
        );

        mutations.add((
          item: match,
          newTimeOfDay: slot.timeOfDay,
          newDurationMinutes: slot.durationMinutes,
          restore: restore,
        ));
      }

      if (mutations.isEmpty) {
        _isExecutingAction = false;
        notifyListeners();
        return false;
      }

      final command = _ApplyDayTemplateCommand(
        actionHandler: _actionHandler,
        overrideRepo: _overrideRepo,
        template: template,
        targetDateStr: dateStr,
        mutations: mutations,
      );

      await command.execute();
      CommandStack.instance.push(command);
      RitmoHapticsPolicy.success();
      await refresh();
      return true;
    } catch (e, stackTrace) {
      RitmoLog.error('JourneyController', 'applyTemplate failed', e, stackTrace);
      _errorMessage = 'خطا در اعمال قالب روز';
      return false;
    } finally {
      if (!_isDisposed) {
        _isExecutingAction = false;
        notifyListeners();
      }
    }
  }

  void startItemResize(AgendaItem item) {
    if (_isDisposed) return;
    _manipulatingItemId = item.id;
    _isDragging = false;
    _isResizing = true;
    _previewTimeOfDay = item.timeOfDay;
    _previewDurationMinutes = item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes;
    notifyListeners();
  }

  void updateResizePreview(int durationMinutes) {
    if (_isDisposed || _previewDurationMinutes == durationMinutes) return;
    _previewDurationMinutes = durationMinutes;
    notifyListeners();
  }

  @visibleForTesting
  static UndoableCommand createMoveItemCommand({
    required AgendaActionHandler actionHandler,
    required AgendaItem item,
    required String oldTimeOfDay,
    required String newTimeOfDay,
    CalendarEditScope scope = CalendarEditScope.thisDayOnly,
    OccurrenceOverrideRepository? overrideRepo,
  }) => _MoveItemCommand(
    actionHandler: actionHandler,
    item: item,
    oldTimeOfDay: oldTimeOfDay,
    newTimeOfDay: newTimeOfDay,
    scope: scope,
    overrideRepo: overrideRepo,
  );

  @visibleForTesting
  static UndoableCommand createResizeItemCommand({
    required AgendaActionHandler actionHandler,
    required AgendaItem item,
    required int oldDuration,
    required int newDuration,
    CalendarEditScope scope = CalendarEditScope.thisDayOnly,
    OccurrenceOverrideRepository? overrideRepo,
  }) => _ResizeItemCommand(
    actionHandler: actionHandler,
    item: item,
    oldDuration: oldDuration,
    newDuration: newDuration,
    scope: scope,
    overrideRepo: overrideRepo,
  );

  @visibleForTesting
  static UndoableCommand createSkipItemCommand({
    required AgendaItem item,
    OccurrenceOverrideRepository? overrideRepo,
  }) => _SkipItemCommand(
    item: item,
    overrideRepo: overrideRepo,
  );

  @visibleForTesting
  static UndoableCommand createPostponeItemCommand({
    required AgendaItem item,
    int days = 1,
    OccurrenceOverrideRepository? overrideRepo,
    SimpleTaskRepository? taskRepo,
  }) => _PostponeItemCommand(
    item: item,
    days: days,
    overrideRepo: overrideRepo,
    taskRepo: taskRepo,
  );
}

enum CalendarEditScope { thisDayOnly, allFutureDays }

abstract class _CalendarCommand implements UndoableCommand {
  _CalendarCommand({
    required this.item,
  });

  final AgendaItem item;

  /// Subclasses specify whether they modify multiple days (e.g. allFutureDays).
  bool get affectsMultipleDays => false;

  /// Pure command business logic forward.
  Future<void> applyForward();

  /// Pure command business logic backward (undo).
  Future<void> applyBackward();

  @override
  Future<void> execute() async {
    await applyForward();
    _invalidateCacheAndNotify();
  }

  @override
  Future<void> undo() async {
    await applyBackward();
    _invalidateCacheAndNotify();
  }

  void _invalidateCacheAndNotify() {
    if (affectsMultipleDays) {
      DayAgendaService.instance.invalidateAll();
    } else {
      DayAgendaService.instance.invalidateDate(item.dateStr);
    }
    RitmoEvents.notifyRoutineChanged();
  }
}

class _MoveItemCommand extends _CalendarCommand {
  _MoveItemCommand({
    required this.actionHandler,
    required super.item,
    required this.oldTimeOfDay,
    required this.newTimeOfDay,
    this.scope = CalendarEditScope.thisDayOnly,
    OccurrenceOverrideRepository? overrideRepo,
  }) : _overrideRepo = overrideRepo ?? const SqliteOccurrenceOverrideRepository();

  final AgendaActionHandler actionHandler;
  final String oldTimeOfDay;
  final String newTimeOfDay;
  final CalendarEditScope scope;
  final OccurrenceOverrideRepository _overrideRepo;

  OccurrenceOverride? _beforeSnapshot;
  List<OccurrenceOverride> _futureSnapshot = const [];
  bool _hasCapturedBefore = false;

  @override
  bool get affectsMultipleDays => scope == CalendarEditScope.allFutureDays;

  @override
  String get description => 'جابه‌جایی رویداد';

  @override
  Future<void> applyForward() async {
    if (!_hasCapturedBefore) {
      if (scope == CalendarEditScope.thisDayOnly) {
        _beforeSnapshot = await _overrideRepo.readOne(
          item.domain.name,
          item.sourceId,
          item.dateStr,
        );
      } else {
        final parsedDate = DateKey.parse(item.dateStr) ?? DateTime.now();
        final untilDateStr = DateKey.of(DateKey.addDays(parsedDate, 366));
        _futureSnapshot = await _overrideRepo.readAllFuture(
          item.domain.name,
          item.sourceId,
          item.dateStr,
          untilDateStr: untilDateStr,
        );
      }
      _hasCapturedBefore = true;
    }

    final nowIso = DateTime.now().toIso8601String();
    if (scope == CalendarEditScope.thisDayOnly) {
      final override = OccurrenceOverride(
        sourceType: item.domain.name,
        sourceId: item.sourceId,
        dateStr: item.dateStr,
        timeOfDay: newTimeOfDay,
        status: 'MOVED',
        createdAt: nowIso,
        updatedAt: nowIso,
      );
      await _overrideRepo.upsert(override);
    } else {
      final parsedDate = DateKey.parse(item.dateStr) ?? DateTime.now();
      final untilDateStr = DateKey.of(DateKey.addDays(parsedDate, 366));
      await _overrideRepo.removeAllFuture(
        item.domain.name,
        item.sourceId,
        item.dateStr,
        untilDateStr: untilDateStr,
      );
      await actionHandler.updateAgendaItemTimeAndDuration(
        item: item,
        newTimeOfDay: newTimeOfDay,
      );
    }
  }

  @override
  Future<void> applyBackward() async {
    if (scope == CalendarEditScope.thisDayOnly) {
      final before = _beforeSnapshot;
      if (before == null) {
        await _overrideRepo.remove(item.domain.name, item.sourceId, item.dateStr);
      } else {
        await _overrideRepo.restoreAll([before]);
      }
    } else {
      await actionHandler.updateAgendaItemTimeAndDuration(
        item: item,
        newTimeOfDay: oldTimeOfDay,
      );
      if (_futureSnapshot.isNotEmpty) {
        await _overrideRepo.restoreAll(_futureSnapshot);
      }
    }
  }
}

class _ResizeItemCommand extends _CalendarCommand {
  _ResizeItemCommand({
    required this.actionHandler,
    required super.item,
    required this.oldDuration,
    required this.newDuration,
    this.scope = CalendarEditScope.thisDayOnly,
    OccurrenceOverrideRepository? overrideRepo,
  }) : _overrideRepo = overrideRepo ?? const SqliteOccurrenceOverrideRepository();

  final AgendaActionHandler actionHandler;
  final int oldDuration;
  final int newDuration;
  final CalendarEditScope scope;
  final OccurrenceOverrideRepository _overrideRepo;

  OccurrenceOverride? _beforeSnapshot;
  List<OccurrenceOverride> _futureSnapshot = const [];
  bool _hasCapturedBefore = false;

  @override
  bool get affectsMultipleDays => scope == CalendarEditScope.allFutureDays;

  @override
  String get description => 'تغییر مدت زمان رویداد';

  @override
  Future<void> applyForward() async {
    if (!_hasCapturedBefore) {
      if (scope == CalendarEditScope.thisDayOnly) {
        _beforeSnapshot = await _overrideRepo.readOne(
          item.domain.name,
          item.sourceId,
          item.dateStr,
        );
      } else {
        final parsedDate = DateKey.parse(item.dateStr) ?? DateTime.now();
        final untilDateStr = DateKey.of(DateKey.addDays(parsedDate, 366));
        _futureSnapshot = await _overrideRepo.readAllFuture(
          item.domain.name,
          item.sourceId,
          item.dateStr,
          untilDateStr: untilDateStr,
        );
      }
      _hasCapturedBefore = true;
    }

    final nowIso = DateTime.now().toIso8601String();
    if (scope == CalendarEditScope.thisDayOnly) {
      final override = OccurrenceOverride(
        sourceType: item.domain.name,
        sourceId: item.sourceId,
        dateStr: item.dateStr,
        durationMinutes: newDuration,
        status: 'RESIZED',
        createdAt: nowIso,
        updatedAt: nowIso,
      );
      await _overrideRepo.upsert(override);
    } else {
      final parsedDate = DateKey.parse(item.dateStr) ?? DateTime.now();
      final untilDateStr = DateKey.of(DateKey.addDays(parsedDate, 366));
      await _overrideRepo.removeAllFuture(
        item.domain.name,
        item.sourceId,
        item.dateStr,
        untilDateStr: untilDateStr,
      );
      await actionHandler.updateAgendaItemTimeAndDuration(
        item: item,
        newDurationMinutes: newDuration,
      );
    }
  }

  @override
  Future<void> applyBackward() async {
    if (scope == CalendarEditScope.thisDayOnly) {
      final before = _beforeSnapshot;
      if (before == null) {
        await _overrideRepo.remove(item.domain.name, item.sourceId, item.dateStr);
      } else {
        await _overrideRepo.restoreAll([before]);
      }
    } else {
      await actionHandler.updateAgendaItemTimeAndDuration(
        item: item,
        newDurationMinutes: oldDuration,
      );
      if (_futureSnapshot.isNotEmpty) {
        await _overrideRepo.restoreAll(_futureSnapshot);
      }
    }
  }
}

class _ScheduleItemCommand extends _CalendarCommand {
  _ScheduleItemCommand({
    required this.actionHandler,
    required super.item,
    required this.newTimeOfDay,
    required this.newDurationMinutes,
  });

  final AgendaActionHandler actionHandler;
  final String newTimeOfDay;
  final int newDurationMinutes;

  @override
  String get description => 'زمان‌بندی رویداد';

  @override
  Future<void> applyForward() async {
    await actionHandler.updateAgendaItemTimeAndDuration(
      item: item,
      newTimeOfDay: newTimeOfDay,
      newDurationMinutes: newDurationMinutes,
    );
  }

  @override
  Future<void> applyBackward() async {
    await actionHandler.clearAgendaItemTime(item: item);
  }
}

class _UnscheduleItemCommand extends _CalendarCommand {
  _UnscheduleItemCommand({
    required this.actionHandler,
    required super.item,
    required this.oldTimeOfDay,
    required this.oldDurationMinutes,
  });

  final AgendaActionHandler actionHandler;
  final String? oldTimeOfDay;
  final int? oldDurationMinutes;

  @override
  String get description => 'لغو زمان‌بندی رویداد';

  @override
  Future<void> applyForward() async {
    await actionHandler.clearAgendaItemTime(item: item);
  }

  @override
  Future<void> applyBackward() async {
    if (oldTimeOfDay != null) {
      await actionHandler.updateAgendaItemTimeAndDuration(
        item: item,
        newTimeOfDay: oldTimeOfDay,
        newDurationMinutes: oldDurationMinutes,
      );
    }
  }
}

class _SkipRoutineCommand extends _CalendarCommand {
  _SkipRoutineCommand({
    required super.item,
    required this.kernel,
  });

  final RitmoExecutionKernel kernel;

  @override
  String get description => 'رد کردن روتین';

  @override
  Future<void> applyForward() async {
    await kernel.execute(SkipOccurrenceCommand(
      routineId: item.sourceId,
      dateStr: item.dateStr,
      reason: 'Skipped via Calendar',
    ));
  }

  @override
  Future<void> applyBackward() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'routine_completions',
      where: 'routineId = ? AND dateStr = ? AND status = ?',
      whereArgs: [item.sourceId, item.dateStr, 'SKIPPED'],
    );
  }
}

class _SkipItemCommand extends _CalendarCommand {
  _SkipItemCommand({
    required super.item,
    OccurrenceOverrideRepository? overrideRepo,
  }) : _overrideRepo = overrideRepo ?? const SqliteOccurrenceOverrideRepository();

  final OccurrenceOverrideRepository _overrideRepo;
  OccurrenceOverride? _beforeSnapshot;
  bool _hasCapturedBefore = false;

  @override
  String get description => 'رد کردن رویداد';

  @override
  Future<void> applyForward() async {
    if (!_hasCapturedBefore) {
      _beforeSnapshot = await _overrideRepo.readOne(
        item.domain.name,
        item.sourceId,
        item.dateStr,
      );
      _hasCapturedBefore = true;
    }

    final nowIso = DateTime.now().toIso8601String();
    final override = OccurrenceOverride(
      sourceType: item.domain.name,
      sourceId: item.sourceId,
      dateStr: item.dateStr,
      status: 'SKIPPED',
      createdAt: nowIso,
      updatedAt: nowIso,
    );
    await _overrideRepo.upsert(override);
  }

  @override
  Future<void> applyBackward() async {
    final before = _beforeSnapshot;
    if (before == null) {
      await _overrideRepo.remove(item.domain.name, item.sourceId, item.dateStr);
    } else {
      await _overrideRepo.restoreAll([before]);
    }
  }
}

class _PostponeItemCommand extends _CalendarCommand {
  _PostponeItemCommand({
    required super.item,
    required this.days,
    OccurrenceOverrideRepository? overrideRepo,
    SimpleTaskRepository? taskRepo,
  })  : _overrideRepo = overrideRepo ?? const SqliteOccurrenceOverrideRepository(),
        _taskRepo = taskRepo ?? SimpleTaskRepository.instance;

  final int days;
  final OccurrenceOverrideRepository _overrideRepo;
  final SimpleTaskRepository _taskRepo;

  @override
  bool get affectsMultipleDays => true;

  @override
  String get description => 'به تعویق انداختن رویداد';

  String? _originalTaskDueDate;
  OccurrenceOverride? _sourceDayBeforeSnapshot;
  OccurrenceOverride? _targetDayBeforeSnapshot;
  String? _targetDateStr;
  bool _hasCapturedBefore = false;

  @override
  Future<void> applyForward() async {
    final today = DateKey.dayOf(DateTime.now());

    if (item.domain == AgendaDomain.task) {
      final task = await _taskRepo.getById(item.sourceId);
      if (task == null) {
        throw StateError('Task ${item.sourceId} not found');
      }

      if (!_hasCapturedBefore) {
        _originalTaskDueDate = task.dueDate;
        _hasCapturedBefore = true;
      }

      final due = DateKey.parse(task.dueDate ?? item.dateStr) ?? today;
      final base = due.isBefore(today) ? today : due;
      final next = DateKey.addDays(base, days);
      final nextDateStr = DateKey.of(next);
      _targetDateStr = nextDateStr;

      await _taskRepo.updateTask(task.copyWith(dueDate: nextDateStr));
    } else {
      final srcDate = DateKey.parse(item.dateStr) ?? today;
      final base = srcDate.isBefore(today) ? today : srcDate;
      final next = DateKey.addDays(base, days);
      final nextDateStr = DateKey.of(next);
      _targetDateStr = nextDateStr;

      if (!_hasCapturedBefore) {
        _sourceDayBeforeSnapshot = await _overrideRepo.readOne(
          item.domain.name,
          item.sourceId,
          item.dateStr,
        );
        _targetDayBeforeSnapshot = await _overrideRepo.readOne(
          item.domain.name,
          item.sourceId,
          nextDateStr,
        );
        _hasCapturedBefore = true;
      }

      final nowIso = DateTime.now().toIso8601String();

      // 1. Source day: SKIPPED
      final skipOverride = OccurrenceOverride(
        sourceType: item.domain.name,
        sourceId: item.sourceId,
        dateStr: item.dateStr,
        status: 'SKIPPED',
        createdAt: nowIso,
        updatedAt: nowIso,
      );

      // 2. Target day: MOVED with original timeOfDay and durationMinutes
      final targetOverride = OccurrenceOverride(
        sourceType: item.domain.name,
        sourceId: item.sourceId,
        dateStr: nextDateStr,
        timeOfDay: item.timeOfDay,
        durationMinutes: item.durationMinutes,
        status: 'MOVED',
        createdAt: nowIso,
        updatedAt: nowIso,
      );

      await _overrideRepo.upsert(skipOverride);
      await _overrideRepo.upsert(targetOverride);
    }
  }

  @override
  Future<void> applyBackward() async {
    if (item.domain == AgendaDomain.task) {
      final task = await _taskRepo.getById(item.sourceId);
      if (task != null) {
        await _taskRepo.updateTask(task.copyWith(dueDate: _originalTaskDueDate));
      }
    } else {
      // Revert source day override
      final srcBefore = _sourceDayBeforeSnapshot;
      if (srcBefore == null) {
        await _overrideRepo.remove(item.domain.name, item.sourceId, item.dateStr);
      } else {
        await _overrideRepo.restoreAll([srcBefore]);
      }

      // Revert target day override
      final targetDate = _targetDateStr;
      if (targetDate != null) {
        final tgtBefore = _targetDayBeforeSnapshot;
        if (tgtBefore == null) {
          await _overrideRepo.remove(item.domain.name, item.sourceId, targetDate);
        } else {
          await _overrideRepo.restoreAll([tgtBefore]);
        }
      }
    }
  }
}

class _MoveItemToDateCommand extends _CalendarCommand {
  _MoveItemToDateCommand({
    required super.item,
    required this.targetDate,
    OccurrenceOverrideRepository? overrideRepo,
    SimpleTaskRepository? taskRepo,
  })  : _overrideRepo = overrideRepo ?? const SqliteOccurrenceOverrideRepository(),
        _taskRepo = taskRepo ?? SimpleTaskRepository.instance;

  final DateTime targetDate;
  final OccurrenceOverrideRepository _overrideRepo;
  final SimpleTaskRepository _taskRepo;

  @override
  bool get affectsMultipleDays => true;

  @override
  String get description => 'انتقال رویداد به تاریخ دیگر';

  String? _originalTaskDueDate;
  OccurrenceOverride? _sourceDayBeforeSnapshot;
  OccurrenceOverride? _targetDayBeforeSnapshot;
  String? _targetDateStr;
  bool _hasCapturedBefore = false;

  @override
  Future<void> applyForward() async {
    final nextDateStr = DateKey.of(targetDate);
    _targetDateStr = nextDateStr;

    if (item.domain == AgendaDomain.task) {
      final task = await _taskRepo.getById(item.sourceId);
      if (task == null) {
        throw StateError('Task ${item.sourceId} not found');
      }

      if (!_hasCapturedBefore) {
        _originalTaskDueDate = task.dueDate;
        _hasCapturedBefore = true;
      }

      await _taskRepo.updateTask(task.copyWith(dueDate: nextDateStr));
    } else {
      if (!_hasCapturedBefore) {
        _sourceDayBeforeSnapshot = await _overrideRepo.readOne(
          item.domain.name,
          item.sourceId,
          item.dateStr,
        );
        _targetDayBeforeSnapshot = await _overrideRepo.readOne(
          item.domain.name,
          item.sourceId,
          nextDateStr,
        );
        _hasCapturedBefore = true;
      }

      final nowIso = DateTime.now().toIso8601String();

      // 1. Source day: SKIPPED
      final skipOverride = OccurrenceOverride(
        sourceType: item.domain.name,
        sourceId: item.sourceId,
        dateStr: item.dateStr,
        status: 'SKIPPED',
        createdAt: nowIso,
        updatedAt: nowIso,
      );

      // 2. Target day: MOVED with original timeOfDay and durationMinutes
      final targetOverride = OccurrenceOverride(
        sourceType: item.domain.name,
        sourceId: item.sourceId,
        dateStr: nextDateStr,
        timeOfDay: item.timeOfDay,
        durationMinutes: item.durationMinutes,
        status: 'MOVED',
        createdAt: nowIso,
        updatedAt: nowIso,
      );

      await _overrideRepo.upsert(skipOverride);
      await _overrideRepo.upsert(targetOverride);
    }
  }

  @override
  Future<void> applyBackward() async {
    if (item.domain == AgendaDomain.task) {
      final task = await _taskRepo.getById(item.sourceId);
      if (task != null) {
        await _taskRepo.updateTask(task.copyWith(dueDate: _originalTaskDueDate));
      }
    } else {
      // Revert source day override
      final srcBefore = _sourceDayBeforeSnapshot;
      if (srcBefore == null) {
        await _overrideRepo.remove(item.domain.name, item.sourceId, item.dateStr);
      } else {
        await _overrideRepo.restoreAll([srcBefore]);
      }

      // Revert target day override
      final targetDateStr = _targetDateStr;
      if (targetDateStr != null) {
        final tgtBefore = _targetDayBeforeSnapshot;
        if (tgtBefore == null) {
          await _overrideRepo.remove(item.domain.name, item.sourceId, targetDateStr);
        } else {
          await _overrideRepo.restoreAll([tgtBefore]);
        }
      }
    }
  }
}

class _TemplateItemRestoreState {
  _TemplateItemRestoreState({
    required this.item,
    required this.previousTimeOfDay,
    required this.previousDurationMinutes,
    required this.previousOverride,
  });

  final AgendaItem item;
  final String? previousTimeOfDay;
  final int? previousDurationMinutes;
  final OccurrenceOverride? previousOverride;
}

class _ApplyDayTemplateCommand implements UndoableCommand {
  _ApplyDayTemplateCommand({
    required this.actionHandler,
    required this.overrideRepo,
    required this.template,
    required this.targetDateStr,
    required this.mutations,
  });

  final AgendaActionHandler actionHandler;
  final OccurrenceOverrideRepository overrideRepo;
  final DayTemplate template;
  final String targetDateStr;
  final List<({AgendaItem item, String newTimeOfDay, int newDurationMinutes, _TemplateItemRestoreState restore})> mutations;

  @override
  String get description => 'اعمال قالب «${template.name}»';

  @override
  Future<void> execute() async {
    final nowIso = DateTime.now().toIso8601String();
    for (final m in mutations) {
      if (m.item.domain == AgendaDomain.routine) {
        final override = OccurrenceOverride(
          sourceType: m.item.domain.name,
          sourceId: m.item.sourceId,
          dateStr: targetDateStr,
          timeOfDay: m.newTimeOfDay,
          durationMinutes: m.newDurationMinutes,
          status: 'MODIFIED',
          createdAt: nowIso,
          updatedAt: nowIso,
        );
        await overrideRepo.upsert(override);
      } else {
        await actionHandler.updateAgendaItemTimeAndDuration(
          item: m.item,
          newTimeOfDay: m.newTimeOfDay,
          newDurationMinutes: m.newDurationMinutes,
        );
      }
    }
    DayAgendaService.instance.invalidateDate(targetDateStr);
    RitmoEvents.notifyRoutineChanged();
  }

  @override
  Future<void> undo() async {
    for (final m in mutations) {
      if (m.item.domain == AgendaDomain.routine) {
        final prev = m.restore.previousOverride;
        if (prev != null) {
          await overrideRepo.upsert(prev);
        } else {
          await overrideRepo.remove(
            m.item.domain.name,
            m.item.sourceId,
            targetDateStr,
          );
        }
      } else {
        await actionHandler.updateAgendaItemTimeAndDuration(
          item: m.item,
          newTimeOfDay: m.restore.previousTimeOfDay,
          newDurationMinutes: m.restore.previousDurationMinutes,
        );
      }
    }
    DayAgendaService.instance.invalidateDate(targetDateStr);
    RitmoEvents.notifyRoutineChanged();
  }
}

class _SetDayMarkCommand implements UndoableCommand {
  _SetDayMarkCommand({
    required this.dayMarkRepo,
    required this.dateStr,
    required this.newKind,
    required this.previousKind,
  });

  final DayMarkRepository dayMarkRepo;
  final String dateStr;
  final DayMarkKind newKind;
  final DayMarkKind previousKind;

  @override
  String get description {
    switch (newKind) {
      case DayMarkKind.rest:
        return 'علامت‌گذاری روز استراحت';
      case DayMarkKind.travel:
        return 'علامت‌گذاری روز سفر';
      case DayMarkKind.special:
        return 'علامت‌گذاری روز ویژه';
      case DayMarkKind.normal:
        return 'تغییر وضعیت به روز عادی';
    }
  }

  @override
  Future<void> execute() async {
    await dayMarkRepo.setMark(dateStr, newKind);
    DayAgendaService.instance.invalidateDate(dateStr);
    RitmoEvents.notifyRoutineChanged();
  }

  @override
  Future<void> undo() async {
    await dayMarkRepo.setMark(dateStr, previousKind);
    DayAgendaService.instance.invalidateDate(dateStr);
    RitmoEvents.notifyRoutineChanged();
  }
}
