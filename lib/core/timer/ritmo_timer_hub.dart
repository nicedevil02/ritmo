import 'dart:async';
import 'package:flutter/material.dart';

/// انواع حالت‌های زمانی در اکوسیستم ریتمو
enum RitmoTimerMode {
  /// کرونومتر صعودی (بدون سقف زمانی از پیش تعیین‌شده)
  stopwatch,

  /// فاز تمرکز پومودورو (مثلاً ۲۵ یا ۵۰ دقیقه)
  pomodoroFocus,

  /// فاز استراحت پومودورو (مثلاً ۵ یا ۱۰ دقیقه)
  pomodoroBreak,

  /// تایمر شمارش معکوس با زمان هدف
  countdown,

  /// تایمر بازه‌ای / اینتروال ورزشی
  interval,
}

/// حوزه‌های فعالیت ریتمو برای آیکون و رنگ‌بندی داینامیک
enum RitmoTimerDomain {
  study,
  course,
  konkur,
  sport,
  routine,
  custom,
}

/// مدل جامع نشست فعال تایمر در هاب سراسری
class ActiveLiveTimerSession {
  ActiveLiveTimerSession({
    required this.id,
    required this.domain,
    required this.title,
    this.subtitle,
    this.icon,
    this.accentColor,
    required this.mode,
    this.isRunning = true,
    this.elapsedSeconds = 0,
    this.targetSeconds = 0,
    this.pomodoroCycle = 1,
    this.maxPomodoroCycles = 4,
    this.onPause,
    this.onResume,
    this.onStop,
    this.onSkipPhase,
    this.reopenBuilder,
  });

  final String id;
  final RitmoTimerDomain domain;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final RitmoTimerMode mode;
  bool isRunning;
  int elapsedSeconds;
  final int targetSeconds;
  final int pomodoroCycle;
  final int maxPomodoroCycles;

  final FutureOr<void> Function()? onPause;
  final FutureOr<void> Function()? onResume;
  final FutureOr<void> Function()? onStop;
  final FutureOr<void> Function()? onSkipPhase;
  final void Function(BuildContext context)? reopenBuilder;

  /// درصد پیشرفت از ۰.۰ تا ۱.۰
  double get progress {
    if (targetSeconds <= 0) return 0.0;
    return (elapsedSeconds / targetSeconds).clamp(0.0, 1.0);
  }

  /// ثانیه‌های باقی‌مانده در حالت‌های معکوس و پومودورو
  int get remainingSeconds {
    if (targetSeconds <= 0) return 0;
    final rem = targetSeconds - elapsedSeconds;
    return rem > 0 ? rem : 0;
  }

  /// بررسی اینکه آیا تایمر معکوس به پایان رسیده است
  bool get isCompleted => targetSeconds > 0 && elapsedSeconds >= targetSeconds;

  ActiveLiveTimerSession copyWith({
    String? id,
    RitmoTimerDomain? domain,
    String? title,
    String? subtitle,
    IconData? icon,
    Color? accentColor,
    RitmoTimerMode? mode,
    bool? isRunning,
    int? elapsedSeconds,
    int? targetSeconds,
    int? pomodoroCycle,
    int? maxPomodoroCycles,
    FutureOr<void> Function()? onPause,
    FutureOr<void> Function()? onResume,
    FutureOr<void> Function()? onStop,
    FutureOr<void> Function()? onSkipPhase,
    void Function(BuildContext context)? reopenBuilder,
  }) {
    return ActiveLiveTimerSession(
      id: id ?? this.id,
      domain: domain ?? this.domain,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
      mode: mode ?? this.mode,
      isRunning: isRunning ?? this.isRunning,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      pomodoroCycle: pomodoroCycle ?? this.pomodoroCycle,
      maxPomodoroCycles: maxPomodoroCycles ?? this.maxPomodoroCycles,
      onPause: onPause ?? this.onPause,
      onResume: onResume ?? this.onResume,
      onStop: onStop ?? this.onStop,
      onSkipPhase: onSkipPhase ?? this.onSkipPhase,
      reopenBuilder: reopenBuilder ?? this.reopenBuilder,
    );
  }
}

/// هاب و رجیستری مرکزی و واکنشی تایمرها در اکوسیستم ریتمو
class RitmoTimerHub {
  RitmoTimerHub._();

  static final RitmoTimerHub instance = RitmoTimerHub._();

  final ValueNotifier<ActiveLiveTimerSession?> activeSessionNotifier = ValueNotifier(null);
  final ValueNotifier<int> secondsTickNotifier = ValueNotifier(0);

  Timer? _heartbeatTimer;

  ActiveLiveTimerSession? get currentSession => activeSessionNotifier.value;
  bool get hasActiveSession => activeSessionNotifier.value != null;

  /// شروع یا ثبت یک نشست جدید در هاب مرکزی
  void registerOrUpdateSession(ActiveLiveTimerSession session) {
    activeSessionNotifier.value = session;
    secondsTickNotifier.value = session.elapsedSeconds;
    _ensureHeartbeat();
  }

  /// مکث تایمر جاری
  Future<void> pauseActiveSession() async {
    final session = currentSession;
    if (session == null || !session.isRunning) return;

    session.isRunning = false;
    activeSessionNotifier.value = session.copyWith(isRunning: false);
    _stopHeartbeat();
    await session.onPause?.call();
  }

  /// از سرگیری تایمر جاری
  Future<void> resumeActiveSession() async {
    final session = currentSession;
    if (session == null || session.isRunning) return;

    session.isRunning = true;
    activeSessionNotifier.value = session.copyWith(isRunning: true);
    _ensureHeartbeat();
    await session.onResume?.call();
  }

  /// توقف و اتمام نشست تایمر
  Future<void> stopActiveSession() async {
    final session = currentSession;
    _stopHeartbeat();
    activeSessionNotifier.value = null;
    secondsTickNotifier.value = 0;
    if (session != null) {
      await session.onStop?.call();
    }
  }

  /// تعویض فاز (مخصوص پومودورو و ست‌های ورزشی)
  Future<void> skipPhase() async {
    final session = currentSession;
    if (session != null && session.onSkipPhase != null) {
      await session.onSkipPhase!.call();
    }
  }

  /// بازگشایی رابط کاربری اصلی تایمر
  void reopenActiveSession(BuildContext context) {
    final session = currentSession;
    if (session?.reopenBuilder != null) {
      session!.reopenBuilder!(context);
    }
  }

  /// به‌روزرسانی زمان سپری شده از سرویس‌های زیرمجموعه
  void syncElapsedSeconds(int elapsed, {int? target}) {
    final session = currentSession;
    if (session == null) return;

    session.elapsedSeconds = elapsed;
    secondsTickNotifier.value = elapsed;
    if (target != null && target != session.targetSeconds) {
      activeSessionNotifier.value = session.copyWith(
        elapsedSeconds: elapsed,
        targetSeconds: target,
      );
    }
  }

  void _ensureHeartbeat() {
    _heartbeatTimer?.cancel();
    if (currentSession?.isRunning != true) return;

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = currentSession;
      if (session == null || !session.isRunning) {
        _stopHeartbeat();
        return;
      }

      session.elapsedSeconds += 1;
      secondsTickNotifier.value = session.elapsedSeconds;

      if (session.isCompleted) {
        // در صورت اتمام فاز، اطلاع‌رسانی
        activeSessionNotifier.value = session.copyWith();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
