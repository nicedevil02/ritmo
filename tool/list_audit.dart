import 'dart:io';

void main() {
  final libDir = Directory('c:/Users/bahman/Desktop/Besme-Allah/Ritmo3/ritmo/lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  print('=== VIEWPORT & LIST AUDIT ===\n');

  for (final file in dartFiles) {
    final relativePath = file.path.replaceAll(r'c:\Users\bahman\Desktop\Besme-Allah\Ritmo3\ritmo\', '').replaceAll('\\', '/');
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('ListView(') && !line.contains('ListView.builder') && !line.contains('ListView.separated') && !line.contains('ListView.custom')) {
        print('[EAGER LISTVIEW] $relativePath:${i + 1} -> ${line.trim()}');
      }
      if (line.contains('GridView(') || line.contains('GridView.count(')) {
        print('[EAGER GRIDVIEW] $relativePath:${i + 1} -> ${line.trim()}');
      }
    }
  }
}
