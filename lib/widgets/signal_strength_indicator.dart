import 'package:flutter/material.dart';

/// Size options for signal strength indicator
enum SignalSize {
  small,
  medium,
  large,
}

/// Visual signal bars widget (like cellular signal)
class SignalStrengthIndicator extends StatelessWidget {
  final int rssi;
  final SignalSize size;
  final Color? color;

  const SignalStrengthIndicator({
    super.key,
    required this.rssi,
    this.size = SignalSize.medium,
    this.color,
  });

  /// Get number of bars based on RSSI
  /// > -50 dBm: 5 bars (excellent)
  /// -50 to -60: 4 bars (good)
  /// -60 to -70: 3 bars (fair)
  /// -70 to -80: 2 bars (weak)
  /// < -80: 1 bar (poor)
  int get _barCount {
    if (rssi > -50) return 5;
    if (rssi > -60) return 4;
    if (rssi > -70) return 3;
    if (rssi > -80) return 2;
    return 1;
  }

  /// Get color based on signal strength
  Color _getSignalColor(BuildContext context) {
    if (color != null) return color!;

    if (rssi > -60) return Colors.green;
    if (rssi > -70) return Colors.lightGreen;
    if (rssi > -80) return Colors.orange;
    return Colors.red;
  }

  /// Get bar dimensions based on size
  double get _barWidth {
    switch (size) {
      case SignalSize.small:
        return 3;
      case SignalSize.medium:
        return 4;
      case SignalSize.large:
        return 6;
    }
  }

  double get _baseHeight {
    switch (size) {
      case SignalSize.small:
        return 8;
      case SignalSize.medium:
        return 12;
      case SignalSize.large:
        return 16;
    }
  }

  double get _barSpacing {
    switch (size) {
      case SignalSize.small:
        return 2;
      case SignalSize.medium:
        return 3;
      case SignalSize.large:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final signalColor = _getSignalColor(context);
    final inactiveColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        final isActive = index < _barCount;
        final barHeight = _baseHeight + (index * _baseHeight * 0.4);

        return Container(
          width: _barWidth,
          height: barHeight,
          margin: EdgeInsets.symmetric(horizontal: _barSpacing / 2),
          decoration: BoxDecoration(
            color: isActive ? signalColor : inactiveColor,
            borderRadius: BorderRadius.circular(_barWidth / 2),
          ),
        );
      }),
    );
  }
}

/// Signal strength indicator with RSSI value
class SignalStrengthWithValue extends StatelessWidget {
  final int rssi;
  final SignalSize size;
  final bool showValue;

  const SignalStrengthWithValue({
    super.key,
    required this.rssi,
    this.size = SignalSize.medium,
    this.showValue = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SignalStrengthIndicator(
          rssi: rssi,
          size: size,
        ),
        if (showValue) ...[
          const SizedBox(width: 8),
          Text(
            '$rssi dBm',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ],
    );
  }
}
