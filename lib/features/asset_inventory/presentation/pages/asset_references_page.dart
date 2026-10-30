// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_references_page.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_reference_models.dart';
import '../../services/asset_reference_service.dart';

class AssetReferencesPage extends StatefulWidget {
  final VoidCallback? onReferencesUpdated;

  const AssetReferencesPage({super.key, this.onReferencesUpdated});

  @override
  State<AssetReferencesPage> createState() => _AssetReferencesPageState();
}

class _AssetReferencesPageState extends State<AssetReferencesPage> with SingleTickerProviderStateMixin {
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
      final classifs = await AssetReferenceService.getClassifications(activeOnly: false);
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
    final nameController = TextEditingController(text: itemToEdit?.locationName ?? '');
    final acronymController = TextEditingController(text: itemToEdit?.acronym ?? '');
    final descController = TextEditingController(text: itemToEdit?.description ?? '');
    bool isActive = itemToEdit?.isActive ?? true;
    final isEdit = itemToEdit != null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Edit Location' : 'Add New Location', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: acronymController,
                    enabled: !isEdit,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Acronym * (e.g. C, S, PEAC)', border: OutlineInputBorder()),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Acronym is required.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Location Name * (e.g. Church)', border: OutlineInputBorder()),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Location name is required.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: isActive,
                      onChanged: (val) => setModalState(() => isActive = val),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final nameController = TextEditingController(text: itemToEdit?.classificationName ?? '');
    final acronymController = TextEditingController(text: itemToEdit?.acronym ?? '');
    final descController = TextEditingController(text: itemToEdit?.description ?? '');
    bool isActive = itemToEdit?.isActive ?? true;
    final isEdit = itemToEdit != null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Edit Classification' : 'Add New Classification', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: acronymController,
                    enabled: !isEdit,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Acronym * (e.g. SI, SV, FF)', border: OutlineInputBorder()),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Acronym is required.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Classification Name * (e.g. Sacred Image)', border: OutlineInputBorder()),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Classification name is required.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: isActive,
                      onChanged: (val) => setModalState(() => isActive = val),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(isEdit ? 'Update' : 'Save Classification'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final cardWhite = ParishColors.cardWhite;
    final textMuted = ParishColors.textMuted;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Locations & Classifications Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            Text('Master reference data used to auto-generate diocesan control numbers',
                style: TextStyle(fontSize: 12, color: textMuted)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: ParishColors.marianBlue,
          indicatorColor: ParishColors.marianBlue,
          tabs: [
            Tab(text: 'Locations (${_locations.length})'),
            Tab(text: 'Classifications (${_classifications.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed)))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildLocationsList(),
          _buildClassificationsList(),
        ],
      ),
    );
  }

  Widget _buildLocationsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Parish Storage Locations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: ParishColors.oliveGreen, foregroundColor: Colors.white),
                onPressed: () => _openLocationFormDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Location'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _locations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final loc = _locations[idx];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: ParishColors.marianBlueSurface, borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        child: Text(loc.acronym, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.locationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (loc.description != null && loc.description!.isNotEmpty)
                            Text(loc.description!, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: ParishColors.marianBlue),
                      onPressed: () => _openLocationFormDialog(loc),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Property Classifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: ParishColors.oliveGreen, foregroundColor: Colors.white),
                onPressed: () => _openClassificationFormDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Classification'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _classifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final cls = _classifications[idx];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        child: Text(cls.acronym, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cls.classificationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (cls.description != null && cls.description!.isNotEmpty)
                            Text(cls.description!, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: ParishColors.marianBlue),
                      onPressed: () => _openClassificationFormDialog(cls),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}