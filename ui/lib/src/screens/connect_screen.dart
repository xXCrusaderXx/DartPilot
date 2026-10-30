import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_choice.dart';
import '../engine/engine_connection.dart';
import '../widgets/engine_card.dart';

/// How the darts are counted, chosen on the first start and whenever the player wants to change it: by hand right
/// away, with cameras on this computer, or with cameras on another computer in the network. Each way is a card of the
/// same weight; the two with cameras open their connection details only when picked.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.onPlayByHand, this.onCancel});

  final VoidCallback onPlayByHand;

  /// Back to the main view unchanged; null on the first start, where there is nothing to go back to
  final VoidCallback? onCancel;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  /// The way with cameras whose details are open; null while none is
  EngineMode? _open;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    // Where this device can run the engine and it is the remembered (or found) choice, its card is open already.
    final local = LocalEngineScope.maybeOf(context);
    if (local != null && local.settings.mode == EngineMode.thisDevice) _open = EngineMode.thisDevice;
  }

  Future<void> _pick(EngineMode mode) async {
    final settings = EngineSettingsScope.of(context);
    final local = LocalEngineScope.maybeOf(context);
    final engine = EngineScope.read(context);
    setState(() => _open = _open == mode ? null : mode);
    if (settings.mode == mode) return;
    settings.mode = mode;
    await settings.save();
    // The engine this app started is not the one in the network.
    if (mode == EngineMode.network && local != null) {
      await local.notifier!.stop();
      await engine.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final local = LocalEngineScope.maybeOf(context);
    final onCancel = widget.onCancel;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        leading: onCancel == null ? null : CloseButton(key: const ValueKey('connect-cancel'), onPressed: onCancel),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.connectTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  l10n.connectIntro,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                _ChoiceCard(
                  key: const ValueKey('play-offline'),
                  icon: Icons.touch_app_outlined,
                  title: l10n.countByHandTitle,
                  text: l10n.countByHandText,
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: widget.onPlayByHand,
                ),
                if (local != null)
                  _ChoiceCard(
                    key: const ValueKey('count-this-device'),
                    icon: Icons.computer,
                    title: l10n.countThisDeviceTitle,
                    text: l10n.countThisDeviceText,
                    open: _open == EngineMode.thisDevice,
                    onTap: () => _pick(EngineMode.thisDevice),
                    child: LocalEnginePanel(local: local),
                  ),
                _ChoiceCard(
                  key: const ValueKey('count-network'),
                  icon: Icons.lan_outlined,
                  title: l10n.countNetworkTitle,
                  text: l10n.countNetworkText,
                  open: _open == EngineMode.network,
                  onTap: () => _pick(EngineMode.network),
                  child: const NetworkEnginePanel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One way of counting: icon, name and a line on what it means; a way with details shows them once picked.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
    this.open = false,
    this.trailing,
    this.child,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;
  final bool open;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = child;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: open
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, size: 36, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailing ?? Icon(open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (open && details != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: details),
        ],
      ),
    );
  }
}
