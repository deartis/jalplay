import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import 'status_header.dart';

class MenuList extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String>? subtitles;
  final int selectedIndex;
  final Function(int) onSelect;
  final bool Function(int)? isPlaying;

  const MenuList({
    super.key,
    required this.title,
    required this.items,
    this.subtitles,
    required this.selectedIndex,
    required this.onSelect,
    this.isPlaying,
  });

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(MenuList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    const itemHeight = 42.0;
    final offset = widget.selectedIndex * itemHeight;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          height: 24,
          color: const Color(0xFF0071C5),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Consumer<PlayerProvider>(
            builder: (context, provider, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const StatusBadges(),
                ],
              );
            },
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: widget.items.length,
            itemExtent: 42,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final isSelected = index == widget.selectedIndex;
              final playing = widget.isPlaying?.call(index) ?? false;

              return GestureDetector(
                onTap: () => widget.onSelect(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  color: isSelected
                      ? const Color(0xFF0071C5)
                      : index.isEven
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFF16162A),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      // Playing indicator
                      SizedBox(
                        width: 16,
                        child: playing
                            ? const Icon(
                                Icons.volume_up,
                                color: Color(0xFF00BFFF),
                                size: 12,
                              )
                            : null,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.items[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFDDEEFF),
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitles != null &&
                                index < widget.subtitles!.length)
                              Text(
                                widget.subtitles![index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white70
                                      : const Color(0xFF4A90A4),
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Arrow indicator
                      Icon(
                        Icons.chevron_right,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF0071C5),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom mini player bar
        Consumer<PlayerProvider>(
          builder: (context, provider, _) {
            if (provider.currentSong == null) return const SizedBox.shrink();
            return Container(
              height: 20,
              color: const Color(0xFF0F3460),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    provider.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: const Color(0xFF00BFFF),
                    size: 10,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      provider.currentSong!.title,
                      style: const TextStyle(
                        color: Color(0xFF00BFFF),
                        fontSize: 8,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Progress dot
                  SizedBox(
                    width: 40,
                    height: 3,
                    child: LinearProgressIndicator(
                      value: provider.progress,
                      backgroundColor: const Color(0xFF1A1A2E),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF0071C5)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
