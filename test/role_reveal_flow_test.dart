import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/core/reveal_palette.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/features/role_reveal/role_reveal_screen.dart';

const _everyoneImpostor = [
  RoleAssignment(playerName: 'Alice', isImpostor: true),
  RoleAssignment(playerName: 'Bob', isImpostor: true),
  RoleAssignment(playerName: 'Charlie', isImpostor: true),
];

Widget _app(Widget home) => MaterialApp(home: home);

Future<void> _settle(WidgetTester tester) async {
  // Reveal screens have looping effects, so pump fixed frames instead of
  // pumpAndSettle.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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

    expect(find.text('Bob'), findsWidgets);
    expect(find.textContaining('goes first'), findsOneWidget);
  });

  testWidgets('impostor reveal uses the same accent as innocents',
      (tester) async {
    await tester.pumpWidget(_app(const RoleRevealScreen(
      assignments: [
        RoleAssignment(playerName: 'Alice', isImpostor: true),
        RoleAssignment(playerName: 'Bob', isImpostor: false, word: 'Lion'),
        RoleAssignment(playerName: 'Charlie', isImpostor: false, word: 'Lion'),
      ],
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
}
