import 'package:carepulseapp/login.dart';
import 'package:carepulseapp/loginApi.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'widgets/glass_card.dart';

String _formatDate(DateTime date) {
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return "${months[date.month - 1]} ${date.day}, ${date.year}";
}

class MedicineReminderPage extends StatefulWidget {
  final VoidCallback? onBack;
  const MedicineReminderPage({super.key, this.onBack});

  @override
  State<MedicineReminderPage> createState() => _MedicineReminderPageState();
}

class _MedicineReminderPageState extends State<MedicineReminderPage> {
  List<dynamic> _reminders = [];
  bool _isLoading = true;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  Future<void> _fetchMedicines() async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.get("$baseUrl/api/medicines/", queryParameters: {"user_id": lid});
      if (response.statusCode == 200) {
        setState(() {
          _reminders = response.data['medicines'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching medicines: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addReminder() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddMedicineSheet(),
    );
    
    if (result == true) {
      _fetchMedicines();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "Medicine Reminders",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
          ),
        ),
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Themed Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1515),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.medication_liquid_rounded, color: Colors.redAccent, size: 28),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Active Medications",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 22,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${_reminders.length} medications scheduled",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _addReminder,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            "ADD MEDICINE",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "YOUR SCHEDULE",
              style: TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 16),
            _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
            : _reminders.isEmpty
            ? Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.medication_outlined, size: 64, color: Colors.white10),
                    const SizedBox(height: 16),
                    Text("No medicines added yet", style: TextStyle(color: Colors.white24, fontSize: 16)),
                  ],
                ),
              )
            : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final med = _reminders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              med['name'] ?? "Unknown",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Switch(
                                  value: med['is_active'] ?? true,
                                  onChanged: (val) async {
                                    try {
                                      await _dio.patch("$baseUrl/api/medicines/${med['id']}/", data: {"is_active": val});
                                      _fetchMedicines();
                                    } catch (e) {
                                      debugPrint("Error toggling: $e");
                                    }
                                  },
                                  activeColor: Colors.redAccent,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                                  onPressed: () async {
                                    try {
                                      await _dio.delete("$baseUrl/api/medicines/${med['id']}/");
                                      _fetchMedicines();
                                    } catch (e) {
                                      debugPrint("Error deleting: $e");
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.schedule, color: Colors.white38, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              (med['timings'] as List).join(" • "),
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "${med['start_date']} - ${med['end_date']}",
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.repeat, color: Colors.white38, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              med['frequency'] ?? "Daily",
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddMedicineSheet extends StatefulWidget {
  const AddMedicineSheet({super.key});

  @override
  State<AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<AddMedicineSheet> {
  final nameController = TextEditingController();
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 30));
  List<TimeOfDay> timings = [const TimeOfDay(hour: 8, minute: 0)];
  String frequency = "Daily";

  void _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  void _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        timings.add(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Add New Medicine",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            
            // Name Field
            _buildInputLabel("MEDICINE NAME"),
            _buildGlassInput(
              controller: nameController,
              hint: "e.g. Metformin",
              icon: Icons.medication,
            ),
            
            const SizedBox(height: 24),
            
            // Timings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInputLabel("TIMINGS"),
                TextButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add, size: 16, color: Colors.redAccent),
                  label: const Text("Add Time", style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: timings.map((t) => Chip(
                backgroundColor: const Color(0xFF251818),
                label: Text(t.format(context), style: const TextStyle(color: Colors.white)),
                deleteIconColor: Colors.redAccent,
                onDeleted: () => setState(() => timings.remove(t)),
              )).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // Dates
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputLabel("START DATE"),
                      GestureDetector(
                        onTap: () => _pickDate(true),
                        child: _buildSelectionTile(_formatDate(startDate), Icons.calendar_today),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputLabel("END DATE"),
                      GestureDetector(
                        onTap: () => _pickDate(false),
                        child: _buildSelectionTile(_formatDate(endDate), Icons.calendar_today),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Frequency
            _buildInputLabel("FREQUENCY"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: frequency,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: ["Daily", "Weekly", "Every Other Day", "Monthly"]
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (val) => setState(() => frequency = val!),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Save Button
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF3030), Color(0xFFAA0000)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () async {
                  if (nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter medicine name")));
                    return;
                  }
                  
                  if (lid == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session error: Please log in again")));
                    return;
                  }

                  final dio = Dio();
                  try {
                    final data = {
                      "user_id": lid,
                      "name": nameController.text,
                      "timings": timings.map((t) => "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}").toList(),
                      "start_date": "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}",
                      "end_date": "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}",
                      "frequency": frequency,
                      "is_active": true,
                    };
                    
                    print("Sending reminder data: $data to $baseUrl/api/medicines/");
                    
                    final response = await dio.post("$baseUrl/api/medicines/", data: data);
                    print("Response status: ${response.statusCode}");
                    print("Response data: ${response.data}");

                    if (response.statusCode == 201 || response.statusCode == 200) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Reminder saved successfully!"), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context, true);
                      }
                    }
                  } catch (e) {
                    print("Exception during save: $e");
                    if (e is DioException) {
                      print("Dio error response: ${e.response?.data}");
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to save reminder: $e")),
                    );
                  }
                },
                child: const Text(
                  "SET REMINDER",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
             const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildGlassInput({required TextEditingController controller, required String hint, required IconData icon}) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      borderRadius: 16,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
          icon: Icon(icon, color: Colors.redAccent, size: 20),
        ),
      ),
    );
  }

  Widget _buildSelectionTile(String text, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
