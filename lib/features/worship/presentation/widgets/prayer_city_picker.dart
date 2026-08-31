import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/services/device_location_service.dart';
import 'package:ritmo/core/services/prayer_time_provider.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_snackbar.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:sqflite/sqflite.dart';

class PrayerCityPicker extends StatefulWidget {

  const PrayerCityPicker({
    super.key,
    required this.onChanged,
    this.initialTab = 0,
  });
  final VoidCallback onChanged;
  final int initialTab;

  @override
  State<PrayerCityPicker> createState() => _PrayerCityPickerState();
}

class _PrayerCityPickerState extends State<PrayerCityPicker> {
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _filteredCities = [];
  bool _isLoadingCities = true;
  bool _isLocatingGps = false;

  // Settings State
  String _selectedMethod = 'TEHRAN_GEOPHYSICS';
  String _currentCityId = 'TEHRAN_TEHRAN';
  String _customCityName = '';
  final Set<String> _expandedGroups = {};
  String _searchQuery = '';

  static const List<Map<String, dynamic>> _internationalCities = [
    {'id': 'INTL_NAJAF', 'city': 'نجف اشرف', 'province': 'عراق (زیارتی)', 'latitude': 32.0259, 'longitude': 44.3463},
    {'id': 'INTL_KARBALA', 'city': 'کربلای معلی', 'province': 'عراق (زیارتی)', 'latitude': 32.6160, 'longitude': 44.0249},
    {'id': 'INTL_MAKKAH', 'city': 'مکه مکرمه', 'province': 'عربستان سعودی (حج)', 'latitude': 21.4225, 'longitude': 39.8262},
    {'id': 'INTL_MADINAH', 'city': 'مدینه منوره', 'province': 'عربستان سعودی (زیارتی)', 'latitude': 24.5247, 'longitude': 39.5692},
    {'id': 'INTL_KADHIMIYA', 'city': 'کاظمین', 'province': 'عراق (زیارتی)', 'latitude': 33.3800, 'longitude': 44.3400},
    {'id': 'INTL_SAMARRA', 'city': 'سامرا', 'province': 'عراق (زیارتی)', 'latitude': 34.1983, 'longitude': 43.8742},
    {'id': 'INTL_DAMASCUS', 'city': 'دمشق (حرم حضرت زینب)', 'province': 'سوریه (زیارتی)', 'latitude': 33.5138, 'longitude': 36.2765},
    {'id': 'INTL_ISTANBUL', 'city': 'استانبول', 'province': 'ترکیه', 'latitude': 41.0082, 'longitude': 28.9784},
    {'id': 'INTL_DUBAI', 'city': 'دبی', 'province': 'امارات متحده عربی', 'latitude': 25.2048, 'longitude': 55.2708},
    {'id': 'INTL_DOHA', 'city': 'دوحه', 'province': 'قطر', 'latitude': 25.2854, 'longitude': 51.5310},
    {'id': 'INTL_LONDON', 'city': 'لندن', 'province': 'انگلستان', 'latitude': 51.5074, 'longitude': -0.1278},
    {'id': 'INTL_TORONTO', 'city': 'تورنتو', 'province': 'کانادا', 'latitude': 43.6532, 'longitude': -79.3832},
    {'id': 'INTL_FRANKFURT', 'city': 'فرانکفورت', 'province': 'آلمان', 'latitude': 50.1109, 'longitude': 8.6821},
    {'id': 'INTL_SYDNEY', 'city': 'سیدنی', 'province': 'استرالیا', 'latitude': -33.8688, 'longitude': 151.2093},
    {'id': 'INTL_KUALA_LUMPUR', 'city': 'کوالالامپور', 'province': 'مالزی', 'latitude': 3.1390, 'longitude': 101.6869},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettingsAndCities();
  }

  Future<void> _loadSettingsAndCities() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Load Settings
      final settingsList = await db.query('app_settings');
      final settings = {
        for (final row in settingsList) row['key']! as String: row['value']! as String
      };

      _selectedMethod = settings['prayer_calculation_method'] ?? 'TEHRAN_GEOPHYSICS';
      _currentCityId = settings['prayer_city_id'] ?? 'TEHRAN_TEHRAN';
      _customCityName = settings['prayer_custom_city_name'] ?? '';

      // Load Cities from DB (iran_cities) and merge with international cities
      final cityResults = await db.query('iran_cities', orderBy: 'city ASC');
      final merged = <Map<String, dynamic>>[
        ..._internationalCities,
        ...cityResults,
      ];

      // Auto-expand group of currently selected city
      if (_currentCityId.startsWith('INTL_')) {
        _expandedGroups.add('🌍 بین‌المللی و زیارتی');
      } else {
        final currentCityMatch = merged.firstWhere(
          (c) => c['id'] == _currentCityId,
          orElse: () => {},
        );
        if (currentCityMatch.isNotEmpty) {
          final prov = (currentCityMatch['province'] as String? ?? '').trim();
          final provClean = prov.replaceFirst(RegExp(r'^استان\s*'), '').trim();
          _expandedGroups.add(provClean.isNotEmpty ? provClean : 'تهران');
        } else {
          _expandedGroups.add('تهران');
        }
      }
      
      if (mounted) {
        setState(() {
          _cities = merged;
          _filteredCities = merged;
          _isLoadingCities = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings and cities: $e');
      if (mounted) {
        setState(() {
          _isLoadingCities = false;
        });
      }
    }
  }

  /// Normalize Persian/Arabic text for search: maps Persian-specific
  /// characters to their Arabic equivalents and strips diacritics/
  /// zero-width characters so that partial queries like "کب" match "كبودرآهنگ".
  String _normalizePersian(String text) {
    var s = text.toLowerCase();
    s = s.replaceAll('\u06A9', '\u0643'); // ک → ك
    s = s.replaceAll('\u06CC', '\u064A'); // ی → ي
    s = s.replaceAll('\u0629', '\u0647'); // ة → ه
    s = s.replaceAll('\u0671', '\u0627'); // ٱ → ا
    s = s.replaceAll('\u200C', ''); // ZWNJ
    s = s.replaceAll('\u200D', ''); // ZWJ
    s = s.replaceAll(RegExp('[\u0617-\u061A\u064B-\u0652]'), '');
    return s;
  }

  void _filterCities(String query) {
    setState(() {
      _searchQuery = query.trim();
      if (_searchQuery.isEmpty) {
        _filteredCities = _cities;
      } else {
        final q = _normalizePersian(_searchQuery);
        _filteredCities = _cities.where((c) {
          final cityName = _normalizePersian(c['city'] as String? ?? '');
          final provinceName = _normalizePersian(c['province'] as String? ?? '');
          return cityName.contains(q) || provinceName.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _selectCity(Map<String, dynamic> cityData) async {
    unawaited(HapticFeedback.mediumImpact());
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cityId = cityData['id'] as String;
      final cityName = cityData['city'] as String;
      final isIntl = cityId.startsWith('INTL_');

      setState(() {
        _currentCityId = cityId;
        _customCityName = cityName;
      });

      final batch = db.batch();
      batch.insert(
        'app_settings',
        {
          'key': 'prayer_city_id',
          'value': cityId,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_settings',
        {
          'key': 'home_city_id',
          'value': cityId,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (isIntl) {
        batch.insert(
          'app_settings',
          {
            'key': 'prayer_location_mode',
            'value': 'CUSTOM_COORDS',
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          'app_settings',
          {
            'key': 'prayer_custom_city_name',
            'value': cityName,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          'app_settings',
          {
            'key': 'prayer_custom_lat',
            'value': (cityData['latitude'] as num).toDouble().toString(),
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          'app_settings',
          {
            'key': 'prayer_custom_lng',
            'value': (cityData['longitude'] as num).toDouble().toString(),
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        batch.insert(
          'app_settings',
          {
            'key': 'prayer_location_mode',
            'value': 'CITY',
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      batch.delete('prayer_times_cache');
      await batch.commit(noResult: true);

      WorshipEngine.instance.invalidate();

      // Batch cache 40 days
      await PrayerTimeProvider.instance.cacheRange(
        cityId: cityId,
        from: DateTime.now(),
        days: 40,
        calculationMethod: _selectedMethod,
      );

      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
        RitmoSnackbar.success(context, 'موقعیت مکانی روی «$cityName» تنظیم شد 🕌');
      }
    } catch (e) {
      debugPrint('Error saving selected city: $e');
    }
  }

  /// محاسبه فاصله دو نقطه جغرافیایی بر حسب کیلومتر با فرمول کروی Haversine
  static double _calculateHaversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// یافتن نزدیک‌ترین شهر از بین لیست شهرهای ایران و بین‌المللی
  Map<String, dynamic>? _findNearestCity(double lat, double lng) {
    if (_cities.isEmpty) return null;

    Map<String, dynamic>? closest;
    double minDistanceKm = double.infinity;

    for (final city in _cities) {
      final cityLat = (city['latitude'] as num?)?.toDouble();
      final cityLng = (city['longitude'] as num?)?.toDouble();
      if (cityLat == null || cityLng == null) continue;

      final distance = _calculateHaversineDistanceKm(lat, lng, cityLat, cityLng);
      if (distance < minDistanceKm) {
        minDistanceKm = distance;
        closest = {
          ...city,
          'distanceKm': distance,
        };
      }
    }

    return closest;
  }

  Future<void> _fetchAndApplyGpsLocation() async {
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _isLocatingGps = true);
    try {
      final position = await DeviceLocationService.instance.getCurrentPosition(context);
      if (position == null) {
        setState(() => _isLocatingGps = false);
        return;
      }

      final lat = double.parse(position.latitude.toStringAsFixed(4));
      final lng = double.parse(position.longitude.toStringAsFixed(4));

      // 1. Find the closest city from database using Haversine calculation
      final nearestCity = _findNearestCity(lat, lng);
      final double distanceKm = (nearestCity?['distanceKm'] as num?)?.toDouble() ?? 999.0;

      final String cityId;
      final String cityName;
      final String locationMode;
      final String? province = nearestCity?['province'] as String?;

      if (nearestCity != null && distanceKm <= 35.0) {
        // Direct match to known city (within 35 km radius)
        cityId = nearestCity['id'] as String;
        cityName = nearestCity['city'] as String;
        final isIntl = cityId.startsWith('INTL_');
        locationMode = isIntl ? 'CUSTOM_COORDS' : 'CITY';
      } else if (nearestCity != null) {
        // Near a known city (> 35 km away, like outer areas/suburbs/roads)
        cityId = 'CUSTOM_GPS';
        final baseName = nearestCity['city'] as String;
        cityName = '$baseName (موقعیت مکانی شما)';
        locationMode = 'CUSTOM_COORDS';
      } else {
        cityId = 'CUSTOM_GPS';
        cityName = 'موقعیت زنده (GPS)';
        locationMode = 'CUSTOM_COORDS';
      }

      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      setState(() {
        _currentCityId = cityId;
        _customCityName = cityName;
      });

      final batch = db.batch();
      batch.insert(
        'app_settings',
        {'key': 'prayer_city_id', 'value': cityId, 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_settings',
        {'key': 'home_city_id', 'value': cityId, 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_settings',
        {'key': 'prayer_location_mode', 'value': locationMode, 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_settings',
        {'key': 'prayer_custom_lat', 'value': lat.toString(), 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_settings',
        {'key': 'prayer_custom_lng', 'value': lng.toString(), 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_settings',
        {'key': 'prayer_custom_city_name', 'value': cityName, 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      batch.delete('prayer_times_cache');
      await batch.commit(noResult: true);

      WorshipEngine.instance.invalidate();

      await PrayerTimeProvider.instance.cacheRange(
        cityId: cityId,
        from: DateTime.now(),
        days: 40,
        calculationMethod: _selectedMethod,
      );

      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
        final String successMessage;
        if (nearestCity != null && distanceKm <= 35.0) {
          final provDisplay = province != null && province.isNotEmpty ? ' ($province)' : '';
          successMessage = 'شهر شما «$cityName$provDisplay» بر اساس موقعیت مکانی تنظیم شد 📍';
        } else {
          successMessage = 'موقعیت شما در نزدیکی «$cityName» اعمال شد 📍\nعرض: ${toPersianDigits(lat.toString())} | طول: ${toPersianDigits(lng.toString())}';
        }
        RitmoSnackbar.success(context, successMessage);
      }
    } catch (e) {
      debugPrint('Error applying GPS location: $e');
      if (mounted) {
        RitmoSnackbar.error(context, 'خطا در ذخیره و اعمال موقعیت GPS. لطفاً دوباره امتحان کنید.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLocatingGps = false);
      }
    }
  }

  Future<void> _openCustomCoordinatesDialog() async {
    final nameCtrl = TextEditingController(text: _customCityName.isNotEmpty ? _customCityName : 'موقعیت سفارشی');
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    bool isFetchingDialogGps = false;

    final db = await DatabaseHelper.instance.database;
    final customSettings = await db.query(
      'app_settings',
      where: "key IN ('prayer_custom_lat', 'prayer_custom_lng', 'prayer_custom_city_name')",
    );
    for (final r in customSettings) {
      if (r['key'] == 'prayer_custom_lat') latCtrl.text = r['value']?.toString() ?? '';
      if (r['key'] == 'prayer_custom_lng') lngCtrl.text = r['value']?.toString() ?? '';
      if (r['key'] == 'prayer_custom_city_name') nameCtrl.text = r['value']?.toString() ?? 'موقعیت سفارشی';
    }

    if (!mounted) return;
    final colors = context.colors;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              '📍 ثبت مختصات دلخواه (GPS)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: colors.textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'برای مناطق خارج از لیست یا محاسبه بر اساس GPS، نام و مختصات نقطه را وارد کنید:',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                    icon: isFetchingDialogGps
                        ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                        : Icon(CupertinoIcons.location_fill, size: 16, color: colors.primary),
                    label: Text(
                      'دریافت مختصات از GPS گوشی',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                    onPressed: isFetchingDialogGps
                        ? null
                        : () async {
                            setDialogState(() => isFetchingDialogGps = true);
                            final pos = await DeviceLocationService.instance.getCurrentPosition(context);
                            if (pos != null) {
                              final dLat = double.parse(pos.latitude.toStringAsFixed(4));
                              final dLng = double.parse(pos.longitude.toStringAsFixed(4));
                              latCtrl.text = dLat.toString();
                              lngCtrl.text = dLng.toString();
                              final nearest = _findNearestCity(dLat, dLng);
                              if (nearest != null) {
                                nameCtrl.text = nearest['city'] as String? ?? 'موقعیت من (GPS)';
                              } else {
                                nameCtrl.text = 'موقعیت من (GPS)';
                              }
                            }
                            setDialogState(() => isFetchingDialogGps = false);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'نام موقعیت / شهر',
                      labelStyle: TextStyle(fontSize: 13, color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surfaceSunken,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: latCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: 'عرض جغرافیایی (Latitude مثلاً 35.6892)',
                      labelStyle: TextStyle(fontSize: 13, color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surfaceSunken,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: 'طول جغرافیایی (Longitude مثلاً 51.3890)',
                      labelStyle: TextStyle(fontSize: 13, color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surfaceSunken,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final lat = double.tryParse(latCtrl.text.trim());
                  final lng = double.tryParse(lngCtrl.text.trim());
                  final name = nameCtrl.text.trim().isEmpty ? 'موقعیت سفارشی' : nameCtrl.text.trim();

                  if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
                    RitmoSnackbar.error(context, 'مختصات جغرافیایی وارد شده نامعتبر است.');
                    return;
                  }

                Navigator.pop(ctx);
                final customId = 'CUSTOM_${DateTime.now().millisecondsSinceEpoch}';
                await _selectCity({
                  'id': customId,
                  'city': name,
                  'province': 'مختصات جغرافیایی دلخواه',
                  'latitude': lat,
                  'longitude': lng,
                });
                },
                child: const Text('ذخیره و اعمال'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedPadding(
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
          ),
          child: RitmoGlassSheet(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Canonical Symmetrical Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Leading (Right in RTL): Circular Tactile Close (X) Button
                      GestureDetector(
                        onTap: () {
                          RitmoHapticsPolicy.tap();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceElevated.withValues(alpha: 0.85)
                                : colors.textPrimary.withValues(alpha: 0.07),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? colors.border.withValues(alpha: 0.35)
                                  : colors.border.withValues(alpha: 0.15),
                              width: 0.85,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 15,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),

                      // Center: Title
                      Expanded(
                        child: Text(
                          'انتخاب شهر و موقعیت مکانی',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),

                      // Trailing (Left in RTL): Symmetrical Spacer
                      const SizedBox(width: 34, height: 34),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Content Area: Direct City List
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildCityTab(colors),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityTab(RitmoColors colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingCities) {
      return Center(
        child: CircularProgressIndicator(color: colors.textPrimary),
      );
    }

    return Column(
      children: [
        // Search TextField
        TextField(
          onChanged: _filterCities,
          style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: 'جستجوی نام شهر یا استان...',
            hintStyle: TextStyle(
              color: colors.textSecondary.withValues(alpha: 0.7),
              fontSize: 13.5,
            ),
            prefixIcon: Icon(CupertinoIcons.search, color: colors.primary, size: 20),
            fillColor: isDark
                ? colors.surfaceElevated.withValues(alpha: 0.6)
                : colors.surface.withValues(alpha: 0.85),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? colors.border.withValues(alpha: 0.5)
                    : colors.border.withValues(alpha: 0.8),
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: colors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // GPS Auto-Location & Custom Coordinates Buttons
        Row(
          children: [
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  elevation: 0,
                ),
                icon: _isLocatingGps
                    ? SizedBox(width: 16, height: 16, child: CupertinoActivityIndicator(color: colors.onPrimary))
                    : Icon(CupertinoIcons.location_fill, size: 16, color: colors.onPrimary),
                label: Text(
                  _isLocatingGps ? 'در حال دریافت GPS...' : 'موقعیت‌یابی با GPS',
                  style: TextStyle(color: colors.onPrimary, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                onPressed: _isLocatingGps ? null : _fetchAndApplyGpsLocation,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.surfaceSunken.withValues(alpha: 0.6),
                  side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                ),
                icon: Icon(CupertinoIcons.pencil_ellipsis_rectangle, color: colors.primary, size: 16),
                label: Text(
                  'ثبت دستی',
                  style: TextStyle(color: colors.primary, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                onPressed: _openCustomCoordinatesDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // List of Cities grouped by Province / International
        Expanded(
          child: _buildGroupedCityList(colors),
        ),
      ],
    );
  }

  Widget _buildGroupedCityList(RitmoColors colors) {
    if (_filteredCities.isEmpty) {
      return Center(
        child: Text(
          'هیچ شهری یافت نشد.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14.5),
        ),
      );
    }

    // 1. Group international cities and Iranian cities by province
    final intlCities = <Map<String, dynamic>>[];
    final provinceGroups = <String, List<Map<String, dynamic>>>{};

    for (final city in _filteredCities) {
      final id = city['id'] as String? ?? '';
      if (id.startsWith('INTL_')) {
        intlCities.add(city);
      } else {
        final province = (city['province'] as String? ?? 'سایر').trim();
        final provinceKey = province.replaceFirst(RegExp(r'^استان\s*'), '').trim();
        provinceGroups.putIfAbsent(provinceKey.isNotEmpty ? provinceKey : 'سایر', () => []).add(city);
      }
    }

    // Sort Iranian provinces alphabetically
    final sortedProvinceKeys = provinceGroups.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    // 2. Flatten into a linear list of headers and city items based on expanded state
    final displayItems = <_CityListRow>[];

    if (intlCities.isNotEmpty) {
      const intlKey = '🌍 بین‌المللی و زیارتی';
      final isExpanded = _searchQuery.isNotEmpty || _expandedGroups.contains(intlKey);
      displayItems.add(_CityListRow.header(
        intlKey,
        groupKey: intlKey,
        isInternational: true,
        count: intlCities.length,
        isExpanded: isExpanded,
      ));
      if (isExpanded) {
        for (final c in intlCities) {
          displayItems.add(_CityListRow.city(c));
        }
      }
    }

    for (final provinceKey in sortedProvinceKeys) {
      final list = provinceGroups[provinceKey]!;
      final isExpanded = _searchQuery.isNotEmpty || _expandedGroups.contains(provinceKey);
      displayItems.add(_CityListRow.header(
        provinceKey,
        groupKey: provinceKey,
        isInternational: false,
        count: list.length,
        isExpanded: isExpanded,
      ));
      if (isExpanded) {
        for (final c in list) {
          displayItems.add(_CityListRow.city(c));
        }
      }
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final item = displayItems[index];

        if (item.isHeader) {
          final isExpanded = item.isExpanded;
          final groupKey = item.groupKey!;

          return Container(
            margin: EdgeInsets.only(top: index == 0 ? 2 : 10, bottom: 4),
            child: Material(
              color: isExpanded ? colors.primary.withValues(alpha: 0.08) : colors.surfaceSunken.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (_expandedGroups.contains(groupKey)) {
                      _expandedGroups.remove(groupKey);
                    } else {
                      _expandedGroups.add(groupKey);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        item.isInternational ? CupertinoIcons.globe : CupertinoIcons.map_pin_ellipse,
                        size: 16,
                        color: isExpanded ? colors.primary : colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.headerTitle!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: isExpanded ? colors.primary : colors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isExpanded ? colors.primary.withValues(alpha: 0.15) : colors.surfaceSunken,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          toPersianDigits('${item.count} شهر'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isExpanded ? colors.primary : colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          CupertinoIcons.chevron_down,
                          size: 14,
                          color: isExpanded ? colors.primary : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final cityData = item.cityData!;
        final cityId = cityData['id'] as String;
        final cityName = cityData['city'] as String;
        final provinceName = cityData['province'] as String;
        final isSelected = cityId == _currentCityId;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.5)
                  : colors.border.withValues(alpha: 0.3),
            ),
          ),
          child: Material(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surfaceSunken.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
              title: Text(
                cityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? colors.primary : colors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                provinceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              trailing: isSelected
                  ? Icon(CupertinoIcons.checkmark_alt, color: colors.primary, size: 18)
                  : Icon(CupertinoIcons.location, color: colors.textSecondary.withValues(alpha: 0.35), size: 15),
              onTap: () => _selectCity(cityData),
            ),
          ),
        );
      },
    );
  }
}

class _CityListRow {
  final bool isHeader;
  final String? headerTitle;
  final String? groupKey;
  final bool isInternational;
  final int count;
  final bool isExpanded;
  final Map<String, dynamic>? cityData;

  const _CityListRow._({
    required this.isHeader,
    this.headerTitle,
    this.groupKey,
    this.isInternational = false,
    this.count = 0,
    this.isExpanded = false,
    this.cityData,
  });

  factory _CityListRow.header(
    String title, {
    required String groupKey,
    required bool isInternational,
    required int count,
    required bool isExpanded,
  }) {
    return _CityListRow._(
      isHeader: true,
      headerTitle: title,
      groupKey: groupKey,
      isInternational: isInternational,
      count: count,
      isExpanded: isExpanded,
    );
  }

  factory _CityListRow.city(Map<String, dynamic> cityData) {
    return _CityListRow._(
      isHeader: false,
      cityData: cityData,
    );
  }
}
