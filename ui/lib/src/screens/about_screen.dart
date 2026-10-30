import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../app_info.dart';

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
              Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(versionText, key: const ValueKey('about-version'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(l10n.aboutDescription),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    _LinkTile(
                      key: const ValueKey('about-licence'),
                      icon: Icons.gavel,
                      title: l10n.aboutLicence,
                      subtitle: l10n.aboutLicenceText,
                      url: licenceUrl,
                    ),
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
                        applicationLegalese: l10n.aboutLegalese,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.aboutCredits, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l10n.aboutCreditsText, key: const ValueKey('about-credits')),
            ],
          ),
        ),
      ),
    );
  }
}

/// A link shown as text that can be copied; the app opens no browser itself
class _LinkTile extends StatelessWidget {
  const _LinkTile({super.key, required this.icon, required this.title, this.subtitle, required this.url});

  final IconData icon;
  final String title;
  final String? subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [if (subtitle != null) Text(subtitle!), SelectableText(url)],
      ),
      trailing: IconButton(
        tooltip: l10n.aboutCopyLink,
        icon: const Icon(Icons.copy),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await Clipboard.setData(ClipboardData(text: url));
          messenger.showSnackBar(SnackBar(content: Text(l10n.aboutLinkCopied)));
        },
      ),
    );
  }
}
