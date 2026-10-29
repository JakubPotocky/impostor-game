import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impostor/data/preset_repository.dart';
import 'package:impostor/features/game_setup/game_setup_notifier.dart';
import 'package:impostor/features/game_setup/round_preset.dart';

/// Saved round presets, plus actions to save, apply and delete them.
class PresetsNotifier extends Notifier<List<RoundPreset>> {
  late final PresetRepository _repo;

  @override
  List<RoundPreset> build() {
    _repo = ref.read(presetRepositoryProvider);
    return _repo.getPresets();
  }

  /// Snapshots the current round settings under [name], overwriting any
  /// preset already using that name.
  Future<void> saveCurrent(String name) async {
    await _repo.savePreset(
      RoundPreset.fromState(name, ref.read(gameSetupProvider)),
    );
    state = _repo.getPresets();
  }

  void apply(RoundPreset preset) {
    ref.read(gameSetupProvider.notifier).applyPreset(preset);
  }

  Future<void> delete(String name) async {
    await _repo.deletePreset(name);
    state = _repo.getPresets();
  }
}

/// Provider for [PresetsNotifier].
final presetsProvider = NotifierProvider<PresetsNotifier, List<RoundPreset>>(
    PresetsNotifier.new);
