import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:impostor/core/animated_effects.dart';
import 'package:impostor/core/feedback_service.dart';
import 'package:impostor/features/game_setup/feedback_provider.dart';
import 'package:impostor/core/motion.dart';
import 'package:impostor/core/reveal_palette.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/role_reveal/role_reveal_state.dart';
import 'package:impostor/features/voting/voting_screen.dart';

/// Screen that manages the sequential role-reveal flow.
///
/// Receives pre-computed [RoleAssignment]s and the secret [word],
/// then steps through them one player at a time.
class RoleRevealScreen extends ConsumerStatefulWidget {
  const RoleRevealScreen({
    super.key,
    required this.assignments,
    required this.word,
    required this.themeName,
    this.timerSeconds = 0,
    this.isBlankRound = false,
    this.hintsEnabled = false,
    this.themeVisibilityMode = ThemeVisibilityMode.innocentsOnly,
    this.impostorHintWord,
    this.reducedMotion = false,
    this.suddenDeathEnabled = true,
    this.startingPlayerName,
    this.wordKey,
    this.holdToReveal = false,
    this.votingAssignments,
    this.onComplete,
    this.completeButtonLabel = 'Start Voting',
  });

  final List<RoleAssignment> assignments;
  final String word;
  final String themeName;

  /// The full player roster to vote over once reveals are done.
  ///
  /// Defaults to [assignments]. LAN hosting needs to pass the complete
  /// roster here separately, since [assignments] on the host device may
  /// only be the subset of players nobody else claimed.
  final List<RoleAssignment>? votingAssignments;

  /// Builds the screen to navigate to once all reveals are done, replacing
  /// the default (go straight to [VotingScreen]).
  ///
  /// LAN hosting uses this to route through a "Check Players" screen first
  /// instead of jumping straight to voting.
  final Widget Function(BuildContext context)? onComplete;

  /// Label for the button shown once all reveals are done.
  final String completeButtonLabel;

  /// Discussion timer in seconds (0 = disabled).
  final int timerSeconds;

  /// Whether this is a blank round (nobody has the word).
  final bool isBlankRound;

  /// Whether the impostor hint should be shown.
  final bool hintsEnabled;

  /// Controls who can see the current round's theme during role reveal.
  final ThemeVisibilityMode themeVisibilityMode;

  /// One related single-word hint shown only to impostors.
  final String? impostorHintWord;

  /// Whether high-intensity animations should be reduced.
  final bool reducedMotion;

  /// Whether sudden death mode is enabled.
  final bool suddenDeathEnabled;

  /// Who opens the discussion, decided when the round was built.
  final String? startingPlayerName;

  /// Identity of [word] for post-round difficulty rating.
  final WordKey? wordKey;

  /// Show roles only while the player presses and holds, instead of after a
  /// single tap — nothing stays on screen for a passer-by to glance at.
  final bool holdToReveal;

  @override
  ConsumerState<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends ConsumerState<RoleRevealScreen>
    with TickerProviderStateMixin {
  late RoleRevealState _state;

  static const _secureChannel = MethodChannel('com.impostor.impostor/secure');
  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  // Animations
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeIn;
  late AnimationController _revealCtrl;
  late Animation<double> _revealScale;
  int _shakeTrigger = 0;

  @override
  void initState() {
    super.initState();
    _state = RoleRevealState(
      currentIndex: 0,
      totalPlayers: widget.assignments.length,
      phase: RevealPhase.hidden,
    );
    _setSecureFlag(true);
    _initAnimations();
    _fadeCtrl.forward();
  }

  bool _shouldShowTheme(bool isImpostor) {
    switch (widget.themeVisibilityMode) {
      case ThemeVisibilityMode.off:
        return false;
      case ThemeVisibilityMode.innocentsOnly:
        return !isImpostor;
      case ThemeVisibilityMode.everyone:
        return true;
    }
  }

  void _initAnimations() {
    _fadeCtrl = AnimationController(
      duration: AppMotion.resolveDuration(
        AppMotion.setupEnter,
        reduced: widget.reducedMotion,
      ),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeCtrl,
      curve: AppMotion.resolveCurve(AppMotion.calmCurve,
          reduced: widget.reducedMotion),
    );

    _revealCtrl = AnimationController(
      duration: AppMotion.resolveDuration(
        AppMotion.revealEnter,
        reduced: widget.reducedMotion,
      ),
      vsync: this,
    );
    _revealScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealCtrl,
        curve: AppMotion.resolveCurve(
          AppMotion.dramaticCurve,
          reduced: widget.reducedMotion,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _setSecureFlag(false);
    _fadeCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  Future<void> _setSecureFlag(bool secure) async {
    try {
      await _secureChannel.invokeMethod(
        secure ? 'enableSecure' : 'disableSecure',
      );
    } on MissingPluginException {
      // Not available in tests.
    }
  }

  void _revealRole() {
    final assignment = widget.assignments[_state.currentIndex];
    _feedback.roleReveal();
    setState(() {
      _state = _state.copyWith(phase: RevealPhase.revealed);
      if (assignment.isImpostor) _shakeTrigger++;
    });
    _revealCtrl.forward(from: 0);
  }

  /// Hold-to-peek: whether the current player has looked at least once.
  bool _hasPeeked = false;

  void _startPeek() {
    if (!_hasPeeked) _feedback.roleReveal();
    setState(() {
      _hasPeeked = true;
      _state = _state.copyWith(phase: RevealPhase.revealed);
    });
  }

  void _endPeek() {
    if (_state.phase == RevealPhase.hidden) return;
    setState(() => _state = _state.copyWith(phase: RevealPhase.hidden));
  }

  void _nextPlayer() {
    _hasPeeked = false;
    final nextIndex = _state.currentIndex + 1;
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      if (nextIndex >= _state.totalPlayers) {
        setState(() {
          _state = _state.copyWith(isComplete: true);
        });
      } else {
        setState(() {
          _state = RoleRevealState(
            currentIndex: nextIndex,
            totalPlayers: _state.totalPlayers,
            phase: RevealPhase.hidden,
          );
        });
      }
      _fadeCtrl.forward();
    });
  }

  void _exitGame() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Game?'),
        content: const Text('All progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _goToVoting() {
    final onComplete = widget.onComplete;
    final votingAssignments = widget.votingAssignments ?? widget.assignments;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            onComplete != null
                ? onComplete(context)
                : VotingScreen(
                    assignments: votingAssignments,
                    word: widget.word,
                    timerSeconds: widget.timerSeconds,
                    isBlankRound: widget.isBlankRound,
                    reducedMotion: widget.reducedMotion,
                    suddenDeathEnabled: widget.suddenDeathEnabled,
                    startingPlayerName: widget.startingPlayerName,
                    wordKey: widget.wordKey,
                    impostorHintWord: widget.impostorHintWord,
                  ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOut);
          return FadeTransition(opacity: curved, child: child);
        },
        transitionDuration: AppMotion.resolveDuration(
          AppMotion.setupEnter,
          reduced: widget.reducedMotion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerLowest,
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Exit button (top-left)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Exit Game',
                    onPressed: _exitGame,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withAlpha(180),
                    ),
                  ),
                ),
                // Main content
                FadeTransition(
                  opacity: _fadeIn,
                  child: _state.isComplete
                      ? _buildComplete(context)
                      : widget.holdToReveal
                          ? _buildHoldToPeek(context)
                          : _state.phase == RevealPhase.hidden
                              ? _buildHidden(context)
                              : _buildRevealed(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHidden(BuildContext context) {
    final assignment = widget.assignments[_state.currentIndex];
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (_state.currentIndex + 1) / _state.totalPlayers;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress indicator
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                  Center(
                    child: Text(
                      '${_state.currentIndex + 1}/${_state.totalPlayers}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Player name
            Text(
              assignment.playerName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Hidden icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHighest.withAlpha(120),
              ),
              child: Icon(Icons.visibility_off_rounded,
                  size: 56, color: colorScheme.onSurface.withAlpha(100)),
            ),
            const SizedBox(height: 24),
            Text(
              'Tap below to see your role privately',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withAlpha(150),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _revealRole,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Reveal My Role',
                    style: TextStyle(fontSize: 18)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hold-to-peek layout: the role is visible only while a finger is down.
  ///
  /// The [Listener] stays in the tree for both the prompt and the role so the
  /// release is always delivered, and the pass button sits outside it so
  /// pressing it can't trigger a peek.
  Widget _buildHoldToPeek(BuildContext context) {
    final assignment = widget.assignments[_state.currentIndex];
    final colorScheme = Theme.of(context).colorScheme;
    final peeking = _state.phase == RevealPhase.revealed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
      child: Column(
        children: [
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _startPeek(),
              onPointerUp: (_) => _endPeek(),
              onPointerCancel: (_) => _endPeek(),
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: peeking
                      ? _revealedContent(
                          context,
                          assignment,
                          assignment.isImpostor,
                          colorScheme,
                          RevealPalette.accent,
                          showNextButton: false,
                        )
                      : _PeekPrompt(
                          playerName: assignment.playerName,
                          hasPeeked: _hasPeeked,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _nextPlayerButton(onPressed: _hasPeeked ? _nextPlayer : null),
        ],
      ),
    );
  }

  Widget _buildRevealed(BuildContext context) {
    final assignment = widget.assignments[_state.currentIndex];
    final isImpostor = assignment.isImpostor;
    final colorScheme = Theme.of(context).colorScheme;

    final roleColor = RevealPalette.accent;

    final content = widget.reducedMotion
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _revealedContent(
                  context, assignment, isImpostor, colorScheme, roleColor),
            ),
          )
        : ShakeEffect(
            trigger: _shakeTrigger,
            intensity: isImpostor ? 10 : 0,
            child: ScaleTransition(
              scale: _revealScale,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: _revealedContent(
                      context, assignment, isImpostor, colorScheme, roleColor),
                ),
              ),
            ),
          );

    return content;
  }

  Widget _revealedContent(
    BuildContext context,
    RoleAssignment assignment,
    bool isImpostor,
    ColorScheme colorScheme,
    Color roleColor, {
    bool showNextButton = true,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        widget.reducedMotion
            ? Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: roleColor.withAlpha(30),
                ),
                child: Icon(
                  isImpostor
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  size: 72,
                  color: roleColor,
                ),
              )
            : GlowRing(
                color: roleColor,
                size: 140,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: roleColor.withAlpha(30),
                  ),
                  child: Icon(
                    isImpostor
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    size: 72,
                    color: roleColor,
                  ),
                ),
              ),
        const SizedBox(height: 32),
        widget.reducedMotion || !isImpostor
            ? Text(
                isImpostor ? 'You are the Impostor!' : 'The word is:',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              )
            : ShimmerText(
                text: 'You are the Impostor!',
                shimmerColor: RevealPalette.shimmer,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
        if (!isImpostor) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.surfaceContainerHigh,
              border: Border.all(
                color: RevealPalette.accent.withAlpha(60),
                width: 2,
              ),
            ),
            child: widget.reducedMotion
                ? Text(
                    assignment.word!,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: RevealPalette.accentSoft,
                        ),
                  )
                : ShimmerText(
                    text: assignment.word!,
                    shimmerColor: RevealPalette.shimmer,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: RevealPalette.accentSoft,
                        ),
                  ),
          ),
        ],
        if (_shouldShowTheme(isImpostor)) ...[
          const SizedBox(height: 10),
          Text(
            'Theme: ${widget.themeName}',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withAlpha(165),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (isImpostor &&
            widget.hintsEnabled &&
            (widget.impostorHintWord ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.surfaceContainerHighest.withAlpha(90),
              border: Border.all(
                color: colorScheme.outline.withAlpha(90),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  size: 18,
                  color: Colors.amber.shade300,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hint: ${widget.impostorHintWord!.trim()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withAlpha(190),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showNextButton) ...[
          const SizedBox(height: 48),
          _nextPlayerButton(onPressed: _nextPlayer),
        ],
      ],
    );
  }

  /// "Pass to Next Player" / "All Roles Revealed". Disabled when
  /// [onPressed] is null.
  Widget _nextPlayerButton({required VoidCallback? onPressed}) {
    final isLast = _state.currentIndex >= _state.totalPlayers - 1;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          isLast ? Icons.done_all_rounded : Icons.arrow_forward_rounded,
        ),
        label: Text(
          isLast ? 'All Roles Revealed' : 'Pass to Next Player',
          style: const TextStyle(fontSize: 18),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildComplete(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer.withAlpha(60),
              ),
              child: Icon(Icons.groups_rounded,
                  size: 72, color: colorScheme.primary),
            ),
            const SizedBox(height: 32),
            Text(
              'All roles revealed!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Start the discussion.\n'
              'After each round, vote to eliminate a suspect.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withAlpha(150),
                height: 1.6,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _goToVoting,
                icon: const Icon(Icons.how_to_vote_rounded),
                label: Text(widget.completeButtonLabel,
                    style: const TextStyle(fontSize: 18)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prompt shown in hold-to-peek mode while no finger is down.
class _PeekPrompt extends StatelessWidget {
  const _PeekPrompt({required this.playerName, required this.hasPeeked});

  final String playerName;
  final bool hasPeeked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          playerName,
          style: Theme.of(context)
              .textTheme
              .headlineLarge
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primaryContainer.withAlpha(90),
          ),
          child: Icon(Icons.fingerprint_rounded,
              size: 72, color: colorScheme.primary),
        ),
        const SizedBox(height: 24),
        Text(
          hasPeeked
              ? 'Hold again to look again,\nor pass the phone on'
              : 'Press and hold here\nto peek at your role',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorScheme.onSurface.withAlpha(160),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
