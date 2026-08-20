import 'package:flutter/material.dart';

/// Parses rich markdown text (Headings, Bold, Italic, Code, Bullets, Lists, Quotes)
/// into a structured list of InlineSpans for high-fidelity chat rendering.
List<InlineSpan> parseMarkdownText(
  String text,
  TextStyle baseStyle, {
  Color? codeBgColor,
  Color? codeTextColor,
}) {
  if (text.isEmpty) return const <InlineSpan>[];

  final spans = <InlineSpan>[];
  final lines = text.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    final trimmedLine = rawLine.trim();

    if (trimmedLine.isEmpty) {
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
      continue;
    }

    // 1. Heading 1 (# ...)
    if (trimmedLine.startsWith('# ')) {
      final content = trimmedLine.substring(2).trim();
      final h1Style = baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 13.5) * 1.32,
        fontWeight: FontWeight.bold,
        height: 1.6,
      );
      spans.addAll(_parseInlineMarkdown(content, h1Style, codeBgColor, codeTextColor));
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: h1Style));
      continue;
    }

    // 2. Heading 2 (## ...)
    if (trimmedLine.startsWith('## ')) {
      final content = trimmedLine.substring(3).trim();
      final h2Style = baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 13.5) * 1.22,
        fontWeight: FontWeight.bold,
        height: 1.55,
      );
      spans.addAll(_parseInlineMarkdown(content, h2Style, codeBgColor, codeTextColor));
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: h2Style));
      continue;
    }

    // 3. Heading 3 (### ...)
    if (trimmedLine.startsWith('### ')) {
      final content = trimmedLine.substring(4).trim();
      final h3Style = baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 13.5) * 1.15,
        fontWeight: FontWeight.bold,
        height: 1.5,
      );
      spans.addAll(_parseInlineMarkdown(content, h3Style, codeBgColor, codeTextColor));
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: h3Style));
      continue;
    }

    // 4. Heading 4+ (#### ...)
    if (trimmedLine.startsWith('#### ')) {
      final content = trimmedLine.substring(5).trim();
      final h4Style = baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 13.5) * 1.08,
        fontWeight: FontWeight.bold,
        height: 1.45,
      );
      spans.addAll(_parseInlineMarkdown(content, h4Style, codeBgColor, codeTextColor));
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: h4Style));
      continue;
    }

    // 5. Blockquote (> ...)
    if (trimmedLine.startsWith('> ')) {
      final content = trimmedLine.substring(2).trim();
      final quoteStyle = baseStyle.copyWith(
        fontStyle: FontStyle.italic,
        color: baseStyle.color?.withValues(alpha: 0.85),
      );
      spans.add(TextSpan(text: '▌ ', style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
      spans.addAll(_parseInlineMarkdown(content, quoteStyle, codeBgColor, codeTextColor));
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: quoteStyle));
      continue;
    }

    // 6. Bullet lists (• ... or - ... or * ...)
    if (trimmedLine.startsWith('• ') ||
        trimmedLine.startsWith('- ') ||
        (trimmedLine.startsWith('* ') && !trimmedLine.endsWith('*'))) {
      final prefix = trimmedLine.startsWith('• ') ? '• ' : (trimmedLine.startsWith('- ') ? '• ' : '• ');
      final content = trimmedLine.substring(2).trim();
      spans.add(TextSpan(text: prefix, style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
      spans.addAll(_parseInlineMarkdown(content, baseStyle, codeBgColor, codeTextColor));
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: baseStyle));
      continue;
    }

    // 7. Numbered lists (1. ... 2. ...)
    final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmedLine);
    if (numMatch != null) {
      final numStr = numMatch.group(1)!;
      final content = numMatch.group(2)!;
      spans.add(TextSpan(text: '$numStr. ', style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
      spans.addAll(_parseInlineMarkdown(content, baseStyle, codeBgColor, codeTextColor));
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: baseStyle));
      continue;
    }

    // 8. Regular paragraph line
    spans.addAll(_parseInlineMarkdown(rawLine, baseStyle, codeBgColor, codeTextColor));
    if (i < lines.length - 1) {
      spans.add(TextSpan(text: '\n', style: baseStyle));
    }
  }

  return spans;
}

/// Parses inline markdown elements: **bold**, *italic*, `code`, ~~strike~~.
List<InlineSpan> _parseInlineMarkdown(
  String text,
  TextStyle style,
  Color? codeBgColor,
  Color? codeTextColor,
) {
  if (text.isEmpty) return const <InlineSpan>[];

  final spans = <InlineSpan>[];
  final inlineRegex = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*|\*[^*]+\*|~~[^~]+~~)');
  var lastIndex = 0;

  for (final match in inlineRegex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(TextSpan(
        text: text.substring(lastIndex, match.start),
        style: style,
      ));
    }

    final token = match.group(0)!;

    if (token.startsWith('`') && token.endsWith('`') && token.length >= 2) {
      final codeContent = token.substring(1, token.length - 1);
      spans.add(
        TextSpan(
          text: ' $codeContent ',
          style: style.copyWith(
            fontFamily: 'monospace',
            fontSize: (style.fontSize ?? 13.5) * 0.92,
            backgroundColor: codeBgColor ?? Colors.black.withValues(alpha: 0.08),
            color: codeTextColor ?? style.color,
          ),
        ),
      );
    } else if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
      final boldContent = token.substring(2, token.length - 2);
      spans.add(
        TextSpan(
          text: boldContent,
          style: style.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (token.startsWith('*') && token.endsWith('*') && token.length >= 2) {
      final italicContent = token.substring(1, token.length - 1);
      spans.add(
        TextSpan(
          text: italicContent,
          style: style.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else if (token.startsWith('~~') && token.endsWith('~~') && token.length >= 4) {
      final strikeContent = token.substring(2, token.length - 2);
      spans.add(
        TextSpan(
          text: strikeContent,
          style: style.copyWith(
            decoration: TextDecoration.lineThrough,
          ),
        ),
      );
    } else {
      spans.add(TextSpan(text: token, style: style));
    }

    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastIndex),
      style: style,
    ));
  }

  return spans;
}
