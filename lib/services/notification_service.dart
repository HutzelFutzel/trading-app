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
      String? token = await _fcm.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // 3. Listen for token refreshes
      _fcm.onTokenRefresh.listen(_registerToken);

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
    if (user == null) return;

    try {
      String platform = 'web';
      if (!kIsWeb) {
        if (Platform.isAndroid) platform = 'android';
        if (Platform.isIOS) platform = 'ios';
      }
      
      // Device name is optional, skipping for now or could use device_info_plus
      
      await _apiService.post('/devices/register', {
        'userId': user.uid,
        'fcmToken': token,
        'platform': platform,
      });
      print('FCM Token registered successfully');
    } catch (e) {
      print('Error registering FCM token: $e');
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

