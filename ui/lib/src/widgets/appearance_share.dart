import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../display.dart';
import 'engine_qr.dart';

/// Moving the appearance to another device: as a code to copy or a QR code to scan, and back
class AppearanceShareTiles extends StatelessWidget {
  const AppearanceShareTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        ListTile(
          key: const ValueKey('appearance-share'),
          leading: const Icon(Icons.qr_code_2),
          title: Text(l10n.appearanceShare),
          subtitle: Text(l10n.appearanceShareHint),
          onTap: () => showDialog<void>(context: context, builder: (_) => const _ShareDialog()),
        ),
        ListTile(
          key: const ValueKey('appearance-apply'),
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.appearanceApply),
          subtitle: Text(l10n.appearanceApplyHint),
          onTap: () => showDialog<void>(context: context, builder: (_) => const _ApplyDialog()),
        ),
      ],
    );
  }
}

class _ShareDialog extends StatelessWidget {
  const _ShareDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = DisplayScope.of(context).toCode();
    return AlertDialog(
      title: Text(l10n.appearanceShare),
      // A fixed width, which the QR code cannot report while the dialog measures its content
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 240,
                  child: QrImageView(key: const ValueKey('appearance-qr'), data: code, size: 240),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                code,
                key: const ValueKey('appearance-code'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('appearance-copy'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: code));
            messenger.showSnackBar(SnackBar(content: Text(l10n.appearanceCopied)));
          },
          child: Text(l10n.appearanceCopy),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close)),
      ],
    );
  }
}

class _ApplyDialog extends StatefulWidget {
  const _ApplyDialog();

  @override
  State<_ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<_ApplyDialog> {
  final TextEditingController _code = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply(String code) async {
    final display = DisplayScope.of(context);
    final navigator = Navigator.of(context);
    if (await display.applyCode(code)) {
      navigator.pop();
    } else {
      setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.appearanceApply),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('appearance-code-field'),
            controller: _code,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.appearanceCodeLabel,
              errorText: _invalid ? l10n.appearanceCodeInvalid : null,
            ),
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
          ),
          if (canScanQr) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('appearance-scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.scanEngineQr),
              onPressed: () async {
                final code = await scanQr(
                  context,
                  title: l10n.appearanceApply,
                  hint: l10n.appearanceScanHint,
                  unavailable: l10n.appearanceScanUnavailable,
                  accept: (value) => value.startsWith(DisplaySettings.codePrefix),
                );
                if (code != null) await _apply(code);
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          key: const ValueKey('appearance-code-apply'),
          onPressed: () => _apply(_code.text),
          child: Text(l10n.accentApply),
        ),
      ],
    );
  }
}
