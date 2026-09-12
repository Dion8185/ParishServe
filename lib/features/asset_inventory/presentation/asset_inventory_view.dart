import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'dialogs/audit_scan_dialog.dart';
import 'dialogs/register_asset_dialog.dart';
import 'widgets/asset_item_card.dart';

class AssetInventoryView extends StatelessWidget {
  const AssetInventoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Parish Asset Inventory', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          Text('Track physical church properties, furniture, and sacred vessels', style: TextStyle(color: ParishColors.textMuted)),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => showAuditScanModal(context),
                    icon: const Icon(Icons.qr_code_scanner, size: 24),
                    label: const Text('Scan Audit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ParishColors.marianBlue, width: 1.8),
                      foregroundColor: ParishColors.marianBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => showRegisterAssetModal(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 24, color: ParishColors.marianBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Search by Control #, item name, or location...', style: TextStyle(fontSize: 14, color: ParishColors.textMuted)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('Registered Diocesan Properties', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 12),

          AssetItemCard(
            controlNo: 'JP2-2023-SAC-0014',
            itemName: 'Gold-Plated Ciboria (Sacred Vessel)',
            location: 'Sacristy Vault - Cabinet A',
            condition: 'VERIFIED / GOOD',
            conditionColor: ParishColors.oliveGreen,
          ),
          AssetItemCard(
            controlNo: 'JP2-2022-AV-0008',
            itemName: 'Wireless Microphone Set (2 Pcs)',
            location: 'Altar Sound Station',
            condition: 'REQUIRES REPAIR',
            conditionColor: ParishColors.mercyRed,
          ),
          AssetItemCard(
            controlNo: 'JP2-2021-FUR-0035',
            itemName: 'Hand-Carved Narra Presider\'s Chair',
            location: 'Sanctuary Altar Floor',
            condition: 'VERIFIED / GOOD',
            conditionColor: ParishColors.oliveGreen,
          ),
          AssetItemCard(
            controlNo: 'JP2-2024-LIT-0002',
            itemName: 'Roman Missal (Third Typical Edition)',
            location: 'Sacristy Clergy Bookcase',
            condition: 'VERIFIED / GOOD',
            conditionColor: ParishColors.oliveGreen,
          ),
        ],
      ),
    );
  }
}