// =============================================================================
// FILE: lib/features/asset_inventory/presentation/widgets/asset_confirmation_dialog.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

/// Shows an action confirmation dialog for saving, modifying, deleting,
/// archiving, or restoring inventory records.
Future<bool> showAssetActionConfirmationDialog(
    BuildContext context, {
      required String title,
      required String message,
      String? itemIdentifier,
      String confirmLabel = 'Confirm',
      String cancelLabel = 'Cancel',
      IconData icon = Icons.help_outline,
      bool isDestructive = false,
      Color? accentColor,
    }) async {
  final resolvedColor = accentColor ?? (isDestructive ? ParishColors.mercyRed : ParishColors.marianBlue);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: ParishColors.cardWhite,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: resolvedColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: resolvedColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: ParishColors.textDark,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: ParishColors.textDark,
                height: 1.4,
              ),
            ),
            if (itemIdentifier != null && itemIdentifier.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParishColors.borderGrey.withOpacity(0.7)),
                ),
                child: Text(
                  itemIdentifier.trim(),
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            cancelLabel,
            style: TextStyle(
              color: ParishColors.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: resolvedColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            elevation: 0,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Specialized confirmation dialog for leaving a form with unsaved changes.
Future<bool> showUnsavedChangesConfirmationDialog(BuildContext context) async {
  return showAssetActionConfirmationDialog(
    context,
    title: 'Discard Unsaved Changes?',
    message: 'You have entered details that have not been saved yet. Leaving now will discard all entered values.',
    confirmLabel: 'Discard & Leave',
    cancelLabel: 'Keep Editing',
    icon: Icons.warning_amber_rounded,
    isDestructive: true,
  );
}