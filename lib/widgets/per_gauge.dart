import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Circular gauge widget for displaying PER percentage
class PerGauge extends StatefulWidget {
  final double perValue; // 0-100
  final double size;
  final bool showValue;
  final String? label;

  const PerGauge({
    super.key,
    required this.perValue,
    this.size = 200,
    this.showValue = true,
    this.label,
  });

  @override
  State<PerGauge> createState() => _PerGaugeState();
}

class _PerGaugeState extends State<PerGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: widget.perValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _displayValue = _animation.value;
        });
      });
    _controller.forward();
  }

  @override
  void didUpdateWidget(PerGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.perValue != widget.perValue) {
      _animation = Tween<double>(
        begin: _displayValue,
        end: widget.perValue,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      )..addListener(() {
          setState(() {
            _displayValue = _animation.value;
          });
        });
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Get color based on PER value
  Color _getPerColor(double per) {
    if (per < 1.0) return Colors.green;
    if (per <= 5.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _GaugePainter(
          value: _displayValue,
          maxValue: 100,
          getColor: _getPerColor,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.showValue) ...[
                Text(
                  _displayValue.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getPerColor(_displayValue),
                      ),
                ),
                Text(
                  '%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _getPerColor(_displayValue),
                      ),
                ),
              ],
              if (widget.label != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.label!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the gauge
class _GaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color Function(double) getColor;

  _GaugePainter({
    required this.value,
    required this.maxValue,
    required this.getColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final strokeWidth = 16.0;

    // Draw background arc
    final backgroundPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi * 0.75; // Start at bottom-left
    const sweepAngle = math.pi * 1.5; // 270 degrees

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Draw gradient arc for value
    if (value > 0) {
      final progress = (value / maxValue).clamp(0.0, 1.0);
      final valueSweepAngle = sweepAngle * progress;

      // Create gradient
      final gradientColors = [
        Colors.green,
        Colors.lightGreen,
        Colors.yellow,
        Colors.orange,
        Colors.red,
      ];

      final gradientStops = [0.0, 0.01, 0.05, 0.1, 1.0];

      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        colors: gradientColors,
        stops: gradientStops,
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
      );

      final valuePaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        startAngle,
        valueSweepAngle,
        false,
        valuePaint,
      );

      // Draw needle
      _drawNeedle(canvas, center, radius, startAngle + valueSweepAngle);
    }

    // Draw tick marks
    _drawTickMarks(canvas, center, radius, strokeWidth, startAngle, sweepAngle);
  }

  /// Draw needle indicator
  void _drawNeedle(Canvas canvas, Offset center, double radius, double angle) {
    final needleLength = radius + 10;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );

    final needlePaint = Paint()
      ..color = getColor(value)
      ..style = PaintingStyle.fill
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Draw needle line
    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw center circle
    canvas.drawCircle(center, 6, needlePaint);
    canvas.drawCircle(
      center,
      4,
      Paint()..color = Colors.white,
    );
  }

  /// Draw tick marks at key values
  void _drawTickMarks(Canvas canvas, Offset center, double radius,
      double strokeWidth, double startAngle, double sweepAngle) {
    final tickPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw ticks at 0, 1, 5, 10, 25, 50, 75, 100
    final tickValues = [0.0, 1.0, 5.0, 10.0, 25.0, 50.0, 75.0, 100.0];
    for (final tickValue in tickValues) {
      final progress = tickValue / maxValue;
      final angle = startAngle + sweepAngle * progress;

      final tickStart = Offset(
        center.dx + (radius - strokeWidth / 2 - 5) * math.cos(angle),
        center.dy + (radius - strokeWidth / 2 - 5) * math.sin(angle),
      );

      final tickEnd = Offset(
        center.dx + (radius + strokeWidth / 2 + 5) * math.cos(angle),
        center.dy + (radius + strokeWidth / 2 + 5) * math.sin(angle),
      );

      canvas.drawLine(tickStart, tickEnd, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

/// Simplified linear PER indicator
class PerLinearIndicator extends StatelessWidget {
  final double perValue; // 0-100
  final double height;
  final bool showValue;

  const PerLinearIndicator({
    super.key,
    required this.perValue,
    this.height = 40,
    this.showValue = true,
  });

  Color _getPerColor(double per) {
    if (per < 1.0) return Colors.green;
    if (per <= 5.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPerColor(perValue);
    final progress = (perValue / 100).clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Stack(
        children: [
          // Progress bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            width: MediaQuery.of(context).size.width * progress,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.6),
                  color,
                ],
              ),
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),

          // Value text
          if (showValue)
            Center(
              child: Text(
                '${perValue.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: progress > 0.5 ? Colors.white : color,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
