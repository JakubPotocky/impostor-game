import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/round_factory.dart';
import 'package:impostor/features/lan_lobby/lan_session_notifier.dart';
import 'package:impostor/features/lan_lobby/screens/lan_ready_check_screen.dart';
import 'package:impostor/features/role_reveal/role_reveal_screen.dart';

/// Result of [launchLanRound]: where the host goes next.
typedef LanRoundLaunch = ({
  Widget hostScreen,

  /// True when every player was claimed by a guest device, so the host has
  /// no local reveals and goes straight to the readiness check.
  bool allPlayersClaimed,
});

/// Sends [round] to connected LAN devices and builds the host's next screen.
///
/// Each device that picked a player gets only that player's reveal; anyone
/// unclaimed (including the host's own role) is revealed locally on the host.
LanRoundLaunch launchLanRound(WidgetRef ref, GameRound round) {
  final setup = ref.read(gameSetupProvider);
  final lanNotifier = ref.read(lanSessionProvider.notifier);

  final hostBucket = lanNotifier.distributeAssignments(
    allAssignments: round.assignments
        .map((a) => {
              'playerName': a.playerName,
              'isImpostor': a.isImpostor,
              'word': a.word,
            })
        .toList(),
    word: round.word,
    themeName: round.themeName,
    hintsEnabled: setup.hintsEnabled,
    themeVisibilityMode: setup.themeVisibilityMode.index,
    impostorHintWord: round.impostorHint,
    reducedMotion: setup.reducedMotion,
  );
  lanNotifier.triggerStartGame();

  final hostAssignments = hostBucket
      .map((a) => RoleAssignment(
            playerName: a['playerName'] as String,
            isImpostor: a['isImpostor'] as bool,
            word: a['word'] as String?,
          ))
      .toList();

  final timerSeconds = setup.timerEnabled ? setup.timerMinutes * 60 : 0;
  Widget checkPlayersScreen(BuildContext _) => LanReadyCheckScreen(
        assignments: round.assignments,
        word: round.word,
        timerSeconds: timerSeconds,
        isBlankRound: round.isBlankRound,
        reducedMotion: setup.reducedMotion,
        suddenDeathEnabled: setup.suddenDeathEnabled,
        startingPlayerName: round.startingPlayerName,
        wordKey: round.wordKey,
        impostorHintWord: round.impostorHint,
      );

  if (hostAssignments.isEmpty) {
    return (
      hostScreen: Builder(builder: checkPlayersScreen),
      allPlayersClaimed: true,
    );
  }

  return (
    hostScreen: RoleRevealScreen(
      assignments: hostAssignments,
      votingAssignments: round.assignments,
      word: round.word,
      themeName: round.themeName,
      hintsEnabled: setup.hintsEnabled,
      themeVisibilityMode: setup.themeVisibilityMode,
      impostorHintWord: round.impostorHint,
      timerSeconds: timerSeconds,
      isBlankRound: round.isBlankRound,
      reducedMotion: setup.reducedMotion,
      suddenDeathEnabled: setup.suddenDeathEnabled,
      startingPlayerName: round.startingPlayerName,
      wordKey: round.wordKey,
      holdToReveal: setup.holdToReveal,
      onComplete: checkPlayersScreen,
      completeButtonLabel: 'Check Players',
    ),
    allPlayersClaimed: false,
  );
}
