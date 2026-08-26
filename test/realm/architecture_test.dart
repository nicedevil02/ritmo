import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Time Realm Architecture Invariants (Section 9, B-04)', () {
    test('1. Realm mode logic lives ONLY in ZoneAndEssentialFilter and realm_mode.dart (B-04)', () {
      final pipelineFile = File('lib/core/domain/engines/rie/rie_pipeline.dart');
      final pipelineContent = pipelineFile.readAsStringSync();

      expect(
        pipelineContent.contains("== 'SILENT'"),
        isFalse,
        reason: 'منطق حالت قلمرو نباید در rie_pipeline.dart تکرار شود',
      );
      expect(
        pipelineContent.contains("== 'FOCUS'"),
        isFalse,
        reason: 'منطق حالت قلمرو نباید در rie_pipeline.dart تکرار شود',
      );
    });

    test('2. Realm mode raw comparisons do not exist in domain engines', () {
      final filtersFile = File('lib/core/domain/engines/rie/rie_filters.dart');
      final filtersContent = filtersFile.readAsStringSync();

      expect(
        filtersContent.contains("activeZoneMode == 'SILENT'"),
        isFalse,
        reason: 'فیلترها باید از RealmMode و متدهای رفتاری آن استفاده کنند نه مقایسه رشته‌ای',
      );
    });

    test('3. Sealed ActiveRealmState hierarchy is strictly enforced', () {
      final stateFile = File('lib/core/domain/realm/realm_state.dart');
      final stateContent = stateFile.readAsStringSync();

      expect(stateContent.contains('sealed class ActiveRealmState'), isTrue);
      expect(stateContent.contains('extension ActiveRealmStateX'), isTrue);
    });
  });
}
