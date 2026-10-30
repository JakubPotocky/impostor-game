import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/achievements.dart';
import 'package:impostor/core/animated_effects.dart';
import 'package:impostor/core/difficulty_style.dart';
import 'package:impostor/core/feedback_service.dart';
import 'package:impostor/features/game_setup/feedback_provider.dart';
import 'package:impostor/core/motion.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/core/streaks.dart';
import 'package:impostor/core/widgets.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/data/achievement_repository.dart';
import 'package:impostor/data/game_history_repository.dart';
import 'package:impostor/data/word_vote_repository.dart';
import 'package:impostor/features/end/session_notifier.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/round_factory.dart';
import 'package:impostor/features/game_setup/start_round.dart';
import 'package:impostor/features/lan_lobby/lan_round_launcher.dart';
import 'package:impostor/features/lan_lobby/lan_session_notifier.dart';
import 'package:impostor/features/lan_lobby/lan_session_state.dart';
import 'package:impostor/features/lan_lobby/screens/host_lobby_screen.dart';
import 'package:impostor/features/players/player_avatar_widget.dart';
import 'package:impostor/features/players/players_notifier.dart';
import 'package:impostor/features/players/players_screen.dart';
import 'package:impostor/features/themes/word_difficulty_notifier.dart';
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
    this.endReason = RoundEndReason.normalVoteResolution,
    this.startingPlayerName,
    this.wordKey,
    this.impostorHintWord,
  });

  final List<RoleAssignment> assignments;
  final String word;
  final GameResult result;
  final List<int> killedIndices;
  final bool reducedMotion;
  final RoundEndReason endReason;
  final String? startingPlayerName;

  /// Identity of [word] for difficulty rating; rating is hidden without it.
  final WordKey? wordKey;

  /// The clue impostors were given, revealed alongside the word.
  final String? impostorHintWord;

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
  List<_PlayerAchievement> _newlyUnlockedAchievements = [];
  List<SessionStanding> _standings = const [];
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

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
    final record = GameRecord(
      timestamp: DateTime.now(),
      word: widget.word,
      mode: _decoyWord != null ? 'undercover' : 'normal',
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
      isBlankRound: widget.result == GameResult.blankRound,
      endReason: widget.endReason,
      startingPlayerName: widget.startingPlayerName,
    );

    // Read history *before* adding: Hive updates its in-memory copy as soon
    // as put() is called, so reading afterwards would count this game twice.
    final updated = [record, ...repo.getGames()];
    repo.addGame(record);

    final standings = SessionScoring.standings(
      updated,
      since: ref.read(sessionProvider),
    );

    final streaks = computePlayerStreaks(updated);
    final hot = winners
        .where((name) => (streaks[name]?.current ?? 0) >= 2)
        .toList(growable: false);

    // Evaluate achievements for every player in this game, not just winners
    // — badges like Survivor or Blank Stare don't require winning.
    final achievementRepo = ref.read(achievementRepositoryProvider);
    final newlyUnlocked = <_PlayerAchievement>[];
    for (final assignment in widget.assignments) {
      final unlocked =
          achievementRepo.evaluateAndUnlock(assignment.playerName, updated);
      for (final u in unlocked) {
        final badge =
            achievementCatalog.firstWhere((b) => b.id == u.badgeId);
        newlyUnlocked.add(_PlayerAchievement(assignment.playerName, badge));
      }
    }

    if (!mounted) return;
    setState(() {
      if (hot.isNotEmpty) {
        hot.sort((a, b) =>
            (streaks[b]?.current ?? 0).compareTo(streaks[a]?.current ?? 0));
        final best = hot.first;
        final value = streaks[best]!.current;
        _hotStreakMessage = 'Hot streak! $best is on 🔥 $value';
      }
      _newlyUnlockedAchievements = newlyUnlocked;
      _standings = standings;
    });
  }

  /// Undercover rounds: the decoy impostors were given.
  String? get _decoyWord {
    for (final a in widget.assignments) {
      if (a.decoyWord != null) return a.decoyWord;
    }
    return null;
  }

  /// Plain-text summary for pasting into a group chat.
  String _resultSummary() {
    final headline = switch (widget.result) {
      GameResult.blankRound => 'Blank round — everyone was the impostor!',
      GameResult.impostorsWin => 'Impostors win!',
      GameResult.innocentsWin => 'Innocents win!',
    };
    final impostors = widget.assignments
        .where((a) => a.isImpostor)
        .map((a) => a.playerName)
        .join(', ');
    final eliminated =
        widget.killedIndices.map((i) => widget.assignments[i].playerName);
    return [
      '🕵️ Impostor — $headline',
      'Secret word: ${widget.word}',
      if (_decoyWord case final decoy?) 'Decoy word: $decoy',
      if (widget.result != GameResult.blankRound) 'Impostors: $impostors',
      if (eliminated.isNotEmpty) 'Voted out: ${eliminated.join(' → ')}',
      if (widget.startingPlayerName case final starter?)
        'First to speak: $starter',
    ].join('\n');
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: _resultSummary()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          const SnackBar(content: Text('Result copied — paste it anywhere')));
  }

  Future<void> _startNewSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Session?'),
        content: const Text('Tonight\'s standings start again from zero. '
            'Game history and stats are kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Start New'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(sessionProvider.notifier).startNew();
    setState(() => _standings = const []);
  }

  /// The impostors' hint, shown only if impostors actually saw one.
  String? get _revealedHint {
    final hint = widget.impostorHintWord?.trim();
    // Undercover impostors never saw a hint — they thought they had the word.
    if (hint == null || hint.isEmpty || _decoyWord != null) return null;
    final hintsEnabled =
        ref.watch(gameSetupProvider.select((s) => s.hintsEnabled));
    return hintsEnabled ? hint : null;
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

  String _impostorWinSubtitle() {
    return switch (widget.endReason) {
      RoundEndReason.impostorGuessedWord =>
        'Impostors won by guessing the secret word!',
      RoundEndReason.suddenDeath =>
        'The impostors outlasted innocents in Sudden Death!',
      _ => 'The impostors managed to survive!',
    };
  }

  void _quickRematch() {
    final lanState = ref.read(lanSessionProvider);
    final isLanHosting = lanState.isHost && lanState.phase != LanPhase.idle;
    // Read from the live LAN roster when hosting, not the pre-lobby players
    // provider — players can be added/removed from the Host Lobby screen
    // after hosting starts.
    final players =
        isLanHosting ? lanState.players : ref.read(playersProvider).players;

    final result = createRound(ref, players: players);
    final GameRound round;
    switch (result) {
      case RoundUnavailable(:final reason):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(reason)));
        return;
      case RoundReady():
        round = result.round;
    }

    final Widget nextScreen = isLanHosting
        // Redistributes the new round through the still-live LAN session
        // instead of abandoning it. Connected devices keep the player
        // identity they already picked, so guests just see a fresh reveal.
        ? launchLanRound(ref, round).hostScreen
        : localRevealScreen(ref.read(gameSetupProvider), round);

    // Replace the entire game stack with the new round. When LAN-hosting,
    // the session lives in lanSessionProvider, not on the nav stack, so it
    // keeps running; it only stops when endSession() is called (see "Back to
    // Home" below) or a device disconnects on its own.
    Navigator.of(context).pushAndRemoveUntil(
      createSlideRoute(nextScreen),
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
                        Semantics(
                          header: true,
                          liveRegion: true,
                          child: widget.reducedMotion
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
                        if (_newlyUnlockedAchievements.isNotEmpty) ...[
                          _AchievementUnlockBanner(
                            unlocked: _newlyUnlockedAchievements,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          isBlankRound
                              ? 'Nobody had the word — everyone was the impostor!'
                              : isImpostorWin
                                  ? _impostorWinSubtitle()
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
                              if (_decoyWord case final decoy?) ...[
                                const SizedBox(height: 6),
                                Text.rich(
                                  TextSpan(children: [
                                    const TextSpan(text: "Impostors' decoy: "),
                                    TextSpan(
                                      text: decoy,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ]),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurface.withAlpha(160),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              if (_revealedHint case final hint?) ...[
                                const SizedBox(height: 6),
                                Text.rich(
                                  TextSpan(children: [
                                    const TextSpan(text: "Impostors' hint: "),
                                    TextSpan(
                                      text: hint,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ]),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurface.withAlpha(160),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
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
                        // Nobody played with the word in a blank round, so
                        // there is no basis for rating it.
                        if (widget.wordKey case final wordKey?
                            when !isBlankRound) ...[
                          const SizedBox(height: 12),
                          _DifficultyRatingRow(wordKey: wordKey),
                        ],
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _copyResult,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy result'),
                        ),
                        const SizedBox(height: 16),

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
                        if (_standings.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _SessionStandingsCard(
                            standings: _standings,
                            onNewSession: _startNewSession,
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
                  PlayerAvatar(name: p.playerName, size: 26),
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

// ---------------------------------------------------------------------------
// Achievement unlock celebration
// ---------------------------------------------------------------------------
class _PlayerAchievement {
  const _PlayerAchievement(this.playerName, this.achievement);
  final String playerName;
  final Achievement achievement;
}

class _AchievementUnlockBanner extends StatelessWidget {
  const _AchievementUnlockBanner({required this.unlocked});
  final List<_PlayerAchievement> unlocked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.amber.withAlpha(30),
        border: Border.all(color: Colors.amber.shade400.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: unlocked.map((u) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(u.achievement.icon, size: 18, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                      children: [
                        const TextSpan(
                            text: '🏆 Achievement Unlocked: ',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(
                          text: '${u.achievement.title} — ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: u.playerName),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Difficulty rating — the host rates how hard the word was to play
// ---------------------------------------------------------------------------
class _DifficultyRatingRow extends ConsumerWidget {
  const _DifficultyRatingRow({required this.wordKey});

  final WordKey wordKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final current = ref.watch(wordDifficultyProvider).of(wordKey);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerHigh,
      ),
      child: Column(
        children: [
          Text(
            current == WordDifficulty.unset
                ? 'How hard was this word?'
                : 'Word difficulty: ${current.label}',
            style: TextStyle(
              color: colorScheme.onSurface.withAlpha(180),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<WordDifficulty>(
            segments: [
              for (final d in WordDifficulty.ratable)
                ButtonSegment(
                  value: d,
                  label: Text(d.label),
                  icon: Icon(d.icon, color: d.color),
                ),
            ],
            selected: {
              if (current != WordDifficulty.unset) current,
            },
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              // Tapping the selected rating again clears it back to unset.
              ref.read(wordDifficultyProvider.notifier).setDifficulty(
                    wordKey,
                    selection.isEmpty ? WordDifficulty.unset : selection.first,
                  );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tonight's standings — scores for games since the session started
// ---------------------------------------------------------------------------
class _SessionStandingsCard extends StatelessWidget {
  const _SessionStandingsCard({
    required this.standings,
    required this.onNewSession,
  });

  final List<SessionStanding> standings;
  final VoidCallback onNewSession;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ranks = SessionScoring.ranks(standings);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard_rounded,
                  size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Tonight's Standings",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onNewSession,
                child: const Text('New session'),
              ),
            ],
          ),
          Text(
            'Impostor win ${SessionScoring.impostorWinPoints} pts · '
            'innocent win ${SessionScoring.innocentWinPoints} pt',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withAlpha(140),
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, s) in standings.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      // Medals only for players who actually scored.
                      ranks[i] <= _medals.length && s.points > 0
                          ? _medals[ranks[i] - 1]
                          : '${ranks[i]}.',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  PlayerAvatar(name: s.name, size: 26),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.name)),
                  Text(
                    '${s.wins}/${s.games} won',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${s.points} pt${s.points == 1 ? '' : 's'}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
