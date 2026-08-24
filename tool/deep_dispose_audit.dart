import 'dart:io';

void main() {
  final libDir = Directory('c:/Users/bahman/Desktop/Besme-Allah/Ritmo3/ritmo/lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

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

  print('=== DEEP RESOURCE LEAK AUDIT ===\n');

  for (final file in dartFiles) {
    final relativePath = file.path.replaceAll(r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\', '').replaceAll('\\', '/');
    final content = file.readAsStringSync();

    // Check StatefulWidgets
    if (content.contains('extends State<')) {
      final hasDispose = content.contains('void dispose()');
      for (final res in resourceTypes) {
        final regex = RegExp(r'(?:final\s+|late\s+)?(?:' + res + r')(?:\??)\s+([_a-zA-Z0-9]+)\s*(?:=|;)');
        final matches = regex.allMatches(content);
        for (final match in matches) {
          final varName = match.group(1)!;
          if (varName == 'controller' && match.group(0)!.contains('final $res controller')) continue;

          bool disposed = false;
          if (hasDispose) {
            final disposeIndex = content.indexOf('void dispose()');
            final disposeEnd = content.indexOf('super.dispose();', disposeIndex);
            if (disposeEnd != -1) {
              final disposeBlock = content.substring(disposeIndex, disposeEnd + 20);
              disposed = disposeBlock.contains(varName);
            }
          }

          if (!disposed) {
            print('[LEAK CANDIDATE IN STATE] $relativePath');
            print('   Resource: $res $varName');
            print('   Has dispose(): $hasDispose, Disposed in block: $disposed\n');
          }
        }
      }
    }

    // Check ChangeNotifiers & Services
    if (content.contains('extends ChangeNotifier') || content.contains('with ChangeNotifier')) {
      for (final res in ['Timer', 'StreamSubscription', 'AnimationController']) {
        final regex = RegExp(r'(?:final\s+|late\s+)?(?:' + res + r')(?:\??)\s+([_a-zA-Z0-9]+)\s*(?:=|;)');
        final matches = regex.allMatches(content);
        for (final match in matches) {
          final varName = match.group(1)!;
          final hasDispose = content.contains('void dispose()');
          bool disposed = false;
          if (hasDispose) {
            final disposeIndex = content.indexOf('void dispose()');
            final disposeEnd = content.indexOf('super.dispose();', disposeIndex);
            final end = disposeEnd != -1 ? disposeEnd + 20 : content.length;
            final disposeBlock = content.substring(disposeIndex, end.clamp(0, content.length));
            disposed = disposeBlock.contains(varName);
          }
          if (!disposed) {
            print('[LEAK CANDIDATE IN NOTIFIER] $relativePath');
            print('   Resource: $res $varName');
            print('   Has dispose(): $hasDispose, Disposed: $disposed\n');
          }
        }
      }
    }
  }
}
