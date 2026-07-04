import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import '../services/audio_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlayerState { stopped, playing, paused }

enum SongRepeat { off, one, all }

enum SleepTimerDuration { off, fifteen, thirty, sixty }

enum SongSortField { title, artist, album }

const sleepTimerLabels = ['Desligado', '15 min', '30 min', '60 min'];
const sortFieldLabels = ['Título', 'Artista', 'Álbum'];

class PlayerProvider extends ChangeNotifier {
  final JalPlayAudioHandler _handler;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<Song> _songs = [];
  int _currentIndex = -1;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;
  bool _isShuffle = false;
  SongRepeat _repeatMode = SongRepeat.off;
  bool _hasPermission = false;
  double _volume = 1.0;
  List<int> _favoriteSongIds = [];
  bool _stateLoaded = false;

  // Artwork cache
  final Map<int, Uint8List?> _artworkCache = {};

  // Settings
  SleepTimerDuration _sleepTimer = SleepTimerDuration.off;
  Timer? _sleepTimerInstance;
  SongSortField _sortField = SongSortField.title;


  // Getters
  List<Song> get songs => _songs;
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _songs.length
      ? _songs[_currentIndex]
      : null;
  PlayerState get playerState => _playerState;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isLoading => _isLoading;
  bool get isPlaying => _playerState == PlayerState.playing;
  bool get isShuffle => _isShuffle;
  SongRepeat get repeatMode => _repeatMode;
  bool get hasPermission => _hasPermission;
  double get volume => _volume;
  List<int> get favoriteSongIds => _favoriteSongIds;
  List<Song> get favoriteSongs =>
      _songs.where((s) => _favoriteSongIds.contains(s.id)).toList();

  SleepTimerDuration get sleepTimer => _sleepTimer;
  bool get isSleepTimerActive => _sleepTimerInstance != null;
  SongSortField get sortField => _sortField;

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlayerProvider(this._handler) {
    _initListeners();
  }

  void _initListeners() {
    _handler.playbackState.listen((state) {
      if (state.playing) {
        _playerState = PlayerState.playing;
      } else {
        switch (state.processingState) {
          case AudioProcessingState.idle:
            _playerState = PlayerState.stopped;
          case AudioProcessingState.loading:
          case AudioProcessingState.buffering:
            _playerState = PlayerState.playing;
          case AudioProcessingState.ready:
            _playerState = PlayerState.paused;
          case AudioProcessingState.completed:
            _playerState = PlayerState.paused;
          default:
            _playerState = PlayerState.paused;
        }
      }

      // Cancel sleep timer on stop
      if (_playerState == PlayerState.stopped && _sleepTimerInstance != null) {
        _cancelSleepTimer();
        notifyListeners();
      }

      _isShuffle = state.shuffleMode == AudioServiceShuffleMode.all;
      _repeatMode = state.repeatMode == AudioServiceRepeatMode.one
          ? SongRepeat.one
          : state.repeatMode == AudioServiceRepeatMode.all
              ? SongRepeat.all
              : SongRepeat.off;

      notifyListeners();
      _saveState();
    });

    _handler.player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
      if (pos.inSeconds % 5 == 0) {
        _saveState();
      }
    });

    _handler.player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });

    _handler.player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _songs.length) {
        _currentIndex = index;
        notifyListeners();
        _saveState();
      }
    });

    _handler.player.volumeStream.listen((val) {
      _volume = val;
      notifyListeners();
    });
  }

  // ─── Sleep Timer ───

  void setSleepTimer(SleepTimerDuration duration) {
    _sleepTimer = duration;
    _cancelSleepTimer();
    if (duration == SleepTimerDuration.off) {
      notifyListeners();
      _savePrefs();
      return;
    }
    final minutes = switch (duration) {
      SleepTimerDuration.fifteen => 15,
      SleepTimerDuration.thirty => 30,
      SleepTimerDuration.sixty => 60,
      _ => 0,
    };
    if (minutes > 0) {
      _sleepTimerInstance = Timer(Duration(minutes: minutes), _onSleepTimerFired);
    }
    notifyListeners();
    _savePrefs();
  }

  void _cancelSleepTimer() {
    _sleepTimerInstance?.cancel();
    _sleepTimerInstance = null;
  }

  void _onSleepTimerFired() {
    _sleepTimerInstance = null;
    if (_playerState == PlayerState.playing || _playerState == PlayerState.paused) {
      _handler.stop();
    }
    notifyListeners();
  }

  // ─── Song Sort ───

  void setSortField(SongSortField field) {
    _sortField = field;
    notifyListeners();
    _savePrefs();
    _sortSongs();
  }

  void _sortSongs() {
    switch (_sortField) {
      case SongSortField.title:
        _songs.sort((a, b) => a.title.compareTo(b.title));
      case SongSortField.artist:
        _songs.sort((a, b) => a.artist.compareTo(b.artist));
      case SongSortField.album:
        _songs.sort((a, b) => a.album.compareTo(b.album));
    }
    _rebuildQueue();
    notifyListeners();
  }

  // ─── Rescan Library ───

  Future<void> rescanLibrary() async {
    if (!_hasPermission) return;
    _artworkCache.clear();
    await loadSongs();
  }

  // ─── Reset Settings ───

  Future<void> resetSettings() async {
    _cancelSleepTimer();
    _sleepTimer = SleepTimerDuration.off;
    _sortField = SongSortField.title;
    _isShuffle = false;
    _repeatMode = SongRepeat.off;
    _favoriteSongIds = [];
    _volume = 1.0;
    _artworkCache.clear();

    await _handler.setShuffleMode(AudioServiceShuffleMode.none);
    await _handler.setRepeatMode(AudioServiceRepeatMode.none);
    await _handler.player.setVolume(1.0);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    await _sortAndRebuild();
    notifyListeners();
  }

  // ─── Permission ───

  Future<bool> requestPermission() async {
    if (await Permission.audio.isGranted) {
      _hasPermission = true;
      notifyListeners();
      return true;
    }
    var status = await Permission.audio.request();
    if (status.isGranted) {
      _hasPermission = true;
      notifyListeners();
      return true;
    }
    status = await Permission.storage.request();
    _hasPermission = status.isGranted;
    notifyListeners();
    return _hasPermission;
  }

  // ─── Load songs ───

  Future<void> loadSongs() async {
    if (!_hasPermission) return;
    _isLoading = true;
    notifyListeners();

    try {
      final sortType = switch (_sortField) {
        SongSortField.title => SongSortType.TITLE,
        SongSortField.artist => SongSortType.ARTIST,
        SongSortField.album => SongSortType.ALBUM,
      };

      final songModels = await _audioQuery.querySongs(
        sortType: sortType,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      _songs = songModels
          .where((s) {
            if (s.duration == null || s.duration! < 30000) return false;
            if (s.isMusic != null && !s.isMusic!) return false;

            final path = s.data.toLowerCase();
            final title = (s.title).toLowerCase();
            final displayName = (s.displayName).toLowerCase();

            if (path.contains('whatsapp') || path.contains('telegram')) {
              return false;
            }
            if (title.startsWith('aud_') ||
                title.startsWith('aud-') ||
                title.startsWith('ptt-')) {
              return false;
            }
            if (displayName.startsWith('aud_') ||
                displayName.startsWith('aud-') ||
                displayName.startsWith('ptt-')) {
              return false;
            }

            return true;
          })
          .map((s) => Song.fromSongModel(s))
          .toList();

      await _rebuildQueue();
      await _loadSavedState();
    } catch (e) {
      debugPrint('Error loading songs: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _sortAndRebuild() async {
    _sortSongs();
    await _rebuildQueue();
  }

  Future<void> _rebuildQueue() async {
    final mediaItems = _songs
        .map(
          (s) => MediaItem(
            id: s.id.toString(),
            title: s.title,
            artist: s.artist,
            album: s.album,
            duration: Duration(milliseconds: s.duration),
            extras: {'filePath': s.data ?? ''},
          ),
        )
        .toList();
    await _handler.updateQueue(mediaItems);
  }

  // ─── Artwork ───

  Future<Uint8List?> getArtwork(int songId) async {
    if (_artworkCache.containsKey(songId)) return _artworkCache[songId];
    try {
      final artwork = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        quality: 100,
        size: 300,
      );
      _artworkCache[songId] = artwork;
      return artwork;
    } catch (e) {
      _artworkCache[songId] = null;
      return null;
    }
  }

  // ─── Playback controls ───

  Future<void> playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    _currentIndex = index;
    await _handler.playIndex(index);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await _handler.pause();
    } else if (_playerState == PlayerState.paused) {
      await _handler.play();
    } else if (_currentIndex >= 0) {
      await playSong(_currentIndex);
    }
  }

  Future<void> next() => _handler.skipToNext();

  Future<void> previous() => _handler.skipToPrevious();

  Future<void> seekTo(Duration position) => _handler.seek(position);

  Future<void> seekRelative(int seconds) async {
    final newPos = _position + Duration(seconds: seconds);
    Duration clamped = newPos;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > _duration) clamped = _duration;
    await seekTo(clamped);
  }

  Future<void> setVolume(double val) async {
    final clamped = val.clamp(0.0, 1.0);
    await _handler.player.setVolume(clamped);
  }

  void toggleShuffle() {
    final newMode = _isShuffle
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all;
    _handler.setShuffleMode(newMode);
  }

  void toggleRepeat() {
    AudioServiceRepeatMode newMode;
    switch (_repeatMode) {
      case SongRepeat.off:
        newMode = AudioServiceRepeatMode.all;
      case SongRepeat.all:
        newMode = AudioServiceRepeatMode.one;
      case SongRepeat.one:
        newMode = AudioServiceRepeatMode.none;
    }
    _handler.setRepeatMode(newMode);
  }

  // ─── Menu helpers ───

  List<String> get artists {
    final set = <String>{};
    for (final s in _songs) {
      set.add(s.artist);
    }
    return set.toList()..sort();
  }

  List<String> get albums {
    final set = <String>{};
    for (final s in _songs) {
      set.add(s.album);
    }
    return set.toList()..sort();
  }

  List<Song> songsByArtist(String artist) =>
      _songs.where((s) => s.artist == artist).toList();

  List<Song> songsByAlbum(String album) =>
      _songs.where((s) => s.album == album).toList();

  List<Song> search(String query) {
    if (query.trim().isEmpty) return _songs;
    final q = query.toLowerCase();
    return _songs
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q),
        )
        .toList();
  }

  bool isFavorite(int songId) => _favoriteSongIds.contains(songId);

  Future<void> toggleFavorite(int songId) async {
    if (_favoriteSongIds.contains(songId)) {
      _favoriteSongIds.remove(songId);
    } else {
      _favoriteSongIds.add(songId);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'jalplay_favorites',
        _favoriteSongIds.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  // ─── Persistence ───

  Future<void> _saveState() async {
    if (!_stateLoaded) return;
    if (_playerState == PlayerState.stopped) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final song = currentSong;
      if (song != null) {
        await prefs.setString('jalplay_last_song_id', song.id.toString());
        await prefs.setInt('jalplay_last_position_ms', _position.inMilliseconds);
      }
      await prefs.setBool('jalplay_is_shuffle', _isShuffle);
      await prefs.setString('jalplay_repeat_mode', _repeatMode.name);
    } catch (e) {
      debugPrint('Error saving state: $e');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jalplay_sleep_timer', _sleepTimer.name);
      await prefs.setString('jalplay_sort_field', _sortField.name);
    } catch (e) {
      debugPrint('Error saving prefs: $e');
    }
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Settings
      final savedSleep = prefs.getString('jalplay_sleep_timer');
      if (savedSleep != null) {
        _sleepTimer = SleepTimerDuration.values.firstWhere(
          (e) => e.name == savedSleep,
          orElse: () => SleepTimerDuration.off,
        );
        if (_sleepTimer != SleepTimerDuration.off) {
          final minutes = switch (_sleepTimer) {
            SleepTimerDuration.fifteen => 15,
            SleepTimerDuration.thirty => 30,
            SleepTimerDuration.sixty => 60,
            _ => 0,
          };
          if (minutes > 0) {
            _sleepTimerInstance = Timer(
              Duration(minutes: minutes), _onSleepTimerFired);
          }
        }
      }
      final savedSort = prefs.getString('jalplay_sort_field');
      if (savedSort != null) {
        _sortField = SongSortField.values.firstWhere(
          (e) => e.name == savedSort,
          orElse: () => SongSortField.title,
        );
      }

      // Favorites
      final savedFavorites = prefs.getStringList('jalplay_favorites');
      if (savedFavorites != null) {
        _favoriteSongIds =
            savedFavorites.map((idStr) => int.parse(idStr)).toList();
      }

      // Shuffle
      final savedShuffle = prefs.getBool('jalplay_is_shuffle') ?? false;
      final shuffleMode =
          savedShuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
      await _handler.setShuffleMode(shuffleMode);

      // Repeat
      final savedRepeat = prefs.getString('jalplay_repeat_mode') ?? 'off';
      AudioServiceRepeatMode repeatMode;
      switch (savedRepeat) {
        case 'one':
          repeatMode = AudioServiceRepeatMode.one;
        case 'all':
          repeatMode = AudioServiceRepeatMode.all;
        default:
          repeatMode = AudioServiceRepeatMode.none;
      }
      await _handler.setRepeatMode(repeatMode);

      // Restore song & position
      final lastSongId = prefs.getString('jalplay_last_song_id');
      final lastPositionMs = prefs.getInt('jalplay_last_position_ms') ?? 0;
      if (lastSongId != null) {
        final idx = _songs.indexWhere((s) => s.id.toString() == lastSongId);
        if (idx >= 0) {
          _currentIndex = idx;
          _position = Duration(milliseconds: lastPositionMs);
          _duration = Duration(milliseconds: _songs[idx].duration);
          await _handler.prepareIndex(idx, Duration(milliseconds: lastPositionMs));
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading saved state: $e');
    } finally {
      _stateLoaded = true;
      await _saveState();
    }
  }

  Future<void> shutdown() async {
    await _handler.stop();
    exit(0);
  }

  @override
  void dispose() {
    _sleepTimerInstance?.cancel();
    _handler.disposePlayer();
    super.dispose();
  }
}
