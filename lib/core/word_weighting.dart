/// How strongly like/dislike votes nudge how often a word comes up.
///
/// A nudge, not a ban: weights are clamped to [minWeight]–[maxWeight], so a
/// word one grumpy group disliked twice still appears now and then, and a
/// beloved word can't crowd out the rest of its theme.
abstract final class WordWeighting {
  static const double baseWeight = 1.0;
  static const double likeBonus = 0.15;
  static const double dislikePenalty = 0.25;
  static const double minWeight = 0.2;
  static const double maxWeight = 3.0;

  /// Relative pick weight for a word with the given vote counts. Words with
  /// no votes get [baseWeight], i.e. today's uniform behaviour.
  static double fromVotes({int likes = 0, int dislikes = 0}) {
    final raw = baseWeight + likes * likeBonus - dislikes * dislikePenalty;
    return raw.clamp(minWeight, maxWeight).toDouble();
  }
}
