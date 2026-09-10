// Generates minimal WAV sound effect files for the app.
// Run with: dart run tool/generate_sounds.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// ignore_for_file: avoid_print

void main() {
  const dir = 'assets/sounds';
  Directory(dir).createSync(recursive: true);

  // Each sound: (filename, frequency Hz, duration ms, type)
  final sounds = <_SoundSpec>[
    _SoundSpec('correct', [660, 880], [100, 150], 'ascending'), // happy ding-ding
    _SoundSpec('wrong', [330, 260], [120, 180], 'descending'),  // sad boop
    _SoundSpec('star', [880, 1100, 1320], [80, 80, 160], 'ascending'), // sparkle
    _SoundSpec('complete', [523, 659, 784, 1047], [100, 100, 100, 250], 'ascending'), // fanfare
    _SoundSpec('tap', [600], [50], 'single'), // quick click
    _SoundSpec('flip', [400, 500], [40, 60], 'ascending'), // flip
    _SoundSpec('match', [784, 1047], [100, 200], 'ascending'), // match found
    _SoundSpec('letter', [520], [60], 'single'), // letter snap
  ];

  for (final spec in sounds) {
    final samples = _generateSamples(spec);
    final wav = _buildWav(samples, 44100);
    File('$dir/${spec.name}.wav').writeAsBytesSync(wav);
    print('Generated ${spec.name}.wav (${wav.length} bytes)');
  }

  print('\nAll sound effects generated in $dir/');

  _generatePacks();
}

class _SoundSpec {
  final String name;
  final List<double> freqs;
  final List<int> durationsMs;
  final String type;
  _SoundSpec(this.name, this.freqs, this.durationsMs, this.type);
}

List<double> _generateSamples(_SoundSpec spec, {int sampleRate = 44100}) {
  final samples = <double>[];

  for (int i = 0; i < spec.freqs.length; i++) {
    final freq = spec.freqs[i];
    final durationMs = spec.durationsMs[i];
    final numSamples = (sampleRate * durationMs / 1000).round();

    for (int s = 0; s < numSamples; s++) {
      final t = s / sampleRate;
      // Sine wave with fade-in/fade-out envelope
      final envelope = _envelope(s, numSamples);
      final sample = sin(2 * pi * freq * t) * envelope * 0.6;
      samples.add(sample);
    }
  }

  return samples;
}

double _envelope(int sample, int total) {
  final fadeLen = (total * 0.15).round().clamp(1, total);
  if (sample < fadeLen) return sample / fadeLen;
  if (sample > total - fadeLen) return (total - sample) / fadeLen;
  return 1.0;
}

Uint8List _buildWav(List<double> samples, int sampleRate) {
  final numSamples = samples.length;
  final byteRate = sampleRate * 2; // 16-bit mono
  final dataSize = numSamples * 2;
  final fileSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);
  int pos = 0;

  // RIFF header
  void writeString(String s) {
    for (int i = 0; i < s.length; i++) {
      buffer.setUint8(pos++, s.codeUnitAt(i));
    }
  }

  void writeUint32(int v) {
    buffer.setUint32(pos, v, Endian.little);
    pos += 4;
  }

  void writeUint16(int v) {
    buffer.setUint16(pos, v, Endian.little);
    pos += 2;
  }

  writeString('RIFF');
  writeUint32(fileSize);
  writeString('WAVE');

  // fmt chunk
  writeString('fmt ');
  writeUint32(16); // chunk size
  writeUint16(1);  // PCM
  writeUint16(1);  // mono
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(2);  // block align
  writeUint16(16); // bits per sample

  // data chunk
  writeString('data');
  writeUint32(dataSize);

  for (final sample in samples) {
    final clamped = sample.clamp(-1.0, 1.0);
    final intSample = (clamped * 32767).round().clamp(-32768, 32767);
    buffer.setInt16(pos, intSample, Endian.little);
    pos += 2;
  }

  return buffer.buffer.asUint8List();
}

// ─── Star Shop sound packs ──────────────────────────────────────────────────
//
// The three Sound Pack items in `ShopData` were withdrawn from sale because
// `assets/sounds/` held exactly one set of effects: equipping a pack changed
// nothing an ear could detect, so the stars bought silence. This section
// synthesises a full set per pack, in a timbre no one could mistake for
// another — square waves for Chiptune, glides and filtered noise for Nature,
// detuned sweeps with an echo tail for Space.
//
// Every pack covers all eight [SoundEffect] values. A pack missing even one
// file would fall back to nothing (playback throws and is swallowed), which is
// worse than the classic sound — `test/sound_pack_assets_test.dart` fails the
// build if a sellable pack is ever short a file.

/// One tone (or noise burst) inside a pack sound.
class _Seg {
  const _Seg(
    this.wave,
    this.f0,
    this.durationMs, {
    double? f1,
    this.gain = 1.0,
  }) : f1 = f1 ?? f0;

  /// 'sine', 'square', or 'noise'.
  final String wave;

  /// Start frequency, and the frequency glided to across the segment. For
  /// 'noise' these are the low-pass corner instead.
  final double f0;
  final double f1;
  final int durationMs;
  final double gain;
}

/// A pack's sounds, keyed by the same base names the classic set uses.
class _Pack {
  const _Pack(this.folder, this.envelope, this.sounds, {this.echoMs = 0});

  final String folder;

  /// 'blocky' (chiptune), 'soft' (nature) or 'decay' (space).
  final String envelope;
  final Map<String, List<_Seg>> sounds;

  /// Delay of a quieter repeat mixed under the whole sound, 0 for none.
  final int echoMs;
}

const _packs = <_Pack>[
  // ─── Chiptune: pulse waves, arpeggios, snap ───────────────────────────────
  _Pack('chiptune', 'blocky', {
    'correct': [
      _Seg('square', 880, 60),
      _Seg('square', 1174, 60),
      _Seg('square', 1568, 120),
    ],
    'wrong': [
      _Seg('square', 220, 90),
      _Seg('square', 185, 90),
      _Seg('square', 147, 170),
    ],
    'star': [
      _Seg('square', 1046, 55),
      _Seg('square', 1318, 55),
      _Seg('square', 1568, 55),
      _Seg('square', 2093, 110),
    ],
    'complete': [
      _Seg('square', 523, 90),
      _Seg('square', 659, 90),
      _Seg('square', 784, 90),
      _Seg('square', 1047, 90),
      _Seg('square', 1318, 280),
    ],
    'tap': [_Seg('square', 1200, 35)],
    'flip': [_Seg('square', 700, 30), _Seg('square', 1000, 45)],
    'match': [_Seg('square', 988, 70), _Seg('square', 1319, 170)],
    'letter': [_Seg('square', 1600, 30)],
  }),

  // ─── Nature: bird glides, water, leaves ───────────────────────────────────
  _Pack('nature', 'soft', {
    'correct': [
      _Seg('sine', 1400, 70, f1: 2600),
      _Seg('sine', 2400, 100, f1: 1900),
    ],
    'wrong': [
      _Seg('sine', 190, 190, f1: 115),
      _Seg('noise', 500, 90, gain: 0.35),
    ],
    'star': [
      _Seg('sine', 1800, 120, f1: 3000),
      _Seg('sine', 2700, 110, f1: 2950),
    ],
    'complete': [
      _Seg('sine', 1300, 90, f1: 2100),
      _Seg('sine', 1600, 90, f1: 2500),
      _Seg('sine', 1900, 120, f1: 3100),
      _Seg('noise', 1400, 300, gain: 0.22),
    ],
    'tap': [_Seg('sine', 900, 75, f1: 380)],
    'flip': [_Seg('noise', 5000, 45, gain: 0.85)],
    'match': [
      _Seg('sine', 1600, 90, f1: 2200),
      _Seg('sine', 2000, 140, f1: 2600),
    ],
    'letter': [_Seg('noise', 4000, 22, gain: 0.8)],
  }),

  // ─── Space: detuned sweeps with an echo tail ──────────────────────────────
  _Pack('space', 'decay', {
    'correct': [_Seg('sine', 440, 170, f1: 880)],
    'wrong': [_Seg('sine', 660, 270, f1: 150)],
    'star': [_Seg('sine', 1568, 210)],
    'complete': [
      _Seg('sine', 330, 300, f1: 990),
      _Seg('sine', 1320, 260),
    ],
    'tap': [_Seg('sine', 900, 45)],
    'flip': [_Seg('noise', 3000, 85, gain: 0.8)],
    'match': [_Seg('sine', 1046, 90), _Seg('sine', 1568, 190)],
    'letter': [_Seg('sine', 1320, 28)],
  }, echoMs: 95),
];

/// Renders every pack under `assets/sounds/<folder>/`.
void _generatePacks() {
  for (final pack in _packs) {
    final dir = 'assets/sounds/${pack.folder}';
    Directory(dir).createSync(recursive: true);
    for (final entry in pack.sounds.entries) {
      // Seeded per file so noise bursts are reproducible: re-running the
      // generator must not churn the committed WAVs.
      final rng = Random(entry.key.hashCode & 0x7fffffff);
      var samples = <double>[];
      for (final seg in entry.value) {
        samples.addAll(_renderSeg(seg, pack.envelope, rng));
      }
      if (pack.echoMs > 0) samples = _withEcho(samples, pack.echoMs);
      final wav = _buildWav(samples, 44100);
      File('$dir/${entry.key}.wav').writeAsBytesSync(wav);
      print('Generated ${pack.folder}/${entry.key}.wav (${wav.length} bytes)');
    }
  }
}

/// One segment's samples, at [envelope]'s shape.
List<double> _renderSeg(_Seg seg, String envelope, Random rng, {int rate = 44100}) {
  final n = (rate * seg.durationMs / 1000).round();
  final dur = seg.durationMs / 1000;
  final out = List<double>.filled(n, 0);

  // One-pole low-pass state, for the noise voice.
  var lp = 0.0;

  for (var s = 0; s < n; s++) {
    final t = s / rate;
    final env = _packEnvelope(envelope, s, n);
    double value;

    if (seg.wave == 'noise') {
      final white = rng.nextDouble() * 2 - 1;
      // Corner frequency doubles as the filter's smoothing constant: a low
      // f0 gives wind, a high one gives leaves.
      final k = (seg.f0 / (rate / 2)).clamp(0.01, 1.0);
      lp += k * (white - lp);
      value = lp;
    } else {
      // Glide: the phase is the integral of a frequency ramping f0 → f1, so a
      // swept tone stays continuous instead of stepping.
      final phase = 2 *
          pi *
          (seg.f0 * t + (seg.f1 - seg.f0) * t * t / (2 * (dur == 0 ? 1 : dur)));
      value = seg.wave == 'square'
          ? (sin(phase) >= 0 ? 1.0 : -1.0)
          // A second voice five cents sharp: the beating is what makes the
          // Space pack shimmer rather than sound like a test tone.
          : (sin(phase) + 0.5 * sin(phase * 1.005)) / 1.5;
    }

    // Square waves read far louder than sines at the same amplitude.
    final headroom = seg.wave == 'square' ? 0.34 : 0.55;
    out[s] = value * env * seg.gain * headroom;
  }

  // A one-pole filter costs the noise voice most of its amplitude — the leaf
  // rustle came out 16 dB under the tones around it, which on a tablet
  // speaker is the difference between a sound and no sound. Normalising the
  // peak puts noise on equal footing with the tones instead.
  if (seg.wave == 'noise') {
    var peak = 0.0;
    for (final v in out) {
      if (v.abs() > peak) peak = v.abs();
    }
    if (peak > 0) {
      final target = seg.gain * 0.55;
      for (var s = 0; s < n; s++) {
        out[s] = out[s] * target / peak;
      }
    }
  }
  return out;
}

/// Amplitude shape. `blocky` snaps on and off like a sound chip, `soft` fades
/// both ends like a breath, `decay` opens fast and rings out.
double _packEnvelope(String envelope, int sample, int total) {
  final x = total <= 1 ? 1.0 : sample / (total - 1);
  switch (envelope) {
    case 'blocky':
      final attack = (total * 0.02).clamp(1, total).toDouble();
      final release = (total * 0.12).clamp(1, total).toDouble();
      if (sample < attack) return sample / attack;
      if (sample > total - release) return (total - sample) / release;
      return 1.0;
    case 'soft':
      // A raised cosine — no corners at all, which is what keeps the bird
      // glides from clicking.
      return 0.5 - 0.5 * cos(2 * pi * x);
    case 'decay':
    default:
      final attack = (total * 0.05).clamp(1, total).toDouble();
      final open = sample < attack ? sample / attack : 1.0;
      return open * exp(-3.2 * x);
  }
}

/// Mixes a quieter copy of [samples] in [delayMs] later, twice, so the tail
/// recedes instead of stopping dead.
List<double> _withEcho(List<double> samples, int delayMs, {int rate = 44100}) {
  final delay = (rate * delayMs / 1000).round();
  final out = List<double>.filled(samples.length + delay * 2, 0);
  for (var i = 0; i < samples.length; i++) {
    out[i] += samples[i];
    out[i + delay] += samples[i] * 0.38;
    out[i + delay * 2] += samples[i] * 0.14;
  }
  return out;
}
