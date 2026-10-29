import 'package:flutter/foundation.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/data/theme_word.dart';

/// Immutable state model for themes.
@immutable
class ThemesState {
  const ThemesState({
    this.themes = const {},
    this.customThemeNames = const {},
    this.isLoading = true,
  });

  /// Map of theme name to language code to word list.
  final ThemeCatalog themes;

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

  /// Gets word entries (text + hint) for a theme in a specific language.
  /// Falls back to English if the language is not available.
  List<ThemeWord> getEntries(String theme, String language) {
    final langMap = themes[theme];
    if (langMap == null) return const [];
    return langMap[language] ?? langMap['en'] ?? const [];
  }

  /// Gets word texts for a theme in a specific language.
  /// Falls back to English if the language is not available.
  List<String> getWords(String theme, String language) =>
      getEntries(theme, language).map((w) => w.text).toList();

  /// Gets words for a theme in English (used for index-based picking).
  List<String> getEnglishWords(String theme) => getWords(theme, 'en');

  /// Difficulty identity of the word at [index] in [theme], or null if the
  /// index has no English counterpart (and so can never be picked).
  WordKey? wordKeyAt(String theme, int index) {
    final english = getEntries(theme, 'en');
    if (index < 0 || index >= english.length) return null;
    return WordKey(theme: theme, englishWord: english[index].text);
  }

  ThemesState copyWith({
    ThemeCatalog? themes,
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
