import 'package:flutter/material.dart';
import 'package:carepulseapp/screens/health_home.dart';

class MedicalReportPage extends StatelessWidget {
  final VoidCallback? onBack;
  const MedicalReportPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return HealthPredictorHome(onBack: onBack);
  }
}
