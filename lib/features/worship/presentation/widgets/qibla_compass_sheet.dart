// lib/features/worship/presentation/widgets/qibla_compass_sheet.dart
// Qibla Compass Widget (F-4) — Pure Trigonometry Qibla Azimuth calculation & Live Compass Sensor
// Uses device magnetometer/gyroscope via flutter_compass, with graceful fallback.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';

class QiblaCompassSheet extends StatefulWidget {
  const QiblaCompassSheet({
    super.key,
    this.cityLat,
    this.cityLng,
    this.cityName,
  });

  final double? cityLat;
  final double? cityLng;
  final String? cityName;

  @override
  State<QiblaCompassSheet> createState() => _QiblaCompassSheetState();
}

class _QiblaCompassSheetState extends State<QiblaCompassSheet>
    with SingleTickerProviderStateMixin {
  late double _qiblaAzimuth;
  double _lat = 35.6892;
  double _lng = 51.3890;
  String _name = 'تهران';
  bool _isLoadingCoords = true;

  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _deviceHeading;
  bool _hasCompassSensor = true;
  bool _isAlignedWithQibla = false;
  DateTime? _lastHapticTime;

  @override
  void initState() {
    super.initState();
    _initCoordinatesAndCompass();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initCoordinatesAndCompass() async {
    try {
      if (widget.cityLat != null && widget.cityLng != null) {
        _lat = widget.cityLat!;
        _lng = widget.cityLng!;
        _name = widget.cityName ?? 'موقعیت فعلی';
      } else {
        final db = await DatabaseHelper.instance.database;
        final settingsList = await db.query('app_settings');
        final settings = {
          for (final row in settingsList)
            row['key']! as String: row['value']! as String,
        };

        final cityId = settings['prayer_city_id'] ?? 'TEHRAN_TEHRAN';
        final locationMode = settings['prayer_location_mode'];

        if (locationMode == 'CUSTOM_COORDS' ||
            cityId.startsWith('CUSTOM_') ||
            cityId.startsWith('INTL_')) {
          final customLat = double.tryParse(
            settings['prayer_custom_lat'] ?? '',
          );
          final customLng = double.tryParse(
            settings['prayer_custom_lng'] ?? '',
          );
          final customName = settings['prayer_custom_city_name'];
          if (customLat != null && customLng != null) {
            _lat = customLat;
            _lng = customLng;
            _name = customName ?? 'موقعیت سفارشی';
          }
        } else {
          final cityRows = await db.query(
            'iran_cities',
            columns: ['city', 'latitude', 'longitude'],
            where: 'id = ?',
            whereArgs: [cityId],
            limit: 1,
          );
          if (cityRows.isNotEmpty) {
            _name = cityRows.first['city'] as String? ?? 'تهران';
            _lat = (cityRows.first['latitude'] as num?)?.toDouble() ?? 35.6892;
            _lng = (cityRows.first['longitude'] as num?)?.toDouble() ?? 51.3890;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading coordinates for Qibla: $e');
    }

    _qiblaAzimuth = _calculateQiblaAzimuth(_lat, _lng);

    if (mounted) {
      setState(() {
        _isLoadingCoords = false;
      });
    }

    // Subscribe to live hardware compass
    _startCompassStream();
  }

  void _startCompassStream() {
    try {
      _compassSubscription = FlutterCompass.events?.listen(
        (event) {
          if (!mounted) return;
          final heading = event.heading;
          if (heading == null) {
            setState(() => _hasCompassSensor = false);
            return;
          }

          // Normalize heading to 0..360
          final normalizedHeading = (heading + 360) % 360;

          // Calculate angle difference between top of phone and Qibla
          // When top of phone points to Qibla: (azimuth - heading) = 0
          double diff = (_qiblaAzimuth - normalizedHeading).abs();
          if (diff > 180) diff = 360 - diff;
          final isAligned = diff <= 4.0; // Within 4 degrees accuracy

          if (isAligned && !_isAlignedWithQibla) {
            final now = DateTime.now();
            if (_lastHapticTime == null ||
                now.difference(_lastHapticTime!).inMilliseconds > 1500) {
              _lastHapticTime = now;
              unawaited(HapticFeedback.heavyImpact());
            }
          }

          setState(() {
            _deviceHeading = normalizedHeading;
            _hasCompassSensor = true;
            _isAlignedWithQibla = isAligned;
          });
        },
        onError: (e) {
          debugPrint('Compass stream error: $e');
          if (mounted) {
            setState(() => _hasCompassSensor = false);
          }
        },
      );
    } catch (e) {
      debugPrint('Compass initialization failed: $e');
      if (mounted) {
        setState(() => _hasCompassSensor = false);
      }
    }
  }

  /// Calculates Qibla direction in degrees clockwise from True North.
  /// Kaaba Coordinates: 21.4225° N, 39.8262° E
  static double _calculateQiblaAzimuth(double lat, double lng) {
    const kaabaLat = 21.4225 * (math.pi / 180.0);
    const kaabaLng = 39.8262 * (math.pi / 180.0);

    final phi = lat * (math.pi / 180.0);
    final lambda = lng * (math.pi / 180.0);
    final deltaLambda = kaabaLng - lambda;

    final y = math.sin(deltaLambda);
    final x =
        math.cos(phi) * math.tan(kaabaLat) -
        math.sin(phi) * math.cos(deltaLambda);

    var azimuth = math.atan2(y, x) * (180.0 / math.pi);
    if (azimuth < 0) {
      azimuth += 360.0;
    }
    return azimuth;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final degreesStr = toPersianDigits(_qiblaAzimuth.toStringAsFixed(1));

    // Determine needle rotation angle:
    // If device heading is available, needle relative to top of phone = (_qiblaAzimuth - _deviceHeading)
    // Otherwise fallback to static azimuth from True North.
    final double needleAngleRad = _deviceHeading != null
        ? ((_qiblaAzimuth - _deviceHeading!) * (math.pi / 180.0))
        : (_qiblaAzimuth * (math.pi / 180.0));

    final double dialAngleRad = _deviceHeading != null
        ? (-_deviceHeading! * (math.pi / 180.0))
        : 0.0;

    return Container(
      height: 520,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Title & Live Alignment Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قبله‌نمای زنده',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'موقعیت: $_name ($degreesStr° نسبت به شمال)',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _isAlignedWithQibla
                      ? Colors.green.withValues(alpha: 0.18)
                      : (_hasCompassSensor && _deviceHeading != null
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.surfaceSunken),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAlignedWithQibla
                        ? Colors.green
                        : (_hasCompassSensor && _deviceHeading != null
                              ? colors.primary.withValues(alpha: 0.4)
                              : colors.border.withValues(alpha: 0.2)),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isAlignedWithQibla
                          ? CupertinoIcons.check_mark_circled_solid
                          : (_hasCompassSensor && _deviceHeading != null
                                ? CupertinoIcons.compass
                                : CupertinoIcons.location_north),
                      size: 14,
                      color: _isAlignedWithQibla
                          ? Colors.green
                          : (_hasCompassSensor && _deviceHeading != null
                                ? colors.primary
                                : colors.textSecondary),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isAlignedWithQibla
                          ? 'رو به قبله 🕋'
                          : (_hasCompassSensor && _deviceHeading != null
                                ? 'سنسور فعال 🧭'
                                : 'حالت آفلاین'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _isAlignedWithQibla
                            ? Colors.green
                            : (_hasCompassSensor && _deviceHeading != null
                                  ? colors.primary
                                  : colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compass Rose UI
          Expanded(
            child: _isLoadingCoords
                ? const Center(child: CupertinoActivityIndicator())
                : Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Compass Ring & Rotating Dial
                        Transform.rotate(
                          angle: dialAngleRad,
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.background,
                              border: Border.all(
                                color: _isAlignedWithQibla
                                    ? Colors.green.withValues(alpha: 0.8)
                                    : colors.textPrimary.withValues(
                                        alpha: 0.12,
                                      ),
                                width: _isAlignedWithQibla ? 3.5 : 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _isAlignedWithQibla
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.06),
                                  blurRadius: _isAlignedWithQibla ? 20 : 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Stack(
                              alignment: Alignment.center,
                              children: [
                                // Cardinal Labels
                                Positioned(
                                  top: 10,
                                  child: Text(
                                    'شمال (N)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  child: Text(
                                    'جنوب (S)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 10,
                                  child: Text(
                                    'W',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  child: Text(
                                    'E',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Fixed Direction Arrow at Top of Phone
                        Positioned(
                          top: 10,
                          child: Icon(
                            CupertinoIcons.chevron_up,
                            size: 20,
                            color: _isAlignedWithQibla
                                ? Colors.green
                                : colors.primary,
                          ),
                        ),

                        // Qibla Pointer Needle
                        Transform.rotate(
                          angle: needleAngleRad,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Kaaba Icon Pointer
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: _isAlignedWithQibla ? 42 : 36,
                                height: _isAlignedWithQibla ? 42 : 36,
                                decoration: BoxDecoration(
                                  color: _isAlignedWithQibla
                                      ? Colors.green
                                      : colors.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _isAlignedWithQibla
                                          ? Colors.green.withValues(alpha: 0.6)
                                          : colors.accent.withValues(
                                              alpha: 0.4,
                                            ),
                                      blurRadius: _isAlignedWithQibla ? 16 : 10,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    '🕋',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              Container(
                                width: _isAlignedWithQibla ? 4 : 3,
                                height: 75,
                                decoration: BoxDecoration(
                                  color: _isAlignedWithQibla
                                      ? Colors.green
                                      : colors.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 75), // Center pivot offset
                            ],
                          ),
                        ),

                        // Center Pivot
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isAlignedWithQibla
                                ? Colors.green
                                : colors.primary,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 10),

          // Status & Calibration Info Text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceSunken.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  size: 14,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _isAlignedWithQibla
                        ? '✨ جهت گوشی شما دقیقاً رو به قبله است.'
                        : (_hasCompassSensor && _deviceHeading != null
                              ? 'گوشی را بچرخانید تا نشانگر 🕋 به سمت بالای صفحه قرار گیرد.'
                              : 'گوشی را افقی نگه دارید و دور از میدان‌های مغناطیسی قرار دهید.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: _isAlignedWithQibla
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _isAlignedWithQibla
                          ? Colors.green
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
