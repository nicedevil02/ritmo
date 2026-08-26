import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Single place that turns stored metric values into what the user sees.
///
/// Storage stays metric everywhere (kg / cm); only presentation converts. Read
/// the preference once per screen with [isMetric] and pass it down.
///
/// TODO(ux): wire this into every weight/height readout (progress charts,
/// session set rows, weight log, plan cards). Until then the units switch in
/// settings only affects the screens that already call this helper.
class SsUnitFormatter {
  const SsUnitFormatter._();

  static const String prefsKey = 'ss_units_metric';
  static const double _kgPerLb = 0.45359237;
  static const double _cmPerInch = 2.54;

  static Future<bool> isMetric([DatabaseExecutor? executor]) async {
    try {
      final db = executor ?? await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [prefsKey],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['value'] == 'true';
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? true;
  }

  static String weightUnit({required bool metric}) =>
      metric ? 'کیلوگرم' : 'پوند';

  static String heightUnit({required bool metric}) =>
      metric ? 'سانتی‌متر' : 'اینچ';

  /// kg -> displayed value in the active unit.
  static double weightFromKg(double kg, {required bool metric}) =>
      metric ? kg : kg / _kgPerLb;

  /// value in the active unit -> kg for storage.
  static double weightToKg(double value, {required bool metric}) =>
      metric ? value : value * _kgPerLb;

  static double heightFromCm(double cm, {required bool metric}) =>
      metric ? cm : cm / _cmPerInch;

  static double heightToCm(double value, {required bool metric}) =>
      metric ? value : value * _cmPerInch;

  static String formatWeight(
    double kg, {
    required bool metric,
    int decimals = 1,
    bool withUnit = true,
    bool persian = true,
  }) {
    final value = weightFromKg(kg, metric: metric).toStringAsFixed(decimals);
    final text = persian ? toPersianDigits(value) : value;
    return withUnit ? '$text ${weightUnit(metric: metric)}' : text;
  }

  static String formatHeight(
    double cm, {
    required bool metric,
    int decimals = 0,
    bool withUnit = true,
    bool persian = true,
  }) {
    final value = heightFromCm(cm, metric: metric).toStringAsFixed(decimals);
    final text = persian ? toPersianDigits(value) : value;
    return withUnit ? '$text ${heightUnit(metric: metric)}' : text;
  }
}
