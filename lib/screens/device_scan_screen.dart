import 'dart:async';
import 'package:flutter/material.dart';
import '../models/per_device.dart';
import '../services/ble_service.dart';

/// Screen for scanning and discovering BLE devices
class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen>
    with SingleTickerProviderStateMixin {
  final BleService _bleService = BleService();
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _errorMessage;
  Timer? _staleDeviceTimer;
  Timer? _buttonDebounceTimer;
  late AnimationController _scanAnimationController;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startStaleDeviceTimer();
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _staleDeviceTimer?.cancel();
    _buttonDebounceTimer?.cancel();
    if (_isScanning) {
      _bleService.stopScan();
    }
    super.dispose();
  }

  /// Start or stop scanning with debounce
  Future<void> _toggleScan() async {
    // Debounce button presses
    if (_buttonDebounceTimer?.isActive ?? false) return;
    _buttonDebounceTimer = Timer(const Duration(milliseconds: 500), () {});

    if (_isScanning) {
      await _stopScan();
    } else {
      await _startScan();
    }
  }

  /// Start scanning for devices
  Future<void> _startScan() async {
    setState(() {
      _errorMessage = null;
      _isScanning = true;
    });

    try {
      await _bleService.startScan();
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Failed to start scan: ${e.toString()}';
      });
    }
  }

  /// Stop scanning for devices
  Future<void> _stopScan() async {
    try {
      await _bleService.stopScan();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to stop scan: ${e.toString()}';
      });
    }
  }

  /// Start timer to remove stale devices
  void _startStaleDeviceTimer() {
    _staleDeviceTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          // UI will rebuild and filter stale devices
        });
      }
    });
  }

  /// Filter out stale devices (not seen in 10 seconds)
  List<PerDevice> _filterStaleDevices(List<PerDevice> devices) {
    final now = DateTime.now();
    return devices.where((device) {
      final timeSinceLastSeen = now.difference(device.lastSeen);
      return timeSinceLastSeen.inSeconds <= 10;
    }).toList();
  }

  /// Sort devices by RSSI (strongest first)
  List<PerDevice> _sortDevicesByRssi(List<PerDevice> devices) {
    final sorted = List<PerDevice>.from(devices);
    sorted.sort((a, b) => b.rssi.compareTo(a.rssi));
    return sorted;
  }

  /// Connect to a device
  Future<void> _connectToDevice(PerDevice device) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    // Stop scanning
    if (_isScanning) {
      await _stopScan();
    }

    try {
      await _bleService.connect(device);

      // Navigate to statistics dashboard on successful connection
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/statistics',
          arguments: device,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  /// Get signal strength icon based on RSSI
  IconData _getSignalIcon(int rssi) {
    if (rssi > -60) return Icons.signal_cellular_alt;
    if (rssi > -70) return Icons.signal_cellular_alt;
    if (rssi > -80) return Icons.signal_cellular_alt_2_bar;
    if (rssi > -90) return Icons.signal_cellular_alt_1_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  /// Get signal strength color based on RSSI
  Color _getSignalColor(int rssi) {
    if (rssi > -70) return Colors.green;
    if (rssi > -85) return Colors.orange;
    return Colors.red;
  }

  /// Format time since last seen
  String _formatTimeSinceLastSeen(DateTime lastSeen) {
    final duration = DateTime.now().difference(lastSeen);
    if (duration.inSeconds < 5) return 'Just now';
    if (duration.inSeconds < 60) return '${duration.inSeconds}s ago';
    return '${duration.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE PER Monitor'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!_isScanning) {
            await _startScan();
          }
        },
        child: Column(
          children: [
            // Error message banner
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: colorScheme.errorContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: colorScheme.onErrorContainer,
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),


            // Scanning status
            if (_isScanning)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _scanAnimationController,
                      child: Icon(
                        Icons.radar,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Scanning for devices...',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Connecting status
            if (_isConnecting)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Connecting...',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Device list
            Expanded(
              child: StreamBuilder<List<PerDevice>>(
                stream: _bleService.scanResultsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Filter and sort devices
                  var devices = _filterStaleDevices(snapshot.data!);
                  devices = _sortDevicesByRssi(devices);

                  if (devices.isEmpty) {
                    return _buildEmptyState();
                  }

                  return AnimatedList(
                    initialItemCount: devices.length,
                    itemBuilder: (context, index, animation) {
                      return _buildDeviceListItem(
                        devices[index],
                        animation,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleScan,
        icon: Icon(_isScanning ? Icons.stop : Icons.radar),
        label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
        backgroundColor: _isScanning ? colorScheme.error : colorScheme.primary,
      ),
    );
  }

  /// Build device list item
  Widget _buildDeviceListItem(PerDevice device, Animation<double> animation) {
    final colorScheme = Theme.of(context).colorScheme;
    final signalColor = _getSignalColor(device.rssi);

    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: InkWell(
          onTap: _isConnecting ? null : () => _connectToDevice(device),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Signal strength icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: signalColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getSignalIcon(device.rssi),
                    color: signalColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Device name
                      Text(
                        device.deviceName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),

                      // Device ID
                      Text(
                        device.deviceId,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 8),

                      // RSSI and last seen
                      Row(
                        children: [
                          // RSSI
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: signalColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: signalColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '${device.rssi} dBm',
                              style: TextStyle(
                                color: signalColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Signal quality
                          Text(
                            device.signalQuality,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: signalColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const Spacer(),

                          // Last seen
                          Text(
                            _formatTimeSinceLastSeen(device.lastSeen),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Connect arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build empty state UI
  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isScanning ? Icons.search : Icons.bluetooth_searching,
              size: 80,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              _isScanning
                  ? 'Searching for LR11xx devices...'
                  : 'No devices found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              _isScanning
                  ? 'Make sure your device is powered on and in range'
                  : 'Tap the scan button to search for devices',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
