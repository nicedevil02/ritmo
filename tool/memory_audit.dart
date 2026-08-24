import 'dart:io';

void main() async {
  final out = StringBuffer();
  final libDir = Directory('c:/Users/bahman/Desktop/Besme-Allah/Ritmo3/ritmo/lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  out.writeln('Total Dart files: ${dartFiles.length}');

  // 1. Image Audit
  out.writeln('\n========================================');
  out.writeln('=== 1. IMAGE USAGE AUDIT ===');
  out.writeln('========================================');
  int imageTotal = 0;
  int imageWithoutCache = 0;

  for (final file in dartFiles) {
    final relativePath = file.path.replaceAll(r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\', '').replaceAll('\\', '/');
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('Image.asset') ||
          line.contains('Image.network') ||
          line.contains('Image.file') ||
          line.contains('Image.memory') ||
          line.contains('DecorationImage') ||
          line.contains('AssetImage(') ||
          line.contains('FileImage(') ||
          line.contains('NetworkImage(') ||
          line.contains('MemoryImage(')) {
        imageTotal++;
        int start = (i - 2).clamp(0, lines.length - 1);
        int end = (i + 15).clamp(0, lines.length - 1);
        String chunk = lines.sublist(start, end + 1).join('\n');

        bool hasCache = chunk.contains('cacheWidth') ||
            chunk.contains('cacheHeight') ||
            chunk.contains('ResizeImage');

        if (!hasCache) {
          imageWithoutCache++;
          out.writeln('$relativePath:${i + 1} -> ${line.trim()}');
        }
      }
    }
  }
  out.writeln('\nTotal Image calls found: $imageTotal');
  out.writeln('Images missing cacheWidth/cacheHeight/ResizeImage: $imageWithoutCache');

  // 2. Controller & Resource Dispose Audit
  out.writeln('\n========================================');
  out.writeln('=== 2. CONTROLLER / RESOURCE DISPOSE AUDIT ===');
  out.writeln('========================================');
  final resourceTypes = [
    'AnimationController',
    'TextEditingController',
    'ScrollController',
    'PageController',
    'TabController',
    'FocusNode',
    'Timer',
    'StreamSubscription',
    'AudioPlayer',
  ];

  int totalControllers = 0;
  int missingDisposes = 0;

  for (final file in dartFiles) {
    final relativePath = file.path.replaceAll(r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\', '').replaceAll('\\', '/');
    final content = file.readAsStringSync();

    for (final res in resourceTypes) {
      final regex = RegExp(r'(?:final\s+|late\s+)?(?:' + res + r')(?:\??)\s+([_a-zA-Z0-9]+)\s*(?:=|;)');
      final matches = regex.allMatches(content);

      for (final match in matches) {
        totalControllers++;
        final varName = match.group(1);
        if (varName == null || (varName == 'controller' && match.group(0)!.contains('final $res controller'))) {
          continue;
        }

        final hasDispose = content.contains('void dispose()') || content.contains('dispose()');
        final hasVarDispose = content.contains('$varName.dispose()') || 
                              content.contains('$varName?.dispose()') ||
                              content.contains('$varName.cancel()') || 
                              content.contains('$varName?.cancel()');

        if (!hasDispose || !hasVarDispose) {
          missingDisposes++;
          out.writeln('$relativePath: field "$varName" ($res) -> disposed: $hasVarDispose (class has dispose: $hasDispose)');
        }
      }
    }
  }

  out.writeln('\nTotal controllers/subscriptions declarations: $totalControllers');
  out.writeln('Potentially undisposed fields: $missingDisposes');

  // 3. Global Database & Image Cache Configuration
  out.writeln('\n========================================');
  out.writeln('=== 3. DATABASE SERVICES & REPOSITORIES ===');
  out.writeln('========================================');
  for (final file in dartFiles) {
    final relativePath = file.path.replaceAll(r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\', '').replaceAll('\\', '/');
    final content = file.readAsStringSync();
    if (content.contains('openDatabase') || content.contains('PRAGMA') || content.contains('sqflite')) {
      out.writeln('$relativePath');
    }
  }

  // 4. PaintingBinding ImageCache Check
  out.writeln('\n========================================');
  out.writeln('=== 4. IMAGE CACHE & REPAINT BOUNDARIES ===');
  out.writeln('========================================');
  for (final file in dartFiles) {
    final relativePath = file.path.replaceAll(r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\', '').replaceAll('\\', '/');
    final content = file.readAsStringSync();
    if (content.contains('PaintingBinding.instance.imageCache') || content.contains('imageCache.')) {
      out.writeln('ImageCache configured in: $relativePath');
    }
  }

  File('c:/Users/bahman/Desktop/Besme-Allah/Ritmo3/ritmo/tool/audit_results.txt').writeAsStringSync(out.toString());
  print('Audit finished and saved to tool/audit_results.txt');
}
