import 'dart:async';
import 'dart:io';
import 'package:ble_per_monitor/services/ble_platform/ble_platform.dart';
import '../models/per_device.dart';
import '../models/per_statistics.dart';
import '../models/radio_parameters.dart';
import '../utils/ble_constants.dart';

/// Singleton service managing all BLE operations for the PER monitor
class BleService {
  // Singleton pattern
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // Current connection state
  BluetoothDevice? _connectedDevice;
  BluetoothService? _perService;
  final Map<String, BluetoothCharacteristic> _characteristics = {};

  // Stream controllers
  final _scanResultsController = StreamController<List<PerDevice>>.broadcast();
  final _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  final _statisticsController = StreamController<PerStatistics>.broadcast();
  final _parametersController = StreamController<RadioParameters>.broadcast();

  // Internal state
  final List<PerDevice> _discoveredDevices = [];
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _scanStateSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _userInitiatedDisconnect = false;

  // Current statistics and parameters
  PerStatistics _currentStatistics = PerStatistics.initial();
  RadioParameters _currentParameters = RadioParameters.defaults();

  // Cached notification values for statistics (notify-only characteristics)
  List<int>? _cachedRxPackets;
  List<int>? _cachedPer;
  List<int>? _cachedRssi;
  List<int>? _cachedSnr;
  List<int>? _cachedTestStatus;

  // Track previous test status to detect transitions
  int? _previousTestStatus;

  // Getters for streams
  Stream<List<PerDevice>> get scanResultsStream => _scanResultsController.stream;
  Stream<BleConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<PerStatistics> get statisticsStream => _statisticsController.stream;
  Stream<RadioParameters> get parametersStream => _parametersController.stream;

  // Getters for current state
  BleConnectionState get connectionState => _connectionState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  PerStatistics get currentStatistics => _currentStatistics;
  RadioParameters get currentParameters => _currentParameters;
  List<PerDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Check if Bluetooth is enabled and supported
  Future<bool> checkBluetoothState() async {
    try {
      // Check if Bluetooth is supported
      if (!await FlutterBluePlus.isSupported) {
        throw BleException(BleErrorMessages.notSupported);
      }

      // Check adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        throw BleException(BleErrorMessages.bluetoothOff);
      }

      return true;
    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException(BleErrorMessages.unknownError);
    }
  }

  /// Request platform-specific BLE permissions
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android permissions are typically handled by flutter_blue_plus
        // Additional permissions may be needed in AndroidManifest.xml
        return true;
      } else if (Platform.isIOS) {
        // iOS permissions are handled automatically via Info.plist
        return true;
      }
      return true;
    } catch (e) {
      throw BleException(BleErrorMessages.permissionDenied);
    }
  }

  /// Start scanning for LR11xx PER RX devices
  Future<void> startScan() async {
    try {
      // Update state
      _updateConnectionState(BleConnectionState.scanning);

      // Clear previous results
      _discoveredDevices.clear();
      _scanResultsController.add([]);

      // Wait for Bluetooth adapter to be ready (important for iOS)
      await FlutterBluePlus.adapterState
          .where((state) => state == BluetoothAdapterState.on)
          .first
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw BleException(BleErrorMessages.bluetoothOff),
          );

      // Start scan
      await FlutterBluePlus.startScan(
        timeout: BleConfig.scanTimeout,
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          _processScanResults(results);
        },
        onError: (error) {
          _handleError(BleErrorMessages.scanFailed, error);
        },
      );

      // Listen to scan state to update UI when scan stops automatically
      _scanStateSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
        if (!isScanning && _connectionState == BleConnectionState.scanning) {
          _updateConnectionState(BleConnectionState.disconnected);
        }
      });
    } catch (e) {
      _handleError(BleErrorMessages.scanFailed, e);
      rethrow;
    }
  }

  /// Process scan results and filter for LR11xx devices
  void _processScanResults(List<ScanResult> results) {
    for (final result in results) {
      final device = PerDevice.fromScanResult(result);

      // Check if device matches our filter
      if (!device.isLr11xxDevice) continue;

      // Update or add device
      final index =
          _discoveredDevices.indexWhere((d) => d.deviceId == device.deviceId);
      if (index >= 0) {
        _discoveredDevices[index] = device;
      } else {
        _discoveredDevices.add(device);
      }
    }

    // Notify listeners
    _scanResultsController.add(List.unmodifiable(_discoveredDevices));
  }

  /// Stop active scan
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      await _scanStateSubscription?.cancel();
      _scanStateSubscription = null;

      if (_connectionState == BleConnectionState.scanning) {
        _updateConnectionState(BleConnectionState.disconnected);
      }
    } catch (e) {
      _handleError('Failed to stop scan', e);
    }
  }

  /// Connect to a specific device
  Future<void> connect(PerDevice device) async {
    try {
      // Stop scanning if active
      await stopScan();

      // Update state
      _updateConnectionState(BleConnectionState.connecting);
      _userInitiatedDisconnect = false;
      _reconnectAttempts = 0;

      // Get the BluetoothDevice
      BluetoothDevice? bluetoothDevice = device.bluetoothDevice;

      // If we don't have the device reference, find it from connected or bonded devices
      if (bluetoothDevice == null) {
        final systemDevices = FlutterBluePlus.connectedDevices;
        bluetoothDevice = systemDevices.firstWhere(
          (d) => d.remoteId.str == device.deviceId,
          orElse: () => throw BleException(BleErrorMessages.deviceNotFound),
        );
      }

      _connectedDevice = bluetoothDevice;

      // Listen to connection state changes
      _connectionSubscription =
          bluetoothDevice.connectionState.listen((state) {
        _handleConnectionStateChange(state);
      });

      // Connect with timeout
      await bluetoothDevice.connect(
        license: License.free, // Using free license (individuals, nonprofits, educational, <50 employees)
        timeout: BleConfig.connectionTimeout,
        autoConnect: false,
      );

      // Discover services
      await discoverServices();

      // Subscribe to notifications
      await subscribeToNotifications();

      // Read initial parameters
      await _readAllParameters();

      // Update state
      _updateConnectionState(BleConnectionState.connected);
    } on TimeoutException {
      _handleError(BleErrorMessages.connectionTimeout, null);
      await disconnect();
      rethrow;
    } catch (e) {
      _handleError(BleErrorMessages.connectionFailed, e);
      await disconnect();
      rethrow;
    }
  }

  /// Handle connection state changes from the device
  void _handleConnectionStateChange(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      _handleDisconnection();
    }
  }

  /// Handle device disconnection
  void _handleDisconnection() {
    // Clean up resources
    _cleanupConnection();

    // Update state
    _updateConnectionState(BleConnectionState.disconnected);

    // Attempt auto-reconnect if not user-initiated
    if (!_userInitiatedDisconnect && BleConfig.autoReconnect) {
      _scheduleReconnect();
    }
  }

  /// Schedule an auto-reconnect attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= BleConfig.maxReconnectAttempts) {
      _handleError('Max reconnect attempts reached', null);
      return;
    }

    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(BleConfig.reconnectDelay, () async {
      if (_connectedDevice != null) {
        try {
          final device = PerDevice.fromBluetoothDevice(
            _connectedDevice!,
            0, // rssi not available during reconnect
          );
          await connect(device);
        } catch (e) {
          _handleError('Reconnect failed', e);
        }
      }
    });
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    try {
      _userInitiatedDisconnect = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      if (_connectedDevice != null) {
        _updateConnectionState(BleConnectionState.disconnecting);
        await _connectedDevice!.disconnect();
      }

      _cleanupConnection();
      _updateConnectionState(BleConnectionState.disconnected);
    } catch (e) {
      _handleError('Failed to disconnect', e);
    }
  }

  /// Clean up connection resources
  void _cleanupConnection() {
    // Cancel subscriptions
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    // Clear characteristics
    for (final characteristic in _characteristics.values) {
      try {
        characteristic.setNotifyValue(false);
      } catch (_) {}
    }
    _characteristics.clear();

    // Clear service reference
    _perService = null;
  }

  /// Discover PER service and characteristics
  Future<void> discoverServices() async {
    try {
      if (_connectedDevice == null) {
        throw BleException('Not connected to any device');
      }

      // Discover services with timeout
      final services = await _connectedDevice!.discoverServices()
          .timeout(BleConfig.discoverServicesTimeout);

      // Find PER service
      _perService = services.firstWhere(
        (service) => service.uuid == BleUuids.toGuid(BleUuids.serviceUuid),
        orElse: () => throw BleException(BleErrorMessages.serviceNotFound),
      );

      // Map all characteristics by UUID
      for (final characteristic in _perService!.characteristics) {
        final uuidStr = characteristic.uuid.toString().toLowerCase();
        _characteristics[uuidStr] = characteristic;
      }

      // Verify required characteristics exist
      _verifyRequiredCharacteristics();
    } on TimeoutException {
      throw BleException('Service discovery timed out');
    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException(BleErrorMessages.serviceNotFound);
    }
  }

  /// Verify all required characteristics are present
  void _verifyRequiredCharacteristics() {
    final requiredUuids = [
      BleUuids.rxPacketsUuid,
      BleUuids.perUuid,
      BleUuids.rssiUuid,
      BleUuids.snrUuid,
      BleUuids.testStatusUuid,
      BleUuids.frequencyUuid,
      BleUuids.spreadingFactorUuid,
      BleUuids.bandwidthUuid,
      BleUuids.txPowerUuid,
    ];

    for (final uuid in requiredUuids) {
      final uuidLower = uuid.toLowerCase();
      // Try both full UUID and shortened version (e.g., "1901" vs "00001901-0000-1000-8000-00805f9b34fb")
      final shortUuid = _extractShortUuid(uuidLower);
      if (!_characteristics.containsKey(uuidLower) && !_characteristics.containsKey(shortUuid)) {
        throw BleException('Required characteristic $uuid not found. Device has ${_characteristics.length} characteristics.');
      }
    }
  }

  /// Extract short UUID (e.g., "1901" from "00001901-0000-1000-8000-00805f9b34fb")
  String _extractShortUuid(String fullUuid) {
    // Standard Bluetooth UUID format: 0000XXXX-0000-1000-8000-00805f9b34fb
    // Extract the XXXX part (positions 4-7)
    if (fullUuid.length >= 8 && fullUuid.contains('-')) {
      return fullUuid.substring(4, 8);
    }
    return fullUuid;
  }

  /// Subscribe to notifications for statistics characteristics
  Future<void> subscribeToNotifications() async {
    try {
      final notifyCharacteristics = [
        BleUuids.rxPacketsUuid,
        BleUuids.perUuid,
        BleUuids.rssiUuid,
        BleUuids.snrUuid,
        BleUuids.testStatusUuid,
      ];

      for (final uuid in notifyCharacteristics) {
        final characteristic = _getCharacteristic(uuid);

        // Workaround: flutter_blue_plus_windows may incorrectly report notify properties
        // Try to enable notifications regardless of advertised properties
        if (!BleCharacteristicProperties.canNotify(characteristic)) {
          print('DEBUG: Characteristic $uuid reports canNotify=false, attempting anyway');
          try {
            // Enable notifications with retry logic
            await _enableNotificationWithRetry(characteristic);

            // Listen to value updates
            characteristic.lastValueStream.listen(
              (value) => _handleCharacteristicUpdate(uuid, value),
              onError: (error) => _handleError('Notification error for $uuid', error),
            );
            print('DEBUG: Successfully subscribed to notifications for $uuid despite canNotify=false');
            continue;
          } catch (e) {
            print('DEBUG: Failed to subscribe to notifications for $uuid: $e');
            continue; // Skip if notify truly not supported
          }
        }

        // Enable notifications with retry logic
        await _enableNotificationWithRetry(characteristic);

        // Listen to value updates
        characteristic.lastValueStream.listen(
          (value) => _handleCharacteristicUpdate(uuid, value),
          onError: (error) => _handleError('Notification error for $uuid', error),
        );
      }
    } catch (e) {
      throw BleException(BleErrorMessages.notificationFailed);
    }
  }

  /// Enable notification with retry logic
  Future<void> _enableNotificationWithRetry(
      BluetoothCharacteristic characteristic) async {
    for (int attempt = 0; attempt < BleConfig.notificationRetryAttempts; attempt++) {
      try {
        await characteristic.setNotifyValue(true);
        return; // Success
      } catch (e) {
        if (attempt == BleConfig.notificationRetryAttempts - 1) {
          rethrow; // Last attempt failed
        }
        await Future.delayed(BleConfig.notificationRetryDelay);
      }
    }
  }

  /// Handle characteristic value updates
  void _handleCharacteristicUpdate(String uuid, List<int> value) {
    if (value.isEmpty) return;

    // DEBUG: Log notification arrival
    final timestamp = DateTime.now().toString().substring(11, 23); // HH:MM:SS.mmm
    print('DEBUG NOTIFY [$timestamp]: UUID=${uuid.substring(4, 8)} value=$value (${value.length} bytes)');

    try {
      // Cache notification data and update statistics
      final uuidLower = uuid.toLowerCase();

      if (uuidLower == BleUuids.rxPacketsUuid.toLowerCase()) {
        _cachedRxPackets = value;
        print('DEBUG NOTIFY: RX Packets = ${BleDataConverter.bytesToUint32(value)}');
        _updateStatisticsFromCache();
      } else if (uuidLower == BleUuids.perUuid.toLowerCase()) {
        _cachedPer = value;
        print('DEBUG NOTIFY: PER = ${BleDataConverter.perToPercentage(BleDataConverter.bytesToUint32(value))}%');
        _updateStatisticsFromCache();
      } else if (uuidLower == BleUuids.rssiUuid.toLowerCase()) {
        _cachedRssi = value;
        final rssiValue = BleDataConverter.bytesToInt16(value);
        print('DEBUG NOTIFY: RSSI = $rssiValue dBm');
        _updateStatisticsFromCache();
      } else if (uuidLower == BleUuids.snrUuid.toLowerCase()) {
        _cachedSnr = value;
        final snrValue = BleDataConverter.bytesToInt8(value);
        print('DEBUG NOTIFY: SNR = $snrValue dB');
        _updateStatisticsFromCache();
      } else if (uuidLower == BleUuids.testStatusUuid.toLowerCase()) {
        _cachedTestStatus = value;
        final testStatusValue = BleDataConverter.bytesToUint8(value);
        print('DEBUG NOTIFY: Test Status = $testStatusValue (previous: $_previousTestStatus)');

        // Detect STOPPED (0) → RUNNING (1) transition
        if (_previousTestStatus == 0 && testStatusValue == 1) {
          print('DEBUG: Test status changed from STOPPED to RUNNING');
        }

        // When test completes, read the PER value
        if (testStatusValue == 2) { // TestStatus.completed
          print('DEBUG: Test status changed to COMPLETED');
          _readPerOnTestComplete();
        }

        // Update previous status for next comparison
        _previousTestStatus = testStatusValue;

        // Force update statistics immediately when test status changes
        _forceUpdateStatistics();
      }
    } catch (e) {
      print('DEBUG NOTIFY ERROR: $e');
      _handleError('Failed to process characteristic update', e);
    }
  }

  /// Update statistics from cached notification values
  void _updateStatisticsFromCache() {
    // Only update if we have all required values
    if (_cachedRxPackets != null &&
        _cachedPer != null &&
        _cachedRssi != null &&
        _cachedSnr != null &&
        _cachedTestStatus != null) {
      _currentStatistics = PerStatistics.fromCharacteristics(
        rxPacketsBytes: _cachedRxPackets!,
        perBytes: _cachedPer!,
        rssiBytes: _cachedRssi!,
        snrBytes: _cachedSnr!,
        testStatusBytes: _cachedTestStatus!,
      );
      _statisticsController.add(_currentStatistics);
    }
  }

  /// Force update statistics even with partial data (used for test status changes)
  void _forceUpdateStatistics() {
    // Use cached values if available, otherwise use current values
    final rxPackets = _cachedRxPackets ?? BleDataConverter.uint32ToBytes(_currentStatistics.packetsReceived);
    final per = _cachedPer ?? BleDataConverter.uint32ToBytes(_currentStatistics.perValue);
    final rssi = _cachedRssi ?? BleDataConverter.int16ToBytes(_currentStatistics.rssi);
    final snr = _cachedSnr ?? BleDataConverter.int8ToBytes(_currentStatistics.snr);
    final testStatus = _cachedTestStatus ?? BleDataConverter.uint8ToBytes(_currentStatistics.testStatus.value);

    _currentStatistics = PerStatistics.fromCharacteristics(
      rxPacketsBytes: rxPackets,
      perBytes: per,
      rssiBytes: rssi,
      snrBytes: snr,
      testStatusBytes: testStatus,
    );
    _statisticsController.add(_currentStatistics);
    print('DEBUG: Forced statistics update with testStatus=${_currentStatistics.testStatus.displayName}');
  }

  /// Read PER characteristic when test completes
  Future<void> _readPerOnTestComplete() async {
    try {
      print('DEBUG: Test completed, reading final PER value');
      final perValue = await readCharacteristic(BleUuids.perUuid);
      _cachedPer = perValue;
      _updateStatisticsFromCache();
    } catch (e) {
      print('DEBUG: Failed to read PER on test complete: $e');
    }
  }

  /// Read all statistics characteristics
  Future<void> _readAllStatistics() async {
    try {
      final rxPackets = await readCharacteristic(BleUuids.rxPacketsUuid);
      final per = await readCharacteristic(BleUuids.perUuid);
      final rssi = await readCharacteristic(BleUuids.rssiUuid);
      final snr = await readCharacteristic(BleUuids.snrUuid);
      final testStatus = await readCharacteristic(BleUuids.testStatusUuid);

      // Initialize previous test status on first read
      _previousTestStatus = BleDataConverter.bytesToUint8(testStatus);

      _currentStatistics = PerStatistics.fromCharacteristics(
        rxPacketsBytes: rxPackets,
        perBytes: per,
        rssiBytes: rssi,
        snrBytes: snr,
        testStatusBytes: testStatus,
      );

      _statisticsController.add(_currentStatistics);
    } catch (e) {
      _handleError('Failed to read statistics', e);
    }
  }

  /// Read all parameter characteristics
  Future<void> _readAllParameters() async {
    try {
      final frequency = await readCharacteristic(BleUuids.frequencyUuid);
      final spreadingFactor =
          await readCharacteristic(BleUuids.spreadingFactorUuid);
      final bandwidth = await readCharacteristic(BleUuids.bandwidthUuid);
      final txPower = await readCharacteristic(BleUuids.txPowerUuid);

      _currentParameters = RadioParameters.fromCharacteristics(
        frequencyBytes: frequency,
        spreadingFactorBytes: spreadingFactor,
        bandwidthBytes: bandwidth,
        txPowerBytes: txPower,
      );

      _parametersController.add(_currentParameters);
    } catch (e) {
      _handleError('Failed to read parameters', e);
    }
  }

  /// Read a single characteristic value
  Future<List<int>> readCharacteristic(String uuid) async {
    try {
      final characteristic = _getCharacteristic(uuid);

      // Workaround: flutter_blue_plus_windows may incorrectly report read properties
      // Try to read regardless of advertised properties
      if (!BleCharacteristicProperties.canRead(characteristic)) {
        // Attempt read anyway - firmware may support it despite property flags
        try {
          final value = await characteristic.read()
              .timeout(BleConfig.characteristicOperationTimeout);
          return value;
        } catch (e) {
          throw BleException('Characteristic $uuid does not support read');
        }
      }

      final value = await characteristic.read()
          .timeout(BleConfig.characteristicOperationTimeout);

      return value;
    } on TimeoutException {
      throw BleException('Read timeout for characteristic $uuid');
    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException(BleErrorMessages.readFailed);
    }
  }

  /// Write a value to a characteristic
  Future<void> writeCharacteristic(String uuid, List<int> value) async {
    try {
      final characteristic = _getCharacteristic(uuid);

      // Workaround: flutter_blue_plus_windows may incorrectly report write properties
      // Try to write regardless of advertised properties
      if (!BleCharacteristicProperties.canWrite(characteristic)) {
        // Attempt write anyway - firmware may support it despite property flags
        try {
          await characteristic.write(value, withoutResponse: false)
              .timeout(BleConfig.characteristicOperationTimeout);

          // If it's a parameter characteristic, re-read all parameters
          if (_isParameterCharacteristic(uuid)) {
            await _readAllParameters();
          }
          return;
        } catch (e) {
          throw BleException('Characteristic $uuid does not support write');
        }
      }

      await characteristic.write(value, withoutResponse: false)
          .timeout(BleConfig.characteristicOperationTimeout);

      // If it's a parameter characteristic, re-read all parameters
      if (_isParameterCharacteristic(uuid)) {
        await _readAllParameters();
      }
    } on TimeoutException {
      throw BleException('Write timeout for characteristic $uuid');
    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException(BleErrorMessages.writeFailed);
    }
  }

  /// Check if a UUID is a parameter characteristic
  bool _isParameterCharacteristic(String uuid) {
    final parameterUuids = [
      BleUuids.frequencyUuid,
      BleUuids.spreadingFactorUuid,
      BleUuids.bandwidthUuid,
      BleUuids.txPowerUuid,
    ];
    return parameterUuids.contains(uuid);
  }

  /// Get a characteristic by UUID
  BluetoothCharacteristic _getCharacteristic(String uuid) {
    final uuidLower = uuid.toLowerCase();
    // Try full UUID first
    var characteristic = _characteristics[uuidLower];
    // If not found, try short UUID format
    if (characteristic == null) {
      final shortUuid = _extractShortUuid(uuidLower);
      characteristic = _characteristics[shortUuid];
    }
    if (characteristic == null) {
      throw BleException(BleErrorMessages.characteristicNotFound);
    }
    return characteristic;
  }

  /// Write radio parameters to device
  Future<void> writeRadioParameters(RadioParameters parameters) async {
    try {
      // Validate parameters
      if (!parameters.isValid) {
        final errors = parameters.getValidationErrors();
        throw BleException('Invalid parameters: ${errors.join(', ')}');
      }

      // Write each parameter
      await writeCharacteristic(
          BleUuids.frequencyUuid, parameters.frequencyToBytes());
      await writeCharacteristic(BleUuids.spreadingFactorUuid,
          parameters.spreadingFactorToBytes());
      await writeCharacteristic(
          BleUuids.bandwidthUuid, parameters.bandwidthToBytes());
      await writeCharacteristic(
          BleUuids.txPowerUuid, parameters.txPowerToBytes());

      // Update current parameters
      _currentParameters = parameters;
      _parametersController.add(_currentParameters);
    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException('Failed to write radio parameters');
    }
  }

  /// Reset statistics on device
  Future<void> resetStatistics() async {
    try {
      // Write 1 to reset characteristic
      await writeCharacteristic(BleUuids.resetStatsUuid, [1]);

      // Clear all cached notification values to start fresh
      _cachedRxPackets = null;
      _cachedPer = null;
      _cachedRssi = null;
      _cachedSnr = null;
      _cachedTestStatus = null;
      _previousTestStatus = null;

      // Wait a bit for device to reset
      await Future.delayed(const Duration(milliseconds: 200));

      // Read updated statistics (this will also reinitialize _previousTestStatus)
      await _readAllStatistics();

      print('DEBUG: Statistics reset - all caches cleared and values re-read from device');
    } catch (e) {
      throw BleException('Failed to reset statistics');
    }
  }

  /// Start RX test (write 0x01 to Test Control)
  Future<void> startRxTest() async {
    try {
      await writeCharacteristic(BleUuids.testControlUuid, [0x01]);
    } catch (e) {
      throw BleException('Failed to start RX test');
    }
  }

  /// Stop RX test (write 0x00 to Test Control)
  Future<void> stopRxTest() async {
    try {
      await writeCharacteristic(BleUuids.testControlUuid, [0x00]);
    } catch (e) {
      throw BleException('Failed to stop RX test');
    }
  }

  /// Read current test control state
  Future<int> readTestControlState() async {
    try {
      final bytes = await readCharacteristic(BleUuids.testControlUuid);
      return BleDataConverter.bytesToUint8(bytes);
    } catch (e) {
      throw BleException('Failed to read test control state');
    }
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(BleConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateController.add(_connectionState);
    }
  }

  /// Handle errors and notify listeners
  void _handleError(String message, dynamic error) {
    // Update state to error if we're not already disconnected
    if (_connectionState != BleConnectionState.disconnected) {
      _updateConnectionState(BleConnectionState.error);
    }

    // Log error (in production, use proper logging)
    print('BLE Error: $message - $error');

    // Could add error stream here if needed
  }

  /// Dispose of all resources
  void dispose() {
    _reconnectTimer?.cancel();
    _scanSubscription?.cancel();
    _scanStateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _cleanupConnection();

    _scanResultsController.close();
    _connectionStateController.close();
    _statisticsController.close();
    _parametersController.close();
  }
}

/// Custom exception for BLE errors
class BleException implements Exception {
  final String message;
  BleException(this.message);

  @override
  String toString() => message;
}
