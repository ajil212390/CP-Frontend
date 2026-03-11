class BloodParameter {
  final String name;
  final String value;
  final String unit;
  final bool isNormal;

  BloodParameter({
    required this.name,
    required this.value,
    this.unit = '',
    this.isNormal = true,
  });

  factory BloodParameter.fromJson(Map<String, dynamic> json) {
    return BloodParameter(
      name: json['name'] ?? '',
      value: json['value'] ?? '',
      unit: json['unit'] ?? '',
      isNormal: json['isNormal'] ?? true,
    );
  }
}

class PredictionResult {
  final String diabetesRisk;
  final String heartDiseaseRisk;
  final String kidneyDiseaseRisk;
  final String liverDiseaseRisk;
  final String anemiaRisk;
  final num healthScore;
  final List<String> recommendedFoods;
  final List<String> foodsToAvoid;
  final List<String> lifestyleAdvice;
  final List<BloodParameter> parameters;

  PredictionResult({
    required this.diabetesRisk,
    required this.heartDiseaseRisk,
    required this.kidneyDiseaseRisk,
    required this.liverDiseaseRisk,
    required this.anemiaRisk,
    required this.healthScore,
    required this.recommendedFoods,
    required this.foodsToAvoid,
    required this.lifestyleAdvice,
    this.parameters = const [],
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final predictions = json['predictions'] ?? {};
    final diet = json['diet_recommendations'] ?? {};
    
    var paramList = json['parameters'] as List?;
    List<BloodParameter> parsedParams = paramList != null
        ? paramList.map((p) => BloodParameter.fromJson(p)).toList()
        : [];

    return PredictionResult(
      diabetesRisk: predictions['diabetes_risk'] ?? json['diabetesRisk'] ?? 'Low',
      heartDiseaseRisk: predictions['heart_disease_risk'] ?? json['heartDiseaseRisk'] ?? 'Low',
      kidneyDiseaseRisk: predictions['kidney_disease_risk'] ?? json['kidneyDiseaseRisk'] ?? 'Low',
      liverDiseaseRisk: predictions['liver_disease_risk'] ?? json['liverDiseaseRisk'] ?? 'Low',
      anemiaRisk: predictions['anemia_risk'] ?? json['anemiaRisk'] ?? 'Low',
      healthScore: json['healthScore'] ?? 0,
      recommendedFoods: List<String>.from(diet['foods_to_eat'] ?? json['recommendedFoods'] ?? []),
      foodsToAvoid: List<String>.from(diet['foods_to_avoid'] ?? json['foodsToAvoid'] ?? []),
      lifestyleAdvice: List<String>.from(diet['advice'] ?? json['lifestyleAdvice'] ?? []),
      parameters: parsedParams,
    );
  }
}
