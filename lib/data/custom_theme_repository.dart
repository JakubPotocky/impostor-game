import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:impostor/data/theme_word.dart';

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

  /// Box backing this repository, for full-app backup/restore.
  Box<dynamic> get backupBox => _safeBox;

  /// Returns custom themes as a map of category name -> language -> words.
  ThemeCatalog getCustomThemes() {
    final raw = _safeBox.get(_keyThemes) as String?;
    if (raw == null || raw.isEmpty) return {};
    return decodeThemeCatalog(json.decode(raw) as Map<String, dynamic>);
  }

  /// Saves the entire custom themes map.
  Future<void> saveCustomThemes(ThemeCatalog themes) async {
    await _safeBox.put(_keyThemes, json.encode(encodeThemeCatalog(themes)));
  }
}
