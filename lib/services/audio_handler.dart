import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class JalPlayAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: []);

  JalPlayAudioHandler() {
    _player.playbackEventStream.listen((_) => _broadcastState());
    _player.playerStateStream.listen((_) => _broadcastState());

    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.idle,
      playing: false,
      repeatMode: AudioServiceRepeatMode.none,
      shuffleMode: AudioServiceShuffleMode.none,
    ));
  }

  AudioPlayer get player => _player;

  // ─── Queue management ───

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    this.queue.add(queue);
    final sources = queue
        .map((item) => AudioSource.uri(
              Uri.file(item.extras?['filePath'] as String? ?? ''),
              tag: item,
            ))
        .toList();
    await _playlist.clear();
    await _playlist.addAll(sources);
    try {
      await _player.setAudioSource(_playlist, preload: false);
    } catch (e) {
      // ignore
    }
  }

  // ─── Public playback controls ───

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    try {
      if (playbackState.value.shuffleMode == AudioServiceShuffleMode.all) {
        final idx = math.Random().nextInt(_playlist.length);
        await _player.seek(Duration.zero, index: idx);
        await _player.play();
      } else {
        await _player.seekToNext();
        await _player.play();
      }
    } catch (e) {
      debugPrint('JALPlay: skipToNext error: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
        return;
      }
      if (playbackState.value.shuffleMode == AudioServiceShuffleMode.all) {
        final idx = math.Random().nextInt(_playlist.length);
        await _player.seek(Duration.zero, index: idx);
        await _player.play();
      } else {
        await _player.seekToPrevious();
        await _player.play();
      }
    } catch (e) {
      debugPrint('JALPlay: skipToPrevious error: $e');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      debugPrint('JALPlay: skipToQueueItem($index) error: $e');
    }
  }

  Future<void> prepareIndex(int index, Duration position) async {
    if (index < 0 || index >= queue.value.length) return;
    try {
      await _player.seek(position, index: index);
    } catch (e) {
      debugPrint('JALPlay: prepareIndex($index) error: $e');
    }
  }

  Future<void> playIndex(int index) => skipToQueueItem(index);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    LoopMode loopMode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        loopMode = LoopMode.one;
      case AudioServiceRepeatMode.all:
        loopMode = LoopMode.all;
      default:
        loopMode = LoopMode.off;
    }
    await _player.setLoopMode(loopMode);
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  // ─── State broadcasting ───

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    ));
  }

  Future<void> disposePlayer() async {
    await _player.stop();
    await _player.dispose();
  }
}
