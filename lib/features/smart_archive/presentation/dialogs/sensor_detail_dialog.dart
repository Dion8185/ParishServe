// =============================================================================
// FILE: lib/features/smart_archive/presentation/dialogs/sensor_detail_dialog.dart
// =============================================================================

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
    builder: (ctx) => _SensorDetailDialog(
      roomTitle: roomTitle,
      nodeId: nodeId,
      temperature: temperature,
      humidity: humidity,
      isWarning: isWarning,
    ),
  );
}

class _SensorDetailDialog extends StatelessWidget {
  final String roomTitle;
  final String nodeId;
  final String temperature;
  final String humidity;
  final bool isWarning;

  const _SensorDetailDialog({
    required this.roomTitle,
    required this.nodeId,
    required this.temperature,
    required this.humidity,
    required this.isWarning,
  });

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isWarning ? ParishColors.mercyRedSurface : ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isWarning ? ParishColors.mercyRed : ParishColors.marianBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isWarning ? Icons.warning_amber_rounded : Icons.sensors,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomTitle,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ESP32 Hardware Node: $nodeId',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Alert Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isWarning ? ParishColors.mercyRedSurface : ParishColors.oliveGreenSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isWarning ? Icons.error_outline : Icons.check_circle_outline,
                                color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isWarning ? 'CRITICAL HUMIDITY BREACH' : 'OPTIMAL PRESERVATION STATUS',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isWarning
                                ? 'Relative humidity is $humidity (Safe limit is <=60%). Inspect room ventilation and activate dehumidifier unit immediately.'
                                : 'Environmental variables are within safe bounds for long-term sacramental parchment storage.',
                            style: TextStyle(fontSize: 12, color: textDark, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Metrics Card
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ParishColors.backgroundLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderGrey),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ambient Temperature', style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(temperature, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                                const SizedBox(height: 2),
                                Text('Safe Target: 18°C - 24°C', style: TextStyle(fontSize: 10, color: textMuted)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ParishColors.backgroundLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderGrey),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Relative Humidity', style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  humidity,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isWarning ? ParishColors.mercyRed : ParishColors.marianBlue,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text('Safe Target: 45% - 60%', style: TextStyle(fontSize: 10, color: textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Hardware Specifications
                    Text('Hardware Node Telemetry', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDark)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderGrey),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Microcontroller Unit', 'ESP32-WROOM-32D Dual Core 240MHz'),
                          _buildDetailRow('Sensor Transducer', 'BME280 Calibrated Digital I2C'),
                          _buildDetailRow('Wi-Fi Mesh Signal', '-58 dBm (Strong Connection)'),
                          _buildDetailRow('Power / Battery Level', '98% (Mains Power + Backup LiPo)'),
                          _buildDetailRow('Firmware Version', 'ParishServe-Sensor-v1.4.2'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close Inspector'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
        ],
      ),
    );
  }
}