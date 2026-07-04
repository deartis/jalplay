import 'package:on_audio_query/on_audio_query.dart';

class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final int duration; // milliseconds
  final String? data; // file path
  final int? albumId;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.data,
    this.albumId,
  });

  factory Song.fromSongModel(SongModel model) {
    return Song(
      id: model.id,
      title: model.title,
      artist: model.artist ?? 'Artista Desconhecido',
      album: model.album ?? 'Álbum Desconhecido',
      duration: model.duration ?? 0,
      data: model.data,
      albumId: model.albumId,
    );
  }

  String get durationFormatted {
    final totalSeconds = (duration / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => 'Song($title - $artist)';
}
