import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';

/// Shown instead of the app while a network engine asks this device to pair (#110): the player types the PIN that the
/// engine's device shows. The token from pairing is stored, so this comes once per engine.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final engine = EngineScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await engine.pairWithPin(_pin.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error != null) _pin.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final engine = EngineScope.of(context);
    final digits = engine.hello?.pinDigits ?? 6;
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              Text(l10n.pairText(engine.url), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              TextField(
                key: const ValueKey('pairing-pin'),
                controller: _pin,
                autofocus: true,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: digits,
                style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 8),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.pairPin, counterText: ''),
                onChanged: (value) {
                  if (value.length == digits) _pair();
                },
                onSubmitted: (_) => _pair(),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    switch (error) {
                      'wrong_pin' => l10n.pairWrongPin,
                      'too_many_attempts' => l10n.pairTooManyAttempts,
                      _ => l10n.pairFailed(error),
                    },
                    key: const ValueKey('pairing-error'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('pairing-submit'),
                onPressed: _busy ? null : _pair,
                child: Text(l10n.pairButton),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: engine.disconnect, child: Text(l10n.disconnect)),
            ],
          ),
        ),
      ),
    );
  }
}
