import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

String baseUrl = "https://5h44kl7q-8001.inc1.devtunnels.ms";
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