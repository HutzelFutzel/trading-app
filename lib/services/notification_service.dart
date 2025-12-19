import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:trading_app/services/api_service.dart';
import 'package:trading_app/services/auth_service.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _apiService;
  final AuthService _authService;

  NotificationService(this._apiService, this._authService);

  Future<void> initialize() async {
    // 1. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // 2. Get Token & Register
      // On iOS, we might want to wait for APNs token first to ensure FCM token is mapped correctly
      if (!kIsWeb && Platform.isIOS) {
        String? apnsToken = await _fcm.getAPNSToken();
        print('APNs Token: $apnsToken');
        if (apnsToken == null) {
           print('Warning: APNs token is null. FCM token might not be generated correctly for iOS.');
           // We can wait a bit or just proceed, sometimes it takes a moment.
           await Future.delayed(const Duration(seconds: 3));
           apnsToken = await _fcm.getAPNSToken();
           print('APNs Token after retry: $apnsToken');
        }
      }

      String? token = await _fcm.getToken();
      print('FCM Token: $token');

      if (token != null) {
        await _registerToken(token);
      } else {
        print('Error: FCM Token is null');
      }

      // 3. Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
         print('FCM Token Refreshed: $newToken');
         _registerToken(newToken);
      });

      // 4. Configure Foreground Handling
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification}');
          // TODO: Show a local notification or dialog if desired
        }
      });
      
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> _registerToken(String token) async {
    final user = _authService.currentUser;
    if (user == null) {
      print('Cannot register FCM token: User is not logged in.');
      return;
    }

    try {
      String platform = 'web';
      if (!kIsWeb) {
        if (Platform.isAndroid) platform = 'android';
        if (Platform.isIOS) platform = 'ios';
      }
      
      print('Registering FCM token for user ${user.uid} on $platform...');
      
      await _apiService.post('/devices/register', {
        'userId': user.uid,
        'fcmToken': token,
        'platform': platform,
      });
      print('FCM Token registered successfully with backend.');
    } catch (e) {
      print('Error registering FCM token: $e');
      print('Make sure the backend is reachable. If on physical iOS device, localhost/127.0.0.1 will not work.');
    }
  }
  
  // Optional: Unregister on logout
  Future<void> deleteToken() async {
    try {
       String? token = await _fcm.getToken();
       if (token != null) {
         await _apiService.post('/devices/delete', {
           'fcmToken': token,
         });
       }
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }
}

