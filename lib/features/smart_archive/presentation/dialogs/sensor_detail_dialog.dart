import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showSensorDetailModal(
    BuildContext context, {
      required String roomTitle,
      required String nodeId,
      required String temperature,
      required String humidity,
      required bool isWarning,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(roomTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Node ID: $nodeId', style: const TextStyle(color: ParishColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Temperature: $temperature', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 14),
              Text('Humidity: $humidity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isWarning ? ParishColors.mercyRedSurface : ParishColors.oliveGreenSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isWarning
                  ? 'CRITICAL ALERT: Safe relative humidity exceeded (Threshold: 60%). Inspect room dehumidifier immediately.'
                  : 'STATUS OPTIMAL: Environmental conditions are within safe paper preservation ranges.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}