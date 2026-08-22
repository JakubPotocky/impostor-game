import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/core/achievements.dart';
import 'package:impostor/data/game_history_repository.dart';

GameRecord _game({
  required List<String> players,
  List<String> impostorNames = const [],
  List<String> winnerNames = const [],
  List<String> killedNames = const [],
  bool isBlankRound = false,
  DateTime? timestamp,
}) {
  return GameRecord(
    timestamp: timestamp ?? DateTime(2026, 1, 1),
    word: 'Word',
    mode: 'normal',
    impostorsWon: false,
    players: players,
    impostorNames: impostorNames,
    winnerNames: winnerNames,
    killedNames: killedNames,
    isBlankRound: isBlankRound,
  );
}

Achievement _badge(String id) =>
    achievementCatalog.firstWhere((b) => b.id == id);

void main() {
  group('achievementCatalog', () {
    test('catalog has unique, stable ids', () {
      final ids = achievementCatalog.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('First Blood unlocks on first win, not before', () {
      final badge = _badge('first_blood');
      final noWins = [
        _game(players: ['Alice'], winnerNames: []),
      ];
      final oneWin = [
        _game(players: ['Alice'], winnerNames: ['Alice']),
      ];
      expect(badge.isUnlockedFor('Alice', noWins), isFalse);
      expect(badge.isUnlockedFor('Alice', oneWin), isTrue);
    });

    test('Impostor Initiate requires winning specifically as impostor', () {
      final badge = _badge('impostor_initiate');
      final wonAsInnocent = [
        _game(
          players: ['Alice', 'Bob'],
          impostorNames: ['Bob'],
          winnerNames: ['Alice'],
        ),
      ];
      final wonAsImpostor = [
        _game(
          players: ['Alice', 'Bob'],
          impostorNames: ['Alice'],
          winnerNames: ['Alice'],
        ),
      ];
      expect(badge.isUnlockedFor('Alice', wonAsInnocent), isFalse);
      expect(badge.isUnlockedFor('Alice', wonAsImpostor), isTrue);
    });

    test('Master of Disguise requires 5 impostor wins, not 4', () {
      final badge = _badge('master_of_disguise');
      List<GameRecord> gamesWith(int impostorWins) => List.generate(
            impostorWins,
            (_) => _game(
              players: ['Alice'],
              impostorNames: ['Alice'],
              winnerNames: ['Alice'],
            ),
          );
      expect(badge.isUnlockedFor('Alice', gamesWith(4)), isFalse);
      expect(badge.isUnlockedFor('Alice', gamesWith(5)), isTrue);
    });

    test('Hot Streak and Unstoppable read the best streak, not current', () {
      // Alice: win, win, win, lose — best streak is 3 even though current is 0.
      final games = [
        _game(
            players: ['Alice'],
            winnerNames: ['Alice'],
            timestamp: DateTime(2026, 1, 1)),
        _game(
            players: ['Alice'],
            winnerNames: ['Alice'],
            timestamp: DateTime(2026, 1, 2)),
        _game(
            players: ['Alice'],
            winnerNames: ['Alice'],
            timestamp: DateTime(2026, 1, 3)),
        _game(players: ['Alice'], winnerNames: [], timestamp: DateTime(2026, 1, 4)),
      ];
      expect(_badge('hot_streak').isUnlockedFor('Alice', games), isTrue);
      expect(_badge('unstoppable').isUnlockedFor('Alice', games), isFalse);
    });

    test('Survivor counts games played without being eliminated', () {
      final badge = _badge('survivor');
      final games = List.generate(
        10,
        (_) => _game(players: ['Alice', 'Bob'], killedNames: ['Bob']),
      );
      expect(badge.isUnlockedFor('Alice', games), isTrue);
      expect(badge.isUnlockedFor('Bob', games), isFalse);
    });

    test('Blank Stare only unlocks on a blank round the player was in', () {
      final badge = _badge('blank_stare');
      final normalGame = [_game(players: ['Alice'], isBlankRound: false)];
      final blankGame = [_game(players: ['Alice'], isBlankRound: true)];
      final blankWithoutPlayer = [
        _game(players: ['Bob'], isBlankRound: true),
      ];
      expect(badge.isUnlockedFor('Alice', normalGame), isFalse);
      expect(badge.isUnlockedFor('Alice', blankGame), isTrue);
      expect(badge.isUnlockedFor('Alice', blankWithoutPlayer), isFalse);
    });

    test('Century Club requires 100 games played, not games won', () {
      final badge = _badge('century_club');
      final games99 = List.generate(99, (_) => _game(players: ['Alice']));
      final games100 = List.generate(100, (_) => _game(players: ['Alice']));
      expect(badge.isUnlockedFor('Alice', games99), isFalse);
      expect(badge.isUnlockedFor('Alice', games100), isTrue);
    });

    test('a player with no games at all unlocks nothing', () {
      for (final badge in achievementCatalog) {
        expect(badge.isUnlockedFor('Nobody', const []), isFalse,
            reason: '${badge.id} should not unlock with empty history');
      }
    });
  });
}
