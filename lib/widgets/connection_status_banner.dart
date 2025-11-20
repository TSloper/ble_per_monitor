import 'package:flutter/material.dart';
import '../utils/ble_constants.dart';

/// Banner widget showing BLE connection state
class ConnectionStatusBanner extends StatefulWidget {
  final BleConnectionState connectionState;
  final String? deviceName;
  final int? rssi;
  final VoidCallback? onDismiss;

  const ConnectionStatusBanner({
    super.key,
    required this.connectionState,
    this.deviceName,
    this.rssi,
    this.onDismiss,
  });

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.connectionState == BleConnectionState.connecting ||
        widget.connectionState == BleConnectionState.scanning) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ConnectionStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connectionState != oldWidget.connectionState) {
      if (widget.connectionState == BleConnectionState.connecting ||
          widget.connectionState == BleConnectionState.scanning) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Get banner color based on connection state
  Color _getBannerColor() {
    switch (widget.connectionState) {
      case BleConnectionState.disconnected:
        return Colors.grey;
      case BleConnectionState.scanning:
      case BleConnectionState.connecting:
        return Colors.blue;
      case BleConnectionState.connected:
        return Colors.green;
      case BleConnectionState.disconnecting:
        return Colors.orange;
      case BleConnectionState.error:
        return Colors.red;
    }
  }

  /// Get banner icon based on connection state
  IconData _getBannerIcon() {
    switch (widget.connectionState) {
      case BleConnectionState.disconnected:
        return Icons.bluetooth_disabled;
      case BleConnectionState.scanning:
        return Icons.bluetooth_searching;
      case BleConnectionState.connecting:
        return Icons.bluetooth;
      case BleConnectionState.connected:
        return Icons.bluetooth_connected;
      case BleConnectionState.disconnecting:
        return Icons.bluetooth_disabled;
      case BleConnectionState.error:
        return Icons.error_outline;
    }
  }

  /// Get banner message based on connection state
  String _getBannerMessage() {
    switch (widget.connectionState) {
      case BleConnectionState.disconnected:
        return 'Not Connected';
      case BleConnectionState.scanning:
        return 'Scanning for devices...';
      case BleConnectionState.connecting:
        return 'Connecting${widget.deviceName != null ? ' to ${widget.deviceName}' : ''}...';
      case BleConnectionState.connected:
        return 'Connected${widget.deviceName != null ? ' to ${widget.deviceName}' : ''}';
      case BleConnectionState.disconnecting:
        return 'Disconnecting...';
      case BleConnectionState.error:
        return 'Connection Failed';
    }
  }

  /// Check if banner is dismissible
  bool get _isDismissible {
    return widget.onDismiss != null &&
        (widget.connectionState == BleConnectionState.connecting ||
            widget.connectionState == BleConnectionState.scanning);
  }

  @override
  Widget build(BuildContext context) {
    final bannerColor = _getBannerColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark
            ? bannerColor.withValues(alpha: 0.3)
            : bannerColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: bannerColor.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Animated icon
              FadeTransition(
                opacity: _pulseAnimation,
                child: Icon(
                  _getBannerIcon(),
                  color: bannerColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getBannerMessage(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: bannerColor,
                          ),
                    ),
                    if (widget.connectionState == BleConnectionState.connected &&
                        widget.rssi != null)
                      Text(
                        'Signal: ${widget.rssi} dBm',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: bannerColor.withValues(alpha: 0.8),
                            ),
                      ),
                  ],
                ),
              ),

              // Dismiss button for connecting state
              if (_isDismissible)
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  color: bannerColor,
                  onPressed: widget.onDismiss,
                  tooltip: 'Cancel',
                ),

              // Status indicator dot
              if (widget.connectionState == BleConnectionState.connected)
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: bannerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact connection status indicator (for app bar, etc.)
class CompactConnectionStatus extends StatelessWidget {
  final BleConnectionState connectionState;
  final int? rssi;

  const CompactConnectionStatus({
    super.key,
    required this.connectionState,
    this.rssi,
  });

  Color _getStatusColor() {
    switch (connectionState) {
      case BleConnectionState.connected:
        return Colors.green;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        return Colors.blue;
      case BleConnectionState.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (connectionState) {
      case BleConnectionState.connected:
        return Icons.bluetooth_connected;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        return Icons.bluetooth;
      case BleConnectionState.disconnected:
        return Icons.bluetooth_disabled;
      default:
        return Icons.bluetooth_disabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getStatusIcon(),
          color: _getStatusColor(),
          size: 20,
        ),
        if (rssi != null) ...[
          const SizedBox(width: 4),
          Text(
            '$rssi',
            style: TextStyle(
              color: _getStatusColor(),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
