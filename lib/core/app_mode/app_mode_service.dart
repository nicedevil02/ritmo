import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/settings/settings_service.dart';

enum AppMode { simple, full }

class AppModeService {
  AppModeService._();
  static final AppModeService instance = AppModeService._();

  final ValueNotifier<AppMode> notifier = ValueNotifier(AppMode.full);

  AppMode _current = AppMode.full;

  Future<void> load() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: "key = 'app_mode'",
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final val = (rows.first['value'] as String?)?.toUpperCase();
        if (val == 'SIMPLE') {
          _current = AppMode.simple;
        } else {
          _current = AppMode.full;
        }
      } else {
        _current = AppMode.full;
      }
      notifier.value = _current;
    } catch (e) {
      _current = AppMode.full;
      notifier.value = _current;
    }
  }

  AppMode get current => _current;

  bool get isSimple {
    try {
      final s = SettingsService.instance.get<String>('app_mode').toLowerCase();
      if (s == 'simple') return true;
      if (s == 'full') return false;
    } catch (_) {}
    return _current == AppMode.simple;
  }

  void syncFromSettings(String modeStr) {
    final mode = modeStr.toLowerCase() == 'simple' ? AppMode.simple : AppMode.full;
    _current = mode;
    notifier.value = mode;
  }

  Future<void> set(AppMode mode) async {
    _current = mode;
    notifier.value = mode;
    final modeStr = mode == AppMode.full ? 'full' : 'simple';
    try {
      await SettingsService.instance.set('app_mode', modeStr);
    } catch (_) {}

    RitmoEventBus().fire(RitmoEvent(
      type: 'app_mode_changed',
      timestamp: DateTime.now(),
      payload: {'mode': modeStr.toUpperCase()},
    ));
  }
}
