import 'dart:convert';

import 'package:hive/hive.dart';

/// Repository that persists user-created / edited themes using Hive.
///
/// Custom themes are stored as a JSON string. They are merged on top of the
/// bundled themes at load time by the ThemesNotifier.
class CustomThemeRepository {
  static const String _boxName = 'custom_themes';
  static const String _keyThemes = 'themes';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(
        _box != null && _box!.isOpen, 'CustomThemeRepository not initialised');
    return _box!;
  }

  /// Returns custom themes as a map of category name -> language -> word list.
  Map<String, Map<String, List<String>>> getCustomThemes() {
    final raw = _safeBox.get(_keyThemes) as String?;
    if (raw == null || raw.isEmpty) return {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((theme, langMap) {
      final languages = (langMap as Map<String, dynamic>).map(
        (lang, words) =>
            MapEntry(lang, (words as List<dynamic>).cast<String>()),
      );
      return MapEntry(theme, languages);
    });
  }

  /// Saves the entire custom themes map.
  Future<void> saveCustomThemes(
      Map<String, Map<String, List<String>>> themes) async {
    final encoded = json.encode(themes);
    await _safeBox.put(_keyThemes, encoded);
  }
}
