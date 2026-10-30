import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/game_setup/round_factory.dart';
import 'package:impostor/features/role_reveal/role_reveal_screen.dart';
import 'package:impostor/features/themes/themes_notifier.dart';

/// The pass-and-play reveal screen for [round] under [setup].
RoleRevealScreen localRevealScreen(GameSetupState setup, GameRound round) {
  return RoleRevealScreen(
    assignments: round.revealAssignments,
    votingAssignments: round.assignments,
    word: round.word,
    themeName: round.themeName,
    hintsEnabled: setup.hintsEnabled,
    themeVisibilityMode: setup.themeVisibilityMode,
    impostorHintWord: round.impostorHint,
    timerSeconds: setup.timerEnabled ? setup.timerMinutes * 60 : 0,
    isBlankRound: round.isBlankRound,
    reducedMotion: setup.reducedMotion,
    suddenDeathEnabled: setup.suddenDeathEnabled,
    startingPlayerName: round.startingPlayerName,
    wordKey: round.wordKey,
    holdToReveal: setup.holdToReveal,
  );
}

/// Builds a round for [players] from the current setup and opens its reveal.
///
/// With [replaceStack], everything above the home screen is replaced (used
/// for rematches). If no round can be built, the reason is shown in a
/// snackbar and false is returned.
Future<bool> startLocalRound(
  BuildContext context,
  WidgetRef ref, {
  required List<String> players,
  bool replaceStack = false,
}) async {
  // Themes load lazily on first use; screens like Home never watch them, so
  // make sure they're loaded rather than failing with "still loading".
  await ref.read(themesProvider.future);
  if (!context.mounted) return false;

  switch (createRound(ref, players: players)) {
    case RoundUnavailable(:final reason):
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(reason)));
      return false;
    case RoundReady(:final round):
      final route =
          createSlideRoute(localRevealScreen(ref.read(gameSetupProvider), round));
      final navigator = Navigator.of(context);
      if (replaceStack) {
        navigator.pushAndRemoveUntil(route, (r) => r.isFirst);
      } else {
        navigator.push(route);
      }
      return true;
  }
}
