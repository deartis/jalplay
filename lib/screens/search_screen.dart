import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../widgets/menu_list.dart';
import '../widgets/status_header.dart';

class SearchScreen extends StatefulWidget {
  final Function(int globalIndex) onSongSelected;

  const SearchScreen({super.key, required this.onSongSelected});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';
  List<Song> _results = [];
  int _selectedIndex = 0;

  void _onQueryChanged(String q, PlayerProvider provider) {
    setState(() {
      _query = q;
      _results = provider.search(q);
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        final theme = ipodThemes[provider.ipodTheme] ?? ipodThemes['classic']!;

        return Column(
          children: [
            // ─── Header ───
            Container(
              height: 20,
              color: theme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.search, color: Colors.white, size: 11),
                      SizedBox(width: 4),
                      Text(
                        'Buscar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const StatusBadges(),
                ],
              ),
            ),

            // ─── Search field ───
            Container(
              height: 28,
              color: theme.darkAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.search,
                      color: theme.subtitleColor, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      onChanged: (q) => _onQueryChanged(q, provider),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      cursorColor: theme.primary,
                      cursorWidth: 1.5,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Digite para buscar...',
                        hintStyle: TextStyle(
                          color: theme.subtitleColor,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () => _onQueryChanged('', provider),
                      child: Icon(Icons.clear,
                          color: theme.subtitleColor, size: 12),
                    ),
                ],
              ),
            ),

            // ─── Results ───
            Expanded(
              child: _query.isEmpty
                  ? Center(
                      child: Text(
                        'Busque por título,\nartista ou álbum',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.subtitleColor,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          height: 1.8,
                        ),
                      ),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum resultado para\n"$_query"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.subtitleColor,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              height: 1.8,
                            ),
                          ),
                        )
                      : MenuList(
                          title: '${_results.length} resultados',
                          items: _results.map((s) => s.title).toList(),
                          subtitles: _results.map((s) => s.artist).toList(),
                          selectedIndex: _selectedIndex,
                          onSelect: (i) {
                            setState(() => _selectedIndex = i);
                            final song = _results[i];
                            final globalIndex = provider.songs
                                .indexWhere((s) => s.id == song.id);
                            widget.onSongSelected(
                                globalIndex >= 0 ? globalIndex : i);
                          },
                          isPlaying: (i) =>
                              i < _results.length &&
                              provider.currentSong?.id == _results[i].id &&
                              provider.isPlaying,
                        ),
            ),
          ],
        );
      },
    );
  }
}
