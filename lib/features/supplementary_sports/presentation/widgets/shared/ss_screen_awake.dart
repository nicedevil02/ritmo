import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the device screen awake while a workout session is running.
///
/// `wakelock_plus` is a declared dependency of the app (see pubspec.yaml),
/// so no custom native channel is needed anymore — this replaced the old
/// `ritmo/screen_awake` MethodChannel which was never wired natively.
class SsScreenAwake {
	const SsScreenAwake._();

	static bool _enabled = false;

	static bool get isEnabled => _enabled;

	static Future<void> enable() => _set(true);

	static Future<void> disable() => _set(false);

	static Future<void> _set(bool enabled) async {
		if (_enabled == enabled) return;
		_enabled = enabled;
		try {
			if (enabled) {
				await WakelockPlus.enable();
			} else {
				await WakelockPlus.disable();
			}
		} catch (e) {
			debugPrint('[ss] screen-awake toggle failed: $e');
		}
	}
}
