import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/notes/logic/note_text_normalizer.dart';

void main() {
  test('note_text_normalizer_test (S-02)', () {
    // ZWNJ removal equality test
    final withZwnj = NoteTextNormalizer.forIndex('می‌روم');
    final withoutZwnj = NoteTextNormalizer.forIndex('میروم');
    expect(withZwnj, equals(withoutZwnj));

    // Digits test
    expect(NoteTextNormalizer.forIndex('تست ۱۲۳'), equals('تست 123'));

    // Arabic letter & diacritic test
    expect(NoteTextNormalizer.forIndex('كِتَابٌ'), equals('کتاب'));

    // Stemming test: کتاب‌هایشان -> کتاب
    expect(NoteTextNormalizer.forIndex('کتاب‌هایشان'), equals('کتاب'));
  });
}
