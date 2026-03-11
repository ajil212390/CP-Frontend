import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';

class DietPlanPage extends StatefulWidget {
  final String predictionResult;
  const DietPlanPage({super.key, required this.predictionResult});

  @override
  State<DietPlanPage> createState() => _DietPlanPageState();
}

class _DietPlanPageState extends State<DietPlanPage> {
  late GenerativeModel model;
  bool isLoading = true;
  String dietAdvice = "";

  final String geminiApiKey = "AIzaSyBYZWIBQdSKUFaYyqu7swWLAWOHBRAAShs";

  @override
  void initState() {
    super.initState();
    model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: geminiApiKey);
    generateDietAdvice();
  }

  Future<void> generateDietAdvice() async {
    setState(() => isLoading = true);

    try {
      String result = widget.predictionResult.toLowerCase();
      int planDays = 7;

      if (result.contains("diabetes") || result.contains("hypertension")) {
        planDays = 30;
      } else if (result.contains("obesity") || result.contains("overweight")) {
        planDays = 21;
      } else if (result.contains("deficiency") || result.contains("low")) {
        planDays = 14;
      }

      final response = await model.generateContent([
        Content.text(
          "You are a certified nutritionist. Based on this medical prediction: '${widget.predictionResult}', "
          "create a clear and simple ${planDays}-day eating plan. "
          "Include meals for Breakfast, Mid-morning snack, Lunch, Evening snack, and Dinner. "
          "List foods in bullet points and give recommended portion sizes. Avoid disclaimers and focus on dietary changes."
        )
      ]);

      setState(() {
        dietAdvice = response.text ?? "No diet plan generated.";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        dietAdvice = "⚠️ Error generating diet plan: $e";
        isLoading = false;
      });
    }
  }

  Future<void> downloadAsPdf() async {
    final pdf = pw.Document();
    final lines = dietAdvice.split('\n');

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            "Personalized Dietary Plan",
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            "Medical Prediction:\n${widget.predictionResult}\n",
            style: const pw.TextStyle(fontSize: 16),
          ),
          pw.Divider(),
          pw.ListView.builder(
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final text = lines[index].trim();
              if (text.isEmpty) return pw.SizedBox(height: 2);
              return pw.Bullet(
                  text: text,
                  style: const pw.TextStyle(fontSize: 14, height: 1.4));
            },
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/diet_plan.pdf");
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("PDF saved: ${file.path}")));
    await OpenFilex.open(file.path);
  }

  // ----------- Begin: NEW UI -----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1B2936) : const Color(0xFFE9FFF2),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A5E4C)),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: "Back",
        ),
        actions: [
          if (dietAdvice.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Color(0xFF1A5E4C)),
              tooltip: "Download as PDF",
              onPressed: downloadAsPdf,
            ),
        ],
        title: Column(
          children: [
            Text(
              "Diet Plan",
              style: TextStyle(
                  color: const Color(0xFF077D4E),
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 1.1),
            ),
            const SizedBox(height: 2),
            Text(
              "Personalized For You",
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w400,
                fontSize: 13,
                letterSpacing: 0.07,
              ),
            ),
          ],
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF0F1A21) : const Color(0xFFF9FEFA),
      body: Column(
        children: [
          // Prediction chip
          // Padding(
          //   padding: const EdgeInsets.only(top: 18.0, bottom: 6),
          //   child: Chip(
          //     backgroundColor: isDark ? const Color(0xFF183E26) : const Color(0xFFE1FFD7),
          //     padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          //     label: Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         const Icon(Icons.local_hospital, size: 19, color: Color(0xFF2CC58D)),
          //         const SizedBox(width: 6),
          //         // Flexible(
          //         //   child: Text(
          //         //     "Prediction: ${widget.predictionResult}",
          //         //     style: TextStyle(
          //         //       fontWeight: FontWeight.bold,
          //         //       letterSpacing: 0.09,
          //         //       fontSize: 15,
          //         //       color: isDark ? Colors.green[200] : const Color(0xFF236B44),
          //         //     ),
          //         //     maxLines: 2,
          //         //     overflow: TextOverflow.ellipsis,
          //         //   ),
          //         // ),
          //       ],
          //     ),
          //   ),
          // ),
          const SizedBox(height: 8),

          // Advice area container
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              child: Material(
                elevation: 8,
                color: isDark ? const Color(0xFF233E2B) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
                  child: isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 35),
                              CircularProgressIndicator(
                                color: Colors.green[300],
                                strokeWidth: 5,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                "Generating your diet plan...",
                                style: TextStyle(
                                  fontSize: 16.5,
                                  color: Colors.green[800],
                                ),
                              )
                            ],
                          ),
                        )
                      : dietAdvice.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.sentiment_dissatisfied,
                                      color: Colors.orange[600], size: 36),
                                  const SizedBox(height: 14),
                                  Text(
                                    "No dietary recommendation!",
                                    style: TextStyle(
                                      color: Colors.red[900],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Could not generate plan.",
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Scrollbar(
                              radius: const Radius.circular(22),
                              child: ListView(
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  Center(
                                    child: Text(
                                      "💡 Your dietary recommendations",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18.5,
                                        color: const Color(0xFF23796A),
                                        letterSpacing: 0.11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ..._buildDietAdviceWidgets(dietAdvice),
                                  const SizedBox(height: 28),
                                  Center(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.save_alt, color: Colors.white, size: 22),
                                      label: const Text(
                                        "Download Diet Plan",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16.2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      onPressed: downloadAsPdf,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF27BE79),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 13),
                                        elevation: 6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDietAdviceWidgets(String advice) {
    final lines = advice.split('\n');
    final widgets = <Widget>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final isSection = RegExp(r'^\d+\s*[\.\)]\s*').hasMatch(trimmed) ||
          trimmed.toLowerCase().contains("day") ||
          trimmed.endsWith(':');
      if (isSection) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4.0, top: 17, bottom: 5),
          child: Text(
            trimmed,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17.5,
              letterSpacing: 0.08,
              color: Color(0xFF248563),
            ),
          ),
        ));
      } else if (trimmed.startsWith('-') || trimmed.startsWith('•') || trimmed.startsWith('*')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.circle, size: 7.3, color: Color(0xFF90E3B5)),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    trimmed.replaceFirst(RegExp(r'^[-•*]\s*'), ''),
                    style: const TextStyle(
                      fontSize: 15.7,
                      height: 1.5,
                      color: Color(0xFF194424),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 2),
            child: Text(
              trimmed,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF355A46),
                height: 1.45,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}
