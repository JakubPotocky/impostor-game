import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/core/feedback_service.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/players/players_notifier.dart';
import 'package:impostor/features/pre_game/pre_game_screen.dart';
import 'package:impostor/features/themes/themes_notifier.dart';

/// Team mode: 2 teams with 2 different (similar) words and 1 impostor.
/// Players figure out who has which word and form teams.
/// The team with the impostor at the end loses.
class TeamModeScreen extends ConsumerStatefulWidget {
  const TeamModeScreen({super.key});

  @override
  ConsumerState<TeamModeScreen> createState() => _TeamModeScreenState();
}

class _TeamModeScreenState extends ConsumerState<TeamModeScreen>
    with TickerProviderStateMixin {
  List<_TeamAssignment>? _assignments;
  String? _wordA;
  String? _wordB;

  // Role reveal state
  int _currentIndex = 0;
  bool _revealed = false;
  bool _allRevealed = false;

  // Team sorting phase
  bool _inSortingPhase = false;
  final Map<int, int> _teamAssignments = {}; // playerIndex -> team (0 or 1)

  static const _feedback = FeedbackService();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeIn;
  late AnimationController _revealCtrl;
  late Animation<double> _revealScale;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _revealScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _revealCtrl, curve: Curves.elasticOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _setupGame());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  void _setupGame() {
    final players = ref.read(playersProvider).players;
    final setup = ref.read(gameSetupProvider);
    final themesState = ref.read(themesProvider).valueOrNull;
    if (themesState == null || players.length < 3) return;

    final random = Random();
    final language = setup.language;

    // Get team pair words.
    final teamPairWords = themesState.getWords('Team Pairs', language);
    final englishTeamPairs = themesState.getEnglishWords('Team Pairs');

    if (teamPairWords.isEmpty && englishTeamPairs.isEmpty) return;

    final wordPicker = ref.read(wordPickerServiceProvider);
    final idx = wordPicker.pickWordIndex(
      theme: 'Team Pairs',
      wordCount: englishTeamPairs.length,
      random: random,
    );

    final pair =
        idx < teamPairWords.length ? teamPairWords[idx] : englishTeamPairs[idx];

    final parts = pair.split('|');
    if (parts.length != 2) return;

    final wordA = parts[0].trim();
    final wordB = parts[1].trim();

    // Pick 1 impostor.
    final impostorIndex = random.nextInt(players.length);

    // Assign remaining players roughly evenly to wordA / wordB.
    final nonImpostorIndices = <int>[
      for (var i = 0; i < players.length; i++)
        if (i != impostorIndex) i,
    ]..shuffle(random);

    final halfCount = nonImpostorIndices.length ~/ 2;

    final assignments = List.generate(players.length, (i) {
      if (i == impostorIndex) {
        return _TeamAssignment(
          playerName: players[i],
          isImpostor: true,
          word: null,
          team: -1,
        );
      }
      final posInNonImpostor = nonImpostorIndices.indexOf(i);
      final isTeamA = posInNonImpostor < halfCount;
      return _TeamAssignment(
        playerName: players[i],
        isImpostor: false,
        word: isTeamA ? wordA : wordB,
        team: isTeamA ? 0 : 1,
      );
    });

    setState(() {
      _assignments = assignments;
      _wordA = wordA;
      _wordB = wordB;
    });
    _fadeCtrl.forward();
  }

  void _revealRole() {
    if (_assignments == null) return;
    final a = _assignments![_currentIndex];
    _feedback.roleReveal(isImpostor: a.isImpostor);
    setState(() => _revealed = true);
    _revealCtrl.forward(from: 0);
  }

  void _nextPlayer() {
    final next = _currentIndex + 1;
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      if (next >= _assignments!.length) {
        setState(() => _allRevealed = true);
      } else {
        setState(() {
          _currentIndex = next;
          _revealed = false;
        });
      }
      _fadeCtrl.forward();
    });
  }

  void _startSorting() {
    setState(() => _inSortingPhase = true);
  }

  void _assignToTeam(int playerIndex, int team) {
    setState(() {
      _teamAssignments[playerIndex] = team;
    });
  }

  void _finishGame() {
    if (_assignments == null) return;

    // Find which team the impostor ended up on.
    final impostorIdx = _assignments!.indexWhere((a) => a.isImpostor);
    final impostorTeam = _teamAssignments[impostorIdx] ?? 0;

    _feedback.victory();

    // Show result.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final losingTeam = impostorTeam == 0 ? _wordA! : _wordB!;
        final winningTeam = impostorTeam == 0 ? _wordB! : _wordA!;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: Colors.amber.shade400, size: 28),
              const SizedBox(width: 10),
              const Text('Game Over!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The impostor was ${_assignments![impostorIdx].playerName}!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'They ended up on Team "$losingTeam"',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green.withAlpha(20),
                  border: Border.all(color: Colors.green.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_rounded,
                        color: Colors.green.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Team "$winningTeam" wins!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.withAlpha(20),
                  border: Border.all(color: Colors.red.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sentiment_dissatisfied,
                        color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Team "$losingTeam" loses!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _assignments = null;
                  _wordA = null;
                  _wordB = null;
                  _currentIndex = 0;
                  _revealed = false;
                  _allRevealed = false;
                  _inSortingPhase = false;
                  _teamAssignments.clear();
                });
                _setupGame();
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Play Again'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Back to Home'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_assignments == null) {
      final players = ref.watch(playersProvider).players;
      final hasEnoughPlayers = players.length >= 3;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Team Mode'),
          centerTitle: true,
        ),
        body: Center(
          child: hasEnoughPlayers
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.groups_rounded,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(80)),
                      const SizedBox(height: 24),
                      Text(
                        'Not enough players',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need at least 3 players for Team Mode.\n'
                        'Go to Play first to add players.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    if (_inSortingPhase) {
      return _buildSortingPhase(context);
    }

    if (_allRevealed) {
      return _buildAllRevealed(context);
    }

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
            child: FadeTransition(
              opacity: _fadeIn,
              child:
                  _revealed ? _buildRevealed(context) : _buildHidden(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHidden(BuildContext context) {
    final a = _assignments![_currentIndex];
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (_currentIndex + 1) / _assignments!.length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                      '${_currentIndex + 1}/${_assignments!.length}',
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'TEAM MODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: Colors.purple,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              a.playerName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
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
              'Tap below to see your word',
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
                label: const Text('Reveal My Word',
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

  Widget _buildRevealed(BuildContext context) {
    final a = _assignments![_currentIndex];
    final isImpostor = a.isImpostor;
    final colorScheme = Theme.of(context).colorScheme;
    final roleColor = isImpostor ? Colors.red.shade400 : Colors.blue.shade400;

    return ScaleTransition(
      scale: _revealScale,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: roleColor.withAlpha(30),
                  boxShadow: [
                    BoxShadow(
                      color: roleColor.withAlpha(40),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  isImpostor
                      ? Icons.warning_amber_rounded
                      : Icons.groups_rounded,
                  size: 72,
                  color: roleColor,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isImpostor ? 'You are the Impostor!' : 'Your team word:',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              if (!isImpostor) ...[
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: colorScheme.surfaceContainerHigh,
                    border: Border.all(
                      color: Colors.blue.withAlpha(60),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    a.word!,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade300,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Find your teammates through discussion!',
                  style: TextStyle(
                    color: colorScheme.onSurface.withAlpha(130),
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  'Blend in with a team.\nDon\'t get caught!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade200.withAlpha(180),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 64),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _nextPlayer,
                  icon: Icon(
                    _currentIndex < _assignments!.length - 1
                        ? Icons.arrow_forward_rounded
                        : Icons.done_all_rounded,
                  ),
                  label: Text(
                    _currentIndex < _assignments!.length - 1
                        ? 'Pass to Next Player'
                        : 'All Words Revealed',
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
          ),
        ),
      ),
    );
  }

  Widget _buildAllRevealed(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
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
          child: FadeTransition(
            opacity: _fadeIn,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.purple.withAlpha(30),
                      ),
                      child: const Icon(Icons.groups_rounded,
                          size: 72, color: Colors.purple),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'All words revealed!',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Discuss and figure out who has the same word as you.\n'
                      'The impostor will try to blend in!',
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
                        onPressed: _startSorting,
                        icon: const Icon(Icons.group_work_rounded),
                        label: const Text('Sort Into Teams',
                            style: TextStyle(fontSize: 18)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortingPhase(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allAssigned = _teamAssignments.length == _assignments!.length;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sort Into Teams'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.blue.withAlpha(20),
                        border: Border.all(color: Colors.blue.withAlpha(80)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.group, color: Colors.blue.shade300),
                          const SizedBox(height: 4),
                          Text(
                            'Team A',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.orange.withAlpha(20),
                        border: Border.all(color: Colors.orange.withAlpha(80)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.group, color: Colors.orange.shade300),
                          const SizedBox(height: 4),
                          Text(
                            'Team B',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _assignments!.length,
                itemBuilder: (context, i) {
                  final a = _assignments![i];
                  final team = _teamAssignments[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: team == 0
                            ? Colors.blue.withAlpha(40)
                            : team == 1
                                ? Colors.orange.withAlpha(40)
                                : colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          color: team == 0
                              ? Colors.blue.shade300
                              : team == 1
                                  ? Colors.orange.shade300
                                  : colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        a.playerName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('A')),
                          ButtonSegment(value: 1, label: Text('B')),
                        ],
                        selected: team != null ? {team} : {},
                        emptySelectionAllowed: true,
                        onSelectionChanged: (sel) {
                          if (sel.isNotEmpty) {
                            _assignToTeam(i, sel.first);
                          }
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: allAssigned ? _finishGame : null,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    allAssigned ? 'Reveal Results' : 'Assign all players first',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

class _TeamAssignment {
  const _TeamAssignment({
    required this.playerName,
    required this.isImpostor,
    this.word,
    required this.team,
  });

  final String playerName;
  final bool isImpostor;
  final String? word;
  final int team; // 0 = A, 1 = B, -1 = impostor
}
