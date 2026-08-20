import 'package:flutter/foundation.dart';

/// Immutable state model for themes.
@immutable
class ThemesState {
  const ThemesState({
    this.themes = const {},
    this.customThemeNames = const {},
    this.isLoading = true,
  });

  /// Map of theme name to language code to word list.
  final Map<String, Map<String, List<String>>> themes;

  /// Names of themes that are user-created (not bundled).
  final Set<String> customThemeNames;

  final bool isLoading;

  List<String> get themeNames => themes.keys.toList()..sort();

  /// Whether a theme is user-created (custom).
  bool isCustom(String name) => customThemeNames.contains(name);

  /// Returns the list of available language codes (from the first theme).
  List<String> get availableLanguages {
    if (themes.isEmpty) return ['en'];
    return themes.values.first.keys.toList();
  }

  /// Gets words for a theme in a specific language.
  /// Falls back to English if the language is not available.
  List<String> getWords(String theme, String language) {
    final langMap = themes[theme];
    if (langMap == null) return [];
    return langMap[language] ?? langMap['en'] ?? [];
  }

  /// Gets words for a theme in English (used for index-based picking).
  List<String> getEnglishWords(String theme) {
    return getWords(theme, 'en');
  }

  ThemesState copyWith({
    Map<String, Map<String, List<String>>>? themes,
    Set<String>? customThemeNames,
    bool? isLoading,
  }) {
    return ThemesState(
      themes: themes ?? this.themes,
      customThemeNames: customThemeNames ?? this.customThemeNames,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
