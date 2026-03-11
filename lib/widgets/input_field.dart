import 'package:flutter/material.dart';

class InputField extends StatelessWidget {
  final String label;
  final String? unit;
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const InputField({
    super.key,
    required this.label,
    this.unit,
    required this.controller,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextFormField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              keyboardType: TextInputType.number,
              validator: validator ?? (value) {
                if (value == null || value.isEmpty) {
                  return "Required";
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: "Enter value ${unit != null ? '($unit)' : ''}",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
