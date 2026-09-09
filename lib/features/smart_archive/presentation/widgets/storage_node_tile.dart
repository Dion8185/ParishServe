import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../dialogs/sensor_detail_dialog.dart';

class StorageNodeTile extends StatelessWidget {
  final String roomTitle;
  final String nodeId;
  final String temperature;
  final String humidity;
  final bool isWarning;

  const StorageNodeTile({
    super.key,
    required this.roomTitle,
    required this.nodeId,
    required this.temperature,
    required this.humidity,
    required this.isWarning,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showSensorDetailModal(
        context,
        roomTitle: roomTitle,
        nodeId: nodeId,
        temperature: temperature,
        humidity: humidity,
        isWarning: isWarning,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isWarning ? ParishColors.mercyRedSurface : ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isWarning ? ParishColors.mercyRed : ParishColors.borderGrey,
            width: isWarning ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(roomTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isWarning ? 'HUMIDITY ALERT' : 'SAFE',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(nodeId, style: const TextStyle(fontSize: 12, color: ParishColors.textMuted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Temp: $temperature', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 20),
                Text('Humidity: $humidity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}