// =============================================================================
// FILE: lib/features/asset_inventory/presentation/widgets/asset_item_card.dart
// =============================================================================

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
    final isDecommissioned = asset.operationalStatus.trim().toLowerCase() == 'decommissioned';
    final isArchived = asset.isArchived || isDecommissioned;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: InkWell(
        onTap: () => showAssetDetailModal(
          context,
          asset: asset,
          onAssetUpdated: onRefresh,
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: asset.photoUrl != null
                      ? Colors.transparent
                      : ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.25)),
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
                      size: 22,
                    ),
                  )
                      : Icon(
                    asset.classificationIcon,
                    color: ParishColors.marianBlue,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Control Number, Quantity Tag & Condition Pill
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                asset.controlNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ParishColors.marianBlue,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (asset.quantity > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: ParishColors.marianBlueSurface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${asset.quantity} units',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.marianBlue,
                                    ),
                                  ),
                                ),
                              if (isArchived)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: ParishColors.mercyRedSurface,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    'ARCHIVED',
                                    style: TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.mercyRed,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: conditionSurface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: conditionColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            asset.conditionStatus.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: conditionColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      asset.itemName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${asset.displayClassification} • ${asset.displayLocation}',
                      style: TextStyle(fontSize: 11, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: asset.unitPrice >= 10000.0
                                ? ParishColors.goldLight
                                : ParishColors.marianBlueSurface,
                            borderRadius: BorderRadius.circular(3),
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
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: asset.unitPrice >= 10000.0
                                  ? ParishColors.goldAccent
                                  : ParishColors.marianBlue,
                            ),
                          ),
                        ),
                        Text(
                          'Acq: ${asset.acquisitionYear}',
                          style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.w500),
                        ),
                        if (asset.quantity > 1)
                          Text(
                            '•  Unit: ${asset.formattedUnitPrice}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        Text(
                          '•  Total: ${asset.formattedTotalCost}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.oliveGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(Icons.chevron_right, color: borderGrey, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}