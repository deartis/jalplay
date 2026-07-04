import 'dart:convert';

class Playlist {
  final String name;
  final List<int> songIds;

  const Playlist({
    required this.name,
    required this.songIds,
  });

  Playlist copyWith({String? name, List<int>? songIds}) {
    return Playlist(
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'songIds': songIds,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        name: json['name'] as String,
        songIds: (json['songIds'] as List).cast<int>(),
      );

  static String encodeList(List<Playlist> playlists) =>
      jsonEncode(playlists.map((p) => p.toJson()).toList());

  static List<Playlist> decodeList(String json) {
    final list = jsonDecode(json) as List;
    return list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
  }
}
