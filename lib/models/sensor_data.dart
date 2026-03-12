class SensorData {
  final double heart;
  final double oxygen;
  final double temperature;

  SensorData({
    required this.heart,
    required this.oxygen,
    required this.temperature,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      heart: (json['heart'] as num).toDouble(),
      oxygen: (json['oxygen'] as num).toDouble(),
      temperature: (json['temperature'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heart': heart,
      'oxygen': oxygen,
      'temperature': temperature,
    };
  }
}
