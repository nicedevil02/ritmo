class CycleAnomaly {
  const CycleAnomaly({
    required this.titleFa,
    required this.descriptionFa,
    required this.isMild,
  });

  final String titleFa;
  final String descriptionFa;
  final bool isMild;
}

class CycleAnomalyDetector {
  static List<CycleAnomaly> detectAnomalies({
    required List<Map<String, dynamic>> periodRows,
    required double avgCycleLength,
  }) {
    final anomalies = <CycleAnomaly>[];
    if (periodRows.length < 2) return anomalies;

    // Defensive: callers pass rows in different orderings (the screen uses
    // startDate DESC). Sort ascending by startDate before taking "latest".
    final rows = [...periodRows]
      ..sort(
        (a, b) => (a['startDate'] ?? '').toString().compareTo(
          (b['startDate'] ?? '').toString(),
        ),
      );

    // Check last cycle length deviation
    final lastStart = DateTime.tryParse(
      rows.last['startDate'] as String? ?? '',
    );
    final prevStart = DateTime.tryParse(
      rows[rows.length - 2]['startDate'] as String? ?? '',
    );

    if (lastStart != null && prevStart != null) {
      final lastLength = lastStart.difference(prevStart).inDays;
      final diff = (lastLength - avgCycleLength).abs();

      if (lastLength > 0 && diff >= 7) {
        anomalies.add(
          CycleAnomaly(
            titleFa: 'تغییر در طول چرخه اخیر',
            descriptionFa:
                'طول چرخه قبلی شما ($lastLength روز) با میانگین معمول (${avgCycleLength.round()} روز) تفاوت داشته است. این روند را زیر نظر داشته باشید.',
            isMild: true,
          ),
        );
      }
    }

    return anomalies;
  }
}
