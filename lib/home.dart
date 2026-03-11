import 'dart:ui';
import 'package:carepulseapp/alertlist.dart';
import 'package:carepulseapp/login.dart';
import 'package:carepulseapp/medicalreport.dart';
import 'package:carepulseapp/medicine_reminder.dart';
import 'package:carepulseapp/readings.dart';
import 'package:carepulseapp/chatbot.dart';
import 'package:carepulseapp/profile.dart';
import 'package:carepulseapp/loginApi.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _pendingAlertsCount = 0;
  final Dio _dio = Dio();
  late PageController _pageController;
  
  // Smart Nav visibility
  late AnimationController _navAnimationController;
  bool _isNavVisible = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _navAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0, // Initially visible
    );
    _fetchPendingAlertsCount();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _navAnimationController.dispose();
    super.dispose();
  }

  void _onScroll(ScrollDirection direction) {
    if (direction == ScrollDirection.reverse) {
      if (_isNavVisible) {
        setState(() => _isNavVisible = false);
        _navAnimationController.reverse();
      }
    } else if (direction == ScrollDirection.forward) {
      if (!_isNavVisible) {
        setState(() => _isNavVisible = true);
        _navAnimationController.forward();
      }
    }
  }

  Future<void> _fetchPendingAlertsCount() async {
    if (lid == null) return;
    final apiUrl = "$baseUrl/api/alerts/";
    try {
      final response = await _dio.post(apiUrl, data: {"user_id": lid});
      if (response.statusCode == 200) {
        final alerts = response.data['alerts'] as List;
        int count = alerts.where((a) => a['sent'] == false || a['sent'] == null).length;
        setState(() {
          _pendingAlertsCount = count;
        });
      }
    } catch (e) {
      debugPrint("Error fetching alerts: $e");
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    
    // Ensure nav is visible when tapping
    if (!_isNavVisible) {
      setState(() => _isNavVisible = true);
      _navAnimationController.forward();
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _openChatbot() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ChatbotPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCirc;

          var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var scaleTween = Tween<double>(begin: 0.9, end: 1.0);
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0);

          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: ScaleTransition(
              scale: animation.drive(scaleTween),
              child: SlideTransition(
                position: animation.drive(slideTween),
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          _onScroll(notification.direction);
          return false;
        },
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Only navigate via nav bar
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: [
            _buildHomeBody(),
            MedicalReportPage(onBack: () => _onItemTapped(0)),
            MedicineReminderPage(onBack: () => _onItemTapped(0)),
            ProfilePage(onBack: () => _onItemTapped(0)),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: SizeTransition(
        sizeFactor: _navAnimationController,
        axisAlignment: -1.0,
        child: FadeTransition(
          opacity: _navAnimationController,
          child: _buildBottomNav(),
        ),
      ),
      floatingActionButton: AnimatedScale(
        scale: _isNavVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: 64,
          width: 64,
          margin: const EdgeInsets.only(top: 20),
          child: FloatingActionButton(
            onPressed: _openChatbot,
            backgroundColor: Colors.black, // Pure black background
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFFE63946), size: 32),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHomeBody() {
    return Container(
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
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome,",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _onItemTapped(3),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(Icons.person, color: Colors.orange.shade300, size: 30),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 28),

              // CARE AI Banner
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1C).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.smart_toy, color: const Color(0xFFFF2A5F), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "CARE AI",
                              style: TextStyle(
                                color: const Color(0xFFFF2A5F),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Ready to help",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "How are you feeling today?",
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade300,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: _openChatbot,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE63946),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text("Ask Now", style: TextStyle(fontWeight: FontWeight.w700)),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Main Services Title
              Text(
                "MAIN SERVICES",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.blueGrey.shade400,
                ),
              ),
              const SizedBox(height: 16),

              // Service Cards
              _buildServiceCard(
                icon: Icons.summarize_rounded,
                iconColor: const Color(0xFFE63946),
                iconBgColor: const Color(0xFFFFE5E5),
                title: "Medical Report",
                subtitle: "Add or View Records",
                onTap: () => _onItemTapped(1),
              ),
              const SizedBox(height: 16),
              _buildServiceCard(
                icon: Icons.alarm_add_rounded,
                iconColor: const Color(0xFFE63946),
                iconBgColor: const Color(0xFFFFE5E5),
                title: "Medicine Reminder",
                subtitle: "Never Miss a Dose",
                hasPending: _pendingAlertsCount > 0,
                pendingCount: _pendingAlertsCount,
                onTap: () => _onItemTapped(2),
              ),
              const SizedBox(height: 24),

              // Vitals Overview Row
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewReadingsPage())),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1C).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE63946).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.favorite_rounded, color: Color(0xFFE63946), size: 28),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "LATEST VITALS",
                                  style: TextStyle(
                                    color: Color(0xFFE63946),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Heart Rate",
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text("72", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 4),
                              Text("BPM", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 75,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(icon: Icons.grid_view_rounded, label: "HOME", index: 0),
                _buildNavItem(icon: Icons.analytics_rounded, label: "REPORT", index: 1),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(icon: Icons.medication_liquid_rounded, label: "MEDS", index: 2),
                _buildNavItem(icon: Icons.account_circle_rounded, label: "SETTINGS", index: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFFE63946) : Colors.blueGrey.shade300;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool hasPending = false,
    int pendingCount = 0,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1C).withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1116),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasPending)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$pendingCount PENDING",
                      style: const TextStyle(
                        color: Color(0xFFE63946),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const Icon(Icons.chevron_right, color: Colors.white24, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String unit,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1C).withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade400,
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
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
