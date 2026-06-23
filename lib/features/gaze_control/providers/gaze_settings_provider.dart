import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../models/gaze_settings.dart';

/// Single Hive key (in the shared `settings` box) holding the serialised
/// [GazeSettings] map.
const String kGazeSettingsKey = 'gazeSettings';

/// Owns the persisted [GazeSettings]. Reads are guarded so the provider yields
/// defaults when Hive isn't initialised (e.g. in widget tests), and writes are
/// fire-and-forget and guarded so a closed box can never crash the UI — the
/// same defensive posture the rest of the app uses for Hive writes.
class GazeSettingsNotifier extends Notifier<GazeSettings> {
  @override
  GazeSettings build() {
    try {
      final raw = HiveService.getSetting(kGazeSettingsKey);
      if (raw is Map) return GazeSettings.fromMap(raw);
    } catch (_) {
      // Hive not ready → fall through to defaults.
    }
    return const GazeSettings();
  }

  void update(GazeSettings settings) {
    state = settings;
    _persist(settings);
  }

  void setEnabled(bool v) => update(state.copyWith(enabled: v));
  void setSensitivity(int v) => update(state.copyWith(sensitivity: v));
  void setDwellMs(int v) => update(state.copyWith(dwellMs: v));
  void setBlinkEnabled(bool v) => update(state.copyWith(blinkEnabled: v));
  void setMirrorHorizontal(bool v) => update(state.copyWith(mirrorHorizontal: v));
  void setInvertVertical(bool v) => update(state.copyWith(invertVertical: v));
  void setScanMode(bool v) => update(state.copyWith(scanMode: v));
  void setScanStepMs(int v) => update(state.copyWith(scanStepMs: v));
  void setVoiceCommands(bool v) => update(state.copyWith(voiceCommands: v));
  void setNavScope(GazeNavScope v) => update(state.copyWith(navScope: v));

  void _persist(GazeSettings s) {
    try {
      HiveService.saveSetting(kGazeSettingsKey, s.toMap()).ignore();
    } catch (_) {
      // Box not open (tests) — state still updates in memory.
    }
  }
}

final gazeSettingsProvider =
    NotifierProvider<GazeSettingsNotifier, GazeSettings>(
  GazeSettingsNotifier.new,
);
