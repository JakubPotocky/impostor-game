import 'package:flutter/material.dart';
import 'package:impostor/core/streaks.dart';
import 'package:impostor/data/game_history_repository.dart';

/// A single unlockable badge definition. Pure and stateless — evaluated
/// against a player's full game history, not tracked incrementally, so
/// re-evaluating after an imported/edited history is always correct.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlockedFor,
  });

  /// Stable identifier — persisted, never rename without a migration.
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(String playerName, List<GameRecord> history) isUnlockedFor;
}

int _gamesPlayed(String player, List<GameRecord> history) =>
    history.where((g) => g.players.contains(player)).length;

int _gamesWon(String player, List<GameRecord> history) =>
    history.where((g) => g.winnerNames.contains(player)).length;

int _impostorWins(String player, List<GameRecord> history) => history
    .where((g) => g.impostorNames.contains(player) && g.winnerNames.contains(player))
    .length;

int _survivedGames(String player, List<GameRecord> history) => history
    .where((g) => g.players.contains(player) && !g.killedNames.contains(player))
    .length;

int _bestStreak(String player, List<GameRecord> history) =>
    computePlayerStreaks(history)[player]?.best ?? 0;

/// Ordered catalog of every badge in the app. Order here is display order.
const List<Achievement> achievementCatalog = [
  Achievement(
    id: 'first_blood',
    title: 'First Blood',
    description: 'Win your first game.',
    icon: Icons.emoji_events_rounded,
    isUnlockedFor: _firstBlood,
  ),
  Achievement(
    id: 'impostor_initiate',
    title: 'Impostor Initiate',
    description: 'Win a game as the impostor.',
    icon: Icons.masks_rounded,
    isUnlockedFor: _impostorInitiate,
  ),
  Achievement(
    id: 'master_of_disguise',
    title: 'Master of Disguise',
    description: 'Win 5 games as the impostor.',
    icon: Icons.theater_comedy_rounded,
    isUnlockedFor: _masterOfDisguise,
  ),
  Achievement(
    id: 'hot_streak',
    title: 'Hot Streak',
    description: 'Reach a 3-game win streak.',
    icon: Icons.local_fire_department_rounded,
    isUnlockedFor: _hotStreak,
  ),
  Achievement(
    id: 'unstoppable',
    title: 'Unstoppable',
    description: 'Reach a 10-game win streak.',
    icon: Icons.bolt_rounded,
    isUnlockedFor: _unstoppable,
  ),
  Achievement(
    id: 'survivor',
    title: 'Survivor',
    description: 'Finish a game without being eliminated, 10 times.',
    icon: Icons.shield_rounded,
    isUnlockedFor: _survivor,
  ),
  Achievement(
    id: 'blank_stare',
    title: 'Blank Stare',
    description: 'Play through a Blank Round.',
    icon: Icons.psychology_alt_rounded,
    isUnlockedFor: _blankStare,
  ),
  Achievement(
    id: 'century_club',
    title: 'Century Club',
    description: 'Play 100 games.',
    icon: Icons.workspace_premium_rounded,
    isUnlockedFor: _centuryClub,
  ),
];

bool _firstBlood(String player, List<GameRecord> history) =>
    _gamesWon(player, history) >= 1;

bool _impostorInitiate(String player, List<GameRecord> history) =>
    _impostorWins(player, history) >= 1;

bool _masterOfDisguise(String player, List<GameRecord> history) =>
    _impostorWins(player, history) >= 5;

bool _hotStreak(String player, List<GameRecord> history) =>
    _bestStreak(player, history) >= 3;

bool _unstoppable(String player, List<GameRecord> history) =>
    _bestStreak(player, history) >= 10;

bool _survivor(String player, List<GameRecord> history) =>
    _survivedGames(player, history) >= 10;

bool _blankStare(String player, List<GameRecord> history) => history
    .any((g) => g.isBlankRound && g.players.contains(player));

bool _centuryClub(String player, List<GameRecord> history) =>
    _gamesPlayed(player, history) >= 100;
