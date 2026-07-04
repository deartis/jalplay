import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../widgets/ipod_body.dart';

class IpodScreen extends StatefulWidget {
  const IpodScreen({super.key});

  @override
  State<IpodScreen> createState() => _IpodScreenState();
}

class _IpodScreenState extends State<IpodScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final provider = context.read<PlayerProvider>();
    final granted = await provider.requestPermission();
    if (granted) {
      await provider.loadSongs();
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          if (!_initialized) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0071C5)),
                  SizedBox(height: 16),
                  Text(
                    'JALPlay',
                    style: TextStyle(
                      color: Color(0xFF0071C5),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            );
          }

          if (!provider.hasPermission) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF0071C5),
                      size: 64,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'O JALPlay precisa de permissão\npara acessar sua biblioteca de músicas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0071C5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _init,
                      child: const Text('Conceder Permissão'),
                    ),
                  ],
                ),
              ),
            );
          }

          return const SafeArea(child: IpodBody());
        },
      ),
    );
  }
}
