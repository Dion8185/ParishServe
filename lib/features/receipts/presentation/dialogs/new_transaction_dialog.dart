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
    if (digitsOnly.length > 11) return oldValue;

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

  // Payment type selection: 'Cash', 'Cheque', 'Gratis'
  String _paymentCategory = 'Cash';
  String _cashSubtype = 'Physical'; // 'Physical', 'Online'
  final _onlineRefController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _chequeNumberController = TextEditingController();

  DateTime _transactionDate = DateTime.now();

  List<PosItemModel> _availableParticulars = [];
  PosItemModel? _selectedParticular;
  bool _isLoadingParticulars = true;

  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _commonBanks = [
    'BDO Unibank',
    'BPI (Bank of the Philippine Islands)',
    'Metrobank',
    'Land Bank of the Philippines',
    'China Bank',
    'RCBC',
    'Security Bank',
    'UnionBank',
    'PNB',
    'Other / Rural Bank',
  ];

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

  Future<void> _pickTransactionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _transactionDate = picked);
    }
  }

  @override
  void dispose() {
    _payorNameController.dispose();
    _payorContactController.dispose();
    _amountController.dispose();
    _detailsController.dispose();
    _onlineRefController.dispose();
    _bankNameController.dispose();
    _chequeNumberController.dispose();
    super.dispose();
  }

  String get _resolvedPaymentMode {
    if (_paymentCategory == 'Cheque') return 'Cheque';
    if (_paymentCategory == 'Gratis') return 'Gratis';
    return _cashSubtype == 'Online' ? 'GCash' : 'Cash';
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
    if (_paymentCategory != 'Gratis' && parsedAmount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final serviceTitle = _selectedParticular?.title ?? 'Parish Offering';
      final notes = _detailsController.text.trim();

      final lineDetails = '• $serviceTitle x1\n  @ ₱${parsedAmount.toStringAsFixed(2)} = ₱${parsedAmount.toStringAsFixed(2)}';
      final detailsBuffer = StringBuffer(lineDetails);

      if (notes.isNotEmpty) {
        detailsBuffer.write('\nRemarks: $notes');
      }

      // Append tender metadata for receipt display and audit
      if (_paymentCategory == 'Cheque') {
        detailsBuffer.write('\nTender Mode: Cheque');
        detailsBuffer.write('\nBank Name: ${_bankNameController.text.trim()}');
        detailsBuffer.write('\nCheque No.: ${_chequeNumberController.text.trim()}');
      } else if (_paymentCategory == 'Cash' && _cashSubtype == 'Online') {
        detailsBuffer.write('\nTender Mode: GCash');
        final ref = _onlineRefController.text.trim();
        if (ref.isNotEmpty) detailsBuffer.write('\nGCash Ref: $ref');
      } else if (_paymentCategory == 'Gratis') {
        detailsBuffer.write('\nTender Mode: Gratis');
      } else {
        detailsBuffer.write('\nTender Mode: Cash');
      }

      final effectiveAmount = _paymentCategory == 'Gratis' ? 0.00 : parsedAmount;

      final record = await SecretaryService.createTransaction(
        payorName: _payorNameController.text.trim(),
        payorContact: _payorContactController.text.trim(),
        relatedService: serviceTitle,
        transactionDetails: detailsBuffer.toString(),
        transactionAmount: effectiveAmount,
        transactionType: _resolveTransactionTypeCategory(),
        transactionDate: _transactionDate,
        paymentMode: _resolvedPaymentMode,
        bankName: _paymentCategory == 'Cheque' ? _bankNameController.text.trim() : null,
        chequeNumber: _paymentCategory == 'Cheque' ? _chequeNumberController.text.trim() : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onTransactionSaved?.call();

      showReceiptDetailModal(
        context,
        receiptNo: record['receipt_number'] ?? 'REC-XXXX',
        payer: record['payor_name'] ?? _payorNameController.text.trim(),
        purpose: record['related_service'] ?? serviceTitle,
        amount: '₱ ${effectiveAmount.toStringAsFixed(2)}',
        date: _transactionDate.toIso8601String().substring(0, 10),
        payorContact: record['payor_contact'],
        transactionDetails: record['transaction_details'],
        paymentMode: _resolvedPaymentMode,
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
    final borderGrey = ParishColors.borderGrey;

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

                // Payor Name
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

                // Contact & Date Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Receipt Date *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickTransactionDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: ParishColors.backgroundLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderGrey),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _transactionDate.toIso8601String().substring(0, 10),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                                  ),
                                  const Icon(Icons.calendar_today, size: 16, color: ParishColors.marianBlue),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Particulars Dropdown
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

                // Amount Field
                Text('Amount (PHP) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  enabled: _paymentCategory != 'Gratis',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                  decoration: _inputDecoration(hint: '0.00'),
                ),
                const SizedBox(height: 14),

                // =============================================================
                // Payment Type: Cash (Physical & Online) vs Cheque
                // =============================================================
                Text('Payment Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: ParishColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderGrey),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _paymentCategory = 'Cash'),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _paymentCategory == 'Cash' ? ParishColors.marianBlue : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, size: 16, color: _paymentCategory == 'Cash' ? Colors.white : textDark),
                                const SizedBox(width: 6),
                                Text(
                                  'Cash (Cash / Online)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _paymentCategory == 'Cash' ? Colors.white : textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _paymentCategory = 'Cheque'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _paymentCategory == 'Cheque' ? const Color(0xFF6D28D9) : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fact_check_outlined, size: 16, color: _paymentCategory == 'Cheque' ? Colors.white : textDark),
                                const SizedBox(width: 6),
                                Text(
                                  'Cheque',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _paymentCategory == 'Cheque' ? Colors.white : textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _paymentCategory = 'Gratis'),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _paymentCategory == 'Gratis' ? ParishColors.goldAccent : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.volunteer_activism_outlined, size: 16, color: _paymentCategory == 'Gratis' ? Colors.white : textDark),
                                const SizedBox(width: 6),
                                Text(
                                  'Gratis',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _paymentCategory == 'Gratis' ? Colors.white : textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Cash sub-types: Physical Cash vs Online (GCash)
                if (_paymentCategory == 'Cash') ...[
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Physical Cash (Over-the-Counter)'),
                        selected: _cashSubtype == 'Physical',
                        selectedColor: ParishColors.oliveGreen,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _cashSubtype == 'Physical' ? Colors.white : textDark,
                        ),
                        onSelected: (_) => setState(() => _cashSubtype = 'Physical'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Online (GCash / E-Wallet)'),
                        selected: _cashSubtype == 'Online',
                        selectedColor: const Color(0xFF005CEE),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _cashSubtype == 'Online' ? Colors.white : textDark,
                        ),
                        onSelected: (_) => setState(() => _cashSubtype = 'Online'),
                      ),
                    ],
                  ),
                  if (_cashSubtype == 'Online') ...[
                    const SizedBox(height: 10),
                    Text('GCash / Online Reference Number *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _onlineRefController,
                      validator: (v) => _cashSubtype == 'Online' && (v?.trim().isEmpty ?? true)
                          ? 'Online reference number is required'
                          : null,
                      style: TextStyle(fontSize: 13, color: textDark),
                      decoration: _inputDecoration(hint: 'e.g. 1002 9847 1120'),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],

                // Cheque inputs: Bank Name & Cheque Number
                if (_paymentCategory == 'Cheque') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.fact_check, size: 16, color: Color(0xFF6D28D9)),
                            SizedBox(width: 6),
                            Text('Cheque Payment Details', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9))),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Text('Issuing Bank Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 4),
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) return _commonBanks;
                            return _commonBanks.where((b) => b.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (String selection) {
                            _bankNameController.text = selection;
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            if (_bankNameController.text.isNotEmpty && controller.text.isEmpty) {
                              controller.text = _bankNameController.text;
                            }
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              validator: (v) => _paymentCategory == 'Cheque' && (v?.trim().isEmpty ?? true)
                                  ? 'Bank name is required'
                                  : null,
                              onChanged: (val) => _bankNameController.text = val,
                              style: TextStyle(fontSize: 13, color: textDark),
                              decoration: _inputDecoration(hint: 'e.g. BDO, BPI, Landbank'),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        Text('Cheque Number *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _chequeNumberController,
                          validator: (v) => _paymentCategory == 'Cheque' && (v?.trim().isEmpty ?? true)
                              ? 'Cheque number is required'
                              : null,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                          decoration: _inputDecoration(hint: 'e.g. 0001234567'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
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