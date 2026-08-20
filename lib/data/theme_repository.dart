import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads theme data from the bundled JSON asset.
///
/// The JSON structure is:
/// ```json
/// { "ThemeName": { "en": ["word1", ...], "fr": ["mot1", ...] } }
/// ```
class ThemeRepository {
  Map<String, Map<String, List<String>>>? _cache;

  /// Loads and caches themes from assets/themes.json.
  /// Returns a map of theme name to language code to word list.
  Future<Map<String, Map<String, List<String>>>> loadThemes() async {
    if (_cache != null) return _cache!;

    final jsonString = await rootBundle.loadString('assets/themes.json');
    final Map<String, dynamic> decoded =
        json.decode(jsonString) as Map<String, dynamic>;

    _cache = decoded.map((themeName, langMap) {
      final languages = (langMap as Map<String, dynamic>).map(
        (lang, words) => MapEntry(
          lang,
          (words as List<dynamic>).cast<String>(),
        ),
      );
      return MapEntry(themeName, languages);
    });
    return _cache!;
  }
}
