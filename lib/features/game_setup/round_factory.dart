import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/constants.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/core/word_hint_service.dart';
import 'package:impostor/core/word_picker_service.dart';
import 'package:impostor/core/word_weighting.dart';
import 'package:impostor/data/theme_word.dart';
import 'package:impostor/data/word_vote_repository.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/themes/themes_notifier.dart';
import 'package:impostor/features/themes/themes_state.dart';
import 'package:impostor/features/themes/word_difficulty_notifier.dart';

/// Provider for the word picker, persists across the session.
final wordPickerServiceProvider = Provider<WordPickerService>((ref) {
  return WordPickerService();
});

/// Everything decided up front for one round of the normal game mode.
@immutable
class GameRound {
  const GameRound({
    required this.assignments,
    required this.word,
    required this.themeName,
    required this.wordKey,
    required this.impostorHint,
    required this.isBlankRound,
    required this.startingPlayerName,
  });

  final List<RoleAssignment> assignments;

  /// The secret word in the selected language.
  final String word;
  final String themeName;

  /// Language-independent identity of [word], used for difficulty ratings.
  final WordKey wordKey;

  /// Clue shown to impostors (when hints are enabled).
  final String? impostorHint;

  /// Whether everyone is an impostor this round.
  final bool isBlankRound;

  /// Who opens the discussion. Always set — including blank rounds.
  final String startingPlayerName;
}

/// Outcome of [RoundFactory.build].
sealed class RoundBuildResult {
  const RoundBuildResult();
}

final class RoundReady extends RoundBuildResult {
  const RoundReady(this.round);
  final GameRound round;
}

final class RoundUnavailable extends RoundBuildResult {
  const RoundUnavailable(this.reason);

  /// User-facing explanation of why no round could be built.
  final String reason;
}

/// Builds a [GameRound]: picks the theme and word, the impostor hint, roles,
/// and the starting player.
///
/// Pure logic (no Flutter or providers) so it is deterministic given a seeded
/// [Random], and shared by local play, rematches and LAN hosting.
class RoundFactory {
  const RoundFactory({this.roleService = const RoleAssignmentService()});

  final RoleAssignmentService roleService;

  /// Team Pairs holds word pairs for Team mode; never a normal-round theme.
  static const String teamPairsTheme = 'Team Pairs';

  /// Typing this as a player name forces a blank round; the "player" is
  /// removed from the roster.
  static const String blankRoundTrigger = 'j999';

  /// One round in this many is a blank round (~8 %).
  static const int blankRoundOdds = 12;

  /// Indices of words in [theme] whose difficulty is in [allowed].
  ///
  /// Only indices with an English entry are considered, since English is the
  /// canonical list words are picked from.
  static List<int> eligibleWordIndices({
    required ThemesState themes,
    required String theme,
    required Set<WordDifficulty> allowed,
    required WordDifficultyMap difficulties,
  }) {
    final english = themes.getEntries(theme, 'en');
    return [
      for (var i = 0; i < english.length; i++)
        if (allowed.contains(difficulties.of(
            WordKey(theme: theme, englishWord: english[i].text))))
          i,
    ];
  }

  RoundBuildResult build({
    required List<String> players,
    required List<String> enabledThemes,
    required int impostorCount,
    required String language,
    required Set<WordDifficulty> allowedDifficulties,
    required ThemesState themes,
    required WordDifficultyMap difficulties,
    required WordPickerService wordPicker,
    required Random random,
    Map<String, WordVote> votes = const {},
  }) {
    final forceBlankRound = players.contains(blankRoundTrigger);
    final roster = players.where((p) => p != blankRoundTrigger).toList();
    if (roster.length < AppConstants.minPlayers) {
      return const RoundUnavailable(
          'Need at least ${AppConstants.minPlayers} players to start.');
    }

    final candidateThemes =
        enabledThemes.where((t) => t != teamPairsTheme).toList();
    if (candidateThemes.isEmpty) {
      return const RoundUnavailable('Enable at least one theme to start.');
    }

    final eligibleByTheme = <String, List<int>>{
      for (final theme in candidateThemes)
        theme: eligibleWordIndices(
          themes: themes,
          theme: theme,
          allowed: allowedDifficulties,
          difficulties: difficulties,
        ),
    }..removeWhere((_, indices) => indices.isEmpty);
    if (eligibleByTheme.isEmpty) {
      final anyWords =
          candidateThemes.any((t) => themes.getEntries(t, 'en').isNotEmpty);
      return RoundUnavailable(anyWords
          ? 'No words in the selected themes match your difficulty filter.'
          : 'The selected themes have no words — pick another theme.');
    }

    final isBlankRound =
        forceBlankRound || random.nextInt(blankRoundOdds) == 0;

    final eligibleThemes = eligibleByTheme.keys.toList();
    final theme = eligibleThemes[random.nextInt(eligibleThemes.length)];
    // Words are index-aligned across languages; translations may be shorter
    // than the English list, in which case the English entry is shown.
    final english = themes.getEntries(theme, 'en');
    final translated = themes.getEntries(theme, language);
    List<ThemeWord> displayListFor(int i) =>
        i < translated.length ? translated : english;

    final index = wordPicker.pickFromCandidates(
      theme: theme,
      candidates: eligibleByTheme[theme]!,
      random: random,
      weightOf: votes.isEmpty
          ? null
          : (i) => _voteWeight(
                votes,
                displayWord: displayListFor(i)[i].text,
                englishWord: english[i].text,
              ),
    );

    final displayList = displayListFor(index);
    final entry = displayList[index];

    final impostorHint = entry.hint ??
        pickImpostorHintWord(
          themeWords: displayList.map((w) => w.text).toList(),
          secretWord: entry.text,
          random: random,
        );

    final assignments = isBlankRound
        ? [
            for (final name in roster)
              RoleAssignment(playerName: name, isImpostor: true),
          ]
        : roleService.assignRoles(
            players: roster,
            // A saved count can be stale (e.g. from a bigger game).
            impostorCount: impostorCount.clamp(1, roster.length - 1),
            word: entry.text,
            random: random,
          );

    return RoundReady(GameRound(
      assignments: assignments,
      word: entry.text,
      themeName: theme,
      wordKey: WordKey(theme: theme, englishWord: english[index].text),
      impostorHint: impostorHint,
      isBlankRound: isBlankRound,
      startingPlayerName: pickStarter(assignments, random),
    ));
  }
}

/// Pick weight from like/dislike votes. Votes are recorded against the word
/// as shown, so a concept's votes are pooled across the languages it was
/// played in (here: the current one and English).
double _voteWeight(
  Map<String, WordVote> votes, {
  required String displayWord,
  required String englishWord,
}) {
  var likes = votes[displayWord]?.likes ?? 0;
  var dislikes = votes[displayWord]?.dislikes ?? 0;
  if (englishWord != displayWord) {
    likes += votes[englishWord]?.likes ?? 0;
    dislikes += votes[englishWord]?.dislikes ?? 0;
  }
  return WordWeighting.fromVotes(likes: likes, dislikes: dislikes);
}

/// Builds a round from the current game setup, themes and ratings.
RoundBuildResult createRound(WidgetRef ref, {required List<String> players}) {
  final themes = ref.read(themesProvider).valueOrNull;
  if (themes == null) {
    return const RoundUnavailable(
        'Themes are still loading — try again in a moment.');
  }
  final setup = ref.read(gameSetupProvider);
  return const RoundFactory().build(
    players: players,
    enabledThemes: setup.selectedThemes,
    impostorCount: setup.impostorCount,
    language: setup.language,
    allowedDifficulties: setup.allowedDifficulties,
    themes: themes,
    difficulties: ref.read(wordDifficultyProvider),
    wordPicker: ref.read(wordPickerServiceProvider),
    random: Random(),
    votes: ref.read(wordVoteRepositoryProvider).getVotes(),
  );
}
