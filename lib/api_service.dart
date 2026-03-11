import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  /// Replace this with your actual local or production IP, e.g., 'https://5h44kl7q-8001.inc1.devtunnels.ms'
  final String baseUrl;

  ApiService({required this.baseUrl});

  // ==========================================
  // Auth & Tokens
  // ==========================================

  /// Login
  /// POST — /api/login/
  Future<Map<String, dynamic>> login(String username, String password, String fcmToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'fcm_token': fcmToken,
      }),
    );
    return _processResponse(response);
  }

  /// Save FCM token
  /// POST — /api/save-fcm-token/
  Future<Map<String, dynamic>> saveFcmToken(
      String userId, String fcmToken, {String? deviceType, String? deviceId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/save-fcm-token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'fcm_token': fcmToken,
        if (deviceType != null) 'device_type': deviceType,
        if (deviceId != null) 'device_id': deviceId,
      }),
    );
    return _processResponse(response);
  }

  /// Delete FCM token
  /// POST — /api/delete-fcm-token/
  Future<Map<String, dynamic>> deleteFcmToken(String userId, {String? fcmToken}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/delete-fcm-token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        if (fcmToken != null) 'fcm_token': fcmToken,
      }),
    );
    return _processResponse(response);
  }

  // ==========================================
  // Alerts
  // ==========================================

  /// Check alerts (manual trigger)
  /// POST — /api/check-alerts/
  Future<Map<String, dynamic>> checkAlerts() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/check-alerts/'),
      headers: {'Content-Type': 'application/json'},
    );
    return _processResponse(response);
  }

  /// Send immediate alert
  /// POST — /api/send-immediate-alert/
  Future<Map<String, dynamic>> sendImmediateAlert(String userId,
      {String? title, String? description, String? medicineId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/send-immediate-alert/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (medicineId != null) 'medicine_id': medicineId,
      }),
    );
    return _processResponse(response);
  }

  /// Create alert
  /// POST — /api/alerts/create/
  Future<Map<String, dynamic>> createAlert({
    required String userId,
    required String title,
    String? description,
    String? medicineId,
    String? startTime,
    String? endTime,
    int? intervalMinutes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/alerts/create/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'title': title,
        if (description != null) 'description': description,
        if (medicineId != null) 'medicine_id': medicineId,
        if (startTime != null) 'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        if (intervalMinutes != null) 'interval_minutes': intervalMinutes,
      }),
    );
    return _processResponse(response);
  }

  /// List alerts for user
  /// POST — /api/alerts/
  Future<Map<String, dynamic>> listAlerts(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/alerts/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
      }),
    );
    return _processResponse(response);
  }

  /// Alert detail
  /// POST — /api/alerts/<alert_id>/
  Future<Map<String, dynamic>> getAlertDetail(String alertId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/alerts/$alertId/'),
      headers: {'Content-Type': 'application/json'},
    );
    return _processResponse(response);
  }

  /// Mark alert read
  /// POST — /api/alerts/<alert_id>/mark-read/
  Future<Map<String, dynamic>> markAlertRead(String alertId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/alerts/$alertId/mark-read/'),
      headers: {'Content-Type': 'application/json'},
    );
    return _processResponse(response);
  }

  // ==========================================
  // Notifications
  // ==========================================

  /// Send notification
  /// POST — /api/send-notification/
  Future<Map<String, dynamic>> sendNotification(
      String userId, String title, String body, {Map<String, dynamic>? data}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/send-notification/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
      }),
    );
    return _processResponse(response);
  }

  /// Send alert notification
  /// POST — /api/send-alert-notification/
  Future<Map<String, dynamic>> sendAlertNotification(String alertId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/send-alert-notification/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'alert_id': alertId,
      }),
    );
    return _processResponse(response);
  }

  // ==========================================
  // Health Data & ML
  // ==========================================

  /// Prediction history (get)
  /// GET — /api/prediction-history/<user_id>/
  Future<Map<String, dynamic>> getPredictionHistory(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/prediction-history/$userId/'),
    );
    return _processResponse(response);
  }

  /// Disease prediction (Gemini)
  /// POST — /DiseasePredictionApi/<lid>
  Future<Map<String, dynamic>> predictDisease({
    required String lid,
    required double fastingBloodSugar,
    required double postPrandialBloodSugar,
    required double fastingLipidProfile,
    required double sTotalCholesterol,
    required double sTriglycerides,
    required double hdlCholesterol,
    required double ldlCholesterol,
    required double vldlCholesterol,
    required double bloodUrea,
    required double sCreatinine,
    required double sUricAcid,
    required double bloodUreaNitrogen,
    required double tsh,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/DiseasePredictionApi/$lid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'Fasting_Blood_Sugar': fastingBloodSugar.toString(),
        'Post_Prandial_Blood_Sugar': postPrandialBloodSugar.toString(),
        'Fasting_Lipid_Profile': fastingLipidProfile.toString(),
        'S_Total_Cholesterol': sTotalCholesterol.toString(),
        'S_Triglycerides': sTriglycerides.toString(),
        'HDL_Cholesterol': hdlCholesterol.toString(),
        'LDL_Cholesterol': ldlCholesterol.toString(),
        'VLDL_Cholesterol': vldlCholesterol.toString(),
        'Blood_Urea': bloodUrea.toString(),
        'S_Creatinine': sCreatinine.toString(),
        'S_Uric_Acid': sUricAcid.toString(),
        'Blood_Urea_Nitrogen': bloodUreaNitrogen.toString(),
        'TSH': tsh.toString(),
      }),
    );
    return _processResponse(response);
  }

  /// Readings (fetch last 10)
  /// GET — /api/readings/<id>/
  Future<Map<String, dynamic>> getReadings(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/readings/$id/'),
    );
    return _processResponse(response);
  }

  /// Submit readings (device)
  /// POST — /test
  Future<Map<String, dynamic>> submitReadings({
    required double heartRate,
    required double spo2,
    required double temperature,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/test'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'heart_rate': heartRate,
        'spo2': spo2,
        'temperature': temperature,
      }),
    );
    return _processResponse(response);
  }

  // ==========================================
  // Diet Chat
  // ==========================================

  /// Get Diet chat messages
  /// GET /dietchat/
  Future<Map<String, dynamic>> getDietChat() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dietchat/'),
    );
    return _processResponse(response);
  }

  /// Send Diet chat message
  /// POST — /dietchat/
  Future<Map<String, dynamic>> sendDietChatMessage(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dietchat/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _processResponse(response);
  }

  // ==========================================
  // Utility
  // ==========================================

  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body);
      } catch (e) {
        return {'success': true, 'body': response.body};
      }
    } else {
      throw Exception('Failed to load data: ${response.statusCode} - ${response.body}');
    }
  }
}
