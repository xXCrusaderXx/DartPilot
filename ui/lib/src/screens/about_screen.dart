import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../app_info.dart';
import '../widgets/app_mark.dart';

/// What this app is: name, version, licence, where the source and the guide are, and the licences of what it includes
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.version = appVersion});

  /// The release version; empty in a build from source
  final String version;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final versionText = version.isEmpty ? l10n.aboutDevelopmentBuild : l10n.aboutVersion(version);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const AppMark(key: ValueKey('about-mark'), size: 88),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
                        Text(
                          versionText,
                          key: const ValueKey('about-version'),
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.aboutDescription),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    _LinkTile(
                      key: const ValueKey('about-source'),
                      icon: Icons.code,
                      title: l10n.aboutSource,
                      url: sourceUrl,
                    ),
                    _LinkTile(
                      key: const ValueKey('about-guide'),
                      icon: Icons.menu_book_outlined,
                      title: l10n.aboutGuide,
                      url: userGuideUrl(Localizations.localeOf(context).languageCode),
                    ),
                    _LinkTile(
                      key: const ValueKey('about-licence'),
                      icon: Icons.gavel,
                      title: l10n.aboutLicence,
                      shown: 'GPL-3.0-or-later',
                      url: licenceUrl,
                    ),
                    ListTile(
                      key: const ValueKey('about-third-party'),
                      leading: const Icon(Icons.description_outlined),
                      title: Text(l10n.aboutThirdParty),
                      subtitle: Text(l10n.aboutThirdPartyHint),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: l10n.appTitle,
                        applicationVersion: versionText,
                        applicationIcon: const Padding(padding: EdgeInsets.all(8), child: AppMark(size: 64)),
                        applicationLegalese: l10n.aboutLegalese,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.aboutCreditsText, key: const ValueKey('about-credits')),
              const SizedBox(height: 16),
              Text(
                l10n.aboutLicenceText,
                key: const ValueKey('about-legal'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A link as a row: tapping it copies the address, which is shown without its scheme; the app opens no browser itself.
class _LinkTile extends StatelessWidget {
  const _LinkTile({super.key, required this.icon, required this.title, required this.url, this.shown});

  final IconData icon;
  final String title;
  final String url;

  /// What the row shows in place of the address
  final String? shown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Future<void> copy() async {
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(SnackBar(content: Text(l10n.aboutLinkCopied)));
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(shown ?? url.replaceFirst('https://', ''), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.copy, semanticLabel: l10n.aboutCopyLink),
      onTap: copy,
    );
  }
}
