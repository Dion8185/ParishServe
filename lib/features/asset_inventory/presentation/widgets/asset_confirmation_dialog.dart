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
  final resolvedColor = accentColor ??
      (isDestructive ? ParishColors.mercyRed : ParishColors.marianBlue);

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
                  border: Border.all(
                    color: ParishColors.borderGrey.withOpacity(0.7),
                  ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
    message:
    'You have entered details that have not been saved yet. Leaving now will discard all entered values.',
    confirmLabel: 'Discard & Leave',
    cancelLabel: 'Keep Editing',
    icon: Icons.warning_amber_rounded,
    isDestructive: true,
  );
}

/// Specialized permanent deletion dialog requiring the user to type the
/// exact Diocesan Control Number before enabling the delete action.
Future<bool> showPermanentDeleteConfirmationDialog(
    BuildContext context, {
      required String controlNumber,
      required String itemName,
    }) async {
  final cleanExpected = controlNumber.trim().toUpperCase();
  final inputController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      bool isMatch = false;

      return StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: ParishColors.cardWhite,
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ParishColors.mercyRed.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: ParishColors.mercyRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Permanently Delete Asset?',
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
                    'This action is irreversible. The record for "$itemName", including its photographic evidence and audit history, will be permanently removed from the parish database.',
                    style: TextStyle(
                      fontSize: 13,
                      color: ParishColors.textDark,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ParishColors.mercyRedSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ParishColors.mercyRed.withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To confirm deletion, please type the control number below:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.mercyRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          controlNumber.trim(),
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: ParishColors.mercyRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: inputController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Type Diocesan Control Number',
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: ParishColors.textMuted,
                      ),
                      hintText: controlNumber.trim(),
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: ParishColors.textMuted.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: ParishColors.backgroundLight,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: ParishColors.borderGrey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isMatch
                              ? ParishColors.mercyRed
                              : ParishColors.borderGrey,
                          width: isMatch ? 1.5 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: ParishColors.mercyRed,
                          width: 1.8,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      final matches = val.trim().toUpperCase() == cleanExpected;
                      if (matches != isMatch) {
                        setModalState(() => isMatch = matches);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: ParishColors.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMatch
                      ? ParishColors.mercyRed
                      : ParishColors.borderGrey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  elevation: 0,
                ),
                onPressed: isMatch ? () => Navigator.pop(ctx, true) : null,
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text(
                  'Permanently Delete',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  inputController.dispose();
  return result ?? false;
}