import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/baptism_record_model.dart';
import '../../models/confirmation_record_model.dart';
import '../../services/baptism_service.dart';
import '../../services/confirmation_service.dart';
import '../dialogs/certificate_preview_dialog.dart';
import '../dialogs/manual_entry_dialog.dart';
import '../dialogs/ocr_scan_dialog.dart';
import 'baptism_manual_entry_page.dart';
import 'confirmation_manual_entry_page.dart';

class SacramentRegistryPage extends StatefulWidget {
  final String sacramentName;
  final String ledgerSubtitle;
  final IconData icon;
  final Color themeColor;
  final Color surfaceColor;

  const SacramentRegistryPage({
    super.key,
    required this.sacramentName,
    required this.ledgerSubtitle,
    required this.icon,
    required this.themeColor,
    required this.surfaceColor,
  });

  @override
  State<SacramentRegistryPage> createState() => _SacramentRegistryPageState();
}

class _SacramentRegistryPageState extends State<SacramentRegistryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<BaptismRecordModel> _baptismRecords = [];
  List<ConfirmationRecordModel> _confirmationRecords = [];
  bool _isLoading = false;
  String? _fetchError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _fetchError = null;
    });

    try {
      if (widget.sacramentName == 'Baptism') {
        final records = await BaptismService.getBaptismRecords();
        if (!mounted) return;
        setState(() => _baptismRecords = records);
      } else if (widget.sacramentName == 'Confirmation') {
        final records = await ConfirmationService.getConfirmationRecords();
        if (!mounted) return;
        setState(() => _confirmationRecords = records);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _fetchError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<BaptismRecordModel> get _filteredBaptismRecords {
    if (_searchQuery.trim().isEmpty) return _baptismRecords;
    final q = _searchQuery.toLowerCase();
    return _baptismRecords.where((r) {
      final nameMatch = r.childFullName.toLowerCase().contains(q);
      final bookMatch = 'book ${r.bookNumber}'.toLowerCase().contains(q) ||
          'page ${r.pageNumber}'.toLowerCase().contains(q) ||
          'line ${r.lineNumber}'.toLowerCase().contains(q);
      final parentMatch = r.fatherFullName.toLowerCase().contains(q) || r.motherFullName.toLowerCase().contains(q);
      return nameMatch || bookMatch || parentMatch;
    }).toList();
  }

  List<ConfirmationRecordModel> get _filteredConfirmationRecords {
    if (_searchQuery.trim().isEmpty) return _confirmationRecords;
    final q = _searchQuery.toLowerCase();
    return _confirmationRecords.where((r) {
      final nameMatch = r.confirmandFullName.toLowerCase().contains(q);
      final bookMatch = 'book ${r.bookNumber}'.toLowerCase().contains(q) ||
          'page ${r.pageNumber}'.toLowerCase().contains(q) ||
          'line ${r.lineNumber}'.toLowerCase().contains(q);
      final parentMatch = r.fatherFullName.toLowerCase().contains(q) || r.motherFullName.toLowerCase().contains(q);
      final churchMatch = r.churchBaptized.toLowerCase().contains(q);
      return nameMatch || bookMatch || parentMatch || churchMatch;
    }).toList();
  }

  void _openManualEntry() {
    if (widget.sacramentName == 'Baptism') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BaptismManualEntryPage(
            onRecordSaved: _loadRecords,
          ),
        ),
      );
    } else if (widget.sacramentName == 'Confirmation') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationManualEntryPage(
            onRecordSaved: _loadRecords,
          ),
        ),
      );
    } else {
      showManualEntryModal(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final isBaptism = widget.sacramentName == 'Baptism';
    final isConfirmation = widget.sacramentName == 'Confirmation';

    int count = 0;
    if (isBaptism) count = _baptismRecords.length;
    if (isConfirmation) count = _confirmationRecords.length;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhiteColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: widget.themeColor, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.sacramentName} Registry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
            ),
            Text(
              widget.ledgerSubtitle,
              style: TextStyle(fontSize: 12, color: textMutedColor),
            ),
          ],
        ),
        actions: [
          if (isBaptism || isConfirmation)
            IconButton(
              icon: Icon(Icons.refresh, color: widget.themeColor),
              onPressed: _loadRecords,
              tooltip: 'Refresh Database Records',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ledger Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.themeColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.themeColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.sacramentName} Canonical Books',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.themeColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (isBaptism || isConfirmation)
                              ? 'Live Database Records: $count registered'
                              : 'Digitized registry companion • St. John Paul II Parish',
                          style: TextStyle(fontSize: 12, color: textMutedColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => showOcrScanModal(context),
                      icon: const Icon(Icons.document_scanner, size: 22),
                      label: const Text('AI OCR Scan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: widget.themeColor, width: 1.8),
                        foregroundColor: widget.themeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _openManualEntry,
                      icon: const Icon(Icons.add, size: 22),
                      label: const Text('Manual Entry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardWhiteColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderGreyColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 24, color: widget.themeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(fontSize: 14, color: textDarkColor),
                      decoration: InputDecoration(
                        hintText: 'Search ${widget.sacramentName} records (Name, Book #, Parent)...',
                        hintStyle: TextStyle(fontSize: 14, color: textMutedColor),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.sacramentName} Records',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Canon 535',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.themeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Records List
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_fetchError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ParishColors.mercyRedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ParishColors.mercyRed),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: ParishColors.mercyRed),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Database error: $_fetchError',
                        style: const TextStyle(fontSize: 13, color: ParishColors.mercyRed),
                      ),
                    ),
                  ],
                ),
              )
            else if (isBaptism) ...[
                if (_filteredBaptismRecords.isEmpty)
                  _buildEmptyState(
                    title: _searchQuery.isNotEmpty ? 'No records match your search.' : 'No registered baptism records yet.',
                    subtitle: 'Tap "Manual Entry" above to add the first baptism record.',
                  )
                else
                  ..._filteredBaptismRecords.map((r) {
                    return _buildSacramentRecordCard(
                      context: context,
                      name: r.childFullName,
                      bookRef: r.bookReference,
                      dateString: 'Baptized: ${r.dateOfBaptism.toIso8601String().substring(0, 10)}',
                      parentage: 'Parents: ${r.fatherFullName} & ${r.motherFullName}',
                      sponsors: 'Sponsors: ${r.sponsor1FullName} (S1) & ${r.sponsor2FullName} (S2)',
                      marginalNotation: r.remarks != null && r.remarks!.trim().isNotEmpty
                          ? 'Marginal Note: ${r.remarks}'
                          : null,
                    );
                  }),
              ] else if (isConfirmation) ...[
                if (_filteredConfirmationRecords.isEmpty)
                  _buildEmptyState(
                    title: _searchQuery.isNotEmpty ? 'No records match your search.' : 'No registered confirmation records yet.',
                    subtitle: 'Tap "Manual Entry" above to add the first confirmation record to Liber Confirmatorum.',
                  )
                else
                  ..._filteredConfirmationRecords.map((c) {
                    final s2Text = c.sponsor2FullName != null ? ' & ${c.sponsor2FullName} (S2)' : '';
                    return _buildSacramentRecordCard(
                      context: context,
                      name: c.confirmandFullName,
                      bookRef: c.bookReference,
                      dateString: 'Confirmed: ${c.dateOfConfirmation.toIso8601String().substring(0, 10)}',
                      parentage: 'Parents: ${c.fatherFullName} & ${c.motherFullName}',
                      sponsors: 'Sponsors: ${c.sponsor1FullName} (S1)$s2Text',
                      marginalNotation: c.remarks != null && c.remarks!.trim().isNotEmpty
                          ? 'Marginal Note: ${c.remarks}'
                          : null,
                    );
                  }),
              ] else ...[
                _buildSacramentRecordCard(
                  context: context,
                  name: 'Sample Record Placeholder',
                  bookRef: 'Book 01, Page 01, Line 01',
                  dateString: 'Administered: 2026-09-01',
                  parentage: 'Parents: Juan Dela Cruz & Maria Dela Cruz',
                  sponsors: 'Sponsors: Pedro Santos & Ana Santos',
                  marginalNotation: null,
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: ParishColors.textMuted),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSacramentRecordCard({
    required BuildContext context,
    required String name,
    required String bookRef,
    required String dateString,
    required String parentage,
    required String sponsors,
    String? marginalNotation,
  }) {
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhiteColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGreyColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.surfaceColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.sacramentName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.themeColor,
                  ),
                ),
              ),
              Icon(Icons.qr_code_2, size: 26, color: textMutedColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor)),
          const SizedBox(height: 2),
          Text(bookRef, style: TextStyle(fontSize: 13, color: textMutedColor)),
          Text(dateString, style: TextStyle(fontSize: 13, color: textMutedColor)),
          const SizedBox(height: 6),
          Text(parentage, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDarkColor)),
          Text(sponsors, style: TextStyle(fontSize: 12, color: textMutedColor)),
          if (marginalNotation != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: widget.themeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.edit_note, size: 18, color: widget.themeColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      marginalNotation,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.themeColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.surfaceColor,
                foregroundColor: textDarkColor,
                elevation: 0,
                side: BorderSide(color: widget.themeColor, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showCertificatePreviewModal(
                context,
                name: name,
                sacrament: widget.sacramentName.toUpperCase(),
                bookRef: bookRef,
              ),
              icon: Icon(Icons.print, size: 18, color: widget.themeColor),
              label: Text(
                'Generate Official ${widget.sacramentName} Certificate',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}