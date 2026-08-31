// گاردِ تیلهٔ هوش مصنوعی.
//
// این تست‌ها زیبایی را نمی‌سنجند؛ قراردادهایی را می‌سنجند که اگر بشکنند، تیله
// دوباره همان چیزی می‌شود که بود: گران، پرحرف و ناخوانا.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_marble_core.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_clock.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_presence.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_shell.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

Widget _harness(Widget child, {bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Center(child: child),
    ),
  );
}

void main() {
  setUp(() {
    RitmoOrbClock.instance.debugReset();
    RitmoAiStateService.instance.setTruth(RitmoOrbTruth.confident);
    RitmoOrbEnergySignal.instance.clear();
    RitmoOrbAttentionSignal.instance.relax();
  });

  group('بودجهٔ نقاشی', () {
    testWidgets('ردهٔ S هیچ پاسِ بلوری ندارد', (WidgetTester tester) async {
      final RitmoOrbPaintStats stats = RitmoOrbPaintStats();
      await tester.pumpWidget(_harness(
        RitmoMarbleCore(size: 19.0, isAnimated: false, stats: stats),
      ));

      stats.reset();
      await tester.pumpWidget(_harness(
        RitmoMarbleCore(
          size: 19.0,
          isAnimated: false,
          stats: stats,
          palette: RitmoOrbPalette.aurora,
        ),
      ));

      expect(stats.blurPasses, 0, reason: 'در ۱۹ پیکسل بلور فقط هزینه است');
      expect(stats.drawOps, lessThanOrEqualTo(RitmoOrbBudget.small.drawOps));
      expect(stats.white, lessThanOrEqualTo(RitmoOrbBudget.small.whiteBudget));
    });

    testWidgets('ردهٔ L از سقفِ بلور و سفید عبور نمی‌کند',
        (WidgetTester tester) async {
      final RitmoOrbPaintStats stats = RitmoOrbPaintStats();
      await tester.pumpWidget(_harness(
        RitmoMarbleCore(size: 96.0, isAnimated: false, stats: stats),
      ));

      stats.reset();
      await tester.pumpWidget(_harness(
        RitmoMarbleCore(
          size: 96.0,
          isAnimated: false,
          stats: stats,
          palette: RitmoOrbPalette.ember,
        ),
      ));

      expect(
        stats.blurPasses,
        lessThanOrEqualTo(RitmoOrbBudget.large.blurPasses),
        reason: 'هر بلور یک render pass جداست',
      );
      expect(stats.drawOps, lessThanOrEqualTo(RitmoOrbBudget.large.drawOps));
      expect(
        stats.white,
        lessThanOrEqualTo(RitmoOrbBudget.large.whiteBudget + 0.001),
        reason: 'سقفِ سفید: تیله نباید دوباره شیری شود',
      );
    });

    testWidgets('حالتِ نوشتن هم از بودجه بیرون نمی‌زند',
        (WidgetTester tester) async {
      final RitmoOrbPaintStats stats = RitmoOrbPaintStats();
      await tester.pumpWidget(_harness(
        RitmoMarbleCore(
          size: 96.0,
          isAnimated: false,
          stats: stats,
          signature: RitmoOrbSignature.of(RitmoOrbLife.celebrating),
        ),
      ));

      stats.reset();
      await tester.pumpWidget(_harness(
        RitmoMarbleCore(
          size: 96.0,
          isAnimated: false,
          stats: stats,
          palette: RitmoOrbPalette.aurora,
          signature: RitmoOrbSignature.of(RitmoOrbLife.celebrating),
        ),
      ));

      expect(stats.blurPasses,
          lessThanOrEqualTo(RitmoOrbBudget.large.blurPasses));
      expect(stats.white,
          lessThanOrEqualTo(RitmoOrbBudget.large.whiteBudget + 0.001));
    });
  });

  group('چرخهٔ عمرِ ساعت', () {
    testWidgets('تیلهٔ زنده مشترکِ ساعت می‌شود و بعد از dispose رها می‌کند',
        (WidgetTester tester) async {
      expect(RitmoOrbClock.instance.subscriberCount, 0);

      await tester.pumpWidget(_harness(
        const RitmoLivingOrb(life: RitmoOrbLife.breathing, size: 96.0),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      expect(RitmoOrbClock.instance.subscriberCount, 1);
      expect(RitmoOrbClock.instance.isRunning, isTrue);

      await tester.pumpWidget(_harness(const SizedBox.shrink()));
      expect(RitmoOrbClock.instance.subscriberCount, 0);
      expect(RitmoOrbClock.instance.isRunning, isFalse,
          reason: 'با رفتنِ آخرین تیله باید بایستد');
    });

    testWidgets('تیلهٔ پنهان هیچ فریمی نمی‌گیرد', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(
        const RitmoLivingOrb(life: RitmoOrbLife.hidden, size: 96.0),
      ));
      await tester.pump(const Duration(milliseconds: 16));

      expect(RitmoOrbClock.instance.subscriberCount, 0);
      // ولی فضایش را رزرو نگه می‌دارد تا انیمیشنِ خروج قابلِ پخش باشد.
      expect(find.byType(RitmoLivingOrb), findsOneWidget);

      await tester.pumpWidget(_harness(const SizedBox.shrink()));
      expect(RitmoOrbClock.instance.subscriberCount, 0);
    });

    testWidgets('احترام به کاهشِ حرکت: یک فریمِ ایستا',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(
        const RitmoLivingOrb(life: RitmoOrbLife.writing, size: 96.0),
        reduceMotion: true,
      ));
      await tester.pump(const Duration(milliseconds: 32));

      expect(RitmoOrbClock.instance.subscriberCount, 0,
          reason: 'کاربری که حرکت را خاموش کرده، نباید باتری بدهد');

      await tester.pumpWidget(_harness(const SizedBox.shrink()));
    });

    testWidgets('TickerMode خاموش = بدون مشترک', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(
        const TickerMode(
          enabled: false,
          child: RitmoLivingOrb(life: RitmoOrbLife.thinking, size: 96.0),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 16));

      expect(RitmoOrbClock.instance.subscriberCount, 0);
      await tester.pumpWidget(_harness(const SizedBox.shrink()));
    });
  });

  group('قراردادهای طراحی', () {
    test('کاستیک در ربعِ مقابلِ هایلایت می‌نشیند', () {
      for (final RitmoOrbTier tier in RitmoOrbTier.values) {
        final RitmoLightRig rig = RitmoLightRig.resolve(
          tier: tier,
          truth: RitmoOrbTruth.confident,
          isDark: false,
        );
        expect(rig.keyAlign.x * rig.causticAlign.x, lessThan(0.0));
        expect(rig.keyAlign.y * rig.causticAlign.y, lessThan(0.0));
      }
    });

    test('بودجهٔ سفید بیش از سقف خرج نمی‌کند', () {
      final RitmoWhitePurse purse = RitmoWhitePurse(0.5);
      expect(purse.take(0.3), closeTo(0.3, 1e-9));
      expect(purse.take(0.3), closeTo(0.2, 1e-9));
      expect(purse.take(0.3), 0.0);
      expect(purse.spent, closeTo(0.5, 1e-9));
    });

    test('مسیرِ پوسته با ورودیِ یکسان دوباره ساخته نمی‌شود', () {
      final RitmoShellCache cache = RitmoShellCache();
      for (int i = 0; i < 5; i++) {
        cache.resolve(
          center: const Offset(50.0, 50.0),
          radius: 40.0,
          samples: 32,
          phase: 1.25,
          wobble: 0.12,
        );
      }
      expect(cache.rebuilds, 1);

      cache.resolve(
        center: const Offset(50.0, 50.0),
        radius: 40.0,
        samples: 32,
        phase: 2.5,
        wobble: 0.12,
      );
      expect(cache.rebuilds, 2);
    });

    test('پوسته درونِ مرزِ معقول می‌ماند', () {
      final Path path = RitmoOrbShell.buildPath(
        center: const Offset(50.0, 50.0),
        radius: 40.0,
        samples: 32,
        phase: 0.7,
        wobble: 0.16,
        bulges: const <RitmoShellBulge>[
          RitmoShellBulge(angle: 0.4, width: 1.1, amount: 0.06),
        ],
      );
      final Rect bounds = path.getBounds();
      expect(bounds.width, lessThan(40.0 * 2.0 * 1.45));
      expect(bounds.height, lessThan(40.0 * 2.0 * 1.45));
      expect(bounds.width, greaterThan(40.0 * 2.0 * 0.6));
    });

    test('پالت مقایسه‌پذیر است (جلوگیری از بازسازیِ بی‌دلیل)', () {
      expect(
        RitmoOrbPalette.coral.copyWith(),
        RitmoOrbPalette.coral,
      );
      expect(
        RitmoOrbPalette.coral.copyWith().hashCode,
        RitmoOrbPalette.coral.hashCode,
      );
      expect(RitmoOrbPalette.coral == RitmoOrbPalette.aurora, isFalse);

      int notifications = 0;
      final ValueNotifier<RitmoOrbPalette> notifier =
          ValueNotifier<RitmoOrbPalette>(RitmoOrbPalette.coral);
      notifier.addListener(() => notifications++);
      notifier.value = RitmoOrbPalette.coral.copyWith();
      expect(notifications, 0);
      notifier.value = RitmoOrbPalette.aurora;
      expect(notifications, 1);
      notifier.dispose();
    });

    test('منحنیِ نفس متقارن نیست و سکوت دارد', () {
      expect(ritmoBreathCurve(0.0), closeTo(0.0, 1e-6));
      expect(ritmoBreathCurve(0.36), 1.0);
      expect(ritmoBreathCurve(0.95), 0.0);
      // دم کوتاه‌تر از بازدم است: در نیمهٔ زمان، هنوز در حال بازدم است.
      expect(ritmoBreathCurve(0.5), greaterThan(0.5));
      for (double t = 0.0; t < 1.0; t += 0.05) {
        final double v = ritmoBreathCurve(t);
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });

    test('صداقت روی امضای حرکت اثر دارد', () {
      final RitmoOrbSignature base =
          RitmoOrbSignature.of(RitmoOrbLife.writing);
      final RitmoOrbSignature unsure =
          base.withTruth(RitmoOrbTruth.unsure);
      final RitmoOrbSignature offline =
          base.withTruth(RitmoOrbTruth.offline);

      expect(unsure.flow, lessThan(base.flow));
      expect(unsure.rim, lessThan(base.rim));
      expect(offline.flow, lessThan(unsure.flow));
      expect(offline.aura, 0.0);
      expect(offline.breathMs, greaterThan(base.breathMs));
    });

    test('P4 تا وقتی داده نداریم هیچ ادعایی نمی‌کند', () {
      final RitmoOrbSignature base =
          RitmoOrbSignature.of(RitmoOrbLife.breathing);
      expect(base.withEnergy(RitmoOrbEnergy.neutral).breathMs, base.breathMs);
      expect(
        ritmoEnergyPalette(RitmoOrbPalette.coral, RitmoOrbEnergy.neutral),
        RitmoOrbPalette.coral,
      );

      const RitmoOrbEnergy heavy =
          RitmoOrbEnergy(load: 1.0, vitality: 0.2);
      expect(base.withEnergy(heavy).breathMs, greaterThan(base.breathMs));
      expect(
        ritmoEnergyPalette(RitmoOrbPalette.coral, heavy) ==
            RitmoOrbPalette.coral,
        isFalse,
      );
    });
  });

  group('دسترسی‌پذیری', () {
    testWidgets('تیله حالتش را برای screen reader می‌گوید',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(
        const RitmoLivingOrb(life: RitmoOrbLife.thinking, size: 96.0),
      ));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.bySemanticsLabel('دستیار هوشمند ریتمو'), findsOneWidget);

      await tester.pumpWidget(_harness(const SizedBox.shrink()));
      handle.dispose();
    });

    testWidgets('تیلهٔ قابلِ لمس حداقل ۴۸ پیکسل ناحیهٔ لمس دارد',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(
        RitmoLivingOrb(
          life: RitmoOrbLife.breathing,
          size: 24.0,
          onTap: () {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 16));

      final Size size = tester.getSize(find.byType(GestureDetector).first);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      await tester.pumpWidget(_harness(const SizedBox.shrink()));
    });
  });
}
