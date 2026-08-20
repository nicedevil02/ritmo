import 'package:ritmo/core/utils/persian_text.dart';

class ParsedTaskTitle {
  final String cleanTitle;
  final List<String> tags;

  const ParsedTaskTitle({
    required this.cleanTitle,
    required this.tags,
  });
}

ParsedTaskTitle parseTags(String rawTitle) {
  final trimmed = rawTitle.trim();
  if (trimmed.isEmpty) {
    return const ParsedTaskTitle(cleanTitle: '', tags: []);
  }

  // Matches hashtag followed by one or more valid Persian/Arabic/Latin letters, digits, or underscore
  final tagRegex = RegExp(r'#([^\s#]+)');
  final matches = tagRegex.allMatches(trimmed).toList();

  if (matches.isEmpty) {
    return ParsedTaskTitle(cleanTitle: trimmed, tags: const []);
  }

  final extractedTags = <String>[];
  var workingTitle = trimmed;

  for (final match in matches) {
    if (extractedTags.length >= 3) break;
    final tagWord = match.group(1);
    if (tagWord != null && tagWord.trim().isNotEmpty) {
      final normalizedTag = normalizeFa(tagWord.trim());
      if (normalizedTag.isNotEmpty) {
        extractedTags.add(normalizedTag);
        // Remove only this occurrence of the tag from the working title
        final fullMatch = match.group(0)!;
        final idx = workingTitle.indexOf(fullMatch);
        if (idx != -1) {
          workingTitle = (workingTitle.substring(0, idx) + workingTitle.substring(idx + fullMatch.length)).trim();
        }
      }
    }
  }

  // Clean up any double spaces leftover
  workingTitle = workingTitle.replaceAll(RegExp(r'\s+'), ' ').trim();

  // If clean title becomes empty, return untouched original title with empty tags
  if (workingTitle.isEmpty) {
    return ParsedTaskTitle(cleanTitle: trimmed, tags: const []);
  }

  return ParsedTaskTitle(cleanTitle: workingTitle, tags: extractedTags);
}
