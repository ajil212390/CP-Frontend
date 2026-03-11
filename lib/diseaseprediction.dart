import 'package:flutter/material.dart';

class PredictDiseasePage extends StatelessWidget {
  const PredictDiseasePage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController symptomController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Predict Disease"),
        backgroundColor: const Color(0xFF00BFA5),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Enter your symptoms",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: symptomController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "E.g. fever, cough, headache...",
                filled: true,
                fillColor: Colors.grey[100],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DiseaseResultPage()));
              },
              icon: const Icon(Icons.search),
              label: const Text("Predict Disease"),
            ),
          ],
        ),
      ),
    );
  }
}

class DiseaseResultPage extends StatelessWidget {
  const DiseaseResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prediction Result"),
        backgroundColor: const Color(0xFF00BFA5),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "Possible disease: Common Cold\n\nRecommendation: Rest, fluids, paracetamol.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
