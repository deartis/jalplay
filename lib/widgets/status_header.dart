import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart' show PlayerProvider, SongRepeat, PlayerState;
import 'battery_icon.dart';

class StatusBadges extends StatelessWidget {
  final double size;
  const StatusBadges({super.key, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        final children = <Widget>[];
        if (provider.isShuffle) {
          children.add(_badge(Icons.shuffle, size));
        }
        if (provider.repeatMode != SongRepeat.off) {
          children.add(_badge(
            provider.repeatMode == SongRepeat.one
                ? Icons.repeat_one
                : Icons.repeat,
            size,
          ));
        }
        if (provider.isPlaying) {
          children.add(_badge(Icons.play_arrow, size));
        } else if (provider.playerState == PlayerState.paused) {
          children.add(_badge(Icons.pause, size));
        }
        children.add(const BatteryIcon(size: 9, color: Colors.white));
        return Row(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }

  Widget _badge(IconData icon, double size) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}
