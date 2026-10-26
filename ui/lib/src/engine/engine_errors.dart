import '../../l10n/app_localizations.dart';

/// Text for error codes any request can end with; null for codes only the caller can explain.
String? engineErrorText(AppLocalizations l10n, String code) => switch (code) {
  'disconnected' => l10n.engineErrorDisconnected,
  'timeout' => l10n.engineErrorTimeout,
  'busy' => l10n.calibErrorBusy,
  _ => null,
};

/// Why connecting failed, from the error the socket gave; null when it names no known cause.
String? connectionErrorText(AppLocalizations l10n, String? error) {
  if (error == null) return null;
  if (error.contains('TimeoutException')) return l10n.engineFailedTimeout;
  if (error.contains('Connection refused')) return l10n.engineFailedRefused;
  if (error.contains('Failed host lookup') || error.contains('No address associated')) return l10n.engineFailedHost;
  if (error.contains('FormatException') ||
      error.contains('Unsupported scheme') ||
      error.contains('No host specified')) {
    return l10n.engineFailedAddress;
  }
  return null;
}
