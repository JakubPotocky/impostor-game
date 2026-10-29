import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:impostor/data/backup_service.dart';

void main() {
  late Directory dir;
  late Box<String> players;
  late Box<dynamic> settings;
  late BackupService service;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup_service_test');
    Hive.init(dir.path);
    players = await Hive.openBox<String>('players');
    settings = await Hive.openBox<dynamic>('settings');
    service = BackupService({'players': players, 'settings': settings});
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  String exportNow({Map<String, int> summary = const {}}) => service.export(
        appVersion: '2.6.0',
        exportedAt: DateTime(2026, 10, 29),
        summary: summary,
      );

  test('export then restore reproduces every box exactly', () async {
    await players.addAll(['Alice', 'Bob']);
    await settings.putAll({'darkMode': false, 'impostorCount': 2});
    final backup = exportNow(summary: {'players': 2});

    await players.clear();
    await players.add('Mallory');
    await settings.put('darkMode', true);
    await settings.put('extra', 'gone after restore');

    final parsed = service.parse(backup);
    expect(parsed.summary, {'players': 2});
    expect(parsed.appVersion, '2.6.0');
    await service.restore(parsed);

    expect(players.values, ['Alice', 'Bob']);
    expect(settings.toMap(), {'darkMode': false, 'impostorCount': 2});
  });

  test('sections missing from the backup are left alone', () async {
    await settings.put('darkMode', true);
    final backup = jsonDecode(exportNow()) as Map<String, dynamic>;
    (backup['sections'] as Map).remove('settings');

    await service.restore(service.parse(jsonEncode(backup)));
    expect(settings.get('darkMode'), isTrue);
  });

  test('unknown sections from newer versions are ignored', () {
    final backup = jsonDecode(exportNow()) as Map<String, dynamic>;
    (backup['sections'] as Map)['fromTheFuture'] = [
      ['k', 'v'],
    ];
    expect(service.parse(jsonEncode(backup)).sections.keys,
        unorderedEquals(['players', 'settings']));
  });

  group('rejects without changing anything', () {
    setUp(() async => players.add('Alice'));

    void expectRejected(String text) {
      expect(() => service.parse(text), throwsA(isA<BackupFormatException>()));
      expect(players.values, ['Alice']);
    }

    test('non-JSON text', () => expectRejected('hello'));

    test('JSON from something else', () => expectRejected('{"a": 1}'));

    test('a newer backup format', () {
      final backup = jsonDecode(exportNow()) as Map<String, dynamic>;
      backup['formatVersion'] = BackupService.formatVersion + 1;
      expectRejected(jsonEncode(backup));
    });

    test('a value that does not fit a typed box', () {
      final backup = jsonDecode(exportNow()) as Map<String, dynamic>;
      (backup['sections'] as Map)['players'] = [
        [0, 42],
      ];
      expectRejected(jsonEncode(backup));
    });
  });
}
