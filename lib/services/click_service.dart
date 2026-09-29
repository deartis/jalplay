import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class ClickService {
  static final ClickService _instance = ClickService._internal();
  factory ClickService() => _instance;
  ClickService._internal();

  final List<AudioPlayer> _pool = [];
  int _poolIndex = 0;
  bool _initialized = false;
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool val) => _enabled = val;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final clickBytes = _generateIpodClickWav();
      final uri = Uri.dataFromBytes(clickBytes, mimeType: 'audio/wav');

      for (int i = 0; i < 3; i++) {
        final player = AudioPlayer();
        await player.setAudioSource(AudioSource.uri(uri), preload: true);
        await player.setVolume(0.8);
        _pool.add(player);
      }
      _initialized = true;
    } catch (_) {
      // Fallback to SystemSound if player initialization fails
    }
  }

  void playClick() {
    if (!_enabled) return;

    HapticFeedback.selectionClick();

    if (_initialized && _pool.isNotEmpty) {
      try {
        final player = _pool[_poolIndex];
        _poolIndex = (_poolIndex + 1) % _pool.length;
        player.seek(Duration.zero);
        player.play();
      } catch (_) {
        SystemSound.play(SystemSoundType.click);
      }
    } else {
      SystemSound.play(SystemSoundType.click);
    }
  }

  static Uint8List _generateIpodClickWav() {
    const sampleRate = 44100;
    const numSamples = 350; // ~8ms
    const numChannels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const blockAlign = numChannels * (bitsPerSample ~/ 8);
    const dataSize = numSamples * blockAlign;
    const chunkSize = 36 + dataSize;

    final bytes = ByteData(44 + dataSize);

    // RIFF header
    bytes.setUint8(0, 0x52); bytes.setUint8(1, 0x49); bytes.setUint8(2, 0x46); bytes.setUint8(3, 0x46);
    bytes.setUint32(4, chunkSize, Endian.little);
    bytes.setUint8(8, 0x57); bytes.setUint8(9, 0x41); bytes.setUint8(10, 0x56); bytes.setUint8(11, 0x45);

    // fmt subchunk
    bytes.setUint8(12, 0x66); bytes.setUint8(13, 0x6D); bytes.setUint8(14, 0x74); bytes.setUint8(15, 0x20);
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, numChannels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, byteRate, Endian.little);
    bytes.setUint16(32, blockAlign, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    bytes.setUint8(36, 0x64); bytes.setUint8(37, 0x61); bytes.setUint8(38, 0x74); bytes.setUint8(39, 0x61);
    bytes.setUint32(40, dataSize, Endian.little);

    // PCM samples: synthesized mechanical click impulse
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final decay = math.exp(-i / 25.0);
      final tone = math.sin(2 * math.pi * 2800 * t);
      final noise = ((i * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF * 2 - 1;
      final sample = ((tone * 0.7 + noise * 0.3) * decay * 28000).toInt();
      bytes.setInt16(44 + i * 2, sample.clamp(-32768, 32767), Endian.little);
    }

    return bytes.buffer.asUint8List();
  }

  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
    _pool.clear();
    _initialized = false;
  }
}
