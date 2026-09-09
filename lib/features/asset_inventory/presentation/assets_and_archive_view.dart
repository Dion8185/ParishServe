import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../smart_archive/presentation/widgets/storage_node_tile.dart';
import 'dialogs/audit_scan_dialog.dart';
import 'widgets/asset_item_card.dart';

class AssetAndArchiveView extends StatelessWidget {
  const AssetAndArchiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assets & Smart Archive', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Inventory audits & environmental storage status', style: TextStyle(color: ParishColors.textMuted)),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => showAuditScanModal(context),
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: const Text('Scan QR / Tap NFC for Audit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Storage Room Telemetry Nodes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const StorageNodeTile(
            roomTitle: 'Main Sacramental Archive Room',
            nodeId: 'ESP32-NODE-01',
            temperature: '24.2 °C',
            humidity: '54 %',
            isWarning: false,
          ),
          const StorageNodeTile(
            roomTitle: 'Liturgical Vessel & Robe Storage',
            nodeId: 'ESP32-NODE-02',
            temperature: '29.1 °C',
            humidity: '68 %',
            isWarning: true,
          ),

          const SizedBox(height: 24),
          const Text('Registered Parish Assets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          const AssetItemCard(
            controlNo: 'JP2-2023-SAC-0014',
            itemName: 'Gold-Plated Ciboria (Sacred Vessel)',
            location: 'Sacristy Vault - Cabinet A',
            condition: 'VERIFIED / GOOD',
            conditionColor: ParishColors.oliveGreen,
          ),
          const AssetItemCard(
            controlNo: 'JP2-2022-AV-0008',
            itemName: 'Wireless Microphone Set (2 Pcs)',
            location: 'Altar Sound Station',
            condition: 'REQUIRES REPAIR',
            conditionColor: ParishColors.mercyRed,
          ),
        ],
      ),
    );
  }
}