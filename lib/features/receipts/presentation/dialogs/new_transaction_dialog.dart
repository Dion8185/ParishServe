import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../models/pos_item_model.dart';
import '../../services/particulars_service.dart';
import '../../services/secretary_service.dart';
import 'manage_particulars_dialog.dart';
import 'receipt_detail_dialog.dart';

void showNewTransactionModal(BuildContext context, {VoidCallback? onTransactionSaved}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _NewTransactionDialog(onTransactionSaved: onTransactionSaved),
  );
}

/// Auto-masking phone input formatter for Philippine phone numbers
class _PhilippinePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 11) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      if ((i == 3 || i == 6) && i != digitsOnly.length - 1) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Title case formatter for names
class _TitleCaseInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final words = text.split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');

    return TextEditingValue(
      text: capitalized,
      selection: newValue.selection,
    );
  }
}

class _NewTransactionDialog extends StatefulWidget {
  final VoidCallback? onTransactionSaved;

  const _NewTransactionDialog({this.onTransactionSaved});

  @override
  State<_NewTransactionDialog> createState() => _NewTransactionDialogState();
}

class _NewTransactionDialogState extends State<_NewTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _payorNameController = TextEditingController();
  final _payorContactController = TextEditingController();
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();

  List<PosItemModel> _availableParticulars = [];
  PosItemModel? _selectedParticular;
  bool _isLoadingParticulars = true;

  String _paymentMode = 'Cash';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadParticulars();
  }

  Future<void> _loadParticulars() async {
    setState(() => _isLoadingParticulars = true);
    try {
      final items = await ParticularsService.getParticulars(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _availableParticulars = items;
        if (items.isNotEmpty) {
          _selectedParticular = items.first;
          _amountController.text = _selectedParticular!.defaultPrice.toStringAsFixed(2);
        }
        _isLoadingParticulars = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingParticulars = false);
    }
  }

  void _onParticularSelected(PosItemModel? item) {
    if (item == null) return;
    setState(() {
      _selectedParticular = item;
      _amountController.text = item.defaultPrice.toStringAsFixed(2);
    });
  }

  void _openManageParticulars() {
    showManageParticularsModal(
      context,
      onParticularsUpdated: _loadParticulars,
    );
  }

  @override
  void dispose() {
    _payorNameController.dispose();
    _payorContactController.dispose();
    _amountController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  String _resolveTransactionTypeCategory() {
    if (_selectedParticular == null) return 'donation';
    final category = _selectedParticular!.category.toLowerCase();
    if (category.contains('sacrament')) return 'sacrament';
    if (category.contains('intention')) return 'mass_intention';
    if (category.contains('certificate')) return 'certificate';
    return 'donation';
  }

  Future<void> _submitTransaction() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (_paymentMode != 'Gratis' && parsedAmount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount greater than 0.00.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final serviceTitle = _selectedParticular?.title ?? 'Parish Offering';
      final details = _detailsController.text.trim().isNotEmpty
          ? '${_detailsController.text.trim()} (Tender Mode: $_paymentMode)'
          : '$serviceTitle (Tender Mode: $_paymentMode)';

      final record = await SecretaryService.createTransaction(
        payorName: _payorNameController.text.trim(),
        payorContact: _payorContactController.text.trim(),
        relatedService: serviceTitle,
        transactionDetails: details,
        transactionAmount: _paymentMode == 'Gratis' ? 0.00 : parsedAmount,
        transactionType: _resolveTransactionTypeCategory(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onTransactionSaved?.call();

      showReceiptDetailModal(
        context,
        receiptNo: record['receipt_number'] ?? 'REC-XXXX',
        payer: record['payor_name'] ?? _payorNameController.text.trim(),
        purpose: record['related_service'] ?? serviceTitle,
        amount: '₱ ${(record['transaction_amount'] as num?)?.toStringAsFixed(2) ?? parsedAmount.toStringAsFixed(2)}',
        date: record['transaction_date']?.toString().substring(0, 10) ?? 'Today',
        payorContact: record['payor_contact'],
        transactionDetails: record['transaction_details'],
        paymentMode: _paymentMode,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
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
                child: const Icon(Icons.receipt, color: ParishColors.oliveGreen, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Record Parish Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          IconButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ParishColors.mercyRedSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ParishColors.mercyRed),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],

                Text('Payor / Parishioner Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _payorNameController,
                  inputFormatters: [_TitleCaseInputFormatter()],
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Payor name is required' : null,
                  style: TextStyle(fontSize: 14, color: textDark),
                  decoration: _inputDecoration(hint: 'First Name and Last Name'),
                ),
                const SizedBox(height: 12),

                Text('Contact Number (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _payorContactController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _PhilippinePhoneInputFormatter(),
                  ],
                  style: TextStyle(fontSize: 14, color: textDark),
                  decoration: _inputDecoration(hint: '09XX-XXX-XXXX'),
                ),
                const SizedBox(height: 12),

                // Live Dynamic Particulars Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Particulars / Offering Service *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: _openManageParticulars,
                      icon: const Icon(Icons.edit_note, size: 16, color: ParishColors.marianBlue),
                      label: const Text('Manage Catalog', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (_isLoadingParticulars)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  DropdownButtonFormField<PosItemModel>(
                    value: _selectedParticular,
                    isExpanded: true,
                    items: _availableParticulars.map((item) {
                      return DropdownMenuItem<PosItemModel>(
                        value: item,
                        child: Row(
                          children: [
                            Icon(item.icon, size: 18, color: ParishColors.marianBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.title} (₱ ${item.defaultPrice.toStringAsFixed(0)})',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _onParticularSelected,
                    decoration: _inputDecoration(),
                  ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount (PHP) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                            decoration: _inputDecoration(hint: '0.00'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Mode *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _paymentMode,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'Cash', child: Text('Cash', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'GCash', child: Text('GCash', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Gratis', child: Text('Gratis', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) => setState(() => _paymentMode = val!),
                            decoration: _inputDecoration(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text('Particulars / Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _detailsController,
                  maxLines: 2,
                  style: TextStyle(fontSize: 13, color: textDark),
                  decoration: _inputDecoration(hint: 'Details inscribed on physical receipt'),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textMuted)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.oliveGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : _submitTransaction,
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check, size: 18),
          label: Text(_isSaving ? 'Issuing...' : 'Issue Receipt'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
    );
  }
}