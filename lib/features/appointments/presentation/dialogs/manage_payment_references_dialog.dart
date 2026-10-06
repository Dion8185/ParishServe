import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/colors.dart';
import '../../models/payment_reference_model.dart';
import '../../services/parish_payment_settings_service.dart';
import '../../services/payment_reference_service.dart';

void showManagePaymentReferencesModal(BuildContext context, {VoidCallback? onReferencesUpdated}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ManagePaymentReferencesDialog(onReferencesUpdated: onReferencesUpdated),
  );
}

class ManagePaymentReferencesDialog extends StatefulWidget {
  final VoidCallback? onReferencesUpdated;

  const ManagePaymentReferencesDialog({super.key, this.onReferencesUpdated});

  @override
  State<ManagePaymentReferencesDialog> createState() => _ManagePaymentReferencesDialogState();
}

class _ManagePaymentReferencesDialogState extends State<ManagePaymentReferencesDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1. References Ledger State
  List<PaymentReferenceModel> _references = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';

  // 2. GCash Account & QR Settings State
  ParishPaymentSettings _settings = const ParishPaymentSettings();
  bool _isLoadingSettings = true;
  bool _isSavingSettings = false;
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _instructionsController = TextEditingController();
  String? _qrImageUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReferences();
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await PaymentReferenceService.fetchPaymentReferences(
        statusFilter: _selectedStatusFilter == 'All' ? null : _selectedStatusFilter,
        searchQuery: _searchQuery,
      );
      if (!mounted) return;
      setState(() {
        _references = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ParishPaymentSettingsService.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _accountNameController.text = settings.gcashAccountName;
        _accountNumberController.text = settings.gcashAccountNumber;
        _instructionsController.text = settings.paymentInstructions;
        _qrImageUrl = settings.gcashQrCodeUrl;
        _isLoadingSettings = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _saveGcashSettings() async {
    setState(() => _isSavingSettings = true);
    try {
      final updated = _settings.copyWith(
        gcashAccountName: _accountNameController.text.trim(),
        gcashAccountNumber: _accountNumberController.text.trim(),
        paymentInstructions: _instructionsController.text.trim(),
        gcashQrCodeUrl: _qrImageUrl,
      );

      await ParishPaymentSettingsService.updateSettings(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parish GCash details and QR settings updated successfully.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e'), backgroundColor: ParishColors.mercyRed),
      );
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  Future<void> _replaceQrCodeImage() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (file == null) return;
      final bytes = await file.readAsBytes();

      setState(() => _isSavingSettings = true);

      final url = await ParishPaymentSettingsService.uploadGcashQrImage(
        imageBytes: bytes,
        fileExtension: file.extension ?? 'png',
      );

      if (!mounted) return;

      setState(() {
        _qrImageUrl = url;
        _isSavingSettings = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New GCash QR Code uploaded and published to parishioner portal.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingSettings = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  void _openAddReferenceDialog() {
    final refController = TextEditingController();
    final amountController = TextEditingController();
    DateTime pickedDate = DateTime.now();
    bool isSavingRef = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Verified GCash Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dialogError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ParishColors.mercyRedSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ParishColors.mercyRed),
                    ),
                    child: Text(dialogError!,
                        style: const TextStyle(fontSize: 12, color: ParishColors.mercyRed, fontWeight: FontWeight.bold)),
                  ),
                ],
                const Text('Reference Number *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: refController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 1002 9847 1120',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Amount Received (PHP) *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date: ${pickedDate.toIso8601String().substring(0, 10)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: pickedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (d != null) {
                          setModalState(() => pickedDate = d);
                        }
                      },
                      child: const Text('Change Date'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSavingRef ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: isSavingRef
                  ? null
                  : () async {
                final rawRef = refController.text.trim();
                final cleanAmt = amountController.text.replaceAll('₱', '').replaceAll(',', '').trim();
                final amt = double.tryParse(cleanAmt) ?? 0.0;

                if (rawRef.isEmpty) {
                  setModalState(() => dialogError = 'Please enter a valid Reference Number.');
                  return;
                }
                if (amt <= 0) {
                  setModalState(() => dialogError = 'Please enter an amount greater than 0.00.');
                  return;
                }

                setModalState(() {
                  isSavingRef = true;
                  dialogError = null;
                });

                try {
                  await PaymentReferenceService.addPaymentReference(
                    referenceNumber: rawRef,
                    amount: amt,
                    paymentDate: pickedDate,
                    paymentMethod: 'GCash',
                  );

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadReferences();
                  widget.onReferencesUpdated?.call();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reference #$rawRef (₱${amt.toStringAsFixed(2)}) added successfully.'),
                      backgroundColor: ParishColors.oliveGreen,
                    ),
                  );
                } catch (e) {
                  setModalState(() {
                    isSavingRef = false;
                    dialogError = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              },
              child: isSavingRef
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Reference'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCsvImport() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (file == null) return;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);

      final lines = const LineSplitter().convert(content);
      final List<Map<String, dynamic>> parsedList = [];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        if (i == 0 && (line.toLowerCase().contains('ref') || line.toLowerCase().contains('amount'))) continue;

        final parts = line.split(',');
        if (parts.isEmpty) continue;

        parsedList.add({
          'reference_number': parts[0].replaceAll('"', '').trim(),
          'amount': parts.length > 1
              ? double.tryParse(parts[1].replaceAll('"', '').replaceAll('₱', '').replaceAll('P', '').trim()) ?? 0.0
              : 0.0,
          'payment_date': parts.length > 2 ? parts[2].replaceAll('"', '').trim() : DateTime.now().toIso8601String(),
          'payment_method': 'GCash',
        });
      }

      final result = await PaymentReferenceService.bulkImportPaymentReferences(parsedList);

      if (!mounted) return;
      _loadReferences();
      widget.onReferencesUpdated?.call();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Results', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Total parsed: ${result.totalParsed}\n'
                'Successfully inserted: ${result.insertedCount}\n'
                'Duplicates skipped: ${result.duplicateCount}',
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV Import error: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  Future<void> _handleCsvExport() async {
    try {
      final csvData = PaymentReferenceService.exportToCsv(_references);
      final bytes = Uint8List.fromList(utf8.encode(csvData));

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'GCash_Payment_References_${DateTime.now().toIso8601String().substring(0, 10)}.csv',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV Export failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  Future<void> _confirmDeleteReference(PaymentReferenceModel ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reference?'),
        content: Text('Remove reference #${ref.referenceNumber} (${ref.formattedAmount})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PaymentReferenceService.deletePaymentReference(ref.referenceId);
      _loadReferences();
      widget.onReferencesUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 840,
        constraints: const BoxConstraints(maxHeight: 740),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GCash Payment Reconciliation & Settings',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: textDark)),
                        Text('Counter-check bank references and configure parish GCash account QR',
                            style: TextStyle(fontSize: 11.5, color: textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: ParishColors.backgroundLight,
              child: TabBar(
                controller: _tabController,
                labelColor: ParishColors.marianBlue,
                unselectedLabelColor: textMuted,
                indicatorColor: ParishColors.marianBlue,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Bank References Ledger'),
                  Tab(icon: Icon(Icons.qr_code_2, size: 18), text: 'Parish QR Code & Account Settings'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReferencesLedgerTab(),
                  _buildGcashSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: References Ledger Tab
  // ===========================================================================

  Widget _buildReferencesLedgerTab() {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 650;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: isCompact
                  ? Column(
                children: [
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderGrey),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 18, color: ParishColors.marianBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setState(() => _searchQuery = val);
                              _loadReferences();
                            },
                            style: TextStyle(fontSize: 13, color: textDark),
                            decoration: const InputDecoration(
                              hintText: 'Search reference...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatusFilter,
                          isDense: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Status', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'unused', child: Text('Unused', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'used', child: Text('Used', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedStatusFilter = val);
                              _loadReferences();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _handleCsvImport,
                        icon: const Icon(Icons.file_upload_outlined, size: 20),
                        tooltip: 'Import CSV',
                      ),
                      IconButton(
                        onPressed: _references.isEmpty ? null : _handleCsvExport,
                        icon: const Icon(Icons.file_download_outlined, size: 20),
                        tooltip: 'Export CSV',
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.oliveGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: _openAddReferenceDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              )
                  : Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderGrey),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 18, color: ParishColors.marianBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                setState(() => _searchQuery = val);
                                _loadReferences();
                              },
                              style: TextStyle(fontSize: 13, color: textDark),
                              decoration: const InputDecoration(
                                hintText: 'Search reference number...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Status')),
                      DropdownMenuItem(value: 'unused', child: Text('Unused Only')),
                      DropdownMenuItem(value: 'used', child: Text('Used Only')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatusFilter = val);
                        _loadReferences();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _handleCsvImport,
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Import CSV', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: _references.isEmpty ? null : _handleCsvExport,
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.oliveGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _openAddReferenceDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Single', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Table Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _references.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 44, color: borderGrey),
                    const SizedBox(height: 8),
                    Text('No GCash references found.',
                        style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
                    Text('Click "Add Single" or "Import CSV" to upload bank references.',
                        style: TextStyle(color: textMuted, fontSize: 12)),
                  ],
                ),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderGrey),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Reference No.', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Linked Intention', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _references.map((r) {
                        return DataRow(
                          cells: [
                            DataCell(Text(r.referenceNumber,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue))),
                            DataCell(Text(r.formattedAmount,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.oliveGreen))),
                            DataCell(Text(r.formattedDate)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: r.isUsed ? ParishColors.backgroundLight : ParishColors.oliveGreenSurface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  r.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: r.isUsed ? textMuted : ParishColors.oliveGreen,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(r.usedInIntentionId ?? '—')),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: ParishColors.mercyRed),
                                onPressed: r.isUsed ? null : () => _confirmDeleteReference(r),
                                tooltip: 'Delete unused reference',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // TAB 2: Parish QR Code & Account Settings Tab
  // ===========================================================================

  Widget _buildGcashSettingsTab() {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    if (_isLoadingSettings) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 680;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: isCompact
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderGrey, width: 1.5),
                      ),
                      child: _qrImageUrl != null && _qrImageUrl!.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_qrImageUrl!, fit: BoxFit.contain),
                      )
                          : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code, size: 75, color: Color(0xFF005CEE)),
                          Text('PARISH GCASH QR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSavingSettings ? null : _replaceQrCodeImage,
                      icon: const Icon(Icons.upload, size: 16),
                      label: const Text('Replace QR Image', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSettingsFormFields(textDark),
            ],
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderGrey, width: 1.5),
                    ),
                    child: _qrImageUrl != null && _qrImageUrl!.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(_qrImageUrl!, fit: BoxFit.contain),
                    )
                        : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 85, color: Color(0xFF005CEE)),
                        Text('PARISH GCASH QR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSavingSettings ? null : _replaceQrCodeImage,
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Replace QR Image', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(child: _buildSettingsFormFields(textDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsFormFields(Color textDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GCash Registered Account Name *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 6),
        TextField(
          controller: _accountNameController,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        Text('GCash Registered Account Number *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 6),
        TextField(
          controller: _accountNumberController,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005CEE)),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        Text('Parishioner Instructions Text *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 6),
        TextField(
          controller: _instructionsController,
          maxLines: 3,
          style: TextStyle(fontSize: 12.5, color: textDark),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.oliveGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: _isSavingSettings ? null : _saveGcashSettings,
            icon: _isSavingSettings
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save, size: 18),
            label: const Text('Save GCash Info', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}