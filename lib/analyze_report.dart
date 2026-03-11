import 'package:flutter/material.dart';
import 'screens/health_home.dart';

class AnalyzeReportScreen extends StatelessWidget {
  const AnalyzeReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This is an older entry point. Redirecting to the primary Health Analyzer Home.
    return const HealthPredictorHome();
  }
}
