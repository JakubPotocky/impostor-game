import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/animated_effects.dart';
import 'package:impostor/core/feedback_service.dart';
import 'package:impostor/core/motion.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/core/streaks.dart';
import 'package:impostor/core/word_hint_service.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/data/game_history_repository.dart';
import 'package:impostor/data/word_vote_repository.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/lan_lobby/lan_session_notifier.dart';
import 'package:impostor/features/lan_lobby/lan_session_state.dart';
import 'package:impostor/features/lan_lobby/screens/host_lobby_screen.dart';
import 'package:impostor/features/lan_lobby/screens/lan_ready_check_screen.dart';
import 'package:impostor/features/players/players_notifier.dart';
import 'package:impostor/features/players/players_screen.dart';
import 'package:impostor/features/pre_game/pre_game_screen.dart';
import 'package:impostor/features/role_reveal/role_reveal_screen.dart';
import 'package:impostor/features/themes/themes_notifier.dart';
import 'package:impostor/features/voting/voting_screen.dart' show GameResult;

/// End screen showing the game result, who the impostors were, and the word.
class EndScreen extends ConsumerStatefulWidget {
  const EndScreen({
    super.key,
    required this.assignments,
    required this.word,
    required this.result,
    required this.killedIndices,
    this.reducedMotion = false,
  });

  final List<RoleAssignment> assignments;
  final String word;
  final GameResult result;
  final List<int> killedIndices;
  final bool reducedMotion;

  @override
  ConsumerState<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends ConsumerState<EndScreen>
    with SingleTickerProviderStateMixin {
  /// Tracks whether the user already voted on this word.
  /// null = not voted, true = liked, false = disliked.
  bool? _vote;
  bool _historySaved = false;
  String? _hotStreakMessage;
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  static const _feedback = FeedbackService();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.resolveDuration(
        AppMotion.celebration,
        reduced: widget.reducedMotion,
      ),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
    _feedback.victory();
    // Record game history after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveHistory());
  }

  void _saveHistory() {
    if (_historySaved) return;
    _historySaved = true;
    final repo = ref.read(gameHistoryRepositoryProvider);
    final winners = _winnerNames();
    repo.addGame(GameRecord(
      timestamp: DateTime.now(),
      word: widget.word,
      mode: 'normal',
      impostorsWon: widget.result == GameResult.impostorsWin,
      players: widget.assignments.map((a) => a.playerName).toList(),
      impostorNames: widget.assignments
          .where((a) => a.isImpostor)
          .map((a) => a.playerName)
          .toList(),
      winnerNames: winners,
      killedNames: widget.killedIndices
          .map((i) => widget.assignments[i].playerName)
          .toList(),
    ));

    final updated = [
      GameRecord(
        timestamp: DateTime.now(),
        word: widget.word,
        mode: 'normal',
        impostorsWon: widget.result == GameResult.impostorsWin,
        players: widget.assignments.map((a) => a.playerName).toList(),
        impostorNames: widget.assignments
            .where((a) => a.isImpostor)
            .map((a) => a.playerName)
            .toList(),
        winnerNames: winners,
        killedNames: widget.killedIndices
            .map((i) => widget.assignments[i].playerName)
            .toList(),
      ),
      ...repo.getGames(),
    ];
    final streaks = computePlayerStreaks(updated);
    final hot = winners
        .where((name) => (streaks[name]?.current ?? 0) >= 2)
        .toList(growable: false);
    if (hot.isNotEmpty && mounted) {
      hot.sort((a, b) =>
          (streaks[b]?.current ?? 0).compareTo(streaks[a]?.current ?? 0));
      final best = hot.first;
      final value = streaks[best]!.current;
      setState(() {
        _hotStreakMessage = 'Hot streak! $best is on 🔥 $value';
      });
    }
  }

  List<String> _winnerNames() {
    switch (widget.result) {
      case GameResult.innocentsWin:
        return widget.assignments
            .where((a) => !a.isImpostor)
            .map((a) => a.playerName)
            .toList();
      case GameResult.impostorsWin:
        return widget.assignments
            .where((a) => a.isImpostor)
            .map((a) => a.playerName)
            .toList();
      case GameResult.blankRound:
        return const [];
    }
  }

  void _quickRematch() {
    final lanState = ref.read(lanSessionProvider);
    final isLanHosting = lanState.isHost && lanState.phase != LanPhase.idle;
    // Read from the live LAN roster when hosting, not the pre-lobby players
    // provider — players can be added/removed from the Host Lobby screen
    // after hosting starts.
    final allPlayers =
        isLanHosting ? lanState.players : ref.read(playersProvider).players;
    final setup = ref.read(gameSetupProvider);
    final themesState = ref.read(themesProvider).valueOrNull;
    if (themesState == null) return;

    final enabledThemes = setup.selectedThemes;
    if (enabledThemes.isEmpty) return;

    final random = Random();

    // Check for "j999" trigger.
    final hasJ999 = allPlayers.any((p) => p == 'j999');
    final players = hasJ999
        ? allPlayers.where((p) => p != 'j999').toList()
        : List<String>.from(allPlayers);

    if (players.length < 3) return;

    final isBlankRound = hasJ999 || random.nextInt(12) == 0;

    final theme = enabledThemes[random.nextInt(enabledThemes.length)];
    final language = setup.language;
    final englishWords = themesState.getEnglishWords(theme);
    if (englishWords.isEmpty) return;

    final wordPicker = ref.read(wordPickerServiceProvider);
    final wordIndex = wordPicker.pickWordIndex(
      theme: theme,
      wordCount: englishWords.length,
      random: random,
    );

    final translatedWords = themesState.getWords(theme, language);
    final word = wordIndex < translatedWords.length
        ? translatedWords[wordIndex]
        : englishWords[wordIndex];
    final impostorHintWord = pickImpostorHintWord(
      themeWords: translatedWords.isNotEmpty ? translatedWords : englishWords,
      secretWord: word,
      random: random,
    );

    List<RoleAssignment> assignments;
    if (isBlankRound) {
      assignments = players
          .map((name) => RoleAssignment(
                playerName: name,
                isImpostor: true,
              ))
          .toList();
    } else {
      const roleService = RoleAssignmentService();
      assignments = roleService.assignRoles(
        players: players,
        impostorCount: setup.impostorCount,
        word: word,
        random: random,
      );
    }

    if (isLanHosting) {
      _lanQuickRematch(
        allAssignments: assignments,
        word: word,
        theme: theme,
        impostorHintWord: impostorHintWord,
        isBlankRound: isBlankRound,
        setup: setup,
      );
      return;
    }

    // Replace the entire game stack with new role reveal.
    Navigator.of(context).pushAndRemoveUntil(
      createSlideRoute(
        RoleRevealScreen(
          assignments: assignments,
          word: word,
          themeName: theme,
          hintsEnabled: setup.hintsEnabled,
          themeVisibilityMode: setup.themeVisibilityMode,
          impostorHintWord: impostorHintWord,
          timerSeconds: setup.timerEnabled ? setup.timerMinutes * 60 : 0,
          isBlankRound: isBlankRound,
          reducedMotion: setup.reducedMotion,
          suddenDeathEnabled: setup.suddenDeathEnabled,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  /// Returns to the Host Lobby screen without starting a new round —
  /// lets the host change themes/settings, add or remove players, and
  /// let more guests join, while everyone currently connected stays in
  /// the lobby with the identity they already picked.
  void _backToLobbySettings() {
    final lanState = ref.read(lanSessionProvider);
    final modeName = lanState.session?.mode;
    final mode = GameMode.values
        .firstWhere((m) => m.name == modeName, orElse: () => GameMode.normal);
    ref.read(lanSessionProvider.notifier).returnToLobby();
    Navigator.of(context).pushAndRemoveUntil(
      createSlideRoute(HostLobbyScreen(mode: mode)),
      (route) => route.isFirst,
    );
  }

  /// Rematch while LAN-hosting: redistributes the new round through the
  /// still-live LAN session instead of abandoning it. Connected devices
  /// keep the player identity they already picked, so guests just see a
  /// fresh reveal for the same player round after round — no re-joining,
  /// no re-picking — until they disconnect or the host ends the session.
  void _lanQuickRematch({
    required List<RoleAssignment> allAssignments,
    required String word,
    required String theme,
    required String? impostorHintWord,
    required bool isBlankRound,
    required GameSetupState setup,
  }) {
    final lanNotifier = ref.read(lanSessionProvider.notifier);
    final hostBucket = lanNotifier.distributeAssignments(
      allAssignments: allAssignments
          .map((a) => {
                'playerName': a.playerName,
                'isImpostor': a.isImpostor,
                'word': a.word,
              })
          .toList(),
      word: word,
      themeName: theme,
      hintsEnabled: setup.hintsEnabled,
      themeVisibilityMode: setup.themeVisibilityMode.index,
      impostorHintWord: impostorHintWord,
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
    Widget checkPlayersScreen(BuildContext ctx) => LanReadyCheckScreen(
          assignments: allAssignments,
          word: word,
          timerSeconds: timerSeconds,
          isBlankRound: isBlankRound,
          reducedMotion: setup.reducedMotion,
          suddenDeathEnabled: setup.suddenDeathEnabled,
        );

    final nextScreen = hostAssignments.isEmpty
        ? checkPlayersScreen(context)
        : RoleRevealScreen(
            assignments: hostAssignments,
            votingAssignments: allAssignments,
            word: word,
            themeName: theme,
            hintsEnabled: setup.hintsEnabled,
            themeVisibilityMode: setup.themeVisibilityMode,
            impostorHintWord: impostorHintWord,
            timerSeconds: timerSeconds,
            isBlankRound: isBlankRound,
            reducedMotion: setup.reducedMotion,
            suddenDeathEnabled: setup.suddenDeathEnabled,
            onComplete: checkPlayersScreen,
            completeButtonLabel: 'Check Players',
          );

    // The LAN session lives in lanSessionProvider, not on the nav stack, so
    // it's safe to unwind HostLobbyScreen the same way the solo path does —
    // the session keeps running in the background and the next rematch can
    // still drive it directly. It only stops when endSession() is called
    // (see "Back to Home" below) or a device disconnects on its own.
    Navigator.of(context).pushAndRemoveUntil(
      createSlideRoute(nextScreen),
      (route) => route.isFirst,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBlankRound = widget.result == GameResult.blankRound;
    final isImpostorWin = widget.result == GameResult.impostorsWin;
    final lanState = ref.watch(lanSessionProvider);
    final isLanHosting = lanState.isHost && lanState.phase != LanPhase.idle;

    final resultColor = isBlankRound
        ? Colors.amber.shade400
        : isImpostorWin
            ? Colors.red.shade400
            : Colors.green.shade400;
    final impostors = widget.assignments.where((a) => a.isImpostor).toList();
    final innocents = widget.assignments.where((a) => !a.isImpostor).toList();

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerLowest,
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Confetti celebration overlay
                Positioned.fill(
                  child: widget.reducedMotion
                      ? const SizedBox.shrink()
                      : ConfettiBurst(
                          particleCount: 80,
                          colors: isBlankRound
                              ? [Colors.amber, Colors.orange, Colors.yellow]
                              : isImpostorWin
                                  ? [
                                      Colors.red,
                                      Colors.deepOrange,
                                      Colors.pink,
                                    ]
                                  : [
                                      Colors.green,
                                      Colors.teal,
                                      Colors.lightGreen,
                                      Colors.blue,
                                    ],
                          duration: const Duration(milliseconds: 3000),
                        ),
                ),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeIn.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideUp.value),
                        child: child,
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // Result icon
                        DramaticEntrance(
                          delay: widget.reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          child: GlowRing(
                            color: resultColor,
                            size: 140,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: resultColor.withAlpha(30),
                              ),
                              child: Icon(
                                isBlankRound
                                    ? Icons.psychology_alt
                                    : isImpostorWin
                                        ? Icons.warning_amber_rounded
                                        : Icons.emoji_events_rounded,
                                size: 72,
                                color: resultColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Winner text
                        widget.reducedMotion
                            ? Text(
                                isBlankRound
                                    ? 'Blank Round!'
                                    : isImpostorWin
                                        ? 'Impostors Win!'
                                        : 'Innocents Win!',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: resultColor,
                                    ),
                              )
                            : ShimmerText(
                                text: isBlankRound
                                    ? 'Blank Round!'
                                    : isImpostorWin
                                        ? 'Impostors Win!'
                                        : 'Innocents Win!',
                                shimmerColor: resultColor.withAlpha(128),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: resultColor,
                                    ),
                              ),
                        const SizedBox(height: 8),
                        if (_hotStreakMessage != null) ...[
                          Text(
                            _hotStreakMessage!,
                            style: TextStyle(
                              color: Colors.orange.shade300,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          isBlankRound
                              ? 'Nobody had the word — everyone was the impostor!'
                              : isImpostorWin
                                  ? 'The impostors managed to survive!'
                                  : 'All impostors have been found!',
                          style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(170),
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // The word
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: colorScheme.surfaceContainerHigh,
                            border: Border.all(
                              color: colorScheme.primary.withAlpha(60),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'The Secret Word',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withAlpha(150),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.word,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Word voting ---
                        _WordVoteRow(
                          vote: _vote,
                          onLike: () {
                            if (_vote != null) return;
                            setState(() => _vote = true);
                            ref
                                .read(wordVoteRepositoryProvider)
                                .likeWord(widget.word);
                          },
                          onDislike: () {
                            if (_vote != null) return;
                            setState(() => _vote = false);
                            ref
                                .read(wordVoteRepositoryProvider)
                                .dislikeWord(widget.word);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Impostors / All Players section
                        _RoleSection(
                          title: isBlankRound ? 'All Players' : 'Impostors',
                          icon: isBlankRound
                              ? Icons.psychology_alt
                              : Icons.warning_amber_rounded,
                          color: isBlankRound
                              ? Colors.amber.shade400
                              : Colors.red.shade400,
                          players: impostors,
                          killedIndices: widget.killedIndices,
                          assignments: widget.assignments,
                        ),
                        if (innocents.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          // Innocents section
                          _RoleSection(
                            title: 'Innocents',
                            icon: Icons.shield_rounded,
                            color: Colors.green.shade400,
                            players: innocents,
                            killedIndices: widget.killedIndices,
                            assignments: widget.assignments,
                          ),
                        ],
                        const SizedBox(height: 40),

                        // Quick rematch button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: () => _quickRematch(),
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Play Again',
                                style: TextStyle(fontSize: 18)),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Back to lobby / settings button (LAN hosting only)
                        if (isLanHosting) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: () => _backToLobbySettings(),
                              icon: const Icon(Icons.settings_backup_restore_rounded),
                              label: const Text('Back to Lobby / Settings',
                                  style: TextStyle(fontSize: 16)),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Back to setup button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final lanState = ref.read(lanSessionProvider);
                              if (lanState.isHost &&
                                  lanState.phase != LanPhase.idle) {
                                // HostLobbyScreen may no longer be on the
                                // stack after a rematch, so its PopScope
                                // won't fire — end the session explicitly
                                // rather than leaving guests connected to
                                // an orphaned lobby.
                                ref
                                    .read(lanSessionProvider.notifier)
                                    .endSession();
                              }
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            },
                            icon: const Icon(Icons.home_rounded),
                            label: const Text('Back to Home',
                                style: TextStyle(fontSize: 16)),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section showing players of a specific role
// ---------------------------------------------------------------------------
class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.players,
    required this.killedIndices,
    required this.assignments,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<RoleAssignment> players;
  final List<int> killedIndices;
  final List<RoleAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withAlpha(15),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...players.map((p) {
            final globalIndex = assignments.indexOf(p);
            final wasKilled = killedIndices.contains(globalIndex);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    wasKilled
                        ? Icons.close_rounded
                        : Icons.check_circle_outline,
                    size: 18,
                    color:
                        wasKilled ? colorScheme.error : Colors.green.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.playerName,
                      style: TextStyle(
                        fontSize: 14,
                        decoration:
                            wasKilled ? TextDecoration.lineThrough : null,
                        color: wasKilled
                            ? colorScheme.onSurface.withAlpha(100)
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (wasKilled)
                    Text(
                      'Eliminated',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.error.withAlpha(180),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Word vote row — like / dislike the secret word
// ---------------------------------------------------------------------------
class _WordVoteRow extends StatelessWidget {
  const _WordVoteRow({
    required this.vote,
    required this.onLike,
    required this.onDislike,
  });

  /// null = not voted, true = liked, false = disliked.
  final bool? vote;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasVoted = vote != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerHigh,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hasVoted ? 'Thanks for voting!' : 'Rate this word',
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha(hasVoted ? 120 : 180),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),

          // Like
          _VoteButton(
            icon: Icons.thumb_up_rounded,
            active: vote == true,
            enabled: !hasVoted,
            color: Colors.green,
            onPressed: onLike,
          ),
          const SizedBox(width: 12),

          // Dislike
          _VoteButton(
            icon: Icons.thumb_down_rounded,
            active: vote == false,
            enabled: !hasVoted,
            color: Colors.red,
            onPressed: onDislike,
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.active,
    required this.enabled,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final bool active;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          icon,
          color: active
              ? color
              : enabled
                  ? Theme.of(context).colorScheme.onSurface.withAlpha(120)
                  : Theme.of(context).colorScheme.onSurface.withAlpha(40),
        ),
        style: IconButton.styleFrom(
          backgroundColor: active ? color.withAlpha(30) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
