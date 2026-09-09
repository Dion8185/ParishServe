import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/dialog_text_field.dart';

void showRegisterAssetModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Register Parish Property', style: TextStyle(fontWeight: FontWeight.bold)),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ParishDialogTextField(label: 'Item Name & Description', hint: 'e.g., Sterling Silver Chalice'),
            ParishDialogTextField(label: 'Asset Classification', hint: 'Sacred Vessel / Audio-Visual / Furniture'),
            ParishDialogTextField(label: 'Storage / Placement Location', hint: 'e.g., Sacristy Vault - Cabinet B'),
            ParishDialogTextField(label: 'Acquisition Mode & Cost', hint: 'e.g., Donated / ₱ 25,000.00'),
            ParishDialogTextField(label: 'Diocesan Control #', hint: 'JP2-2026-SAC-0021', enabled: false),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Save Asset Record'),
        ),
      ],
    ),
  );
}