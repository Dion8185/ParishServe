import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/remittance_report_service.dart';
import '../../../asset_inventory/presentation/widgets/asset_loading_overlay.dart';

void showRemittanceReportModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const RemittanceReportDialog(),
  );
}

class RemittanceReportDialog extends StatefulWidget {
  const RemittanceReportDialog({super.key});

  @override
  State<RemittanceReportDialog> createState() => _RemittanceReportDialogState();
}

class _RemittanceReportDialogState extends State<RemittanceReportDialog> {
  RemittancePeriodType _selectedPeriod = RemittancePeriodType.daily;
  DateTime _targetDate = DateTime.now();

  bool _isLoading = false;
  RemittanceReportData? _reportData;
  String? _errorMessage;

  bool _isExportingPdf = false;
  bool _isExportingExcel = false;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await RemittanceReportService.fetchReportData(
        periodType: _selectedPeriod,
        targetDate: _targetDate,
      );
      if (!mounted) return;
      setState(() {
        _reportData = data;
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

  Future<void> _pickDailyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
      _generateReport();
    }
  }

  Future<void> _handlePdfExport() async {
    if (_reportData == null) return;
    setState(() => _isExportingPdf = true);
    try {
      await RemittanceReportService.exportPdf(_reportData!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF Export failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _handleExcelExport() async {
    if (_reportData == null) return;
    setState(() => _isExportingExcel = true);
    try {
      await RemittanceReportService.exportExcel(_reportData!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel Export failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 650;

    return AssetLoadingOverlay(
      isLoading: _isLoading || _isExportingPdf || _isExportingExcel,
      message: _isExportingPdf || _isExportingExcel ? 'Exporting report...' : 'Generating remittance report...',
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cardWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 880,
            maxHeight: screenSize.height * 0.88,
          ),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 16),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: borderGrey)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ParishColors.marianBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assessment_outlined, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parish Remittance & Financial Report',
                            style: TextStyle(
                              fontSize: isMobile ? 15.5 : 17,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Generate and export canonical collection journals (Excludes Voided & Gratis)',
                            style: TextStyle(fontSize: 11.5, color: textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Controls & Period Selector Bar (Responsive)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final segmented = SegmentedButton<RemittancePeriodType>(
                      segments: const [
                        ButtonSegment(
                          value: RemittancePeriodType.daily,
                          label: Text('Daily'),
                          icon: Icon(Icons.today, size: 15),
                        ),
                        ButtonSegment(
                          value: RemittancePeriodType.monthly,
                          label: Text('Monthly'),
                          icon: Icon(Icons.calendar_view_month, size: 15),
                        ),
                        ButtonSegment(
                          value: RemittancePeriodType.yearly,
                          label: Text('Yearly'),
                          icon: Icon(Icons.calendar_today, size: 15),
                        ),
                      ],
                      selected: {_selectedPeriod},
                      onSelectionChanged: (set) {
                        setState(() => _selectedPeriod = set.first);
                        _generateReport();
                      },
                    );

                    if (constraints.maxWidth < 600) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          segmented,
                          const SizedBox(height: 12),
                          _buildPeriodSelectorControls(isMobile: true),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        segmented,
                        const SizedBox(width: 16),
                        Expanded(child: _buildPeriodSelectorControls(isMobile: false)),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),

              // Main Content Area (KPIs + Table)
              Expanded(
                child: _errorMessage != null
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 38, color: ParishColors.mercyRed),
                        const SizedBox(height: 10),
                        Text(
                          'Error generating report: $_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: ParishColors.mercyRed),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _generateReport, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
                    : _reportData == null
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Cards Banner
                      _buildKpiSummaryBanner(_reportData!, isMobile),
                      const SizedBox(height: 14),

                      // Exclusions Note Callout
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 16, color: ParishColors.oliveGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Canonical Exclusions Enforced: Excluded ${_reportData!.excludedVoidCount} voided slip(s) and ${_reportData!.excludedGratisCount} gratis transaction(s). Only valid cash and GCash intake are computed.',
                                style: TextStyle(fontSize: 11.5, color: textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Receipts Table Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Applicable Receipts (${_reportData!.totalCount} Entries)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ParishColors.marianBlueSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _reportData!.periodLabel,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      _buildReportDataTable(_reportData!),
                    ],
                  ),
                ),
              ),

              // Modal Action Footer (Export PDF & Excel, Responsive Wrap)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: borderGrey)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: TextStyle(color: textMuted, fontWeight: FontWeight.w600)),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ParishColors.oliveGreen, width: 1.4),
                            foregroundColor: ParishColors.oliveGreen,
                            minimumSize: const Size(120, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: (_isLoading || _reportData == null || _isExportingExcel) ? null : _handleExcelExport,
                          icon: const Icon(Icons.table_view_outlined, size: 18),
                          label: const Text('Export Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(130, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: (_isLoading || _reportData == null || _isExportingPdf) ? null : _handlePdfExport,
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Export / Print PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelectorControls({required bool isMobile}) {
    final textDark = ParishColors.textDark;

    if (_selectedPeriod == RemittancePeriodType.daily) {
      final y = _targetDate.year;
      final m = _months[_targetDate.month - 1];
      final d = _targetDate.day;

      return InkWell(
        onTap: _pickDailyDate,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: _inputDecoration(
            labelText: 'Target Date',
            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 17, color: ParishColors.marianBlue),
          ),
          child: Text(
            '$m $d, $y',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textDark),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (_selectedPeriod == RemittancePeriodType.monthly) {
      return Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _targetDate.month,
              isDense: true,
              isExpanded: true,
              decoration: _inputDecoration(labelText: 'Month'),
              items: List.generate(12, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(_months[index], style: const TextStyle(fontSize: 13)),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _targetDate = DateTime(_targetDate.year, val, 1));
                  _generateReport();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: DropdownButtonFormField<int>(
              value: _targetDate.year,
              isDense: true,
              decoration: _inputDecoration(labelText: 'Year'),
              items: [2024, 2025, 2026, 2027, 2028].map((y) {
                return DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _targetDate = DateTime(val, _targetDate.month, 1));
                  _generateReport();
                }
              },
            ),
          ),
        ],
      );
    }

    // Yearly
    return SizedBox(
      width: isMobile ? double.infinity : 140,
      child: DropdownButtonFormField<int>(
        value: _targetDate.year,
        isDense: true,
        decoration: _inputDecoration(labelText: 'Target Year'),
        items: [2023, 2024, 2025, 2026, 2027, 2028, 2029].map((y) {
          return DropdownMenuItem(value: y, child: Text('Year $y', style: const TextStyle(fontSize: 13)));
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() => _targetDate = DateTime(val, 1, 1));
            _generateReport();
          }
        },
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
    );
  }

  Widget _buildKpiSummaryBanner(RemittanceReportData data, bool isMobile) {
    if (isMobile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildKpiBlock('Included Slips', '${data.totalCount} slips', ParishColors.textDark)),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                Expanded(child: _buildKpiBlock('Cash Remittance', '₱ ${data.totalCash.toStringAsFixed(2)}', ParishColors.oliveGreen)),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(child: _buildKpiBlock('GCash Remittance', '₱ ${data.totalGCash.toStringAsFixed(2)}', const Color(0xFF005CEE))),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                Expanded(child: _buildKpiBlock('TOTAL REMITTANCE', '₱ ${data.totalRemittance.toStringAsFixed(2)}', ParishColors.marianBlue, isBig: true)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildKpiBlock('Included Receipts', '${data.totalCount} slips', ParishColors.textDark)),
          Expanded(child: _buildKpiBlock('Cash Remittance', '₱ ${data.totalCash.toStringAsFixed(2)}', ParishColors.oliveGreen)),
          Expanded(child: _buildKpiBlock('GCash Remittance', '₱ ${data.totalGCash.toStringAsFixed(2)}', const Color(0xFF005CEE))),
          Expanded(child: _buildKpiBlock('TOTAL REMITTANCE', '₱ ${data.totalRemittance.toStringAsFixed(2)}', ParishColors.marianBlue, isBig: true)),
        ],
      ),
    );
  }

  Widget _buildKpiBlock(String label, String value, Color color, {bool isBig = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: ParishColors.textMuted, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBig ? 17 : 14.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildReportDataTable(RemittanceReportData data) {
    final borderGrey = ParishColors.borderGrey;
    final textDark = ParishColors.textDark;

    if (data.validReceipts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderGrey),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 36, color: ParishColors.textMuted),
            const SizedBox(height: 8),
            Text(
              'No valid receipt transactions recorded for ${data.periodLabel}.',
              style: TextStyle(fontSize: 13, color: textDark, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(ParishColors.marianBlueSurface),
            columnSpacing: 20,
            horizontalMargin: 14,
            columns: const [
              DataColumn(label: Text('Receipt No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Payor Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Particulars / Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Tender', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Amount (PHP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: [
              ...data.validReceipts.map((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(r.receiptNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 12))),
                    DataCell(Text(r.formattedDate, style: const TextStyle(fontSize: 11.5))),
                    DataCell(Text(r.payorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(r.relatedService, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: r.paymentMode == 'GCash' ? const Color(0xFFEFF6FF) : ParishColors.oliveGreenSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.paymentMode.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: r.paymentMode == 'GCash' ? const Color(0xFF005CEE) : ParishColors.oliveGreen,
                        ),
                      ),
                    )),
                    DataCell(Text('₱ ${r.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}