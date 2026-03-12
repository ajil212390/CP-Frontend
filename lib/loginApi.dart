import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

String baseUrl = "https://s16831sg-8000.inc1.devtunnels.ms";
String sensorBaseUrl = "http://192.168.1.5:5000"; // Update with computer's local IP
String ollamaBaseUrl = "http://192.168.1.5:11434"; // Fixed for your PC's local IP
Future<void> sendFcmTokenToBackend(String userId) async {
  final dio = Dio();
  String? token = await FirebaseMessaging.instance.getToken();

  if (token != null) {
    await dio.post(
      "$baseUrl/api/save-fcm-token/", 
      data: {
        "user_id": userId,
        "fcm_token": token,
      },
    );
  }
}
Future<void> login(String username, String password) async {
  String? fcmToken = await FirebaseMessaging.instance.getToken();

  final dio = Dio();
  final response = await dio.post(
    "$baseUrl/api/login/",
    data: jsonEncode({
      "username": username,
      "password": password,
      "fcm_token": fcmToken,
    }),
    options: Options(headers: {"Content-Type": "application/json"}),
  );

  print(response.data);
}