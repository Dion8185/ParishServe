import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/baptism_record_model.dart';
import '../../models/confirmation_record_model.dart';
import '../../models/first_communion_record_model.dart';
import '../../models/matrimony_record_model.dart';
import '../../models/death_record_model.dart';
import '../../models/conversion_record_model.dart';
import '../../services/baptism_service.dart';
import '../../services/confirmation_service.dart';
import '../../services/first_communion_service.dart';
import '../../services/matrimony_service.dart';
import '../../services/death_service.dart';
import '../../services/conversion_service.dart';
import '../dialogs/manual_entry_dialog.dart';
import '../dialogs/ocr_scan_dialog.dart';
import 'baptism_manual_entry_page.dart';
import 'confirmation_manual_entry_page.dart';
import 'first_communion_manual_entry_page.dart';
import 'matrimony_manual_entry_page.dart';
import 'death_manual_entry_page.dart';
import 'conversion_manual_entry_page.dart';
import 'sacrament_record_detail_page.dart';

enum RegistryViewMode { cards, table }

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
  List<FirstCommunionRecordModel> _firstCommunionRecords = [];
  List<MatrimonyRecordModel> _matrimonyRecords = [];
  List<DeathRecordModel> _deathRecords = [];
  List<ConversionRecordModel> _conversionRecords = [];

  bool _isLoading = false;
  String? _fetchError;
  String _searchQuery = '';

  // View & Pagination State
  RegistryViewMode _viewMode = RegistryViewMode.cards;
  int _currentPage = 0;
  int _rowsPerPage = 10;

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
      } else if (widget.sacramentName == 'First Communion') {
        final records = await FirstCommunionService.getFirstCommunionRecords();
        if (!mounted) return;
        setState(() => _firstCommunionRecords = records);
      } else if (widget.sacramentName == 'Matrimony') {
        final records = await MatrimonyService.getMatrimonyRecords();
        if (!mounted) return;
        setState(() => _matrimonyRecords = records);
      } else if (widget.sacramentName == 'Death') {
        final records = await DeathService.getDeathRecords();
        if (!mounted) return;
        setState(() => _deathRecords = records);
      } else if (widget.sacramentName == 'Conversion') {
        final records = await ConversionService.getConversionRecords();
        if (!mounted) return;
        setState(() => _conversionRecords = records);
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

  List<FirstCommunionRecordModel> get _filteredFirstCommunionRecords {
    if (_searchQuery.trim().isEmpty) return _firstCommunionRecords;
    final q = _searchQuery.toLowerCase();
    return _firstCommunionRecords.where((r) {
      final nameMatch = r.communicantFullName.toLowerCase().contains(q);
      final controlMatch = r.controlNumber.toLowerCase().contains(q);
      final yearMatch = r.year.toString().contains(q);
      final parishMatch = r.baptismParish.toLowerCase().contains(q);
      return nameMatch || controlMatch || yearMatch || parishMatch;
    }).toList();
  }

  List<MatrimonyRecordModel> get _filteredMatrimonyRecords {
    if (_searchQuery.trim().isEmpty) return _matrimonyRecords;
    final q = _searchQuery.toLowerCase();
    return _matrimonyRecords.where((r) {
      final nameMatch = r.groomFullName.toLowerCase().contains(q) || r.brideFullName.toLowerCase().contains(q);
      final bookMatch = 'book ${r.bookNumber}'.toLowerCase().contains(q) ||
          'page ${r.pageNumber}'.toLowerCase().contains(q) ||
          'line ${r.lineNumber}'.toLowerCase().contains(q);
      return nameMatch || bookMatch;
    }).toList();
  }

  List<DeathRecordModel> get _filteredDeathRecords {
    if (_searchQuery.trim().isEmpty) return _deathRecords;
    final q = _searchQuery.toLowerCase();
    return _deathRecords.where((d) {
      final nameMatch = d.deceasedFullName.toLowerCase().contains(q);
      final bookMatch = 'book ${d.bookNumber}'.toLowerCase().contains(q) ||
          'page ${d.pageNumber}'.toLowerCase().contains(q) ||
          'line ${d.lineNumber}'.toLowerCase().contains(q);
      final placeMatch = d.placeOfBurial.toLowerCase().contains(q);
      return nameMatch || bookMatch || placeMatch;
    }).toList();
  }

  List<ConversionRecordModel> get _filteredConversionRecords {
    if (_searchQuery.trim().isEmpty) return _conversionRecords;
    final q = _searchQuery.toLowerCase();
    return _conversionRecords.where((c) {
      final nameMatch = c.convertFullName.toLowerCase().contains(q);
      final bookMatch = 'book ${c.bookNumber}'.toLowerCase().contains(q) ||
          'page ${c.pageNumber}'.toLowerCase().contains(q) ||
          'line ${c.lineNumber}'.toLowerCase().contains(q);
      final parentMatch = c.fatherFullName.toLowerCase().contains(q) || c.motherFullName.toLowerCase().contains(q);
      return nameMatch || bookMatch || parentMatch;
    }).toList();
  }

  void _openManualEntry() {
    if (widget.sacramentName == 'Baptism') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => BaptismManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'Confirmation') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmationManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'First Communion') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => FirstCommunionManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'Matrimony') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MatrimonyManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'Death') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DeathManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'Conversion') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ConversionManualEntryPage(onRecordSaved: _loadRecords)));
    } else {
      showManualEntryModal(context);
    }
  }

  void _navigateToDetail(BuildContext context, {
    required String recordId,
    required String name,
    required String bookRef,
    required String dateString,
    required String parentage,
    required String sponsors,
    String? marginalNotation,
    required Map<String, dynamic> rawRecordData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SacramentRecordDetailPage(
          sacramentName: widget.sacramentName,
          recordId: recordId,
          name: name,
          bookRef: bookRef,
          dateString: dateString,
          parentage: parentage,
          sponsors: sponsors,
          marginalNotation: marginalNotation,
          themeColor: widget.themeColor,
          surfaceColor: widget.surfaceColor,
          rawRecordData: rawRecordData,
          onRecordUpdated: _loadRecords,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    final isBaptism = widget.sacramentName == 'Baptism';
    final isConfirmation = widget.sacramentName == 'Confirmation';
    final isCommunion = widget.sacramentName == 'First Communion';
    final isMatrimony = widget.sacramentName == 'Matrimony';
    final isDeath = widget.sacramentName == 'Death';
    final isConversion = widget.sacramentName == 'Conversion';

    int totalCount = 0;
    List paginatedBaptism = [];
    List paginatedConfirmation = [];
    List paginatedCommunion = [];
    List paginatedMatrimony = [];
    List paginatedDeath = [];
    List paginatedConversion = [];

    if (isBaptism) {
      final list = _filteredBaptismRecords;
      totalCount = list.length;
      paginatedBaptism = _paginate(list);
    } else if (isConfirmation) {
      final list = _filteredConfirmationRecords;
      totalCount = list.length;
      paginatedConfirmation = _paginate(list);
    } else if (isCommunion) {
      final list = _filteredFirstCommunionRecords;
      totalCount = list.length;
      paginatedCommunion = _paginate(list);
    } else if (isMatrimony) {
      final list = _filteredMatrimonyRecords;
      totalCount = list.length;
      paginatedMatrimony = _paginate(list);
    } else if (isDeath) {
      final list = _filteredDeathRecords;
      totalCount = list.length;
      paginatedDeath = _paginate(list);
    } else if (isConversion) {
      final list = _filteredConversionRecords;
      totalCount = list.length;
      paginatedConversion = _paginate(list);
    }

    final int totalPages = (totalCount / _rowsPerPage).ceil() > 0 ? (totalCount / _rowsPerPage).ceil() : 1;
    if (_currentPage >= totalPages) _currentPage = totalPages > 0 ? totalPages - 1 : 0;

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
          if (isBaptism || isConfirmation || isCommunion || isMatrimony || isDeath || isConversion)
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
                border: Border.all(color: widget.themeColor.withOpacity(0.4), width: 1.5),
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
                          'Live Database Records: $totalCount registered',
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

            // Search Bar & View/Pagination Controls Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardWhiteColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderGreyColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.search, size: 24, color: widget.themeColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() {
                            _searchQuery = val;
                            _currentPage = 0;
                          }),
                          style: TextStyle(fontSize: 14, color: textDarkColor),
                          decoration: InputDecoration(
                            hintText: 'Search ${widget.sacramentName} records...',
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
                            setState(() {
                              _searchQuery = '';
                              _currentPage = 0;
                            });
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // View Mode Toggle (Cards vs Table)
                      ToggleButtons(
                        isSelected: [_viewMode == RegistryViewMode.cards, _viewMode == RegistryViewMode.table],
                        onPressed: (index) {
                          setState(() {
                            _viewMode = index == 0 ? RegistryViewMode.cards : RegistryViewMode.table;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: widget.themeColor,
                        color: textMutedColor,
                        constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
                        children: const [
                          Tooltip(message: 'Card View', child: Icon(Icons.grid_view, size: 18)),
                          Tooltip(message: 'Table View', child: Icon(Icons.table_chart, size: 18)),
                        ],
                      ),
                      // Rows Per Page Selector
                      Row(
                        children: [
                          Text('Rows:', style: TextStyle(fontSize: 12, color: textMutedColor)),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _rowsPerPage,
                            isDense: true,
                            items: [10, 25, 50].map((val) {
                              return DropdownMenuItem<int>(
                                value: val,
                                child: Text('$val', style: TextStyle(fontSize: 13, color: textDarkColor)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _rowsPerPage = val;
                                  _currentPage = 0;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Header info & total count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.sacramentName} Records ($totalCount)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Page ${_currentPage + 1} of $totalPages',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.themeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main Records Display Area (Cards vs Table)
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
            else if (totalCount == 0)
                _buildEmptyState(
                  title: _searchQuery.isNotEmpty ? 'No records match your search.' : 'No registered ${widget.sacramentName.toLowerCase()} records yet.',
                  subtitle: 'Tap "Manual Entry" above to add a new record.',
                )
              else if (_viewMode == RegistryViewMode.cards)
                  ..._buildCardsList(paginatedBaptism, paginatedConfirmation, paginatedCommunion, paginatedMatrimony, paginatedDeath, paginatedConversion, isBaptism, isConfirmation, isCommunion, isMatrimony, isDeath, isConversion)
                else
                  _buildTableView(paginatedBaptism, paginatedConfirmation, paginatedCommunion, paginatedMatrimony, paginatedDeath, paginatedConversion, isBaptism, isConfirmation, isCommunion, isMatrimony, isDeath, isConversion),

            const SizedBox(height: 16),

            // Pagination Controls Footer
            if (totalCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: cardWhiteColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderGreyColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${_currentPage * _rowsPerPage + 1}–${((_currentPage + 1) * _rowsPerPage) > totalCount ? totalCount : ((_currentPage + 1) * _rowsPerPage)} of $totalCount',
                      style: TextStyle(fontSize: 12, color: textMutedColor),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.first_page, size: 20),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        ),
                        Text(
                          '${_currentPage + 1} / $totalPages',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDarkColor),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.last_page, size: 20),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
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

  List _paginate(List list) {
    final startIndex = _currentPage * _rowsPerPage;
    if (startIndex >= list.length) return [];
    final endIndex = (startIndex + _rowsPerPage) > list.length ? list.length : (startIndex + _rowsPerPage);
    return list.sublist(startIndex, endIndex);
  }

  List<Widget> _buildCardsList(
      List bList, List cList, List fList, List mList, List dList, List cnList,
      bool isBaptism, bool isConfirmation, bool isCommunion, bool isMatrimony, bool isDeath, bool isConversion) {
    if (isBaptism) {
      return bList.map((r) => _buildConciseSacramentCard(
        context: context,
        name: r.childFullName,
        parents: 'Parents: ${r.fatherFullName} & ${r.motherFullName}',
        dob: 'DOB: ${r.dateOfBirth.toIso8601String().substring(0, 10)}',
        sacramentDate: 'Baptism Date: ${r.dateOfBaptism.toIso8601String().substring(0, 10)}',
        bookRef: r.bookReference,
        recordId: r.recordId,
        parentage: 'Parents: ${r.fatherFullName} & ${r.motherFullName}',
        sponsors: 'Sponsors: ${r.sponsor1FullName} (S1) & ${r.sponsor2FullName} (S2)',
        marginalNotation: r.remarks,
        rawRecordData: r.toMap(),
      )).toList();
    }
    if (isConfirmation) {
      return cList.map((c) {
        final s2Text = c.sponsor2FullName != null ? ' & ${c.sponsor2FullName} (S2)' : '';
        return _buildConciseSacramentCard(
          context: context,
          name: c.confirmandFullName,
          parents: 'Parents: ${c.fatherFullName} & ${c.motherFullName}',
          dob: c.dateOfBirth != null ? 'DOB: ${c.dateOfBirth!.toIso8601String().substring(0, 10)}' : 'DOB: Not Specified',
          sacramentDate: 'Confirmation Date: ${c.dateOfConfirmation.toIso8601String().substring(0, 10)}',
          bookRef: c.bookReference,
          recordId: c.recordId,
          parentage: 'Parents: ${c.fatherFullName} & ${c.motherFullName}',
          sponsors: 'Sponsors: ${c.sponsor1FullName} (S1)$s2Text',
          marginalNotation: c.remarks,
          rawRecordData: c.toMap(),
        );
      }).toList();
    }
    if (isCommunion) {
      return fList.map((fcm) {
        final parents = (fcm.fatherFullName != '—' || fcm.motherFullName != '—')
            ? 'Parents: ${fcm.fatherFullName} & ${fcm.motherFullName}'
            : 'Parents: Not Specified in Batch Register';
        return _buildConciseSacramentCard(
          context: context,
          name: fcm.communicantFullName,
          parents: parents,
          dob: 'Baptism Parish: ${fcm.baptismParish}',
          sacramentDate: 'Communion Date: ${fcm.dateOfCommunion.toIso8601String().substring(0, 10)}',
          bookRef: fcm.referenceDisplay,
          recordId: fcm.recordId,
          parentage: parents,
          sponsors: 'Baptism Parish: ${fcm.baptismParish}',
          marginalNotation: fcm.remarks,
          rawRecordData: fcm.toMap(),
        );
      }).toList();
    }
    if (isMatrimony) {
      return mList.map((m) {
        final coupleName = '${m.groomFullName}  &  ${m.brideFullName}';
        return _buildConciseSacramentCard(
          context: context,
          name: coupleName,
          parents: 'Groom DOB: ${m.groomDateOfBirth?.toIso8601String().substring(0, 10) ?? "N/A"} | Bride DOB: ${m.brideDateOfBirth?.toIso8601String().substring(0, 10) ?? "N/A"}',
          dob: 'Marriage Type: ${m.marriageType}',
          sacramentDate: 'Marriage Date: ${m.dateOfMarriage.toIso8601String().substring(0, 10)}',
          bookRef: m.bookReference,
          recordId: m.recordId,
          parentage: 'Parents: Groom (${m.groomFatherLastName}) & Bride (${m.brideFatherLastName})',
          sponsors: 'Primary Sponsors: ${m.sponsor1FirstName} ${m.sponsor1LastName} & ${m.sponsor2FirstName} ${m.sponsor2LastName}',
          marginalNotation: m.remarks,
          rawRecordData: m.toMap(),
        );
      }).toList();
    }
    if (isDeath) {
      return dList.map((d) {
        final spouseOrParents = d.spouseFullName != '—' ? 'Spouse: ${d.spouseFullName}' : 'Parents: ${d.parentsFullName}';
        return _buildConciseSacramentCard(
          context: context,
          name: d.deceasedFullName,
          parents: spouseOrParents,
          dob: 'Civil Status: ${d.civilStatus} (Age: ${d.age})',
          sacramentDate: 'Burial Date: ${d.dateOfBurial.toIso8601String().substring(0, 10)}',
          bookRef: d.bookReference,
          recordId: d.recordId,
          parentage: spouseOrParents,
          sponsors: 'Cemetery: ${d.placeOfBurial} • Liturgical Service: ${d.liturgicalService}',
          marginalNotation: d.remarks,
          rawRecordData: d.toMap(),
        );
      }).toList();
    }
    if (isConversion) {
      return cnList.map((cnv) {
        return _buildConciseSacramentCard(
          context: context,
          name: cnv.convertFullName,
          parents: 'Parents: ${cnv.fatherFullName} & ${cnv.motherFullName}',
          dob: 'DOB: ${cnv.dateOfBirth.toIso8601String().substring(0, 10)}',
          sacramentDate: 'Reception Date: ${cnv.dateOfReception.toIso8601String().substring(0, 10)}',
          bookRef: cnv.bookReference,
          recordId: cnv.recordId,
          parentage: 'Parents: ${cnv.fatherFullName} & ${cnv.motherFullName}',
          sponsors: 'Witness 1: ${cnv.witness1FullName}',
          marginalNotation: cnv.remarks,
          rawRecordData: cnv.toMap(),
        );
      }).toList();
    }
    return [];
  }

  Widget _buildTableView(
      List bList, List cList, List fList, List mList, List dList, List cnList,
      bool isBaptism, bool isConfirmation, bool isCommunion, bool isMatrimony, bool isDeath, bool isConversion) {
    List<DataColumn> columns = [];
    List<DataRow> rows = [];

    if (isBaptism) {
      columns = const [
        DataColumn(label: Text('Book')),
        DataColumn(label: Text('Page')),
        DataColumn(label: Text('Line')),
        DataColumn(label: Text('Child Full Name')),
        DataColumn(label: Text('Date of Birth')),
        DataColumn(label: Text('Date of Baptism')),
        DataColumn(label: Text('Parents')),
        DataColumn(label: Text('Action')),
      ];
      rows = bList.map((r) {
        return DataRow(cells: [
          DataCell(Text(r.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r.childFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r.dateOfBirth.toIso8601String().substring(0, 10))),
          DataCell(Text(r.dateOfBaptism.toIso8601String().substring(0, 10))),
          DataCell(Text('${r.fatherFullName} & ${r.motherFullName}')),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: r.recordId,
            name: r.childFullName,
            bookRef: r.bookReference,
            dateString: 'Baptized: ${r.dateOfBaptism.toIso8601String().substring(0, 10)}',
            parentage: 'Parents: ${r.fatherFullName} & ${r.motherFullName}',
            sponsors: 'Sponsors: ${r.sponsor1FullName} (S1) & ${r.sponsor2FullName} (S2)',
            marginalNotation: r.remarks,
            rawData: r.toMap(),
          )),
        ]);
      }).toList();
    } else if (isConfirmation) {
      columns = const [
        DataColumn(label: Text('Book')),
        DataColumn(label: Text('Page')),
        DataColumn(label: Text('Line')),
        DataColumn(label: Text('Confirmand Full Name')),
        DataColumn(label: Text('Date of Birth')),
        DataColumn(label: Text('Date of Confirmation')),
        DataColumn(label: Text('Parents')),
        DataColumn(label: Text('Action')),
      ];
      rows = cList.map((c) {
        final s2Text = c.sponsor2FullName != null ? ' & ${c.sponsor2FullName} (S2)' : '';
        return DataRow(cells: [
          DataCell(Text(c.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(c.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(c.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(c.confirmandFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(c.dateOfBirth != null ? c.dateOfBirth!.toIso8601String().substring(0, 10) : '—')),
          DataCell(Text(c.dateOfConfirmation.toIso8601String().substring(0, 10))),
          DataCell(Text('${c.fatherFullName} & ${c.motherFullName}')),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: c.recordId,
            name: c.confirmandFullName,
            bookRef: c.bookReference,
            dateString: 'Confirmed: ${c.dateOfConfirmation.toIso8601String().substring(0, 10)}',
            parentage: 'Parents: ${c.fatherFullName} & ${c.motherFullName}',
            sponsors: 'Sponsors: ${c.sponsor1FullName} (S1)$s2Text',
            marginalNotation: c.remarks,
            rawData: c.toMap(),
          )),
        ]);
      }).toList();
    } else if (isCommunion) {
      columns = const [
        DataColumn(label: Text('Year')),
        DataColumn(label: Text('Control #')),
        DataColumn(label: Text('Communicant Name')),
        DataColumn(label: Text('Date of Communion')),
        DataColumn(label: Text('Baptism Parish')),
        DataColumn(label: Text('Action')),
      ];
      rows = fList.map((fcm) {
        final parents = (fcm.fatherFullName != '—' || fcm.motherFullName != '—')
            ? 'Parents: ${fcm.fatherFullName} & ${fcm.motherFullName}'
            : 'Parents: Not Specified';
        return DataRow(cells: [
          DataCell(Text('${fcm.year}', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(fcm.controlNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(fcm.communicantFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(fcm.dateOfCommunion.toIso8601String().substring(0, 10))),
          DataCell(Text(fcm.baptismParish)),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: fcm.recordId,
            name: fcm.communicantFullName,
            bookRef: fcm.referenceDisplay,
            dateString: 'Received Holy Communion: ${fcm.dateOfCommunion.toIso8601String().substring(0, 10)}',
            parentage: parents,
            sponsors: 'Baptism Parish: ${fcm.baptismParish}',
            marginalNotation: fcm.remarks,
            rawData: fcm.toMap(),
          )),
        ]);
      }).toList();
    } else if (isMatrimony) {
      columns = const [
        DataColumn(label: Text('Book')),
        DataColumn(label: Text('Page')),
        DataColumn(label: Text('Line')),
        DataColumn(label: Text('Groom & Bride')),
        DataColumn(label: Text('Date of Marriage')),
        DataColumn(label: Text('Marriage Type')),
        DataColumn(label: Text('Action')),
      ];
      rows = mList.map((m) {
        final couple = '${m.groomFullName} & ${m.brideFullName}';
        return DataRow(cells: [
          DataCell(Text(m.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(m.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(m.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(couple, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(m.dateOfMarriage.toIso8601String().substring(0, 10))),
          DataCell(Text(m.marriageType)),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: m.recordId,
            name: couple,
            bookRef: m.bookReference,
            dateString: 'Married: ${m.dateOfMarriage.toIso8601String().substring(0, 10)} (${m.marriageType})',
            parentage: 'Primary Sponsors: ${m.sponsor1FirstName} ${m.sponsor1LastName} & ${m.sponsor2FirstName} ${m.sponsor2LastName}',
            sponsors: 'Solemnized by: Rev. Fr. ${m.solemnizerFirstName} ${m.solemnizerLastName}',
            marginalNotation: m.remarks,
            rawData: m.toMap(),
          )),
        ]);
      }).toList();
    } else if (isDeath) {
      columns = const [
        DataColumn(label: Text('Book')),
        DataColumn(label: Text('Page')),
        DataColumn(label: Text('Line')),
        DataColumn(label: Text('Deceased Name')),
        DataColumn(label: Text('Age')),
        DataColumn(label: Text('Date of Death')),
        DataColumn(label: Text('Date of Burial')),
        DataColumn(label: Text('Action')),
      ];
      rows = dList.map((d) {
        final spouseOrParents = d.spouseFullName != '—' ? 'Spouse: ${d.spouseFullName}' : 'Parents: ${d.parentsFullName}';
        return DataRow(cells: [
          DataCell(Text(d.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(d.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(d.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(d.deceasedFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(d.age)),
          DataCell(Text(d.dateOfDeath.toIso8601String().substring(0, 10))),
          DataCell(Text(d.dateOfBurial.toIso8601String().substring(0, 10))),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: d.recordId,
            name: d.deceasedFullName,
            bookRef: d.bookReference,
            dateString: 'Buried: ${d.dateOfBurial.toIso8601String().substring(0, 10)}',
            parentage: spouseOrParents,
            sponsors: 'Cemetery: ${d.placeOfBurial}',
            marginalNotation: d.remarks,
            rawData: d.toMap(),
          )),
        ]);
      }).toList();
    } else if (isConversion) {
      columns = const [
        DataColumn(label: Text('Book')),
        DataColumn(label: Text('Page')),
        DataColumn(label: Text('Line')),
        DataColumn(label: Text('Convert Name')),
        DataColumn(label: Text('Date of Birth')),
        DataColumn(label: Text('Date of Reception')),
        DataColumn(label: Text('Prior Church')),
        DataColumn(label: Text('Action')),
      ];
      rows = cnList.map((cnv) {
        return DataRow(cells: [
          DataCell(Text(cnv.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(cnv.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(cnv.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(cnv.convertFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(cnv.dateOfBirth.toIso8601String().substring(0, 10))),
          DataCell(Text(cnv.dateOfReception.toIso8601String().substring(0, 10))),
          DataCell(Text(cnv.priorBaptismChurch ?? 'None')),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: cnv.recordId,
            name: cnv.convertFullName,
            bookRef: cnv.bookReference,
            dateString: 'Received into Communion: ${cnv.dateOfReception.toIso8601String().substring(0, 10)}',
            parentage: 'Parents: ${cnv.fatherFullName} & ${cnv.motherFullName}',
            sponsors: 'Witness 1: ${cnv.witness1FullName}',
            marginalNotation: cnv.remarks,
            rawData: cnv.toMap(),
          )),
        ]);
      }).toList();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columns: columns,
                rows: rows,
                headingRowColor: WidgetStateProperty.all(widget.surfaceColor),
                headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: widget.themeColor, fontSize: 13),
                dataTextStyle: TextStyle(fontSize: 13, color: ParishColors.textDark),
                columnSpacing: 24,
                horizontalMargin: 20,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableDetailBtn({
    required BuildContext context,
    required String recordId,
    required String name,
    required String bookRef,
    required String dateString,
    required String parentage,
    required String sponsors,
    String? marginalNotation,
    required Map<String, dynamic> rawData,
  }) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: widget.themeColor,
        backgroundColor: widget.surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _navigateToDetail(
        context,
        recordId: recordId,
        name: name,
        bookRef: bookRef,
        dateString: dateString,
        parentage: parentage,
        sponsors: sponsors,
        marginalNotation: marginalNotation,
        rawRecordData: rawData,
      ),
      icon: const Icon(Icons.visibility, size: 15),
      label: const Text('View / Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

  /// Concise Card View displaying strictly Name, Parents, DOB, and Sacrament Date
  Widget _buildConciseSacramentCard({
    required BuildContext context,
    required String name,
    required String parents,
    required String dob,
    required String sacramentDate,
    required String bookRef,
    required String recordId,
    required String parentage,
    required String sponsors,
    String? marginalNotation,
    required Map<String, dynamic> rawRecordData,
  }) {
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    return InkWell(
      onTap: () => _navigateToDetail(
        context,
        recordId: recordId,
        name: name,
        bookRef: bookRef,
        dateString: sacramentDate,
        parentage: parentage,
        sponsors: sponsors,
        marginalNotation: marginalNotation,
        rawRecordData: rawRecordData,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                Text(
                  bookRef,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMutedColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 1. Person's full name
            Text(
              name,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDarkColor),
            ),
            const SizedBox(height: 4),
            // 2. Parents' names
            Text(
              parents,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDarkColor),
            ),
            const SizedBox(height: 2),
            // 3. Date of birth
            Text(
              dob,
              style: TextStyle(fontSize: 12.5, color: textMutedColor),
            ),
            const SizedBox(height: 2),
            // 4. Date of the administered sacrament
            Text(
              sacramentDate,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: widget.themeColor),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: widget.surfaceColor,
                  foregroundColor: textDarkColor,
                  elevation: 0,
                  side: BorderSide(color: widget.themeColor, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _navigateToDetail(
                  context,
                  recordId: recordId,
                  name: name,
                  bookRef: bookRef,
                  dateString: sacramentDate,
                  parentage: parentage,
                  sponsors: sponsors,
                  marginalNotation: marginalNotation,
                  rawRecordData: rawRecordData,
                ),
                icon: Icon(Icons.visibility, size: 18, color: widget.themeColor),
                label: Text(
                  'View & Manage Record Details',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDarkColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}