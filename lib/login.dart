import 'dart:convert';
import 'package:carepulseapp/home.dart';
import 'package:carepulseapp/loginApi.dart';
import 'package:carepulseapp/fcmtoken.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

int? lid;
String userName = "User";

class SessionManager {
  static const String _keyLid = 'user_id';
  static const String _keyUserName = 'user_name';

  static Future<void> saveSession(int id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLid, id);
    await prefs.setString(_keyUserName, name);
    lid = id;
    userName = name;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLid);
    await prefs.remove(_keyUserName);
    lid = null;
    userName = "User";
  }

  static Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyLid)) {
      lid = prefs.getInt(_keyLid);
      userName = prefs.getString(_keyUserName) ?? "User";
      return true;
    }
    return false;
  }
}

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ValueNotifier<bool> _obscurePassword = ValueNotifier(true);
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);

  Future<void> loginUser(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;

    String username = emailController.text.trim();
    String password = passwordController.text.trim();

    try {
      String? fcmToken;
      try {
        fcmToken = FCMService.getCurrentToken();
      } catch (e) {
        // Continue login even if FCM token fails
      }

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final response = await dio.post(
        "$baseUrl/api/login/",
        data: jsonEncode({
          "username": username,
          "password": password,
          "fcm_token": fcmToken,
        }),
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
      );

      final data = response.data;

      if (data['error'] != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error']),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        final userId = data['user_id'];
        final name = data['name'] ?? username;
        
        await SessionManager.saveSession(userId, name);
        
        if (fcmToken != null && lid != null) {
          FCMService.sendFcmTokenToBackend(lid.toString()).then((_) {});
        }

        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF0A0A0A);
    final fieldColor = const Color(0xFF1C1C1E);
    final redColor = const Color(0xFFE63946);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing Logo Image
                const PulsingLogo(),
                const SizedBox(height: 24),
                
                // Title
                const Text(
                  "Care-Pulse",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  " Health Intelligence",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 60),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username Label
                      Text(
                        "EMAIL ADDRESS",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade400,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Username Field
                      TextFormField(
                        controller: emailController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "name@healthcare.ai",
                          hintStyle: TextStyle(color: Colors.grey.shade700),
                          prefixIcon: Icon(Icons.mail_outline, color: redColor),
                          filled: true,
                          fillColor: fieldColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        validator: (value) => value!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 24),

                      // Password Label
                      Text(
                        "PASSWORD",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade400,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Password Field
                      ValueListenableBuilder(
                        valueListenable: _obscurePassword,
                        builder: (context, bool obscure, _) {
                          return TextFormField(
                            controller: passwordController,
                            obscureText: obscure,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: "••••••••",
                              hintStyle: TextStyle(color: Colors.grey.shade700),
                              prefixIcon: Icon(Icons.lock_outline, color: redColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: () => _obscurePassword.value = !obscure,
                              ),
                              filled: true,
                              fillColor: fieldColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            validator: (value) => value!.isEmpty ? "Required" : null,
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      // Login Button
                      ValueListenableBuilder(
                        valueListenable: _isLoading,
                        builder: (context, bool isLoading, _) {
                          return SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : () => loginUser(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: redColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Text(
                                      "LOG IN",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 60),

                // End-to-end Encryption Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security, color: redColor, size: 14),
                      const SizedBox(width: 8),
                      const Text(
                        "END-TO-END ENCRYPTED HEALTH DATA",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PulsingLogo extends StatefulWidget {
  const PulsingLogo({Key? key}) : super(key: key);

  @override
  State<PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<PulsingLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Hero(
        tag: 'heart_logo',
        child: Icon(
          Icons.favorite_rounded,
          color: const Color(0xFFE63946),
          size: 90,
          shadows: [
            Shadow(
              color: const Color(0xFFE63946).withOpacity(0.5),
              blurRadius: 30,
            ),
          ],
        ),
      ),
    );
  }
}