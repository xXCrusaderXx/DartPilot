import '../../l10n/app_localizations.dart';
import 'scoring.dart';

/// A score as players read it: [Score.label] stays the language-free id that statistics and the engine share.
extension ScoreText on Score {
  String text(AppLocalizations l10n) => ring == Ring.miss ? l10n.miss : label;
}
