import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ParishDialogTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool enabled;

  const ParishDialogTextField({
    super.key,
    required this.label,
    required this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: ParishColors.backgroundLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}