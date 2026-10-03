// =============================================================================
// FILE: lib/features/smart_archive/presentation/widgets/storage_node_tile.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../dialogs/sensor_detail_dialog.dart';

class StorageNodeTile extends StatelessWidget {
  final String roomTitle;
  final String nodeId;
  final String temperature;
  final String humidity;
  final bool isWarning;
  final String? storageType;
  final int signalDbm;
  final int batteryPercent;
  final DateTime? lastTelemetry;

  const StorageNodeTile({
    super.key,
    required this.roomTitle,
    required this.nodeId,
    required this.temperature,
    required this.humidity,
    required this.isWarning,
    this.storageType,
    this.signalDbm = -60,
    this.batteryPercent = 95,
    this.lastTelemetry,
  });

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return InkWell(
      onTap: () => showSensorDetailModal(
        context,
        roomTitle: roomTitle,
        nodeId: nodeId,
        temperature: temperature,
        humidity: humidity,
        isWarning: isWarning,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isWarning ? ParishColors.mercyRedSurface.withOpacity(0.5) : cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWarning ? ParishColors.mercyRed : borderGrey,
            width: isWarning ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isWarning
                  ? ParishColors.mercyRed.withOpacity(0.08)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Title, Node ID & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isWarning ? ParishColors.mercyRed : textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            nodeId,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.marianBlue,
                            ),
                          ),
                          if (storageType != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '• $storageType',
                                style: TextStyle(fontSize: 11, color: textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWarning ? Icons.warning_amber_rounded : Icons.check_circle,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isWarning ? 'HUMIDITY ALERT' : 'SAFE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live Gauges: Temperature & Relative Humidity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isWarning ? Colors.white : ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isWarning
                      ? ParishColors.mercyRed.withOpacity(0.3)
                      : borderGrey.withOpacity(0.6),
                ),
              ),
              child: Row(
                children: [
                  // Temperature Metric
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ParishColors.goldLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.thermostat, color: ParishColors.goldAccent, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Temp', style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.w600)),
                            Text(temperature, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: borderGrey),
                  const SizedBox(width: 12),

                  // Humidity Metric
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isWarning ? ParishColors.mercyRedSurface : ParishColors.marianBlueSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.water_drop_outlined,
                            color: isWarning ? ParishColors.mercyRed : ParishColors.marianBlue,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Humidity', style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.w600)),
                            Text(
                              humidity,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isWarning ? ParishColors.mercyRed : textDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Footer: Node Telemetry Metadata
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi, size: 12, color: textMuted),
                    const SizedBox(width: 3),
                    Text('$signalDbm dBm', style: TextStyle(fontSize: 10.5, color: textMuted)),
                    const SizedBox(width: 8),
                    Icon(Icons.battery_charging_full, size: 12, color: textMuted),
                    const SizedBox(width: 3),
                    Text('$batteryPercent%', style: TextStyle(fontSize: 10.5, color: textMuted)),
                  ],
                ),
                Text(
                  'Tap to inspect telemetry',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isWarning ? ParishColors.mercyRed : ParishColors.marianBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}