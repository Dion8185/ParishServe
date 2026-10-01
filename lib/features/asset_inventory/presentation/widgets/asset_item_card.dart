import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_model.dart';
import '../dialogs/asset_detail_dialog.dart';

class AssetItemCard extends StatelessWidget {
  final AssetModel asset;
  final VoidCallback? onRefresh;

  const AssetItemCard({
    super.key,
    required this.asset,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    final conditionColor = asset.conditionColor;
    final conditionSurface = asset.conditionSurfaceColor;
    final isDecommissioned =
        asset.operationalStatus.trim().toLowerCase() == 'decommissioned';
    final isArchived = asset.isArchived || isDecommissioned;

    return InkWell(
      onTap: () => showAssetDetailModal(
        context,
        asset: asset,
        onAssetUpdated: onRefresh,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isArchived
                ? ParishColors.mercyRed.withValues(alpha: 0.4)
                : borderGrey,
            width: isArchived ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Photo or Classification Emblem
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: asset.photoUrl != null
                    ? Colors.transparent
                    : ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: ParishColors.marianBlue.withValues(alpha: 0.25)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: asset.photoUrl != null && asset.photoUrl!.isNotEmpty
                    ? Image.network(
                  asset.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    asset.classificationIcon,
                    color: ParishColors.marianBlue,
                    size: 24,
                  ),
                )
                    : Icon(
                  asset.classificationIcon,
                  color: ParishColors.marianBlue,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Center: Clear Hierarchy Particulars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Control Number + Condition Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            asset.controlNumber,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.marianBlue,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (isArchived) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: ParishColors.mercyRedSurface,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'ARCHIVED',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: ParishColors.mercyRed,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: conditionSurface,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: conditionColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          asset.conditionStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: conditionColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Row 2: Prominent Asset Name
                  Text(
                    asset.itemName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Row 3: Category & Location
                  Text(
                    '${asset.displayClassification} • ${asset.displayLocation}',
                    style: TextStyle(fontSize: 11.5, color: textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),

                  // Row 4: Compact Badges (Section, Price, Acquisition, RFID)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Section Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: asset.unitPrice >= 10000.0
                              ? ParishColors.goldLight
                              : ParishColors.marianBlueSurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: asset.unitPrice >= 10000.0
                                ? ParishColors.goldAccent
                                : ParishColors.marianBlue,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          asset.inventorySectionCode,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: asset.unitPrice >= 10000.0
                                ? ParishColors.goldAccent
                                : ParishColors.marianBlue,
                          ),
                        ),
                      ),

                      // Acquisition Year & Mode
                      Text(
                        'Acq: ${asset.acquisitionYear} (${asset.modeOfAcquisition})',
                        style: TextStyle(
                            fontSize: 11,
                            color: textMuted,
                            fontWeight: FontWeight.w500),
                      ),

                      // Unit Price
                      if (asset.unitPrice > 0)
                        Text(
                          '•  ${asset.formattedUnitPrice}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.oliveGreen,
                          ),
                        ),

                      // NFC Tag Indicator
                      if (asset.rfidTag != null && asset.rfidTag!.isNotEmpty)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('• ',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Icon(Icons.nfc,
                                size: 12, color: ParishColors.goldAccent),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),

            // Right: Navigation Arrow
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(Icons.chevron_right, color: borderGrey, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}