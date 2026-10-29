import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:impostor/data/theme_word.dart';

/// Loads theme data from the bundled JSON asset.
///
/// The JSON structure is:
/// ```json
/// { "ThemeName": { "en": [{"word": "Lion", "hint": "Mane"}, ...], ... } }
/// ```
/// Plain-string entries (no hint) are also accepted; see [ThemeWord.fromJson].
class ThemeRepository {
  ThemeCatalog? _cache;

  /// Loads and caches themes from assets/themes.json.
  Future<ThemeCatalog> loadThemes() async {
    if (_cache != null) return _cache!;

    final jsonString = await rootBundle.loadString('assets/themes.json');
    _cache = decodeThemeCatalog(json.decode(jsonString) as Map<String, dynamic>);
    return _cache!;
  }
}
