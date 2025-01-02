enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  // Force production environment
  static final Environment _environment = Environment.production;
  
  // Base URLs for different environments
  static const String _baseDeviceUrl = 'http://192.168.1.2:3001';
  static const String _baseEmulatorUrl = 'http://10.0.2.2:3001';
  static const String _baseProductionUrl = 'https://pinewraps-api.onrender.com';
  
  // Always use production URL
  static final String _currentBaseUrl = _baseProductionUrl;

  // Remove ability to change environment
  static void setEnvironment(Environment env) {
    // Do nothing - environment is locked to production
  }

  // Remove ability to switch to emulator
  static void useEmulator(bool useEmulator) {
    // Do nothing - environment is locked to production
  }

  static String get baseUrl => _currentBaseUrl;
  static String get apiBaseUrl => '$_currentBaseUrl/api';
  static String get imageBaseUrl => '$_currentBaseUrl/images';
  static String get uploadBaseUrl => '$_currentBaseUrl/uploads';

  static bool get isDevelopment => false;
  static bool get isProduction => true;
}
