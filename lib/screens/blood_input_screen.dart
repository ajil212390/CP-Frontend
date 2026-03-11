import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/input_field.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import '../login.dart';
import 'prediction_result_screen.dart';

class BloodInputScreen extends StatefulWidget {
  final Map<String, String>? initialData;
  const BloodInputScreen({super.key, this.initialData});

  @override
  State<BloodInputScreen> createState() => _BloodInputScreenState();
}

class _BloodInputScreenState extends State<BloodInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'Age': TextEditingController(text: widget.initialData?['Age']),
      'Glucose': TextEditingController(text: widget.initialData?['Glucose']),
      'Hemoglobin': TextEditingController(text: widget.initialData?['Hemoglobin']),
      'Platelets': TextEditingController(text: widget.initialData?['Platelets']),
      'Cholesterol': TextEditingController(text: widget.initialData?['Cholesterol']),
      'HDL': TextEditingController(text: widget.initialData?['HDL']),
      'LDL': TextEditingController(text: widget.initialData?['LDL']),
      'Creatinine': TextEditingController(text: widget.initialData?['Creatinine']),
      'Bilirubin': TextEditingController(text: widget.initialData?['Bilirubin']),
      'BMI': TextEditingController(text: widget.initialData?['BMI']),
      'Blood Pressure': TextEditingController(text: widget.initialData?['Blood Pressure']),
    };
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> data = {
        'userid': lid,
      };
      
      _controllers.forEach((key, controller) {
        String finalKey = key.toLowerCase().replaceAll(' ', '_');
        String val = controller.text.trim();
        
        if (finalKey == 'blood_pressure' && val.contains('/')) {
          final parts = val.split('/');
          data[finalKey] = num.tryParse(parts[0]) ?? 120.0;
        } else {
          num? numericVal = num.tryParse(val);
          data[finalKey] = numericVal ?? (val.isEmpty ? 0 : val);
        }
      });

      final result = await _apiService.predictDisease(data);
      if (result != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PredictionResultScreen(
              result: result,
              inputData: data,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Input your lab results precisely for accurate AI prediction.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 32),
                        ..._controllers.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: InputField(
                                label: entry.key,
                                controller: entry.value,
                              ),
                            ),
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0);
                        }),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE63946)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: const Text(
          "Manual Entry",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFE63946), Color(0xFFD62839)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE63946).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: const Text(
          "GENERATE ANALYSIS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
