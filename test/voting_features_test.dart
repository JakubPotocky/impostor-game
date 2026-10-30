import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:impostor/core/discussion_prompts.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/data/achievement_repository.dart';
import 'package:impostor/data/game_history_repository.dart';
import 'package:impostor/data/word_difficulty_repository.dart';
import 'package:impostor/data/word_vote_repository.dart';
import 'package:impostor/features/end/session_notifier.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/voting/voting_screen.dart';

import 'helpers/test_app.dart';

const _alice = RoleAssignment(playerName: 'Alice', isImpostor: true);
const _bob = RoleAssignment(playerName: 'Bob', isImpostor: false, word: 'Lion');
const _carol =
    RoleAssignment(playerName: 'Carol', isImpostor: false, word: 'Lion');
const _dave = RoleAssignment(playerName: 'Dave', isImpostor: false, word: 'Lion');

late Directory _dir;
late GameHistoryRepository _history;
late AchievementRepository _achievements;
late WordVoteRepository _votes;
late WordDifficultyRepository _difficulty;

/// Voting screen in a harness that can also show the end screen it leads to.
Widget _voting(
  List<RoleAssignment> assignments, {
  GameSetupState setup = const GameSetupState(suddenDeathEnabled: false),
  int timerSeconds = 0,
}) {
  return testApp(
    VotingScreen(
      assignments: assignments,
      word: 'Lion',
      timerSeconds: timerSeconds,
      reducedMotion: true,
      suddenDeathEnabled: false,
      startingPlayerName: assignments.first.playerName,
    ),
    setup: setup,
    overrides: [
      gameHistoryRepositoryProvider.overrideWithValue(_history),
      achievementRepositoryProvider.overrideWithValue(_achievements),
      wordVoteRepositoryProvider.overrideWithValue(_votes),
      wordDifficultyRepositoryProvider.overrideWithValue(_difficulty),
      // Count every game in tests, whatever the clock says.
      sessionProvider.overrideWith(() => SessionNotifier(DateTime(2000))),
    ],
  );
}

Future<void> _eliminate(WidgetTester tester, String name) async {
  await tester.tap(find.bySemanticsLabel('$name, eliminate'));
  await pumpFrames(tester, count: 20);
}

void main() {
  setUpAll(() async {
    _dir = await Directory.systemTemp.createTemp('voting_features_test');
    Hive.init(_dir.path);
    _history = GameHistoryRepository();
    _achievements = AchievementRepository();
    _votes = WordVoteRepository();
    _difficulty = WordDifficultyRepository();
    await _history.init();
    await _achievements.init();
    await _votes.init();
    await _difficulty.init();
  });

  tearDownAll(() async {
    // Not Hive.deleteFromDisk(): writes started inside widget tests' fake
    // clock never complete, so closing boxes would wait forever.
    try {
      await _dir.delete(recursive: true);
    } on FileSystemException {
      // Windows keeps the open box files locked; the OS temp dir cleans up.
    }
  });

  testWidgets('player cards expose their name and action to screen readers',
      (tester) async {
    await tester.pumpWidget(_voting(const [_alice, _bob, _carol, _dave]));
    await pumpFrames(tester);

    expect(find.bySemanticsLabel('Alice, eliminate'), findsOneWidget);
    await _eliminate(tester, 'Bob');
    expect(find.bySemanticsLabel('Bob, eliminated, was innocent'),
        findsOneWidget);
  });

  testWidgets('mystery mode hides how many impostors remain', (tester) async {
    await tester.pumpWidget(_voting(
      const [_alice, _bob, _carol, _dave],
      setup: const GameSetupState(mysteryImpostors: true),
    ));
    await pumpFrames(tester);

    expect(find.textContaining('impostors left'), findsNothing);
    expect(find.text('4 alive · 0 impostors caught · ? left'), findsOneWidget);
  });

  testWidgets('without Last Chance, catching the impostor ends the game',
      (tester) async {
    await tester.pumpWidget(_voting(const [_alice, _bob, _carol]));
    await pumpFrames(tester);

    await _eliminate(tester, 'Alice');
    expect(find.text('Last Chance!'), findsNothing);
    expect(find.text('Innocents Win!'), findsOneWidget);
  });

  testWidgets('Last Chance: a right guess turns it into an impostor win',
      (tester) async {
    await tester.pumpWidget(_voting(
      const [_alice, _bob, _carol],
      setup: const GameSetupState(lastChanceGuess: true),
    ));
    await pumpFrames(tester);

    await _eliminate(tester, 'Alice');
    expect(find.text('Last Chance!'), findsOneWidget);

    await tester.tap(find.text('Guessed it!'));
    await pumpFrames(tester, count: 20);
    expect(find.text('Impostors Win!'), findsOneWidget);
    expect(find.text('Impostors won by guessing the secret word!'),
        findsOneWidget);
    // The game also counted towards tonight's standings.
    expect(find.text("Tonight's Standings"), findsOneWidget);
  });

  testWidgets('Last Chance: a wrong guess keeps the innocent win',
      (tester) async {
    await tester.pumpWidget(_voting(
      const [_alice, _bob, _carol],
      setup: const GameSetupState(lastChanceGuess: true),
    ));
    await pumpFrames(tester);

    await _eliminate(tester, 'Alice');
    await tester.tap(find.text('Wrong guess'));
    await pumpFrames(tester, count: 20);
    expect(find.text('Innocents Win!'), findsOneWidget);
  });

  testWidgets('undercover rounds reveal the decoy word at the end',
      (tester) async {
    await tester.pumpWidget(_voting(const [
      RoleAssignment(playerName: 'Alice', isImpostor: true, decoyWord: 'Tiger'),
      _bob,
      _carol,
    ]));
    await pumpFrames(tester);

    await _eliminate(tester, 'Alice');
    expect(find.textContaining("Impostors' decoy: Tiger"), findsOneWidget);
  });

  testWidgets('timer can be paused and extended', (tester) async {
    await tester.pumpWidget(_voting(
      const [_alice, _bob, _carol],
      timerSeconds: 60,
    ));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:57'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause timer'));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0:57 · paused'), findsOneWidget);

    await tester.tap(find.text('+30s'));
    await tester.pump();
    expect(find.text('1:27 · paused'), findsOneWidget);

    await tester.tap(find.byTooltip('Resume timer'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1:25'), findsOneWidget);

    // Leave the screen so the periodic timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('discussion questions can be shown, cycled and hidden',
      (tester) async {
    await tester.pumpWidget(_voting(const [_alice, _bob, _carol]));
    await pumpFrames(tester);

    await tester.tap(find.byTooltip('Discussion question'));
    await tester.pump();
    String shownPrompt() => DiscussionPrompts.all
        .firstWhere((p) => find.text(p).evaluate().isNotEmpty);
    final first = shownPrompt();

    await tester.tap(find.text('Another question'));
    await tester.pump();
    expect(shownPrompt(), isNot(first));

    await tester.tap(find.byTooltip('Hide question'));
    await tester.pump();
    expect(find.text('Another question'), findsNothing);
  });
}
