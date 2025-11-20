import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import '../utils/ble_constants.dart';

/// Represents a discovered or connected LR11xx PER device
class PerDevice {
  /// Unique device identifier (MAC address)
  final String deviceId;

  /// Device name (e.g., "LR11xx PER RX")
  final String deviceName;

  /// Signal strength in dBm
  final int rssi;

  /// Current connection state
  final BleConnectionState connectionState;

  /// Last time the device was seen or updated
  final DateTime lastSeen;

  /// Bluetooth device reference (optional, only when discovered)
  final BluetoothDevice? bluetoothDevice;

  const PerDevice({
    required this.deviceId,
    required this.deviceName,
    required this.rssi,
    required this.connectionState,
    required this.lastSeen,
    this.bluetoothDevice,
  });

  /// Create PerDevice from BluetoothDevice scan result
  factory PerDevice.fromBluetoothDevice(
    BluetoothDevice device,
    int rssi, {
    BleConnectionState? state,
  }) {
    return PerDevice(
      deviceId: device.remoteId.toString(),
      deviceName: device.platformName.isNotEmpty
          ? device.platformName
          : 'Unknown Device',
      rssi: rssi,
      connectionState: state ?? BleConnectionState.disconnected,
      lastSeen: DateTime.now(),
      bluetoothDevice: device,
    );
  }

  /// Create PerDevice from scan result
  factory PerDevice.fromScanResult(ScanResult result) {
    return PerDevice.fromBluetoothDevice(
      result.device,
      result.rssi,
    );
  }

  /// Check if device matches the expected device name
  bool get isLr11xxDevice {
    return deviceName.toLowerCase().contains('lr11xx') ||
        deviceName.toLowerCase().contains('per rx');
  }

  /// Check if device is currently connected
  bool get isConnected => connectionState.isConnected;

  /// Check if device is in a transitional state
  bool get isInProgress => connectionState.isInProgress;

  /// Check if signal strength is good (> -70 dBm)
  bool get hasGoodSignal => rssi > -70;

  /// Check if signal strength is fair (-70 to -85 dBm)
  bool get hasFairSignal => rssi >= -85 && rssi <= -70;

  /// Check if signal strength is poor (< -85 dBm)
  bool get hasPoorSignal => rssi < -85;

  /// Get signal strength quality description
  String get signalQuality {
    if (hasGoodSignal) return 'Excellent';
    if (hasFairSignal) return 'Good';
    return 'Poor';
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'rssi': rssi,
      'connectionState': connectionState.name,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  /// Create from JSON
  factory PerDevice.fromJson(Map<String, dynamic> json) {
    return PerDevice(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      rssi: json['rssi'] as int,
      connectionState: BleConnectionState.values.firstWhere(
        (state) => state.name == json['connectionState'],
        orElse: () => BleConnectionState.disconnected,
      ),
      lastSeen: DateTime.parse(json['lastSeen'] as String),
    );
  }

  /// Create a copy with updated fields
  PerDevice copyWith({
    String? deviceId,
    String? deviceName,
    int? rssi,
    BleConnectionState? connectionState,
    DateTime? lastSeen,
    BluetoothDevice? bluetoothDevice,
  }) {
    return PerDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      rssi: rssi ?? this.rssi,
      connectionState: connectionState ?? this.connectionState,
      lastSeen: lastSeen ?? this.lastSeen,
      bluetoothDevice: bluetoothDevice ?? this.bluetoothDevice,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PerDevice && other.deviceId == deviceId;
  }

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() {
    return 'PerDevice(id: $deviceId, name: $deviceName, rssi: $rssi dBm, '
        'state: ${connectionState.displayName})';
  }
}
