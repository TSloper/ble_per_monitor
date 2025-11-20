# BLE PER Monitor

A professional monitoring client application for Bluetooth Low Energy (BLE) Packet Error Rate (PER) statistics. This Flutter application provides real-time monitoring, statistics visualization, and comprehensive analysis of BLE device performance.

## Features

- Real-time BLE device scanning and connection
- Packet Error Rate (PER) monitoring
- Live statistics visualization with charts
- Support for multiple platforms (Windows, Linux, iOS, Android)
- Material Design 3 with light and dark theme support
- Professional dashboard interface

## Requirements

### Minimum Platform Versions

- **Android**: API Level 21 (Android 5.0 Lollipop) or higher
- **iOS**: iOS 12.0 or higher
- **Windows**: Windows 10/11 with BLE support
- **Linux**: BlueZ 5.0 or higher

### Development Requirements

- Flutter SDK 3.10.0 or higher
- Dart SDK 3.10.0 or higher
- For Android: Android Studio with Android SDK
- For iOS: Xcode 13 or higher
- For Windows: Visual Studio 2022 with C++ Desktop Development
- For Linux: BlueZ development libraries

## Dependencies

This project uses the following key packages:

- `flutter_blue_plus: ^1.32.0` - BLE connectivity and communication
- `provider: ^6.1.0` - State management
- `fl_chart: ^0.68.0` - Statistics charts and visualization
- `intl: ^0.19.0` - Number formatting and internationalization
- `permission_handler: ^11.3.0` - Runtime permissions for BLE

## Platform-Specific Setup

### Android

The app requires the following permissions (already configured):
- BLUETOOTH
- BLUETOOTH_ADMIN
- BLUETOOTH_SCAN
- BLUETOOTH_CONNECT
- ACCESS_FINE_LOCATION
- ACCESS_COARSE_LOCATION

### iOS

The app requires Bluetooth and location permissions (already configured in Info.plist):
- NSBluetoothAlwaysUsageDescription
- NSBluetoothPeripheralUsageDescription
- NSLocationWhenInUseUsageDescription

### Linux

Install BlueZ development libraries:
```bash
sudo apt-get install bluez libbluetooth-dev
```

### Windows

Ensure your system has Bluetooth Low Energy support. Windows 10/11 typically includes this by default.

## Getting Started

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

### Running the App

```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d windows
flutter run -d linux
flutter run -d android
flutter run -d ios
```

### Building for Release

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

## Project Structure

```
ble_per_monitor/
├── lib/
│   ├── main.dart              # Application entry point
│   ├── screens/               # UI screens
│   ├── services/              # BLE and business logic services
│   ├── models/                # Data models
│   ├── widgets/               # Reusable UI components
│   └── utils/                 # Utility functions and theme
├── assets/                    # Images and resources
├── android/                   # Android platform code
├── ios/                       # iOS platform code
├── linux/                     # Linux platform code
├── windows/                   # Windows platform code
└── test/                      # Unit and widget tests
```

## License

This project is licensed under the MIT License.

## Support

For issues, feature requests, or contributions, please visit the project repository.
