import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/per_device.dart';
import 'screens/device_scan_screen.dart';
import 'screens/statistics_dashboard_screen.dart';
import 'screens/parameters_screen.dart';
import 'services/ble_service.dart';
import 'utils/theme.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const BlePerMonitorApp());
}

/// Main application widget
class BlePerMonitorApp extends StatelessWidget {
  const BlePerMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Singleton BLE service provider
        Provider<BleService>(
          create: (_) => BleService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'LR11xx PER Monitor',
        debugShowCheckedModeBanner: false,

        // Theme configuration
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,

        // Navigation configuration
        initialRoute: '/',
        onGenerateRoute: _generateRoute,

        // Error handling
        builder: (context, widget) {
          // Global error boundary wrapper
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            return _ErrorScreen(errorDetails: errorDetails);
          };
          return widget ?? const SizedBox.shrink();
        },
      ),
    );
  }

  /// Generate routes with proper argument handling
  static Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const DeviceScanScreen(),
          settings: settings,
        );

      case '/statistics':
        final device = settings.arguments as PerDevice?;
        if (device == null) {
          // No device provided, redirect to scan
          return MaterialPageRoute(
            builder: (_) => const DeviceScanScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => StatisticsDashboardScreen(device: device),
          settings: settings,
        );

      case '/parameters':
        return MaterialPageRoute(
          builder: (_) => const ParametersScreen(),
          settings: settings,
        );

      default:
        // Unknown route, show 404
        return MaterialPageRoute(
          builder: (_) => const _NotFoundScreen(),
        );
    }
  }
}

/// Error screen for unhandled errors
class _ErrorScreen extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const _ErrorScreen({required this.errorDetails});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Oops! Something went wrong',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  errorDetails.exception.toString(),
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => runApp(const BlePerMonitorApp()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 404 Not Found screen
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text('404 - Page Not Found', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('The page you are looking for does not exist.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
              icon: const Icon(Icons.home),
              label: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
