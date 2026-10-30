import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/core/reveal_palette.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/features/role_reveal/role_reveal_screen.dart';
import 'package:impostor/features/voting/voting_screen.dart';

import 'helpers/test_app.dart';

const _everyoneImpostor = [
  RoleAssignment(playerName: 'Alice', isImpostor: true),
  RoleAssignment(playerName: 'Bob', isImpostor: true),
  RoleAssignment(playerName: 'Charlie', isImpostor: true),
];

const _mixed = [
  RoleAssignment(playerName: 'Alice', isImpostor: true),
  RoleAssignment(playerName: 'Bob', isImpostor: false, word: 'Lion'),
  RoleAssignment(playerName: 'Charlie', isImpostor: false, word: 'Lion'),
];

Widget _app(Widget home) => testApp(home);

Future<void> _settle(WidgetTester tester) => pumpFrames(tester);

void main() {
  testWidgets('all-impostor round reaches voting with a starter announced',
      (tester) async {
    await tester.pumpWidget(_app(const RoleRevealScreen(
      assignments: _everyoneImpostor,
      word: 'Lion',
      themeName: 'Animals',
      isBlankRound: true,
      reducedMotion: true,
      startingPlayerName: 'Bob',
    )));
    await _settle(tester);

    for (var i = 0; i < _everyoneImpostor.length; i++) {
      await tester.tap(find.text('Reveal My Role'));
      await _settle(tester);
      await tester.tap(find.byType(OutlinedButton));
      await _settle(tester);
    }

    await tester.tap(find.text('Start Voting'));
    await _settle(tester);

    expect(find.textContaining('Bob goes first'), findsOneWidget);
    expect(find.textContaining('Then: Charlie → Alice'), findsOneWidget);
  });

  testWidgets('impostor reveal uses the same accent as innocents',
      (tester) async {
    await tester.pumpWidget(_app(const RoleRevealScreen(
      assignments: _mixed,
      word: 'Lion',
      themeName: 'Animals',
      reducedMotion: true,
      startingPlayerName: 'Bob',
    )));
    await _settle(tester);

    await tester.tap(find.text('Reveal My Role'));
    await _settle(tester);

    final title = tester.widget<Text>(find.text('You are the Impostor!'));
    expect(title.style?.color, RevealPalette.accent);
    final icon =
        tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded));
    expect(icon.color, RevealPalette.accent);
  });

  testWidgets('hold to peek shows the role only while pressed',
      (tester) async {
    await tester.pumpWidget(_app(const RoleRevealScreen(
      assignments: _mixed,
      word: 'Lion',
      themeName: 'Animals',
      reducedMotion: true,
      holdToReveal: true,
      startingPlayerName: 'Bob',
    )));
    await _settle(tester);

    Finder passButton() => find.widgetWithText(
        OutlinedButton, 'Pass to Next Player');
    OutlinedButton button() => tester.widget<OutlinedButton>(passButton());

    expect(find.text('You are the Impostor!'), findsNothing);
    expect(button().onPressed, isNull, reason: 'must peek before passing');

    final gesture =
        await tester.startGesture(tester.getCenter(find.byIcon(Icons.fingerprint_rounded)));
    await _settle(tester);
    expect(find.text('You are the Impostor!'), findsOneWidget);

    await gesture.up();
    await _settle(tester);
    expect(find.text('You are the Impostor!'), findsNothing);
    expect(button().onPressed, isNotNull);

    await tester.tap(passButton());
    await _settle(tester);
    expect(find.text('Bob'), findsOneWidget);
    expect(button().onPressed, isNull, reason: 'next player starts fresh');
  });

  test('speaking order starts at the starter and wraps around', () {
    expect(speakingOrder(['A', 'B', 'C', 'D'], starter: 'C'),
        ['C', 'D', 'A', 'B']);
    expect(speakingOrder(['A', 'B'], starter: 'Z'), ['Z']);
  });
}
