import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_wrapper.dart';
import 'services/config_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Use Firebase Emulator in debug mode
  if (kDebugMode) {
    try {
      String authHost = 'localhost';
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        authHost = '10.0.2.2';
      }
      await FirebaseAuth.instance.useAuthEmulator(authHost, 9099);
      print('Using Firebase Auth Emulator at $authHost:9099');
    } catch (e) {
      print('Failed to use Firebase Auth Emulator: $e');
    }
  }

  await ConfigService().loadConfig();
  runApp(const TradingApp());
}

class TradingApp extends StatelessWidget {
  const TradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlphaRelay',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

