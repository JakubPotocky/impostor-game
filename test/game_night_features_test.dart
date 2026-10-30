import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:impostor/core/achievements.dart';
import 'package:impostor/core/discussion_prompts.dart';
import 'package:impostor/core/player_avatar.dart';
import 'package:impostor/core/player_profile.dart';
import 'package:impostor/core/role_assignment_service.dart';
import 'package:impostor/core/screen_awake.dart';
import 'package:impostor/core/word_difficulty.dart';
import 'package:impostor/core/word_picker_service.dart';
import 'package:impostor/data/game_history_repository.dart';
import 'package:impostor/data/roster_repository.dart';
import 'package:impostor/data/settings_repository.dart';
import 'package:impostor/data/theme_word.dart';
import 'package:impostor/features/end/session_notifier.dart';
import 'package:impostor/features/game_setup/game_setup_state.dart';
import 'package:impostor/features/game_setup/round_factory.dart';
import 'package:impostor/features/game_setup/round_preset.dart';
import 'package:impostor/features/game_setup/theme_selection.dart';
import 'package:impostor/features/themes/themes_state.dart';

final _themes = ThemesState(isLoading: false, themes: {
  'Animals': {
    'en': const [
      ThemeWord('Lion', hint: 'Mane'),
      ThemeWord('Tiger', hint: 'Stripes'),
      ThemeWord('Otter', hint: 'River'),
    ],
  },
  'Kinky': {
    'en': const [ThemeWord('Mask')],
  },
  'Team Pairs': {
    'en': const [ThemeWord('Cat|Dog')],
  },
});

GameRound _round({
  bool undercover = false,
  bool mystery = false,
  int impostors = 1,
  List<String> players = const ['A', 'B', 'C', 'D', 'E', 'F'],
  int seed = 1,
}) {
  final result = const RoundFactory().build(
    players: players,
    enabledThemes: const ['Animals'],
    impostorCount: impostors,
    language: 'en',
    allowedDifficulties: GameSetupState.allDifficulties,
    themes: _themes,
    difficulties: const WordDifficultyMap(),
    wordPicker: WordPickerService(),
    random: Random(seed),
    undercover: undercover,
    mysteryImpostorCount: mystery,
  );
  return (result as RoundReady).round;
}

GameRecord _game({
  required List<String> players,
  required List<String> impostors,
  required bool impostorsWon,
  DateTime? at,
  String mode = 'normal',
  RoundEndReason endReason = RoundEndReason.normalVoteResolution,
  List<String> killed = const [],
  String? starter,
}) {
  final winners = impostorsWon
      ? impostors
      : players.where((p) => !impostors.contains(p)).toList();
  return GameRecord(
    timestamp: at ?? DateTime(2026, 10, 30, 20),
    word: 'Lion',
    mode: mode,
    impostorsWon: impostorsWon,
    players: players,
    impostorNames: impostors,
    winnerNames: winners,
    killedNames: killed,
    endReason: endReason,
    startingPlayerName: starter,
  );
}

void main() {
  group('Undercover rounds', () {
    test('impostors keep their role but are shown a decoy as their word', () {
      for (var seed = 0; seed < 20; seed++) {
        final round = _round(undercover: true, seed: seed);
        expect(round.isBlankRound, isFalse,
            reason: 'blank rounds make no sense when nobody knows their role');
        expect(round.isUndercover, isTrue);
        for (var i = 0; i < round.assignments.length; i++) {
          final real = round.assignments[i];
          final shown = round.revealAssignments[i];
          expect(shown.playerName, real.playerName);
          expect(shown.isImpostor, isFalse, reason: 'nobody sees "impostor"');
          if (real.isImpostor) {
            expect(real.decoyWord, isNotNull);
            expect(real.decoyWord, isNot(round.word));
            expect(shown.word, real.decoyWord);
          } else {
            expect(shown.word, round.word);
          }
        }
      }
    });

    test('normal rounds show the real roles', () {
      final round = _round(seed: 3);
      expect(round.isUndercover, isFalse);
      expect(round.revealAssignments.map((a) => a.isImpostor),
          round.assignments.map((a) => a.isImpostor));
    });
  });

  test('mystery impostor count varies between 1 and the maximum', () {
    final counts = {
      for (var seed = 0; seed < 60; seed++)
        _round(mystery: true, impostors: 3, seed: seed)
            .assignments
            .where((a) => a.isImpostor)
            .length,
    }..remove(6); // blank rounds (everyone) aren't part of this rule
    expect(counts, {1, 2, 3});
  });

  test('family mode hides mature themes; Team Pairs is never selectable', () {
    expect(selectableThemes(_themes, const GameSetupState()),
        ['Animals', 'Kinky']);
    expect(selectableThemes(_themes, const GameSetupState(familyMode: true)),
        ['Animals']);
  });

  test('presets remember the game variants', () {
    const state = GameSetupState(
        undercoverMode: true, mysteryImpostors: true, lastChanceGuess: true);
    final preset =
        RoundPreset.fromJson(RoundPreset.fromState('Wild', state).toJson());
    expect(preset.matches(state), isTrue);
    expect(preset.matches(const GameSetupState()), isFalse);
  });

  group('Player avatars', () {
    test('defaults are stable for a name, regardless of case and spaces', () {
      expect(PlayerAvatars.defaultEmoji('Alice'),
          PlayerAvatars.defaultEmoji(' alice '));
      expect(PlayerAvatars.colorFor('Alice'), PlayerAvatars.colorFor('ALICE'));
      expect(PlayerAvatars.emojis, contains(PlayerAvatars.defaultEmoji('Bo')));
    });

    test('different names spread across the set', () {
      final emojis = {
        for (final n in ['Ann', 'Ben', 'Cid', 'Dee', 'Eve', 'Fay', 'Gus'])
          PlayerAvatars.defaultEmoji(n),
      };
      expect(emojis.length, greaterThan(3));
    });
  });

  test('discussion prompts never repeat back to back', () {
    final random = Random(9);
    var previous = DiscussionPrompts.next(random);
    for (var i = 0; i < 100; i++) {
      final next = DiscussionPrompts.next(random, previous: previous);
      expect(next, isNot(previous));
      previous = next;
    }
  });

  group('Tonight\'s standings', () {
    final start = DateTime(2026, 10, 30, 18);
    final games = [
      _game(
          players: ['A', 'B', 'C'],
          impostors: ['A'],
          impostorsWon: true,
          at: DateTime(2026, 10, 30, 19)),
      _game(
          players: ['A', 'B', 'C'],
          impostors: ['B'],
          impostorsWon: false,
          at: DateTime(2026, 10, 30, 20)),
      // Before the session started: ignored.
      _game(
          players: ['A', 'B', 'C'],
          impostors: ['C'],
          impostorsWon: true,
          at: DateTime(2026, 10, 29)),
    ];

    test('impostor wins score double, older games are ignored', () {
      final table = SessionScoring.standings(games, since: start);
      expect(table.map((s) => s.name), ['A', 'C', 'B']);
      expect(table.map((s) => s.points), [3, 1, 0]);
      expect(table.first.games, 2);
    });

    test('players level on points share a rank', () {
      SessionStanding s(String name, int points) =>
          SessionStanding(name)..points = points;
      expect(
        SessionScoring.ranks([s('A', 3), s('B', 1), s('C', 1), s('D', 0)]),
        [1, 2, 2, 4],
      );
      expect(SessionScoring.ranks(const []), isEmpty);
    });
  });

  group('PlayerProfile', () {
    test('splits results by role and tracks form', () {
      final games = [
        _game(
            players: ['A', 'B', 'C'],
            impostors: ['A'],
            impostorsWon: true,
            starter: 'A',
            at: DateTime(2026, 10, 30, 22)),
        _game(
            players: ['A', 'B', 'C'],
            impostors: ['A'],
            impostorsWon: false,
            killed: ['A'],
            at: DateTime(2026, 10, 30, 21)),
        _game(
            players: ['A', 'B', 'C'],
            impostors: ['B'],
            impostorsWon: false,
            at: DateTime(2026, 10, 30, 20)),
      ];
      final p = PlayerProfile.compute('A', games);
      expect(p.games, 3);
      expect(p.impostorGames, 2);
      expect(p.impostorWinRate, 0.5);
      expect(p.innocentWinRate, 1.0);
      expect(p.timesEliminated, 1);
      expect(p.timesStarted, 1);
      expect(p.recentForm, [true, false, true]);
    });

    test('rates are unknown, not zero, without games', () {
      final p = PlayerProfile.compute('Nobody', const []);
      expect(p.winRate, isNull);
      expect(p.recentForm, isEmpty);
    });
  });

  group('New achievements', () {
    bool unlocked(String id, String player, List<GameRecord> history) =>
        achievementCatalog
            .firstWhere((a) => a.id == id)
            .isUnlockedFor(player, history);

    test('Undercover Agent needs an impostor win in undercover mode', () {
      final win = _game(
          players: ['A', 'B', 'C'],
          impostors: ['A'],
          impostorsWon: true,
          mode: 'undercover');
      expect(unlocked('undercover_agent', 'A', [win]), isTrue);
      expect(unlocked('undercover_agent', 'B', [win]), isFalse);
    });

    test('Last Word needs an impostor win by guessing the word', () {
      final guess = _game(
          players: ['A', 'B', 'C'],
          impostors: ['A'],
          impostorsWon: true,
          endReason: RoundEndReason.impostorGuessedWord);
      expect(unlocked('last_word', 'A', [guess]), isTrue);
    });

    test('Marathon needs 10 games on the same day', () {
      List<GameRecord> day(int n, int dayOfMonth) => [
            for (var i = 0; i < n; i++)
              _game(
                  players: ['A', 'B', 'C'],
                  impostors: ['B'],
                  impostorsWon: true,
                  at: DateTime(2026, 10, dayOfMonth, 10, i)),
          ];
      expect(unlocked('marathon', 'A', day(10, 30)), isTrue);
      expect(unlocked('marathon', 'A', [...day(5, 29), ...day(5, 30)]),
          isFalse);
    });
  });

  group('ScreenAwake', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <String>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.impostor.impostor/secure'),
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
    });

    test('stays on across a screen handover and turns off at the end', () {
      ScreenAwake.acquire(); // reveal screen
      ScreenAwake.acquire(); // voting screen starts before reveal is disposed
      ScreenAwake.release(); // reveal disposed
      expect(calls, ['keepScreenOn']);
      ScreenAwake.release(); // voting disposed
      expect(calls, ['keepScreenOn', 'allowScreenOff']);
      expect(ScreenAwake.holderCount, 0);
      ScreenAwake.release(); // extra release is harmless
      expect(ScreenAwake.holderCount, 0);
    });
  });

  group('Storage', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('game_night_test');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('appearance migrates from the old dark-mode switch', () async {
      final repo = SettingsRepository();
      await repo.init();
      expect(repo.getThemeMode(), ThemeMode.system);

      await repo.backupBox.put('darkMode', false);
      expect(repo.getThemeMode(), ThemeMode.light);

      await repo.saveThemeMode(ThemeMode.dark);
      expect(repo.getThemeMode(), ThemeMode.dark);
    });

    test('player groups save, replace by name, and delete', () async {
      final repo = RosterRepository();
      await repo.init();
      await repo.saveGroup(const PlayerGroup(name: 'Family', players: ['A']));
      await repo.saveGroup(const PlayerGroup(name: 'Work', players: ['B']));
      await repo
          .saveGroup(const PlayerGroup(name: 'Family', players: ['A', 'C']));
      expect(repo.getGroups().map((g) => g.name), ['Family', 'Work']);
      expect(repo.getGroups().first.players, ['A', 'C']);

      await repo.deleteGroup('Work');
      expect(repo.getGroups().map((g) => g.name), ['Family']);
    });
  });
}
