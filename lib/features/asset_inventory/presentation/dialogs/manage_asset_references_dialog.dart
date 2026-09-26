import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_reference_models.dart';
import '../../services/asset_reference_service.dart';

void showManageAssetReferencesModal(
    BuildContext context, {
      VoidCallback? onReferencesUpdated,
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ManageAssetReferencesDialog(
      onReferencesUpdated: onReferencesUpdated,
    ),
  );
}

class _ManageAssetReferencesDialog extends StatefulWidget {
  final VoidCallback? onReferencesUpdated;

  const _ManageAssetReferencesDialog({this.onReferencesUpdated});

  @override
  State<_ManageAssetReferencesDialog> createState() =>
      _ManageAssetReferencesDialogState();
}

class _ManageAssetReferencesDialogState
    extends State<_ManageAssetReferencesDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReferences();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final locs = await AssetReferenceService.getLocations(activeOnly: false);
      final classifs =
      await AssetReferenceService.getClassifications(activeOnly: false);

      if (!mounted) return;
      setState(() {
        _locations = locs;
        _classifications = classifs;
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

  void _openLocationFormDialog([AssetLocationModel? itemToEdit]) {
    final nameController =
    TextEditingController(text: itemToEdit?.locationName ?? '');
    final acronymController =
    TextEditingController(text: itemToEdit?.acronym ?? '');
    final descController =
    TextEditingController(text: itemToEdit?.description ?? '');
    bool isActive = itemToEdit?.isActive ?? true;
    final bool isEdit = itemToEdit != null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEdit ? 'Edit Diocesan Location' : 'Add New Parish Location',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: acronymController,
                      enabled: !isEdit,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Location Acronym *',
                        hintText: 'e.g. C, S, O, PEAC',
                        helperText: isEdit
                            ? 'Acronym is locked to protect control numbers.'
                            : 'Short uppercase code used in Control #',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return 'Acronym is required.';
                        if (text.length > 8) return 'Max 8 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Location Name *',
                        hintText: 'e.g. Sacred Heart Chapel',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Location name is required.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: ParishColors.oliveGreen,
                        title: const Text('Active Status',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        value: isActive,
                        onChanged: (val) =>
                            setModalState(() => isActive = val),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  if (isEdit) {
                    await AssetReferenceService.updateLocation(
                      locationId: itemToEdit.locationId,
                      locationName: nameController.text.trim(),
                      description: descController.text.trim(),
                      isActive: isActive,
                    );
                  } else {
                    await AssetReferenceService.createLocation(
                      acronym: acronymController.text.trim(),
                      locationName: nameController.text.trim(),
                      description: descController.text.trim(),
                    );
                  }
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadReferences();
                  widget.onReferencesUpdated?.call();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: ParishColors.mercyRed,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Save Location'),
            ),
          ],
        ),
      ),
    );
  }

  void _openClassificationFormDialog([AssetClassificationModel? itemToEdit]) {
    final nameController =
    TextEditingController(text: itemToEdit?.classificationName ?? '');
    final acronymController =
    TextEditingController(text: itemToEdit?.acronym ?? '');
    final descController =
    TextEditingController(text: itemToEdit?.description ?? '');
    bool isActive = itemToEdit?.isActive ?? true;
    final bool isEdit = itemToEdit != null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEdit
                ? 'Edit Asset Classification'
                : 'Add New Asset Classification',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: acronymController,
                      enabled: !isEdit,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Classification Acronym *',
                        hintText: 'e.g. SI, SV, MI, LB, FF',
                        helperText: isEdit
                            ? 'Acronym is locked to protect control numbers.'
                            : 'Short uppercase code used in Control #',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return 'Acronym is required.';
                        if (text.length > 8) return 'Max 8 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Classification Name *',
                        hintText: 'e.g. Audio-Visual Equipment',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Classification name is required.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: ParishColors.oliveGreen,
                        title: const Text('Active Status',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        value: isActive,
                        onChanged: (val) =>
                            setModalState(() => isActive = val),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  if (isEdit) {
                    await AssetReferenceService.updateClassification(
                      classificationId: itemToEdit.classificationId,
                      classificationName: nameController.text.trim(),
                      description: descController.text.trim(),
                      isActive: isActive,
                    );
                  } else {
                    await AssetReferenceService.createClassification(
                      acronym: acronymController.text.trim(),
                      classificationName: nameController.text.trim(),
                      description: descController.text.trim(),
                    );
                  }
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadReferences();
                  widget.onReferencesUpdated?.call();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: ParishColors.mercyRed,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Save Classification'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLocation(AssetLocationModel loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Location?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove "${loc.locationName}" (${loc.acronym})? '
              'Deletion will be blocked if any registered parish assets are assigned to this location.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.mercyRed,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AssetReferenceService.deleteLocation(
            loc.locationId, loc.acronym);
        _loadReferences();
        widget.onReferencesUpdated?.call();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$e'), backgroundColor: ParishColors.mercyRed),
        );
      }
    }
  }

  Future<void> _confirmDeleteClassification(
      AssetClassificationModel cls) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Classification?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove "${cls.classificationName}" (${cls.acronym})? '
              'Deletion will be blocked if any registered parish assets belong to this category.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.mercyRed,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AssetReferenceService.deleteClassification(
            cls.classificationId, cls.acronym);
        _loadReferences();
        widget.onReferencesUpdated?.call();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$e'), backgroundColor: ParishColors.mercyRed),
        );
      }
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
        width: 760,
        constraints: const BoxConstraints(maxHeight: 740),
        child: Column(
          children: [
            // Header
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
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
                    child: const Icon(Icons.settings_suggest,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diocesan Locations & Classifications',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textDark),
                        ),
                        Text(
                          'Configure reference data for automatic control number generation and inventory sorting',
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

            // Tab Bar
            Container(
              color: cardWhite,
              child: TabBar(
                controller: _tabController,
                labelColor: ParishColors.marianBlue,
                unselectedLabelColor: textMuted,
                indicatorColor: ParishColors.marianBlue,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.location_on_outlined, size: 18),
                    text: 'Locations (${_locations.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.category_outlined, size: 18),
                    text: 'Classifications (${_classifications.length})',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                child: Text(_errorMessage!,
                    style: const TextStyle(
                        color: ParishColors.mercyRed)),
              )
                  : TabBarView(
                controller: _tabController,
                children: [
                  _buildLocationsTab(),
                  _buildClassificationsTab(),
                ],
              ),
            ),

            // Footer
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close',
                        style: TextStyle(
                            color: textMuted, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Diocesan Storage Locations & Zones',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.oliveGreen,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openLocationFormDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Location',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _locations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final loc = _locations[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: loc.isActive
                      ? ParishColors.cardWhite
                      : ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: loc.isActive
                            ? ParishColors.marianBlueSurface
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          loc.acronym,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: loc.isActive
                                ? ParishColors.marianBlue
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                loc.locationName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: loc.isActive
                                      ? ParishColors.textDark
                                      : ParishColors.textMuted,
                                ),
                              ),
                              if (!loc.isActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ParishColors.mercyRedSurface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('INACTIVE',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: ParishColors.mercyRed)),
                                ),
                              ],
                            ],
                          ),
                          if (loc.description != null)
                            Text(
                              loc.description!,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: ParishColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: ParishColors.marianBlue),
                      onPressed: () => _openLocationFormDialog(loc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: ParishColors.mercyRed),
                      onPressed: () => _confirmDeleteLocation(loc),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassificationsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Diocesan Property Classifications',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.oliveGreen,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openClassificationFormDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Classification',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _classifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cls = _classifications[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cls.isActive
                      ? ParishColors.cardWhite
                      : ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cls.isActive
                            ? ParishColors.goldLight
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          cls.acronym,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: cls.isActive
                                ? ParishColors.goldAccent
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                cls.classificationName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cls.isActive
                                      ? ParishColors.textDark
                                      : ParishColors.textMuted,
                                ),
                              ),
                              if (!cls.isActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ParishColors.mercyRedSurface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('INACTIVE',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: ParishColors.mercyRed)),
                                ),
                              ],
                            ],
                          ),
                          if (cls.description != null)
                            Text(
                              cls.description!,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: ParishColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: ParishColors.marianBlue),
                      onPressed: () => _openClassificationFormDialog(cls),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: ParishColors.mercyRed),
                      onPressed: () => _confirmDeleteClassification(cls),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}