import 'package:carepulseapp/fcmtoken.dart';
import 'package:carepulseapp/login.dart';
import 'package:carepulseapp/home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Top-level background message handler - MUST be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background handler
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print('=== Background Message Handler ===');
  print('Message ID: ${message.messageId}');
  
  if (message.notification != null) {
    print('Background notification: ${message.notification!.title}');
    print('Background body: ${message.notification!.body}');
  }
  
  if (message.data.isNotEmpty) {
    print('Background data: ${message.data}');
  }
}

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');

    // Set background message handler BEFORE any other FCM operations
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize FCM - non-blocking, won't crash app if it fails
    FCMService.initFCM().catchError((error) {
      print("FCM initialization failed: $error");
      // App continues without FCM - notifications won't work but app runs
    });

  } catch (e) {
    print("Firebase initialization error: $e");
    // Continue app startup even if Firebase fails
  }

  // Load existing session
  final bool isLoggedIn = await SessionManager.loadSession();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Check for initial message when app starts
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    await FCMService.checkInitialMessage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HealthcareRobot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: widget.isLoggedIn ? const DashboardPage() : LoginPage(),
    );
  }
}