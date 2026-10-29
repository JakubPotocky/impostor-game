import 'package:flutter/foundation.dart';
import 'package:impostor/core/word_difficulty.dart';

enum ThemeVisibilityMode {
  off,
  innocentsOnly,
  everyone,
}

/// Immutable state model for game setup / configuration.
@immutable
class GameSetupState {
  const GameSetupState({
    this.impostorCount = 1,
    this.selectedThemes = const [],
    this.language = 'en',
    this.timerEnabled = false,
    this.timerMinutes = 2,
    this.hintsEnabled = false,
    this.themeVisibilityMode = ThemeVisibilityMode.innocentsOnly,
    this.reducedMotion = false,
    this.suddenDeathEnabled = true,
    this.darkMode = true,
    this.allowedDifficulties = allDifficulties,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.holdToReveal = false,
  });

  static const Set<WordDifficulty> allDifficulties = {
    WordDifficulty.unset,
    WordDifficulty.easy,
    WordDifficulty.medium,
    WordDifficulty.hard,
  };

  final int impostorCount;

  /// List of enabled theme names (multi-select via toggles).
  final List<String> selectedThemes;
  final String language;
  final bool timerEnabled;
  final int timerMinutes;
  final bool hintsEnabled;
  final ThemeVisibilityMode themeVisibilityMode;
  final bool reducedMotion;
  final bool suddenDeathEnabled;
  final bool darkMode;

  /// Only words rated with one of these difficulties can be picked.
  final Set<WordDifficulty> allowedDifficulties;

  final bool soundEnabled;
  final bool hapticsEnabled;

  /// Roles are only visible while the player holds a finger on the screen.
  final bool holdToReveal;

  /// Whether the difficulty filter excludes anything.
  bool get isDifficultyFiltered =>
      !allowedDifficulties.containsAll(WordDifficulty.values);

  bool get hasThemes => selectedThemes.isNotEmpty;

  GameSetupState copyWith({
    int? impostorCount,
    List<String>? selectedThemes,
    String? language,
    bool? timerEnabled,
    int? timerMinutes,
    bool? hintsEnabled,
    ThemeVisibilityMode? themeVisibilityMode,
    bool? reducedMotion,
    bool? suddenDeathEnabled,
    bool? darkMode,
    Set<WordDifficulty>? allowedDifficulties,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? holdToReveal,
  }) {
    return GameSetupState(
      impostorCount: impostorCount ?? this.impostorCount,
      selectedThemes: selectedThemes ?? this.selectedThemes,
      language: language ?? this.language,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      timerMinutes: timerMinutes ?? this.timerMinutes,
      hintsEnabled: hintsEnabled ?? this.hintsEnabled,
      themeVisibilityMode: themeVisibilityMode ?? this.themeVisibilityMode,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      suddenDeathEnabled: suddenDeathEnabled ?? this.suddenDeathEnabled,
      darkMode: darkMode ?? this.darkMode,
      allowedDifficulties: allowedDifficulties ?? this.allowedDifficulties,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      holdToReveal: holdToReveal ?? this.holdToReveal,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSetupState &&
          runtimeType == other.runtimeType &&
          impostorCount == other.impostorCount &&
          _listEquals(selectedThemes, other.selectedThemes) &&
          language == other.language &&
          timerEnabled == other.timerEnabled &&
          timerMinutes == other.timerMinutes &&
          hintsEnabled == other.hintsEnabled &&
          themeVisibilityMode == other.themeVisibilityMode &&
          reducedMotion == other.reducedMotion &&
          suddenDeathEnabled == other.suddenDeathEnabled &&
          darkMode == other.darkMode &&
          setEquals(allowedDifficulties, other.allowedDifficulties) &&
          soundEnabled == other.soundEnabled &&
          hapticsEnabled == other.hapticsEnabled &&
          holdToReveal == other.holdToReveal;

  @override
  int get hashCode => Object.hash(
      impostorCount,
      Object.hashAll(selectedThemes),
      language,
      timerEnabled,
      timerMinutes,
      hintsEnabled,
      themeVisibilityMode,
      reducedMotion,
      suddenDeathEnabled,
      darkMode,
      Object.hashAllUnordered(allowedDifficulties),
      soundEnabled,
      hapticsEnabled,
      holdToReveal);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
