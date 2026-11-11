import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Writes how long the app's frames take to the device log, for measuring a
/// release build on a phone or a tablet (where the system's own frame counters
/// see only Android's views, never Flutter's surface, and Android 16 no longer
/// reports a surface's frame times).
///
/// Off in every published build: a measuring build is a release build made
/// with `--dart-define=FLASHLEARN_FRAME_TIMINGS=true`, and the constant keeps
/// this out of the others entirely. Every 120 frames it logs the median and
/// the 90th and 99th percentiles of the build (UI thread) and raster (GPU
/// thread) times and of the whole frame, and how many frames missed a 60 Hz
/// deadline. Read with `adb logcat -s flutter | grep FrameTimings`.
abstract final class FrameTimingLog {
  static const bool _requested = bool.fromEnvironment(
    'FLASHLEARN_FRAME_TIMINGS',
  );

  static final List<FrameTiming> _batch = [];

  static void install() {
    if (!_requested) return;
    SchedulerBinding.instance.addTimingsCallback(_collect);
  }

  static void _collect(List<FrameTiming> timings) {
    _batch.addAll(timings);
    if (_batch.length < 120) return;
    int ms(Duration d) => d.inMicroseconds;
    String pct(List<int> us) {
      us.sort();
      double at(double p) => us[((us.length - 1) * p).round()] / 1000;
      return '${at(0.5).toStringAsFixed(1)}/${at(0.9).toStringAsFixed(1)}/'
          '${at(0.99).toStringAsFixed(1)} ms';
    }

    final build = [for (final t in _batch) ms(t.buildDuration)];
    final raster = [for (final t in _batch) ms(t.rasterDuration)];
    final total = [for (final t in _batch) ms(t.totalSpan)];
    final slow = total.where((us) => us > 16667).length;
    debugPrint(
      'FrameTimings ${_batch.length} frames | build p50/p90/p99 '
      '${pct(build)} | raster ${pct(raster)} | total ${pct(total)} | '
      'over 16.7 ms: $slow',
    );
    _batch.clear();
  }
}
