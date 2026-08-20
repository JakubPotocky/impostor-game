/// Application-wide constants for the Impostor game.
class AppConstants {
  AppConstants._();

  static const int minPlayers = 3;
  static const int maxPlayerNameLength = 20;
  static const int defaultImpostorCount = 1;
  static const String appName = 'Impostor';
  static const String defaultLanguage = 'en';

  /// Human-readable labels for supported languages.
  static const Map<String, String> languageLabels = {
    'en': 'English',
    'sk': 'Slovenčina',
    'da': 'Dansk',
    'de': 'Deutsch',
    'es': 'Español',
    'zh': '中文',
  };
}
