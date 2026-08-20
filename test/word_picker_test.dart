import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/core/word_picker_service.dart';

void main() {
  group('WordPickerService', () {
    late WordPickerService service;

    setUp(() {
      service = WordPickerService();
    });

    test('picks a word from the list', () {
      final word = service.pickWord(
        theme: 'Animals',
        words: ['Lion', 'Tiger', 'Bear'],
        random: Random(42),
      );
      expect(['Lion', 'Tiger', 'Bear'], contains(word));
    });

    test('does not repeat words until pool is exhausted', () {
      final words = ['A', 'B', 'C'];
      final picked = <String>{};
      final random = Random(0);

      for (var i = 0; i < 3; i++) {
        picked.add(
          service.pickWord(theme: 'Test', words: words, random: random),
        );
      }
      // All 3 should have been picked (no repeats).
      expect(picked.length, 3);
    });

    test('resets and re-picks after pool exhaustion', () {
      final words = ['X', 'Y'];
      final random = Random(1);

      // Exhaust pool.
      service.pickWord(theme: 'T', words: words, random: random);
      service.pickWord(theme: 'T', words: words, random: random);

      // Third pick should still succeed (pool resets).
      final third = service.pickWord(theme: 'T', words: words, random: random);
      expect(words, contains(third));
    });

    test('reset clears history', () {
      final random = Random(5);
      service.pickWord(theme: 'A', words: ['W1'], random: random);
      service.reset();
      // After reset, W1 should be pick-able again without exhausting.
      final picked =
          service.pickWord(theme: 'A', words: ['W1'], random: random);
      expect(picked, 'W1');
    });
  });
}
