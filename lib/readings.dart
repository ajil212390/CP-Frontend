import 'package:carepulseapp/login.dart';
import 'package:carepulseapp/loginApi.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:ui';

class ViewReadingsPage extends StatefulWidget {
  const ViewReadingsPage({super.key});

  @override
  State<ViewReadingsPage> createState() => _ViewReadingsPageState();
}

class _ViewReadingsPageState extends State<ViewReadingsPage> with TickerProviderStateMixin {
  final Dio _dio = Dio();
  bool _loading = true;
  String? _error;

  double? heartRate;
  double? oxygenLevel;
  double? temperature;

  @override
  void initState() {
    super.initState();
    fetchReadings();
  }

  Future<void> fetchReadings() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final response = await _dio.get('$baseUrl/api/readings/$lid');
      
      if (response.statusCode == 200) {
        final data = response.data;

        if (data is List && data.isNotEmpty) {
          final latest = data.last;

          setState(() {
            heartRate = double.tryParse(latest['heart'].toString());
            oxygenLevel = double.tryParse(latest['oxygen'].toString());
            temperature = double.tryParse(latest['temperature'].toString());
            _loading = false;
          });
        } else {
          throw Exception('No readings available');
        }
      } else {
        throw Exception('Failed to load readings');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Health Intelligence',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlow(300, const Color(0xFF0D47A1).withOpacity(0.2)),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildGlow(250, const Color(0xFF81D4FA).withOpacity(0.15)),
          ),

          _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF81D4FA)))
              : _error != null
                  ? Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
                                const SizedBox(height: 20),
                                Text(
                                  'Analysis Error',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 30),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF81D4FA),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                  onPressed: fetchReadings,
                                  child: const Text("Retry Connection"),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchReadings,
                      color: const Color(0xFF81D4FA),
                      backgroundColor: Colors.black,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
                        children: [
                          _buildReadingCard(
                            title: 'Resting Heart Rate',
                            value: heartRate != null ? '${heartRate!.toStringAsFixed(0)}' : '--',
                            unit: 'BPM',
                            icon: Icons.favorite_rounded,
                            accentColor: const Color(0xFFEF5350),
                          ),
                          const SizedBox(height: 20),
                          _buildReadingCard(
                            title: 'Blood Oxygen',
                            value: oxygenLevel != null ? '${oxygenLevel!.toStringAsFixed(0)}' : '--',
                            unit: '% SpO2',
                            icon: Icons.water_drop_rounded,
                            accentColor: const Color(0xFF42A5F5),
                          ),
                          const SizedBox(height: 20),
                          _buildReadingCard(
                            title: 'Body Temperature',
                            value: temperature != null ? '${temperature!.toStringAsFixed(1)}' : '--',
                            unit: '°C',
                            icon: Icons.thermostat_rounded,
                            accentColor: const Color(0xFFFFA726),
                          ),
                          const SizedBox(height: 40),
                          Center(
                            child: Text(
                              "Last updated: Just now",
                              style: TextStyle(color: Colors.white24, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildGlow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size / 2,
            spreadRadius: size / 4,
          )
        ],
      ),
    );
  }

  Widget _buildReadingCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color accentColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.01),
              ],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.05),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          unit,
                          style: TextStyle(
                            color: accentColor.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white10),
            ],
          ),
        ),
      ),
    );
  }
}
