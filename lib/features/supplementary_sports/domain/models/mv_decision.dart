/// Standard container for any intelligent decision or suggestion produced by engines.
///
/// Follows R-01 (Rule 2: Explainability, Rule 7: Data Maturity, Rule 19: Source traceability).
class MvDecision<T> {
  /// The resulting decision, plan, prescription or item.
  final T value;

  /// Human-readable explanation in Persian explaining "Why this decision".
  final String reasonFa;

  /// Data sources used to reach this decision (e.g. 'sleep', 'energy', 'cycle', 'checkin', 'history').
  final List<String> sources;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Indicates whether sufficient baseline data existed to make an informed decision.
  final bool hasEnoughData;

  const MvDecision({
    required this.value,
    required this.reasonFa,
    this.sources = const [],
    this.confidence = 1.0,
    this.hasEnoughData = true,
  });

  MvDecision<R> map<R>(R Function(T v) transform) {
    return MvDecision<R>(
      value: transform(value),
      reasonFa: reasonFa,
      sources: sources,
      confidence: confidence,
      hasEnoughData: hasEnoughData,
    );
  }

  @override
  String toString() => 'MvDecision(value: $value, reasonFa: "$reasonFa", confidence: $confidence, hasEnoughData: $hasEnoughData)';
}
