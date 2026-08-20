import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/data/game_history_repository.dart';

/// Screen showing game history and player stats.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(gameHistoryRepositoryProvider);
    final games = repo.getGames();
    final colorScheme = Theme.of(context).colorScheme;

    // Compute player stats.
    final playerStats = _computePlayerStats(games);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
        centerTitle: true,
        actions: [
          if (games.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear History',
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: games.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64, color: colorScheme.primary.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text(
                    'No games played yet',
                    style: TextStyle(
                      color: colorScheme.onSurface.withAlpha(150),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: const [
                      Tab(text: 'Recent Games'),
                      Tab(text: 'Player Stats'),
                    ],
                    indicatorColor: colorScheme.primary,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurface.withAlpha(120),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _RecentGamesTab(games: games),
                        _PlayerStatsTab(stats: playerStats),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Map<String, _PlayerStat> _computePlayerStats(List<GameRecord> games) {
    final stats = <String, _PlayerStat>{};
    for (final game in games) {
      for (final player in game.players) {
        final s = stats.putIfAbsent(player, () => _PlayerStat(name: player));
        s.totalGames++;
        final wasImpostor = game.impostorNames.contains(player);
        if (wasImpostor) {
          s.timesImpostor++;
          if (game.impostorsWon) s.wins++;
        } else {
          if (!game.impostorsWon) s.wins++;
        }
      }
    }
    return stats;
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Delete all game history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              ref.read(gameHistoryRepositoryProvider).clearHistory();
              Navigator.of(ctx).pop();
              // Force rebuild.
              (context as Element).markNeedsBuild();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player stat model
// ---------------------------------------------------------------------------
class _PlayerStat {
  _PlayerStat({required this.name});
  final String name;
  int totalGames = 0;
  int wins = 0;
  int timesImpostor = 0;

  double get winRate => totalGames > 0 ? wins / totalGames : 0;
}

// ---------------------------------------------------------------------------
// Recent games tab
// ---------------------------------------------------------------------------
class _RecentGamesTab extends StatelessWidget {
  const _RecentGamesTab({required this.games});
  final List<GameRecord> games;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        final isImpostorWin = game.impostorsWon;
        final resultColor =
            isImpostorWin ? Colors.red.shade400 : Colors.green.shade400;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isImpostorWin
                          ? Icons.warning_amber_rounded
                          : Icons.emoji_events_rounded,
                      size: 18,
                      color: resultColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isImpostorWin ? 'Impostors Won' : 'Innocents Won',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: resultColor,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(game.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withAlpha(100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.key_rounded,
                        size: 14, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Word: ${game.word}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withAlpha(180),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.masks_rounded,
                        size: 14, color: Colors.red.shade300),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Impostors: ${game.impostorNames.join(", ")}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people_alt_rounded,
                        size: 14, color: colorScheme.onSurface.withAlpha(100)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${game.players.length} players',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withAlpha(120),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Player stats tab
// ---------------------------------------------------------------------------
class _PlayerStatsTab extends StatelessWidget {
  const _PlayerStatsTab({required this.stats});
  final Map<String, _PlayerStat> stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sorted = stats.values.toList()
      ..sort((a, b) => b.winRate.compareTo(a.winRate));

    if (sorted.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final s = sorted[index];
        final pct = (s.winRate * 100).toStringAsFixed(0);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(s.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${s.totalGames} games · ${s.timesImpostor} as impostor',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withAlpha(120),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  '${s.wins} wins',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withAlpha(120),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
