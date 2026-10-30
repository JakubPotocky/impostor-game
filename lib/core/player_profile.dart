import 'package:impostor/core/streaks.dart';
import 'package:impostor/data/game_history_repository.dart';

/// Everything worth knowing about one player, computed from game history.
class PlayerProfile {
  PlayerProfile._(this.name);

  /// Builds [name]'s profile from [games] (any order).
  factory PlayerProfile.compute(String name, List<GameRecord> games) {
    final profile = PlayerProfile._(name);
    final played = games.where((g) => g.players.contains(name)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final g in played) {
      profile.games++;
      final won = g.winnerNames.contains(name);
      if (won) profile.wins++;
      if (g.killedNames.contains(name)) profile.timesEliminated++;
      if (g.startingPlayerName == name) profile.timesStarted++;
      if (g.isBlankRound) {
        profile.blankRounds++;
      } else if (g.impostorNames.contains(name)) {
        profile.impostorGames++;
        if (won) profile.impostorWins++;
      } else {
        profile.innocentGames++;
        if (won) profile.innocentWins++;
      }
    }
    profile.recentForm = [
      for (final g in played.where((g) => !g.isBlankRound).take(recentGames))
        g.winnerNames.contains(name),
    ];
    final streak = computePlayerStreaks(games)[name];
    profile.currentStreak = streak?.current ?? 0;
    profile.bestStreak = streak?.best ?? 0;
    return profile;
  }

  /// How many recent results [recentForm] covers.
  static const int recentGames = 10;

  final String name;
  int games = 0;
  int wins = 0;
  int impostorGames = 0;
  int impostorWins = 0;
  int innocentGames = 0;
  int innocentWins = 0;
  int blankRounds = 0;
  int timesEliminated = 0;
  int timesStarted = 0;
  int currentStreak = 0;
  int bestStreak = 0;

  /// Win (true) / loss (false), newest first, blank rounds excluded.
  List<bool> recentForm = const [];

  double? get winRate => _rate(wins, games);
  double? get impostorWinRate => _rate(impostorWins, impostorGames);
  double? get innocentWinRate => _rate(innocentWins, innocentGames);

  /// Share of games where the player was voted out.
  double? get eliminationRate => _rate(timesEliminated, games);

  static double? _rate(int part, int whole) => whole == 0 ? null : part / whole;
}
