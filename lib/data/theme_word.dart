import 'package:flutter/foundation.dart';

/// A single word in a theme, optionally paired with a hint for impostors.
@immutable
class ThemeWord {
  const ThemeWord(this.text, {String? hint}) : _hint = hint;

  /// Parses an entry from theme JSON.
  ///
  /// Accepts both the legacy plain-string form (`"Lion"`) and the object form
  /// (`{"word": "Lion", "hint": "Mane"}`), so custom themes saved and exported
  /// before hints existed keep loading.
  factory ThemeWord.fromJson(Object? raw) {
    if (raw is String) return ThemeWord(raw);
    if (raw is Map) {
      final word = raw['word'];
      if (word is! String) {
        throw const FormatException('Theme word entry is missing "word"');
      }
      return ThemeWord(word, hint: raw['hint'] as String?);
    }
    throw FormatException('Unsupported theme word entry: $raw');
  }

  final String text;
  final String? _hint;

  /// The trimmed hint, or null when there is no usable hint.
  String? get hint {
    final trimmed = _hint?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  bool get hasHint => hint != null;

  /// Serialises back to the most compact form: a plain string when there is
  /// no hint, so hint-less themes stay byte-compatible with older versions.
  Object toJson() => hasHint ? {'word': text, 'hint': hint} : text;

  ThemeWord copyWith({String? text, String? hint}) =>
      ThemeWord(text ?? this.text, hint: hint ?? _hint);

  @override
  bool operator ==(Object other) =>
      other is ThemeWord && other.text == text && other.hint == hint;

  @override
  int get hashCode => Object.hash(text, hint);

  @override
  String toString() => hasHint ? 'ThemeWord($text, hint: $hint)' : text;
}

/// Theme name -> language code -> index-aligned word list.
///
/// Words are index-aligned across languages: index `i` in every language is
/// the same concept, with English as the canonical list.
typedef ThemeCatalog = Map<String, Map<String, List<ThemeWord>>>;

/// Decodes a [ThemeCatalog] from already-parsed JSON.
ThemeCatalog decodeThemeCatalog(Map<String, dynamic> json) {
  return json.map((themeName, langMap) {
    final languages = (langMap as Map<String, dynamic>).map(
      (lang, words) => MapEntry(
        lang,
        (words as List<dynamic>).map(ThemeWord.fromJson).toList(),
      ),
    );
    return MapEntry(themeName, languages);
  });
}

/// Encodes a [ThemeCatalog] to a JSON-compatible map.
Map<String, dynamic> encodeThemeCatalog(ThemeCatalog catalog) {
  return catalog.map((themeName, langMap) => MapEntry(
        themeName,
        langMap.map((lang, words) =>
            MapEntry(lang, words.map((w) => w.toJson()).toList())),
      ));
}

/// Deep-copies a catalog so callers can mutate the result freely.
ThemeCatalog copyThemeCatalog(ThemeCatalog catalog) {
  return catalog.map((themeName, langMap) => MapEntry(
        themeName,
        langMap.map((lang, words) => MapEntry(lang, List.of(words))),
      ));
}

/// Parses bulk-entered words, each optionally followed by `: hint`.
///
/// Entries are one per line; input without line breaks is split on commas
/// instead (the original single-line format), so hints in multi-line input may
/// themselves contain commas. Blank entries are skipped.
///
/// ```text
/// Lion: Mane
/// Penguin: Tuxedo
/// Otter
/// ```
List<ThemeWord> parseWordList(String input) {
  final entries = input.contains('\n') ? input.split('\n') : input.split(',');
  final words = <ThemeWord>[];
  for (final entry in entries) {
    final separator = entry.indexOf(':');
    final text =
        (separator == -1 ? entry : entry.substring(0, separator)).trim();
    if (text.isEmpty) continue;
    final hint = separator == -1 ? null : entry.substring(separator + 1).trim();
    words.add(ThemeWord(text, hint: hint));
  }
  return words;
}
