import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../board/dartboard.dart';
import '../display.dart';
import '../theme.dart';

/// The preset the appearance starts from, and Reset back to it
class AppearancePresetTiles extends StatelessWidget {
  const AppearancePresetTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = DisplayScope.of(context);
    String name(AppearancePreset p) => switch (p) {
      AppearancePreset.standard => l10n.presetStandard,
      AppearancePreset.light => l10n.presetLight,
      AppearancePreset.highContrast => l10n.presetHighContrast,
      AppearancePreset.scoreboard => l10n.presetScoreboard,
    };
    return Column(
      children: [
        ListTile(
          title: Text(l10n.appearancePreset),
          subtitle: Text(l10n.appearancePresetHint),
          trailing: TextButton(
            key: const ValueKey('appearance-reset'),
            onPressed: display.reset,
            child: Text(l10n.appearanceReset),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in AppearancePreset.values)
                  ChoiceChip(
                    key: ValueKey('preset-${p.name}'),
                    label: Text(name(p)),
                    selected: display.preset == p,
                    onSelected: (_) => display.applyPreset(p),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The colours the accent can be made from; the first is the flight's blue, the default
const accentSwatches = [
  AppColors.accent,
  Color(0xFF34D399),
  Color(0xFF2DD4BF),
  Color(0xFFA78BFA),
  Color(0xFFF472B6),
  Color(0xFFFB923C),
  Color(0xFFF87171),
  Color(0xFFFACC15),
];

/// Contrast, accent colour, text size and font
class AppearanceColourTiles extends StatelessWidget {
  const AppearanceColourTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = DisplayScope.of(context);
    final palette = AppPalette.of(context);
    final names = [
      l10n.accentSky,
      l10n.accentGreen,
      l10n.accentTeal,
      l10n.accentViolet,
      l10n.accentPink,
      l10n.accentOrange,
      l10n.accentRed,
      l10n.accentGold,
    ];
    final chosen = display.accent;
    final custom = chosen != null && !accentSwatches.contains(chosen);
    final adjusted =
        chosen != null &&
        (HSLColor.fromColor(chosen).lightness - HSLColor.fromColor(palette.accent).lightness).abs() > 0.1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('high-contrast'),
          title: Text(l10n.highContrast),
          subtitle: Text(l10n.highContrastHint),
          value: display.highContrast,
          onChanged: (on) => display.set(highContrast: on),
        ),
        ListTile(
          title: Text(l10n.accentColour),
          subtitle: adjusted ? Text(l10n.accentAdjusted, key: const ValueKey('accent-adjusted')) : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < accentSwatches.length; ++i)
                _Swatch(
                  key: ValueKey('accent-$i'),
                  colour: accentSwatches[i],
                  label: names[i],
                  selected: i == 0 ? chosen == null || chosen == AppColors.accent : chosen == accentSwatches[i],
                  onTap: () => display.setAccent(i == 0 ? null : accentSwatches[i]),
                ),
              ActionChip(
                key: const ValueKey('accent-custom'),
                avatar: custom ? CircleAvatar(backgroundColor: chosen) : const Icon(Icons.palette_outlined),
                label: Text(l10n.accentCustom),
                side: custom ? BorderSide(color: palette.text, width: 2) : null,
                onPressed: () async {
                  final picked = await showDialog<Color>(
                    context: context,
                    builder: (_) => _HueDialog(start: chosen ?? AppColors.accent),
                  );
                  if (picked != null) await display.setAccent(picked);
                },
              ),
            ],
          ),
        ),
        ListTile(title: Text(l10n.textSize), subtitle: Text(l10n.textSizeHint)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<TextSize>(
            key: const ValueKey('text-size'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: TextSize.small, label: Text(l10n.textSmall)),
              ButtonSegment(value: TextSize.normal, label: Text(l10n.textNormal)),
              ButtonSegment(value: TextSize.large, label: Text(l10n.textLarge)),
              ButtonSegment(value: TextSize.larger, label: Text(l10n.textLarger)),
            ],
            selected: {display.textSize},
            onSelectionChanged: (s) => display.set(textSize: s.first),
          ),
        ),
        ListTile(title: Text(l10n.textFont), subtitle: Text(l10n.textFontHint)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<TextFont>(
            key: const ValueKey('text-font'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: TextFont.bundled,
                label: Text(l10n.textFontBundled, style: const TextStyle(fontFamily: textFontFamily)),
              ),
              ButtonSegment(value: TextFont.system, label: Text(l10n.textFontSystem)),
            ],
            selected: {display.font},
            onSelectionChanged: (s) => display.set(font: s.first),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.colour, required this.label, required this.selected, required this.onTap});

  final Color colour;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colour,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? palette.text : palette.border, width: selected ? 3 : 1),
            ),
            child: selected
                ? Icon(Icons.check, size: 20, color: colour.computeLuminance() > 0.3 ? Colors.black : Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

/// A hue for the player's own accent; saturation and lightness come from the flight's blue, and the palette then fits
/// the lightness so that text stays readable.
class _HueDialog extends StatefulWidget {
  const _HueDialog({required this.start});

  final Color start;

  @override
  State<_HueDialog> createState() => _HueDialogState();
}

class _HueDialogState extends State<_HueDialog> {
  late double _hue = HSLColor.fromColor(widget.start).hue;

  Color get _colour => HSLColor.fromColor(AppColors.accent).withHue(_hue).toColor();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.accentCustom),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(color: _colour, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 16),
          Slider(
            key: const ValueKey('accent-hue'),
            label: l10n.accentHue,
            min: 0,
            max: 359,
            value: _hue,
            onChanged: (v) => setState(() => _hue = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          key: const ValueKey('accent-apply'),
          onPressed: () => Navigator.of(context).pop(_colour),
          child: Text(l10n.accentApply),
        ),
      ],
    );
  }
}

/// The game screen's layout and how it celebrates; a preset leaves them alone
class GameScreenTiles extends StatelessWidget {
  const GameScreenTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = DisplayScope.of(context);
    Widget segmented<T>(String key, List<(T, String)> values, T selected, ValueChanged<T> onChanged) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SegmentedButton<T>(
        key: ValueKey(key),
        showSelectedIcon: false,
        segments: [for (final (value, label) in values) ButtonSegment(value: value, label: Text(label))],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
    final details = [
      (PanelDetail.visitDarts, l10n.detailVisitDarts),
      (PanelDetail.checkout, l10n.detailCheckout),
      (PanelDetail.average, l10n.detailAverage),
      (PanelDetail.dartsThrown, l10n.detailDartsThrown),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(title: Text(l10n.boardSide), subtitle: Text(l10n.boardSideHint)),
        segmented(
          'board-side',
          [(BoardSide.left, l10n.boardLeft), (BoardSide.right, l10n.boardRight)],
          display.boardSide,
          (v) => display.set(boardSide: v),
        ),
        ListTile(title: Text(l10n.boardSize), subtitle: Text(l10n.boardSizeHint)),
        segmented(
          'board-size',
          [
            (BoardSize.small, l10n.boardSmall),
            (BoardSize.medium, l10n.boardMedium),
            (BoardSize.large, l10n.boardLarge),
          ],
          display.boardSize,
          (v) => display.set(boardSize: v),
        ),
        ListTile(title: Text(l10n.panelDetails)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (detail, label) in details)
                  FilterChip(
                    key: ValueKey('detail-${detail.name}'),
                    label: Text(label),
                    selected: display.shows(detail),
                    onSelected: (on) => display.showDetail(detail, on),
                  ),
              ],
            ),
          ),
        ),
        const BoardColourTiles(),
        ListTile(title: Text(l10n.celebration), subtitle: Text(l10n.celebrationHint)),
        segmented(
          'celebration',
          [
            (Celebration.full, l10n.celebrationFull),
            (Celebration.subtle, l10n.celebrationSubtle),
            (Celebration.off, l10n.celebrationOff),
          ],
          display.celebration,
          (v) => display.set(celebration: v),
        ),
      ],
    );
  }
}

/// The drawn board's colours and the darts' colour, with a small board to see them on
class BoardColourTiles extends StatelessWidget {
  const BoardColourTiles({super.key});

  /// Three darts around the treble 20, the last one the brightest
  static final _sample = [
    DartThrow(BoardPoint.polar(103, 92), ThrowInput.board),
    DartThrow(BoardPoint.polar(60, 80), ThrowInput.board),
    DartThrow(BoardPoint.polar(103, 89), ThrowInput.board),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = DisplayScope.of(context);
    final palette = AppPalette.of(context);
    final dartNames = [l10n.dartWhite, l10n.dartYellow, l10n.dartCyan, l10n.dartMagenta];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(title: Text(l10n.boardColours), subtitle: Text(l10n.boardColoursHint)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<BoardColours>(
            key: const ValueKey('board-colours'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: BoardColours.classic, label: Text(l10n.boardClassic)),
              ButtonSegment(value: BoardColours.colourSafe, label: Text(l10n.boardColourSafe)),
              ButtonSegment(value: BoardColours.contrast, label: Text(l10n.boardContrast)),
            ],
            selected: {display.boardColours},
            onSelectionChanged: (s) => display.set(boardColours: s.first),
          ),
        ),
        ListTile(title: Text(l10n.dartColour)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Swatch(
                key: const ValueKey('dart-colour-accent'),
                colour: palette.accent,
                label: l10n.dartAccent,
                selected: display.dartColour == null,
                onTap: () => display.setDartColour(null),
              ),
              for (var i = 0; i < dartSwatches.length; ++i)
                _Swatch(
                  key: ValueKey('dart-colour-$i'),
                  colour: dartSwatches[i],
                  label: dartNames[i],
                  selected: display.dartColour == dartSwatches[i],
                  onTap: () => display.setDartColour(dartSwatches[i]),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Center(
            child: SizedBox.square(
              dimension: 180,
              child: ExcludeSemantics(
                child: Dartboard(key: const ValueKey('board-preview'), throws: _sample),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
