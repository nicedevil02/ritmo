import 'dart:convert';
import 'dart:io';

class MetricRule {
  final String key;
  final String name;
  final RegExp pattern;
  final bool isFeaturesOnly;
  final String scope;

  const MetricRule({
    required this.key,
    required this.name,
    required this.pattern,
    required this.isFeaturesOnly,
    required this.scope,
  });
}

final rules = <MetricRule>[
  MetricRule(
    key: 'hardcodedColors',
    name: 'Hardcoded Colors',
    pattern: RegExp(r'Color\(0x[0-9a-fA-F]+'),
    isFeaturesOnly: true,
    scope: 'lib/features/',
  ),
  MetricRule(
    key: 'materialColors',
    name: 'Material Colors (non-transparent)',
    pattern: RegExp(r'Colors\.(?!transparent\b)[a-zA-Z]+'),
    isFeaturesOnly: true,
    scope: 'lib/features/',
  ),
  MetricRule(
    key: 'oldOpacity',
    name: 'Old Opacity withOpacity()',
    pattern: RegExp(r'withOpacity\('),
    isFeaturesOnly: false,
    scope: 'lib/',
  ),
  MetricRule(
    key: 'duplicateFont',
    name: 'Duplicate Local Font Family',
    pattern: RegExp(r'fontFamily\b'),
    isFeaturesOnly: true,
    scope: 'lib/features/',
  ),
  MetricRule(
    key: 'scatteredBlur',
    name: 'Scattered BackdropFilter',
    pattern: RegExp(r'\bBackdropFilter\b'),
    isFeaturesOnly: true,
    scope: 'lib/features/',
  ),
  MetricRule(
    key: 'manualShadow',
    name: 'Manual BoxShadow',
    pattern: RegExp(r'\bBoxShadow\('),
    isFeaturesOnly: true,
    scope: 'lib/features/',
  ),
  MetricRule(
    key: 'rawScaffold',
    name: 'Raw Scaffold',
    pattern: RegExp(r'(?<!RitmoPage)Scaffold\('),
    isFeaturesOnly: true,
    scope: 'lib/features/',
  ),
  MetricRule(
    key: 'circularProgress',
    name: 'Page-level CircularProgressIndicator',
    pattern: RegExp(r'\bCircularProgressIndicator\b'),
    isFeaturesOnly: true,
    scope: 'lib/features/',
  ),
  MetricRule(
    key: 'localDirectionality',
    name: 'Local Directionality Override',
    pattern: RegExp(r'\bDirectionality\('),
    isFeaturesOnly: true,
    scope: 'lib/features/',
  ),
  MetricRule(
    key: 'hardcodedDuration',
    name: 'Hardcoded Millisecond Duration',
    pattern: RegExp(r'Duration\(milliseconds:\s*\d+'),
    isFeaturesOnly: true,
    scope: 'lib/features/',
  ),
];

String stripComments(String code) {
  final blockComment = RegExp(r'/\*[\s\S]*?\*/');
  final lineComment = RegExp(r'//.*');
  return code.replaceAll(blockComment, '').replaceAll(lineComment, '');
}

void main(List<String> args) {
  final isCheckMode = args.contains('--check');
  final libDir = Directory('lib');

  if (!libDir.existsSync()) {
    stderr.writeln('Error: lib directory not found.');
    exit(1);
  }

  final baselineFile = File('tool/theme_baseline.json');
  Map<String, dynamic> baseline = {};
  if (baselineFile.existsSync()) {
    try {
      baseline = jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('Warning: Failed to parse tool/theme_baseline.json: $e');
    }
  }

  final files = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  final counts = <String, int>{};
  final fileCounts = <String, Map<String, int>>{};

  for (final rule in rules) {
    counts[rule.key] = 0;
    fileCounts[rule.key] = {};
  }

  for (final file in files) {
    final normalizedPath = file.path.replaceAll(r'\', '/');
    final isFeatures = normalizedPath.contains('lib/features/');

    final rawContent = file.readAsStringSync();
    final cleanContent = stripComments(rawContent);

    for (final rule in rules) {
      if (rule.isFeaturesOnly && !isFeatures) continue;

      final matches = rule.pattern.allMatches(cleanContent).length;
      if (matches > 0) {
        counts[rule.key] = (counts[rule.key] ?? 0) + matches;
        fileCounts[rule.key]![normalizedPath] = matches;
      }
    }
  }

  // Check against baseline
  bool hasViolation = false;
  bool canLowerBaseline = false;

  print('=== Ritmo Aurora Design System Audit ===');
  print('Checked ${files.length} Dart files.\n');

  final tableRows = <String>[];
  tableRows.add('| Metric | Key | Scope | Current Count | Baseline | Status |');
  tableRows.add('|---|---|---|---|---|---|');

  for (final rule in rules) {
    final current = counts[rule.key] ?? 0;
    final base = (baseline[rule.key] as num?)?.toInt() ?? current;
    String status = 'OK';

    if (current > base) {
      status = 'REGRESSION (+$current > $base)';
      hasViolation = true;
    } else if (current < base) {
      status = 'IMPROVED ($current < $base)';
      canLowerBaseline = true;
    }

    tableRows.add('| ${rule.name} | `${rule.key}` | `${rule.scope}` | $current | $base | $status |');
    print('${rule.name.padRight(40)} : $current (Baseline: $base) -> $status');

    // Show top 5 worst offenders
    final sortedFiles = (fileCounts[rule.key]!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
      .take(5)
      .toList();

    if (sortedFiles.isNotEmpty && (!isCheckMode || current > base)) {
      print('   Top offenders:');
      for (final entry in sortedFiles) {
        print('     - ${entry.key}: ${entry.value}');
      }
    }
  }

  if (canLowerBaseline) {
    print('\n[TIP] One or more metrics improved! Lower baseline in tool/theme_baseline.json');
  }

  if (!isCheckMode) {
    // Generate docs/theme_migration.md report
    final report = StringBuffer();
    report.writeln('# Ritmo Aurora Theme Migration Audit Report');
    report.writeln();
    report.writeln('Generated At: ${DateTime.now().toIso8601String()}');
    report.writeln();
    report.writeln('## Audit Metrics Summary');
    report.writeln();
    for (final row in tableRows) {
      report.writeln(row);
    }
    report.writeln();
    report.writeln('## Top Offenders by Metric');
    report.writeln();

    for (final rule in rules) {
      final sortedFiles = (fileCounts[rule.key]!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

      report.writeln('### ${rule.name} (`${rule.key}`)');
      report.writeln('Total: ${counts[rule.key]} occurrences');
      report.writeln();
      if (sortedFiles.isEmpty) {
        report.writeln('*No violations found.*');
      } else {
        report.writeln('| File | Occurrences |');
        report.writeln('|---|---|');
        for (final entry in sortedFiles) {
          report.writeln('| `${entry.key}` | ${entry.value} |');
        }
      }
      report.writeln();
    }

    final docsDir = Directory('docs');
    if (!docsDir.existsSync()) {
      docsDir.createSync(recursive: true);
    }
    File('docs/theme_migration.md').writeAsStringSync(report.toString());
    print('\nReport saved to docs/theme_migration.md');
  }

  if (isCheckMode && hasViolation) {
    stderr.writeln('\n[FAILED] Design System Guard: Regression detected against baseline!');
    exit(1);
  }
}
