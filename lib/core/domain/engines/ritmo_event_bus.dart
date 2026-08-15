import 'dart:async';

import 'package:flutter/foundation.dart';

enum RitmoEventType {
  routineCreated('RoutineCreated'),
  routineUpdated('RoutineUpdated'),
  routineDeleted('RoutineDeleted'),
  occurrenceCompleted('OccurrenceCompleted'),
  occurrenceSkipped('OccurrenceSkipped'),
  reshuffleConfirmed('ReshuffleConfirmed'),
  goalChanged('GoalChanged'),
  goalStepToggled('GoalStepToggled'),
  worshipChanged('WorshipChanged'),
  worshipPracticeChanged('WorshipPracticeChanged'),
  workoutLogChanged('WorkoutLogChanged'),
  reflectionSaved('ReflectionSaved'),
  completionRecorded('CompletionRecorded'),
  completionDeleted('CompletionDeleted'),
  konkurItemChanged('KonkurItemChanged'),
  energyLogged('EnergyLogged'),
  sleepLogged('SleepLogged'),
  moodLogged('MoodLogged'),
  zoneChanged('ZoneChanged'),
  cycleStarted('CycleStarted'),
  cycleEnded('CycleEnded'),
  medicineTaken('MedicineTaken'),
  courseSessionCompleted('CourseSessionCompleted'),
  dayRolledOver('DayRolledOver'),
  dataImported('DataImported'),
  settingsChanged('SettingsChanged'),
  noteCreated('NoteCreated'),
  noteUpdated('NoteUpdated'),
  noteDeleted('NoteDeleted'),
  experienceCreated('ExperienceCreated');


  const RitmoEventType(this.code);
  final String code;
}

class RitmoEvent {
  RitmoEvent({
    required this.type,
    required this.timestamp,
    required this.payload,
  });

  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  @override
  String toString() => 'RitmoEvent(type: $type, timestamp: $timestamp, payload: $payload)';
}

class RitmoEventBus {
  factory RitmoEventBus() => _instance;
  RitmoEventBus._internal();
  static final RitmoEventBus _instance = RitmoEventBus._internal();

  final _controller = StreamController<RitmoEvent>.broadcast();

  Stream<RitmoEvent> get onEvents => _controller.stream;

  /// Storm protection (per event type, per second).
  ///
  /// Listeners of this bus refresh the whole UI, and some of them write to the
  /// database while doing so - which fires new events. That closes a feedback
  /// loop: bus -> UI refresh -> write -> bus. Because a broadcast controller
  /// buffers whatever it cannot deliver yet, such a loop runs entirely inside
  /// the microtask queue: the event loop never gets control back (the UI
  /// freezes, with no frames rendered and no logs flushed) and every cycle
  /// allocates a fresh controller, snapshot and pending event until the heap is
  /// exhausted.
  ///
  /// No legitimate interaction fires the *same* event type more than a handful
  /// of times per second, so anything past [_maxPerTypePerWindow] is a loop and
  /// not a user. Dropping it breaks the cycle at the only place that observes
  /// all of it, regardless of which component started it.
  static const int _maxPerTypePerWindow = 30;
  static const Duration _window = Duration(seconds: 1);
  static const int _maxTrackedTypes = 128;

  final Map<String, int> _windowStartMs = {};
  final Map<String, int> _windowCount = {};
  final Map<String, int> _windowDropped = {};
  final Map<String, int> _droppedTotal = {};

  /// Diagnostics: events dropped per type since launch. A non-empty map always
  /// means some component is firing in a loop.
  Map<String, int> get droppedEventCounts => Map.unmodifiable(_droppedTotal);

  @visibleForTesting
  void resetStormProtection() {
    _windowStartMs.clear();
    _windowCount.clear();
    _windowDropped.clear();
    _droppedTotal.clear();
  }

  void fire(RitmoEvent event) {
    if (_controller.isClosed) return;
    if (!_admit(event.type)) return;
    _controller.add(event);
  }

  bool _admit(String type) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startMs = _windowStartMs[type];

    if (startMs == null || nowMs - startMs >= _window.inMilliseconds) {
      final dropped = _windowDropped[type] ?? 0;
      if (dropped > 0) {
        debugPrint(
          '[RitmoEventBus] storm protection: dropped $dropped "$type" event(s) '
          'in the last ${_window.inMilliseconds}ms',
        );
      }
      if (_windowStartMs.length > _maxTrackedTypes) {
        _windowStartMs.clear();
        _windowCount.clear();
        _windowDropped.clear();
      }
      _windowStartMs[type] = nowMs;
      _windowCount[type] = 1;
      _windowDropped[type] = 0;
      return true;
    }

    final count = (_windowCount[type] ?? 0) + 1;
    if (count > _maxPerTypePerWindow) {
      if (count == _maxPerTypePerWindow + 1) {
        debugPrint(
          '[RitmoEventBus] storm detected for "$type" '
          '(> $_maxPerTypePerWindow/${_window.inMilliseconds}ms) - throttling. '
          'Something is firing this event from inside its own handler.',
        );
      }
      _windowCount[type] = count;
      _windowDropped[type] = (_windowDropped[type] ?? 0) + 1;
      _droppedTotal[type] = (_droppedTotal[type] ?? 0) + 1;
      return false;
    }

    _windowCount[type] = count;
    return true;
  }
}
