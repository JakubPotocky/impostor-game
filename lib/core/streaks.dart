import 'package:impostor/data/game_history_repository.dart';

class PlayerStreak {
  const PlayerStreak({
    required this.current,
    required this.best,
    required this.lastGameWon,
  });

  final int current;
  final int best;
  final bool lastGameWon;
}

Map<String, PlayerStreak> computePlayerStreaks(List<GameRecord> games) {
  final byName = <String, _MutableStreak>{};

  final chronological = List<GameRecord>.from(games)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  for (final game in chronological) {
    final winnerSet = game.winnerNames.toSet();
    for (final player in game.players) {
      final row = byName.putIfAbsent(player, () => _MutableStreak());
      final won = winnerSet.contains(player);
      if (won) {
        row.current += 1;
        if (row.current > row.best) {
          row.best = row.current;
        }
      } else {
        row.current = 0;
      }
      row.lastGameWon = won;
    }
  }

  return byName.map((name, s) => MapEntry(
        name,
        PlayerStreak(
          current: s.current,
          best: s.best,
          lastGameWon: s.lastGameWon,
        ),
      ));
}

class _MutableStreak {
  int current = 0;
  int best = 0;
  bool lastGameWon = false;
}
