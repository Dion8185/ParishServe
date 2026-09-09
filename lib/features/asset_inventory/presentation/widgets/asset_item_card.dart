import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../dialogs/asset_detail_dialog.dart';

class AssetItemCard extends StatelessWidget {
  final String controlNo;
  final String itemName;
  final String location;
  final String condition;
  final Color conditionColor;

  const AssetItemCard({
    super.key,
    required this.controlNo,
    required this.itemName,
    required this.location,
    required this.condition,
    required this.conditionColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showAssetDetailModal(
        context,
        controlNo: controlNo,
        itemName: itemName,
        location: location,
        condition: condition,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ParishColors.goldLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParishColors.goldAccent),
              ),
              child: const Icon(Icons.inventory, color: ParishColors.goldAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controlNo,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                  ),
                  const SizedBox(height: 2),
                  Text(itemName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(location, style: const TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: conditionColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      condition,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: conditionColor),
                    ),
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