// =============================================================================
// FILE: lib/features/smart_archive/presentation/dialogs/sensor_detail_dialog.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class _SensorDetailDialog extends StatefulWidget {
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
  State<_SensorDetailDialog> createState() => _SensorDetailDialogState();
}

class _SensorDetailDialogState extends State<_SensorDetailDialog> {
  List<Map<String, dynamic>> _historyLogs = [];
  bool _isLoadingLogs = true;

  @override
  void initState() {
    super.initState();
    _fetch24HourTelemetry();
  }

  Future<void> _fetch24HourTelemetry() async {
    try {
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      final data = await Supabase.instance.client
          .from('sensor_telemetry_logs')
          .select('temperature, humidity, recorded_at, is_warning')
          .eq('node_id', widget.nodeId)
          .gte('recorded_at', twentyFourHoursAgo)
          .order('recorded_at', ascending: true)
          .limit(30);

      if (mounted) {
        setState(() {
          _historyLogs = List<Map<String, dynamic>>.from(data);
          _isLoadingLogs = false;
        });
      }
    } catch (e) {
      debugPrint('[SensorDetailDialog] Notice fetching telemetry logs: $e');
      if (mounted) setState(() => _isLoadingLogs = false);
    }
  }

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
        width: 520,
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: widget.isWarning ? ParishColors.mercyRedSurface : ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isWarning ? ParishColors.mercyRed : ParishColors.marianBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isWarning ? Icons.warning_amber_rounded : Icons.sensors,
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
                          widget.roomTitle,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Node ID: ${widget.nodeId}',
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

            // Content Body - Strictly essential data
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
                        color: widget.isWarning ? ParishColors.mercyRedSurface : ParishColors.oliveGreenSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                widget.isWarning ? Icons.error_outline : Icons.check_circle_outline,
                                color: widget.isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isWarning ? 'MICROCLIMATE BREACH DETECTED' : 'OPTIMAL PRESERVATION STATUS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isWarning
                                ? 'Relative humidity is currently ${widget.humidity}. Please verify room ventilation and run the archive dehumidifier.'
                                : 'Microclimate parameters are safe for long-term sacramental book and parchment preservation.',
                            style: TextStyle(fontSize: 12, color: textDark, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Telemetry Cards
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
                                Text(widget.temperature, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                                const SizedBox(height: 2),
                                Text('Canon Target: 18°C – 24°C', style: TextStyle(fontSize: 10, color: textMuted)),
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
                                  widget.humidity,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isWarning ? ParishColors.mercyRed : ParishColors.marianBlue,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text('Canon Target: 45% – 60%', style: TextStyle(fontSize: 10, color: textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Actual Log History
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recorded Telemetry History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                        if (_isLoadingLogs)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Text('${_historyLogs.length} events logged', style: TextStyle(fontSize: 11, color: textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      height: 85,
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderGrey),
                      ),
                      child: _historyLogs.isEmpty
                          ? Center(
                        child: Text(
                          _isLoadingLogs ? 'Loading archive logs...' : 'No historical breach logs recorded in the past 24 hours.',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                      )
                          : _buildTelemetrySparkline(_historyLogs),
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

  Widget _buildTelemetrySparkline(List<Map<String, dynamic>> logs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: logs.map((log) {
        final hum = double.tryParse(log['humidity']?.toString() ?? '50.0') ?? 50.0;
        final isBreach = hum > 60.0;
        final normalizedHeight = ((hum - 35) / 45 * 50).clamp(8.0, 56.0);

        return Expanded(
          child: Tooltip(
            message: '${hum.toStringAsFixed(1)}% RH',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: normalizedHeight,
                    decoration: BoxDecoration(
                      color: isBreach ? ParishColors.mercyRed : ParishColors.marianBlue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}