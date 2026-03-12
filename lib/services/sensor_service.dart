import 'package:dio/dio.dart';
import '../models/sensor_data.dart';
import '../loginApi.dart';

class SensorService {
  final Dio _dio = Dio();

  Future<SensorData> fetchLiveSensorData() async {
    try {
      // Fetch from the local Flask backend (port 5000)
      final response = await _dio.get("$sensorBaseUrl/data");
      if (response.statusCode == 200) {
        return SensorData.fromJson(response.data);
      } else {
        throw Exception("Failed to load sensor data");
      }
    } catch (e) {
      throw Exception("Sensor Backend offline: $e");
    }
  }

  Future<void> saveToMainBackend(String userId, SensorData data) async {
    try {
      // Sync with the main Django backend
      await _dio.post(
        "$baseUrl/api/save-readings/", 
        data: {
          "user_id": userId,
          "heart": data.heart,
          "oxygen": data.oxygen,
          "temperature": data.temperature,
        }
      );
    } catch (e) {
      print("Sync error: $e");
    }
  }
}
