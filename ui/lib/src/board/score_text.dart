import '../../l10n/app_localizations.dart';
import 'scoring.dart';

/// A score as players read it: a single as the bare number, as a scorer writes it, and doubles, triples and the bulls
/// as usual. [Score.label] stays the language-free id that statistics, checkout routes and the engine share.
extension ScoreText on Score {
  String text(AppLocalizations l10n) => switch (ring) {
    Ring.miss => l10n.miss,
    Ring.innerSingle || Ring.outerSingle => '$sector',
    _ => label,
  };
}
