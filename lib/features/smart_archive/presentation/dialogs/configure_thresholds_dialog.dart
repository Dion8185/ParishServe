// =============================================================================
// FILE: lib/features/smart_archive/presentation/dialogs/configure_thresholds_dialog.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showConfigureThresholdsModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ConfigureThresholdsDialog(),
  );
}

class _ConfigureThresholdsDialog extends StatefulWidget {
  const _ConfigureThresholdsDialog();

  @override
  State<_ConfigureThresholdsDialog> createState() => _ConfigureThresholdsDialogState();
}

class _ConfigureThresholdsDialogState extends State<_ConfigureThresholdsDialog> {
  double _maxHumidity = 60.0;
  double _maxTemperature = 26.0;
  int _pollingIntervalSec = 60;
  bool _audioAlarmsEnabled = true;
  bool _pushNotificationsEnabled = true;

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
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: ParishColors.marianBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Environmental Thresholds',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          'Define microclimate alert triggers for archive rooms',
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

            // Sliders & Configuration Settings
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Maximum Relative Humidity Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Max Relative Humidity Threshold:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                        Text('${_maxHumidity.toInt()}% RH', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                      ],
                    ),
                    Slider(
                      value: _maxHumidity,
                      min: 45.0,
                      max: 80.0,
                      divisions: 35,
                      activeColor: ParishColors.marianBlue,
                      onChanged: (val) => setState(() => _maxHumidity = val),
                    ),
                    Text('Canon 1283 baseline: Relative humidity exceeding 60% promotes mold spores and biological paper decay.', style: TextStyle(fontSize: 11, color: textMuted)),
                    const Divider(height: 24),

                    // Maximum Temperature Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Max Ambient Temperature Threshold:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                        Text('${_maxTemperature.toInt()} °C', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                      ],
                    ),
                    Slider(
                      value: _maxTemperature,
                      min: 18.0,
                      max: 35.0,
                      divisions: 17,
                      activeColor: ParishColors.goldAccent,
                      onChanged: (val) => setState(() => _maxTemperature = val),
                    ),
                    Text('Temperatures above 26°C accelerate ink acid hydrolysis in handwritten leather volumes.', style: TextStyle(fontSize: 11, color: textMuted)),
                    const Divider(height: 24),

                    // Polling Interval Dropdown
                    Text('Telemetry Ingestion Rate:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _pollingIntervalSec,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: ParishColors.backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('Every 30 Seconds (High-Frequency)')),
                        DropdownMenuItem(value: 60, child: Text('Every 60 Seconds (Standard Mesh)')),
                        DropdownMenuItem(value: 300, child: Text('Every 5 Minutes (Power-Saving)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _pollingIntervalSec = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Alert Dispatch Rules
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: ParishColors.oliveGreen,
                      title: const Text('Push Notification Broadcast', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Alert all Secretariat & Clergy mobile devices on breach', style: TextStyle(fontSize: 11)),
                      value: _pushNotificationsEnabled,
                      onChanged: (val) => setState(() => _pushNotificationsEnabled = val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: ParishColors.oliveGreen,
                      title: const Text('Audible Hardware Alarm Tone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Emit piezo tone from ESP32 node when threshold is breached', style: TextStyle(fontSize: 11)),
                      value: _audioAlarmsEnabled,
                      onChanged: (val) => setState(() => _audioAlarmsEnabled = val),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: textMuted)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Environmental parameters updated. Broadcast sent to ESP32 nodes.'),
                          backgroundColor: ParishColors.oliveGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save Parameters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}