// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/sacrament_drafts_page.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/sacramental_draft_model.dart';
import '../../services/sacramental_draft_service.dart';
import '../widgets/sacramental_loading_overlay.dart';
import 'baptism_manual_entry_page.dart';
import 'confirmation_manual_entry_page.dart';
import 'conversion_manual_entry_page.dart';
import 'death_manual_entry_page.dart';
import 'first_communion_manual_entry_page.dart';
import 'matrimony_manual_entry_page.dart';

class SacramentDraftsPage extends StatefulWidget {
  final String sacramentName;
  final Color themeColor;
  final Color surfaceColor;
  final IconData icon;

  const SacramentDraftsPage({
    super.key,
    required this.sacramentName,
    required this.themeColor,
    required this.surfaceColor,
    required this.icon,
  });

  @override
  State<SacramentDraftsPage> createState() => _SacramentDraftsPageState();
}

class _SacramentDraftsPageState extends State<SacramentDraftsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<SacramentalDraftModel> _drafts = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _loadingMessage = 'Processing draft...';
  String? _errorMessage;
  String _searchQuery = '';
  bool _didModifyCanonicalRecords = false;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await SacramentalDraftService.getDraftsForSacrament(
        widget.sacramentName,
      );
      if (!mounted) return;
      setState(() {
        _drafts = list;
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

  List<SacramentalDraftModel> get _filteredDrafts {
    if (_searchQuery.trim().isEmpty) return _drafts;
    final q = _searchQuery.trim().toLowerCase();
    return _drafts.where((d) {
      final titleMatch = d.displayTitle.toLowerCase().contains(q);
      final refMatch = (d.bookReference ?? '').toLowerCase().contains(q);
      final idMatch = d.draftId.toLowerCase().contains(q);
      return titleMatch || refMatch || idMatch;
    }).toList();
  }

  Future<void> _resumeDraft(SacramentalDraftModel draft) async {
    Widget? entryPage;

    switch (widget.sacramentName) {
      case 'Baptism':
        entryPage = BaptismManualEntryPage(
          draftId: draft.draftId,
          initialDraftData: draft.draftData,
          onRecordSaved: () => _didModifyCanonicalRecords = true,
        );
        break;
      case 'Confirmation':
        entryPage = ConfirmationManualEntryPage(
          draftId: draft.draftId,
          initialDraftData: draft.draftData,
          onRecordSaved: () => _didModifyCanonicalRecords = true,
        );
        break;
      case 'First Communion':
        entryPage = FirstCommunionManualEntryPage(
          draftId: draft.draftId,
          initialDraftData: draft.draftData,
          onRecordSaved: () => _didModifyCanonicalRecords = true,
        );
        break;
      case 'Matrimony':
        entryPage = MatrimonyManualEntryPage(
          draftId: draft.draftId,
          initialDraftData: draft.draftData,
          onRecordSaved: () => _didModifyCanonicalRecords = true,
        );
        break;
      case 'Death':
        entryPage = DeathManualEntryPage(
          draftId: draft.draftId,
          initialDraftData: draft.draftData,
          onRecordSaved: () => _didModifyCanonicalRecords = true,
        );
        break;
      case 'Conversion':
        entryPage = ConversionManualEntryPage(
          draftId: draft.draftId,
          initialDraftData: draft.draftData,
          onRecordSaved: () => _didModifyCanonicalRecords = true,
        );
        break;
    }

    if (entryPage == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => entryPage!),
    );

    if (mounted) {
      _loadDrafts();
    }
  }

  Future<void> _confirmAndDeleteDraft(SacramentalDraftModel draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: ParishColors.mercyRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Delete Saved Draft?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
              ),
            ),
          ],
        ),
        content: Text(
          'Permanently discard "${draft.displayTitle}"? Unsaved progress stored in this draft will be lost.',
          style: TextStyle(
            fontSize: 13.5,
            color: ParishColors.textDark.withOpacity(0.85),
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 17),
            label: const Text('Delete Draft'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _loadingMessage = 'Deleting ${widget.sacramentName.toLowerCase()} draft...';
    });

    try {
      await SacramentalDraftService.deleteDraft(draft.draftId);
      if (!mounted) return;

      setState(() {
        _drafts.removeWhere((d) => d.draftId == draft.draftId);
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draft "${draft.displayTitle}" deleted.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting draft: $e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final date = local.toIso8601String().substring(0, 10);
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$date • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final filtered = _filteredDrafts;

    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: SacramentalLoadingOverlay(
        isLoading: _isProcessing,
        message: _loadingMessage,
        accentColor: widget.themeColor,
        icon: widget.icon,
        child: Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: widget.themeColor, size: 26),
              onPressed: () =>
                  Navigator.pop(context, _didModifyCanonicalRecords),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.sacramentName} Drafts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                Text(
                  'Saved incomplete manual entries awaiting completion',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: widget.themeColor),
                tooltip: 'Reload Drafts',
                onPressed: _isLoading ? null : _loadDrafts,
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth >= 900;
                final bool isMobile = constraints.maxWidth < 650;

                return RefreshIndicator(
                  onRefresh: _loadDrafts,
                  color: widget.themeColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 26,
                      vertical: 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Banner
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: widget.surfaceColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: widget.themeColor.withOpacity(0.35),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: widget.themeColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.drafts_outlined,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${widget.sacramentName} Drafts (${_drafts.length})',
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.bold,
                                            color: widget.themeColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Select a saved draft below to resume encoding or delete drafts no longer needed.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textDark.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Search Bar
                            Container(
                              height: 46,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: cardWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderGrey),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.search,
                                      size: 20, color: widget.themeColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) => setState(
                                            () => _searchQuery = val,
                                      ),
                                      style: TextStyle(
                                          fontSize: 13.5, color: textDark),
                                      decoration: InputDecoration(
                                        hintText:
                                        'Search drafts by name, reference, or ID...',
                                        hintStyle: TextStyle(
                                            fontSize: 12.5, color: textMuted),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 17),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Content
                            if (_isLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: ParishColors.mercyRedSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                  Border.all(color: ParishColors.mercyRed),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: ParishColors.mercyRed),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: ParishColors.mercyRed,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loadDrafts,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            else if (filtered.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(36),
                                  decoration: BoxDecoration(
                                    color: cardWhite,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderGrey),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.drafts_outlined,
                                        size: 46,
                                        color: textMuted,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No drafts match "$_searchQuery".'
                                            : 'No saved ${widget.sacramentName.toLowerCase()} drafts yet.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Use "Save to Draft" in the header of any manual entry form to save progress for later.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12.5, color: textMuted),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isDesktop)
                                  LayoutBuilder(
                                    builder: (context, gridConstraints) {
                                      final itemWidth =
                                          (gridConstraints.maxWidth - 14) / 2;
                                      return Wrap(
                                        spacing: 14,
                                        runSpacing: 14,
                                        children: filtered
                                            .map(
                                              (d) => SizedBox(
                                            width: itemWidth,
                                            child: _buildDraftCard(
                                                d, textDark, textMuted),
                                          ),
                                        )
                                            .toList(),
                                      );
                                    },
                                  )
                                else
                                  Column(
                                    children: filtered
                                        .map(
                                          (d) => Padding(
                                        padding:
                                        const EdgeInsets.only(bottom: 12),
                                        child: _buildDraftCard(
                                            d, textDark, textMuted),
                                      ),
                                    )
                                        .toList(),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftCard(
      SacramentalDraftModel draft,
      Color textDark,
      Color textMuted,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.themeColor.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.themeColor.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _resumeDraft(draft),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.surfaceColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DRAFT',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: widget.themeColor,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        draft.bookReference?.isNotEmpty == true
                            ? draft.bookReference!
                            : draft.draftId,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  draft.displayTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Last saved: ${_formatDateTime(draft.updatedAt)}',
                        style: TextStyle(fontSize: 12, color: textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.themeColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          onPressed: () => _resumeDraft(draft),
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text(
                            'Resume Entry',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      width: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: ParishColors.mercyRed,
                          side: BorderSide(
                            color: ParishColors.mercyRed.withOpacity(0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        onPressed: () => _confirmAndDeleteDraft(draft),
                        child: const Icon(Icons.delete_outline, size: 19),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}