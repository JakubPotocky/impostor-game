import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/core/validators.dart';

void main() {
  group('Validators', () {
    group('validatePlayerName', () {
      test('rejects empty name', () {
        expect(Validators.validatePlayerName(''), isNotNull);
        expect(Validators.validatePlayerName('   '), isNotNull);
      });

      test('accepts valid name', () {
        expect(Validators.validatePlayerName('Alice'), isNull);
      });

      test('rejects name exceeding max length', () {
        final longName = 'A' * 21;
        expect(Validators.validatePlayerName(longName), isNotNull);
      });

      test('accepts name at max length', () {
        final maxName = 'A' * 20;
        expect(Validators.validatePlayerName(maxName), isNull);
      });
    });

    group('hasEnoughPlayers', () {
      test('returns false for fewer than 3 players', () {
        expect(Validators.hasEnoughPlayers(0), false);
        expect(Validators.hasEnoughPlayers(1), false);
        expect(Validators.hasEnoughPlayers(2), false);
      });

      test('returns true for 3 or more players', () {
        expect(Validators.hasEnoughPlayers(3), true);
        expect(Validators.hasEnoughPlayers(10), true);
      });
    });

    group('isValidImpostorCount', () {
      test('rejects 0 impostors', () {
        expect(Validators.isValidImpostorCount(0, 5), false);
      });

      test('rejects impostors >= player count', () {
        expect(Validators.isValidImpostorCount(5, 5), false);
        expect(Validators.isValidImpostorCount(6, 5), false);
      });

      test('accepts valid impostor count', () {
        expect(Validators.isValidImpostorCount(1, 3), true);
        expect(Validators.isValidImpostorCount(2, 5), true);
        expect(Validators.isValidImpostorCount(4, 5), true);
      });
    });

    group('makeUnique', () {
      test('returns name unchanged if unique', () {
        expect(Validators.makeUnique('Alice', ['Bob', 'Charlie']), 'Alice');
      });

      test('appends suffix for duplicate', () {
        expect(Validators.makeUnique('Alice', ['Alice']), 'Alice 2');
      });

      test('increments suffix for multiple duplicates', () {
        expect(
          Validators.makeUnique('Alice', ['Alice', 'Alice 2']),
          'Alice 3',
        );
      });
    });
  });
}
