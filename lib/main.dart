import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure AudioSession for background music playback
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Full screen immersive mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF111111),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize audio service for background playback
  final handler = await AudioService.init(
    builder: () => JalPlayAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.jalplay.jalplay.audio',
      androidNotificationChannelName: 'JALPlay',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
      notificationColor: Color(0xFF0071C5),
      androidNotificationIcon: 'drawable/ic_stat_music_note',
    ),
  );

  runApp(JalPlayApp(handler: handler));
}
