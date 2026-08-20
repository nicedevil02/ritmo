/// Lexicon and token utilities for anti-hallucination validation.
class ValidatorLexicon {
  ValidatorLexicon._();

  static const List<String> causalPhrases = [
    'باعث شد',
    'باعث می‌شود',
    'باعث میشود',
    'به خاطرِ',
    'به‌خاطر',
    'به خاطر',
    'در نتیجه',
    'موجب شد',
    'ناشی از',
    'دلیلش این است که',
    'دلیلش اینه که',
    'سبب شد',
  ];

  static const List<String> cyclePhrases = [
    'قاعدگی',
    'پریود',
    'چرخهٔ قاعدگی',
    'چرخه قاعدگی',
    'چرخهٔ ماهانه',
    'چرخه ماهانه',
    'سیکل قاعدگی',
    'خونریزی ماهانه',
    'menstrual',
    'menstruation',
  ];

  static const List<String> pregnancyPhrases = [
    'بارداری',
    'حاملگی',
    'pregnancy',
  ];

  static const Set<String> delimiters = {
    ' ',
    '\u200c', // Zero-width non-joiner
    '\u200f',
    '\u200e',
    ',',
    '،',
    '.',
    '!',
    '؟',
    '?',
    ':',
    ';',
    '؛',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    '\n',
    '\r',
    '\t',
    '"',
    '«',
    '»',
    '“',
    '”',
    '\'',
    '`',
  };

  /// Tokenizes text while preserving word tokens.
  static List<String> tokenize(String text) {
    if (text.isEmpty) return const [];
    final tokens = <String>[];
    final currentToken = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (delimiters.contains(char)) {
        if (currentToken.isNotEmpty) {
          tokens.add(currentToken.toString());
          currentToken.clear();
        }
      } else {
        currentToken.write(char);
      }
    }
    if (currentToken.isNotEmpty) {
      tokens.add(currentToken.toString());
    }
    return tokens;
  }

  /// Removes quoted sections (between «...», "...", “...”) to exempt quoted text.
  static String stripQuotedText(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    bool inQuote = false;
    String quoteChar = '';

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (!inQuote) {
        if (char == '«' || char == '"' || char == '“') {
          inQuote = true;
          quoteChar = char;
        } else {
          buffer.write(char);
        }
      } else {
        if ((quoteChar == '«' && char == '»') ||
            (quoteChar == '"' && char == '"') ||
            (quoteChar == '“' && char == '”')) {
          inQuote = false;
          quoteChar = '';
        }
      }
    }
    return buffer.toString();
  }

  /// Checks if [text] contains any phrase from [phrases] with word-boundary awareness.
  /// If [exemptQuotes] is true, phrases inside quotes are ignored.
  static bool containsPhrase(
    String text,
    List<String> phrases, {
    bool exemptQuotes = false,
  }) {
    if (text.isEmpty) return false;
    final targetText = exemptQuotes ? stripQuotedText(text) : text;
    final textTokens = tokenize(targetText);
    if (textTokens.isEmpty) return false;

    for (final phrase in phrases) {
      final phraseTokens = tokenize(phrase);
      if (phraseTokens.isEmpty) continue;

      // Single token match
      if (phraseTokens.length == 1) {
        final pt = phraseTokens.first.toLowerCase();
        for (final tt in textTokens) {
          if (tt.toLowerCase() == pt) return true;
        }
      } else {
        // Multi-token sequence match
        final pLen = phraseTokens.length;
        for (int i = 0; i <= textTokens.length - pLen; i++) {
          bool matched = true;
          for (int j = 0; j < pLen; j++) {
            if (textTokens[i + j].toLowerCase() != phraseTokens[j].toLowerCase()) {
              matched = false;
              break;
            }
          }
          if (matched) return true;
        }
      }
    }
    return false;
  }
}
