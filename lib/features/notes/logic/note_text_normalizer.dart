/// Custom Persian text normalizer for notebook search (S-01).
///
/// NOTE: Differently from core `normalizeFa()`, step 4 explicitly REMOVES
/// Zero-Width Non-Joiners (U+200C) instead of converting them to spaces.
/// Reason: "می‌روم" and "میروم" must normalize to identical tokens.
class NoteTextNormalizer {
  NoteTextNormalizer._();

  static const _persianDigits = [
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹',
  ];
  static const _arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  static const _stemSuffixes = [
    'هایشان',
    'هایتان',
    'هایمان',
    'انمان',
    'انتان',
    'انشان',
    'هایی',
    'هایم',
    'هایت',
    'هایش',
    'های',
    'ها',
    'ترین',
    'تر',
    'شان',
    'تان',
    'مان',
    'ان',
    'ام',
    'ات',
    'اش',
    'را',
  ];

  static String forIndex(String input) {
    if (input.isEmpty) return '';

    var text = input;

    // 1. Digits -> Latin
    for (var i = 0; i < 10; i++) {
      text = text.replaceAll(_persianDigits[i], '$i');
      text = text.replaceAll(_arabicDigits[i], '$i');
    }

    // 2. Arabic character normalization
    text = text
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ی');

    // 3. Remove diacritics (U+064B..U+0652, U+0670) and tatweel (U+0640)
    text = text.replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '');

    // 4. REMOVE (not space) ZWNJ (U+200C, U+200D, U+200E, U+200F, U+FEFF)
    text = text.replaceAll(RegExp(r'[\u200C\u200D\u200E\u200F\uFEFF]'), '');

    // 5. Punctuation -> space
    text = text.replaceAll(RegExp(r'''[،؛؟«»"'()\[\]{}<>\/\\\|—–_*\#]'''), ' ');

    // 6. Compress spaces & toLowerCase
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

    // 7. Stemming for tokens >= 5 chars
    final tokens = text.split(' ');
    final stemmedTokens = tokens.map((token) {
      if (token.length < 5) return token;
      var current = token;
      for (final suffix in _stemSuffixes) {
        if (current.length >= 5 && current.endsWith(suffix)) {
          final stripped = current.substring(0, current.length - suffix.length);
          if (stripped.length >= 2) {
            current = stripped;
            break;
          }
        }
      }
      return current;
    });

    return stemmedTokens.join(' ');
  }

  static String forQuery(String input) => forIndex(input);
}
