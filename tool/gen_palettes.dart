// ژنراتور پالت OKLCH — RFC «Ritmo Aurora» §۵.۱
//
// اجرا:
//   dart run tool/gen_palettes.dart
//
// خروجی روی stdout چاپ می‌شود و به‌صورت دستی در فایل‌های تولیدی زیر
// lib/core/theme/palettes/ کپی و کامیت می‌شود؛ این ابزار عمداً روی فایل‌های
// موجود نمی‌نویسد تا بازنویسی تصادفی ممکن نباشد.
//
// زنجیره‌ی تبدیل: OKLCH → OkLab → linear sRGB → sRGB
// گَموت‌مپینگ: به‌جای clip کردن کانال‌ها، کروما پله‌پله کم می‌شود تا رنگ وارد
// sRGB شود. clip کانال، همان ناپیوستگی ادراکی و چسبیدن پله‌های تیره را
// برمی‌گرداند که این ابزار برای حذفش ساخته شده.

import 'dart:math' as math;

class Oklch {
  const Oklch(this.l, this.c, this.h);

  final double l; // روشنایی ادراکی، ۰ تا ۱
  final double c; // کروما
  final double h; // hue به درجه
}

class Srgb {
  const Srgb(this.r, this.g, this.b);

  final double r;
  final double g;
  final double b;

  bool get inGamut =>
      r >= 0 && r <= 1 && g >= 0 && g <= 1 && b >= 0 && b <= 1;

  int get hexValue {
    int channel(double v) => (v.clamp(0.0, 1.0) * 255).round() & 0xFF;
    return 0xFF000000 | (channel(r) << 16) | (channel(g) << 8) | channel(b);
  }

  String get hexString =>
      '#${hexValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

double _cube(double x) => x * x * x;

double _cbrt(double x) => x >= 0
    ? math.pow(x, 1 / 3).toDouble()
    : -math.pow(-x, 1 / 3).toDouble();

/// sRGB (۰ تا ۱) → linear sRGB
double _toLinear(double c) => c <= 0.04045
    ? c / 12.92
    : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// linear sRGB → sRGB (۰ تا ۱)
double _fromLinear(double c) => c <= 0.0031308
    ? 12.92 * c
    : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

/// OKLCH → linear sRGB (ماتریس‌های Ottosson)
Srgb oklchToLinearSrgb(Oklch color) {
  final hRad = color.h * math.pi / 180;
  final a = color.c * math.cos(hRad);
  final b = color.c * math.sin(hRad);

  final lPrime = color.l + 0.3963377774 * a + 0.2158037573 * b;
  final mPrime = color.l - 0.1055613458 * a - 0.0638541728 * b;
  final sPrime = color.l - 0.0894841775 * a - 1.2914855480 * b;

  final l = _cube(lPrime);
  final m = _cube(mPrime);
  final s = _cube(sPrime);

  return Srgb(
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  );
}

/// linear sRGB → OKLCH (معکوس همان ماتریس‌ها)
Oklch linearSrgbToOklch(Srgb color) {
  final l = 0.4122214708 * color.r +
      0.5363325363 * color.g +
      0.0514459929 * color.b;
  final m = 0.2119034982 * color.r +
      0.6806995451 * color.g +
      0.1073969566 * color.b;
  final s = 0.0883024619 * color.r +
      0.2817188376 * color.g +
      0.6299787005 * color.b;

  final lPrime = _cbrt(l);
  final mPrime = _cbrt(m);
  final sPrime = _cbrt(s);

  final lOut =
      0.2104542553 * lPrime + 0.7936177850 * mPrime - 0.0040720468 * sPrime;
  final aOut =
      1.9779984951 * lPrime - 2.4285922050 * mPrime + 0.4505937099 * sPrime;
  final bOut =
      0.0259040371 * lPrime + 0.7827717662 * mPrime - 0.8086757660 * sPrime;

  final c = math.sqrt(aOut * aOut + bOut * bOut);
  var h = math.atan2(bOut, aOut) * 180 / math.pi;
  if (h < 0) h += 360;

  return Oklch(lOut, c, h);
}

Srgb hexToLinearSrgb(int hex) {
  double channel(int shift) => _toLinear(((hex >> shift) & 0xFF) / 255);
  return Srgb(channel(16), channel(8), channel(0));
}

/// گَموت‌مپینگ: کاهش پله‌ای کروما تا ورود رنگ به sRGB.
/// هرگز کانال‌ها را clip نمی‌کنیم.
Srgb gamutMap(Oklch color) {
  const chromaStep = 0.002;
  const epsilon = 0.0005;
  var current = color;

  while (current.c > epsilon) {
    final linear = oklchToLinearSrgb(current);
    if (linear.inGamut) {
      return Srgb(
        _fromLinear(linear.r),
        _fromLinear(linear.g),
        _fromLinear(linear.b),
      );
    }
    current = Oklch(current.l, current.c - chromaStep, current.h);
  }

  // سقوط امن به خاکستری بی‌رنگ با همان روشنایی
  final gray = oklchToLinearSrgb(Oklch(current.l, 0, current.h));
  return Srgb(
    _fromLinear(gray.r.clamp(0.0, 1.0)),
    _fromLinear(gray.g.clamp(0.0, 1.0)),
    _fromLinear(gray.b.clamp(0.0, 1.0)),
  );
}

/// ۱۲ پله‌ی روشنایی ادراکی — از روشن به تیره.
const lightnessStops = <double>[
  0.97, 0.92, 0.86, 0.79, 0.71, 0.62, 0.54, 0.47, 0.40, 0.33, 0.26, 0.18,
];

class PaletteSeed {
  const PaletteSeed(this.id, this.primaryHex, this.accentHex);

  final String id;
  final int primaryHex;
  final int accentHex;
}

const seeds = <PaletteSeed>[
  PaletteSeed('jade_noir', 0xFF0F7A68, 0xFF45BFA0),
  PaletteSeed('copper_dusk', 0xFFA95F3B, 0xFFE08A5B),
  PaletteSeed('rosewood', 0xFF92485C, 0xFFD9829A),
  PaletteSeed('olive_sand', 0xFF5E7236, 0xFFA8C46C),
  PaletteSeed('graphite_champagne', 0xFF3D4441, 0xFFD8C79E),
];

String _camel(String id) {
  final parts = id.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

void main() {
  print('// تولیدشده توسط tool/gen_palettes.dart — ویرایش دستی نکنید');
  print('// گَموت‌مپینگ: کاهش پله‌ای کروما، بدون clip کانال');
  print('');

  for (final seed in seeds) {
    for (final role in ['primary', 'accent']) {
      final hex = role == 'primary' ? seed.primaryHex : seed.accentHex;
      final seedOklch = linearSrgbToOklch(hexToLinearSrgb(hex));
      final seedLabel =
          '#${hex.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      final roleName = role[0].toUpperCase() + role.substring(1);

      print('// ${seed.id} · $role · seed $seedLabel '
          '(OKLCH L=${seedOklch.l.toStringAsFixed(3)} '
          'C=${seedOklch.c.toStringAsFixed(3)} '
          'h=${seedOklch.h.toStringAsFixed(1)})');
      print('const List<int> ${_camel(seed.id)}${roleName}Ramp = <int>[');

      for (final l in lightnessStops) {
        final mapped = gamutMap(Oklch(l, seedOklch.c, seedOklch.h));
        print('  0x${mapped.hexValue.toRadixString(16).padLeft(8, '0').toUpperCase()},'
            ' // ${mapped.hexString}');
      }
      print('];');
      print('');
    }
  }
}
