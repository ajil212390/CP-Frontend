// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:carepulseapp/loginApi.dart';

// class FCMService {
//   static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   static final FlutterLocalNotificationsPlugin _localNotifications = 
//       FlutterLocalNotificationsPlugin();

//   static Future<void> initFCM() async {
//     // Initialize local notifications
//     await _initLocalNotifications();
    
//     // Request permissions (iOS)
//     NotificationSettings settings = await _messaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//       provisional: false,
//       announcement: false,
//       carPlay: false,
//       criticalAlert: false,
//     );

//     print('User granted permission: ${settings.authorizationStatus}');

//     // Get the device token
//     String? token = await _messaging.getToken();
//     print("FCM Token: $token");

//     // Handle foreground messages
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       print('Foreground message received: ${message.notification?.body}');
//       _showLocalNotification(message);
//     });

//     // Handle background/terminated messages
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       print('Message clicked!');
//       // Handle navigation here
//     });

//     // Handle messages when app is terminated
//     RemoteMessage? initialMessage = await _messaging.getInitialMessage();
//     if (initialMessage != null) {
//       print('App opened from terminated state via notification');
//       // Handle navigation here
//     }
//   }

//   static Future<void> _initLocalNotifications() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
    
//     const InitializationSettings initializationSettings =
//         InitializationSettings(android: initializationSettingsAndroid);

//     await _localNotifications.initialize(initializationSettings);

//     // Create notification channel for Android
//     const AndroidNotificationChannel channel = AndroidNotificationChannel(
//       'high_importance_channel',
//       'High Importance Notifications',
//       description: 'This channel is used for important notifications.',
//       importance: Importance.high,
//     );

//     await _localNotifications
//         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(channel);
//   }

//   static Future<void> _showLocalNotification(RemoteMessage message) async {
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//         AndroidNotificationDetails(
//       'high_importance_channel',
//       'High Importance Notifications',
//       channelDescription: 'This channel is used for important notifications.',
//       importance: Importance.high,
//       priority: Priority.high,
//     );

//     const NotificationDetails platformChannelSpecifics =
//         NotificationDetails(android: androidPlatformChannelSpecifics);

//     await _localNotifications.show(
//       message.hashCode,
//       message.notification?.title ?? 'New Message',
//       message.notification?.body ?? 'You have a new message',
//       platformChannelSpecifics,
//     );
//   }

//   static Future<void> sendFcmTokenToBackend(String userId) async {
//     final dio = Dio();
//     String? token = await FirebaseMessaging.instance.getToken();
    
//     if (token != null) {
//       try {
//         await dio.post(
//           "$baseUrl/api/save-fcm-token/",
//           data: {
//             "user_id": userId,
//             "fcm_token": token,
//           },
//         );
//         print('FCM token sent to backend successfully');
//       } catch (e) {
//         print('Error sending FCM token to backend: $e');
//       }
//     }
//   }
// }


import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:carepulseapp/loginApi.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  static String? _currentToken;

  /// Initialize FCM with comprehensive error handling
  static Future<void> initFCM() async {
    try {
      // Initialize local notifications first
      await _initLocalNotifications();
      
      // Request permissions (iOS primarily, Android auto-grants)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      // Get the device token with error handling
      await _getAndStoreToken();

      // Set up message listeners
      _setupMessageListeners();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        print("FCM Token refreshed: $newToken");
        _currentToken = newToken;
      }).onError((error) {
        print("Error on token refresh: $error");
      });
      
    } catch (e) {
      print("Error initializing FCM: $e");
      // Don't throw - allow app to continue running without FCM
    }
  }

  /// Get FCM token with retry mechanism
  static Future<String?> _getAndStoreToken() async {
    // Initial delay to let device establish network connection
    await Future.delayed(Duration(seconds: 3));
    
    int retries = 5;
    int delaySeconds = 3;

    for (int i = 0; i < retries; i++) {
      try {
        String? token = await _messaging.getToken();
        if (token != null) {
          print("FCM Token: $token");
          _currentToken = token;
          return token;
        } else {
          print("FCM Token is null - attempt ${i + 1}/$retries");
        }
      } catch (e) {
        print("Error getting FCM token (attempt ${i + 1}/$retries): $e");
        if (i < retries - 1) {
          await Future.delayed(Duration(seconds: delaySeconds));
          delaySeconds = (delaySeconds * 1.5).toInt(); // Exponential backoff
        }
      }
    }

    print("Failed to get FCM token after $retries attempts");
    print("Will retry on next app launch or when network is available");
    
    // Schedule a retry in background
    _scheduleTokenRetry();
    
    return null;
  }
  
  /// Schedule a background retry for token
  static void _scheduleTokenRetry() {
    Future.delayed(Duration(seconds: 30), () async {
      if (_currentToken == null) {
        print("Retrying FCM token fetch...");
        try {
          String? token = await _messaging.getToken();
          if (token != null) {
            print("FCM Token retrieved on retry: $token");
            _currentToken = token;
          }
        } catch (e) {
          print("Retry failed: $e");
        }
      }
    });
  }

  /// Get current stored token
  static String? getCurrentToken() {
    return _currentToken;
  }

  /// Setup all message listeners
  static void _setupMessageListeners() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('=== Foreground Message Received ===');
      print('Message ID: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');
      
      _showLocalNotification(message);
    }).onError((error) {
      print("Error in onMessage listener: $error");
    });

    // Handle background/terminated messages when app is opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('=== Message Clicked (Background) ===');
      print('Message ID: ${message.messageId}');
      print('Data: ${message.data}');
      
      // Handle navigation based on message data
      _handleMessageNavigation(message);
    }).onError((error) {
      print("Error in onMessageOpenedApp listener: $error");
    });
  }

  /// Check for initial message when app opens from terminated state
  static Future<void> checkInitialMessage() async {
    try {
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print('=== App Opened from Terminated State ===');
        print('Message ID: ${initialMessage.messageId}');
        print('Data: ${initialMessage.data}');
        
        _handleMessageNavigation(initialMessage);
      }
    } catch (e) {
      print("Error checking initial message: $e");
    }
  }

  /// Initialize local notifications for Android
  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification clicked: ${response.payload}');
        // Handle notification tap
      },
    );

    // Create notification channel for Android (required for Android 8.0+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show local notification for foreground messages
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'New Message',
        message.notification?.body ?? 'You have a new message',
        platformChannelSpecifics,
        payload: message.data.toString(),
      );
    } catch (e) {
      print("Error showing local notification: $e");
    }
  }

  /// Handle message navigation based on data
  static void _handleMessageNavigation(RemoteMessage message) {
    // Implement your navigation logic here based on message.data
    // Example:
    // if (message.data['type'] == 'alert') {
    //   Navigator.push(context, MaterialPageRoute(builder: (context) => AlertScreen()));
    // }
    print("Navigation handler called with data: ${message.data}");
  }

  /// Send FCM token to backend
  static Future<bool> sendFcmTokenToBackend(String userId) async {
    try {
      // Get current token or fetch new one
      String? token = _currentToken;
      
      // If no cached token, try to get it
      if (token == null) {
        token = await _messaging.getToken();
      }
      
      if (token == null) {
        print('Cannot send FCM token - token is null');
        return false;
      }

      print('Sending FCM token to backend for user: $userId');
      
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      final response = await dio.post(
        "$baseUrl/api/save-fcm-token/",
        data: {
          "user_id": userId,
          "fcm_token": token,
        },
      );

      if (response.statusCode == 200) {
        print('FCM token sent to backend successfully');
        return true;
      } else {
        print('Failed to send FCM token. Status: ${response.statusCode}');
        return false;
      }
      
    } catch (e) {
      print('Error sending FCM token to backend: $e');
      return false;
    }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Delete FCM token
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _currentToken = null;
      print('FCM token deleted');
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      NotificationSettings settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print('Error checking notification settings: $e');
      return false;
    }
  }
}