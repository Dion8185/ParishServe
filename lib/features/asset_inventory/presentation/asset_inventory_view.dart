import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../models/asset_model.dart';
import '../models/asset_reference_models.dart';
import '../services/asset_label_pdf_service.dart';
import '../services/asset_reference_service.dart';
import '../services/asset_service.dart';
import 'dialogs/asset_detail_dialog.dart';
import 'dialogs/audit_scan_dialog.dart';
import 'dialogs/manage_asset_references_dialog.dart';
import 'dialogs/register_asset_dialog.dart';
import 'widgets/asset_item_card.dart';

enum AssetViewMode { cards, table }

class AssetInventoryView extends StatefulWidget {
  const AssetInventoryView({super.key});

  @override
  State<AssetInventoryView> createState() => _AssetInventoryViewState();
}

class _AssetInventoryViewState extends State<AssetInventoryView> {
  final TextEditingController _searchController = TextEditingController();

  List<AssetModel> _assets = [];
  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedLocation = 'All';
  String _selectedCondition = 'All';
  String _statusTab = 'Active'; // 'Active' or 'Archived'

  AssetViewMode _viewMode = AssetViewMode.cards;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final assetsFuture = AssetService.getAssets(includeArchived: true);
      final locsFuture = AssetReferenceService.getLocations(activeOnly: false);
      final classifsFuture = AssetReferenceService.getClassifications(activeOnly: false);

      final results = await Future.wait([assetsFuture, locsFuture, classifsFuture]);

      if (!mounted) return;
      setState(() {
        _assets = results[0] as List<AssetModel>;
        _locations = results[1] as List<AssetLocationModel>;
        _classifications = results[2] as List<AssetClassificationModel>;
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

  List<AssetModel> get _filteredAssets {
    var list = _assets;

    // Filter by Active vs Archived
    if (_statusTab == 'Active') {
      list = list.where((a) => !a.isArchived).toList();
    } else {
      list = list.where((a) => a.isArchived).toList();
    }

    // Filter by Classification
    if (_selectedCategory != 'All') {
      list = list.where((a) => a.classificationAcronym.toUpperCase() == _selectedCategory.toUpperCase()).toList();
    }

    // Filter by Location
    if (_selectedLocation != 'All') {
      list = list.where((a) => a.locationAcronym.toUpperCase() == _selectedLocation.toUpperCase()).toList();
    }

    // Filter by Condition
    if (_selectedCondition != 'All') {
      list = list.where((a) => a.conditionStatus.toUpperCase() == _selectedCondition.toUpperCase()).toList();
    }

    // Search Query (Control #, Name, Model, Color, or Location)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((a) {
        return a.controlNumber.toLowerCase().contains(q) ||
            a.itemName.toLowerCase().contains(q) ||
            (a.model ?? '').toLowerCase().contains(q) ||
            (a.color ?? '').toLowerCase().contains(q) ||
            (a.rfidTag ?? '').toLowerCase().contains(q) ||
            a.displayLocation.toLowerCase().contains(q) ||
            a.displayClassification.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  int get _activeCount => _assets.where((a) => !a.isArchived).length;
  int get _archivedCount => _assets.where((a) => a.isArchived).length;
  int get _needsRepairCount => _assets.where((a) => !a.isArchived && a.conditionStatus.contains('REPAIR')).length;
  int get _missingCount => _assets.where((a) => !a.isArchived && a.conditionStatus.contains('MISSING')).length;

  Future<void> _printBatchStickers() async {
    final list = _filteredAssets;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assets available to print under current filter.')),
      );
      return;
    }

    try {
      await AssetLabelPdfService.printBatchAssetLabels(list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  void _openManageReferences() {
    showManageAssetReferencesModal(
      context,
      onReferencesUpdated: _loadAllData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    final filtered = _filteredAssets;
    final totalCount = filtered.length;
    final int totalPages = (totalCount / _rowsPerPage).ceil() > 0 ? (totalCount / _rowsPerPage).ceil() : 1;
    if (_currentPage >= totalPages) _currentPage = totalPages > 0 ? totalPages - 1 : 0;

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage > totalCount) ? totalCount : startIndex + _rowsPerPage;
    final paged = (startIndex >= totalCount) ? <AssetModel>[] : filtered.sublist(startIndex, endIndex);

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: ParishColors.marianBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parish Property & Asset Inventory',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    Text(
                      'Diocese of San Pablo • CustodiaIMS Asset Verification & NFC/QR Engine',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_suggest_outlined, color: ParishColors.marianBlue),
                      tooltip: 'Manage Locations & Classifications',
                      onPressed: _openManageReferences,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
                      tooltip: 'Reload Database Records',
                      onPressed: _loadAllData,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Top Primary Action Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return isWide
                    ? Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => showAuditScanModal(context, onScanCompleted: _loadAllData),
                          icon: const Icon(Icons.qr_code_scanner, size: 22),
                          label: const Text('Field Audit (QR / NFC)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.oliveGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => showRegisterAssetModal(context, onAssetSaved: _loadAllData),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Register Asset', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
                            foregroundColor: ParishColors.goldAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _printBatchStickers,
                          icon: const Icon(Icons.print_outlined, size: 20),
                          label: const Text('Batch Print Tags', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                )
                    : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => showAuditScanModal(context, onScanCompleted: _loadAllData),
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        label: const Text('Field Audit (QR / NFC)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ParishColors.oliveGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => showRegisterAssetModal(context, onAssetSaved: _loadAllData),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Register', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
                                foregroundColor: ParishColors.goldAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _printBatchStickers,
                              icon: const Icon(Icons.print_outlined, size: 16),
                              label: const Text('Print Tags', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // Statistics Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Active Inventory',
                    value: '$_activeCount',
                    icon: Icons.inventory_2,
                    color: ParishColors.marianBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Needs Repair',
                    value: '$_needsRepairCount',
                    icon: Icons.build_circle_outlined,
                    color: ParishColors.goldAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Missing Items',
                    value: '$_missingCount',
                    icon: Icons.help_outline,
                    color: ParishColors.mercyRed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Archived / Decom',
                    value: '$_archivedCount',
                    icon: Icons.archive_outlined,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Search Bar
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderGrey),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 22, color: ParishColors.marianBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _currentPage = 0;
                      }),
                      style: TextStyle(fontSize: 13.5, color: textDark),
                      decoration: InputDecoration(
                        hintText: 'Search by Control #, item name, model, color, RFID, or location...',
                        hintStyle: TextStyle(fontSize: 12.5, color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
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
            ),
            const SizedBox(height: 14),

            // Filter Dropdowns & Status Segmented Buttons
            Row(
              children: [
                // Active vs Archived Segments
                Container(
                  decoration: BoxDecoration(
                    color: ParishColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderGrey),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSegmentTab('Active', _statusTab == 'Active'),
                      _buildSegmentTab('Archived', _statusTab == 'Archived'),
                    ],
                  ),
                ),
                const Spacer(),

                // Location Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderGrey),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLocation,
                      isDense: true,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Locations')),
                        ..._locations.map((l) => DropdownMenuItem(value: l.acronym, child: Text('${l.acronym} - ${l.locationName}'))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedLocation = val;
                            _currentPage = 0;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Condition Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderGrey),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCondition,
                      isDense: true,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Conditions')),
                        DropdownMenuItem(value: 'VERIFIED / GOOD', child: Text('VERIFIED / GOOD')),
                        DropdownMenuItem(value: 'REQUIRES REPAIR', child: Text('REQUIRES REPAIR')),
                        DropdownMenuItem(value: 'DAMAGED', child: Text('DAMAGED')),
                        DropdownMenuItem(value: 'MISSING', child: Text('MISSING')),
                        DropdownMenuItem(value: 'UNUSABLE', child: Text('UNUSABLE')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCondition = val;
                            _currentPage = 0;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Classification Horizontal Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildClassificationChip('All', 'All Items'),
                  ..._classifications.map((c) => _buildClassificationChip(c.acronym, c.classificationName)),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // View Mode & Pagination Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_statusTab == "Active" ? "Active" : "Archived"} Parish Properties ($totalCount)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                ),
                Row(
                  children: [
                    ToggleButtons(
                      isSelected: [_viewMode == AssetViewMode.cards, _viewMode == AssetViewMode.table],
                      onPressed: (idx) => setState(() => _viewMode = idx == 0 ? AssetViewMode.cards : AssetViewMode.table),
                      borderRadius: BorderRadius.circular(8),
                      selectedColor: Colors.white,
                      fillColor: ParishColors.marianBlue,
                      color: textMuted,
                      constraints: const BoxConstraints(minHeight: 32, minWidth: 38),
                      children: const [
                        Tooltip(message: 'Card View', child: Icon(Icons.grid_view, size: 16)),
                        Tooltip(message: 'Table View', child: Icon(Icons.table_chart, size: 16)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content Area (Cards vs Table)
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: ParishColors.mercyRedSurface, borderRadius: BorderRadius.circular(12)),
                child: Text('Error loading inventory: $_errorMessage', style: const TextStyle(color: ParishColors.mercyRed)),
              )
            else if (totalCount == 0)
                _buildEmptyState()
              else if (_viewMode == AssetViewMode.cards)
                  ...paged.map((a) => AssetItemCard(asset: a, onRefresh: _loadAllData))
                else
                  _buildTableView(paged),

            const SizedBox(height: 16),

            // Pagination Controls Footer
            if (totalCount > 0) _buildPaginationFooter(totalCount, totalPages, startIndex, endIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentTab(String title, bool isSelected) {
    return InkWell(
      onTap: () => setState(() {
        _statusTab = title;
        _currentPage = 0;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? ParishColors.marianBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : ParishColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildClassificationChip(String acronym, String label) {
    final isSelected = _selectedCategory == acronym;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: ParishColors.marianBlue,
        backgroundColor: ParishColors.cardWhite,
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : ParishColors.textDark,
        ),
        onSelected: (_) => setState(() {
          _selectedCategory = acronym;
          _currentPage = 0;
        }),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.textMuted), maxLines: 1),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTableView(List<AssetModel> assets) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(ParishColors.marianBlueSurface),
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 13),
          dataTextStyle: TextStyle(fontSize: 12.5, color: ParishColors.textDark),
          columns: const [
            DataColumn(label: Text('Control Number')),
            DataColumn(label: Text('Asset Name')),
            DataColumn(label: Text('Classification')),
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('Acq. Year')),
            DataColumn(label: Text('Cost (₱)')),
            DataColumn(label: Text('Condition')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: assets.map((a) {
            return DataRow(cells: [
              DataCell(Text(a.controlNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue))),
              DataCell(Text(a.itemName, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(a.displayClassification)),
              DataCell(Text(a.displayLocation)),
              DataCell(Text('${a.acquisitionYear}')),
              DataCell(Text(a.cost.toStringAsFixed(2))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: a.conditionSurfaceColor, borderRadius: BorderRadius.circular(4)),
                  child: Text(a.conditionStatus, style: TextStyle(color: a.conditionColor, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ),
              DataCell(Text(a.operationalStatus)),
              DataCell(
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => showAssetDetailModal(context, asset: a, onAssetUpdated: _loadAllData),
                  icon: const Icon(Icons.visibility, size: 14),
                  label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(int totalCount, int totalPages, int startIndex, int endIndex) {
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final textMuted = ParishColors.textMuted;
    final textDark = ParishColors.textDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGrey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalCount properties',
            style: TextStyle(fontSize: 12, color: textMuted),
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
                'Page ${_currentPage + 1} of $totalPages',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
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
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: ParishColors.borderGrey),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ? 'No registered assets match your search.' : 'No assets registered under this category yet.',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.textDark),
          ),
          const SizedBox(height: 4),
          Text('Tap "Register Asset" above to add diocesan church property.', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
        ],
      ),
    );
  }
}