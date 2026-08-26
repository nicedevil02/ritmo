/// Calculates concrete [startDt] and [endDt] timestamps for a given schedule window
/// around [now], handling cross-midnight time ranges correctly.
({DateTime startDt, DateTime endDt}) calculateScheduleBounds({
  required DateTime now,
  required String startTime,
  required String endTime,
}) {
  final startParts = startTime.split(':');
  final endParts = endTime.split(':');
  final startH = int.tryParse(startParts[0]) ?? 0;
  final startM = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;
  final endH = int.tryParse(endParts[0]) ?? 0;
  final endM = endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0;

  var startDt = DateTime(now.year, now.month, now.day, startH, startM);
  var endDt = DateTime(now.year, now.month, now.day, endH, endM);

  if (startDt.isAfter(endDt)) {
    // Cross-midnight range e.g. 23:00 to 05:00
    if (now.hour < endH || (now.hour == endH && now.minute < endM)) {
      // We are in the early morning part (after midnight)
      startDt = startDt.subtract(const Duration(days: 1));
    } else {
      // We are in the late night part (before midnight)
      endDt = endDt.add(const Duration(days: 1));
    }
  }

  return (startDt: startDt, endDt: endDt);
}
