import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/config_service.dart';
import '../screens/signin_screen.dart';
import '../screens/home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    // Ideally use a Service Locator (GetIt) or Provider
    final configService = ConfigService();
    // Ensure baseUrl is passed to ApiService
    _notificationService = NotificationService(
      ApiService(baseUrl: configService.apiBaseUrl), 
      AuthService()
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // Initialize notifications when user is authenticated
          _notificationService.initialize();
          return const HomeScreen();
        }

        return const SignInScreen();
      },
    );
  }
}

