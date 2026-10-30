import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/data/game_history_repository.dart';

/// When the current game night ("session") started. Games played since then
/// count towards tonight's standings.
class SessionNotifier extends Notifier<DateTime> {
  SessionNotifier([this._initialStart]);

  final DateTime? _initialStart;

  @override
  DateTime build() => _initialStart ?? DateTime.now();

  /// Starts a fresh session: standings reset, history is untouched.
  void startNew() => state = DateTime.now();
}

/// Provider for [SessionNotifier]. Overridden in `main` with the app launch
/// time, so the first game of the night counts even though nothing reads
/// this provider until it ends.
final sessionProvider =
    NotifierProvider<SessionNotifier, DateTime>(SessionNotifier.new);

/// One player's score for the session.
class SessionStanding {
  SessionStanding(this.name);

  final String name;
  int points = 0;
  int wins = 0;
  int games = 0;
}

/// Standings for games played at or after [since], best first.
///
/// Scoring: an impostor win is worth [impostorWinPoints] (it's harder —
/// they're outnumbered), an innocent win [innocentWinPoints]. Blank rounds
/// have no winners and score nothing. Ties break on fewer games played, then
/// name.
abstract final class SessionScoring {
  static const int impostorWinPoints = 2;
  static const int innocentWinPoints = 1;

  static List<SessionStanding> standings(
    List<GameRecord> games, {
    required DateTime since,
  }) {
    final byName = <String, SessionStanding>{};
    for (final game in games) {
      if (game.timestamp.isBefore(since)) continue;
      for (final player in game.players) {
        final s = byName.putIfAbsent(player, () => SessionStanding(player));
        s.games++;
        if (!game.winnerNames.contains(player)) continue;
        s.wins++;
        s.points += game.impostorNames.contains(player)
            ? impostorWinPoints
            : innocentWinPoints;
      }
    }
    return byName.values.toList()
      ..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) return byPoints;
        final byGames = a.games.compareTo(b.games);
        return byGames != 0 ? byGames : a.name.compareTo(b.name);
      });
  }

  /// Competition ranks ("1, 1, 1, 4") for [standings] as returned by
  /// [standings]: players level on points share a rank, so ties don't hand
  /// out different medals.
  static List<int> ranks(List<SessionStanding> standings) {
    final ranks = <int>[];
    for (var i = 0; i < standings.length; i++) {
      final tied = i > 0 && standings[i].points == standings[i - 1].points;
      ranks.add(tied ? ranks[i - 1] : i + 1);
    }
    return ranks;
  }
}
