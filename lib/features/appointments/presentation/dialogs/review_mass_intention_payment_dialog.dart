import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../receipts/presentation/dialogs/receipt_detail_dialog.dart';
import '../../models/mass_intention_model.dart';
import '../../models/payment_reference_model.dart';
import '../../services/mass_intention_service.dart';
import '../../services/payment_reference_service.dart';

void showReviewMassIntentionPaymentModal(
    BuildContext context, {
      required MassIntentionModel intention,
      VoidCallback? onVerified,
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ReviewMassIntentionPaymentDialog(
      intention: intention,
      onVerified: onVerified,
    ),
  );
}

class _ReviewMassIntentionPaymentDialog extends StatefulWidget {
  final MassIntentionModel intention;
  final VoidCallback? onVerified;

  const _ReviewMassIntentionPaymentDialog({
    required this.intention,
    this.onVerified,
  });

  @override
  State<_ReviewMassIntentionPaymentDialog> createState() =>
      _ReviewMassIntentionPaymentDialogState();
}

class _ReviewMassIntentionPaymentDialogState
    extends State<_ReviewMassIntentionPaymentDialog> {
  final _amountController = TextEditingController();
  final _refNumberController = TextEditingController();
  final _rejectionReasonController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;

  PaymentReferenceModel? _matchedReference;
  bool _isSearchingReference = true;

  bool get _isAlreadyApproved =>
      widget.intention.intentionStatus.toLowerCase() == 'confirmed' &&
          widget.intention.verificationStatus.toLowerCase() == 'verified';

  bool get _isAlreadyRejected =>
      widget.intention.intentionStatus.toLowerCase() == 'rejected' ||
          widget.intention.intentionStatus.toLowerCase() == 'cancelled';

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.intention.stipendAmount.toStringAsFixed(2);
    _refNumberController.text = widget.intention.gcashReferenceNo ??
        widget.intention.ocrReferenceNumber ??
        '';

    _counterCheckPaymentReference();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refNumberController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _counterCheckPaymentReference() async {
    setState(() => _isSearchingReference = true);
    final refToMatch = _refNumberController.text.trim();

    if (refToMatch.isNotEmpty) {
      final match = await PaymentReferenceService.findMatchingReference(
        referenceNumber: refToMatch,
        expectedAmount: double.tryParse(_amountController.text.trim()),
      );
      if (mounted) {
        setState(() {
          _matchedReference = match;
          _isSearchingReference = false;
        });
      }
    } else {
      if (mounted) setState(() => _isSearchingReference = false);
    }
  }

  Future<void> _handleApproveAndGenerateReceipt() async {
    setState(() => _errorMessage = null);

    final double enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (enteredAmount <= 0) {
      setState(() => _errorMessage = 'Please confirm a valid stipend amount.');
      return;
    }

    final String confirmedRefNo = _refNumberController.text.trim();
    if (widget.intention.paymentMethod == 'GCash' && confirmedRefNo.isEmpty) {
      setState(() => _errorMessage = 'GCash reference number is required for verification.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final transactionRecord = await MassIntentionService.approveAndVerifyIntention(
        intention: widget.intention,
        verifiedAmount: enteredAmount,
        verifiedRefNumber: confirmedRefNo,
        matchingReferenceId: _matchedReference?.referenceId,
      );

      if (!mounted) return;

      Navigator.pop(context); // Close review dialog
      widget.onVerified?.call();

      // Automatically launch the official receipt voucher
      showReceiptDetailModal(
        context,
        receiptNo: transactionRecord['receipt_number'] ?? 'REC-XXXX',
        payer: transactionRecord['payor_name'] ?? widget.intention.requesterName,
        purpose: transactionRecord['related_service'] ?? 'Mass Intention',
        amount: '₱ ${enteredAmount.toStringAsFixed(2)}',
        date: widget.intention.formattedDate,
        payorContact: widget.intention.contactNumber,
        transactionDetails: transactionRecord['transaction_details'],
        paymentMode: widget.intention.paymentMethod,
        transactionId: transactionRecord['transaction_id'],
        status: 'PAID',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleRejectIntention() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: ParishColors.mercyRed, size: 24),
            SizedBox(width: 8),
            Text('Reject Mass Intention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will mark the Mass intention as REJECTED and auto-archive it. No official receipt will be generated.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                hintText: 'e.g. Unverified GCash payment, invalid screenshot',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (_rejectionReasonController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await MassIntentionService.rejectIntention(
          intentionId: widget.intention.intentionId,
          reason: _rejectionReasonController.text.trim(),
          matchingReferenceId: _matchedReference?.referenceId,
        );

        if (!mounted) return;
        Navigator.pop(context);
        widget.onVerified?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mass intention rejected and archived. No receipt generated.'),
            backgroundColor: ParishColors.mercyRed,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isProcessing = false;
        });
      }
    }
  }

  void _openReceiptImageFullPreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('GCash Receipt Screenshot Inspection',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('Image failed to load.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.intention;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: cardWhite,
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
            child: Column(
              children: [
                // Modal Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                        child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAlreadyApproved
                                  ? 'Mass Intention & Payment (Verified)'
                                  : 'Review & Verify Mass Intention Payment',
                              style: TextStyle(fontSize: isCompact ? 15 : 16.5, fontWeight: FontWeight.bold, color: textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _isAlreadyApproved
                                  ? 'Payment confirmed • Official receipt generated in parish ledger'
                                  : 'Verify payment details before official receipt generation in parish ledger',
                              style: TextStyle(fontSize: 11.5, color: textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isCompact ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: ParishColors.mercyRedSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ParishColors.mercyRed),
                            ),
                            child: Text(_errorMessage!,
                                style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ),
                        ],

                        // Prominent Mass Schedule Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ParishColors.marianBlueSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: ParishColors.marianBlue, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('MASS LITURGICAL SCHEDULE',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue, letterSpacing: 0.5)),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.formattedScheduleDisplay,
                                      style: TextStyle(fontSize: isCompact ? 14 : 15, fontWeight: FontWeight.bold, color: textDark),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.intentionStatus == 'confirmed'
                                      ? ParishColors.oliveGreenSurface
                                      : ParishColors.goldLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.intentionStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.intentionStatus == 'confirmed'
                                        ? ParishColors.oliveGreen
                                        : ParishColors.goldAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Requester Information
                        Text('Requester Information', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ParishColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderGrey),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Requester: ${item.requesterName}',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDark)),
                              const SizedBox(height: 2),
                              Text('Contact: ${item.contactNumber}${item.email != null ? " • ${item.email}" : ""}',
                                  style: TextStyle(fontSize: 12, color: textMuted)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Petitions Preview
                        Text('Intention Petitions (${item.totalIntentionsCount} names)',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ParishColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderGrey),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.thanksgivingList.isNotEmpty)
                                _buildPetitionRow('Thanksgiving:', item.thanksgivingList.join(', ')),
                              if (item.reposeSoulsList.isNotEmpty)
                                _buildPetitionRow('Repose of Souls:', item.reposeSoulsList.join(', ')),
                              if (item.specialIntentionsList.isNotEmpty)
                                _buildPetitionRow('Special Petitions:', item.specialIntentionsList.join(', ')),
                              if (item.otherIntentions != null && item.otherIntentions!.isNotEmpty)
                                _buildPetitionRow('Other Petitions:', item.otherIntentions!),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Payment Verification Card
                        Text('Payment Verification & Bank Reconciliation',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF005CEE).withOpacity(0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Method: ${item.paymentMethod.toUpperCase()}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF005CEE))),
                                  if (_isSearchingReference)
                                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  else if (_matchedReference != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ParishColors.oliveGreenSurface,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('MATCHED PARISH GCASH ENTRY',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ParishColors.goldLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('UNMATCHED REFERENCE',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (isCompact) ...[
                                TextFormField(
                                  controller: _refNumberController,
                                  enabled: !_isAlreadyApproved,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                                  decoration: const InputDecoration(
                                    labelText: 'Verified Reference Number *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => _counterCheckPaymentReference(),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _amountController,
                                  enabled: !_isAlreadyApproved,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                                  decoration: const InputDecoration(
                                    labelText: 'Verified Amount (PHP) *',
                                    prefixText: '₱ ',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _refNumberController,
                                        enabled: !_isAlreadyApproved,
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                                        decoration: const InputDecoration(
                                          labelText: 'Verified Reference Number *',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onChanged: (_) => _counterCheckPaymentReference(),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _amountController,
                                        enabled: !_isAlreadyApproved,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                                        decoration: const InputDecoration(
                                          labelText: 'Verified Amount (PHP) *',
                                          prefixText: '₱ ',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              if (item.ocrReferenceNumber != null || item.ocrAmount != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderGrey),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.document_scanner, size: 16, color: ParishColors.marianBlue),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'OCR Extracted: Ref #${item.ocrReferenceNumber ?? "—"} • ₱ ${(item.ocrAmount ?? 0).toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Screenshot Thumbnail
                              if (item.receiptImageUrl != null && item.receiptImageUrl!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () => _openReceiptImageFullPreview(item.receiptImageUrl!),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderGrey),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.network(
                                            item.receiptImageUrl!,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.receipt, size: 30),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Uploaded GCash Screenshot',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              Text('Tap to inspect full screenshot & details',
                                                  style: TextStyle(fontSize: 11.5, color: textMuted)),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.zoom_in, color: ParishColors.marianBlue),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Modal Action Bar (Responsive, no overflow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: borderGrey)),
                  ),
                  child: _isAlreadyApproved
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ParishColors.oliveGreenSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, size: 15, color: ParishColors.oliveGreen),
                            SizedBox(width: 6),
                            Text('RECEIPT ISSUED & VERIFIED',
                                style: TextStyle(color: ParishColors.oliveGreen, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  )
                      : isCompact
                      ? Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.oliveGreen,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isProcessing ? null : _handleApproveAndGenerateReceipt,
                          icon: _isProcessing
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle, size: 16),
                          label: Text(
                            _isProcessing ? 'Verifying...' : 'Approve & Issue Receipt',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ParishColors.mercyRed,
                                side: const BorderSide(color: ParishColors.mercyRed),
                              ),
                              onPressed: _isProcessing ? null : _handleRejectIntention,
                              child: const Text('Reject (No Receipt)', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _isProcessing ? null : () => Navigator.pop(context),
                            child: Text('Close', style: TextStyle(color: textMuted)),
                          ),
                        ],
                      ),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ParishColors.mercyRed,
                          side: const BorderSide(color: ParishColors.mercyRed),
                        ),
                        onPressed: _isProcessing ? null : _handleRejectIntention,
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Reject (No Receipt)'),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _isProcessing ? null : () => Navigator.pop(context),
                            child: Text('Close', style: TextStyle(color: textMuted)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.oliveGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            ),
                            onPressed: _isProcessing ? null : _handleApproveAndGenerateReceipt,
                            icon: _isProcessing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_circle, size: 18),
                            label: Text(
                              _isProcessing ? 'Verifying...' : 'Approve & Issue Receipt',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
      },
    );
  }

  Widget _buildPetitionRow(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: ParishColors.textDark),
          children: [
            TextSpan(text: '$title ', style:  TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: content, style:  TextStyle(color: ParishColors.textMuted)),
          ],
        ),
      ),
    );
  }
}