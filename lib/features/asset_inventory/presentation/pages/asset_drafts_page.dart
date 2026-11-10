// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_drafts_page.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_draft_model.dart';
import '../../services/asset_draft_service.dart';
import 'register_asset_page.dart';

class AssetDraftsPage extends StatefulWidget {
  final VoidCallback? onAssetSaved;

  const AssetDraftsPage({super.key, this.onAssetSaved});

  @override
  State<AssetDraftsPage> createState() => _AssetDraftsPageState();
}

class _AssetDraftsPageState extends State<AssetDraftsPage> {
  List<AssetDraftModel> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    final drafts = await AssetDraftService.getAllDrafts();
    if (!mounted) return;
    setState(() {
      _drafts = drafts;
      _isLoading = false;
    });
  }

  Future<void> _deleteDraft(AssetDraftModel draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Registration Draft?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ParishColors.textDark,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to discard the cloud draft for "${draft.itemName.isNotEmpty ? draft.itemName : draft.fullControlNumber}"? '
              'This will remove it from all devices.',
          style: TextStyle(fontSize: 13, color: ParishColors.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ParishColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Draft'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AssetDraftService.deleteDraft(draft.draftId);
      await _loadDrafts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Cloud draft deleted.'),
          backgroundColor: ParishColors.textMuted,
        ),
      );
    }
  }

  Future<void> _clearAllDrafts() async {
    if (_drafts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear All Saved Drafts?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ParishColors.textDark,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to discard all ${_drafts.length} cloud registration drafts? This cannot be undone.',
          style: TextStyle(fontSize: 13, color: ParishColors.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ParishColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AssetDraftService.clearAllDrafts();
      await _loadDrafts();
    }
  }

  void _resumeRegistration(AssetDraftModel draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterAssetPage(
          initialDraft: draft,
          onAssetSaved: () {
            _loadDrafts();
            widget.onAssetSaved?.call();
          },
        ),
      ),
    ).then((_) => _loadDrafts());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: ParishColors.cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cloud Asset Drafts',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                Text(
                  'Synchronized across all parish phones, tablets, and laptops',
                  style: TextStyle(
                    fontSize: isMobile ? 10.5 : 12,
                    color: ParishColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              if (_drafts.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearAllDrafts,
                  icon: const Icon(Icons.delete_sweep_outlined,
                      size: 16, color: ParishColors.mercyRed),
                  label: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: isMobile ? 11.5 : 12.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.mercyRed,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _drafts.isEmpty
              ? _buildEmptyState(isMobile)
              : RefreshIndicator(
            onRefresh: _loadDrafts,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: isMobile ? 14 : 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDraftsHeader(isMobile),
                      const SizedBox(height: 14),
                      ..._drafts
                          .map((d) => _buildDraftCard(d, isMobile)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraftsHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined,
                  size: 18, color: ParishColors.marianBlue),
              const SizedBox(width: 8),
              Text(
                '${_drafts.length} Cloud Registration Draft(s)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: ParishColors.textDark,
                ),
              ),
            ],
          ),
          Text(
            'Synced via Supabase',
            style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(AssetDraftModel draft, bool isMobile) {
    final bool hasCloudPhoto =
        draft.photoUrl != null && draft.photoUrl!.isNotEmpty;
    final bool hasLocalPhoto =
        draft.localPhotoBytes != null && draft.localPhotoBytes!.isNotEmpty;
    final bool hasAnyPhoto = hasCloudPhoto || hasLocalPhoto;
    final List<String> missing = draft.missingChecklist;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail (Cloud Network Image or Local In-Memory Fallback)
              Container(
                width: isMobile ? 54 : 64,
                height: isMobile ? 54 : 64,
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasAnyPhoto
                        ? ParishColors.goldAccent
                        : ParishColors.borderGrey,
                    width: hasAnyPhoto ? 1.4 : 1.0,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: hasCloudPhoto
                      ? Image.network(
                    draft.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image_outlined,
                      size: 24,
                      color: ParishColors.textMuted.withOpacity(0.6),
                    ),
                  )
                      : hasLocalPhoto
                      ? Image.memory(draft.localPhotoBytes!,
                      fit: BoxFit.cover)
                      : Icon(
                    Icons.image_not_supported_outlined,
                    size: 24,
                    color: ParishColors.textMuted.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title, Control # and Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ParishColors.goldLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: ParishColors.goldAccent.withOpacity(0.6),
                            ),
                          ),
                          child: Text(
                            draft.fullControlNumber,
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.goldAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${draft.quantity} unit(s)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.marianBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.itemName.trim().isNotEmpty
                          ? draft.itemName
                          : 'Untitled Draft Entry',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15.5,
                        fontWeight: FontWeight.bold,
                        color: draft.itemName.trim().isNotEmpty
                            ? ParishColors.textDark
                            : ParishColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Category: ${draft.classificationAcronym} • Location: ${draft.locationAcronym} • Mode: ${draft.modeOfAcquisition}',
                      style: TextStyle(
                          fontSize: 11, color: ParishColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Missing Checklist Tags
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (missing.isEmpty)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ParishColors.oliveGreenSurface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: ParishColors.oliveGreen.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 12, color: ParishColors.oliveGreen),
                      SizedBox(width: 4),
                      Text(
                        'Ready to Register',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.oliveGreen,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...missing.map(
                      (m) => Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: Text(
                      '⚠️ Needs $m',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 18),

          // Bottom Bar: Last Updated & Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Updated: ${draft.formattedUpdatedAt}',
                style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: ParishColors.mercyRed),
                    tooltip: 'Discard Draft',
                    onPressed: () => _deleteDraft(draft),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _resumeRegistration(draft),
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text(
                      'Resume',
                      style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_outlined,
                size: 48, color: ParishColors.textMuted.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(
              'No Saved Cloud Drafts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ParishColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use the "Save as Cloud Draft" button during item registration to store incomplete work across devices.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}