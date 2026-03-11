import 'dart:convert';

import 'package:carepulseapp/alertdetails.dart';
import 'package:carepulseapp/loginApi.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';


class AlertListPage extends StatefulWidget {
  final int userId; // Pass from login or user model
  const AlertListPage({super.key, required this.userId});

  @override
  State<AlertListPage> createState() => _AlertListPageState();
}

class _AlertListPageState extends State<AlertListPage> {
  final Dio _dio = Dio();
  bool isLoading = true;
  List alerts = [];

  @override
  void initState() {
    super.initState();
    fetchAlerts();
  }

  Future<void> fetchAlerts() async {
    final apiUrl = "$baseUrl/api/alerts/"; // <-- Replace with real API URL

    try {
      final response = await _dio.post(apiUrl, data: {"user_id": widget.userId});

      if (response.statusCode == 200) {
        setState(() {
          alerts = response.data['alerts'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load alerts")),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Alerts"),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : alerts.isEmpty
              ? const Center(child: Text("No alerts found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final bool isRead = alert['sent'] ?? false;

                    return Card(
                      color: isRead ? Colors.grey[100] : Colors.teal[50],
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.notifications,
                          color: isRead ? Colors.grey : Colors.teal,
                        ),
                        title: Text(
                          alert['title'] ?? "Untitled Alert",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRead ? Colors.black54 : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          alert['description'] ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isRead
                            ? const Icon(Icons.done_all, color: Colors.grey)
                            : const Icon(Icons.mark_email_unread, color: Colors.teal),
                        onTap: () async {
                          // Navigate to detail page
                          final marked = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlertDetailPage(
                                alertId: alert['id'],
                              ),
                            ),
                          );

                          // Refresh if alert marked as read
                          if (marked == true) {
                            fetchAlerts();
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
