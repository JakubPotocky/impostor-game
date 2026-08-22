import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/achievements.dart';
import 'package:impostor/data/achievement_repository.dart';
import 'package:impostor/data/game_history_repository.dart';

/// Screen showing every player's unlocked (and locked) badges.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final games = ref.read(gameHistoryRepositoryProvider).getGames();
    final unlocked = ref.read(achievementRepositoryProvider).getUnlocked();

    // Every player who has ever appeared in a game record, most active first.
    final gamesByPlayer = <String, int>{};
    for (final game in games) {
      for (final player in game.players) {
        gamesByPlayer[player] = (gamesByPlayer[player] ?? 0) + 1;
      }
    }
    final players = gamesByPlayer.keys.toList()
      ..sort((a, b) => gamesByPlayer[b]!.compareTo(gamesByPlayer[a]!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        centerTitle: true,
      ),
      body: players.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 64, color: colorScheme.primary.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text(
                    'Play a game to start earning badges',
                    style: TextStyle(
                      color: colorScheme.onSurface.withAlpha(150),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final unlockedIds = unlocked
                    .where((u) => u.playerName == player)
                    .map((u) => u.badgeId)
                    .toSet();
                return _PlayerBadgeCard(
                  playerName: player,
                  unlockedCount: unlockedIds.length,
                  unlockedIds: unlockedIds,
                );
              },
            ),
    );
  }
}

class _PlayerBadgeCard extends StatelessWidget {
  const _PlayerBadgeCard({
    required this.playerName,
    required this.unlockedCount,
    required this.unlockedIds,
  });

  final String playerName;
  final int unlockedCount;
  final Set<String> unlockedIds;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    playerName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$unlockedCount / ${achievementCatalog.length}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: achievementCatalog.map((badge) {
                final isUnlocked = unlockedIds.contains(badge.id);
                return Tooltip(
                  message: '${badge.title}\n${badge.description}',
                  child: Container(
                    width: 68,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isUnlocked
                          ? Colors.amber.withAlpha(35)
                          : colorScheme.surfaceContainerHighest.withAlpha(60),
                      border: Border.all(
                        color: isUnlocked
                            ? Colors.amber.shade400
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          badge.icon,
                          color: isUnlocked
                              ? Colors.amber.shade700
                              : colorScheme.onSurface.withAlpha(70),
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isUnlocked
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withAlpha(100),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
