import '../utils/ble_constants.dart';

/// Test status enumeration
enum TestStatus {
  stopped(0, 'Stopped'),
  running(1, 'Running'),
  completed(2, 'Completed');

  const TestStatus(this.value, this.displayName);

  final int value;
  final String displayName;

  /// Get test status from integer value
  static TestStatus fromValue(int value) {
    return TestStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TestStatus.stopped,
    );
  }
}

/// Represents PER (Packet Error Rate) test statistics
class PerStatistics {
  /// Total number of packets received (uint32)
  final int packetsReceived;

  /// Packet Error Rate as percentage × 100 (uint32 from device)
  /// Device sends value × 100, so 1525 = 15.25%
  /// Only valid when test is completed (testStatus == completed)
  final int perValue;

  /// Current RSSI in dBm (int16)
  final int rssi;

  /// Current SNR in dB (int8)
  final int snr;

  /// Test status (uint8): 0=stopped, 1=running, 2=completed
  final TestStatus testStatus;

  /// Timestamp of last update
  final DateTime lastUpdate;

  const PerStatistics({
    required this.packetsReceived,
    required this.perValue,
    required this.rssi,
    required this.snr,
    required this.testStatus,
    required this.lastUpdate,
  });

  /// Create empty/initial statistics
  factory PerStatistics.initial() {
    return PerStatistics(
      packetsReceived: 0,
      perValue: 0,
      rssi: 0,
      snr: 0,
      testStatus: TestStatus.stopped,
      lastUpdate: DateTime.now(),
    );
  }

  /// Create from BLE characteristic values
  factory PerStatistics.fromCharacteristics({
    required List<int> rxPacketsBytes,
    required List<int> perBytes,
    required List<int> rssiBytes,
    required List<int> snrBytes,
    required List<int> testStatusBytes,
  }) {
    try {
      return PerStatistics(
        packetsReceived: BleDataConverter.bytesToUint32(rxPacketsBytes),
        perValue: BleDataConverter.bytesToUint32(perBytes),
        rssi: BleDataConverter.bytesToInt16(rssiBytes),
        snr: BleDataConverter.bytesToInt8(snrBytes),
        testStatus: TestStatus.fromValue(BleDataConverter.bytesToUint8(testStatusBytes)),
        lastUpdate: DateTime.now(),
      );
    } catch (e) {
      // Return initial statistics if conversion fails
      return PerStatistics.initial();
    }
  }

  /// Calculate PER as a percentage (0.0 - 100.0)
  /// Returns null if test is not completed
  double? get perPercentage {
    if (testStatus != TestStatus.completed) return null;
    return BleDataConverter.perToPercentage(perValue);
  }

  /// Get formatted PER string
  String get perFormatted {
    if (testStatus != TestStatus.completed) return '--';
    return BleDataConverter.formatPer(perValue);
  }

  /// Check if statistics are valid (at least one packet received)
  bool get isValid => packetsReceived > 0;

  /// Check if error rate is high (> 5%)
  bool get hasHighErrorRate => perPercentage != null && perPercentage! > 5.0;

  /// Check if error rate is moderate (1-5%)
  bool get hasModerateErrorRate =>
      perPercentage != null && perPercentage! >= 1.0 && perPercentage! <= 5.0;

  /// Check if error rate is low (< 1%)
  bool get hasLowErrorRate => perPercentage != null && perPercentage! < 1.0;

  /// Get quality rating based on PER
  String get qualityRating {
    if (!isValid || testStatus != TestStatus.completed) return 'No Data';
    if (hasLowErrorRate) return 'Excellent';
    if (hasModerateErrorRate) return 'Good';
    return 'Poor';
  }

  /// Get formatted RSSI string
  String get rssiFormatted => BleDataConverter.formatRssi(rssi);

  /// Get formatted SNR string
  String get snrFormatted => BleDataConverter.formatSnr(snr);

  /// Reset all statistics to zero
  PerStatistics reset() {
    return PerStatistics(
      packetsReceived: 0,
      perValue: 0,
      rssi: rssi, // Keep current RSSI
      snr: snr, // Keep current SNR
      testStatus: TestStatus.stopped,
      lastUpdate: DateTime.now(),
    );
  }

  /// Update only packet statistics
  PerStatistics updatePacketStats({
    required int packetsReceived,
    required int perValue,
  }) {
    return PerStatistics(
      packetsReceived: packetsReceived,
      perValue: perValue,
      rssi: rssi,
      snr: snr,
      testStatus: testStatus,
      lastUpdate: DateTime.now(),
    );
  }

  /// Update only radio statistics
  PerStatistics updateRadioStats({
    required int rssi,
    required int snr,
  }) {
    return PerStatistics(
      packetsReceived: packetsReceived,
      perValue: perValue,
      rssi: rssi,
      snr: snr,
      testStatus: testStatus,
      lastUpdate: DateTime.now(),
    );
  }

  /// Create a copy with updated fields (immutable updates)
  PerStatistics copyWith({
    int? packetsReceived,
    int? perValue,
    int? rssi,
    int? snr,
    TestStatus? testStatus,
    DateTime? lastUpdate,
  }) {
    return PerStatistics(
      packetsReceived: packetsReceived ?? this.packetsReceived,
      perValue: perValue ?? this.perValue,
      rssi: rssi ?? this.rssi,
      snr: snr ?? this.snr,
      testStatus: testStatus ?? this.testStatus,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'packetsReceived': packetsReceived,
      'perValue': perValue,
      'rssi': rssi,
      'snr': snr,
      'testStatus': testStatus.value,
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }

  /// Create from JSON
  factory PerStatistics.fromJson(Map<String, dynamic> json) {
    return PerStatistics(
      packetsReceived: json['packetsReceived'] as int,
      perValue: json['perValue'] as int,
      rssi: json['rssi'] as int,
      snr: json['snr'] as int,
      testStatus: TestStatus.fromValue(json['testStatus'] as int),
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PerStatistics &&
        other.packetsReceived == packetsReceived &&
        other.perValue == perValue &&
        other.rssi == rssi &&
        other.snr == snr &&
        other.testStatus == testStatus;
  }

  @override
  int get hashCode {
    return Object.hash(
      packetsReceived,
      perValue,
      rssi,
      snr,
      testStatus,
    );
  }

  @override
  String toString() {
    return 'PerStatistics('
        'received: $packetsReceived, '
        'PER: $perFormatted, '
        'RSSI: $rssiFormatted, '
        'SNR: $snrFormatted, '
        'status: ${testStatus.displayName})';
  }
}
