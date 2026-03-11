import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import '../login.dart';
import '../loginApi.dart';
import 'blood_input_screen.dart';
import 'report_upload_screen.dart';
import '../widgets/glass_card.dart';
import '../predictionhistory.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class HealthPredictorHome extends StatefulWidget {
  final VoidCallback? onBack;
  const HealthPredictorHome({super.key, this.onBack});

  @override
  State<HealthPredictorHome> createState() => _HealthPredictorHomeState();
}

class _HealthPredictorHomeState extends State<HealthPredictorHome> {
  final Dio _dio = Dio();
  List<dynamic> _history = [];
  bool _isLoading = true;

  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh every time this page becomes visible (e.g. tab switch or return from prediction)
    if (!_firstLoad) _fetchHistory();
    _firstLoad = false;
  }

  Future<void> _fetchHistory() async {
    if (lid == null) { setState(() => _isLoading = false); return; }
    try {
      final response = await _dio.get("$baseUrl/api/prediction-history/$lid/");
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _history = response.data['prediction_history'] ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(s);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${m[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) { return 'Recent'; }
  }

  Map<String, String> _parseResult(String? result) {
    if (result == null || result.isEmpty) return {};
    final map = <String, String>{};
    for (var part in result.split(',')) {
      final kv = part.trim().split(':');
      if (kv.length >= 2) map[kv[0].trim()] = kv[1].trim();
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          gradient: RadialGradient(
            colors: [
              Color(0xFF1A1116),
              Color(0xFF0A0A0A),
            ],
            center: Alignment.bottomCenter,
            radius: 0.8,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // ── APP BAR
            SliverAppBar(
              expandedHeight: 80,
              backgroundColor: Colors.transparent,
              elevation: 0,
              floating: true,
              centerTitle: false,
              leading: widget.onBack != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onBack,
                    )
                  : null,
              title: const Text(
                "Report Page",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ),
  
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── EQUAL-HEIGHT ACTION TILES
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _actionTile(
                              context,
                              "Upload Report",
                              "Camera scan & AI OCR",
                              Icons.document_scanner_rounded,
                              () => _showUploadOptions(context),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _actionTile(
                              context,
                              "Manual Entry",
                              "Enter values by hand",
                              Icons.keyboard_rounded,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BloodInputScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),
  
                    const SizedBox(height: 40),
  
                    // ── PREDICTION HISTORY SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PREDICTION HISTORY',
                          style: TextStyle(
                            color: Color(0xFFE63946),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        if (_history.isNotEmpty)
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PredictionHistoryPage()),
                            ),
                            child: const Text(
                              'SEE ALL',
                              style: TextStyle(
                                color: Color(0xFFE63946),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ).animate().fadeIn(delay: 200.ms),
  
                    const SizedBox(height: 16),
  
                    // History content
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFFE63946), strokeWidth: 2)),
                          )
                        : _history.isEmpty
                            ? _buildEmptyHistory()
                            : Column(
                                children: _history.take(5).toList().asMap().entries.map((e) =>
                                  _buildHistoryCard(e.value, e.key)).toList(),
                                ),
                    ],
                  ),
                ),
              ),
            ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    const color = Color(0xFFE63946);
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderColor: color.withOpacity(0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 20),
            Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item, int index) {
    final resultStr = item['result']?.toString() ?? '';
    final date = _fmtDate(item['createdAt']?.toString());
    final riskMap = _parseResult(resultStr);

    Color dominant = const Color(0xFF10B981);
    if (riskMap.values.any((v) => v.toLowerCase() == 'high')) dominant = const Color(0xFFE63946);
    else if (riskMap.values.any((v) => v.toLowerCase() == 'medium')) dominant = Colors.orangeAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderColor: dominant.withOpacity(0.12),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: dominant.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.analytics_rounded, color: dominant, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date,
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  if (riskMap.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: riskMap.entries.take(3).map((e) {
                        final c = _riskColor(e.value);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.withOpacity(0.2)),
                          ),
                          child: Text(
                            '${e.key}: ${e.value.toUpperCase()}',
                            style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Text(
                      resultStr.isEmpty ? 'No result' : resultStr,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white12, size: 20),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 300 + index * 60)).fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildEmptyHistory() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 52, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 16),
          const Text('No analyses yet', style: TextStyle(color: Colors.white24, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Your completed predictions will appear here', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white12, fontSize: 12)),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  // ───────── UPLOAD SHEET ─────────
  void _showUploadOptions(BuildContext context) {
    final mainContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GlassCard(
        padding: const EdgeInsets.all(24),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Text("Upload Medical Report",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Select a photo or PDF to scan",
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 24),
            _sheetOption(context, "Take Photo", Icons.camera_alt_rounded,
                () => _handlePick(mainContext, ImageSource.camera)),
            _sheetOption(context, "Pick from Gallery", Icons.image_rounded,
                () => _handlePick(mainContext, ImageSource.gallery)),
            _sheetOption(context, "Upload PDF File", Icons.picture_as_pdf_rounded,
                () => _handlePickPDF(mainContext)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE63946).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFFE63946), size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
      onTap: onTap,
    );
  }

  Future<void> _handlePick(BuildContext mainContext, ImageSource source) async {
    Navigator.of(mainContext).pop();
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
      if (image != null && mounted) _startScanning(mainContext, File(image.path));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(mainContext).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _handlePickPDF(BuildContext mainContext) async {
    Navigator.of(mainContext).pop();
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.single.path != null && mounted) {
        _startScanning(mainContext, File(result.files.single.path!));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(mainContext).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
    }
  }

  void _startScanning(BuildContext context, File file) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportUploadScreen(file: file), fullscreenDialog: true),
    );
  }
}
