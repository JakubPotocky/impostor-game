import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Provider for [BackupService].
final backupServiceProvider = Provider<BackupService>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Thrown when text is not a valid backup this app version can restore.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// A validated backup, ready to be shown to the user and restored.
@immutable
class ParsedBackup {
  const ParsedBackup({
    required this.exportedAt,
    required this.appVersion,
    required this.summary,
    required this.sections,
  });

  final DateTime exportedAt;
  final String appVersion;

  /// Informational counts (e.g. players, games) recorded at export time.
  final Map<String, int> summary;

  /// Section name -> raw Hive entries (key -> value).
  final Map<String, Map<Object, Object?>> sections;
}

/// Exports and restores every Hive box the app uses as one JSON document.
///
/// Works on raw box entries rather than per-repository models, so data added
/// to an existing box later is backed up without touching this class. Values
/// are limited to JSON primitives — every repository already stores its data
/// as JSON strings or plain settings values.
class BackupService {
  BackupService(this._boxes);

  /// Section name -> the box holding that section's data.
  final Map<String, Box<dynamic>> _boxes;

  static const String _appId = 'impostor';
  static const int formatVersion = 1;

  /// Serialises every box. [summary] is stored as-is for display on restore.
  String export({
    required String appVersion,
    required DateTime exportedAt,
    Map<String, int> summary = const {},
  }) {
    return const JsonEncoder.withIndent(' ').convert({
      'app': _appId,
      'formatVersion': formatVersion,
      'appVersion': appVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'summary': summary,
      'sections': {
        for (final MapEntry(key: name, value: box) in _boxes.entries)
          name: [
            for (final MapEntry(:key, :value) in box.toMap().entries)
              [key, value],
          ],
      },
    });
  }

  /// Validates [text] completely, without modifying anything.
  ///
  /// Sections this app version doesn't know are ignored, so backups from a
  /// newer version still restore everything this one understands.
  ParsedBackup parse(String text) {
    final Object? decoded;
    try {
      decoded = json.decode(text);
    } on FormatException {
      throw const BackupFormatException("That isn't a backup — invalid JSON.");
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != _appId) {
      throw const BackupFormatException("That isn't an Impostor backup.");
    }
    final version = decoded['formatVersion'];
    if (version is! int || version > formatVersion) {
      throw const BackupFormatException(
          'This backup was made by a newer version of the app — update first.');
    }
    final exportedAt = DateTime.tryParse('${decoded['exportedAt']}');
    final rawSections = decoded['sections'];
    if (exportedAt == null || rawSections is! Map<String, dynamic>) {
      throw const BackupFormatException('The backup is incomplete.');
    }

    final sections = <String, Map<Object, Object?>>{};
    for (final MapEntry(key: name, value: entries) in rawSections.entries) {
      final box = _boxes[name];
      if (box == null) continue;
      if (entries is! List) {
        throw BackupFormatException('Section "$name" is malformed.');
      }
      sections[name] = Map.fromEntries(
        entries.map((entry) => _parseEntry(name, box, entry)),
      );
    }

    final rawSummary = decoded['summary'];
    return ParsedBackup(
      exportedAt: exportedAt.toLocal(),
      appVersion: '${decoded['appVersion'] ?? 'unknown'}',
      summary: {
        if (rawSummary is Map<String, dynamic>)
          for (final MapEntry(:key, :value) in rawSummary.entries)
            if (value is int) key: value,
      },
      sections: sections,
    );
  }

  MapEntry<Object, Object?> _parseEntry(
    String section,
    Box<dynamic> box,
    Object? entry,
  ) {
    if (entry is! List || entry.length != 2) {
      throw BackupFormatException('Section "$section" has a malformed entry.');
    }
    final [key, value] = entry;
    final validKey = key is String || key is int;
    final validValue =
        value == null || value is String || value is num || value is bool;
    // Typed boxes (e.g. the String-only players box) reject other values at
    // write time; catch that here so restore can't fail halfway through.
    final fitsBox = box is! Box<String> || value is String;
    if (!validKey || !validValue || !fitsBox) {
      throw BackupFormatException('Section "$section" has an invalid entry.');
    }
    return MapEntry(key!, value);
  }

  /// Replaces each backed-up section's box contents with the backup's.
  /// Boxes for sections absent from the backup are left untouched.
  Future<void> restore(ParsedBackup backup) async {
    for (final MapEntry(key: name, value: entries) in backup.sections.entries) {
      final box = _boxes[name]!;
      await box.clear();
      for (final MapEntry(:key, :value) in entries.entries) {
        await box.put(key, value);
      }
    }
  }
}
