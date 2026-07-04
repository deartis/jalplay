import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'screens/ipod_screen.dart';
import 'services/audio_handler.dart';

class JalPlayApp extends StatelessWidget {
  final JalPlayAudioHandler handler;
  const JalPlayApp({super.key, required this.handler});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlayerProvider(handler),
      child: MaterialApp(
        title: 'JALPlay',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF0071C5),
            surface: const Color(0xFF1A1A2E),
          ),
          scaffoldBackgroundColor: const Color(0xFF111111),
          fontFamily: 'monospace',
        ),
        home: const IpodScreen(),
      ),
    );
  }
}
