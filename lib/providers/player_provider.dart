import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/playlist.dart';
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
  List<Song> _currentQueue = [];
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
  String _ipodTheme = 'classic';

  // Playlists
  List<Playlist> _playlists = [];

  // Getters
  List<Song> get songs => _songs;
  int get currentIndex => _currentIndex;
  Song? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _currentQueue.length
      ? _currentQueue[_currentIndex]
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
  String get ipodTheme => _ipodTheme;

  void setIpodTheme(String theme) {
    _ipodTheme = theme;
    notifyListeners();
    _savePrefs();
  }

  // Playlists
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<String> get playlistNames => _playlists.map((p) => p.name).toList();
  bool hasPlaylist(String name) => _playlists.any((p) => p.name == name);
  List<int> getPlaylistSongIds(String name) =>
      _playlists.firstWhere((p) => p.name == name).songIds;
  List<Song> getPlaylistSongs(String name) {
    final ids = getPlaylistSongIds(name).toSet();
    return _songs.where((s) => ids.contains(s.id)).toList();
  }

  bool isSongInPlaylist(String name, int songId) =>
      getPlaylistSongIds(name).contains(songId);

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
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
      if (index != null && index >= 0 && index < _currentQueue.length) {
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
      _sleepTimerInstance = Timer(
        Duration(minutes: minutes),
        _onSleepTimerFired,
      );
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
    if (_playerState == PlayerState.playing ||
        _playerState == PlayerState.paused) {
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
    _playlists = [];
    _ipodTheme = 'classic';

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

  // ─── Playlists ───

  void createPlaylist(String name) {
    if (name.trim().isEmpty) return;
    if (hasPlaylist(name)) return;
    _playlists.add(Playlist(name: name.trim(), songIds: []));
    notifyListeners();
    _savePrefs();
  }

  void deletePlaylist(String name) {
    _playlists.removeWhere((p) => p.name == name);
    notifyListeners();
    _savePrefs();
  }

  void addSongToPlaylist(String name, int songId) {
    final idx = _playlists.indexWhere((p) => p.name == name);
    if (idx < 0) return;
    if (_playlists[idx].songIds.contains(songId)) return;
    final updated = _playlists[idx].copyWith(
      songIds: [..._playlists[idx].songIds, songId],
    );
    _playlists[idx] = updated;
    notifyListeners();
    _savePrefs();
  }

  void removeSongFromPlaylist(String name, int songId) {
    final idx = _playlists.indexWhere((p) => p.name == name);
    if (idx < 0) return;
    final updated = _playlists[idx].copyWith(
      songIds: _playlists[idx].songIds.where((id) => id != songId).toList(),
    );
    _playlists[idx] = updated;
    notifyListeners();
    _savePrefs();
  }

  void renamePlaylist(String oldName, String newName) {
    if (newName.trim().isEmpty) return;
    if (oldName == newName) return;
    final idx = _playlists.indexWhere((p) => p.name == oldName);
    if (idx < 0) return;
    _playlists[idx] = _playlists[idx].copyWith(name: newName.trim());
    notifyListeners();
    _savePrefs();
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
    _currentQueue = List.from(_songs);
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

  Future<void> playSong(int index, {List<Song>? queue}) async {
    final targetQueue = queue ?? _songs;
    if (index < 0 || index >= targetQueue.length) return;

    bool queueChanged = _currentQueue.length != targetQueue.length;
    if (!queueChanged) {
      for (int i = 0; i < targetQueue.length; i++) {
        if (_currentQueue[i].id != targetQueue[i].id) {
          queueChanged = true;
          break;
        }
      }
    }

    if (queueChanged) {
      _currentQueue = List.from(targetQueue);
      final mediaItems = _currentQueue
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
        await prefs.setInt(
          'jalplay_last_position_ms',
          _position.inMilliseconds,
        );
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
      await prefs.setString('jalplay_ipod_theme', _ipodTheme);
      await prefs.setString(
        'jalplay_playlists',
        Playlist.encodeList(_playlists),
      );
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
              Duration(minutes: minutes),
              _onSleepTimerFired,
            );
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
      _ipodTheme = prefs.getString('jalplay_ipod_theme') ?? 'classic';

      // Playlists
      final savedPlaylists = prefs.getString('jalplay_playlists');
      if (savedPlaylists != null && savedPlaylists.isNotEmpty) {
        _playlists = Playlist.decodeList(savedPlaylists);
      }

      // Favorites
      final savedFavorites = prefs.getStringList('jalplay_favorites');
      if (savedFavorites != null) {
        _favoriteSongIds = savedFavorites
            .map((idStr) => int.parse(idStr))
            .toList();
      }

      // Shuffle
      final savedShuffle = prefs.getBool('jalplay_is_shuffle') ?? false;
      final shuffleMode = savedShuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none;
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
          await _handler.prepareIndex(
            idx,
            Duration(milliseconds: lastPositionMs),
          );
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

class IpodThemeData {
  final List<Color> bodyGradient;
  final List<Color> wheelGradient;
  final Color wheelLabelColor;
  final List<Color> wheelCenterGradient;

  // Display screen theme colors
  final Color screenBg;
  final Color screenBgAlt;
  final Color primary;
  final Color accent;
  final Color darkAccent;
  final Color subtitleColor;

  const IpodThemeData({
    required this.bodyGradient,
    required this.wheelGradient,
    required this.wheelLabelColor,
    required this.wheelCenterGradient,
    required this.screenBg,
    required this.screenBgAlt,
    required this.primary,
    required this.accent,
    required this.darkAccent,
    required this.subtitleColor,
  });
}

const Map<String, IpodThemeData> ipodThemes = {
  'classic': IpodThemeData(
    bodyGradient: [Color(0xFFF8F8F8), Color(0xFFE8E8E8), Color(0xFFD8D8D8)],
    wheelGradient: [Color(0xFFFAFAFA), Color(0xFFDFDFDF), Color(0xFFC4C4C4)],
    wheelLabelColor: Color(0xFF0071C5),
    wheelCenterGradient: [
      Color(0xFFF5F5F5),
      Color(0xFFDDDDDD),
      Color(0xFFC8C8C8),
    ],
    screenBg: Color(0xFF1A1A2E),
    screenBgAlt: Color(0xFF16162A),
    primary: Color(0xFF0071C5),
    accent: Color(0xFF00BFFF),
    darkAccent: Color(0xFF0F3460),
    subtitleColor: Color(0xFF4A90A4),
  ),
  'charcoal': IpodThemeData(
    bodyGradient: [Color(0xFF404040), Color(0xFF282828), Color(0xFF181818)],
    wheelGradient: [Color(0xFF383838), Color(0xFF242424), Color(0xFF1C1C1C)],
    wheelLabelColor: Color(0xFF00A300),
    wheelCenterGradient: [
      Color(0xFF4A4A4A),
      Color(0xFF333333),
      Color(0xFF222222),
    ],
    screenBg: Color(0xFF0D1B0D),
    screenBgAlt: Color(0xFF081408),
    primary: Color(0xFF00A300),
    accent: Color(0xFF39FF14),
    darkAccent: Color(0xFF002200),
    subtitleColor: Color(0xFF008000),
  ),
  'cobalt': IpodThemeData(
    bodyGradient: [Color(0xFF0A4D68), Color(0xFF088395), Color(0xFF05BFDB)],
    wheelGradient: [Color(0xFF0E2954), Color(0xFF0A4D68), Color(0xFF088395)],
    wheelLabelColor: Colors.white,
    wheelCenterGradient: [
      Color(0xFF088395),
      Color(0xFF0A4D68),
      Color(0xFF05BFDB),
    ],
    screenBg: Color(0xFF0E1A2F),
    screenBgAlt: Color(0xFF0A1426),
    primary: Color(0xFF0A4D68),
    accent: Color(0xFF05BFDB),
    darkAccent: Color(0xFF088395),
    subtitleColor: Color(0xFF4A90A4),
  ),
  'rose': IpodThemeData(
    bodyGradient: [Color(0xFFFFB6C1), Color(0xFFFF69B4), Color(0xFFFF1493)],
    wheelGradient: [Color(0xFFFFF0F5), Color(0xFFFFB6C1), Color(0xFFFF69B4)],
    wheelLabelColor: Color(0xFFFF1493),
    wheelCenterGradient: [
      Color(0xFFFFF0F5),
      Color(0xFFFFC0CB),
      Color(0xFFFFB6C1),
    ],
    screenBg: Color(0xFF2B0A1A),
    screenBgAlt: Color(0xFF200713),
    primary: Color(0xFFC71585),
    accent: Color(0xFFFF69B4),
    darkAccent: Color(0xFF4A0E2E),
    subtitleColor: Color(0xFFFFB6C1),
  ),
  'u2': IpodThemeData(
    bodyGradient: [Color(0xFF262626), Color(0xFF161616), Color(0xFF0A0A0A)],
    wheelGradient: [Color(0xFF303030), Color(0xFF1F1F1F), Color(0xFF101010)],
    wheelLabelColor: Color(0xFFFF0000),
    wheelCenterGradient: [
      Color(0xFFFF0000),
      Color(0xFFCC0000),
      Color(0xFF990000),
    ],
    screenBg: Color(0xFF140505),
    screenBgAlt: Color(0xFF0A0202),
    primary: Color(0xFFCC0000),
    accent: Color(0xFFFF3333),
    darkAccent: Color(0xFF4A0000),
    subtitleColor: Color(0xFFFF6666),
  ),
};
