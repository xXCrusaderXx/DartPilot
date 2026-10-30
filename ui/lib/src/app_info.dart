/// The release version, set by the release build (`--dart-define=DARTPILOT_VERSION=X.Y.Z`, the same value it passes
/// as `--build-name`); empty in a build from source.
const appVersion = String.fromEnvironment('DARTPILOT_VERSION');

const sourceUrl = 'https://github.com/xXCrusaderXx/DartPilot';
const licenceUrl = '$sourceUrl/blob/main/LICENSE';

/// The player guide in the app's language: German for German, English otherwise
String userGuideUrl(String languageCode) =>
    '$sourceUrl/blob/main/docs/${languageCode == 'de' ? 'user-guide.de.md' : 'user-guide.md'}';
