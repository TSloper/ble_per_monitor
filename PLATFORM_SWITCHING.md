# Platform Switching Guide

This document explains how to switch between iOS/Android/macOS builds and Windows builds.

## Problem

The BLE packages for different platforms have incompatible version requirements:
- **flutter_blue_plus** v2.0+ (for iOS/Android/macOS) uses a newer API with License parameters
- **flutter_blue_plus_windows** v1.26.1 (for Windows) depends on flutter_blue_plus v1.32-1.34 (older version)

These packages cannot coexist in `pubspec.yaml` due to version conflicts.

## Solution

The codebase is designed to work with either package through a platform abstraction layer at:
`lib/services/ble_platform/ble_platform.dart`

This file re-exports the appropriate BLE package, and all application code imports from this abstraction layer.

## Switching to iOS/Android/macOS Build (Current Configuration)

**pubspec.yaml:**
```yaml
dependencies:
  flutter_blue_plus: '>=2.0.0'
  # flutter_blue_plus_windows: ^1.26.1  # Commented out
```

**Platform abstraction (lib/services/ble_platform/ble_platform.dart):**
```dart
export 'package:flutter_blue_plus/flutter_blue_plus.dart';
```

Then run:
```bash
flutter pub get
flutter build ios  # or macos, android
```

## Switching to Windows Build

### 1. Update pubspec.yaml

Comment out flutter_blue_plus and uncomment flutter_blue_plus_windows:

```yaml
dependencies:
  # flutter_blue_plus: '>=2.0.0'  # Commented out for Windows
  flutter_blue_plus_windows: ^1.26.1
```

### 2. Update platform abstraction

Edit `lib/services/ble_platform/ble_platform.dart`:

```dart
// Comment out:
// export 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Uncomment:
export 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
```

### 3. Update BLE service

Edit `lib/services/ble_service.dart` - Remove the `license` parameter from the connect call (around line 203):

```dart
// For Windows (flutter_blue_plus_windows):
await bluetoothDevice.connect(
  timeout: BleConfig.connectionTimeout,
  autoConnect: false,
);
```

Instead of:

```dart
// For iOS/Android/macOS (flutter_blue_plus v2.0+):
await bluetoothDevice.connect(
  license: License.free,
  timeout: BleConfig.connectionTimeout,
  autoConnect: false,
);
```

### 4. Build for Windows

```bash
flutter pub get
flutter build windows
```

## Notes

- The `License.free` parameter is only required in flutter_blue_plus v2.0+
- flutter_blue_plus_windows uses the older API without this parameter
- All other BLE APIs are compatible between the packages
- The platform abstraction layer ensures application code remains unchanged

## License Information

When using flutter_blue_plus v2.0+, you must specify a license:

- **License.free**: For individuals, nonprofits, educational institutions, and organizations with <50 employees
- **License.commercial**: For for-profit organizations with ≥50 employees (requires purchase)

See the flutter_blue_plus LICENSE file for details.
