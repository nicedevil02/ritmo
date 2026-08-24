// سیستم تم مرکزی Ritmo — تنها منبع حقیقت طراحی بصری اپ
// شامل توکن‌های فاصله، رادیوس، تایپوگرافی، تم دینامیک و اکستنشن‌های دسترسی

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_behavior.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';
import 'package:ritmo/core/theme/ritmo_module_colors.dart';
import 'package:ritmo/core/theme/ritmo_palette.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/core/theme/tokens/ritmo_material.dart';
import 'package:ritmo/core/theme/tokens/ritmo_metrics.dart';
import 'package:ritmo/core/theme/ui_scale.dart';

export 'package:ritmo/core/theme/ritmo_behavior.dart';
export 'package:ritmo/core/theme/ritmo_colors.dart';
export 'package:ritmo/core/theme/ritmo_module_colors.dart';
export 'package:ritmo/core/theme/ritmo_palette.dart';
export 'package:ritmo/core/theme/tokens/ritmo_breakpoints.dart';
export 'package:ritmo/core/theme/tokens/ritmo_material.dart';
export 'package:ritmo/core/theme/tokens/ritmo_metrics.dart';
export 'package:ritmo/core/theme/tokens/ritmo_springs.dart';
export 'package:ritmo/core/theme/ui_scale.dart';

/// توکن‌های فاصله‌گذاری — فقط ۷ مقدار مجاز (سند طراحی §۳.۲)
abstract final class RitmoSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16; // فاصلهٔ استاندارد لبهٔ صفحه
  static const double xl = 24; // فاصلهٔ بین بخش‌های صفحه
  static const double xxl = 32;
  static const double xxxl = 48; // فضای تنفس Hero و Empty state

  static const double section = 16;
}

/// توکن‌های رادیوس — سند طراحی §۳.۳
abstract final class RitmoRadius {
  static const double field = 14; // TextField و دکمه
  static const double card = 16; // کارت معمولی
  static const double hero = 20; // کارت Hero
  static const double sheet = 28; // BottomSheet — فقط دو گوشهٔ بالا
  static const double iconButton = 12;
  static const double pill = 999; // چیپ و برچسب
  static const double badge = 8; // نشان عددی کوچک

  // Backward compatibility aliases
  static const double chip = iconButton;
  static const double cardLarge = hero;

  /// گوشه‌ی پیوسته‌ی سبک اپل (squircle) برای کارت‌های کلیدی
  static ShapeBorder squircle(
    double radius, {
    BorderSide side = BorderSide.none,
  }) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius * 2.35),
      side: side,
    );
  }
}

/// توکن‌های حرکت — سند طراحی §۳.۷
abstract final class RitmoMotion {
  static const Duration press = Duration(milliseconds: 120);
  static const Duration state = Duration(milliseconds: 200);
  static const Duration sheet = Duration(milliseconds: 320);
  static const Duration themeSwap = Duration(milliseconds: 200);
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const double pressScale = 0.97;

  // Backward compatibility aliases
  static const Duration fast = press;
  static const Duration normal = state;
  static const Duration slow = sheet;
  static const Curve spring = Curves.easeOutBack;
  static const Curve standard = enter;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration effective(BuildContext context, [Duration base = state]) =>
      reduceMotion(context) ? Duration.zero : base;
}

/// هپتیک — یک قرارداد واحد (سند طراحی §۳.۸)
abstract final class RitmoHapticsPolicy {
  static bool get _isEnabled =>
      !SettingsService.instance.isInitialized ||
      SettingsService.instance.get<bool>('haptic_feedback_enabled');

  static void selection() {
    if (_isEnabled) HapticFeedback.selectionClick();
  }

  static void tap() {
    if (_isEnabled) HapticFeedback.lightImpact();
  }

  static void success() {
    if (_isEnabled) HapticFeedback.mediumImpact();
  }

  static void warning() {
    if (_isEnabled) HapticFeedback.heavyImpact();
  }

  static void error() {
    if (_isEnabled) HapticFeedback.vibrate();
  }
}

abstract final class RitmoTextStyles {
  static TextStyle heroNumber(Color color) => TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    color: color,
    fontFamily: 'Vazirmatn',
    height: 1.1,
  );

  static TextStyle pageTitle(Color color) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: color,
    fontFamily: 'Vazirmatn',
    height: 1.3,
  );

  static TextStyle sectionHeadline(Color color) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: color,
    fontFamily: 'Vazirmatn',
    height: 1.4,
  );

  static TextStyle cardTitle(Color color) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: color,
    fontFamily: 'Vazirmatn',
    height: 1.4,
  );

  static TextStyle titleMedium(Color color) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: color,
    fontFamily: 'Vazirmatn',
    height: 1.5,
  );

  static TextStyle body(Color color) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: color,
    fontFamily: 'Vazirmatn',
    height: 1.6,
  );

  static TextStyle label(Color color) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color,
    fontFamily: 'Vazirmatn',
    height: 1.3,
  );

  static TextStyle caption(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: color,
    fontFamily: 'Vazirmatn',
    height: 1.6,
  );

  static TextStyle badge(Color color) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: color,
    fontFamily: 'Vazirmatn',
    height: 1.3,
  );
}

/// تایپوگرافی کامل و متناسب با Vazirmatn (سند طراحی §۳.۴)
abstract final class RitmoTypography {
  static TextTheme textTheme(RitmoColors colors) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        height: 1.3,
        fontFamily: 'Vazirmatn',
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        height: 1.3,
        fontFamily: 'Vazirmatn',
      ),
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        height: 1.3,
        fontFamily: 'Vazirmatn',
      ),
      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        height: 1.4,
        fontFamily: 'Vazirmatn',
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        height: 1.4,
        fontFamily: 'Vazirmatn',
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        height: 1.4,
        fontFamily: 'Vazirmatn',
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        height: 1.4,
        fontFamily: 'Vazirmatn',
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.5,
        fontFamily: 'Vazirmatn',
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.4,
        fontFamily: 'Vazirmatn',
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.6,
        fontFamily: 'Vazirmatn',
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        height: 1.6,
        fontFamily: 'Vazirmatn',
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textTertiary,
        height: 1.5,
        fontFamily: 'Vazirmatn',
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.3,
        fontFamily: 'Vazirmatn',
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
        height: 1.3,
        fontFamily: 'Vazirmatn',
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
        height: 1.3,
        fontFamily: 'Vazirmatn',
      ),
    );
  }
}

/// کلاس توکن‌های سایه و خط دور کارت (سند طراحی §۳.۶)
abstract final class RitmoElevation {
  static const List<BoxShadow> cardLight = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> elevatedLight = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> none = <BoxShadow>[];
  static const double borderWidthDark = 1.0;
}

class RitmoTheme {
  @Deprecated('از RitmoTheme.build استفاده کن')
  static ThemeData get darkTheme =>
      build(palette: RitmoPalette.jadeNoir, brightness: Brightness.dark);

  @Deprecated('از RitmoTheme.build استفاده کن')
  static ThemeData get lightTheme =>
      build(palette: RitmoPalette.jadeNoir, brightness: Brightness.light);

  static ThemeData build({
    required RitmoPalette palette,
    required Brightness brightness,
    bool reduceTransparency = false,
    bool trueBlack = false,
    RitmoDensityLevel density = RitmoDensityLevel.comfortable,
  }) {
    var colors = palette.forBrightness(brightness);
    if (trueBlack && brightness == Brightness.dark) {
      colors = colors.copyWith(
        background: const Color(0xFF000000),
        systemNavBar: const Color(0xFF000000),
      );
    }

    final isDark = brightness == Brightness.dark;
    final m = RitmoMetrics.of(density);
    final vd = ((RitmoUiScale.densityFactor(density) - 1) * 8).clamp(-2.0, 2.0);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Vazirmatn',
      scaffoldBackgroundColor: colors.background,
      colorScheme: _schemeFrom(colors, brightness),
      textTheme: RitmoTypography.textTheme(colors),
      visualDensity: VisualDensity(horizontal: vd, vertical: vd),
      extensions: <ThemeExtension<dynamic>>[
        colors,
        RitmoBehavior(reduceTransparency: reduceTransparency),
        RitmoMaterials.fromColors(colors),
        m,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: m.rowHeight,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          fontFamily: 'Vazirmatn',
        ),
        iconTheme: IconThemeData(color: colors.textPrimary, size: m.iconLg),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.disabled,
          disabledForegroundColor: colors.textTertiary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(m.radiusField),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Vazirmatn',
          ),
          minimumSize: Size(m.touchTarget, m.touchTarget),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.surfaceElevated,
          foregroundColor: colors.textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(m.radiusField),
            side: isDark ? BorderSide(color: colors.border) : BorderSide.none,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Vazirmatn',
          ),
          minimumSize: Size(m.touchTarget, m.touchTarget),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Vazirmatn',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(m.radiusField),
          ),
          minimumSize: Size(m.touchTarget, m.touchTarget),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(m.radiusField),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Vazirmatn',
          ),
          minimumSize: Size(m.touchTarget, m.touchTarget),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.radiusCard),
          side: isDark
              ? BorderSide(
                  color: colors.border,
                  width: RitmoElevation.borderWidthDark,
                )
              : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(m.radiusField),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(m.radiusField),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(m.radiusField),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(m.radiusField),
          borderSide: BorderSide(color: colors.disabled.withValues(alpha: 0.3)),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: m.spaceLg,
          vertical: m.spaceMd + 2,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceSunken,
        disabledColor: colors.disabled,
        selectedColor: colors.primaryContainer,
        secondarySelectedColor: colors.primary,
        padding: EdgeInsets.symmetric(
          horizontal: m.spaceMd,
          vertical: m.spaceXs + 2,
        ),
        labelStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 13,
          fontFamily: 'Vazirmatn',
        ),
        secondaryLabelStyle: TextStyle(
          color: colors.onPrimary,
          fontSize: 13,
          fontFamily: 'Vazirmatn',
        ),
        brightness: brightness,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.pill),
          side: BorderSide(color: colors.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        modalBackgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(m.radiusSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.radiusCard),
          side: isDark ? BorderSide(color: colors.border) : BorderSide.none,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          fontFamily: 'Vazirmatn',
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colors.textSecondary,
          fontFamily: 'Vazirmatn',
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: TextStyle(
          color: colors.textPrimary,
          fontFamily: 'Vazirmatn',
        ),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.radiusField),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.primary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontFamily: 'Vazirmatn',
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontFamily: 'Vazirmatn',
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.primary,
              fontFamily: 'Vazirmatn',
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colors.textSecondary,
            fontFamily: 'Vazirmatn',
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.primary, size: m.iconLg);
          }
          return IconThemeData(color: colors.textSecondary, size: m.iconLg);
        }),
      ),
      listTileTheme: ListTileThemeData(
        textColor: colors.textPrimary,
        iconColor: colors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.radiusCard),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: m.spaceLg,
          vertical: m.spaceXs,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.onPrimary;
          return colors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.surfaceSunken;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return colors.border;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceSunken,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceSunken,
        circularTrackColor: colors.surfaceSunken,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return colors.primary;
            return colors.surfaceSunken;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return colors.onPrimary;
            return colors.textPrimary;
          }),
          side: WidgetStateProperty.all(BorderSide(color: colors.border)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.field),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(RitmoRadius.badge),
          border: Border.all(color: colors.border),
        ),
        textStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 12,
          fontFamily: 'Vazirmatn',
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.field),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          side: BorderSide(color: colors.border),
        ),
        textStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontFamily: 'Vazirmatn',
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: colors.surface,
        headerForegroundColor: colors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
        ),
      ),
      iconTheme: IconThemeData(color: colors.textPrimary, size: m.iconLg),
    );
  }

  static ColorScheme _schemeFrom(RitmoColors colors, Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.textPrimary,
      secondary: colors.accent,
      onSecondary: colors.textOnColor,
      secondaryContainer: colors.accentContainer,
      onSecondaryContainer: colors.textPrimary,
      tertiary: colors.accent,
      onTertiary: colors.textOnColor,
      error: colors.error,
      onError: colors.textOnColor,
      errorContainer: colors.error.withValues(alpha: 0.15),
      onErrorContainer: colors.error,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surfaceElevated,
      surfaceContainerHighest: colors.surfaceSunken,
      surfaceDim: colors.surfaceSunken,
      surfaceBright: colors.surfaceElevated,
      outline: colors.border,
      outlineVariant: colors.divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: brightness == Brightness.dark
          ? colors.surfaceElevated
          : colors.surfaceSunken,
      onInverseSurface: colors.textPrimary,
      inversePrimary: colors.primary,
    );
  }

  /// گرادیان پس‌زمینه زمان‌محور — در حال حاضر هگز هاردکد و مستقل از پالت است.
  /// TODO(Aurora P1): به توکن گرادیان مشتق از پالت منتقل شود (RFC §۵.۷)؛
  /// ساعت روز فقط زاویه و روشنایی را جابه‌جا می‌کند، نه هویت رنگ را.
  static List<Color> timeAwareGradient(Brightness brightness, {DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    final isDark = brightness == Brightness.dark;

    if (isDark) {
      if (hour >= 5 && hour < 9) {
        return const [Color(0xff060C0E), Color(0xff101D21)];
      } else if (hour >= 9 && hour < 17) {
        return const [Color(0xff0B0C10), Color(0xff161A22)];
      } else if (hour >= 17 && hour < 21) {
        return const [Color(0xff080B12), Color(0xff121824)];
      }
      return const [Color(0xff040407), Color(0xff0D0C15)];
    }

    if (hour >= 5 && hour < 9) {
      return const [Color(0xffF1F4FA), Color(0xffF8F6FC)];
    } else if (hour >= 9 && hour < 17) {
      return const [Color(0xffF4F6FB), Color(0xffFAF8F5)];
    } else if (hour >= 17 && hour < 21) {
      return const [Color(0xffF6F4FA), Color(0xffFCF6F2)];
    }
    return const [Color(0xffF0F2F9), Color(0xffF6F5FA)];
  }

  static Widget buildBackgroundContainer({
    required BuildContext context,
    required Widget child,
  }) {
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: timeAwareGradient(brightness),
        ),
      ),
      child: child,
    );
  }

  static Widget glassCard({
    required Widget child,
    double blurSigma = 10.0,
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return RitmoGlassCard(
      blurSigma: blurSigma,
      color: color,
      borderRadius: borderRadius,
      border: border,
      child: child,
    );
  }

  static Widget glassCardLight({
    required Widget child,
    double blurSigma = 15.0,
    double borderRadius = 24.0,
    Color? color,
    Border? border,
    List<BoxShadow>? shadows,
  }) {
    return RitmoGlassCardLight(
      blurSigma: blurSigma,
      borderRadius: borderRadius,
      color: color,
      border: border,
      shadows: shadows,
      child: child,
    );
  }

  static InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final colors = context.colors;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: colors.textSecondary,
        fontSize: 13,
        fontFamily: 'Vazirmatn',
      ),
      prefixIcon: Icon(icon, color: colors.primary, size: 20),
      filled: true,
      fillColor: colors.surfaceSunken,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RitmoRadius.field),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RitmoRadius.field),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RitmoRadius.field),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    );
  }
}

class RitmoGlassCard extends StatelessWidget {
  const RitmoGlassCard({
    super.key,
    required this.child,
    this.blurSigma = 10.0,
    this.color,
    this.borderRadius,
    this.border,
  });

  final Widget child;
  final double blurSigma;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(RitmoRadius.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? colors.glassTint,
            borderRadius:
                borderRadius ?? BorderRadius.circular(RitmoRadius.card),
            border:
                border ??
                Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.45),
                ),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

class RitmoGlassCardLight extends StatelessWidget {
  const RitmoGlassCardLight({
    super.key,
    required this.child,
    this.blurSigma = 15.0,
    this.borderRadius = 24.0,
    this.color,
    this.border,
    this.shadows,
  });

  final Widget child;
  final double blurSigma;
  final double borderRadius;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow:
            shadows ??
            (isDarkMode ? RitmoElevation.none : RitmoElevation.cardLight),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: color ?? colors.glassTint,
              borderRadius: BorderRadius.circular(borderRadius),
              border:
                  border ??
                  Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

extension RitmoThemeExtension on BuildContext {
  RitmoColors get colors {
    final c = Theme.of(this).extension<RitmoColors>();
    final isDarkMode = Theme.of(this).brightness == Brightness.dark;
    return c ?? (isDarkMode ? kJadeNoirDark : kJadeNoirLight);
  }

  RitmoColors get ritmoColors => colors;
  RitmoModuleColors get modules => colors.modules;
  RitmoBehavior get behavior =>
      Theme.of(this).extension<RitmoBehavior>() ??
      const RitmoBehavior(reduceTransparency: false);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  TextTheme get t => Theme.of(this).textTheme;
}
