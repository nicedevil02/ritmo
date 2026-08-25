import 'package:flutter/widgets.dart';
import 'package:ritmo/l10n/app_localizations.dart';

export 'components/components.dart';
export 'player/player.dart';
export 'screens/screens.dart';
export 'sheets/sheets.dart';

extension MvL10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
