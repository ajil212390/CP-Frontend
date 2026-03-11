import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:carepulseapp/loginApi.dart'; // Ensure baseUrl is accessible
import '../models/prediction_model.dart';
import 'package:carepulseapp/login.dart';

class ApiService {
  Future<PredictionResult?> predictDisease(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/predict/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return PredictionResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception("Failed to predict: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error predicting disease: $e");
    }
  }

  Future<PredictionResult?> uploadBloodReport(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/analyze-report/'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      var response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        var responseData = await response.stream.bytesToString();
        return PredictionResult.fromJson(jsonDecode(responseData));
      } else {
        throw Exception("Failed to upload report: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error uploading report: $e");
    }
  }

  Future<num> getHealthScore() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health-score/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['score'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> savePrediction(Map<String, dynamic> data) async {
    try {
      // Include user_id so the backend can associate it with the user
      final payload = Map<String, dynamic>.from(data);
      if (lid != null) payload['user_id'] = lid;

      final response = await http.post(
        Uri.parse('$baseUrl/api/save-prediction/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      debugPrint("savePrediction: ${response.statusCode} — ${response.body}");
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Error saving prediction: $e");
      return false;
    }
  }
}
