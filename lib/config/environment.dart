enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  // Current environment
  static Environment _environment = Environment.production;

  // Base URLs for different environments
  static const String _baseLocalUrl = 'http://localhost:3001';
  static String _baseLocalNetworkUrl =
      'http://localhost:3001'; // Will be set dynamically
  static const String _baseEmulatorUrl = 'http://192.168.1.33:3001';
  static const String _baseProductionUrl = 'https://pinewraps-api.onrender.com';

  // Use emulator flag
  static bool _useEmulator = true;

  // Use physical device flag
  static bool _usePhysicalDevice = true;

  // Dynamic base URL based on environment
  static String get _currentBaseUrl {
    switch (_environment) {
      case Environment.development:
        if (_useEmulator) {
          return _baseEmulatorUrl;
        } else if (_usePhysicalDevice) {
          return _baseLocalNetworkUrl;
        } else {
          return _baseLocalUrl;
        }
      case Environment.staging:
        return _baseLocalNetworkUrl;
      case Environment.production:
        return _baseProductionUrl;
    }
  }

  // Set environment
  static void setEnvironment(Environment env) {
    _environment = env;
  }

  // Toggle emulator mode
  static void useEmulator(bool useEmulator) {
    _useEmulator = useEmulator;
  }

  // Toggle physical device mode
  static void usePhysicalDevice(bool usePhysicalDevice) {
    _usePhysicalDevice = usePhysicalDevice;
  }

  // Set local network URL (for physical devices)
  static void setLocalNetworkUrl(String ip) {
    _baseLocalNetworkUrl = 'http://$ip:3001';
  }

  static String get baseUrl => _currentBaseUrl;
  static String get apiBaseUrl => '$_currentBaseUrl/api';
  static String get imageBaseUrl => '$_currentBaseUrl/images';
  static String get uploadBaseUrl => '$_currentBaseUrl/uploads';

  static bool get isDevelopment => _environment == Environment.development;
  static bool get isRunningInProduction =>
      _environment == Environment.production;
  static bool get isProduction => _environment == Environment.production;
}
