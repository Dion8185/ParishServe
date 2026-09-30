import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class ReceiptCard extends StatelessWidget {
  final String receiptNo;
  final String payer;
  final String purpose;
  final String amount;
  final String date;
  final String status;
  final String? payorContact;
  final String? transactionDetails;
  final String paymentMode;
  final bool isVoided;
  final String? transactionId;
  final VoidCallback? onTap;

  const ReceiptCard({
    super.key,
    required this.receiptNo,
    required this.payer,
    required this.purpose,
    required this.amount,
    required this.date,
    required this.status,
    this.payorContact,
    this.transactionDetails,
    this.paymentMode = 'Cash',
    this.isVoided = false,
    this.transactionId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    Color tenderColor = ParishColors.oliveGreen;
    if (paymentMode.toLowerCase().contains('gcash')) {
      tenderColor = const Color(0xFF005CEE);
    } else if (paymentMode.toLowerCase().contains('gratis')) {
      tenderColor = ParishColors.goldAccent;
    }

    Color statusColor = isVoided ? ParishColors.mercyRed : ParishColors.oliveGreen;
    if (!isVoided && status.toLowerCase().contains('pending')) {
      statusColor = ParishColors.goldAccent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isVoided ? const Color(0xFFFEF2F2) : cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isVoided ? ParishColors.mercyRed : borderGrey,
            width: isVoided ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isVoided
                    ? ParishColors.mercyRedSurface
                    : tenderColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isVoided ? Icons.block : Icons.receipt_long,
                color: isVoided ? ParishColors.mercyRed : tenderColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            receiptNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: ParishColors.marianBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isVoided
                                  ? ParishColors.mercyRedSurface
                                  : tenderColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isVoided
                                    ? ParishColors.mercyRed.withOpacity(0.4)
                                    : tenderColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              isVoided ? 'VOIDED' : paymentMode.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isVoided ? ParishColors.mercyRed : tenderColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        amount,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isVoided ? ParishColors.mercyRed : textDark,
                          decoration: isVoided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    payer,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                      decoration: isVoided ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    purpose,
                    style: TextStyle(fontSize: 13, color: textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 13, color: textMuted),
                          const SizedBox(width: 4),
                          Text(date, style: TextStyle(fontSize: 12, color: textMuted)),
                          if (payorContact != null && payorContact!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.phone_outlined, size: 13, color: textMuted),
                            const SizedBox(width: 4),
                            Text(payorContact!, style: TextStyle(fontSize: 12, color: textMuted)),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isVoided ? 'VOID' : status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
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