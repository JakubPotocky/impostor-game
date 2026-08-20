import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/data/word_vote_repository.dart';

/// Screen showing word voting analytics — top rated and worst rated words.
class WordAnalyticsScreen extends ConsumerWidget {
  const WordAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(wordVoteRepositoryProvider);
    final votes = repo.getVotes();
    final colorScheme = Theme.of(context).colorScheme;

    // Sort by score (likes - dislikes).
    final entries = votes.entries.toList()
      ..sort((a, b) {
        final scoreA = a.value.likes - a.value.dislikes;
        final scoreB = b.value.likes - b.value.dislikes;
        return scoreB.compareTo(scoreA);
      });

    final topRated =
        entries.where((e) => e.value.likes > e.value.dislikes).toList();
    final worstRated =
        entries.where((e) => e.value.dislikes > e.value.likes).toList()
          ..sort((a, b) {
            final scoreA = a.value.likes - a.value.dislikes;
            final scoreB = b.value.likes - b.value.dislikes;
            return scoreA.compareTo(scoreB);
          });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Analytics'),
        centerTitle: true,
      ),
      body: votes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_rounded,
                      size: 64, color: colorScheme.primary.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text(
                    'No votes collected yet',
                    style: TextStyle(
                      color: colorScheme.onSurface.withAlpha(150),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rate words at the end of each game',
                    style: TextStyle(
                      color: colorScheme.onSurface.withAlpha(100),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Top rated ---
                if (topRated.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.thumb_up_rounded,
                    title: 'Top Rated Words',
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(height: 8),
                  ...topRated.take(10).map(
                        (e) => _WordVoteTile(
                          word: e.key,
                          vote: e.value,
                        ),
                      ),
                  const SizedBox(height: 24),
                ],

                // --- Worst rated ---
                if (worstRated.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.thumb_down_rounded,
                    title: 'Worst Rated Words',
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 8),
                  ...worstRated.take(10).map(
                        (e) => _WordVoteTile(
                          word: e.key,
                          vote: e.value,
                        ),
                      ),
                  const SizedBox(height: 24),
                ],

                // --- All votes ---
                _SectionHeader(
                  icon: Icons.list_rounded,
                  title: 'All Votes (${entries.length})',
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 8),
                ...entries.map(
                  (e) => _WordVoteTile(word: e.key, vote: e.value),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });
  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WordVoteTile extends StatelessWidget {
  const _WordVoteTile({required this.word, required this.vote});
  final String word;
  final WordVote vote;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final score = vote.likes - vote.dislikes;
    final scoreColor = score > 0
        ? Colors.green.shade400
        : score < 0
            ? Colors.red.shade400
            : colorScheme.onSurface.withAlpha(120);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                word,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.thumb_up_outlined,
                size: 14, color: Colors.green.shade400),
            const SizedBox(width: 4),
            Text('${vote.likes}',
                style: TextStyle(fontSize: 12, color: Colors.green.shade400)),
            const SizedBox(width: 12),
            Icon(Icons.thumb_down_outlined,
                size: 14, color: Colors.red.shade400),
            const SizedBox(width: 4),
            Text('${vote.dislikes}',
                style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scoreColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                score > 0 ? '+$score' : '$score',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: scoreColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
