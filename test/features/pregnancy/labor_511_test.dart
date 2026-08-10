import 'package:flutter_test/flutter_test.dart';

bool check511LaborAlert(List<Map<String, dynamic>> contractionLogs, int nowMs) {
  if (contractionLogs.length < 3) return false;

  final oneHourAgo = nowMs - 3600000;
  final recent = contractionLogs.where((c) {
    final logged = (c['loggedAt'] as int?) ?? 0;
    return logged >= oneHourAgo;
  }).toList();

  if (recent.length < 3) return false;

  final newestTime = (recent.first['loggedAt'] as int?) ?? 0;
  final oldestTime = (recent.last['loggedAt'] as int?) ?? 0;
  if (newestTime - oldestTime < 3600000) return false;

  int matchesCount = 0;
  for (var i = 0; i < recent.length; i++) {
    final duration = (recent[i]['durationSeconds'] as int?) ?? 0;
    final interval = (recent[i]['intervalFromPrevious'] as int?) ?? 0;

    final validDuration = duration >= 60;
    final validInterval = (i == recent.length - 1) || (interval > 0 && interval <= 300);

    if (validDuration && validInterval) {
      matchesCount++;
    }
  }

  return (matchesCount / recent.length) >= 0.8;
}

void main() {
  group('PREG-13: 5-1-1 Labor Logic Tests', () {
    test('3 contractions in 10 minutes => False (Duration span < 1 hour)', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final logs = [
        {'durationSeconds': 65, 'intervalFromPrevious': 300, 'loggedAt': now},
        {'durationSeconds': 62, 'intervalFromPrevious': 300, 'loggedAt': now - 300000},
        {'durationSeconds': 70, 'intervalFromPrevious': 0, 'loggedAt': now - 600000},
      ];
      expect(check511LaborAlert(logs, now), isFalse);
    });

    test('Consistent 5-min contractions spanning 60 mins => True', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final logs = <Map<String, dynamic>>[];
      for (int i = 0; i < 13; i++) {
        logs.add({
          'durationSeconds': 65,
          'intervalFromPrevious': i == 12 ? 0 : 300,
          'loggedAt': now - (i * 300000),
        });
      }
      expect(check511LaborAlert(logs, now), isTrue);
    });

    test('Single short 55s contraction does not suppress alert (Majority rule)', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final logs = <Map<String, dynamic>>[];
      for (int i = 0; i < 13; i++) {
        logs.add({
          'durationSeconds': i == 5 ? 55 : 65,
          'intervalFromPrevious': i == 12 ? 0 : 300,
          'loggedAt': now - (i * 300000),
        });
      }
      expect(check511LaborAlert(logs, now), isTrue);
    });
  });
}
