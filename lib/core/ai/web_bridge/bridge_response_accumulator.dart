// A-03: BridgeResponseAccumulator — Single source of truth for ChatGPT response accumulation
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';

class AccumulatorDelta {
  const AccumulatorDelta({
    required this.delta,
    required this.fullText,
    this.isRewrite = false,
  });

  final String delta;
  final bool isRewrite;
  final String fullText;

  @override
  String toString() => 'AccumulatorDelta(deltaLen: ${delta.length}, fullLen: ${fullText.length}, rewrite: $isRewrite)';
}

class BridgeResponseAccumulator {
  String _currentText = '';

  String get text => _currentText;
  int get length => _currentText.length;
  bool get isEmpty => _currentText.isEmpty;

  void reset() {
    _currentText = '';
  }

  /// Sanitizes text, stripping ChatGPT UI prefixes and disclaimers.
  static String sanitize(String text) {
    var clean = text.trim();
    if (clean.isEmpty) return '';

    // 1. Remove prefixes like "ChatGPT گفت:", ":ChatGPT گفت:", "ChatGPT said:", "چت‌جی‌پی‌تی گفت:", "ChatGPT:"
    final prefixRe = RegExp(
      r'^(?:[•\-\*#\s:>`]|\[\d+\])*(?:ChatGPT|چت‌جی‌پی‌تی|Assistant|You|شما)\s*(?:said|گفت|گفتید)?\s*[:：\-\*]*\s*',
      caseSensitive: false,
    );
    clean = clean.replaceAll(prefixRe, '').trim();

    // 2. Remove markdown bold wrappers like **ChatGPT گفت:** or **ChatGPT said:** if still present
    final markdownBoldPrefixRe = RegExp(
      r'^(?:\*\*|\*|#+\s*)?(?:ChatGPT|چت‌جی‌پی‌تی|Assistant)\s*(?:گفت|said)?\s*[:：\-\*]*(?:\*\*|\*)?\s*',
      caseSensitive: false,
    );
    clean = clean.replaceAll(markdownBoldPrefixRe, '').trim();

    // 3. Strip trailing disclaimers (English & Persian)
    final disclaimerRe = RegExp(
      r'(?:\n\s*)?ChatGPT\s*(?:هوش مصنوعی است و ممکن است اشتباه کند|ممکن است اشتباه کند|can make mistakes[^\n]*)\.?\s*$',
      caseSensitive: false,
    );
    clean = clean.replaceAll(disclaimerRe, '').trim();

    return clean;
  }

  /// Applies a fullText payload, computing exact delta or rewrite signal.
  AccumulatorDelta? applyFull(String incomingFull, {required String source}) {
    final sanitized = sanitize(incomingFull);
    if (sanitized.isEmpty) {
      return null;
    }

    if (sanitized == _currentText) {
      return null;
    }

    if (_currentText.isEmpty) {
      _currentText = sanitized;
      return AccumulatorDelta(
        delta: sanitized,
        fullText: sanitized,
        isRewrite: false,
      );
    }

    // Standard progressive growth: previous text is prefix of incoming
    if (sanitized.startsWith(_currentText)) {
      final d = sanitized.substring(_currentText.length);
      _currentText = sanitized;
      return AccumulatorDelta(
        delta: d,
        fullText: sanitized,
        isRewrite: false,
      );
    }

    // Transient DOM retreat (incoming is shorter but is prefix of current)
    if (_currentText.startsWith(sanitized)) {
      BridgeTraceLog.instance.addEntry(
        type: 'accumulator_retreat',
        source: source,
        textLength: sanitized.length,
        note: 'transient_dom_retreat_ignored (currentLen=${_currentText.length})',
        level: BridgeTraceLevel.info,
      );
      return null;
    }

    // Divergent rewrite (node substitution or significant markup replacement)
    _currentText = sanitized;
    BridgeTraceLog.instance.addEntry(
      type: 'accumulator_rewrite',
      source: source,
      textLength: sanitized.length,
      note: 'non_prefix_rewrite_applied',
      level: BridgeTraceLevel.info,
    );
    return AccumulatorDelta(
      delta: sanitized,
      fullText: sanitized,
      isRewrite: true,
    );
  }

  /// Applies a delta payload (e.g. from SSE chunk or DOM delta).
  AccumulatorDelta? applyDelta(String incomingDelta, {required String source}) {
    if (incomingDelta.isEmpty) return null;

    _currentText += incomingDelta;
    return AccumulatorDelta(
      delta: incomingDelta,
      fullText: _currentText,
      isRewrite: false,
    );
  }
}
