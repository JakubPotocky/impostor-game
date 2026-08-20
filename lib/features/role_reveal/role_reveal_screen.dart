import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:impostor/core/animated_effects.dart';
import 'package:impostor/core/feedback_service.dart';
import 'package:impostor/core/motion.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/features/role_reveal/role_reveal_state.dart';
import 'package:impostor/features/voting/voting_screen.dart';

/// Screen that manages the sequential role-reveal flow.
///
/// Receives pre-computed [RoleAssignment]s and the secret [word],
/// then steps through them one player at a time.
class RoleRevealScreen extends StatefulWidget {
  const RoleRevealScreen({
    super.key,
    required this.assignments,
    required this.word,
    required this.themeName,
    this.timerSeconds = 0,
    this.isBlankRound = false,
    this.hintsEnabled = false,
    this.reducedMotion = false,
    this.suddenDeathEnabled = true,
  });

  final List<RoleAssignment> assignments;
  final String word;
  final String themeName;

  /// Discussion timer in seconds (0 = disabled).
  final int timerSeconds;

  /// Whether this is a blank round (nobody has the word).
  final bool isBlankRound;

  /// Whether hints should be shown for non-impostor players.
  final bool hintsEnabled;

  /// Whether high-intensity animations should be reduced.
  final bool reducedMotion;

  /// Whether sudden death mode is enabled.
  final bool suddenDeathEnabled;

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen>
    with TickerProviderStateMixin {
  late RoleRevealState _state;

  static const _secureChannel = MethodChannel('com.impostor.impostor/secure');
  static const _feedback = FeedbackService();

  // Animations
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeIn;
  late AnimationController _revealCtrl;
  late Animation<double> _revealScale;
  int _shakeTrigger = 0;
  bool _privacyClosed = false;

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
    _feedback.roleReveal(isImpostor: assignment.isImpostor);
    setState(() {
      _state = _state.copyWith(phase: RevealPhase.revealed);
      _privacyClosed = false;
      if (assignment.isImpostor) _shakeTrigger++;
    });
    _revealCtrl.forward(from: 0);
  }

  void _nextPlayer() {
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
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => VotingScreen(
          assignments: widget.assignments,
          word: widget.word,
          timerSeconds: widget.timerSeconds,
          isBlankRound: widget.isBlankRound,
          reducedMotion: widget.reducedMotion,
          suddenDeathEnabled: widget.suddenDeathEnabled,
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

  String _buildHint(String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return 'Hint: category is ${widget.themeName}';
    final first = String.fromCharCode(trimmed.runes.first);
    final last = String.fromCharCode(trimmed.runes.last);
    final length = trimmed.runes.length;
    final words =
        trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    if (words > 1) {
      return 'Hint: category is ${widget.themeName}. $words words, starts with "$first".';
    }
    return 'Hint: category is ${widget.themeName}. $length letters, starts with "$first" and ends with "$last".';
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

            _CurtainRevealCard(
              reducedMotion: widget.reducedMotion,
              onReveal: _revealRole,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevealed(BuildContext context) {
    final assignment = widget.assignments[_state.currentIndex];
    final isImpostor = assignment.isImpostor;
    final colorScheme = Theme.of(context).colorScheme;

    final roleColor = isImpostor ? Colors.red.shade400 : Colors.green.shade400;

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
    Color roleColor,
  ) {
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
                shimmerColor: Colors.red.shade200,
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
                color: Colors.green.withAlpha(60),
                width: 2,
              ),
            ),
            child: widget.reducedMotion
                ? Text(
                    assignment.word!,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade300,
                        ),
                  )
                : ShimmerText(
                    text: assignment.word!,
                    shimmerColor: Colors.green.shade200,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade300,
                        ),
                  ),
          ),
          if (widget.hintsEnabled) ...[
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
                      _buildHint(assignment.word!),
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
        ],
        const SizedBox(height: 48),
        if (!_privacyClosed)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: () => setState(() => _privacyClosed = true),
              icon: const Icon(Icons.visibility_off_rounded),
              label: const Text('Close Curtain'),
            ),
          )
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.surfaceContainerHighest,
            ),
            child: const Text(
              'Curtain closed. Pass the phone to the next player.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _nextPlayer,
              icon: Icon(
                _state.currentIndex < _state.totalPlayers - 1
                    ? Icons.arrow_forward_rounded
                    : Icons.done_all_rounded,
              ),
              label: Text(
                _state.currentIndex < _state.totalPlayers - 1
                    ? 'Pass to Next Player'
                    : 'All Roles Revealed',
                style: const TextStyle(fontSize: 18),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ],
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
                label:
                    const Text('Start Voting', style: TextStyle(fontSize: 18)),
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

class _CurtainRevealCard extends StatefulWidget {
  const _CurtainRevealCard({
    required this.onReveal,
    required this.reducedMotion,
  });

  final VoidCallback onReveal;
  final bool reducedMotion;

  @override
  State<_CurtainRevealCard> createState() => _CurtainRevealCardState();
}

class _CurtainRevealCardState extends State<_CurtainRevealCard> {
  double _progress = 0;
  bool _triggered = false;

  void _update(double delta, double height) {
    if (_triggered) return;
    final next = (_progress + (delta / height)).clamp(0.0, 1.0);
    setState(() => _progress = next);
    if (next >= 0.9) {
      _triggered = true;
      widget.onReveal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onVerticalDragUpdate: (details) {
            _update(-details.delta.dy, constraints.maxHeight.clamp(220, 360));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: colorScheme.surfaceContainerHigh,
              border: Border.all(color: colorScheme.outline.withAlpha(80)),
            ),
            child: Column(
              children: [
                Text(
                  'Identity Curtain',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 160,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.lock_person_rounded,
                            size: 50,
                            color: colorScheme.onSurface.withAlpha(100),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: (1 - _progress) * 0.5 * constraints.maxWidth,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF8B1E3F), Color(0xFF5A122A)],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: (1 - _progress) * 0.5 * constraints.maxWidth,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF8B1E3F), Color(0xFF5A122A)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.reducedMotion
                      ? 'Tap reveal to continue'
                      : 'Swipe up to open the curtain',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.reducedMotion)
                  FilledButton.icon(
                    onPressed: widget.onReveal,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Reveal My Role'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
