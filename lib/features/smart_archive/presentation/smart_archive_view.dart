import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'dialogs/configure_thresholds_dialog.dart';
import 'widgets/storage_node_tile.dart';

class SmartArchiveView extends StatelessWidget {
  const SmartArchiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Smart Archive & IoT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          Text('ESP32 telemetry monitoring for sacramental books & asset storage', style: TextStyle(color: ParishColors.textMuted)),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hub_outlined, color: ParishColors.marianBlue, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('4 Active ESP32 Nodes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                      const Text('1 Node Triggered Humidity Alert', style: TextStyle(fontSize: 13, color: ParishColors.mercyRed, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                foregroundColor: ParishColors.marianBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => showConfigureThresholdsModal(context),
              icon: const Icon(Icons.tune),
              label: const Text('Configure Environmental Thresholds', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          Text('Monitored Storage Zones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 12),

          StorageNodeTile(
            roomTitle: 'Main Sacramental Archive Room',
            nodeId: 'ESP32-NODE-01',
            temperature: '24.2 °C',
            humidity: '54 %',
            isWarning: false,
          ),
          StorageNodeTile(
            roomTitle: 'Liturgical Vessel & Robe Storage',
            nodeId: 'ESP32-NODE-02',
            temperature: '29.1 °C',
            humidity: '68 %',
            isWarning: true,
          ),
          StorageNodeTile(
            roomTitle: 'Historical Parish Register Vault',
            nodeId: 'ESP32-NODE-03',
            temperature: '23.5 °C',
            humidity: '51 %',
            isWarning: false,
          ),
          StorageNodeTile(
            roomTitle: 'Altar Linen & Vestment Closet',
            nodeId: 'ESP32-NODE-04',
            temperature: '26.0 °C',
            humidity: '58 %',
            isWarning: false,
          ),
        ],
      ),
    );
  }
}