// =============================================================================
//  Ritmo Orb Clock — یک ساعت برای همهٔ تیله‌ها
//  قبلاً هر تیله ticker خودش را داشت و هیچ‌وقت هم خاموش نمی‌شد. حالا یک ticker
//  مشترک هست که: تا مشترکی نباشد شروع نمی‌شود، اپ که برود پس‌زمینه می‌ایستد،
//  و هر مشترک می‌تواند نرخِ فریمِ خودش را کم کند (ردهٔ S روی ۲۴ فریم).
// =============================================================================

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';

class _Slot {
  _Slot(this.interval);

  final double interval;
  double due = 0.0;
}

class RitmoOrbClock with WidgetsBindingObserver {
  RitmoOrbClock._();

  static final RitmoOrbClock instance = RitmoOrbClock._();

  final Map<VoidCallback, _Slot> _subs = <VoidCallback, _Slot>{};
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double _time = 0.0;
  bool _foreground = true;
  bool _observing = false;

  /// زمانِ پیوسته بر حسب ثانیه. وقتی اپ پس‌زمینه است جلو نمی‌رود.
  double get time => _time;

  @visibleForTesting
  int get subscriberCount => _subs.length;

  @visibleForTesting
  bool get isRunning => _ticker != null;

  /// [interval] فاصلهٔ کمینه بین دو صدا زدن؛ ۰ = هر فریم.
  void subscribe(VoidCallback onFrame, {double interval = 0.0}) {
    final _Slot slot = _Slot(interval);
    slot.due = _time;
    _subs[onFrame] = slot;
    _sync();
  }

  void unsubscribe(VoidCallback onFrame) {
    if (_subs.remove(onFrame) != null) _sync();
  }

  void _sync() {
    final bool want = _subs.isNotEmpty && _foreground;
    if (want) {
      if (!_observing) {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      }
      if (_ticker == null) {
        _lastTick = Duration.zero;
        final Ticker ticker = Ticker(_onTick, debugLabel: 'RitmoOrbClock');
        _ticker = ticker;
        ticker.start();
      }
      return;
    }
    final Ticker? ticker = _ticker;
    if (ticker != null) {
      ticker.stop();
      ticker.dispose();
      _ticker = null;
      _lastTick = Duration.zero;
    }
    if (_subs.isEmpty && _observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    // پرشِ بزرگ (پس از توقف) هیچ‌وقت به فنرها منتقل نمی‌شود.
    if (dt <= 0.0 || dt > 0.25) dt = 1.0 / 60.0;
    _time += dt;

    final List<MapEntry<VoidCallback, _Slot>> frame =
        _subs.entries.toList(growable: false);
    for (final MapEntry<VoidCallback, _Slot> entry in frame) {
      final _Slot slot = entry.value;
      if (slot.interval > 0.0 && _time < slot.due) continue;
      slot.due = _time + slot.interval;
      // ممکن است مشترک در همین فریم dispose شود؛ آن‌وقت دیگر صدایش نمی‌زنیم.
      if (_subs.containsKey(entry.key)) entry.key();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool next = state == AppLifecycleState.resumed;
    if (next == _foreground) return;
    _foreground = next;
    _sync();
  }

  @visibleForTesting
  void debugReset() {
    _subs.clear();
    _foreground = true;
    _time = 0.0;
    _sync();
  }
}
