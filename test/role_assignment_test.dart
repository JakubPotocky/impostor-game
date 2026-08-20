import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/core/role_assignment_service.dart';

void main() {
  const service = RoleAssignmentService();

  group('RoleAssignmentService', () {
    test('assigns correct number of impostors', () {
      final random = Random(42);
      final players = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'];

      final assignments = service.assignRoles(
        players: players,
        impostorCount: 2,
        word: 'Lion',
        random: random,
      );

      expect(assignments.length, 5);
      final impostors = assignments.where((a) => a.isImpostor).toList();
      expect(impostors.length, 2);
    });

    test('impostors have no word, crew members have the word', () {
      final random = Random(99);
      final players = ['Alice', 'Bob', 'Charlie'];

      final assignments = service.assignRoles(
        players: players,
        impostorCount: 1,
        word: 'Pizza',
        random: random,
      );

      for (final a in assignments) {
        if (a.isImpostor) {
          expect(a.word, isNull);
        } else {
          expect(a.word, 'Pizza');
        }
      }
    });

    test('preserves player order', () {
      final random = Random(7);
      final players = ['P1', 'P2', 'P3', 'P4'];

      final assignments = service.assignRoles(
        players: players,
        impostorCount: 1,
        word: 'Test',
        random: random,
      );

      for (var i = 0; i < players.length; i++) {
        expect(assignments[i].playerName, players[i]);
      }
    });

    test('deterministic with same seed', () {
      final players = ['A', 'B', 'C', 'D', 'E'];

      final a1 = service.assignRoles(
        players: players,
        impostorCount: 2,
        word: 'Word',
        random: Random(123),
      );

      final a2 = service.assignRoles(
        players: players,
        impostorCount: 2,
        word: 'Word',
        random: Random(123),
      );

      for (var i = 0; i < players.length; i++) {
        expect(a1[i].isImpostor, a2[i].isImpostor);
        expect(a1[i].word, a2[i].word);
      }
    });

    test('single impostor in 3 players', () {
      final random = Random(0);
      final players = ['X', 'Y', 'Z'];

      final assignments = service.assignRoles(
        players: players,
        impostorCount: 1,
        word: 'Shark',
        random: random,
      );

      expect(assignments.length, 3);
      expect(assignments.where((a) => a.isImpostor).length, 1);
      expect(assignments.where((a) => !a.isImpostor).length, 2);
    });
  });
}
