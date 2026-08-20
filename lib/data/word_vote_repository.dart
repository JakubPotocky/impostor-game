import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Provider for [WordVoteRepository].
final wordVoteRepositoryProvider = Provider<WordVoteRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Repository that persists word votes (likes / dislikes) using Hive.
///
/// Votes are stored per word as a JSON map: `{ "word": { "likes": 3, "dislikes": 1 } }`.
/// This data is collected for future analytics — no gameplay effect for now.
class WordVoteRepository {
  static const String _boxName = 'word_votes';
  static const String _keyVotes = 'votes';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(_box != null && _box!.isOpen, 'WordVoteRepository not initialised');
    return _box!;
  }

  /// Returns the full votes map.
  Map<String, WordVote> getVotes() {
    final raw = _safeBox.get(_keyVotes) as String?;
    if (raw == null || raw.isEmpty) return {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((word, data) {
      final map = data as Map<String, dynamic>;
      return MapEntry(
        word,
        WordVote(
          likes: (map['likes'] as num?)?.toInt() ?? 0,
          dislikes: (map['dislikes'] as num?)?.toInt() ?? 0,
        ),
      );
    });
  }

  /// Records a like for the given word.
  Future<void> likeWord(String word) async {
    final votes = getVotes();
    final current = votes[word] ?? const WordVote();
    votes[word] =
        WordVote(likes: current.likes + 1, dislikes: current.dislikes);
    await _save(votes);
  }

  /// Records a dislike for the given word.
  Future<void> dislikeWord(String word) async {
    final votes = getVotes();
    final current = votes[word] ?? const WordVote();
    votes[word] =
        WordVote(likes: current.likes, dislikes: current.dislikes + 1);
    await _save(votes);
  }

  Future<void> _save(Map<String, WordVote> votes) async {
    final map = votes.map((word, v) => MapEntry(word, {
          'likes': v.likes,
          'dislikes': v.dislikes,
        }));
    await _safeBox.put(_keyVotes, json.encode(map));
  }
}

/// Simple data class holding like/dislike counts for a word.
class WordVote {
  const WordVote({this.likes = 0, this.dislikes = 0});
  final int likes;
  final int dislikes;
}
