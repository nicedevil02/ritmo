// گاردِ چهرهٔ تیله: چشم، سوئیچِ خاموشی، و لنگرِ کادرِ تایپ.
//
// دو چیزی که این‌جا محافظت می‌شود، همانی است که اگر بشکند چشم‌ها دوباره
// می‌شوند همان پلکِ عروسکیِ قبل:
//  ۱) بستن باید تندتر از باز شدن باشد.
//  ۲) خاموشی باید واقعاً خاموشی باشد: صفر فریم، صفر فضا.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_clock.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_dock.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_eyes.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_presence.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_settings.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

const RitmoOrbDockAnchorInfo _anchor = RitmoOrbDockAnchorInfo(
  rect: Rect.fromLTRB(14.0, 500.0, 786.0, 556.0),
);

Widget _harness(Widget child, {bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Center(child: child),
    ),
  );
}

Widget _dockHarness({
  required Widget layer,
  Widget? below,
  double keyboard = 300.0,
  bool reduceMotion = false,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(800.0, 600.0),
      disableAnimations: reduceMotion,
      viewInsets: EdgeInsets.only(bottom: keyboard),
    ),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: <Widget>[
          if (below != null) Positioned.fill(child: below),
          layer,
        ],
      ),
    ),
  );
}

RitmoOrbPaintStats _paintEyes(RitmoEyeFrame frame, {double budget = 0.62}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final RitmoOrbPaintStats stats = RitmoOrbPaintStats();
  RitmoOrbPaintStats.active = stats;
  try {
    ritmoPaintEyes(
      canvas,
      center: const Offset(60.0, 60.0),
      span: 26.0,
      radius: 7.0,
      frame: frame,
      palette: RitmoOrbPalette.coral,
      isDark: false,
      purse: RitmoWhitePurse(budget),
    );
  } finally {
    RitmoOrbPaintStats.active = null;
    recorder.endRecording().dispose();
  }
  return stats;
}

void main() {
  setUp(() {
    RitmoOrbClock.instance.debugReset();
    RitmoAiStateService.instance.setTruth(RitmoOrbTruth.confident);
    RitmoOrbEnergySignal.instance.clear();
    RitmoOrbAttentionSignal.instance.relax();
    RitmoOrbSettings.instance.debugReset();
    RitmoOrbDockSignal.instance.clear();
  });

  group('پلک', () {
    test('بستن تنداست، باز شدن کند', () {
      final RitmoEyeLife life = RitmoEyeLife(seed: 5);
      life.debugSnap(open: 1.0, presence: 1.0);
      life.blinkNow(ms: 200.0);

      double? closedAt;
      double? reopenedAt;
      double t = 0.0;
      for (int i = 0; i < 90; i++) {
        life.step(
          0.004,
          tempo: RitmoEyeTempo.rest,
          wantVisible: true,
          always: true,
        );
        t += 4.0;
        if (closedAt == null && life.open <= 0.05) closedAt = t;
        if (closedAt != null && reopenedAt == null && life.open >= 0.98) {
          reopenedAt = t;
        }
      }

      expect(closedAt, isNotNull, reason: 'پلک باید بسته شود');
      expect(reopenedAt, isNotNull, reason: 'و دوباره باز شود');

      final double closeSpan = closedAt!;
      final double openSpan = reopenedAt! - closedAt;
      expect(
        closeSpan,
        lessThan(openSpan),
        reason: 'باز شدنِ هم‌اندازه، پلک را عروسکی می‌کند',
      );
      expect(closeSpan / (closeSpan + openSpan), lessThan(0.48));
    });

    test('دوپلک: آدم‌ها همیشه یک‌دانه پلک نمی‌زنند', () {
      final RitmoEyeLife life = RitmoEyeLife(seed: 9);
      life.debugSnap(open: 1.0, presence: 1.0);
      life.blinkNow(twice: true, ms: 160.0);

      int closures = 0;
      bool closed = false;
      for (int i = 0; i < 200; i++) {
        life.step(
          0.004,
          tempo: RitmoEyeTempo.rest,
          wantVisible: true,
          always: true,
        );
        if (!closed && life.open <= 0.08) {
          closed = true;
          closures++;
        } else if (closed && life.open >= 0.9) {
          closed = false;
        }
      }

      expect(closures, greaterThanOrEqualTo(2));
    });

    test('آفلاین = چشمِ بسته، نه چشمِ نبود', () {
      final RitmoEyeLife life = RitmoEyeLife(seed: 3);
      life.debugSnap(open: 1.0, presence: 1.0);
      for (int i = 0; i < 200; i++) {
        life.step(
          0.016,
          tempo: RitmoEyeTempo.sleep,
          wantVisible: true,
          always: true,
        );
      }

      expect(life.open, lessThan(0.12), reason: 'خوابیده، نه غیب');
      expect(life.presence, greaterThan(0.9));
      expect(life.isBlinking, isFalse);
    });

    test('آهنگِ چشم از امضای حرکت می‌آید، نه از enum', () {
      final RitmoOrbSignature base =
          RitmoOrbSignature.of(RitmoOrbLife.breathing);

      expect(
        RitmoEyeTempo.fromSignature(base, RitmoOrbTruth.offline),
        RitmoEyeTempo.sleep,
      );
      expect(
        RitmoEyeTempo.fromSignature(
          base.copyWith(flow: 1.2, tremor: 0.0),
          RitmoOrbTruth.confident,
        ),
        RitmoEyeTempo.joy,
      );
      expect(
        RitmoEyeTempo.fromSignature(
          base.copyWith(flow: 0.7, tremor: 0.3),
          RitmoOrbTruth.confident,
        ),
        RitmoEyeTempo.think,
      );
      expect(
        RitmoEyeTempo.fromSignature(
          base.copyWith(flow: 0.2, tremor: 0.0),
          RitmoOrbTruth.confident,
        ),
        RitmoEyeTempo.rest,
      );

      // در تمرکز کشیده‌تر و کمتر؛ در شادی تندتر و بیشتر.
      expect(
        RitmoEyeTempo.think.blinkMs,
        greaterThan(RitmoEyeTempo.joy.blinkMs),
      );
      expect(
        RitmoEyeTempo.joy.gapMax,
        lessThan(RitmoEyeTempo.think.gapMax),
      );
    });
  });

  group('هزینهٔ چشم', () {
    test('چشمِ باز: حداکثر چهار فرمان، صفر بلور', () {
      final RitmoOrbPaintStats stats = _paintEyes(RitmoEyeFrame.calm);
      expect(stats.blurPasses, 0, reason: 'چشم بلور لازم ندارد');
      expect(stats.drawOps, lessThanOrEqualTo(4));
      expect(stats.drawOps, greaterThanOrEqualTo(2));
    });

    test('چشمِ بسته دو خط است، بی‌درخش', () {
      final RitmoOrbPaintStats stats = _paintEyes(
        const RitmoEyeFrame(
          open: 0.0,
          gaze: Offset.zero,
          presence: 1.0,
          squint: 0.0,
        ),
      );
      expect(stats.drawOps, 2);
      expect(stats.white, 0.0);
      expect(stats.blurPasses, 0);
    });

    test('چشمِ ناپیدا هیچ فرمانی نمی‌دهد', () {
      final RitmoOrbPaintStats stats = _paintEyes(RitmoEyeFrame.absent);
      expect(stats.drawOps, 0);
      expect(stats.white, 0.0);
    });

    test('درخشِ چشم از کیفِ سفید بیرون نمی‌زند', () {
      final RitmoOrbPaintStats stats =
          _paintEyes(RitmoEyeFrame.calm, budget: 0.08);
      expect(stats.white, lessThanOrEqualTo(0.08 + 1e-9));
    });
  });

  group('سوئیچِ خاموشی', () {
    testWidgets('خاموش = صفر فریم، صفر فضا',
        (tester) async {
      RitmoOrbSettings.instance.debugSet(on: false);

      await tester.pumpWidget(_harness(
        const RitmoLivingOrb(life: RitmoOrbLife.breathing, size: 96.0),
      ));
      await tester.pump(const Duration(milliseconds: 32));

      expect(RitmoOrbClock.instance.subscriberCount, 0,
          reason: 'خاموش که باشد، نباید باتری بخورد');
      expect(RitmoOrbClock.instance.isRunning, isFalse);
      expect(
        tester.getSize(find.byType(RitmoLivingOrb)),
        Size.zero,
        reason: 'نباید جای خالی هم بگیرد',
      );

      await tester.pumpWidget(_harness(const SizedBox.shrink()));
    });

    testWidgets('روشن کردن، حباب را برمی‌گرداند',
        (tester) async {
      RitmoOrbSettings.instance.debugSet(on: false);

      await tester.pumpWidget(_harness(
        const RitmoLivingOrb(life: RitmoOrbLife.breathing, size: 96.0),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(CustomPaint), findsNothing);

      RitmoOrbSettings.instance.debugSet(on: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(RitmoOrbClock.instance.subscriberCount, 1);
      expect(tester.getSize(find.byType(RitmoLivingOrb)).width, 96.0);

      await tester.pumpWidget(_harness(const SizedBox.shrink()));
      expect(RitmoOrbClock.instance.subscriberCount, 0);
    });
  });

  group('لنگرِ کادرِ تایپ', () {
    testWidgets('کیبرد بسته = لنگری نیست',
        (tester) async {
      final RitmoOrbPaintStats stats = RitmoOrbPaintStats();
      await tester.pumpWidget(_dockHarness(
        layer: RitmoOrbDockLayer(stats: stats),
        keyboard: 0.0,
      ));
      await tester.pump(const Duration(milliseconds: 16));

      expect(stats.drawOps, 0);
      expect(RitmoOrbClock.instance.subscriberCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('از سقفِ ردهٔ میانی رد نمی‌شود',
        (tester) async {
      final RitmoOrbPaintStats stats = RitmoOrbPaintStats();

      // reduceMotion تا ساعت وسط نیاید و شمارش دو بار نشود.
      await tester.pumpWidget(_dockHarness(
        layer: RitmoOrbDockLayer(debugAnchor: _anchor, stats: stats),
        reduceMotion: true,
      ));

      stats.reset();
      await tester.pumpWidget(_dockHarness(
        layer: RitmoOrbDockLayer(
          debugAnchor: _anchor,
          stats: stats,
          palette: RitmoOrbPalette.aurora,
        ),
        reduceMotion: true,
      ));

      expect(stats.drawOps, greaterThan(0), reason: 'باید کشیده شده باشد');
      expect(
        stats.blurPasses,
        lessThanOrEqualTo(RitmoOrbBudget.medium.blurPasses),
        reason: 'لنگر روی کیبرد زنده است؛ بلور گران‌ترین چیز است',
      );
      expect(stats.drawOps, lessThanOrEqualTo(RitmoOrbBudget.medium.drawOps));
      expect(
        stats.white,
        lessThanOrEqualTo(RitmoOrbBudget.medium.whiteBudget + 0.001),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('لمس را نمی‌دزدد', (tester) async {
      int taps = 0;
      await tester.pumpWidget(_dockHarness(
        reduceMotion: true,
        below: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
        ),
        layer: const RitmoOrbDockLayer(debugAnchor: _anchor),
      ));

      // دقیقاً روی جایی که ژله و سر کشیده می‌شوند.
      await tester.tapAt(const Offset(400.0, 505.0));
      await tester.pump();

      expect(taps, 1, reason: 'لنگر باید شفافِ لمس باشد');

      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('لنگرِ تکراری دوباره خبر نمی‌دهد', () {
      int notifications = 0;
      void listener() => notifications++;
      RitmoOrbDockSignal.instance.addListener(listener);

      RitmoOrbDockSignal.instance.report(const Rect.fromLTRB(0, 0, 100, 50));
      RitmoOrbDockSignal.instance.report(const Rect.fromLTRB(0, 0, 100, 50));
      expect(notifications, 1);

      RitmoOrbDockSignal.instance.report(const Rect.fromLTRB(0, 8, 100, 58));
      expect(notifications, 2);

      // کادرِ خالی معنا ندارد.
      RitmoOrbDockSignal.instance.report(Rect.zero);
      expect(notifications, 2);

      RitmoOrbDockSignal.instance.removeListener(listener);
      RitmoOrbDockSignal.instance.clear();
    });
  });

  group('تحویلِ کار', () {
    testWidgets('کیبردِ باز = تیله جایش را به لنگر می‌دهد',
        (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300.0);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: Center(
          child: RitmoLivingOrb(life: RitmoOrbLife.breathing, size: 96.0),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 32));

      expect(find.byType(RitmoOrbDockLayer), findsOneWidget);
      expect(
        RitmoOrbClock.instance.subscriberCount,
        1,
        reason: 'فقط لنگر فریم می‌گیرد؛ تیلهٔ پشتِ کادر نه',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(RitmoOrbClock.instance.subscriberCount, 0);
    });

    testWidgets('خاموشیِ لنگر در تنظیمات محترم است',
        (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300.0);
      addTearDown(tester.view.reset);
      RitmoOrbSettings.instance.debugSet(dock: false);

      await tester.pumpWidget(const MaterialApp(
        home: Center(
          child: RitmoLivingOrb(life: RitmoOrbLife.breathing, size: 96.0),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 32));

      expect(find.byType(RitmoOrbDockLayer), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
