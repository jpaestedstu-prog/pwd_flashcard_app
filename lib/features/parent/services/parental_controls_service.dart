import 'package:hive_flutter/hive_flutter.dart';
import '../models/parental_controls.dart';

/// Manages parental control settings stored in Hive.
///
/// Controls are device-wide: one set of parental controls applies
/// to all student profiles on this device.
class ParentalControlsService {
  static const String _boxName = 'settings';
  static const String _key = 'parental_controls';

  static Box get _box => Hive.box(_boxName);

  /// Get the current parental controls (defaults to no restrictions).
  static ParentalControls getControls() {
    final raw = _box.get(_key);
    if (raw == null) return const ParentalControls();
    return ParentalControls.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// Save parental controls.
  static Future<void> saveControls(ParentalControls controls) async {
    await _box.put(_key, controls.toJson());
  }

  /// Reset all controls to defaults (no restrictions).
  static Future<void> resetControls() async {
    await _box.delete(_key);
  }
}
