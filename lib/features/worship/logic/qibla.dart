import 'dart:math' as math;

const double kKaabaLat = 21.4225;
const double kKaabaLon = 39.8262;

/// Calculates Qibla azimuth bearing in degrees clockwise from True North [0..360].
double qiblaBearing(double lat, double lon) {
  final phi = lat * math.pi / 180;
  final dLambda = (kKaabaLon - lon) * math.pi / 180;
  const phiK = kKaabaLat * math.pi / 180;

  final y = math.sin(dLambda);
  final x = math.cos(phi) * math.tan(phiK) - math.sin(phi) * math.cos(dLambda);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// Computes magnetic declination (magnetic variation) in degrees for [lat], [lon] at [date].
/// Positive values indicate East declination, negative values indicate West declination.
/// Corrects magnetic heading from sensor to True North (M12).
double magneticDeclination(double lat, double lon, [DateTime? date]) {
  final targetDate = date ?? DateTime.now();
  final yearFraction = targetDate.year + (targetDate.month - 1) / 12.0 + (targetDate.day - 1) / 365.25;
  final dt = yearFraction - 2020.0;

  // Geomagnetic dipole coordinates (WMM epoch model)
  final poleLat = (80.65 + 0.05 * dt) * math.pi / 180;
  final poleLon = (-72.68 - 0.35 * dt) * math.pi / 180;

  final phi = lat * math.pi / 180;
  final lambda = lon * math.pi / 180;

  final dLambda = poleLon - lambda;
  final y = math.sin(dLambda);
  final x = math.cos(phi) * math.tan(poleLat) - math.sin(phi) * math.cos(dLambda);

  final dipoleDec = math.atan2(y, x) * 180 / math.pi;
  final lonNorm = (lon > 180 ? lon - 360 : lon);
  final correction = 13.5 * math.sin((lonNorm + 60) * math.pi / 180) * math.cos(phi);
  return dipoleDec + correction;
}

/// Calculates Qibla azimuth bearing relative to Magnetic North.
double magneticQiblaBearing(double lat, double lon, [DateTime? date]) {
  final trueAzimuth = qiblaBearing(lat, lon);
  final dec = magneticDeclination(lat, lon, date);
  return (trueAzimuth - dec + 360) % 360;
}

