// Platform-agnostic BLE package re-export
//
// This provides a single import point for BLE functionality that works across platforms.
// The actual package used depends on which dependency is active in pubspec.yaml:
//
// - For iOS/Android/macOS: Enable flutter_blue_plus (v2.0+) in pubspec.yaml
// - For Windows: Enable flutter_blue_plus_windows (v1.26.1) in pubspec.yaml
//
// Since these packages cannot coexist (version conflict), you must comment/uncomment
// the appropriate dependency when switching platforms.
//
// Usage:
//   import 'package:ble_per_monitor/services/ble_platform/ble_platform.dart';

// Try to import flutter_blue_plus first (for iOS/Android/macOS)
// If it's not available, fall back to flutter_blue_plus_windows
export 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Note: When flutter_blue_plus is not in pubspec.yaml, uncomment the line below
// and comment the line above:
// export 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
