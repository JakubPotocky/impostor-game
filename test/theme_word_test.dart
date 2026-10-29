import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor/data/theme_word.dart';

void main() {
  group('ThemeWord JSON', () {
    test('parses legacy plain strings without a hint', () {
      final word = ThemeWord.fromJson('Lion');
      expect(word.text, 'Lion');
      expect(word.hasHint, isFalse);
    });

    test('parses word objects with a hint', () {
      final word = ThemeWord.fromJson({'word': 'Lion', 'hint': 'Mane'});
      expect(word, const ThemeWord('Lion', hint: 'Mane'));
    });

    test('rejects entries without a word', () {
      expect(() => ThemeWord.fromJson({'hint': 'Mane'}),
          throwsA(isA<FormatException>()));
    });

    test('blank hints count as no hint', () {
      expect(const ThemeWord('Lion', hint: '   ').hint, isNull);
    });

    test('serialises hint-less words as plain strings', () {
      expect(const ThemeWord('Lion').toJson(), 'Lion');
      expect(const ThemeWord('Lion', hint: 'Mane').toJson(),
          {'word': 'Lion', 'hint': 'Mane'});
    });

    test('catalog round-trips through encode/decode', () {
      final catalog = <String, Map<String, List<ThemeWord>>>{
        'Animals': {
          'en': const [ThemeWord('Lion', hint: 'Mane'), ThemeWord('Otter')],
        },
      };
      final decoded = decodeThemeCatalog(
          json.decode(json.encode(encodeThemeCatalog(catalog)))
              as Map<String, dynamic>);
      expect(decoded['Animals']!['en'], catalog['Animals']!['en']);
    });
  });

  group('parseWordList', () {
    test('parses one word per line with optional hints', () {
      expect(parseWordList('Red: Roses\nBlue\n\n  Green :  Grass, lawn '), [
        const ThemeWord('Red', hint: 'Roses'),
        const ThemeWord('Blue'),
        const ThemeWord('Green', hint: 'Grass, lawn'),
      ]);
    });

    test('still accepts the single-line comma format', () {
      expect(parseWordList('Red, Blue: Sky, ,Green'), [
        const ThemeWord('Red'),
        const ThemeWord('Blue', hint: 'Sky'),
        const ThemeWord('Green'),
      ]);
    });
  });

  group('bundled themes.json', () {
    final catalog = decodeThemeCatalog(
        json.decode(File('assets/themes.json').readAsStringSync())
            as Map<String, dynamic>);

    test('every word outside Team Pairs has a hint that does not leak it', () {
      for (final theme in catalog.entries) {
        if (theme.key == 'Team Pairs') continue;
        for (final lang in theme.value.entries) {
          for (final word in lang.value) {
            final where = '${theme.key}/${lang.key}/${word.text}';
            expect(word.hint, isNotNull, reason: '$where has no hint');
            final w = word.text.toLowerCase();
            final h = word.hint!.toLowerCase();
            expect(h.contains(w) || w.contains(h), isFalse,
                reason: '$where hint "${word.hint}" leaks the word');
          }
        }
      }
    });
  });
}
