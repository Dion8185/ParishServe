import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../models/pos_item_model.dart';
import '../../services/particulars_service.dart';
import '../../services/secretary_service.dart';
import 'manage_particulars_dialog.dart';
import 'receipt_detail_dialog.dart';
import '../../../asset_inventory/presentation/widgets/asset_loading_overlay.dart';

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

      final lineDetails =
          '• $serviceTitle x1\n  @ ₱${parsedAmount.toStringAsFixed(2)} = ₱${parsedAmount.toStringAsFixed(2)}';
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
    final screenSize = MediaQuery.of(context).size;

    return AssetLoadingOverlay(
      isLoading: _isLoadingParticulars || _isSaving,
      message: _isLoadingParticulars ? 'Loading particulars...' : 'Saving transaction...',
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cardWhite,
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.oliveGreenSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long, color: ParishColors.oliveGreen, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Record Parish Receipt',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.2),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 22),
              tooltip: 'Close',
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: screenSize.height * 0.74,
          ),
          child: SizedBox(
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
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: ParishColors.mercyRedSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ParishColors.mercyRed.withOpacity(0.5)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),

                    // Payor Name (Floating Label)
                    TextFormField(
                      controller: _payorNameController,
                      inputFormatters: [_TitleCaseInputFormatter()],
                      validator: (v) => (v?.trim().isEmpty ?? true) ? 'Payor name is required' : null,
                      style: TextStyle(fontSize: 14.5, color: textDark),
                      decoration: _inputDecoration(
                        labelText: 'Payor / Parishioner Name *',
                        prefixIcon: const Icon(Icons.person_outline, size: 19, color: ParishColors.marianBlue),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Contact & Receipt Date (Responsive, Floating Labels)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final contactField = TextFormField(
                          controller: _payorContactController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _PhilippinePhoneInputFormatter(),
                          ],
                          style: TextStyle(fontSize: 14.5, color: textDark),
                          decoration: _inputDecoration(
                            labelText: 'Contact Number (Optional)',
                            prefixIcon: const Icon(Icons.phone_outlined, size: 19, color: ParishColors.marianBlue),
                          ),
                        );

                        final dateField = InkWell(
                          onTap: _pickTransactionDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: _inputDecoration(
                              labelText: 'Receipt Date *',
                              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: ParishColors.marianBlue),
                            ),
                            child: Text(
                              _transactionDate.toIso8601String().substring(0, 10),
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );

                        if (constraints.maxWidth < 400) {
                          return Column(
                            children: [
                              contactField,
                              const SizedBox(height: 14),
                              dateField,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: contactField),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: dateField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Manage Catalog Action Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: _openManageParticulars,
                        icon: const Icon(Icons.tune, size: 15, color: ParishColors.marianBlue),
                        label: const Text(
                          'Manage Catalog',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.marianBlue),
                        ),
                      ),
                    ),

                    // Particulars Dropdown (Floating Label)
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
                                  style: const TextStyle(fontSize: 13.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _onParticularSelected,
                      decoration: _inputDecoration(labelText: 'Particulars / Offering Service *'),
                    ),
                    const SizedBox(height: 14),

                    // Amount Field (Floating Label)
                    TextFormField(
                      controller: _amountController,
                      enabled: _paymentCategory != 'Gratis',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: textDark),
                      decoration: _inputDecoration(
                        labelText: 'Amount (PHP) *',
                        prefixText: '₱ ',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Type Segmented Control (HIG-style)
                    Text(
                      'Payment Type',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderGrey),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _paymentCategory = 'Cash'),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: _paymentCategory == 'Cash' ? ParishColors.marianBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.payments_outlined, size: 15, color: _paymentCategory == 'Cash' ? Colors.white : textDark),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Cash / Online',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _paymentCategory == 'Cash' ? Colors.white : textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _paymentCategory = 'Cheque'),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: _paymentCategory == 'Cheque' ? const Color(0xFF6D28D9) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.fact_check_outlined, size: 15, color: _paymentCategory == 'Cheque' ? Colors.white : textDark),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Cheque',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _paymentCategory == 'Cheque' ? Colors.white : textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _paymentCategory = 'Gratis'),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: _paymentCategory == 'Gratis' ? ParishColors.goldAccent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.volunteer_activism_outlined, size: 15, color: _paymentCategory == 'Gratis' ? Colors.white : textDark),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Gratis',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _paymentCategory == 'Gratis' ? Colors.white : textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cash sub-types: Physical Cash vs Online (GCash) using Wrap to prevent overflow
                    if (_paymentCategory == 'Cash') ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Physical Cash'),
                            selected: _cashSubtype == 'Physical',
                            selectedColor: ParishColors.oliveGreen,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _cashSubtype == 'Physical' ? Colors.white : textDark,
                            ),
                            onSelected: (_) => setState(() => _cashSubtype = 'Physical'),
                          ),
                          ChoiceChip(
                            label: const Text('Online (GCash / E-Wallet)'),
                            selected: _cashSubtype == 'Online',
                            selectedColor: const Color(0xFF005CEE),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _cashSubtype == 'Online' ? Colors.white : textDark,
                            ),
                            onSelected: (_) => setState(() => _cashSubtype = 'Online'),
                          ),
                        ],
                      ),
                      if (_cashSubtype == 'Online') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _onlineRefController,
                          validator: (v) => _cashSubtype == 'Online' && (v?.trim().isEmpty ?? true)
                              ? 'Online reference number is required'
                              : null,
                          style: TextStyle(fontSize: 14, color: textDark),
                          decoration: _inputDecoration(
                            labelText: 'GCash / Online Reference Number *',
                            prefixIcon: const Icon(Icons.tag, size: 18, color: Color(0xFF005CEE)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                    ],

                    // Cheque inputs: Bank Name & Cheque Number (Floating Labels)
                    if (_paymentCategory == 'Cheque') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.fact_check, size: 16, color: Color(0xFF6D28D9)),
                                SizedBox(width: 6),
                                Text(
                                  'Cheque Payment Details',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
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
                                  style: TextStyle(fontSize: 14, color: textDark),
                                  decoration: _inputDecoration(labelText: 'Issuing Bank Name *'),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _chequeNumberController,
                              validator: (v) => _paymentCategory == 'Cheque' && (v?.trim().isEmpty ?? true)
                                  ? 'Cheque number is required'
                                  : null,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
                              decoration: _inputDecoration(labelText: 'Cheque Number *'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Taller Particulars / Notes / Remarks Field (Floating Label Only)
                    TextFormField(
                      controller: _detailsController,
                      minLines: 3,
                      maxLines: 5,
                      style: TextStyle(fontSize: 14, color: textDark, height: 1.4),
                      decoration: _inputDecoration(
                        labelText: 'Particulars / Remarks / Notes',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(88, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.oliveGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(130, 44),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSaving ? null : _submitTransaction,
            icon: const Icon(Icons.check, size: 18),
            label: Text(
              _isSaving ? 'Issuing...' : 'Issue Receipt',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    Widget? prefixIcon,
    String? prefixText,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      alignLabelWithHint: alignLabelWithHint,
      labelStyle: TextStyle(fontSize: 13.5, color: ParishColors.textMuted),
      floatingLabelStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: ParishColors.marianBlue,
      ),
      prefixIcon: prefixIcon,
      prefixText: prefixText,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.6),
      ),
    );
  }
}