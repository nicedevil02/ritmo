import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/platform/native_channel_contract.dart';

enum TapResult { openApp, popup }

TapResult resolveTapAction({
  required String behavior,
  required bool isEssential,
  required String realmMode,
}) {
  final wantsPopup = switch (behavior) {
    NotifTapBehavior.popup => true,
    NotifTapBehavior.popupForEssential => isEssential,
    _ => false,
  } && realmMode != 'SILENT';

  return wantsPopup ? TapResult.popup : TapResult.openApp;
}

void main() {
  group('Notification Tap Behavior Decision Matrix (12 Cases)', () {
    // 1. OPEN_APP mode
    test('OPEN_APP with essential=true, mode=NORMAL -> OPEN_APP', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.openApp,
          isEssential: true,
          realmMode: 'NORMAL',
        ),
        equals(TapResult.openApp),
      );
    });

    test('OPEN_APP with essential=false, mode=NORMAL -> OPEN_APP', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.openApp,
          isEssential: false,
          realmMode: 'NORMAL',
        ),
        equals(TapResult.openApp),
      );
    });

    test('OPEN_APP with essential=true, mode=SILENT -> OPEN_APP', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.openApp,
          isEssential: true,
          realmMode: 'SILENT',
        ),
        equals(TapResult.openApp),
      );
    });

    test('OPEN_APP with essential=false, mode=SILENT -> OPEN_APP', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.openApp,
          isEssential: false,
          realmMode: 'SILENT',
        ),
        equals(TapResult.openApp),
      );
    });

    // 2. POPUP mode
    test('POPUP with essential=true, mode=NORMAL -> POPUP', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.popup,
          isEssential: true,
          realmMode: 'NORMAL',
        ),
        equals(TapResult.popup),
      );
    });

    test('POPUP with essential=false, mode=NORMAL -> POPUP', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.popup,
          isEssential: false,
          realmMode: 'NORMAL',
        ),
        equals(TapResult.popup),
      );
    });

    test('POPUP with essential=true, mode=SILENT -> OPEN_APP (SILENT blocks popup)', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.popup,
          isEssential: true,
          realmMode: 'SILENT',
        ),
        equals(TapResult.openApp),
      );
    });

    test('POPUP with essential=false, mode=SILENT -> OPEN_APP (SILENT blocks popup)', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.popup,
          isEssential: false,
          realmMode: 'SILENT',
        ),
        equals(TapResult.openApp),
      );
    });

    // 3. POPUP_FOR_ESSENTIAL mode (Default)
    test('POPUP_FOR_ESSENTIAL with essential=true, mode=NORMAL -> POPUP', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.popupForEssential,
          isEssential: true,
          realmMode: 'NORMAL',
        ),
        equals(TapResult.popup),
      );
    });

    test('POPUP_FOR_ESSENTIAL with essential=false, mode=NORMAL -> OPEN_APP', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.popupForEssential,
          isEssential: false,
          realmMode: 'NORMAL',
        ),
        equals(TapResult.openApp),
      );
    });

    test('POPUP_FOR_ESSENTIAL with essential=true, mode=SILENT -> OPEN_APP (SILENT blocks popup)', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.popupForEssential,
          isEssential: true,
          realmMode: 'SILENT',
        ),
        equals(TapResult.openApp),
      );
    });

    test('POPUP_FOR_ESSENTIAL with essential=false, mode=SILENT -> OPEN_APP', () {
      expect(
        resolveTapAction(
          behavior: NotifTapBehavior.popupForEssential,
          isEssential: false,
          realmMode: 'SILENT',
        ),
        equals(TapResult.openApp),
      );
    });
  });
}
