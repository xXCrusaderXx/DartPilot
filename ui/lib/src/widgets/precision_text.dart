import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../stats/precision.dart';

/// The offset of a mean or a dart from the target in words: "6 mm left, 4 mm low"
String offsetText(AppLocalizations l10n, double dxMm, double dyMm) {
  String mm(double v) => NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 0).format(v.abs());
  final parts = [
    if (mm(dxMm) != '0') dxMm > 0 ? l10n.offsetRight(mm(dxMm)) : l10n.offsetLeft(mm(dxMm)),
    if (mm(dyMm) != '0') dyMm > 0 ? l10n.offsetHigh(mm(dyMm)) : l10n.offsetLow(mm(dyMm)),
  ];
  return parts.isEmpty ? l10n.precisionOnTarget : parts.join(', ');
}

/// A length with one decimal in the locale's format, without the unit
String mmNumber(AppLocalizations l10n, double valueMm) =>
    NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 1).format(valueMm);

/// A length with one decimal and its unit: "12,5 mm"
String mmText(AppLocalizations l10n, double valueMm) => '${mmNumber(l10n, valueMm)} mm';

/// One dart of a training: what it scored, what it was aimed at, and how far it missed and to where
class MissTile extends StatelessWidget {
  const MissTile({super.key, required this.number, required this.dart, required this.target, this.showTarget = false});

  final int number;
  final DartThrow dart;
  final PrecisionTarget? target;

  /// Names the target, for trainings where it changes from dart to dart
  final bool showTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final aim = target;
    String? miss;
    if (aim != null && hasMeasuredPoint(dart)) {
      final centre = aim.centre();
      final dx = dart.point.xMm - centre.xMm, dy = dart.point.yMm - centre.yMm;
      miss = l10n.missFromTarget(mmNumber(l10n, math.sqrt(dx * dx + dy * dy)), offsetText(l10n, dx, dy));
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Text('$number', style: theme.textTheme.titleMedium),
      title: Text([dart.score.label, if (showTarget && aim != null) l10n.aimedAt(aim.label)].join('  ')),
      subtitle: miss == null ? null : Text(miss),
    );
  }
}
