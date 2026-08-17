import 'package:ritmo/core/util/ritmo_number.dart';

/// Legacy helper for Persian digits, wraps [RitmoNumber.toFa].
@Deprecated('Use RitmoNumber.toFa() or RitmoNumber.fa() directly instead.')
String toPersianDigits(dynamic input) {
  return RitmoNumber.toFa(input);
}

/// Formats duration in minutes to Persian representation, wraps [RitmoNumber.formatDuration].
String formatDuration(int minutes) {
  return RitmoNumber.formatDuration(minutes);
}
