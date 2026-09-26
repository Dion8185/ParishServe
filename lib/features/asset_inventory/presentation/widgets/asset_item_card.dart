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

    return InkWell(
      onTap: () => showAssetDetailModal(
        context,
        asset: asset,
        onAssetUpdated: onRefresh,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: asset.isArchived ? ParishColors.mercyRed.withValues(alpha: 0.5) : borderGrey,
            width: asset.isArchived ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Photo or Classification Emblem Icon
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: asset.photoUrl != null ? Colors.transparent : ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: asset.photoUrl != null && asset.photoUrl!.isNotEmpty
                    ? Image.network(
                  asset.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    asset.classificationIcon,
                    color: ParishColors.marianBlue,
                    size: 28,
                  ),
                )
                    : Icon(
                  asset.classificationIcon,
                  color: ParishColors.marianBlue,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Complete Diocesan Particulars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Coordinate Bar: Diocesan Control Number & Condition Pill
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
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (asset.isArchived) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: ParishColors.mercyRedSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ARCHIVED',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: ParishColors.mercyRed,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: conditionSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: conditionColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          asset.conditionStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: conditionColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Item Designation / Name
                  Text(
                    asset.itemName,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Classification & Location Line
                  Row(
                    children: [
                      Icon(Icons.category_outlined, size: 13, color: textMuted),
                      const SizedBox(width: 4),
                      Text(
                        asset.displayClassification,
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.location_on_outlined, size: 13, color: textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          asset.displayLocation,
                          style: TextStyle(fontSize: 12, color: textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Acquisition Year, Value & Physical Tag Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Text(
                          'Acquired: ${asset.acquisitionYear} (${asset.modeOfAcquisition})',
                          style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (asset.cost > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ParishColors.oliveGreenSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '₱ ${asset.cost.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.oliveGreen,
                            ),
                          ),
                        ),
                      if (asset.rfidTag != null && asset.rfidTag!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ParishColors.goldLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: ParishColors.goldAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.nfc, size: 11, color: ParishColors.goldAccent),
                              SizedBox(width: 3),
                              Text(
                                'NFC/RFID Tagged',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: ParishColors.goldAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Detail Navigation Indicator
            Icon(Icons.chevron_right, color: borderGrey, size: 20),
          ],
        ),
      ),
    );
  }
}