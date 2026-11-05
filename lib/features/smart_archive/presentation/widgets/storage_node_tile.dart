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
  final bool isOffline;
  final String? storageType;
  final DateTime? lastTelemetry;

  const StorageNodeTile({
    super.key,
    required this.roomTitle,
    required this.nodeId,
    required this.temperature,
    required this.humidity,
    required this.isWarning,
    this.isOffline = false,
    this.storageType,
    this.lastTelemetry,
  });

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    Color tileBgColor = cardWhite;
    Color tileBorderColor = borderGrey;
    double tileBorderWidth = 1.0;

    if (isOffline) {
      tileBgColor = Colors.grey.shade50;
      tileBorderColor = Colors.grey.shade400;
      tileBorderWidth = 1.2;
    } else if (isWarning) {
      tileBgColor = ParishColors.mercyRedSurface.withOpacity(0.5);
      tileBorderColor = ParishColors.mercyRed;
      tileBorderWidth = 1.8;
    }

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
          color: tileBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tileBorderColor,
            width: tileBorderWidth,
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
                          fontSize: 15.5,
                          color: isOffline ? textMuted : (isWarning ? ParishColors.mercyRed : textDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            nodeId,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isOffline ? textMuted : ParishColors.marianBlue,
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

                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOffline
                        ? Colors.grey.shade600
                        : (isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOffline
                            ? Icons.wifi_off_rounded
                            : (isWarning ? Icons.warning_amber_rounded : Icons.check_circle),
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isOffline
                              ? 'OFFLINE'
                              : (isWarning ? 'ALERT' : 'OPTIMAL'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live Gauges: Temperature & Relative Humidity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.thermostat, color: ParishColors.goldAccent, size: 17),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Temperature', style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                temperature,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isOffline ? textMuted : textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: borderGrey),
                  const SizedBox(width: 10),

                  // Humidity Metric
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isOffline
                                ? Colors.grey.shade200
                                : (isWarning ? ParishColors.mercyRedSurface : ParishColors.marianBlueSurface),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.water_drop_outlined,
                            color: isOffline
                                ? textMuted
                                : (isWarning ? ParishColors.mercyRed : ParishColors.marianBlue),
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rel. Humidity', style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                humidity,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isOffline
                                      ? textMuted
                                      : (isWarning ? ParishColors.mercyRed : textDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Honest Footer: Sensor & Action Hint
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.sensors, size: 13, color: isOffline ? Colors.amber.shade800 : ParishColors.marianBlue),
                    const SizedBox(width: 4),
                    Text(
                      isOffline ? 'Awaiting transmission...' : 'DHT11 Live Feed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOffline ? Colors.amber.shade800 : textMuted,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'View Inspector',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOffline ? Colors.amber.shade900 : ParishColors.marianBlue,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: isOffline ? Colors.amber.shade900 : ParishColors.marianBlue,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}