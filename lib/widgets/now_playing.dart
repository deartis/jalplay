import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart' show PlayerProvider, SongRepeat, ipodThemes;
import 'status_header.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  Uint8List? _artwork;
  int? _lastSongId;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadArtwork(PlayerProvider provider) async {
    final song = provider.currentSong;
    if (song == null) return;
    if (song.id == _lastSongId) return;
    _lastSongId = song.id;
    final art = await provider.getArtwork(song.id);
    if (mounted) setState(() => _artwork = art);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        // Sync animation with playing state
        if (provider.isPlaying && !_rotationController.isAnimating) {
          _rotationController.repeat();
        } else if (!provider.isPlaying && _rotationController.isAnimating) {
          _rotationController.stop();
        }

        // Load artwork lazily
        _loadArtwork(provider);

        final song = provider.currentSong;

        final theme = ipodThemes[provider.ipodTheme] ?? ipodThemes['classic']!;

        return Container(
          color: theme.screenBg,
          child: Column(
            children: [
              // ─── Header ───
              Container(
                height: 20,
                color: theme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tocando Agora',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const StatusBadges(),
                  ],
                ),
              ),

              // ─── Album Art ───
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RotationTransition(
                        turns: _rotationController,
                        child: Container(
                          width: 95,
                          height: 95,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.darkAccent,
                            border: Border.all(
                              color: theme.primary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primary.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _artwork != null
                                ? Image.memory(_artwork!, fit: BoxFit.cover)
                                : Icon(
                                    Icons.music_note,
                                    color: theme.primary,
                                    size: 50,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RetroVisualizer(
                        isPlaying: provider.isPlaying,
                        primaryColor: theme.primary,
                        accentColor: theme.accent,
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Song Info ───
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        song?.title ?? 'Nenhuma Música',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      // Artist
                      Text(
                        song?.artist ?? '',
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Album
                      Text(
                        song?.album ?? '',
                        style: TextStyle(
                          color: theme.subtitleColor,
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 10),

                      // ─── Progress ───
                      Row(
                        children: [
                          Text(
                            _formatDuration(provider.position),
                            style: TextStyle(
                              color: theme.accent,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: GestureDetector(
                                onHorizontalDragUpdate: (details) {
                                  final box = context.findRenderObject() as RenderBox;
                                  final dx = details.localPosition.dx / box.size.width;
                                  final newPos = provider.duration * dx.clamp(0.0, 1.0);
                                  provider.seekTo(newPos);
                                },
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: theme.darkAccent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: provider.progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            song != null
                                ? _formatDuration(provider.duration)
                                : '--:--',
                            style: TextStyle(
                              color: theme.accent,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ─── Controls row ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ControlButton(
                            icon: provider.isShuffle
                                ? Icons.shuffle
                                : Icons.shuffle,
                            color: provider.isShuffle
                                ? theme.accent
                                : theme.subtitleColor,
                            onTap: provider.toggleShuffle,
                          ),
                          _ControlButton(
                            icon: provider.repeatMode == SongRepeat.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: provider.repeatMode != SongRepeat.off
                                ? theme.accent
                                : theme.subtitleColor,
                            onTap: provider.toggleRepeat,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class RetroVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color primaryColor;
  final Color accentColor;

  const RetroVisualizer({
    super.key,
    required this.isPlaying,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  State<RetroVisualizer> createState() => _RetroVisualizerState();
}

class _RetroVisualizerState extends State<RetroVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights = List.filled(15, 2.0);
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addListener(() {
        if (widget.isPlaying) {
          setState(() {
            for (int i = 0; i < _barHeights.length; i++) {
              final target = _random.nextDouble() * 24.0 + 3.0;
              _barHeights[i] = _barHeights[i] * 0.4 + target * 0.6;
            }
          });
        } else {
          setState(() {
            for (int i = 0; i < _barHeights.length; i++) {
              _barHeights[i] = _barHeights[i] * 0.8 + 2.0 * 0.2;
            }
          });
        }
      });

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RetroVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      setState(() {
        for (int i = 0; i < _barHeights.length; i++) {
          _barHeights[i] = 2.0;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_barHeights.length, (index) {
          return Container(
            width: 3.5,
            height: _barHeights[index],
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  widget.primaryColor,
                  widget.accentColor,
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
