import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/realm/realm_mode.dart';

void main() {
  group('RealmMode Parsing & Converters (B-02, B-03)', () {
    test('parses canonical raw strings correctly', () {
      expect(parseRealmMode('NORMAL'), RealmMode.normal);
      expect(parseRealmMode('FOCUS'), RealmMode.focus);
      expect(parseRealmMode('SILENT'), RealmMode.silent);
    });

    test('accepts MUTE as alias for silent (B-02)', () {
      expect(parseRealmMode('MUTE'), RealmMode.silent);
      expect(parseRealmMode('mute'), RealmMode.silent);
      expect(parseRealmMode('  Mute  '), RealmMode.silent);
    });

    test('handles null and empty input as normal', () {
      expect(parseRealmMode(null), RealmMode.normal);
      expect(parseRealmMode(''), RealmMode.normal);
      expect(parseRealmMode('   '), RealmMode.normal);
    });

    test('normalizes unknown values (e.g. WORK) to normal with safe fallback (B-03)', () {
      expect(parseRealmMode('WORK'), RealmMode.normal);
      expect(parseRealmMode('INVALID_MODE'), RealmMode.normal);
    });

    test('converts RealmMode to raw canonical uppercase string', () {
      expect(realmModeToRaw(RealmMode.normal), 'NORMAL');
      expect(realmModeToRaw(RealmMode.focus), 'FOCUS');
      expect(realmModeToRaw(RealmMode.silent), 'SILENT');
    });
  });

  group('RealmModeBehavior Extensions (B-02, B-10)', () {
    test('NORMAL mode does not suppress routines or notifications', () {
      const mode = RealmMode.normal;
      expect(mode.suppressesNonEssential, isFalse);
      expect(mode.suppressesNotifications, isFalse);
      expect(mode.allowsEssentialBypass, isTrue);
    });

    test('FOCUS mode suppresses non-essential routines but allows essential notifications', () {
      const mode = RealmMode.focus;
      expect(mode.suppressesNonEssential, isTrue);
      expect(mode.suppressesNotifications, isFalse);
      expect(mode.allowsEssentialBypass, isTrue);
    });

    test('SILENT mode suppresses non-essential routines and all standard notifications', () {
      const mode = RealmMode.silent;
      expect(mode.suppressesNonEssential, isTrue);
      expect(mode.suppressesNotifications, isTrue);
      expect(mode.allowsEssentialBypass, isFalse);
    });
  });
}
