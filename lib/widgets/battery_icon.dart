import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

class BatteryIcon extends StatefulWidget {
  final double size;
  final Color color;

  const BatteryIcon({
    super.key,
    this.size = 10.0,
    this.color = Colors.white,
  });

  @override
  State<BatteryIcon> createState() => _BatteryIconState();
}

class _BatteryIconState extends State<BatteryIcon> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  StreamSubscription<BatteryState>? _subscription;

  @override
  void initState() {
    super.initState();
    _getBatteryLevel();
    _subscription = _battery.onBatteryStateChanged.listen((state) {
      _getBatteryLevel();
      if (mounted) {
        setState(() {
          _batteryState = state;
        });
      }
    });
  }

  Future<void> _getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  IconData _getBatteryIcon() {
    if (_batteryState == BatteryState.charging) {
      return Icons.battery_charging_full;
    }
    if (_batteryLevel > 80) return Icons.battery_full;
    if (_batteryLevel > 50) return Icons.battery_4_bar;
    if (_batteryLevel > 20) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      _getBatteryIcon(),
      color: widget.color,
      size: widget.size,
    );
  }
}
