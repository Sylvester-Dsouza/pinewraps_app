import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/subjects.dart';
import 'api_service.dart';
import 'dart:io';
import 'package:dio/dio.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final _onMessageOpenedAppController = BehaviorSubject<RemoteMessage>();
  final _unreadCountController = BehaviorSubject<int>.seeded(0);
  final ApiService _apiService = ApiService();
  bool _initialized = false;

  Stream<RemoteMessage> get onMessageOpenedApp => _onMessageOpenedAppController.stream;
  Stream<int> get unreadCount => _unreadCountController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    
    // Request permission for iOS
    if (!kIsWeb) {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    // Configure FCM handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Check for initial notification (app opened from terminated state)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    // Load initial unread count
    await _loadUnreadCount();

    // Check if we have a logged in user to register the token
    final email = await _apiService.getCachedCustomerEmailAsync();
    if (email != null && email.isNotEmpty) {
      print('Found logged in user: $email, registering device token');
      await registerDeviceToken(email: email);
    } else {
      print('No logged in user found during initialization');
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }

    // Save notification to history
    await _saveNotificationToHistory(message);

    // Update unread count
    await _incrementUnreadCount();
  }

  // Handle notification taps
  void _handleNotificationOpen(RemoteMessage message) {
    print('Notification opened: ${message.messageId}');
    _onMessageOpenedAppController.add(message);
  }

  // Save notification to local history
  Future<void> _saveNotificationToHistory(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('notification_history') ?? [];
      
      // Create notification object
      final Map<String, dynamic> notificationData = {
        'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'createdAt': DateTime.now().toIso8601String(),
        'read': false,
      };
      
      // Add to history (limit to 100 items)
      history.insert(0, jsonEncode(notificationData));
      if (history.length > 100) {
        history = history.sublist(0, 100);
      }
      
      await prefs.setStringList('notification_history', history);
    } catch (e) {
      print('Error saving notification to history: $e');
    }
  }

  // Get notification history
  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('notification_history') ?? [];
      
      return history.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting notification history: $e');
      return [];
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('notification_history') ?? [];
      
      List<Map<String, dynamic>> notifications = 
          history.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
      
      for (int i = 0; i < notifications.length; i++) {
        if (notifications[i]['id'] == id) {
          notifications[i]['read'] = true;
          break;
        }
      }
      
      history = notifications.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList('notification_history', history);
      
      // Update unread count
      await _updateUnreadCount();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('notification_history') ?? [];
      
      List<Map<String, dynamic>> notifications = 
          history.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
      
      for (int i = 0; i < notifications.length; i++) {
        notifications[i]['read'] = true;
      }
      
      history = notifications.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList('notification_history', history);
      
      // Reset unread count
      await _resetUnreadCount();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Load unread count from storage
  Future<void> _loadUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int count = prefs.getInt('unread_notification_count') ?? 0;
      _unreadCountController.add(count);
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  // Increment unread count
  Future<void> _incrementUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int count = prefs.getInt('unread_notification_count') ?? 0;
      count++;
      await prefs.setInt('unread_notification_count', count);
      _unreadCountController.add(count);
    } catch (e) {
      print('Error incrementing unread count: $e');
    }
  }

  // Update unread count based on unread notifications
  Future<void> _updateUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('notification_history') ?? [];
      
      List<Map<String, dynamic>> notifications = 
          history.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
      
      int count = notifications.where((item) => item['read'] == false).length;
      
      await prefs.setInt('unread_notification_count', count);
      _unreadCountController.add(count);
    } catch (e) {
      print('Error updating unread count: $e');
    }
  }

  // Public method to refresh unread count
  Future<void> refreshUnreadCount() async {
    await _updateUnreadCount();
  }

  // Register the device token with the backend
  Future<void> registerDeviceToken({required String email}) async {
    try {
      print('Starting FCM token registration process for email: $email');
      
      if (email.isEmpty) {
        print('Cannot register device token: email is empty');
        return;
      }
      
      print('Getting FCM token from Firebase...');
      final token = await _firebaseMessaging.getToken();
      print('FCM token received: ${token != null ? 'Yes' : 'No'}');
      
      if (token != null) {
        print('Registering device token for $email: $token');
        final platform = Platform.isAndroid ? 'android' : 'ios';
        print('Device platform: $platform');
        
        // Cache the email in SharedPreferences for later use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customer_email', email);
        print('Cached customer email in SharedPreferences: $email');
        
        // Try registration multiple times in case of failure
        bool success = false;
        for (int i = 0; i < 3; i++) {
          print('Attempt ${i+1} to register FCM token...');
          
          // Pass the email directly to the registerDeviceToken method
          final Map<String, dynamic> data = {
            'token': token,
            'email': email,
            'platform': platform,
          };
          
          // Use a direct API call to the backend
          try {
            final dio = Dio(BaseOptions(
              baseUrl: 'http://192.168.1.4:3001/api',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ));
            
            print('Sending direct request to register FCM token...');
            final response = await dio.post(
              '/customer-auth/register-fcm-token-public',
              data: data,
            );
            
            print('FCM token registration response: ${response.statusCode}');
            print('FCM token registration data: ${response.data}');
            
            success = response.statusCode == 200 || response.statusCode == 201;
            if (success) {
              print('Successfully registered FCM token with backend');
              break;
            }
          } catch (directError) {
            print('Error with direct API call: $directError');
            
            // Fall back to using the API service
            success = await _apiService.registerDeviceToken(token, platform);
            if (success) {
              print('Successfully registered FCM token with API service');
              break;
            } else {
              print('Failed to register FCM token with backend (attempt ${i+1}/3)');
              // Wait before retrying
              if (i < 2) {
                print('Waiting before retry...');
                await Future.delayed(const Duration(seconds: 2));
              }
            }
          }
        }
        
        if (!success) {
          print('All attempts to register FCM token failed');
        }
      } else {
        print('Unable to get FCM token from Firebase');
      }
    } catch (e) {
      print('Error registering device token: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Async alias for registerDeviceToken to match the method signature in AuthService
  Future<void> registerDeviceTokenAsync({required String email}) async {
    return registerDeviceToken(email: email);
  }

  // Unregister the device token from the backend
  Future<void> unregisterDeviceToken() async {
    try {
      print('Starting FCM token unregistration process');
      
      // Get the token before trying to unregister
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        print('No FCM token to unregister');
        return;
      }
      
      print('FCM token to unregister: $token');
      
      // Try unregistration multiple times in case of failure
      bool success = false;
      for (int i = 0; i < 3; i++) {
        print('Attempt ${i+1} to unregister FCM token...');
        success = await _apiService.unregisterDeviceToken(token);
        if (success) {
          print('Successfully unregistered FCM token with backend');
          break;
        } else {
          print('Failed to unregister FCM token with backend (attempt ${i+1}/3)');
          // Wait before retrying
          if (i < 2) {
            print('Waiting before retry...');
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
      
      if (!success) {
        print('All attempts to unregister FCM token failed');
      }
    } catch (e) {
      print('Error unregistering device token: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Reset unread count
  Future<void> _resetUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('unread_notification_count', 0);
      _unreadCountController.add(0);
    } catch (e) {
      print('Error resetting unread count: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _onMessageOpenedAppController.close();
    _unreadCountController.close();
  }
}

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Need to ensure Firebase is initialized
  print("Handling a background message: ${message.messageId}");
  
  // We can't access the NotificationService instance here because this function
  // runs in a separate isolate. If you need to save the notification or update
  // unread count, you'll need to do it when the app is next opened.
}
