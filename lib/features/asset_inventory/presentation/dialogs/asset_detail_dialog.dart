import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showAssetDetailModal(
    BuildContext context, {
      required String controlNo,
      required String itemName,
      required String location,
      required String condition,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diocese Control No: $controlNo', style: const TextStyle(color: ParishColors.marianBlue, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text('Location: $location', style: const TextStyle(fontSize: 14)),
          Text('Current Condition: $condition', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Update Status'),
        ),
      ],
    ),
  );
}