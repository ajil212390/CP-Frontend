import 'package:carepulseapp/loginApi.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class AlertDetailPage extends StatefulWidget {
  final int alertId;
  const AlertDetailPage({super.key, required this.alertId});

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  final Dio _dio = Dio();
  bool isLoading = true;
  Map<String, dynamic>? alert;

  @override
  void initState() {
    super.initState();
    fetchAlertDetails();
  }

  Future<void> fetchAlertDetails() async {
    final apiUrl = "$baseUrl/api/alerts/${widget.alertId}/"; // replace with backend URL
    try {
      final response = await _dio.post(apiUrl);
      if (response.statusCode == 200) {
        setState(() {
          alert = response.data['alert'];
          isLoading = false;
        });
        markAsRead(); // mark as read automatically
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> markAsRead() async {
    final markUrl = "$baseUrl/api/alerts/${widget.alertId}/mark-read/";
    try {
      await _dio.post(markUrl);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alert Details"),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : alert == null
              ? const Center(child: Text("Alert not found"))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: Colors.teal[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            alert!['title'] ?? "No Title",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            alert!['description'] ?? "",
                            style: const TextStyle(fontSize: 16, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          // Split start_time into date and time for display
                          Builder(
                            builder: (context) {
                              final startTimeStr = alert!['start_time'];
                              if (startTimeStr == null || startTimeStr.isEmpty) {
                                return const Text(
                                  'Date: N/A\nTime: N/A',
                                  style: TextStyle(fontSize: 14),
                                );
                              }
                              DateTime? dt;
                              try {
                                dt = DateTime.parse(startTimeStr);
                              } catch (_) {}
                              if (dt == null) {
                                return Text(
                                  'Date: N/A\nTime: N/A',
                                  style: const TextStyle(fontSize: 14),
                                );
                              }
                              final dateStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                              final timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Date: $dateStr",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    "Time: $timeStr",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          // Text(
                          //   "End Time: ${alert!['end_time'] ?? 'N/A'}",
                          //   style: const TextStyle(fontSize: 14),
                          // ),
                          // const SizedBox(height: 6),
                          // Text(
                          //   "Interval: ${alert!['interval_minutes']} minutes",
                          //   style: const TextStyle(fontSize: 14),
                          // ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
