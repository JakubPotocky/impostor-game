import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:impostor/features/game_setup/round_preset.dart';

/// Provider for [PresetRepository].
final presetRepositoryProvider = Provider<PresetRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Persists named [RoundPreset]s using Hive.
class PresetRepository {
  static const String _boxName = 'round_presets';
  static const String _keyPresets = 'presets';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _safeBox {
    assert(_box != null && _box!.isOpen, 'PresetRepository not initialised');
    return _box!;
  }

  /// Box backing this repository, for full-app backup/restore.
  Box<dynamic> get backupBox => _safeBox;

  /// All presets, in the order they were first saved.
  List<RoundPreset> getPresets() {
    final raw = _safeBox.get(_keyPresets) as String?;
    if (raw == null || raw.isEmpty) return [];
    return (json.decode(raw) as List<dynamic>)
        .map((e) => RoundPreset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Saves [preset], replacing an existing one with the same name in place.
  Future<void> savePreset(RoundPreset preset) async {
    final presets = getPresets();
    final index = presets.indexWhere((p) => p.name == preset.name);
    if (index == -1) {
      presets.add(preset);
    } else {
      presets[index] = preset;
    }
    await _save(presets);
  }

  Future<void> deletePreset(String name) async {
    final presets = getPresets()..removeWhere((p) => p.name == name);
    await _save(presets);
  }

  Future<void> _save(List<RoundPreset> presets) async {
    await _safeBox.put(
      _keyPresets,
      json.encode(presets.map((p) => p.toJson()).toList()),
    );
  }
}
