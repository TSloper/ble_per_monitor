import 'dart:typed_data';
import 'package:ble_per_monitor/services/ble_platform/ble_platform.dart';

/// BLE service and characteristic UUIDs matching Zephyr device implementation
/// Updated to use full 128-bit custom UUIDs
class BleUuids {
  // Service UUID
  static const String serviceUuid = '19001900-9119-4719-b419-190019001900';

  // Read-Only Characteristics (Read + Notify)
  static const String rxPacketsUuid = '19011901-9119-4719-b419-010119011901';
  static const String perUuid = '19031903-9119-4719-b419-030319031903';
  static const String rssiUuid = '19041904-9119-4719-b419-040419041904';
  static const String snrUuid = '19051905-9119-4719-b419-050519051905';
  static const String testStatusUuid = '19061906-9119-4719-b419-060619061906';

  // Configuration Characteristics (Read + Write)
  static const String frequencyUuid = '19101910-9119-4719-b419-101019101910';
  static const String spreadingFactorUuid = '19111911-9119-4719-b419-111119111911';
  static const String bandwidthUuid = '19121912-9119-4719-b419-121219121912';
  static const String txPowerUuid = '19131913-9119-4719-b419-131319131913';

  // Control Characteristics
  static const String resetStatsUuid = '19201920-9119-4719-b419-202019201920'; // Write
  static const String testControlUuid = '19211921-9119-4719-b419-212119211921'; // Read + Write

  /// Convert UUID string to Guid for flutter_blue_plus
  static Guid toGuid(String uuid) => Guid(uuid);

  /// Get all characteristic UUIDs as a list
  static List<String> getAllCharacteristicUuids() => [
        rxPacketsUuid,
        perUuid,
        rssiUuid,
        snrUuid,
        testStatusUuid,
        frequencyUuid,
        spreadingFactorUuid,
        bandwidthUuid,
        txPowerUuid,
        resetStatsUuid,
        testControlUuid,
      ];
}

/// BLE connection and scan configuration constants
class BleConfig {
  // Device identification
  static const String deviceNameFilter = 'LR11xx PER RX';
  static const String deviceNamePrefix = 'LR11xx';

  // Timeout durations
  static const Duration scanTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration discoverServicesTimeout = Duration(seconds: 10);
  static const Duration characteristicOperationTimeout = Duration(seconds: 5);

  // Auto-reconnect settings
  static const bool autoReconnect = false;
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const int maxReconnectAttempts = 5;

  // Notification subscription settings
  static const int notificationRetryAttempts = 3;
  static const Duration notificationRetryDelay = Duration(milliseconds: 500);

  // RSSI update interval
  static const Duration rssiUpdateInterval = Duration(seconds: 2);

  // Data update rate limits
  static const Duration minUpdateInterval = Duration(milliseconds: 100);
}

/// LoRa bandwidth enumeration
enum LoraBandwidth {
  bw125(0, 125, '125 kHz'),
  bw250(1, 250, '250 kHz'),
  bw500(2, 500, '500 kHz');

  const LoraBandwidth(this.value, this.khz, this.displayName);

  final int value;
  final int khz;
  final String displayName;

  /// Get bandwidth from integer value
  static LoraBandwidth fromValue(int value) {
    return LoraBandwidth.values.firstWhere(
      (bw) => bw.value == value,
      orElse: () => LoraBandwidth.bw125,
    );
  }

  /// Get bandwidth from kHz value
  static LoraBandwidth fromKhz(int khz) {
    return LoraBandwidth.values.firstWhere(
      (bw) => bw.khz == khz,
      orElse: () => LoraBandwidth.bw125,
    );
  }
}

/// LoRa spreading factor enumeration
enum LoraSpreadingFactor {
  sf5(5, 'SF5'),
  sf6(6, 'SF6'),
  sf7(7, 'SF7'),
  sf8(8, 'SF8'),
  sf9(9, 'SF9'),
  sf10(10, 'SF10'),
  sf11(11, 'SF11'),
  sf12(12, 'SF12');

  const LoraSpreadingFactor(this.value, this.displayName);

  final int value;
  final String displayName;

  /// Get spreading factor from integer value
  static LoraSpreadingFactor fromValue(int value) {
    return LoraSpreadingFactor.values.firstWhere(
      (sf) => sf.value == value,
      orElse: () => LoraSpreadingFactor.sf7,
    );
  }

  /// Validate spreading factor value
  static bool isValid(int value) {
    return value >= 5 && value <= 12;
  }
}

/// BLE connection state enumeration
enum BleConnectionState {
  disconnected('Disconnected'),
  scanning('Scanning'),
  connecting('Connecting'),
  connected('Connected'),
  disconnecting('Disconnecting'),
  error('Error');

  const BleConnectionState(this.displayName);

  final String displayName;

  bool get isConnected => this == BleConnectionState.connected;
  bool get isDisconnected => this == BleConnectionState.disconnected;
  bool get isInProgress =>
      this == BleConnectionState.scanning ||
      this == BleConnectionState.connecting;
}

/// Parameter ranges and validation
class BleParameterRanges {
  // Frequency range (MHz)
  static const int frequencyMin = 300;
  static const int frequencyMax = 1000;
  static const int frequencyDefault = 915;

  // Spreading factor range
  static const int spreadingFactorMin = 5;
  static const int spreadingFactorMax = 12;
  static const int spreadingFactorDefault = 7;

  // Bandwidth values
  static const int bandwidthMin = 0;
  static const int bandwidthMax = 2;
  static const int bandwidthDefault = 0;

  // TX power range (dBm)
  static const int txPowerMin = -9;
  static const int txPowerMax = 22;
  static const int txPowerDefault = 14;

  /// Validate frequency value
  static bool isValidFrequency(int frequency) {
    return frequency >= frequencyMin && frequency <= frequencyMax;
  }

  /// Validate spreading factor value
  static bool isValidSpreadingFactor(int sf) {
    return sf >= spreadingFactorMin && sf <= spreadingFactorMax;
  }

  /// Validate bandwidth value
  static bool isValidBandwidth(int bw) {
    return bw >= bandwidthMin && bw <= bandwidthMax;
  }

  /// Validate TX power value
  static bool isValidTxPower(int power) {
    return power >= txPowerMin && power <= txPowerMax;
  }

  /// Clamp frequency to valid range
  static int clampFrequency(int frequency) {
    return frequency.clamp(frequencyMin, frequencyMax);
  }

  /// Clamp spreading factor to valid range
  static int clampSpreadingFactor(int sf) {
    return sf.clamp(spreadingFactorMin, spreadingFactorMax);
  }

  /// Clamp bandwidth to valid range
  static int clampBandwidth(int bw) {
    return bw.clamp(bandwidthMin, bandwidthMax);
  }

  /// Clamp TX power to valid range
  static int clampTxPower(int power) {
    return power.clamp(txPowerMin, txPowerMax);
  }
}

/// BLE data type conversion helpers
class BleDataConverter {
  /// Convert bytes to uint32 (little-endian)
  static int bytesToUint32(List<int> bytes) {
    if (bytes.length < 4) {
      throw ArgumentError('Need at least 4 bytes for uint32');
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return data.getUint32(0, Endian.little);
  }

  /// Convert bytes to int16 (little-endian)
  static int bytesToInt16(List<int> bytes) {
    if (bytes.length < 2) {
      throw ArgumentError('Need at least 2 bytes for int16');
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return data.getInt16(0, Endian.little);
  }

  /// Convert bytes to int8
  static int bytesToInt8(List<int> bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('Need at least 1 byte for int8');
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return data.getInt8(0);
  }

  /// Convert bytes to uint8
  static int bytesToUint8(List<int> bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('Need at least 1 byte for uint8');
    }
    return bytes[0];
  }

  /// Convert uint32 to bytes (little-endian)
  static List<int> uint32ToBytes(int value) {
    final data = ByteData(4);
    data.setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  /// Convert int16 to bytes (little-endian)
  static List<int> int16ToBytes(int value) {
    final data = ByteData(2);
    data.setInt16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  /// Convert int8 to bytes
  static List<int> int8ToBytes(int value) {
    final data = ByteData(1);
    data.setInt8(0, value);
    return data.buffer.asUint8List();
  }

  /// Convert uint8 to bytes
  static List<int> uint8ToBytes(int value) {
    return [value & 0xFF];
  }

  /// Convert PER value from percentage × 100 to double percentage
  static double perToPercentage(int perValue) {
    return perValue / 100.0;
  }

  /// Convert double percentage to PER value (percentage × 100)
  static int percentageToPer(double percentage) {
    return (percentage * 100).round();
  }

  /// Format PER as percentage string
  static String formatPer(int perValue) {
    final percentage = perToPercentage(perValue);
    return '${percentage.toStringAsFixed(2)}%';
  }

  /// Format RSSI value
  static String formatRssi(int rssi) {
    return '$rssi dBm';
  }

  /// Format SNR value
  static String formatSnr(int snr) {
    return '$snr dB';
  }

  /// Format frequency value
  static String formatFrequency(int frequency) {
    return '$frequency MHz';
  }

  /// Format TX power value
  static String formatTxPower(int power) {
    return '$power dBm';
  }
}

/// BLE error messages
class BleErrorMessages {
  static const String scanFailed = 'Failed to start BLE scan';
  static const String scanTimeout = 'Device scan timed out';
  static const String deviceNotFound = 'Device not found';
  static const String connectionFailed = 'Failed to connect to device';
  static const String connectionTimeout = 'Connection attempt timed out';
  static const String disconnected = 'Device disconnected';
  static const String serviceNotFound = 'BLE service not found';
  static const String characteristicNotFound = 'Characteristic not found';
  static const String readFailed = 'Failed to read characteristic';
  static const String writeFailed = 'Failed to write characteristic';
  static const String notificationFailed = 'Failed to enable notifications';
  static const String invalidData = 'Invalid data received';
  static const String permissionDenied = 'Bluetooth permission denied';
  static const String bluetoothOff = 'Bluetooth is turned off';
  static const String notSupported = 'BLE is not supported on this device';
  static const String unknownError = 'An unknown error occurred';

  /// Get user-friendly error message from exception
  static String fromException(Exception e) {
    final message = e.toString();
    if (message.contains('scan')) return scanFailed;
    if (message.contains('timeout')) return connectionTimeout;
    if (message.contains('connect')) return connectionFailed;
    if (message.contains('service')) return serviceNotFound;
    if (message.contains('characteristic')) return characteristicNotFound;
    if (message.contains('permission')) return permissionDenied;
    if (message.contains('bluetooth')) return bluetoothOff;
    return unknownError;
  }
}

/// Characteristic property helpers
class BleCharacteristicProperties {
  /// Check if characteristic supports read
  static bool canRead(BluetoothCharacteristic characteristic) {
    return characteristic.properties.read;
  }

  /// Check if characteristic supports write
  static bool canWrite(BluetoothCharacteristic characteristic) {
    return characteristic.properties.write ||
        characteristic.properties.writeWithoutResponse;
  }

  /// Check if characteristic supports notify
  static bool canNotify(BluetoothCharacteristic characteristic) {
    return characteristic.properties.notify ||
        characteristic.properties.indicate;
  }

  /// Get property description string
  static String getPropertiesString(BluetoothCharacteristic characteristic) {
    final props = <String>[];
    if (characteristic.properties.read) props.add('Read');
    if (characteristic.properties.write) props.add('Write');
    if (characteristic.properties.writeWithoutResponse) {
      props.add('Write No Response');
    }
    if (characteristic.properties.notify) props.add('Notify');
    if (characteristic.properties.indicate) props.add('Indicate');
    return props.join(', ');
  }
}
