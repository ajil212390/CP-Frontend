import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/sensor_data.dart';
import '../services/sensor_service.dart';
import '../widgets/glass_card.dart';
import '../login.dart'; // for lid

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  final SensorService _sensorService = SensorService();
  SensorData? _currentData;
  Timer? _timer;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    try {
      final data = await _sensorService.fetchLiveSensorData();
      if (mounted) {
        setState(() {
          _currentData = data;
          _isLoading = false;
          _errorMessage = null;
        });
        // Auto-sync to main backend if user is logged in
        if (lid != null) {
           _sensorService.saveToMainBackend(lid!.toString(), data);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Connecting to Flask server on port 5000...";
          _isLoading = _currentData == null;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("LIVE MONITOR", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1A1116), Color(0xFF0A0A0A)],
            center: Alignment.bottomCenter,
            radius: 1.2,
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))
          : Column(
              children: [
                if (_errorMessage != null)
                   Container(
                     margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: Colors.orange.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.orange.withOpacity(0.3)),
                     ),
                     child: Row(
                       children: [
                         const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                         const SizedBox(width: 10),
                         Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.orange, fontSize: 11))),
                       ],
                     ),
                   ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    children: [
                      _buildHeartRateCard(),
                      const SizedBox(height: 20),
                      _buildOxygenCard(),
                      const SizedBox(height: 20),
                      _buildTemperatureCard(),
                      const SizedBox(height: 40),
                      const Center(
                        child: Text("Real-time data updates every 3 seconds", 
                          style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildHeartRateCard() {
    final val = _currentData?.heart ?? 0;
    final isNormal = val >= 60 && val <= 100;
    return GlassCard(
      borderColor: const Color(0xFFE63946).withOpacity(0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE63946).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.favorite, color: Color(0xFFE63946), size: 30)
              .animate(onPlay: (controller) => controller.repeat())
              .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 600.ms, curve: Curves.easeInOut)
              .then()
              .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1), duration: 600.ms, curve: Curves.easeInOut),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("HEART RATE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text("${val.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 6),
                    const Text("BPM", style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          _statusIndicator(isNormal),
        ],
      ),
    );
  }

  Widget _buildOxygenCard() {
    final val = _currentData?.oxygen ?? 0;
    final isNormal = val >= 95 && val <= 100;
    return GlassCard(
      borderColor: Colors.blue.withOpacity(0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.water_drop, color: Colors.blue, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SPO2 LEVEL", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text("${val.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 6),
                    const Text("%", style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          _statusIndicator(isNormal),
        ],
      ),
    );
  }

  Widget _buildTemperatureCard() {
    final val = _currentData?.temperature ?? 0;
    final isNormal = val >= 36.0 && val <= 37.5;
    return GlassCard(
      borderColor: Colors.orange.withOpacity(0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.thermostat, color: Colors.orange, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("TEMPERATURE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text("${val.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 6),
                    const Text("°C", style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          _statusIndicator(isNormal),
        ],
      ),
    );
  }

  Widget _statusIndicator(bool isNormal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isNormal ? Colors.green : Colors.red).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isNormal ? Colors.green : Colors.red).withOpacity(0.3)),
      ),
      child: Text(
        isNormal ? "NORMAL" : "ALERT",
        style: TextStyle(color: isNormal ? Colors.green : Colors.red, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }
}
