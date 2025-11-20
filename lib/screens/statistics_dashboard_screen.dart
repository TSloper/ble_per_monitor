import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/per_device.dart';
import '../models/per_statistics.dart';
import '../services/ble_service.dart';
import '../utils/ble_constants.dart';

/// Main statistics dashboard screen showing real-time PER data
///
/// LAYOUT REVISION: 2025-01-19
/// - Changed Packet Statistics to horizontal layout (left to right):
///   Packets Received | RSSI | SNR | Packet Error Rate
/// - Replaced Signal Quality Card with Test Control/Status Card
/// - Test Control/Status Card now contains the Start/Stop RX button
/// - Quick Actions Card now only contains Reset Statistics and Parameters buttons
///
/// TO REVERT: Use git to restore the previous version if needed:
/// git checkout HEAD~1 -- lib/screens/statistics_dashboard_screen.dart
class StatisticsDashboardScreen extends StatefulWidget {
  final PerDevice device;

  const StatisticsDashboardScreen({
    super.key,
    required this.device,
  });

  @override
  State<StatisticsDashboardScreen> createState() =>
      _StatisticsDashboardScreenState();
}

class _StatisticsDashboardScreenState extends State<StatisticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  final BleService _bleService = BleService();
  PerStatistics? _currentStats;
  BleConnectionState _connectionState = BleConnectionState.connected;
  bool _isResetting = false;
  bool _isTestRunning = false;
  bool _isTogglingTest = false;
  late AnimationController _pulseController;

  // Number formatter
  final _numberFormatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _subscribeToUpdates();
    // Note: _isTestRunning will be set automatically when statistics stream
    // provides the initial test status from the device
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Subscribe to statistics and connection state updates
  void _subscribeToUpdates() {
    // Listen to statistics updates
    _bleService.statisticsStream.listen(
      (stats) {
        if (mounted) {
          setState(() {
            _currentStats = stats;

            // Update button state based on test status
            // Running (1) -> button shows "Stop"
            // Stopped (0) or Completed (2) -> button shows "Start"
            _isTestRunning = stats.testStatus == TestStatus.running;
          });
        }
      },
      onError: (error) {
        _showError('Statistics update failed: $error');
      },
    );

    // Listen to connection state
    _bleService.connectionStateStream.listen(
      (state) {
        if (mounted) {
          setState(() {
            _connectionState = state;
          });

          if (state == BleConnectionState.disconnected) {
            _handleDisconnection();
          }
        }
      },
    );
  }

  /// Handle device disconnection
  void _handleDisconnection() {
    // Don't auto-navigate - let user manually go back with back button
    // This allows them to review final statistics after disconnect
  }

  /// Disconnect from device
  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Are you sure you want to disconnect from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _bleService.disconnect();
      // Don't navigate away - let user press back button to return to scan screen
    }
  }

  /// Reconnect to device
  Future<void> _reconnect() async {
    try {
      await _bleService.connect(widget.device);
      // Connection successful - UI will update via connection state stream
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reconnect: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Reset statistics on device
  Future<void> _resetStatistics() async {
    setState(() {
      _isResetting = true;
    });

    try {
      await _bleService.resetStatistics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statistics reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to reset statistics: $e');
    } finally {
      setState(() {
        _isResetting = false;
      });
    }
  }

  /// Toggle RX test (Start/Stop)
  Future<void> _toggleRxTest() async {
    setState(() {
      _isTogglingTest = true;
    });

    try {
      if (_isTestRunning) {
        // Stop the running test
        await _bleService.stopRxTest();
      } else {
        // Start a new test
        await _bleService.startRxTest();
      }

      // Note: _isTestRunning state will be automatically updated via statisticsStream
      // when the test status notification arrives from the device
    } catch (e) {
      _showError('Failed to ${_isTestRunning ? 'stop' : 'start'} RX test: $e');
    } finally {
      setState(() {
        _isTogglingTest = false;
      });
    }
  }

  /// Navigate to parameters screen
  void _navigateToParameters() {
    Navigator.pushNamed(context, '/parameters');
  }

  /// Show error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Get PER indicator color
  Color _getPerColor(double per) {
    if (per < 1.0) return Colors.green;
    if (per <= 5.0) return Colors.orange;
    return Colors.red;
  }

  /// Get test status color
  Color _getTestStatusColor(TestStatus status) {
    switch (status) {
      case TestStatus.stopped:
        return Colors.grey;
      case TestStatus.running:
        return Colors.blue;
      case TestStatus.completed:
        return Colors.green;
    }
  }

  /// Get test status icon
  IconData _getTestStatusIcon(TestStatus status) {
    switch (status) {
      case TestStatus.stopped:
        return Icons.stop_circle_outlined;
      case TestStatus.running:
        return Icons.play_circle_outlined;
      case TestStatus.completed:
        return Icons.check_circle_outlined;
    }
  }

  /// Get formatted timestamp
  String _getFormattedTime(DateTime time) {
    return DateFormat('hh:mm:ss a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stats = _currentStats ?? PerStatistics.initial();

    return PopScope(
      canPop: !_connectionState.isConnected,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _connectionState.isConnected) {
          // Show dialog asking user to disconnect first
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Device Connected'),
              content: const Text('Please disconnect from the device before going back.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistics Dashboard'),
          actions: [
            // Connection state indicator
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                _connectionState.isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: _connectionState.isConnected ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Connection Status Card
                  _buildConnectionStatusCard(colorScheme),
                  const SizedBox(height: 16),

                  // Statistics Card (shows last known values even when disconnected)
                  _buildStatisticsCard(colorScheme, stats),
                  const SizedBox(height: 16),

                  // Test Control / Status Card
                  _buildTestControlCard(colorScheme, stats),
                  const SizedBox(height: 16),

                  // Quick Actions
                  _buildQuickActions(colorScheme),
                  const SizedBox(height: 16),
                ],
              ),
            ),
      ),
    );
  }

  /// Build connection status card
  Widget _buildConnectionStatusCard(ColorScheme colorScheme) {
    final isConnected = _connectionState.isConnected;
    final statusColor = isConnected ? Colors.green : Colors.grey;
    final statusIcon = isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: isConnected ? colorScheme.primary : Colors.grey),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Connected Device' : 'Disconnected Device',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.device.deviceName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.device.deviceId,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _connectionState.displayName,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                isConnected
                    ? OutlinedButton.icon(
                        onPressed: _disconnect,
                        icon: const Icon(Icons.bluetooth_disabled),
                        label: const Text('Disconnect'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _reconnect,
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('Reconnect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build statistics card (horizontal layout)
  Widget _buildStatisticsCard(ColorScheme colorScheme, PerStatistics stats) {
    final perColor = stats.testStatus == TestStatus.completed
        ? _getPerColor(stats.perPercentage ?? 0.0)
        : Colors.grey;
    final rssiColor = stats.rssi > -70 ? Colors.green : (stats.rssi > -85 ? Colors.orange : Colors.red);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Packet Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  'Updated: ${_getFormattedTime(stats.lastUpdate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Horizontal layout of all stats
            Row(
              children: [
                // Packets Received
                Expanded(
                  child: _buildCompactStatItem(
                    'Packets\nReceived',
                    _numberFormatter.format(stats.packetsReceived),
                    Colors.blue,
                    Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 12),

                // RSSI
                Expanded(
                  child: _buildCompactStatItem(
                    'RSSI',
                    '${stats.rssi}\ndBm',
                    rssiColor,
                    Icons.signal_cellular_alt,
                  ),
                ),
                const SizedBox(width: 12),

                // SNR
                Expanded(
                  child: _buildCompactStatItem(
                    'SNR',
                    '${stats.snr}\ndB',
                    Colors.purple,
                    Icons.graphic_eq,
                  ),
                ),
                const SizedBox(width: 12),

                // Packet Error Rate
                Expanded(
                  child: _buildCompactStatItem(
                    'Packet\nError Rate',
                    stats.testStatus == TestStatus.completed
                        ? '${(stats.perPercentage ?? 0.0).toStringAsFixed(2)}%'
                        : '--%',
                    perColor,
                    Icons.percent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build compact stat item for horizontal layout
  Widget _buildCompactStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build test control/status card
  Widget _buildTestControlCard(ColorScheme colorScheme, PerStatistics stats) {
    final statusColor = _getTestStatusColor(stats.testStatus);
    final statusIcon = _getTestStatusIcon(stats.testStatus);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_input_antenna, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Test Control / Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Status',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stats.testStatus.displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Start/Stop RX button (full width, fixed size)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isTogglingTest ? null : _toggleRxTest,
                icon: _isTogglingTest
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_isTestRunning ? Icons.stop : Icons.play_arrow),
                label: Text(_isTestRunning ? 'Stop RX' : 'Start RX'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTestRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build quick actions card
  Widget _buildQuickActions(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_suggest, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isResetting || _isTestRunning) ? null : _resetStatistics,
                    icon: _isResetting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Reset Statistics'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTestRunning ? null : _navigateToParameters,
                    icon: const Icon(Icons.settings),
                    label: const Text('Parameters'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
