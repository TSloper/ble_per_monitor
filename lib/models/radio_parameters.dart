import '../utils/ble_constants.dart';

/// Represents LoRa radio configuration parameters
class RadioParameters {
  /// Frequency in Hz (uint32)
  /// Valid range: 300,000,000 - 1,000,000,000 Hz (300-1000 MHz)
  final int frequency;

  /// LoRa spreading factor (uint8)
  /// Valid range: 5-12
  final int spreadingFactor;

  /// LoRa bandwidth (uint8)
  /// Valid values: 0 (125 kHz), 1 (250 kHz), 2 (500 kHz)
  final int bandwidth;

  /// Transmit power in dBm (int8)
  /// Valid range: -9 to +22 dBm
  final int txPower;

  const RadioParameters({
    required this.frequency,
    required this.spreadingFactor,
    required this.bandwidth,
    required this.txPower,
  });

  /// Create default radio parameters (915 MHz, SF7, 125 kHz, 14 dBm)
  factory RadioParameters.defaults() {
    return RadioParameters(
      frequency: BleParameterRanges.frequencyDefault * 1000000, // Convert MHz to Hz
      spreadingFactor: BleParameterRanges.spreadingFactorDefault,
      bandwidth: BleParameterRanges.bandwidthDefault,
      txPower: BleParameterRanges.txPowerDefault,
    );
  }

  /// Create from BLE characteristic values
  factory RadioParameters.fromCharacteristics({
    required List<int> frequencyBytes,
    required List<int> spreadingFactorBytes,
    required List<int> bandwidthBytes,
    required List<int> txPowerBytes,
  }) {
    try {
      return RadioParameters(
        frequency: BleDataConverter.bytesToUint32(frequencyBytes),
        spreadingFactor: BleDataConverter.bytesToUint8(spreadingFactorBytes),
        bandwidth: BleDataConverter.bytesToUint8(bandwidthBytes),
        txPower: BleDataConverter.bytesToInt8(txPowerBytes),
      );
    } catch (e) {
      // Return defaults if conversion fails
      return RadioParameters.defaults();
    }
  }

  /// Frequency presets in Hz
  static const int freq915MHz = 915000000;
  static const int freq868MHz = 868000000;
  static const int freq433MHz = 433000000;
  static const int freq470MHz = 470000000;
  static const int freq779MHz = 779000000;

  /// Create preset for US 915 MHz
  factory RadioParameters.preset915MHz() {
    return RadioParameters(
      frequency: freq915MHz,
      spreadingFactor: 7,
      bandwidth: 0, // 125 kHz
      txPower: 14,
    );
  }

  /// Create preset for EU 868 MHz
  factory RadioParameters.preset868MHz() {
    return RadioParameters(
      frequency: freq868MHz,
      spreadingFactor: 7,
      bandwidth: 0, // 125 kHz
      txPower: 14,
    );
  }

  /// Create preset for 433 MHz
  factory RadioParameters.preset433MHz() {
    return RadioParameters(
      frequency: freq433MHz,
      spreadingFactor: 7,
      bandwidth: 0, // 125 kHz
      txPower: 14,
    );
  }

  /// Validate all parameters
  bool get isValid {
    return isValidFrequency &&
        isValidSpreadingFactor &&
        isValidBandwidth &&
        isValidTxPower;
  }

  /// Validate frequency (300-1000 MHz)
  bool get isValidFrequency {
    const minHz = 300000000; // 300 MHz
    const maxHz = 1000000000; // 1000 MHz
    return frequency >= minHz && frequency <= maxHz;
  }

  /// Validate spreading factor (5-12)
  bool get isValidSpreadingFactor {
    return spreadingFactor >= 5 && spreadingFactor <= 12;
  }

  /// Validate bandwidth (0, 1, or 2)
  bool get isValidBandwidth {
    return bandwidth >= 0 && bandwidth <= 2;
  }

  /// Validate TX power (-9 to +22 dBm)
  bool get isValidTxPower {
    return txPower >= -9 && txPower <= 22;
  }

  /// Get frequency in MHz
  double get frequencyMHz {
    return frequency / 1000000.0;
  }

  /// Get bandwidth enum
  LoraBandwidth get bandwidthEnum {
    return LoraBandwidth.fromValue(bandwidth);
  }

  /// Get spreading factor enum
  LoraSpreadingFactor get spreadingFactorEnum {
    return LoraSpreadingFactor.fromValue(spreadingFactor);
  }

  /// Convert frequency to bytes for BLE write (uint32, little-endian)
  List<int> frequencyToBytes() {
    return BleDataConverter.uint32ToBytes(frequency);
  }

  /// Convert spreading factor to bytes for BLE write (uint8)
  List<int> spreadingFactorToBytes() {
    return BleDataConverter.uint8ToBytes(spreadingFactor);
  }

  /// Convert bandwidth to bytes for BLE write (uint8)
  List<int> bandwidthToBytes() {
    return BleDataConverter.uint8ToBytes(bandwidth);
  }

  /// Convert TX power to bytes for BLE write (int8)
  List<int> txPowerToBytes() {
    return BleDataConverter.int8ToBytes(txPower);
  }

  /// Convert all parameters to a map of characteristic bytes
  Map<String, List<int>> toBytes() {
    return {
      'frequency': frequencyToBytes(),
      'spreadingFactor': spreadingFactorToBytes(),
      'bandwidth': bandwidthToBytes(),
      'txPower': txPowerToBytes(),
    };
  }

  /// Create from bytes for BLE read operations
  static RadioParameters fromBytes({
    required List<int> frequencyBytes,
    required List<int> spreadingFactorBytes,
    required List<int> bandwidthBytes,
    required List<int> txPowerBytes,
  }) {
    return RadioParameters.fromCharacteristics(
      frequencyBytes: frequencyBytes,
      spreadingFactorBytes: spreadingFactorBytes,
      bandwidthBytes: bandwidthBytes,
      txPowerBytes: txPowerBytes,
    );
  }

  /// Create a validated copy with clamped values
  RadioParameters validated() {
    return RadioParameters(
      frequency: _clampFrequency(frequency),
      spreadingFactor: _clampSpreadingFactor(spreadingFactor),
      bandwidth: _clampBandwidth(bandwidth),
      txPower: _clampTxPower(txPower),
    );
  }

  /// Clamp frequency to valid range
  static int _clampFrequency(int freq) {
    const minHz = 300000000;
    const maxHz = 1000000000;
    return freq.clamp(minHz, maxHz);
  }

  /// Clamp spreading factor to valid range
  static int _clampSpreadingFactor(int sf) {
    return sf.clamp(5, 12);
  }

  /// Clamp bandwidth to valid range
  static int _clampBandwidth(int bw) {
    return bw.clamp(0, 2);
  }

  /// Clamp TX power to valid range
  static int _clampTxPower(int power) {
    return power.clamp(-9, 22);
  }

  /// Get validation errors as a list of strings
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (!isValidFrequency) {
      errors.add(
          'Frequency must be between 300-1000 MHz (got ${frequencyMHz.toStringAsFixed(1)} MHz)');
    }

    if (!isValidSpreadingFactor) {
      errors.add('Spreading Factor must be between 5-12 (got $spreadingFactor)');
    }

    if (!isValidBandwidth) {
      errors.add('Bandwidth must be 0, 1, or 2 (got $bandwidth)');
    }

    if (!isValidTxPower) {
      errors.add('TX Power must be between -9 and +22 dBm (got $txPower dBm)');
    }

    return errors;
  }

  /// Create a copy with updated fields (immutable updates)
  RadioParameters copyWith({
    int? frequency,
    int? spreadingFactor,
    int? bandwidth,
    int? txPower,
  }) {
    return RadioParameters(
      frequency: frequency ?? this.frequency,
      spreadingFactor: spreadingFactor ?? this.spreadingFactor,
      bandwidth: bandwidth ?? this.bandwidth,
      txPower: txPower ?? this.txPower,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'spreadingFactor': spreadingFactor,
      'bandwidth': bandwidth,
      'txPower': txPower,
    };
  }

  /// Create from JSON
  factory RadioParameters.fromJson(Map<String, dynamic> json) {
    return RadioParameters(
      frequency: json['frequency'] as int,
      spreadingFactor: json['spreadingFactor'] as int,
      bandwidth: json['bandwidth'] as int,
      txPower: json['txPower'] as int,
    );
  }

  /// Get formatted string for frequency
  String get frequencyFormatted {
    return BleDataConverter.formatFrequency(frequencyMHz.round());
  }

  /// Get formatted string for TX power
  String get txPowerFormatted {
    return BleDataConverter.formatTxPower(txPower);
  }

  /// Get formatted string for bandwidth
  String get bandwidthFormatted {
    return bandwidthEnum.displayName;
  }

  /// Get formatted string for spreading factor
  String get spreadingFactorFormatted {
    return spreadingFactorEnum.displayName;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RadioParameters &&
        other.frequency == frequency &&
        other.spreadingFactor == spreadingFactor &&
        other.bandwidth == bandwidth &&
        other.txPower == txPower;
  }

  @override
  int get hashCode {
    return Object.hash(frequency, spreadingFactor, bandwidth, txPower);
  }

  @override
  String toString() {
    return 'RadioParameters('
        'freq: $frequencyFormatted, '
        'SF: $spreadingFactorFormatted, '
        'BW: $bandwidthFormatted, '
        'power: $txPowerFormatted)';
  }
}
