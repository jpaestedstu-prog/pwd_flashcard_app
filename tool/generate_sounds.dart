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
