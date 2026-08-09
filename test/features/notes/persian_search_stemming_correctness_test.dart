import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/notes/logic/note_text_normalizer.dart';

void main() {
  test('persian_search_stemming_correctness_test (V-03)', () {
    expect(NoteTextNormalizer.forIndex('کتاب‌ها'), equals('کتاب'));
    expect(NoteTextNormalizer.forIndex('بهترین'), equals('به'));
    expect(NoteTextNormalizer.forIndex('دوستانمان'), equals('دوست'));
    expect(NoteTextNormalizer.forIndex('دستورات'), equals('دستور'));
  });
}
