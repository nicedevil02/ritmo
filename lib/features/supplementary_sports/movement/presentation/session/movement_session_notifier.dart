// lib/features/supplementary_sports/movement/presentation/session/movement_session_notifier.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_session_repository.dart';

class MovementSessionNotifier extends ChangeNotifier {
  MovementSessionNotifier(this.session) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // هیچ state جدیدی ساخته نمی‌شود؛ فقط خبر بازترسیم.
      notifyListeners();
    });
  }

  MovementSession session;
  Timer? _ticker;

  /// تنها منبع حقیقت زمان — wall clock.
  int get elapsedMs => session.elapsedMs;

  bool get isPaused => session.status == MovementSessionStatus.paused;

  Future<void> pause() async {
    await MovementSessionRepository.instance.pauseSession(session.id);
    final updated = await MovementSessionRepository.instance.getActiveSession();
    if (updated != null) {
      session = updated;
    }
    notifyListeners();
  }

  Future<void> resume() async {
    await MovementSessionRepository.instance.resumeSession(session.id);
    final updated = await MovementSessionRepository.instance.getActiveSession();
    if (updated != null) {
      session = updated;
    }
    notifyListeners();
  }

  Future<void> finish({String? feeling, String? note}) async {
    _ticker?.cancel();
    await MovementSessionRepository.instance.finishSession(session.id, feeling: feeling, note: note);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
