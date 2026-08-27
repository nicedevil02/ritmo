import 'package:flutter_test/flutter_test.dart';

bool evaluateFullScreenIntent({
  required bool enabled,
  required String scope,
  required bool isEssential,
  required bool isOptedIn,
  required bool canUseFullScreenPermission,
}) {
  if (!enabled) return false;
  if (!canUseFullScreenPermission) return false;

  return switch (scope) {
    'all' => true,
    'custom' => isOptedIn,
    'none' => false,
    'essential' => isEssential || isOptedIn,
    _ => isEssential || isOptedIn,
  };
}

void main() {
  group('Notification Fullscreen Scope Logic Tests (N-01 Regression)', () {
    test('when master fullscreen is disabled, always returns false', () {
      expect(
        evaluateFullScreenIntent(
          enabled: false,
          scope: 'all',
          isEssential: true,
          isOptedIn: true,
          canUseFullScreenPermission: true,
        ),
        isFalse,
      );
    });

    test('when OS permission is revoked on Android 14+, always returns false', () {
      expect(
        evaluateFullScreenIntent(
          enabled: true,
          scope: 'all',
          isEssential: true,
          isOptedIn: true,
          canUseFullScreenPermission: false,
        ),
        isFalse,
      );
    });

    test('scope="all" enables fullscreen for non-essential routines without opt-in', () {
      expect(
        evaluateFullScreenIntent(
          enabled: true,
          scope: 'all',
          isEssential: false,
          isOptedIn: false,
          canUseFullScreenPermission: true,
        ),
        isTrue,
      );
    });

    test('scope="custom" only enables fullscreen for opted-in routine IDs', () {
      // Opted in
      expect(
        evaluateFullScreenIntent(
          enabled: true,
          scope: 'custom',
          isEssential: false,
          isOptedIn: true,
          canUseFullScreenPermission: true,
        ),
        isTrue,
      );

      // Not opted in
      expect(
        evaluateFullScreenIntent(
          enabled: true,
          scope: 'custom',
          isEssential: false,
          isOptedIn: false,
          canUseFullScreenPermission: true,
        ),
        isFalse,
      );
    });

    test('scope="essential" (default) allows essential or opted-in routines', () {
      // Essential
      expect(
        evaluateFullScreenIntent(
          enabled: true,
          scope: 'essential',
          isEssential: true,
          isOptedIn: false,
          canUseFullScreenPermission: true,
        ),
        isTrue,
      );

      // Non-essential without opt-in -> false
      expect(
        evaluateFullScreenIntent(
          enabled: true,
          scope: 'essential',
          isEssential: false,
          isOptedIn: false,
          canUseFullScreenPermission: true,
        ),
        isFalse,
      );

      // Non-essential with opt-in -> true
      expect(
        evaluateFullScreenIntent(
          enabled: true,
          scope: 'essential',
          isEssential: false,
          isOptedIn: true,
          canUseFullScreenPermission: true,
        ),
        isTrue,
      );
    });

    test('scope="none" disables fullscreen even for essential routines', () {
      expect(
        evaluateFullScreenIntent(
          enabled: true,
          scope: 'none',
          isEssential: true,
          isOptedIn: true,
          canUseFullScreenPermission: true,
        ),
        isFalse,
      );
    });
  });
}
