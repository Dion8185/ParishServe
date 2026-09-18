import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

/// Shows a reusable confirmation dialog when attempting to exit or discard unsaved form inputs.
/// Highlights "Cancel" (colored background, primary) over "Confirm" (white background, secondary).
/// Returns `true` if the user confirms exit, or `false` if the user cancels.
Future<bool> showDiscardConfirmationDialog(
    BuildContext context, {
      String title = 'Are you sure you want to Exit?',
      String message = 'All information entered will be discarded.',
      Color? accentColor,
    }) async {
  final primaryColor = accentColor ?? ParishColors.marianBlue;

  final shouldExit = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: ParishColors.cardWhite,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: ParishColors.textDark,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: ParishColors.textMuted,
          height: 1.3,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      actions: [
        // Confirm Exit (White bg with subtle border, secondary)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: BorderSide(color: ParishColors.borderGrey, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Confirm',
            style: TextStyle(
              color: ParishColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Cancel Exit (Prominent colored background, primary)
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );

  return shouldExit ?? false;
}