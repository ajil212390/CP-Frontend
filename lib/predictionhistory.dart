import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:carepulseapp/login.dart';
import 'package:carepulseapp/loginApi.dart';
import 'widgets/glass_card.dart';

class PredictionHistoryPage extends StatefulWidget {
  const PredictionHistoryPage({Key? key}) : super(key: key);

  @override
  State<PredictionHistoryPage> createState() => _PredictionHistoryPageState();
}

class _PredictionHistoryPageState extends State<PredictionHistoryPage> {
  final Dio _dio = Dio();
  bool isLoading = true;
  List<dynamic> history = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { isLoading = true; error = null; });
    try {
      final response = await _dio.get("$baseUrl/api/prediction-history/$lid/");
      if (response.statusCode == 200) {
        final raw = response.data;
        setState(() {
          history = raw['prediction_history'] ?? raw['results'] ?? (raw is List ? raw : []);
          isLoading = false;
        });
      } else {
        setState(() { error = 'Server error ${response.statusCode}'; isLoading = false; });
      }
    } catch (e) {
      setState(() { error = 'Connection failed. Check your network.'; isLoading = false; });
    }
  }

  String _fmtDate(String? s) {
    if (s == null || s.isEmpty || s == 'null') return 'Unknown Date';
    try {
      final dt = DateTime.parse(s);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${m[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) { return 'Recent'; }
  }

  // Parse "Diabetes: High, Heart: Low, ..." into a map
  Map<String, String> _parseResult(String? result) {
    if (result == null || result.isEmpty) return {};
    final map = <String, String>{};
    for (var part in result.split(',')) {
      final kv = part.trim().split(':');
      if (kv.length >= 2) {
        map[kv[0].trim()] = kv[1].trim();
      }
    }
    return map;
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return const Color(0xFFE63946);
      case 'medium': return Colors.orangeAccent;
      default: return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0A0A0A);
    const accent = Color(0xFFE63946);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── SLIVER APP BAR
          SliverAppBar(
            pinned: true,
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 22),
                onPressed: isLoading ? null : _fetch,
              ),
            ],
            title: const Text(
              'Health History',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // ── BODY
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 120),
                      child: Center(child: CircularProgressIndicator(color: accent)),
                    )
                  : error != null
                      ? _buildError()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Summary Banner
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.analytics_rounded, color: accent, size: 26),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Health Reports',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                                      const SizedBox(height: 4),
                                      Text('${history.length} analyses completed',
                                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn().slideY(begin: -0.1),

                            const SizedBox(height: 32),

                            if (history.isEmpty)
                              _buildEmpty()
                            else ...[
                              const Text(
                                'PREVIOUS ANALYSES',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...history.asMap().entries.map((e) =>
                                _buildCard(e.value, e.key)),
                            ],
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic item, int index) {
    final resultStr = item['result']?.toString() ?? '';
    final date = _fmtDate(item['createdAt']?.toString());
    final riskMap = _parseResult(resultStr);

    // Overall severity for the card's accent
    Color dominantColor = const Color(0xFF10B981);
    if (riskMap.values.any((v) => v.toLowerCase() == 'high')) {
      dominantColor = const Color(0xFFE63946);
    } else if (riskMap.values.any((v) => v.toLowerCase() == 'medium')) {
      dominantColor = Colors.orangeAccent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderColor: dominantColor.withOpacity(0.12),
        padding: const EdgeInsets.all(0),
        child: Theme(
          data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: dominantColor,
            collapsedIconColor: Colors.white24,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            title: Text(
              date,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: riskMap.isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: riskMap.entries.map((e) => _riskBadge(e.key, e.value)).toList(),
                    )
                  : Text(
                      resultStr.isEmpty ? 'No result stored' : resultStr,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            children: [
              if (riskMap.isNotEmpty) ...[
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                const Text(
                  'FULL RISK BREAKDOWN',
                  style: TextStyle(
                    color: Color(0xFFE63946),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.4,
                  children: riskMap.entries.map((e) => _riskDetailTile(e.key, e.value)).toList(),
                ),
              ],

              // Blood parameters if present
              _buildParams(item),
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 100 + index * 60)).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _riskBadge(String label, String risk) {
    final c = _riskColor(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            '$label: ${risk.toUpperCase()}',
            style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _riskDetailTile(String label, String risk) {
    final c = _riskColor(risk);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 12,
      borderColor: c.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(risk.toUpperCase(), style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildParams(dynamic item) {
    final paramKeys = {
      'Glucose': 'Glucose', 'Hemoglobin': 'Hemoglobin', 'Platelets': 'Platelets',
      'Cholesterol': 'Cholesterol', 'HDL': 'HDL', 'LDL': 'LDL',
      'Creatinine': 'Creatinine', 'Bilirubin': 'Bilirubin', 'BMI': 'BMI',
      'Blood_Pressure': 'BP', 'Age': 'Age',
      'S_Creatinine': 'Creatinine', 'HDL_Cholesterol': 'HDL',
      'LDL_Cholesterol': 'LDL', 'S_Total_Cholesterol': 'Cholesterol',
    };
    final found = <String, String>{};
    for (var entry in paramKeys.entries) {
      if (item[entry.key] != null && item[entry.key].toString().isNotEmpty) {
        found[entry.value] = item[entry.key].toString();
      }
    }
    if (found.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'BLOOD PARAMETERS',
          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: found.entries.map((e) => GlassCard(
            padding: const EdgeInsets.all(10),
            borderRadius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(e.key, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.history_toggle_off_rounded, size: 72, color: Colors.white.withOpacity(0.04)),
          const SizedBox(height: 20),
          const Text('No analyses yet', style: TextStyle(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Complete a blood test prediction\nto see it here', textAlign: TextAlign.center, style: TextStyle(color: Colors.white12, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.wifi_off_rounded, size: 56, color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 20),
          Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _fetch,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE63946), width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: const Text('RETRY', style: TextStyle(color: Color(0xFFE63946), fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}
