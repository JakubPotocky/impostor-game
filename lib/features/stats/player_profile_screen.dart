import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/achievements.dart';
import 'package:impostor/core/player_profile.dart';
import 'package:impostor/data/achievement_repository.dart';
import 'package:impostor/data/game_history_repository.dart';
import 'package:impostor/features/players/player_avatar_widget.dart';

/// One player's career: win rates by role, streaks, recent form, badges.
class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({super.key, required this.playerName});

  final String playerName;

  static String _pct(double? rate) =>
      rate == null ? '—' : '${(rate * 100).round()}%';

  static String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.read(gameHistoryRepositoryProvider).getGames();
    final profile = PlayerProfile.compute(playerName, games);
    final badges = ref
        .read(achievementRepositoryProvider)
        .getUnlockedFor(playerName)
        .map((u) => achievementCatalog.where((a) => a.id == u.badgeId))
        .expand((matches) => matches)
        .toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(playerName), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: PlayerAvatar(name: playerName, size: 88)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${_count(profile.games, 'game')} · '
              '${_count(profile.wins, 'win')} · ${_pct(profile.winRate)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.masks_rounded,
                  color: Colors.red.shade400,
                  label: 'As impostor',
                  value: _pct(profile.impostorWinRate),
                  detail:
                      '${profile.impostorWins} of ${profile.impostorGames} won',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.shield_rounded,
                  color: Colors.green.shade400,
                  label: 'As innocent',
                  value: _pct(profile.innocentWinRate),
                  detail:
                      '${profile.innocentWins} of ${profile.innocentGames} won',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                  label: 'Win streak',
                  value: '${profile.currentStreak}',
                  detail: 'Best ever: ${profile.bestStreak}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.how_to_vote_rounded,
                  color: Colors.blueGrey,
                  label: 'Voted out',
                  value: _pct(profile.eliminationRate),
                  detail: 'Spoke first ${profile.timesStarted}×',
                ),
              ),
            ],
          ),
          if (profile.recentForm.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Recent form',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Semantics(
              label: 'Last ${_count(profile.recentForm.length, 'game')}, '
                  'newest first: '
                  '${profile.recentForm.map((w) => w ? 'win' : 'loss').join(', ')}',
              child: ExcludeSemantics(
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final won in profile.recentForm)
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: (won ? Colors.green : Colors.red)
                            .withAlpha(50),
                        child: Text(
                          won ? 'W' : 'L',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: won
                                ? Colors.green.shade400
                                : Colors.red.shade400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Newest first',
              style: TextStyle(
                  fontSize: 11, color: colorScheme.onSurface.withAlpha(120)),
            ),
          ],
          const SizedBox(height: 24),
          Text('Badges (${badges.length}/${achievementCatalog.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (badges.isEmpty)
            Text('None yet',
                style: TextStyle(color: colorScheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final badge in badges)
                  Chip(
                    avatar: Icon(badge.icon,
                        size: 18, color: Colors.amber.shade700),
                    label: Text(badge.title),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(detail,
              style: TextStyle(
                  fontSize: 11, color: colorScheme.onSurface.withAlpha(140))),
        ],
      ),
    );
  }
}
