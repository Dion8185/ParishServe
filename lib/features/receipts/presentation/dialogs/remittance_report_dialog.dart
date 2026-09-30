import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/remittance_report_service.dart';

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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 880,
        constraints: const BoxConstraints(maxHeight: 780),
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
                    child: const Icon(Icons.assessment_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parish Remittance & Financial Report Generator',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          'Generate and export canonical collection journals (Excludes Voided & Gratis)',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
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

            // Controls & Period Selector Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Segmented Buttons: Daily, Monthly, Yearly
                      SegmentedButton<RemittancePeriodType>(
                        segments: const [
                          ButtonSegment(
                            value: RemittancePeriodType.daily,
                            label: Text('Daily'),
                            icon: Icon(Icons.today, size: 16),
                          ),
                          ButtonSegment(
                            value: RemittancePeriodType.monthly,
                            label: Text('Monthly'),
                            icon: Icon(Icons.calendar_view_month, size: 16),
                          ),
                          ButtonSegment(
                            value: RemittancePeriodType.yearly,
                            label: Text('Yearly'),
                            icon: Icon(Icons.calendar_today, size: 16),
                          ),
                        ],
                        selected: {_selectedPeriod},
                        onSelectionChanged: (set) {
                          setState(() => _selectedPeriod = set.first);
                          _generateReport();
                        },
                      ),
                      const SizedBox(width: 16),

                      // Specific Period Controls
                      Expanded(child: _buildPeriodSelectorControls()),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Main Content Area (KPIs + Table)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Cards Banner
                    _buildKpiSummaryBanner(_reportData!),
                    const SizedBox(height: 14),

                    // Exclusions Note Callout
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
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

                    // Receipts Table
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Applicable Receipts (${_reportData!.totalCount} Entries)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          'Reporting Period: ${_reportData!.periodLabel}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _buildReportDataTable(_reportData!),
                  ],
                ),
              ),
            ),

            // Modal Action Footer (Export PDF & Excel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(color: textMuted)),
                  ),
                  Row(
                    children: [
                      // Excel Export Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: ParishColors.oliveGreen, width: 1.5),
                          foregroundColor: ParishColors.oliveGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: (_isLoading || _reportData == null || _isExportingExcel) ? null : _handleExcelExport,
                        icon: _isExportingExcel
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ParishColors.oliveGreen))
                            : const Icon(Icons.table_view_outlined, size: 18),
                        label: const Text('Export Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),

                      // PDF Export & Print Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: (_isLoading || _reportData == null || _isExportingPdf) ? null : _handlePdfExport,
                        icon: _isExportingPdf
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Export / Print PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildPeriodSelectorControls() {
    final textDark = ParishColors.textDark;
    final borderGrey = ParishColors.borderGrey;

    if (_selectedPeriod == RemittancePeriodType.daily) {
      final y = _targetDate.year;
      final m = _months[_targetDate.month - 1];
      final d = _targetDate.day;

      return InkWell(
        onTap: _pickDailyDate,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderGrey),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date: $m $d, $y', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
              const Icon(Icons.calendar_today, size: 16, color: ParishColors.marianBlue),
            ],
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
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
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
            width: 90,
            child: DropdownButtonFormField<int>(
              value: _targetDate.year,
              isDense: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
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
      width: 120,
      child: DropdownButtonFormField<int>(
        value: _targetDate.year,
        isDense: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(),
        ),
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

  Widget _buildKpiSummaryBanner(RemittanceReportData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildKpiBlock('Included Receipts', '${data.totalCount} slips', ParishColors.textDark),
          _buildKpiBlock('Cash Remittance', '₱ ${data.totalCash.toStringAsFixed(2)}', ParishColors.oliveGreen),
          _buildKpiBlock('GCash Remittance', '₱ ${data.totalGCash.toStringAsFixed(2)}', const Color(0xFF005CEE)),
          _buildKpiBlock('TOTAL REMITTANCE', '₱ ${data.totalRemittance.toStringAsFixed(2)}', ParishColors.marianBlue, isBig: true),
        ],
      ),
    );
  }

  Widget _buildKpiBlock(String label, String value, Color color, {bool isBig = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: ParishColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBig ? 17 : 14.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderGrey),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 36, color: ParishColors.textMuted),
            const SizedBox(height: 8),
            Text(
              'No valid receipt transactions recorded for ${data.periodLabel}.',
              style: TextStyle(fontSize: 13, color: textDark, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
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