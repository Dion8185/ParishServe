// =============================================================================
// FILE: lib/features/receipts/presentation/pages/remittance_report_page.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/remittance_report_service.dart';

class RemittanceReportPage extends StatefulWidget {
  const RemittanceReportPage({super.key});

  @override
  State<RemittanceReportPage> createState() => _RemittanceReportPageState();
}

class _RemittanceReportPageState extends State<RemittanceReportPage> {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        final bool isMobile = constraints.maxWidth < 650;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Remittance & Collection Reports',
                  style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: textDark),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Canonical financial journals (Excludes Voided & Gratis slips)',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
            actions: [
              if (isDesktop && _reportData != null) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ParishColors.oliveGreen, width: 1.5),
                    foregroundColor: ParishColors.oliveGreen,
                  ),
                  onPressed: _isExportingExcel ? null : _handleExcelExport,
                  icon: const Icon(Icons.table_view, size: 16),
                  label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isExportingPdf ? null : _handlePdfExport,
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Export / Print PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
              ],
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: ParishColors.mercyRed),
                  const SizedBox(height: 10),
                  Text('Error generating report: $_errorMessage', style: const TextStyle(color: ParishColors.mercyRed)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _generateReport, child: const Text('Retry')),
                ],
              ),
            ),
          )
              : SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Period Selector Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderGrey),
                  ),
                  child: isMobile
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<RemittancePeriodType>(
                        segments: const [
                          ButtonSegment(value: RemittancePeriodType.daily, label: Text('Daily')),
                          ButtonSegment(value: RemittancePeriodType.monthly, label: Text('Monthly')),
                          ButtonSegment(value: RemittancePeriodType.yearly, label: Text('Yearly')),
                        ],
                        selected: {_selectedPeriod},
                        onSelectionChanged: (set) {
                          setState(() => _selectedPeriod = set.first);
                          _generateReport();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildPeriodSelectorControls(isMobile),
                    ],
                  )
                      : Row(
                    children: [
                      SegmentedButton<RemittancePeriodType>(
                        segments: const [
                          ButtonSegment(value: RemittancePeriodType.daily, label: Text('Daily Journal')),
                          ButtonSegment(value: RemittancePeriodType.monthly, label: Text('Monthly Remittance')),
                          ButtonSegment(value: RemittancePeriodType.yearly, label: Text('Annual Ledger')),
                        ],
                        selected: {_selectedPeriod},
                        onSelectionChanged: (set) {
                          setState(() => _selectedPeriod = set.first);
                          _generateReport();
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPeriodSelectorControls(isMobile)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Summary KPI Cards
                if (_reportData != null) ...[
                  _buildKpiSummaryBanner(_reportData!, isMobile),
                  const SizedBox(height: 14),

                  // Exclusions Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderGrey),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 18, color: ParishColors.oliveGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Canonical Exclusions Enforced: Excluded ${_reportData!.excludedVoidCount} voided slip(s) and ${_reportData!.excludedGratisCount} gratis transaction(s). Only valid cash and GCash intake are computed.',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. DataTable Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Included Receipts (${_reportData!.totalCount} Entries)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ParishColors.marianBlueSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _reportData!.periodLabel,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Full-width Data Table
                  _buildReportDataTable(_reportData!),
                ],

                if (!isDesktop && _reportData != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ParishColors.oliveGreen, width: 1.5),
                            foregroundColor: ParishColors.oliveGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isExportingExcel ? null : _handleExcelExport,
                          icon: const Icon(Icons.table_view, size: 18),
                          label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isExportingPdf ? null : _handlePdfExport,
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Print PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelectorControls(bool isMobile) {
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
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderGrey),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date: $m $d, $y', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDark)),
              const Icon(Icons.calendar_today, size: 18, color: ParishColors.marianBlue),
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
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            width: 100,
            child: DropdownButtonFormField<int>(
              value: _targetDate.year,
              isDense: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
      width: 140,
      child: DropdownButtonFormField<int>(
        value: _targetDate.year,
        isDense: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(),
        ),
        items: [2023, 2024, 2025, 2026, 2027, 2028, 2029].map((y) {
          return DropdownMenuItem(value: y, child: Text('Year $y', style: const TextStyle(fontSize: 13.5)));
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

  Widget _buildKpiSummaryBanner(RemittanceReportData data, bool isMobile) {
    if (isMobile) {
      return Container(
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
                Expanded(child: _buildKpiBlock('Included Slips', '${data.totalCount}', ParishColors.textDark)),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                Expanded(child: _buildKpiBlock('Cash Intake', '₱ ${data.totalCash.toStringAsFixed(0)}', ParishColors.oliveGreen)),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(child: _buildKpiBlock('GCash Intake', '₱ ${data.totalGCash.toStringAsFixed(0)}', const Color(0xFF005CEE))),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                Expanded(child: _buildKpiBlock('TOTAL REMITTANCE', '₱ ${data.totalRemittance.toStringAsFixed(2)}', ParishColors.goldAccent, isBig: true)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildKpiBlock('Included Receipts', '${data.totalCount} slips', ParishColors.textDark),
          Container(width: 1, height: 36, color: Colors.grey.shade300),
          _buildKpiBlock('Cash Remittance', '₱ ${data.totalCash.toStringAsFixed(2)}', ParishColors.oliveGreen),
          Container(width: 1, height: 36, color: Colors.grey.shade300),
          _buildKpiBlock('GCash Remittance', '₱ ${data.totalGCash.toStringAsFixed(2)}', const Color(0xFF005CEE)),
          Container(width: 1, height: 36, color: Colors.grey.shade300),
          _buildKpiBlock('TOTAL REMITTANCE', '₱ ${data.totalRemittance.toStringAsFixed(2)}', ParishColors.marianBlue, isBig: true),
        ],
      ),
    );
  }

  Widget _buildKpiBlock(String label, String value, Color color, {bool isBig = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: isBig ? 18 : 15,
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
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderGrey),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: ParishColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'No valid receipt transactions recorded for ${data.periodLabel}.',
              style: TextStyle(fontSize: 14, color: textDark, fontWeight: FontWeight.bold),
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
            columnSpacing: 22,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('Receipt No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
              DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
              DataColumn(label: Text('Payor Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
              DataColumn(label: Text('Particulars / Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
              DataColumn(label: Text('Tender', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
              DataColumn(label: Text('Amount (PHP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
            ],
            rows: [
              ...data.validReceipts.map((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(r.receiptNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 12))),
                    DataCell(Text(r.formattedDate, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r.payorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(r.relatedService, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
                    DataCell(Text('₱ ${r.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
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