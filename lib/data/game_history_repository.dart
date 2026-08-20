import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Provider for [GameHistoryRepository].
final gameHistoryRepositoryProvider = Provider<GameHistoryRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Repository that persists game history using Hive.
class GameHistoryRepository {
  static const String _boxName = 'game_history';
  static const String _keyGames = 'games';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(
        _box != null && _box!.isOpen, 'GameHistoryRepository not initialised');
    return _box!;
  }

  /// Returns all stored game records, newest first.
  List<GameRecord> getGames() {
    final raw = _safeBox.get(_keyGames) as String?;
    if (raw == null || raw.isEmpty) return [];
    final decoded = json.decode(raw) as List<dynamic>;
    return decoded
        .map((e) => GameRecord.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Adds a game record.
  Future<void> addGame(GameRecord record) async {
    final games = getGames();
    games.insert(0, record);
    final encoded = json.encode(games.map((g) => g.toJson()).toList());
    await _safeBox.put(_keyGames, encoded);
  }

  /// Clears all history.
  Future<void> clearHistory() async {
    await _safeBox.put(_keyGames, '[]');
  }
}

/// A single game's historical record.
class GameRecord {
  const GameRecord({
    required this.timestamp,
    required this.word,
    required this.impostorsWon,
    required this.players,
    required this.impostorNames,
    required this.killedNames,
  });

  final DateTime timestamp;
  final String word;
  final bool impostorsWon;
  final List<String> players;
  final List<String> impostorNames;
  final List<String> killedNames;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'word': word,
        'impostorsWon': impostorsWon,
        'players': players,
        'impostorNames': impostorNames,
        'killedNames': killedNames,
      };

  factory GameRecord.fromJson(Map<String, dynamic> json) => GameRecord(
        timestamp: DateTime.parse(json['timestamp'] as String),
        word: json['word'] as String,
        impostorsWon: json['impostorsWon'] as bool,
        players: (json['players'] as List<dynamic>).cast<String>(),
        impostorNames: (json['impostorNames'] as List<dynamic>).cast<String>(),
        killedNames: (json['killedNames'] as List<dynamic>).cast<String>(),
      );
}
