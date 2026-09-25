import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/receipt_template_model.dart';
import '../../services/receipt_pdf_generator.dart';
import '../../services/receipt_template_service.dart';
import '../pages/receipt_template_management_page.dart';

void showReceiptDetailModal(
    BuildContext context, {
      required String receiptNo,
      required String payer,
      required String purpose,
      required String amount,
      required String date,
      String? payorContact,
      String? transactionDetails,
      String paymentMode = 'Cash',
    }) {
  showDialog(
    context: context,
    builder: (ctx) => _ReceiptDetailDialog(
      receiptNo: receiptNo,
      payer: payer,
      purpose: purpose,
      amount: amount,
      date: date,
      payorContact: payorContact,
      transactionDetails: transactionDetails,
      paymentMode: paymentMode,
    ),
  );
}

class _ReceiptDetailDialog extends StatefulWidget {
  final String receiptNo;
  final String payer;
  final String purpose;
  final String amount;
  final String date;
  final String? payorContact;
  final String? transactionDetails;
  final String paymentMode;

  const _ReceiptDetailDialog({
    required this.receiptNo,
    required this.payer,
    required this.purpose,
    required this.amount,
    required this.date,
    this.payorContact,
    this.transactionDetails,
    this.paymentMode = 'Cash',
  });

  @override
  State<_ReceiptDetailDialog> createState() => _ReceiptDetailDialogState();
}

class _ItemizedLine {
  final String title;
  final String rateInfo;
  final String itemAmount;

  const _ItemizedLine({
    required this.title,
    required this.rateInfo,
    required this.itemAmount,
  });
}

class _ReceiptDetailDialogState extends State<_ReceiptDetailDialog> {
  bool _isPrinting = false;
  List<ReceiptTemplateModel> _templates = [];
  ReceiptTemplateModel? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await ReceiptTemplateService.getAllTemplates();
      if (!mounted) return;
      setState(() {
        _templates = list;
        if (list.isNotEmpty) {
          _selectedTemplate = list.firstWhere((t) => t.isDefault, orElse: () => list.first);
        }
      });
    } catch (_) {}
  }

  double get _numericAmount {
    final clean = widget.amount.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  String get _displayPaymentMode {
    final lower = widget.paymentMode.toLowerCase();
    if (lower == 'cash' || lower.contains('cash')) return 'Cash';
    if (lower == 'gcash' || lower.contains('gcash')) return 'GCash';
    if (lower == 'gratis' || lower.contains('gratis')) return 'Gratis';

    final details = widget.transactionDetails?.toLowerCase() ?? '';
    if (details.contains('tender mode: gcash') || details.contains('gcash ref')) return 'GCash';
    if (details.contains('tender mode: gratis')) return 'Gratis';
    return 'Cash';
  }

  /// Parses the stored transaction_details text into itemized rows with individual amounts
  (List<_ItemizedLine>, String?) _parseLineItems() {
    final text = widget.transactionDetails;
    if (text == null || text.trim().isEmpty) {
      return (
      [_ItemizedLine(title: widget.purpose, rateInfo: '', itemAmount: 'P ${_numericAmount.toStringAsFixed(2)}')],
      null
      );
    }

    final rawLines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final List<_ItemizedLine> items = [];
    final List<String> notes = [];

    for (final raw in rawLines) {
      final clean = raw.replaceAll('•', '').replaceAll('-', '').trim();

      // Check if it's an item line containing pricing information (e.g. '@ 150.00 = 150.00')
      if (clean.contains('@') && clean.contains('=')) {
        final parts = clean.split('=');
        final leftSide = parts[0].trim();
        final rightAmount = parts.length > 1 ? parts[1].trim() : '';

        // Extract title and rate
        final atParts = leftSide.split('@');
        final title = atParts[0].trim();
        final rate = atParts.length > 1 ? '@ ${atParts[1].trim()}' : '';

        final formattedAmt = rightAmount.startsWith('P') ? rightAmount : 'P $rightAmount';
        items.add(_ItemizedLine(title: title, rateInfo: rate, itemAmount: formattedAmt));
      } else if (clean.startsWith('Remarks:') || clean.startsWith('GCash Ref:') || clean.startsWith('Tender:')) {
        notes.add(clean);
      } else if (!clean.toLowerCase().contains('cash tendered')) {
        // General text item
        items.add(_ItemizedLine(title: clean, rateInfo: '', itemAmount: ''));
      }
    }

    if (items.isEmpty) {
      items.add(_ItemizedLine(title: widget.purpose, rateInfo: '', itemAmount: 'P ${_numericAmount.toStringAsFixed(2)}'));
    }

    final combinedNotes = notes.isNotEmpty ? notes.join(' | ') : null;
    return (items, combinedNotes);
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);
    try {
      await ReceiptPdfGenerator.printReceipt(
        receiptNumber: widget.receiptNo,
        payorName: widget.payer,
        payorContact: widget.payorContact,
        relatedService: widget.purpose,
        transactionDetails: widget.transactionDetails ?? widget.purpose,
        amount: _numericAmount,
        paymentMode: _displayPaymentMode,
        dateString: widget.date,
        template: _selectedTemplate,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: ParishColors.mercyRed),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColorMuted = ParishColors.textMuted;
    final textDark = ParishColors.textDark;
    final parsed = _parseLineItems();
    final itemizedList = parsed.$1;
    final notes = parsed.$2;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: ParishColors.cardWhite,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ParishColors.oliveGreenSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: ParishColors.oliveGreen, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Parish Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.receiptNo,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PAYOR:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColorMuted)),
            Text(widget.payer, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
            if (widget.payorContact != null && widget.payorContact!.isNotEmpty)
              Text('Contact: ${widget.payorContact}', style: TextStyle(fontSize: 12, color: textColorMuted)),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date Issued:', style: TextStyle(fontSize: 12.5, color: textColorMuted)),
                Text(widget.date, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment Mode:', style: TextStyle(fontSize: 12.5, color: textColorMuted)),
                Text(_displayPaymentMode.toUpperCase(), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark)),
              ],
            ),
            const Divider(height: 20),

            // Itemized Particulars Box with individual amounts per item
            Text('ITEMIZED PARTICULARS & OFFERINGS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColorMuted)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ITEM DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColorMuted)),
                      Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColorMuted)),
                    ],
                  ),
                  const Divider(height: 14),
                  ...itemizedList.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDark),
                                ),
                                if (item.rateInfo.isNotEmpty)
                                  Text(
                                    item.rateInfo,
                                    style: TextStyle(fontSize: 11, color: textColorMuted),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            item.itemAmount,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (notes != null) ...[
                    const Divider(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        notes,
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: textColorMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ParishColors.oliveGreenSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount Paid:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    'P ${_numericAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Print Template:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                TextButton(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReceiptTemplateManagementPage()),
                    ).then((_) => _loadTemplates());
                  },
                  child: const Text('Manage Templates', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (_templates.isNotEmpty)
              DropdownButtonFormField<ReceiptTemplateModel>(
                value: _selectedTemplate,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                items: _templates.map((tpl) {
                  return DropdownMenuItem(
                    value: tpl,
                    child: Text(
                      '${tpl.templateName} (${tpl.paperSize})',
                      style: const TextStyle(fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTemplate = val);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: textColorMuted)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isPrinting ? null : _handlePrint,
          icon: _isPrinting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.print, size: 18),
          label: Text(_isPrinting ? 'Printing...' : 'Print Official Receipt'),
        ),
      ],
    );
  }
}