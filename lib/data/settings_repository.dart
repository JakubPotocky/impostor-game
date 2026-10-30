import 'package:flutter/material.dart' show ThemeMode;
import 'package:hive/hive.dart';
import 'package:impostor/core/word_difficulty.dart';

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
  /// Legacy bool from before [ThemeMode] support; read once for migration.
  static const String _keyDarkMode = 'darkMode';
  static const String _keyLastSeenVersion = 'lastSeenVersion';
  static const String _keyAllowedDifficulties = 'allowedDifficulties';
  static const String _keySoundEnabled = 'soundEnabled';
  static const String _keyHapticsEnabled = 'hapticsEnabled';
  static const String _keyHoldToReveal = 'holdToReveal';
  static const String _keyThemeMode = 'themeMode';
  static const String _keyUndercoverMode = 'undercoverMode';
  static const String _keyMysteryImpostors = 'mysteryImpostors';
  static const String _keyLastChanceGuess = 'lastChanceGuess';
  static const String _keyFamilyMode = 'familyMode';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(_box != null && _box!.isOpen, 'SettingsRepository not initialised');
    return _box!;
  }

  /// Box backing this repository, for full-app backup/restore.
  Box<dynamic> get backupBox => _safeBox;

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

  String getLastSeenVersion({String defaultValue = '0.0.0'}) {
    return _safeBox.get(_keyLastSeenVersion, defaultValue: defaultValue)
        as String;
  }

  Future<void> saveLastSeenVersion(String version) async {
    await _safeBox.put(_keyLastSeenVersion, version);
  }

  /// Light/dark/system appearance. Installs from before this setting existed
  /// keep their explicit choice from the old dark-mode switch.
  ThemeMode getThemeMode() {
    final stored = _safeBox.get(_keyThemeMode) as String?;
    if (stored != null) {
      return ThemeMode.values.firstWhere((m) => m.name == stored,
          orElse: () => ThemeMode.system);
    }
    final legacyDark = _safeBox.get(_keyDarkMode) as bool?;
    if (legacyDark == null) return ThemeMode.system;
    return legacyDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _safeBox.put(_keyThemeMode, mode.name);
  }

  bool getUndercoverMode() =>
      _safeBox.get(_keyUndercoverMode, defaultValue: false) as bool;

  Future<void> saveUndercoverMode(bool enabled) async {
    await _safeBox.put(_keyUndercoverMode, enabled);
  }

  bool getMysteryImpostors() =>
      _safeBox.get(_keyMysteryImpostors, defaultValue: false) as bool;

  Future<void> saveMysteryImpostors(bool enabled) async {
    await _safeBox.put(_keyMysteryImpostors, enabled);
  }

  bool getLastChanceGuess() =>
      _safeBox.get(_keyLastChanceGuess, defaultValue: false) as bool;

  Future<void> saveLastChanceGuess(bool enabled) async {
    await _safeBox.put(_keyLastChanceGuess, enabled);
  }

  bool getFamilyMode() =>
      _safeBox.get(_keyFamilyMode, defaultValue: false) as bool;

  Future<void> saveFamilyMode(bool enabled) async {
    await _safeBox.put(_keyFamilyMode, enabled);
  }

  bool getSoundEnabled() =>
      _safeBox.get(_keySoundEnabled, defaultValue: true) as bool;

  Future<void> saveSoundEnabled(bool enabled) async {
    await _safeBox.put(_keySoundEnabled, enabled);
  }

  bool getHapticsEnabled() =>
      _safeBox.get(_keyHapticsEnabled, defaultValue: true) as bool;

  Future<void> saveHapticsEnabled(bool enabled) async {
    await _safeBox.put(_keyHapticsEnabled, enabled);
  }

  bool getHoldToReveal() =>
      _safeBox.get(_keyHoldToReveal, defaultValue: false) as bool;

  Future<void> saveHoldToReveal(bool enabled) async {
    await _safeBox.put(_keyHoldToReveal, enabled);
  }

  /// Difficulties a word may have to be picked. Defaults to all of them, and
  /// never returns an empty set (that would make every word ineligible).
  Set<WordDifficulty> getAllowedDifficulties() {
    final raw = _safeBox.get(_keyAllowedDifficulties) as String?;
    if (raw == null || raw.isEmpty) return WordDifficulty.values.toSet();
    final parsed = raw
        .split(',')
        .map((name) => WordDifficulty.values.where((d) => d.name == name))
        .expand((matches) => matches)
        .toSet();
    return parsed.isEmpty ? WordDifficulty.values.toSet() : parsed;
  }

  Future<void> saveAllowedDifficulties(Set<WordDifficulty> difficulties) async {
    await _safeBox.put(
      _keyAllowedDifficulties,
      difficulties.map((d) => d.name).join(','),
    );
  }
}
