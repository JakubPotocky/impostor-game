import 'package:flutter/foundation.dart';

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
    this.reducedMotion = false,
    this.suddenDeathEnabled = true,
    this.darkMode = true,
  });

  final int impostorCount;

  /// List of enabled theme names (multi-select via toggles).
  final List<String> selectedThemes;
  final String language;
  final bool timerEnabled;
  final int timerMinutes;
  final bool hintsEnabled;
  final bool reducedMotion;
  final bool suddenDeathEnabled;
  final bool darkMode;

  bool get hasThemes => selectedThemes.isNotEmpty;

  GameSetupState copyWith({
    int? impostorCount,
    List<String>? selectedThemes,
    String? language,
    bool? timerEnabled,
    int? timerMinutes,
    bool? hintsEnabled,
    bool? reducedMotion,
    bool? suddenDeathEnabled,
    bool? darkMode,
  }) {
    return GameSetupState(
      impostorCount: impostorCount ?? this.impostorCount,
      selectedThemes: selectedThemes ?? this.selectedThemes,
      language: language ?? this.language,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      timerMinutes: timerMinutes ?? this.timerMinutes,
      hintsEnabled: hintsEnabled ?? this.hintsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      suddenDeathEnabled: suddenDeathEnabled ?? this.suddenDeathEnabled,
      darkMode: darkMode ?? this.darkMode,
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
          reducedMotion == other.reducedMotion &&
          suddenDeathEnabled == other.suddenDeathEnabled &&
          darkMode == other.darkMode;

  @override
  int get hashCode => Object.hash(
      impostorCount,
      Object.hashAll(selectedThemes),
      language,
      timerEnabled,
      timerMinutes,
      hintsEnabled,
      reducedMotion,
      suddenDeathEnabled,
      darkMode);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
