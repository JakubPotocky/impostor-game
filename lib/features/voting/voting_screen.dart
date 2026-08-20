import 'dart:math';

import 'package:flutter/material.dart';
import 'package:impostor/core/feedback_service.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/features/end/end_screen.dart';

/// Screen where players vote to eliminate suspects.
///
/// Displays all players as tappable squares. Tapping a player "kills" them
/// with an animation that reveals whether they were an impostor or innocent.
class VotingScreen extends StatefulWidget {
  const VotingScreen({
    super.key,
    required this.assignments,
    required this.word,
    this.timerSeconds = 0,
    this.isBlankRound = false,
    this.suddenDeathEnabled = true,
  });

  final List<RoleAssignment> assignments;
  final String word;

  /// Discussion timer in seconds (0 = disabled).
  final int timerSeconds;

  /// Whether this is a blank round (nobody has the word).
  final bool isBlankRound;

  /// Whether sudden death mode is enabled.
  final bool suddenDeathEnabled;

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen>
    with TickerProviderStateMixin {
  /// Set of indices already eliminated.
  final Set<int> _killed = {};

  /// Ordered kill history for undo.
  final List<int> _killHistory = [];

  /// Controls the flip animation for the most recently killed player.
  final Map<int, AnimationController> _flipControllers = {};

  static const _feedback = FeedbackService();

  /// Timer state (only used if timerSeconds > 0).
  late int _remainingSeconds;
  bool _timerRunning = false;

  /// Sudden death state.
  bool _suddenDeathActive = false;
  bool _suddenDeathAnimating = false;
  late AnimationController _suddenDeathCtrl;
  late Animation<double> _suddenDeathScale;
  late Animation<double> _suddenDeathOpacity;
  late AnimationController _suddenDeathPulseCtrl;
  late Animation<double> _suddenDeathPulse;

  /// Precomputed threshold (computed once when game state allows).
  int? _suddenDeathThreshold;

  /// Random for sudden death threshold.
  final _random = Random();

  /// Tracks whether game is navigating to end.
  bool _gameEnding = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timerSeconds;
    if (widget.timerSeconds > 0) {
      _startTimer();
    }

    // Sudden death animation controllers.
    _suddenDeathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _suddenDeathScale = Tween(begin: 3.0, end: 1.0).animate(
      CurvedAnimation(parent: _suddenDeathCtrl, curve: Curves.elasticOut),
    );
    _suddenDeathOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _suddenDeathCtrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _suddenDeathPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _suddenDeathPulse = Tween(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _suddenDeathPulseCtrl, curve: Curves.easeInOut),
    );

    // Precompute the sudden death threshold based on initial impostor count.
    if (!widget.isBlankRound && widget.suddenDeathEnabled) {
      final totalImpostors =
          widget.assignments.where((a) => a.isImpostor).length;
      _suddenDeathThreshold = _computeSuddenDeathThreshold(totalImpostors);
    }
  }

  void _startTimer() {
    _timerRunning = true;
    _tick();
  }

  void _tick() {
    if (!mounted || !_timerRunning) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_timerRunning) return;
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        _timerRunning = false;
        _feedback.click();
      } else {
        _tick();
      }
    });
  }

  @override
  void dispose() {
    _timerRunning = false;
    for (final ctrl in _flipControllers.values) {
      ctrl.dispose();
    }
    _suddenDeathCtrl.dispose();
    _suddenDeathPulseCtrl.dispose();
    super.dispose();
  }

  /// Compute the sudden death threshold.
  /// threshold = impostorsAlive * 2 + rand(1,2)
  /// +2 has lower chance if more than 1 impostor alive.
  int _computeSuddenDeathThreshold(int aliveImpostors) {
    int bonus;
    if (aliveImpostors > 1) {
      // With multiple impostors, 80% chance of +1, 20% chance of +2.
      bonus = _random.nextInt(5) < 4 ? 1 : 2;
    } else {
      // With 1 impostor, 50/50.
      bonus = _random.nextBool() ? 1 : 2;
    }
    return aliveImpostors * 2 + bonus;
  }

  /// Check if sudden death should activate (called after every non-terminal kill).
  void _checkSuddenDeath() {
    if (_suddenDeathActive || widget.isBlankRound) return;
    if (_suddenDeathThreshold == null) return;

    final aliveCount = widget.assignments.length - _killed.length;
    final aliveImpostors = widget.assignments
        .asMap()
        .entries
        .where((e) => !_killed.contains(e.key) && e.value.isImpostor)
        .length;

    // Recompute threshold if an impostor was killed (changes the formula).
    final threshold =
        aliveImpostors < widget.assignments.where((a) => a.isImpostor).length
            ? _computeSuddenDeathThreshold(aliveImpostors)
            : _suddenDeathThreshold!;

    if (aliveCount <= threshold) {
      _activateSuddenDeath();
    }
  }

  void _activateSuddenDeath() {
    _feedback.voteKill(); // dramatic haptic
    setState(() {
      _suddenDeathActive = true;
      _suddenDeathAnimating = true;
    });

    _suddenDeathCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      // Start pulsing border after entrance animation.
      _suddenDeathPulseCtrl.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        setState(() {
          _suddenDeathAnimating = false;
        });
      });
    });
  }

  /// Check win conditions after a kill.
  GameResult? _checkWinCondition() {
    // Blank round: end after the first kill.
    if (widget.isBlankRound) {
      return GameResult.blankRound;
    }

    final alive = <RoleAssignment>[];
    for (var i = 0; i < widget.assignments.length; i++) {
      if (!_killed.contains(i)) {
        alive.add(widget.assignments[i]);
      }
    }

    final aliveImpostors = alive.where((a) => a.isImpostor).length;
    final aliveInnocents = alive.where((a) => !a.isImpostor).length;

    // All impostors eliminated → innocents win.
    if (aliveImpostors == 0) {
      return GameResult.innocentsWin;
    }

    // Impostors >= innocents → impostors win.
    if (aliveImpostors >= aliveInnocents) {
      return GameResult.impostorsWin;
    }

    // Sudden death: if an innocent was just killed, impostors win immediately.
    if (_suddenDeathActive && _killHistory.isNotEmpty) {
      final lastKilled = _killHistory.last;
      if (!widget.assignments[lastKilled].isImpostor) {
        return GameResult.impostorsWin;
      }
    }

    return null;
  }

  void _killPlayer(int index) {
    if (_killed.contains(index) || _gameEnding || _suddenDeathAnimating) return;

    _feedback.voteKill();

    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipControllers[index] = ctrl;

    setState(() {
      _killed.add(index);
      _killHistory.add(index);
    });

    ctrl.forward().then((_) {
      if (!mounted) return;
      final result = _checkWinCondition();
      if (result != null) {
        _gameEnding = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  EndScreen(
                assignments: widget.assignments,
                word: widget.word,
                result: result,
                killedIndices: _killed.toList(),
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity:
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        });
      } else {
        _checkSuddenDeath();
      }
    });
  }

  void _undoLastKill() {
    if (_killHistory.isEmpty || _gameEnding) return;

    final lastIndex = _killHistory.removeLast();
    _flipControllers[lastIndex]?.dispose();
    _flipControllers.remove(lastIndex);

    setState(() {
      _killed.remove(lastIndex);
    });

    _feedback.click();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final aliveCount = widget.assignments.length - _killed.length;
    final totalImpostors = widget.assignments.where((a) => a.isImpostor).length;
    final aliveImpostors = widget.assignments
        .asMap()
        .entries
        .where((e) => !_killed.contains(e.key) && e.value.isImpostor)
        .length;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // Main game UI
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _suddenDeathActive
                      ? [
                          Colors.red.shade900.withAlpha(50),
                          colorScheme.surface,
                          colorScheme.surfaceContainerLowest,
                        ]
                      : [
                          colorScheme.surface,
                          colorScheme.surfaceContainerLowest,
                        ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top bar with exit + undo + status
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Exit Game',
                            onPressed: _exitGame,
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme
                                  .surfaceContainerHighest
                                  .withAlpha(180),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Undo button
                          if (_killHistory.isNotEmpty && !_gameEnding)
                            IconButton(
                              icon: const Icon(Icons.undo_rounded),
                              tooltip: 'Undo Last Kill',
                              onPressed: _undoLastKill,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.orange.withAlpha(40),
                                foregroundColor: Colors.orange.shade300,
                              ),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.isBlankRound
                                  ? '$aliveCount alive'
                                  : '$aliveCount alive · $aliveImpostors/$totalImpostors impostors left',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sudden death banner
                    if (_suddenDeathActive && !_suddenDeathAnimating)
                      ScaleTransition(
                        scale: _suddenDeathPulse,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade900.withAlpha(200),
                                Colors.red.shade700.withAlpha(200),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.red.shade400.withAlpha(150),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.shade900.withAlpha(80),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_fire_department,
                                  color: Colors.amber.shade300, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'SUDDEN DEATH',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontSize: 16,
                                  color: Colors.amber.shade200,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.local_fire_department,
                                  color: Colors.amber.shade300, size: 22),
                            ],
                          ),
                        ),
                      ),

                    // --- Timer bar ---
                    if (widget.timerSeconds > 0) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _remainingSeconds <= 0
                                    ? 0.0
                                    : _remainingSeconds / widget.timerSeconds,
                                minHeight: 8,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(
                                  _remainingSeconds <= 30
                                      ? Colors.red.shade400
                                      : colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _remainingSeconds <= 0
                                  ? "Time's up!"
                                  : '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _remainingSeconds <= 30
                                    ? Colors.red.shade400
                                    : colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Text(
                      _suddenDeathActive
                          ? 'One Wrong Vote = Game Over'
                          : 'Vote to Eliminate',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                _suddenDeathActive ? Colors.red.shade300 : null,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _suddenDeathActive
                          ? 'Choose wisely — innocents lose on a mistake'
                          : 'Tap a player to eliminate them',
                      style: TextStyle(
                        color: _suddenDeathActive
                            ? Colors.red.shade200.withAlpha(180)
                            : colorScheme.onSurface.withAlpha(150),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Player grid
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: widget.assignments.length,
                          itemBuilder: (context, index) {
                            return _PlayerCard(
                              assignment: widget.assignments[index],
                              isKilled: _killed.contains(index),
                              flipController: _flipControllers[index],
                              onTap: () => _killPlayer(index),
                              suddenDeath: _suddenDeathActive,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sudden death fullscreen overlay animation
            if (_suddenDeathAnimating)
              AnimatedBuilder(
                animation: _suddenDeathCtrl,
                builder: (context, child) {
                  return Opacity(
                    opacity: _suddenDeathOpacity.value,
                    child: Container(
                      color: Colors.black.withAlpha(
                        (200 * (1 - _suddenDeathCtrl.value).clamp(0.0, 1.0))
                            .toInt(),
                      ),
                      child: Center(
                        child: ScaleTransition(
                          scale: _suddenDeathScale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.red.shade900.withAlpha(200),
                                      Colors.red.shade700.withAlpha(100),
                                      Colors.transparent,
                                    ],
                                    radius: 0.8,
                                  ),
                                ),
                                child: Icon(
                                  Icons.local_fire_department,
                                  size: 80,
                                  color: Colors.amber.shade300,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'SUDDEN DEATH',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.red.shade300,
                                  letterSpacing: 4,
                                  shadows: [
                                    Shadow(
                                      color: Colors.red.shade900,
                                      blurRadius: 20,
                                    ),
                                    Shadow(
                                      color: Colors.red.shade700,
                                      blurRadius: 40,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ONE WRONG VOTE AND\nINNOCENTS LOSE!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade200,
                                  letterSpacing: 2,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player card with flip animation on kill
// ---------------------------------------------------------------------------
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.assignment,
    required this.isKilled,
    this.flipController,
    required this.onTap,
    this.suddenDeath = false,
  });

  final RoleAssignment assignment;
  final bool isKilled;
  final AnimationController? flipController;
  final VoidCallback onTap;
  final bool suddenDeath;

  @override
  Widget build(BuildContext context) {
    if (isKilled && flipController != null) {
      return AnimatedBuilder(
        animation: flipController!,
        builder: (context, child) {
          final value = flipController!.value;
          final showBack = value > 0.5;
          final angle = value * 3.14159;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159),
                    child: _buildRevealed(context),
                  )
                : _buildAlive(context, enabled: false),
          );
        },
      );
    }

    return _buildAlive(context, enabled: !isKilled);
  }

  Widget _buildAlive(BuildContext context, {required bool enabled}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: suddenDeath && enabled
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.shade400.withAlpha(60),
                    width: 1,
                  ),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  assignment.playerName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevealed(BuildContext context) {
    final isImpostor = assignment.isImpostor;
    final color = isImpostor ? Colors.red.shade400 : Colors.green.shade400;
    final bgColor = isImpostor
        ? Colors.red.shade400.withAlpha(30)
        : Colors.green.shade400.withAlpha(30);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isImpostor ? Icons.warning_amber_rounded : Icons.shield_rounded,
            size: 36,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            isImpostor ? 'IMPOSTOR' : 'INNOCENT',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              color: color,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              assignment.playerName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: color.withAlpha(200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Possible game outcomes.
enum GameResult {
  innocentsWin,
  impostorsWin,
  blankRound,
}
