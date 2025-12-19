import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';


class ConfigService {
  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() {
    return _instance;
  }

  ConfigService._internal();

  Map<String, dynamic>? _config;

  Future<void> loadConfig() async {
    String configPath;
    
    // Determine which config to load
    // 1. Check for explicit ENV override via --dart-define=ENV=prod
    const String env = String.fromEnvironment('ENV', defaultValue: '');
    
    if (env == 'prod') {
      configPath = 'assets/config/app_config_prod.json';
    } else if (env == 'dev') {
      configPath = 'assets/config/app_config_dev.json';
    } else {
      // 2. Fallback to kReleaseMode
      if (kReleaseMode) {
        configPath = 'assets/config/app_config_prod.json';
      } else {
        configPath = 'assets/config/app_config_dev.json';
      }
    }

    try {
      final String response = await rootBundle.loadString(configPath);
      _config = json.decode(response);
      debugPrint('Loaded config from $configPath: $_config');
    } catch (e) {
      debugPrint('Error loading config from $configPath: $e');
      // Fallback or rethrow? For now, empty config which might cause runtime errors but better than crash loop
      _config = {};
    }
  }

  String get apiBaseUrl {
    String url = _config?['apiBaseUrl'] ?? 'http://localhost:8000';
    
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android Emulator: localhost refers to the emulator itself.
        // Use 10.0.2.2 to access the host machine.
        if (url.contains('localhost')) {
          url = url.replaceAll('localhost', '10.0.2.2');
        } else if (url.contains('127.0.0.1')) {
          url = url.replaceAll('127.0.0.1', '10.0.2.2');
        }
        debugPrint('ConfigService: Rewrote API URL for Android to $url');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS Simulator: 10.0.2.2 fails. Use localhost or 127.0.0.1.
        if (url.contains('10.0.2.2')) {
          url = url.replaceAll('10.0.2.2', '127.0.0.1');
          debugPrint('ConfigService: Rewrote API URL for iOS to $url');
        }
      }
    }
    
    return url;
  }
  
  String get environment => _config?['environment'] ?? 'unknown';
}
