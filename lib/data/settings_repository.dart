import 'package:hive/hive.dart';

/// Repository that persists game settings between sessions using Hive.
class SettingsRepository {
  static const String _boxName = 'settings';
  static const String _keyImpostorCount = 'impostorCount';
  static const String _keySelectedThemes = 'selectedThemes';
  static const String _keyLanguage = 'language';
  static const String _keyHasSeenTutorial = 'hasSeenTutorial';
  static const String _keyTimerEnabled = 'timerEnabled';
  static const String _keyTimerMinutes = 'timerMinutes';
  static const String _keyHintsEnabled = 'hintsEnabled';
  static const String _keyThemeVisibilityMode = 'themeVisibilityMode';
  static const String _keyReducedMotion = 'reducedMotion';
  static const String _keySuddenDeathEnabled = 'suddenDeathEnabled';
  static const String _keyDarkMode = 'darkMode';
  static const String _keyLastSeenVersion = 'lastSeenVersion';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(_box != null && _box!.isOpen, 'SettingsRepository not initialised');
    return _box!;
  }

  int getImpostorCount({int defaultValue = 1}) {
    return _safeBox.get(_keyImpostorCount, defaultValue: defaultValue) as int;
  }

  Future<void> saveImpostorCount(int count) async {
    await _safeBox.put(_keyImpostorCount, count);
  }

  List<String> getSelectedThemes() {
    final raw = _safeBox.get(_keySelectedThemes) as String?;
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  Future<void> saveSelectedThemes(List<String> themes) async {
    await _safeBox.put(_keySelectedThemes, themes.join(','));
  }

  String getLanguage({String defaultValue = 'en'}) {
    return _safeBox.get(_keyLanguage, defaultValue: defaultValue) as String;
  }

  Future<void> saveLanguage(String language) async {
    await _safeBox.put(_keyLanguage, language);
  }

  bool getHasSeenTutorial() {
    return _safeBox.get(_keyHasSeenTutorial, defaultValue: false) as bool;
  }

  Future<void> saveHasSeenTutorial(bool seen) async {
    await _safeBox.put(_keyHasSeenTutorial, seen);
  }

  bool getTimerEnabled() {
    return _safeBox.get(_keyTimerEnabled, defaultValue: false) as bool;
  }

  Future<void> saveTimerEnabled(bool enabled) async {
    await _safeBox.put(_keyTimerEnabled, enabled);
  }

  int getTimerMinutes({int defaultValue = 2}) {
    return _safeBox.get(_keyTimerMinutes, defaultValue: defaultValue) as int;
  }

  Future<void> saveTimerMinutes(int minutes) async {
    await _safeBox.put(_keyTimerMinutes, minutes);
  }

  bool getHintsEnabled({bool defaultValue = false}) {
    return _safeBox.get(_keyHintsEnabled, defaultValue: defaultValue) as bool;
  }

  Future<void> saveHintsEnabled(bool enabled) async {
    await _safeBox.put(_keyHintsEnabled, enabled);
  }

  int getThemeVisibilityMode({int defaultValue = 1}) {
    return _safeBox.get(_keyThemeVisibilityMode, defaultValue: defaultValue)
        as int;
  }

  Future<void> saveThemeVisibilityMode(int mode) async {
    await _safeBox.put(_keyThemeVisibilityMode, mode);
  }

  bool getReducedMotion({bool defaultValue = false}) {
    return _safeBox.get(_keyReducedMotion, defaultValue: defaultValue) as bool;
  }

  Future<void> saveReducedMotion(bool enabled) async {
    await _safeBox.put(_keyReducedMotion, enabled);
  }

  bool getSuddenDeathEnabled({bool defaultValue = true}) {
    return _safeBox.get(_keySuddenDeathEnabled, defaultValue: defaultValue)
        as bool;
  }

  Future<void> saveSuddenDeathEnabled(bool enabled) async {
    await _safeBox.put(_keySuddenDeathEnabled, enabled);
  }

  bool getDarkMode({bool defaultValue = true}) {
    return _safeBox.get(_keyDarkMode, defaultValue: defaultValue) as bool;
  }

  Future<void> saveDarkMode(bool dark) async {
    await _safeBox.put(_keyDarkMode, dark);
  }

  String getLastSeenVersion({String defaultValue = '0.0.0'}) {
    return _safeBox.get(_keyLastSeenVersion, defaultValue: defaultValue)
        as String;
  }

  Future<void> saveLastSeenVersion(String version) async {
    await _safeBox.put(_keyLastSeenVersion, version);
  }
}
