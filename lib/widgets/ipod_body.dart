import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../screens/search_screen.dart';
import 'click_wheel.dart';
import 'menu_list.dart';
import 'now_playing.dart';

enum MenuScreen {
  main,
  music,
  allSongs,
  artists,
  artistSongs,
  albums,
  albumSongs,
  search,
  nowPlaying,
  favorites,
  settings,
  settingsOptions,
  about,
}

class IpodBody extends StatefulWidget {
  const IpodBody({super.key});

  @override
  State<IpodBody> createState() => _IpodBodyState();
}

class _IpodBodyState extends State<IpodBody> {
  MenuScreen _screen = MenuScreen.main;
  int _selectedIndex = 0;
  String? _selectedArtist;
  String? _selectedAlbum;

  bool _showVolumeOverlay = false;
  Timer? _volumeOverlayTimer;

  final List<MenuScreen> _history = [];
  bool _slidingForward = true;

  // Settings state
  String? _settingsCategory; // sleepTimer, equalizer, sorting, crossfade
  bool _showConfirmReset = false;

  final List<String> _mainMenuItems = [
    'Música',
    'Buscar',
    'Tocando Agora',
    'Configurações',
    'Desligar',
  ];
  final List<String> _musicMenuItems = [
    'Todas as Músicas',
    'Artistas',
    'Álbuns',
    'Favoritos'
  ];
  final List<String> _settingsMenuItems = [
    'Temporizador',
    'Ordenar',
    'Atualizar Biblioteca',
    'Sobre',
    'Redefinir Ajustes',
  ];

  final Map<String, List<String>> _settingsOptions = {
    'sleepTimer': sleepTimerLabels,
    'sorting': sortFieldLabels,
  };

  bool _showFavFeedback = false;
  bool _isAddedFav = false;
  Timer? _favFeedbackTimer;

  void _navigateTo(MenuScreen screen) {
    setState(() {
      _slidingForward = true;
      _history.add(_screen);
      _screen = screen;
      _selectedIndex = 0;
    });
  }

  void _navigateBack() {
    if (_history.isEmpty) return;
    setState(() {
      _slidingForward = false;
      _screen = _history.removeLast();
      _selectedIndex = 0;
    });
  }

  int _getMaxIndex(PlayerProvider provider) {
    switch (_screen) {
      case MenuScreen.main:
        return _mainMenuItems.length - 1;
      case MenuScreen.music:
        return _musicMenuItems.length - 1;
      case MenuScreen.allSongs:
        return provider.songs.length - 1;
      case MenuScreen.artists:
        return provider.artists.length - 1;
      case MenuScreen.artistSongs:
        return (_selectedArtist != null
                    ? provider.songsByArtist(_selectedArtist!)
                    : provider.songs)
                .length -
            1;
      case MenuScreen.albums:
        return provider.albums.length - 1;
      case MenuScreen.albumSongs:
        return (_selectedAlbum != null
                    ? provider.songsByAlbum(_selectedAlbum!)
                    : provider.songs)
                .length -
            1;
      case MenuScreen.favorites:
        final count = provider.favoriteSongs.length;
        return count == 0 ? 0 : count - 1;
      case MenuScreen.settings:
        return _settingsMenuItems.length - 1;
      case MenuScreen.settingsOptions:
        final options = _settingsOptions[_settingsCategory];
        return (options?.length ?? 1) - 1;
      case MenuScreen.about:
      case MenuScreen.search:
      case MenuScreen.nowPlaying:
        return 0;
    }
  }

  @override
  void dispose() {
    _volumeOverlayTimer?.cancel();
    _favFeedbackTimer?.cancel();
    super.dispose();
  }

  void _showFavoriteFeedback(bool isAdded) {
    setState(() {
      _showFavFeedback = true;
      _isAddedFav = isAdded;
    });
    _favFeedbackTimer?.cancel();
    _favFeedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showFavFeedback = false;
        });
      }
    });
  }

  Song? _getSelectedSong(PlayerProvider provider) {
    switch (_screen) {
      case MenuScreen.allSongs:
        if (provider.songs.isEmpty) return null;
        return provider.songs[_selectedIndex];
      case MenuScreen.artistSongs:
        final songs = provider.songsByArtist(_selectedArtist ?? '');
        if (songs.isEmpty) return null;
        return songs[_selectedIndex];
      case MenuScreen.albumSongs:
        final songs = provider.songsByAlbum(_selectedAlbum ?? '');
        if (songs.isEmpty) return null;
        return songs[_selectedIndex];
      case MenuScreen.favorites:
        final songs = provider.favoriteSongs;
        if (songs.isEmpty) return null;
        return songs[_selectedIndex];
      default:
        return null;
    }
  }

  void _onCenterLongPress() {
    final provider = context.read<PlayerProvider>();
    final song = _getSelectedSong(provider);
    if (song != null) {
      provider.toggleFavorite(song.id);

      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.mediumImpact();
      });

      _showFavoriteFeedback(provider.isFavorite(song.id));
    }
  }

  void _onScroll(double delta) {
    final provider = context.read<PlayerProvider>();
    if (_screen == MenuScreen.nowPlaying && !_showConfirmReset) {
      final newVolume = (provider.volume + (delta * 0.05)).clamp(0.0, 1.0);
      provider.setVolume(newVolume);

      setState(() {
        _showVolumeOverlay = true;
      });
      _volumeOverlayTimer?.cancel();
      _volumeOverlayTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _showVolumeOverlay = false;
          });
        }
      });
      return;
    }

    final max = _getMaxIndex(provider);
    if (max < 0) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta.round()).clamp(0, max);
    });
  }

  void _onCenterPress() {
    final provider = context.read<PlayerProvider>();
    switch (_screen) {
      case MenuScreen.main:
        _selectMainMenuItem(_selectedIndex, provider);
      case MenuScreen.music:
        _selectMusicMenuItem(_selectedIndex);
      case MenuScreen.allSongs:
        provider.playSong(_selectedIndex);
        _navigateTo(MenuScreen.nowPlaying);
      case MenuScreen.artists:
        _selectedArtist = provider.artists[_selectedIndex];
        _navigateTo(MenuScreen.artistSongs);
      case MenuScreen.artistSongs:
        final songs = provider.songsByArtist(_selectedArtist!);
        final globalIdx = provider.songs.indexWhere(
          (s) => s.id == songs[_selectedIndex].id,
        );
        provider.playSong(globalIdx >= 0 ? globalIdx : _selectedIndex);
        _navigateTo(MenuScreen.nowPlaying);
      case MenuScreen.albums:
        _selectedAlbum = provider.albums[_selectedIndex];
        _navigateTo(MenuScreen.albumSongs);
      case MenuScreen.albumSongs:
        final songs = provider.songsByAlbum(_selectedAlbum!);
        final globalIdx = provider.songs.indexWhere(
          (s) => s.id == songs[_selectedIndex].id,
        );
        provider.playSong(globalIdx >= 0 ? globalIdx : _selectedIndex);
        _navigateTo(MenuScreen.nowPlaying);
      case MenuScreen.favorites:
        final songs = provider.favoriteSongs;
        if (songs.isEmpty) break;
        final globalIdx = provider.songs.indexWhere(
          (s) => s.id == songs[_selectedIndex].id,
        );
        provider.playSong(globalIdx >= 0 ? globalIdx : _selectedIndex);
        _navigateTo(MenuScreen.nowPlaying);
      case MenuScreen.settings:
        _selectSettingsMenuItem(_selectedIndex, provider);
      case MenuScreen.settingsOptions:
        _selectSettingsOption(_selectedIndex, provider);
      case MenuScreen.about:
      case MenuScreen.search:
      case MenuScreen.nowPlaying:
        break;
    }
  }

  void _selectMainMenuItem(int index, PlayerProvider provider) {
    switch (index) {
      case 0:
        _navigateTo(MenuScreen.music);
      case 1:
        _navigateTo(MenuScreen.search);
      case 2:
        if (provider.currentSong != null) {
          _navigateTo(MenuScreen.nowPlaying);
        }
      case 3:
        _navigateTo(MenuScreen.settings);
      case 4:
        provider.shutdown();
    }
  }

  void _selectMusicMenuItem(int index) {
    switch (index) {
      case 0:
        _navigateTo(MenuScreen.allSongs);
      case 1:
        _navigateTo(MenuScreen.artists);
      case 2:
        _navigateTo(MenuScreen.albums);
      case 3:
        _navigateTo(MenuScreen.favorites);
    }
  }

  void _selectSettingsMenuItem(int index, PlayerProvider provider) {
    switch (index) {
      case 0: // Sleep Timer
        _settingsCategory = 'sleepTimer';
        _navigateTo(MenuScreen.settingsOptions);
      case 1: // Sorting
        _settingsCategory = 'sorting';
        _navigateTo(MenuScreen.settingsOptions);
      case 2: // Rescan Library
        provider.rescanLibrary();
        _navigateBack();
      case 3: // About
        _navigateTo(MenuScreen.about);
      case 4: // Reset Settings
        _showConfirmReset = true;
        setState(() {});
    }
  }

  void _selectSettingsOption(int index, PlayerProvider provider) {
    switch (_settingsCategory) {
      case 'sleepTimer':
        provider.setSleepTimer(SleepTimerDuration.values[index]);
      case 'sorting':
        provider.setSortField(SongSortField.values[index]);
    }
    _navigateBack();
  }

  void _onMenu() {
    if (_showConfirmReset) {
      setState(() => _showConfirmReset = false);
      return;
    }
    if (_history.isNotEmpty) {
      _navigateBack();
    }
  }

  int _selectedOptionIndex(PlayerProvider provider) {
    switch (_settingsCategory) {
      case 'sleepTimer':
        return SleepTimerDuration.values.indexOf(provider.sleepTimer);
      case 'sorting':
        return SongSortField.values.indexOf(provider.sortField);
      default:
        return 0;
    }
  }

  Widget _buildScreenContent(PlayerProvider provider) {
    switch (_screen) {
      case MenuScreen.main:
        return MenuList(
          key: const ValueKey('main'),
          title: 'JALPlay',
          items: _mainMenuItems,
          selectedIndex: _selectedIndex,
          onSelect: (i) {
            setState(() => _selectedIndex = i);
            _onCenterPress();
          },
        );

      case MenuScreen.music:
        return MenuList(
          key: const ValueKey('music'),
          title: 'Música',
          items: _musicMenuItems,
          selectedIndex: _selectedIndex,
          onSelect: (i) {
            setState(() => _selectedIndex = i);
            _onCenterPress();
          },
        );

      case MenuScreen.allSongs:
        return MenuList(
          key: const ValueKey('allSongs'),
          title: 'Todas as Músicas',
          items: provider.songs.map((s) => s.title).toList(),
          subtitles: provider.songs.map((s) => s.artist).toList(),
          selectedIndex: _selectedIndex,
          onSelect: (i) {
            setState(() => _selectedIndex = i);
            _onCenterPress();
          },
          isPlaying: (i) => provider.currentIndex == i && provider.isPlaying,
        );

      case MenuScreen.artists:
        return MenuList(
          key: const ValueKey('artists'),
          title: 'Artistas',
          items: provider.artists,
          selectedIndex: _selectedIndex,
          onSelect: (i) {
            setState(() => _selectedIndex = i);
            _onCenterPress();
          },
        );

      case MenuScreen.artistSongs:
        final songs = provider.songsByArtist(_selectedArtist ?? '');
        return MenuList(
          key: ValueKey('artistSongs_$_selectedArtist'),
          title: _selectedArtist ?? 'Músicas',
          items: songs.map((s) => s.title).toList(),
          subtitles: songs.map((s) => s.album).toList(),
          selectedIndex: _selectedIndex,
          onSelect: (i) {
            setState(() => _selectedIndex = i);
            _onCenterPress();
          },
          isPlaying: (i) =>
              i < songs.length &&
              provider.currentSong?.id == songs[i].id &&
              provider.isPlaying,
        );

      case MenuScreen.favorites:
        final songs = provider.favoriteSongs;
        return MenuList(
          key: const ValueKey('favorites'),
          title: 'Favoritos',
          items: songs.isEmpty
              ? ['Nenhum favorito ainda']
              : songs.map((s) => s.title).toList(),
          subtitles: songs.isEmpty
              ? null
              : songs.map((s) => s.artist).toList(),
          selectedIndex: _selectedIndex,
          onSelect: (i) {
            if (songs.isEmpty) return;
            setState(() => _selectedIndex = i);
            _onCenterPress();
          },
          isPlaying: (i) =>
              songs.isNotEmpty &&
              i < songs.length &&
              provider.currentSong?.id == songs[i].id &&
              provider.isPlaying,
        );

      case MenuScreen.albums:
        return MenuList(
          key: const ValueKey('albums'),
          title: 'Álbuns',
          items: provider.albums,
          selectedIndex: _selectedIndex,
          onSelect: (i) {
            setState(() => _selectedIndex = i);
            _onCenterPress();
          },
        );

      case MenuScreen.albumSongs:
        final songs = provider.songsByAlbum(_selectedAlbum ?? '');
        return MenuList(
          key: ValueKey('albumSongs_$_selectedAlbum'),
          title: _selectedAlbum ?? 'Músicas',
          items: songs.map((s) => s.title).toList(),
          subtitles: songs.map((s) => s.artist).toList(),
          selectedIndex: _selectedIndex,
          onSelect: (i) {
            setState(() => _selectedIndex = i);
            _onCenterPress();
          },
          isPlaying: (i) =>
              i < songs.length &&
              provider.currentSong?.id == songs[i].id &&
              provider.isPlaying,
        );

      case MenuScreen.search:
        return SearchScreen(
          key: const ValueKey('search'),
          onSongSelected: (globalIndex) {
            provider.playSong(globalIndex);
            _navigateTo(MenuScreen.nowPlaying);
          },
        );

      case MenuScreen.nowPlaying:
        return const NowPlayingScreen(key: ValueKey('nowPlaying'));

      case MenuScreen.settings:
        return _buildSettingsMenu();

      case MenuScreen.settingsOptions:
        return _buildSettingsOptions(provider);

      case MenuScreen.about:
        return _buildAboutScreen();
    }
  }

  Widget _buildSettingsMenu() {
    final provider = context.read<PlayerProvider>();
    final items = List<String>.from(_settingsMenuItems);

    // Show sleep timer status
    if (provider.isSleepTimerActive) {
      final mins = switch (provider.sleepTimer) {
        SleepTimerDuration.fifteen => 15,
        SleepTimerDuration.thirty => 30,
        SleepTimerDuration.sixty => 60,
        _ => 0,
      };
      items[0] = 'Temporizador ($mins min)';
    }

    // Show current sort
    items[1] = 'Ordenar (${sortFieldLabels[SongSortField.values.indexOf(provider.sortField)]})';

    return MenuList(
      key: const ValueKey('settings'),
      title: 'Configurações',
      items: items,
      selectedIndex: _selectedIndex,
      onSelect: (i) {
        setState(() => _selectedIndex = i);
        _onCenterPress();
      },
    );
  }

  Widget _buildSettingsOptions(PlayerProvider provider) {
    const categoryTitles = {
      'sleepTimer': 'Temporizador',
      'sorting': 'Ordenar',
    };
    final options = _settingsOptions[_settingsCategory] ?? [];
    final selected = _selectedOptionIndex(provider);

    return MenuList(
      key: ValueKey('settings_$_settingsCategory'),
      title: categoryTitles[_settingsCategory] ?? '',
      items: options,
      selectedIndex: _selectedIndex,
      onSelect: (i) {
        setState(() => _selectedIndex = i);
        _onCenterPress();
      },
      subtitles: options.asMap().entries.map((e) {
        return e.key == selected ? '✓' : '';
      }).toList(),
    );
  }

  Widget _buildAboutScreen() {
    return Column(
      children: [
        Container(
          height: 20,
          color: const Color(0xFF0071C5),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Row(
            children: [
              Text(
                'Sobre',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'JALPlay',
                    style: TextStyle(
                      color: Color(0xFF0071C5),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: Color(0xFF4A90A4),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Reprodutor MP3 estilo iPod\npara Android',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF87CEEB),
                      fontSize: 9,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '☕ Pague um café (PIX):',
                    style: TextStyle(
                      color: Color(0xFF00BFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F3460),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF0071C5), width: 0.8),
                    ),
                    child: const SelectableText(
                      '7b16efd5-bf9d-438c-b48c-e30419704613',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Feito com Flutter & just_audio',
                    style: TextStyle(
                      color: Color(0xFF4A90A4),
                      fontSize: 8,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        return Center(
          child: AspectRatio(
            aspectRatio: 0.52,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8F8F8),
                    Color(0xFFE8E8E8),
                    Color(0xFFD8D8D8),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 10,
                    offset: const Offset(-3, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // ─── Logo bar ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF888888),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'JALPlay',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF888888),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── LCD Screen ───
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF888888),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 2,
                              spreadRadius: 2,
                              blurStyle: BlurStyle.solid,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) {
                                  final isNew =
                                      child.key == ValueKey(_screen.name);
                                  final beginOffset = isNew
                                      ? Offset(_slidingForward ? 1.0 : -1.0, 0)
                                      : Offset(_slidingForward ? -1.0 : 1.0, 0);
                                  return SlideTransition(
                                    position: Tween<Offset>(
                                      begin: beginOffset,
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeInOut,
                                      ),
                                    ),
                                    child: child,
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey(_screen.name),
                                  child: _buildScreenContent(provider),
                                ),
                              ),
                              if (_showVolumeOverlay)
                                _buildVolumeOverlay(provider),
                              if (_showFavFeedback)
                                _buildFavFeedbackOverlay(),
                              if (_showConfirmReset)
                                _buildResetConfirmOverlay(provider),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Click Wheel ───
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.85,
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: ClickWheel(
                            onMenu: _onMenu,
                            onRewind: provider.previous,
                            onPlayPause: provider.togglePlayPause,
                            onFastForward: provider.next,
                            onCenterPress: _onCenterPress,
                            onCenterLongPress: _onCenterLongPress,
                            onScroll: _onScroll,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVolumeOverlay(PlayerProvider provider) {
    final volume = provider.volume;
    IconData iconData = Icons.volume_up;
    if (volume == 0) {
      iconData = Icons.volume_mute;
    } else if (volume < 0.5) {
      iconData = Icons.volume_down;
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: AnimatedOpacity(
        opacity: _showVolumeOverlay ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xEC111122),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF0071C5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(iconData, color: const Color(0xFF87CEEB), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: volume,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0071C5),
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0071C5), Color(0xFF00BFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavFeedbackOverlay() {
    return Positioned(
      left: 32,
      right: 32,
      top: 60,
      child: AnimatedOpacity(
        opacity: _showFavFeedback ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xEC111122),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF0071C5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isAddedFav ? Icons.favorite : Icons.favorite_border,
                color: Colors.redAccent,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                _isAddedFav ? 'Adicionado aos Favoritos' : 'Removido dos Favoritos',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResetConfirmOverlay(PlayerProvider provider) {
    return Positioned(
      left: 24,
      right: 24,
      top: 40,
      bottom: 40,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xEC111122),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF0071C5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Redefinir todos os ajustes\ne favoritos?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                provider.resetSettings();
                setState(() => _showConfirmReset = false);
                _navigateBack();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0071C5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                    'SIM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showConfirmReset = false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF4A90A4),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
