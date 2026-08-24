import 'dart:io';

void main() {
  final libDir = Directory('c:/Users/bahman/Desktop/Besme-Allah/Ritmo3/ritmo/lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  print('=== LOTTIE ANIMATIONS AUDIT ===\n');

  for (final file in dartFiles) {
    final relativePath = file.path.replaceAll(r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\', '').replaceAll('\\', '/');
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('Lottie.asset') || line.contains('Lottie.network') || line.contains('LottieBuilder')) {
        print('$relativePath:${i + 1} -> ${line.trim()}');
      }
    }
  }
}
