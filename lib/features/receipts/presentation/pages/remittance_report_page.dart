// =============================================================================
// FILE: lib/features/receipts/presentation/pages/remittance_report_page.dart
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/remittance_report_service.dart';
import '../../../asset_inventory/presentation/widgets/asset_loading_overlay.dart';

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

    return AssetLoadingOverlay(
      isLoading: _isLoading || _isExportingPdf || _isExportingExcel,
      message: _isExportingPdf || _isExportingExcel ? 'Exporting report...' : 'Generating report...',
      child: LayoutBuilder(
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
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Canonical financial journals (Excludes Voided & Gratis slips)',
                    style: TextStyle(fontSize: 12, color: textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                if (isDesktop && _reportData != null) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ParishColors.oliveGreen, width: 1.4),
                      foregroundColor: ParishColors.oliveGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _isExportingExcel ? null : _handleExcelExport,
                    icon: const Icon(Icons.table_view, size: 16),
                    label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _isExportingPdf ? null : _handlePdfExport,
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Export / Print PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 14),
                ],
              ],
            ),
            body: SafeArea(
              child: _errorMessage != null
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40, color: ParishColors.mercyRed),
                      const SizedBox(height: 10),
                      Text(
                        'Error generating report: $_errorMessage',
                        style: const TextStyle(color: ParishColors.mercyRed),
                        textAlign: TextAlign.center,
                      ),
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
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderGrey),
                      ),
                      child: isMobile
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          color: ParishColors.cardWhite,
                          borderRadius: BorderRadius.circular(12),
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

                      // 3. Fund Receipts Template Breakdown (Sacrament vs Parish Fund + 60/40 Split)
                      _buildFundReceiptsBreakdownSection(_reportData!, isDesktop),
                      const SizedBox(height: 22),

                      // 4. DataTable Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Included Receipts (${_reportData!.totalCount} Entries)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: ParishColors.marianBlueSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _reportData!.periodLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.marianBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 5. Full-width Data Table
                      _buildReportDataTable(_reportData!),
                    ],

                    if (!isDesktop && _reportData != null) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: ParishColors.oliveGreen, width: 1.4),
                                foregroundColor: ParishColors.oliveGreen,
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _isExportingExcel ? null : _handleExcelExport,
                              icon: const Icon(Icons.table_view, size: 18),
                              label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ParishColors.marianBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _isExportingPdf ? null : _handlePdfExport,
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('Print PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFundReceiptsBreakdownSection(RemittanceReportData data, bool isDesktop) {
    final breakdown = RemittanceReportService.computeFundBreakdown(data.validReceipts);

    final sacramentCard = _buildSummaryBlockCard(
      title: 'Sacrament Fund Summary',
      icon: Icons.church_outlined,
      accentColor: ParishColors.marianBlue,
      rows: [
        _SummaryRowData('Baptism Infant', breakdown.col('baptism')),
        _SummaryRowData('Confirmation', breakdown.col('confirmation')),
        _SummaryRowData('Permission', breakdown.col('permission')),
        _SummaryRowData('Certificates', breakdown.col('certificates')),
        _SummaryRowData('Marriage Banns', breakdown.col('marriage_banns')),
        _SummaryRowData('Funeral Mass', breakdown.col('funeral_mass')),
        _SummaryRowData('Funeral Blessing', breakdown.col('funeral_blessing')),
        _SummaryRowData('Mass Intention (60%)', breakdown.massIntention60),
        _SummaryRowData('MI Collection (60%)', breakdown.miCollection60),
        _SummaryRowData('Wedding', breakdown.col('wedding')),
      ],
      subtotalLabel: 'Sacrament Sub Total',
      subtotalValue: breakdown.sacramentSubtotal,
    );

    final parishFundCard = _buildSummaryBlockCard(
      title: 'Parish Fund Summary',
      icon: Icons.account_balance_outlined,
      accentColor: ParishColors.oliveGreen,
      rows: [
        _SummaryRowData('Weekday Collection', breakdown.col('weekday_coll')),
        _SummaryRowData('Sunday Collection', breakdown.col('sunday_coll')),
        _SummaryRowData('Special Collection', breakdown.col('special_coll')),
        _SummaryRowData('Mass Intention (40%)', breakdown.massIntention40),
        _SummaryRowData('MI Collection (40%)', breakdown.miCollection40),
        _SummaryRowData('Donation — Balik Handog', breakdown.col('balik_handog')),
        _SummaryRowData(
          'Donation — Additional Sponsors',
          breakdown.col('baptism_add') + breakdown.col('confirmation_add'),
        ),
        _SummaryRowData('Donation from Parishioners', breakdown.col('donation_parish')),
        _SummaryRowData('Subsidy from Diocese', breakdown.col('subsidy')),
      ],
      subtotalLabel: 'Parish Fund Sub Total',
      subtotalValue: breakdown.parishFundSubtotal,
      extraFooter: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ParishColors.marianBlueSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Grand Total (Sacrament + Parish Fund)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '₱ ${breakdown.grandSummaryTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fund Receipts Breakdown (Excel Template Reconciliation)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ParishColors.textDark),
        ),
        const SizedBox(height: 10),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: sacramentCard),
              const SizedBox(width: 16),
              Expanded(child: parishFundCard),
            ],
          )
        else ...[
          sacramentCard,
          const SizedBox(height: 12),
          parishFundCard,
        ],
      ],
    );
  }

  Widget _buildSummaryBlockCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<_SummaryRowData> rows,
    required String subtotalLabel,
    required double subtotalValue,
    Widget? extraFooter,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ParishColors.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...rows.map((r) {
            final hasValue = r.amount > 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: hasValue ? ParishColors.textDark : ParishColors.textMuted,
                        fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasValue ? '₱ ${r.amount.toStringAsFixed(2)}' : '—',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                      color: hasValue ? ParishColors.textDark : ParishColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subtotalLabel,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
              Text(
                '₱ ${subtotalValue.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: accentColor),
              ),
            ],
          ),
          if (extraFooter != null) extraFooter,
        ],
      ),
    );
  }

  Widget _buildPeriodSelectorControls(bool isMobile) {
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
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
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
      width: isMobile ? double.infinity : 150,
      child: DropdownButtonFormField<int>(
        value: _targetDate.year,
        isDense: true,
        decoration: _inputDecoration(labelText: 'Target Year'),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        children: [
          Expanded(child: _buildKpiBlock('Included Receipts', '${data.totalCount} slips', ParishColors.textDark)),
          Container(width: 1, height: 36, color: Colors.grey.shade300),
          Expanded(child: _buildKpiBlock('Cash Remittance', '₱ ${data.totalCash.toStringAsFixed(2)}', ParishColors.oliveGreen)),
          Container(width: 1, height: 36, color: Colors.grey.shade300),
          Expanded(child: _buildKpiBlock('GCash Remittance', '₱ ${data.totalGCash.toStringAsFixed(2)}', const Color(0xFF005CEE))),
          Container(width: 1, height: 36, color: Colors.grey.shade300),
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
          style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: isBig ? 18 : 15,
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
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderGrey),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: ParishColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'No valid receipt transactions recorded for ${data.periodLabel}.',
              style: TextStyle(fontSize: 14, color: textDark, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, tableConstraints) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderGrey),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: max(tableConstraints.maxWidth, 740),
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(ParishColors.marianBlueSurface),
                  columnSpacing: 24,
                  horizontalMargin: 18,
                  columns: const [
                    DataColumn(label: Text('Receipt No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                    DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                    DataColumn(label: Text('Payor Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                    DataColumn(label: Text('Particulars / Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                    DataColumn(label: Text('Tender', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                    DataColumn(label: Text('Amount (PHP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)), numeric: true),
                  ],
                  rows: [
                    ...data.validReceipts.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(Text(r.receiptNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 12))),
                          DataCell(Text(r.formattedDate, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(r.payorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Text(r.relatedService, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: r.paymentMode == 'GCash' ? const Color(0xFFEFF6FF) : ParishColors.oliveGreenSurface,
                              borderRadius: BorderRadius.circular(6),
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
          ),
        );
      },
    );
  }
}

class _SummaryRowData {
  final String label;
  final double amount;

  const _SummaryRowData(this.label, this.amount);
}