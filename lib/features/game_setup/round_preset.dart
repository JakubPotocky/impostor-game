import 'package:flutter/foundation.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';

/// A named snapshot of the round settings in [GameSetupState].
///
/// Only settings that shape a round are captured — device preferences such as
/// dark mode, sound or reduced motion stay as they are when a preset is
/// applied, since they belong to the phone rather than the game night.
@immutable
class RoundPreset {
  const RoundPreset({
    required this.name,
    required this.impostorCount,
    required this.selectedThemes,
    required this.language,
    required this.timerEnabled,
    required this.timerMinutes,
    required this.hintsEnabled,
    required this.themeVisibilityMode,
    required this.suddenDeathEnabled,
    required this.allowedDifficulties,
    this.undercoverMode = false,
    this.mysteryImpostors = false,
    this.lastChanceGuess = false,
  });

  factory RoundPreset.fromState(String name, GameSetupState state) {
    return RoundPreset(
      name: name,
      impostorCount: state.impostorCount,
      selectedThemes: List.unmodifiable(state.selectedThemes),
      language: state.language,
      timerEnabled: state.timerEnabled,
      timerMinutes: state.timerMinutes,
      hintsEnabled: state.hintsEnabled,
      themeVisibilityMode: state.themeVisibilityMode,
      suddenDeathEnabled: state.suddenDeathEnabled,
      allowedDifficulties: Set.unmodifiable(state.allowedDifficulties),
      undercoverMode: state.undercoverMode,
      mysteryImpostors: state.mysteryImpostors,
      lastChanceGuess: state.lastChanceGuess,
    );
  }

  /// Parses a stored preset. Fields missing from older saves fall back to
  /// [GameSetupState] defaults, so presets survive new settings being added.
  factory RoundPreset.fromJson(Map<String, dynamic> json) {
    const defaults = GameSetupState();
    final visibility = json['themeVisibilityMode'] as String?;
    final difficulties = (json['allowedDifficulties'] as List<dynamic>?)
        ?.map((d) => WordDifficulty.fromName(d as String))
        .toSet();
    return RoundPreset(
      name: json['name'] as String,
      impostorCount: json['impostorCount'] as int? ?? defaults.impostorCount,
      selectedThemes:
          ((json['selectedThemes'] as List<dynamic>?) ?? const [])
              .cast<String>(),
      language: json['language'] as String? ?? defaults.language,
      timerEnabled: json['timerEnabled'] as bool? ?? defaults.timerEnabled,
      timerMinutes: json['timerMinutes'] as int? ?? defaults.timerMinutes,
      hintsEnabled: json['hintsEnabled'] as bool? ?? defaults.hintsEnabled,
      themeVisibilityMode: ThemeVisibilityMode.values.firstWhere(
        (m) => m.name == visibility,
        orElse: () => defaults.themeVisibilityMode,
      ),
      suddenDeathEnabled:
          json['suddenDeathEnabled'] as bool? ?? defaults.suddenDeathEnabled,
      allowedDifficulties: (difficulties == null || difficulties.isEmpty)
          ? defaults.allowedDifficulties
          : difficulties,
      undercoverMode: json['undercoverMode'] as bool? ?? false,
      mysteryImpostors: json['mysteryImpostors'] as bool? ?? false,
      lastChanceGuess: json['lastChanceGuess'] as bool? ?? false,
    );
  }

  final String name;
  final int impostorCount;
  final List<String> selectedThemes;
  final String language;
  final bool timerEnabled;
  final int timerMinutes;
  final bool hintsEnabled;
  final ThemeVisibilityMode themeVisibilityMode;
  final bool suddenDeathEnabled;
  final Set<WordDifficulty> allowedDifficulties;
  final bool undercoverMode;
  final bool mysteryImpostors;
  final bool lastChanceGuess;

  /// [state] with this preset's round settings applied.
  GameSetupState applyTo(GameSetupState state) {
    return state.copyWith(
      impostorCount: impostorCount,
      selectedThemes: selectedThemes,
      language: language,
      timerEnabled: timerEnabled,
      timerMinutes: timerMinutes,
      hintsEnabled: hintsEnabled,
      themeVisibilityMode: themeVisibilityMode,
      suddenDeathEnabled: suddenDeathEnabled,
      allowedDifficulties: allowedDifficulties,
      undercoverMode: undercoverMode,
      mysteryImpostors: mysteryImpostors,
      lastChanceGuess: lastChanceGuess,
    );
  }

  /// Whether [state] currently has exactly this preset's round settings.
  bool matches(GameSetupState state) => applyTo(state) == state;

  Map<String, dynamic> toJson() => {
        'name': name,
        'impostorCount': impostorCount,
        'selectedThemes': selectedThemes,
        'language': language,
        'timerEnabled': timerEnabled,
        'timerMinutes': timerMinutes,
        'hintsEnabled': hintsEnabled,
        'themeVisibilityMode': themeVisibilityMode.name,
        'suddenDeathEnabled': suddenDeathEnabled,
        'allowedDifficulties':
            allowedDifficulties.map((d) => d.name).toList(),
        'undercoverMode': undercoverMode,
        'mysteryImpostors': mysteryImpostors,
        'lastChanceGuess': lastChanceGuess,
      };
}
