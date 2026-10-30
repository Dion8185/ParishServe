// =============================================================================
// FILE: lib/features/sacramental_records/presentation/dialogs/discard_entry_dialog.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

/// Shows a reusable confirmation dialog when attempting to exit or discard unsaved form inputs.
/// Highlights "Keep Editing" (primary action) over "Discard & Exit" (secondary action).
/// Returns `true` if the user confirms exit, or `false` if the user chooses to stay.
Future<bool> showDiscardConfirmationDialog(
    BuildContext context, {
      String title = 'Discard Unsaved Changes?',
      String message = 'All information entered on this form will be discarded. Do you wish to leave this page?',
      Color? accentColor,
    }) async {
  final primaryColor = accentColor ?? ParishColors.marianBlue;
  final textDark = ParishColors.textDark;
  final textMuted = ParishColors.textMuted;
  final cardWhite = ParishColors.cardWhite;
  final borderGrey = ParishColors.borderGrey;

  final shouldExit = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: cardWhite,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ParishColors.mercyRedSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: ParishColors.mercyRed,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14.5,
          color: textDark.withOpacity(0.85),
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      actions: [
        Row(
          children: [
            // Destructive Secondary Option: Explicitly named "Discard & Exit"
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: borderGrey, width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: Icon(Icons.close, size: 18, color: ParishColors.mercyRed),
                  label: Text(
                    'Discard & Exit',
                    style: TextStyle(
                      color: ParishColors.mercyRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Safe Primary Option: Explicitly named "Keep Editing"
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text(
                    'Keep Editing',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return shouldExit ?? false;
}