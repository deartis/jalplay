import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum WheelRegion { menu, rewind, playPause, fastForward, center }

class ClickWheel extends StatefulWidget {
  final VoidCallback? onMenu;
  final VoidCallback? onRewind;
  final VoidCallback? onPlayPause;
  final VoidCallback? onFastForward;
  final VoidCallback? onCenterPress;
  final VoidCallback? onCenterLongPress;
  final Function(double delta)? onScroll;

  const ClickWheel({
    super.key,
    this.onMenu,
    this.onRewind,
    this.onPlayPause,
    this.onFastForward,
    this.onCenterPress,
    this.onCenterLongPress,
    this.onScroll,
  });

  @override
  State<ClickWheel> createState() => _ClickWheelState();
}

class _ClickWheelState extends State<ClickWheel>
    with SingleTickerProviderStateMixin {
  WheelRegion? _pressedRegion;
  double? _lastAngle;
  double _accumulatedDelta = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _centerLongPressTimer;
  bool _isLongPressActive = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _centerLongPressTimer?.cancel();
    super.dispose();
  }

  WheelRegion? _getRegion(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final centerRadius = radius * 0.38;
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < centerRadius) return WheelRegion.center;
    if (distance > radius) return null; // outside

    // Determine sector (angle from top, clockwise)
    final angle = math.atan2(dy, dx) * 180 / math.pi + 90;
    final normalized = (angle + 360) % 360;

    // Menu = top (315-45°), Rewind = left (225-315°)
    // Play = bottom (135-225°), FastForward = right (45-135°)
    if (normalized >= 315 || normalized < 45) return WheelRegion.menu;
    if (normalized >= 45 && normalized < 135) return WheelRegion.fastForward;
    if (normalized >= 135 && normalized < 225) return WheelRegion.playPause;
    return WheelRegion.rewind;
  }

  double _getAngle(Offset pos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    return math.atan2(pos.dy - center.dy, pos.dx - center.dx);
  }

  bool _isOnRing(Offset pos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final centerRadius = radius * 0.38;
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    return distance > centerRadius && distance <= radius;
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  void _onTapDown(TapDownDetails details, BoxConstraints constraints) {
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    final region = _getRegion(details.localPosition, size);
    if (region == null) return;
    setState(() => _pressedRegion = region);
    _pulseController.forward();
    _triggerHaptic();

    if (region == WheelRegion.center) {
      _isLongPressActive = false;
      _centerLongPressTimer?.cancel();
      _centerLongPressTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && _pressedRegion == WheelRegion.center) {
          setState(() {
            _isLongPressActive = true;
          });
          widget.onCenterLongPress?.call();
        }
      });
    }
  }

  void _onTapUp(TapUpDetails details, BoxConstraints constraints) {
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    final region = _getRegion(details.localPosition, size);

    _centerLongPressTimer?.cancel();

    if (region != null) {
      if (region == WheelRegion.center && _isLongPressActive) {
        _isLongPressActive = false;
      } else {
        switch (region) {
          case WheelRegion.menu:
            widget.onMenu?.call();
            break;
          case WheelRegion.rewind:
            widget.onRewind?.call();
            break;
          case WheelRegion.playPause:
            widget.onPlayPause?.call();
            break;
          case WheelRegion.fastForward:
            widget.onFastForward?.call();
            break;
          case WheelRegion.center:
            widget.onCenterPress?.call();
            break;
        }
      }
    }

    _pulseController.reverse();
    setState(() {
      _pressedRegion = null;
      _lastAngle = null;
      _isLongPressActive = false;
    });
  }

  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    _centerLongPressTimer?.cancel();
    _isLongPressActive = false;
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    if (_isOnRing(details.localPosition, size)) {
      _lastAngle = _getAngle(details.localPosition, size);
      _accumulatedDelta = 0;
    }
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_lastAngle == null) return;
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    if (!_isOnRing(details.localPosition, size)) return;

    final currentAngle = _getAngle(details.localPosition, size);
    double delta = currentAngle - _lastAngle!;

    // Handle angle wrap-around
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    _accumulatedDelta += delta;
    _lastAngle = currentAngle;

    // Trigger scroll every ~15 degrees
    if (_accumulatedDelta.abs() > 0.26) {
      _triggerHaptic();
      widget.onScroll?.call(_accumulatedDelta > 0 ? 1.0 : -1.0);
      _accumulatedDelta = 0;
    }
  }

  void _onPanEnd(DragEndDetails _) {
    _lastAngle = null;
    _accumulatedDelta = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (d) => _onTapDown(d, constraints),
          onTapUp: (d) => _onTapUp(d, constraints),
          onTapCancel: () {
            _centerLongPressTimer?.cancel();
            _pulseController.reverse();
            setState(() {
              _pressedRegion = null;
              _isLongPressActive = false;
            });
          },
          onPanStart: (d) => _onPanStart(d, constraints),
          onPanUpdate: (d) => _onPanUpdate(d, constraints),
          onPanEnd: _onPanEnd,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) => Transform.scale(
              scale: _pressedRegion == WheelRegion.center
                  ? _pulseAnimation.value
                  : 1.0,
              child: child,
            ),
            child: CustomPaint(
              painter: _ClickWheelPainter(pressedRegion: _pressedRegion),
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClickWheelPainter extends CustomPainter {
  final WheelRegion? pressedRegion;

  _ClickWheelPainter({this.pressedRegion});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final centerRadius = radius * 0.38;

    // ─── Outer wheel ring ───
    _drawWheel(canvas, center, radius, centerRadius);

    // ─── Button labels ───
    _drawLabels(canvas, center, radius, centerRadius);

    // ─── Center button ───
    _drawCenterButton(canvas, center, centerRadius);
  }

  void _drawWheel(
      Canvas canvas, Offset center, double radius, double centerRadius) {
    // Outer shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center + const Offset(0, 3), radius + 2, shadowPaint);

    // Wheel background gradient (smooth radial from light to dark grey)
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFAFAFA),
          Color(0xFFDFDFDF),
          Color(0xFFC4C4C4),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Highlight pressed region
    if (pressedRegion != null && pressedRegion != WheelRegion.center) {
      _drawPressedSector(canvas, center, radius, centerRadius, pressedRegion!);
    }

    // Outer border
    final borderPaint = Paint()
      ..color = const Color(0xFF909090)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Inner ring separator
    final innerBorderPaint = Paint()
      ..color = const Color(0xFF909090)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, centerRadius + 1, innerBorderPaint);
  }

  void _drawPressedSector(Canvas canvas, Offset center, double radius,
      double centerRadius, WheelRegion region) {
    double startAngle;
    switch (region) {
      case WheelRegion.menu:
        startAngle = -math.pi * 0.75;
        break;
      case WheelRegion.fastForward:
        startAngle = -math.pi * 0.25;
        break;
      case WheelRegion.playPause:
        startAngle = math.pi * 0.25;
        break;
      case WheelRegion.rewind:
        startAngle = math.pi * 0.75;
        break;
      default:
        return;
    }

    final path = Path()
      ..moveTo(
          center.dx + centerRadius * math.cos(startAngle),
          center.dy + centerRadius * math.sin(startAngle))
      ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          math.pi / 2,
          false)
      ..arcTo(
          Rect.fromCircle(center: center, radius: centerRadius),
          startAngle + math.pi / 2,
          -math.pi / 2,
          false)
      ..close();

    final paint = Paint()
      ..color = const Color(0xFF0071C5).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  void _drawLabels(
      Canvas canvas, Offset center, double radius, double centerRadius) {
    // Positioning labels closer to the outer border (70% of the ring thickness)
    final labelRadius = centerRadius + (radius - centerRadius) * 0.70;
    const labelColor = Color(0xFF0071C5);
    const labelStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final labels = {
      'MENU': Offset(center.dx, center.dy - labelRadius),
      '⏮': Offset(center.dx - labelRadius, center.dy),
      '▶II': Offset(center.dx, center.dy + labelRadius),
      '⏭': Offset(center.dx + labelRadius, center.dy),
    };

    final paint = Paint()
      ..color = labelColor
      ..style = PaintingStyle.fill;

    for (final entry in labels.entries) {
      final text = entry.key;
      final pos = entry.value;

      if (text == 'MENU') {
        final tp = TextPainter(
          text: TextSpan(text: text, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            pos.dx - tp.width / 2,
            pos.dy - tp.height / 2,
          ),
        );
      } else {
        final path = Path();
        if (text == '⏮') {
          // Vertical bar on left
          path.addRect(Rect.fromLTWH(pos.dx - 6, pos.dy - 5, 1.5, 10));
          // First triangle (left)
          path.moveTo(pos.dx - 4, pos.dy);
          path.lineTo(pos.dx + 1, pos.dy - 5);
          path.lineTo(pos.dx + 1, pos.dy + 5);
          path.close();
          // Second triangle (right)
          path.moveTo(pos.dx + 1, pos.dy);
          path.lineTo(pos.dx + 6, pos.dy - 5);
          path.lineTo(pos.dx + 6, pos.dy + 5);
          path.close();
        } else if (text == '⏭') {
          // First triangle (left)
          path.moveTo(pos.dx - 6, pos.dy - 5);
          path.lineTo(pos.dx - 1, pos.dy);
          path.lineTo(pos.dx - 6, pos.dy + 5);
          path.close();
          // Second triangle (right)
          path.moveTo(pos.dx - 1, pos.dy - 5);
          path.lineTo(pos.dx + 4, pos.dy);
          path.lineTo(pos.dx - 1, pos.dy + 5);
          path.close();
          // Vertical bar on right
          path.addRect(Rect.fromLTWH(pos.dx + 4.5, pos.dy - 5, 1.5, 10));
        } else if (text == '▶II') {
          // Play triangle (left)
          path.moveTo(pos.dx - 7, pos.dy - 5);
          path.lineTo(pos.dx - 1, pos.dy);
          path.lineTo(pos.dx - 7, pos.dy + 5);
          path.close();
          // Pause bars (right)
          path.addRect(Rect.fromLTWH(pos.dx + 2, pos.dy - 5, 1.5, 10));
          path.addRect(Rect.fromLTWH(pos.dx + 5.5, pos.dy - 5, 1.5, 10));
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawCenterButton(Canvas canvas, Offset center, double centerRadius) {
    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center + const Offset(0, 2), centerRadius, shadowPaint);

    // Center button gradient
    final centerPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.4),
        colors: [
          const Color(0xFFF5F5F5),
          const Color(0xFFDDDDDD),
          const Color(0xFFC8C8C8),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: centerRadius));
    canvas.drawCircle(center, centerRadius, centerPaint);

    // Center button border
    final centerBorderPaint = Paint()
      ..color = const Color(0xFF999999)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, centerRadius, centerBorderPaint);

    // Inner highlight ring
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, centerRadius * 0.85, highlightPaint);
  }

  @override
  bool shouldRepaint(_ClickWheelPainter oldDelegate) =>
      oldDelegate.pressedRegion != pressedRegion;
}
