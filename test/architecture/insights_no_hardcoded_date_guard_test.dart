import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('هیچ تاریخ هاردکدی در لایهٔ تحلیل نیست', () {
    for (final path in ['lib/core/analytics', 'lib/features/today/presentation']) {
      final dir = Directory(path);
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        expect(
          file.readAsStringSync(),
          isNot(contains('fromMillisecondsSinceEpoch(17')),
          reason: '${file.path} ساعت هاردکد دارد',
        );
      }
    }
  });
}
