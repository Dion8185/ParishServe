import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
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
  bool _isPrintingThermal = false;
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

  Color get _tenderBadgeColor {
    final mode = _displayPaymentMode.toLowerCase();
    if (mode.contains('gcash')) return const Color(0xFF005CEE);
    if (mode.contains('gratis')) return ParishColors.goldAccent;
    return ParishColors.oliveGreen;
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

      if (clean.contains('@') && clean.contains('=')) {
        final parts = clean.split('=');
        final leftSide = parts[0].trim();
        final rightAmount = parts.length > 1 ? parts[1].trim() : '';

        final atParts = leftSide.split('@');
        final title = atParts[0].trim();
        final rate = atParts.length > 1 ? '@ ${atParts[1].trim()}' : '';

        final formattedAmt = rightAmount.startsWith('P') ? rightAmount : 'P $rightAmount';
        items.add(_ItemizedLine(title: title, rateInfo: rate, itemAmount: formattedAmt));
      } else if (clean.startsWith('Remarks:') || clean.startsWith('GCash Ref:') || clean.startsWith('Tender:')) {
        notes.add(clean);
      } else if (!clean.toLowerCase().contains('cash tendered')) {
        items.add(_ItemizedLine(title: clean, rateInfo: '', itemAmount: ''));
      }
    }

    if (items.isEmpty) {
      items.add(_ItemizedLine(title: widget.purpose, rateInfo: '', itemAmount: 'P ${_numericAmount.toStringAsFixed(2)}'));
    }

    final combinedNotes = notes.isNotEmpty ? notes.join(' | ') : null;
    return (items, combinedNotes);
  }

  Future<void> _handlePrint({bool isThermal = false}) async {
    setState(() {
      if (isThermal) {
        _isPrintingThermal = true;
      } else {
        _isPrinting = true;
      }
    });

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
        isThermalRoll: isThermal,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: ParishColors.mercyRed),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
          _isPrintingThermal = false;
        });
      }
    }
  }

  Future<void> _openPdfPreviewModal({bool isThermal = false}) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isThermal ? '80mm Thermal Receipt Preview' : 'Official Receipt Voucher Preview',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 680,
          height: 560,
          child: PdfPreview(
            build: (format) => ReceiptPdfGenerator.generateReceiptPdf(
              receiptNumber: widget.receiptNo,
              payorName: widget.payer,
              payorContact: widget.payorContact,
              relatedService: widget.purpose,
              transactionDetails: widget.transactionDetails ?? widget.purpose,
              amount: _numericAmount,
              paymentMode: _displayPaymentMode,
              dateString: widget.date,
              template: _selectedTemplate,
              isThermalRoll: isThermal,
            ),
            allowPrinting: true,
            allowSharing: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  void _copyReceiptNumber() {
    Clipboard.setData(ClipboardData(text: widget.receiptNo));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt Number "${widget.receiptNo}" copied to clipboard.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColorMuted = ParishColors.textMuted;
    final textDark = ParishColors.textDark;
    final parsed = _parseLineItems();
    final itemizedList = parsed.$1;
    final notes = parsed.$2;
    final tenderColor = _tenderBadgeColor;

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
                  color: tenderColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long, color: tenderColor, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Parish Receipt Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          InkWell(
            onTap: _copyReceiptNumber,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.receiptNo,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, size: 13, color: ParishColors.marianBlue),
                ],
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payor & Details Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PAYOR / RECIPIENT:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColorMuted)),
                        const SizedBox(height: 2),
                        Text(widget.payer, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                        if (widget.payorContact != null && widget.payorContact!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 12, color: textColorMuted),
                              const SizedBox(width: 4),
                              Text(widget.payorContact!, style: TextStyle(fontSize: 12, color: textColorMuted)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tenderColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tenderColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_displayPaymentMode == 'Cash') Icon(Icons.payments_outlined, size: 14, color: tenderColor),
                        if (_displayPaymentMode == 'GCash') Icon(Icons.qr_code_2, size: 14, color: tenderColor),
                        if (_displayPaymentMode == 'Gratis') Icon(Icons.volunteer_activism, size: 14, color: tenderColor),
                        const SizedBox(width: 5),
                        Text(
                          _displayPaymentMode.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tenderColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transaction Date:', style: TextStyle(fontSize: 12.5, color: textColorMuted)),
                  Text(widget.date, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark)),
                ],
              ),
              const Divider(height: 20),

              // Itemized Particulars Box
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ITEMIZED PARTICULARS & OFFERINGS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColorMuted)),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _openPdfPreviewModal(isThermal: false),
                    icon: const Icon(Icons.picture_as_pdf, size: 15, color: ParishColors.marianBlue),
                    label: const Text('View PDF Layout', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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
                        Text('OFFERING DESCRIPTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColorMuted)),
                        Text('LINE TOTAL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColorMuted)),
                      ],
                    ),
                    const Divider(height: 14),
                    ...itemizedList.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.5),
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

              // Total Amount Paid Card
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

              // Template Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Print Template Configuration:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReceiptTemplateManagementPage()),
                      ).then((_) => _loadTemplates());
                    },
                    child: const Text('Manage Templates', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
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
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: textColorMuted)),
        ),
        // 1. 80mm Thermal Slip Print Option
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: ParishColors.goldAccent, width: 1.2),
            foregroundColor: ParishColors.goldAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: _isPrintingThermal || _isPrinting ? null : () => _handlePrint(isThermal: true),
          icon: _isPrintingThermal
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: ParishColors.goldAccent, strokeWidth: 2))
              : const Icon(Icons.receipt, size: 16),
          label: const Text('80mm Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        ),
        // 2. Standard Official Voucher / Document Print Option
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _isPrinting || _isPrintingThermal ? null : () => _handlePrint(isThermal: false),
          icon: _isPrinting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.print, size: 17),
          label: Text(
            _isPrinting ? 'Printing...' : 'Print Voucher',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}