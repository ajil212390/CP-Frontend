import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/prediction_model.dart';
import '../widgets/glass_card.dart';
import '../home.dart';
import '../services/api_service.dart';

class PredictionResultScreen extends StatelessWidget {
  final PredictionResult result;
  final Map<String, dynamic> inputData;

  const PredictionResultScreen({
    super.key,
    required this.result,
    required this.inputData,
  });

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFE63946);
    const bg = Color(0xFF0A0A0A);

    // Determine dominant/highest risk for hero banner
    final allRisks = {
      'Diabetes': result.diabetesRisk,
      'Heart': result.heartDiseaseRisk,
      'Kidney': result.kidneyDiseaseRisk,
      'Liver': result.liverDiseaseRisk,
      'Anemia': result.anemiaRisk,
    };
    final highCount = allRisks.values.where((r) => r.toLowerCase() == 'high').length;
    final medCount = allRisks.values.where((r) => r.toLowerCase() == 'medium').length;

    String overallStatus;
    Color overallColor;
    String overallEmoji;
    if (highCount > 0) {
      overallStatus = 'CRITICAL RISK DETECTED';
      overallColor = primaryRed;
      overallEmoji = '⚠️';
    } else if (medCount > 0) {
      overallStatus = 'MODERATE RISK DETECTED';
      overallColor = Colors.orangeAccent;
      overallEmoji = '⚡';
    } else {
      overallStatus = 'ALL SYSTEMS NORMAL';
      overallColor = const Color(0xFF10B981);
      overallEmoji = '✓';
    }

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── SLIVER APP BAR (matches home page style)
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                color: bg,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'HEALTH INSIGHTS',
                          style: TextStyle(
                            color: overallColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'AI Risk Analysis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: overallColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: overallColor.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(overallEmoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Text(
                                overallStatus,
                                style: TextStyle(
                                  color: overallColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: const Text(
              'Health Insights',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // ── BODY CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SECTION: Risk Cards
                  const Text(
                    'SYSTEMIC RISK ANALYSIS',
                    style: TextStyle(
                      color: primaryRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 16),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.15,
                    children: [
                      _riskCard('DIABETES', result.diabetesRisk, Icons.bloodtype_rounded, 0),
                      _riskCard('HEART', result.heartDiseaseRisk, Icons.favorite_rounded, 1),
                      _riskCard('KIDNEY', result.kidneyDiseaseRisk, Icons.medication_rounded, 2),
                      _riskCard('LIVER', result.liverDiseaseRisk, Icons.monitor_heart_rounded, 3),
                      _riskCard('ANEMIA', result.anemiaRisk, Icons.opacity_rounded, 4),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // ── SECTION: Nutritional Guidance
                  const Text(
                    'NUTRITIONAL AI GUIDANCE',
                    style: TextStyle(
                      color: primaryRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 16),

                  _adviceCard(
                    'Clinical Advice',
                    result.lifestyleAdvice,
                    const Color(0xFF3B82F6),
                    Icons.lightbulb_rounded,
                    delay: 500,
                  ),
                  const SizedBox(height: 14),
                  _adviceCard(
                    'Foods to Prioritize',
                    result.recommendedFoods,
                    const Color(0xFF10B981),
                    Icons.check_circle_rounded,
                    delay: 600,
                  ),
                  const SizedBox(height: 14),
                  _adviceCard(
                    'Strictly Avoid',
                    result.foodsToAvoid,
                    primaryRed,
                    Icons.warning_rounded,
                    delay: 700,
                  ),

                  const SizedBox(height: 48),

                  // ── COMPLETE SESSION BUTTON
                  _completeButton(context).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskCard(String title, String risk, IconData icon, int index) {
    Color color;
    double progress;
    String label;

    switch (risk.toLowerCase()) {
      case 'high':
        color = const Color(0xFFE63946);
        progress = 0.88;
        label = 'HIGH';
        break;
      case 'medium':
        color = Colors.orangeAccent;
        progress = 0.55;
        label = 'MEDIUM';
        break;
      default:
        color = const Color(0xFF10B981);
        progress = 0.2;
        label = 'LOW';
    }

    return GlassCard(
      borderColor: color.withOpacity(0.15),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 200 + index * 80))
     .fadeIn().slideY(begin: 0.15, end: 0);
  }

  Widget _adviceCard(String title, List<String> items, Color color, IconData icon, {int delay = 0}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      borderColor: color.withOpacity(0.12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _completeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFE63946), Color(0xFFD62839)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE63946).withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () async {
            final conclusion =
                'Diabetes: ${result.diabetesRisk}, Heart: ${result.heartDiseaseRisk}, '
                'Liver: ${result.liverDiseaseRisk}, Anemia: ${result.anemiaRisk}';
            final Map<String, dynamic> finalData = Map.from(inputData);
            finalData['result'] = conclusion;
            await ApiService().savePrediction(finalData);
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DashboardPage()),
              (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded, color: Colors.white, size: 22),
              SizedBox(width: 12),
              Text(
                'COMPLETE SESSION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
