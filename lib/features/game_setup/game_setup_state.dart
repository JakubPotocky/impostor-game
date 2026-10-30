import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
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
    this.themeMode = ThemeMode.system,
    this.allowedDifficulties = allDifficulties,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.holdToReveal = false,
    this.undercoverMode = false,
    this.mysteryImpostors = false,
    this.lastChanceGuess = false,
    this.familyMode = false,
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
  /// Light, dark, or follow the phone.
  final ThemeMode themeMode;

  /// Only words rated with one of these difficulties can be picked.
  final Set<WordDifficulty> allowedDifficulties;

  final bool soundEnabled;
  final bool hapticsEnabled;

  /// Roles are only visible while the player holds a finger on the screen.
  final bool holdToReveal;

  /// Impostors get a decoy word and don't know they are impostors.
  final bool undercoverMode;

  /// The impostor count is random (1 to [impostorCount]) and kept secret.
  final bool mysteryImpostors;

  /// A caught impostor may still win by guessing the secret word.
  final bool lastChanceGuess;

  /// Hide themes with mature content.
  final bool familyMode;

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
    ThemeMode? themeMode,
    Set<WordDifficulty>? allowedDifficulties,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? holdToReveal,
    bool? undercoverMode,
    bool? mysteryImpostors,
    bool? lastChanceGuess,
    bool? familyMode,
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
      themeMode: themeMode ?? this.themeMode,
      allowedDifficulties: allowedDifficulties ?? this.allowedDifficulties,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      holdToReveal: holdToReveal ?? this.holdToReveal,
      undercoverMode: undercoverMode ?? this.undercoverMode,
      mysteryImpostors: mysteryImpostors ?? this.mysteryImpostors,
      lastChanceGuess: lastChanceGuess ?? this.lastChanceGuess,
      familyMode: familyMode ?? this.familyMode,
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
          themeMode == other.themeMode &&
          setEquals(allowedDifficulties, other.allowedDifficulties) &&
          soundEnabled == other.soundEnabled &&
          hapticsEnabled == other.hapticsEnabled &&
          holdToReveal == other.holdToReveal &&
          undercoverMode == other.undercoverMode &&
          mysteryImpostors == other.mysteryImpostors &&
          lastChanceGuess == other.lastChanceGuess &&
          familyMode == other.familyMode;

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
      themeMode,
      Object.hashAllUnordered(allowedDifficulties),
      soundEnabled,
      hapticsEnabled,
      holdToReveal,
      Object.hash(
          undercoverMode, mysteryImpostors, lastChanceGuess, familyMode));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
