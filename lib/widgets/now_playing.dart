import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart' show PlayerProvider, SongRepeat;
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

        return Container(
          color: const Color(0xFF1A1A2E),
          child: Column(
            children: [
              // ─── Header ───
              Container(
                height: 20,
                color: const Color(0xFF0071C5),
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
                  child: RotationTransition(
                    turns: _rotationController,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F3460),
                        border: Border.all(
                          color: const Color(0xFF0071C5),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0071C5).withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _artwork != null
                            ? Image.memory(_artwork!, fit: BoxFit.cover)
                            : const Icon(
                                Icons.music_note,
                                color: Color(0xFF0071C5),
                                size: 60,
                              ),
                      ),
                    ),
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
                        style: const TextStyle(
                          color: Color(0xFF87CEEB),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Album
                      Text(
                        song?.album ?? '',
                        style: const TextStyle(
                          color: Color(0xFF4A90A4),
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
                            style: const TextStyle(
                              color: Color(0xFF87CEEB),
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
                                    color: const Color(0xFF0F3460),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: provider.progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0071C5),
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
                            style: const TextStyle(
                              color: Color(0xFF87CEEB),
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
                                ? const Color(0xFF00BFFF)
                                : const Color(0xFF4A90A4),
                            onTap: provider.toggleShuffle,
                          ),
                          _ControlButton(
                            icon: provider.repeatMode == SongRepeat.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: provider.repeatMode != SongRepeat.off
                                ? const Color(0xFF00BFFF)
                                : const Color(0xFF4A90A4),
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
