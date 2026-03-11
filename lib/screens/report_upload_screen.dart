import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'blood_input_screen.dart';
import '../widgets/glass_card.dart';
import '../loginApi.dart';

class ReportUploadScreen extends StatefulWidget {
  final File file;
  const ReportUploadScreen({super.key, required this.file});

  @override
  State<ReportUploadScreen> createState() => _ReportUploadScreenState();
}

class _ReportUploadScreenState extends State<ReportUploadScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _animation;
  String _status = "Sending to Gemini AI...";
  bool _isCompleted = false;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
        vsync: this, duration: const Duration(seconds: 8));
    _animation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _progressController, curve: Curves.easeOut));
    _startGeminiExtraction();
  }

  Future<void> _startGeminiExtraction() async {
    setState(() {
      _hasError = false;
      _status = "Uploading to Gemini Vision...";
    });
    _progressController.forward();

    try {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _status = "Gemini Reading Your Report...");

      // Build multipart request to /api/extract-report/
      final uri = Uri.parse('$baseUrl/api/extract-report/');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath(
        'report_file',
        widget.file.path,
      ));

      if (!mounted) return;
      setState(() => _status = "AI Extracting Clinical Values...");

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (!mounted) return;

      if (streamedResponse.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        final Map<String, dynamic> rawValues = decoded['extracted_values'] ?? {};

        final Map<String, String> extractedData = rawValues.map(
          (k, v) => MapEntry(k, v?.toString() ?? ''),
        );

        _progressController.animateTo(1.0);
        setState(() {
          _status = "Extraction Complete";
          _isCompleted = true;
        });

        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BloodInputScreen(initialData: extractedData),
          ),
        );
      } else if (streamedResponse.statusCode == 429) {
        throw Exception('Too many requests. Please wait a moment and try again.');
      } else {
        throw Exception('Server error. Please check your connection and retry.');
      }
    } catch (e) {
      debugPrint("Gemini Extract Error: $e");
      if (mounted) {
        setState(() {
          _status = "Extraction Failed";
          _errorMessage = e.toString().replaceAll("Exception: ", "");
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String fileName = widget.file.path.split(Platform.pathSeparator).last;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "AI Scan",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: (_hasError ? Colors.red : const Color(0xFFE63946)).withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (_hasError ? Colors.red : const Color(0xFFE63946)).withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                _hasError
                    ? Icons.error_outline
                    : (_isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.auto_awesome_rounded),
                color: _hasError ? Colors.red : const Color(0xFFE63946),
                size: 80,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.08, 1.08),
                    duration: 1500.ms),

            const SizedBox(height: 56),

            // Status Text
            Text(
              _status.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ).animate().fadeIn(),

            if (_hasError && _errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _errorMessage.length > 120 ? '${_errorMessage.substring(0, 120)}...' : _errorMessage,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.5),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Progress Bar
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _animation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFE63946), Color(0xFFFF5E62)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFE63946).withOpacity(0.4),
                            blurRadius: 10)
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Powered by AI badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFFE63946), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    "POWERED BY VISION AI",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            if (_hasError)
              ElevatedButton(
                onPressed: _startGeminiExtraction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 20),
                ),
                child: const Text("RETRY",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              )
            else
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(children: [
                  const Icon(Icons.health_and_safety_rounded,
                      color: Color(0xFFE63946), size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
              ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}
