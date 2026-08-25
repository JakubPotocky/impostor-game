import 'dart:math';

/// Reason a round ended, beyond simply "somebody won via voting".
enum RoundEndReason {
  normalVoteResolution,
  suddenDeath,
  impostorGuessedWord,
  blankRound,
}

/// Picks the discussion starter using weighted random.
///
/// Innocents have weight 1.0; impostors have weight 0.25 (4× less likely).
/// In a blank round all players are impostors and the weights are equal,
/// giving a uniform distribution.
String pickStarter(List<RoleAssignment> assignments, Random random) {
  final allImpostors = assignments.every((a) => a.isImpostor);
  final weighted = assignments.map((a) {
    final w = (allImpostors || !a.isImpostor) ? 1.0 : 0.25;
    return (name: a.playerName, w: w);
  }).toList();

  final total = weighted.fold<double>(0, (sum, e) => sum + e.w);
  var r = random.nextDouble() * total;
  for (final e in weighted) {
    r -= e.w;
    if (r <= 0) return e.name;
  }
  return weighted.last.name;
}

/// Immutable model representing a player's assigned role in a round.
class RoleAssignment {
  const RoleAssignment({
    required this.playerName,
    required this.isImpostor,
    this.word,
  });

  final String playerName;
  final bool isImpostor;

  /// The secret word — null for impostors.
  final String? word;
}

/// Pure logic service for assigning roles.
/// Deterministic when given a specific [Random] instance.
class RoleAssignmentService {
  const RoleAssignmentService();

  /// Assigns roles to all players.
  ///
  /// [players] — list of player names (order matters for reveal sequence).
  /// [impostorCount] — number of impostors (must be >= 1 and < players.length).
  /// [word] — the secret word for the round.
  /// [random] — RNG instance (injectable for testing).
  ///
  /// Returns a list of [RoleAssignment] in the same order as [players].
  List<RoleAssignment> assignRoles({
    required List<String> players,
    required int impostorCount,
    required String word,
    required Random random,
  }) {
    assert(players.length >= 3, 'Need at least 3 players');
    assert(
      impostorCount >= 1 && impostorCount < players.length,
      'Invalid impostor count',
    );

    // Pick unique impostor indices.
    final impostorIndices = <int>{};
    while (impostorIndices.length < impostorCount) {
      impostorIndices.add(random.nextInt(players.length));
    }

    return List.generate(players.length, (i) {
      final isImpostor = impostorIndices.contains(i);
      return RoleAssignment(
        playerName: players[i],
        isImpostor: isImpostor,
        word: isImpostor ? null : word,
      );
    });
  }
}
