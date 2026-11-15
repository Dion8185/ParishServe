// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_references_page.dart
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_reference_models.dart';
import '../../services/asset_reference_service.dart';
import '../widgets/asset_confirmation_dialog.dart';
import '../widgets/asset_loading_overlay.dart';

class AssetReferencesPage extends StatefulWidget {
  final VoidCallback? onReferencesUpdated;

  const AssetReferencesPage({super.key, this.onReferencesUpdated});

  @override
  State<AssetReferencesPage> createState() => _AssetReferencesPageState();
}

class _AssetReferencesPageState extends State<AssetReferencesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String _busyMessage = 'Please wait...';
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
    final isEdit = itemToEdit != null;
    final formKey = GlobalKey<FormState>();

    bool isFormDirty() {
      if (isEdit) {
        if (nameController.text.trim() != itemToEdit.locationName) return true;
        if (descController.text.trim() != (itemToEdit.description ?? '')) {
          return true;
        }
        if (isActive != itemToEdit.isActive) return true;
        return false;
      } else {
        return acronymController.text.trim().isNotEmpty ||
            nameController.text.trim().isNotEmpty ||
            descController.text.trim().isNotEmpty;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (isFormDirty()) {
              final discard =
              await showUnsavedChangesConfirmationDialog(ctx);
              if (discard && ctx.mounted) {
                Navigator.pop(ctx);
              }
            } else {
              Navigator.pop(ctx);
            }
          },
          child: StatefulBuilder(
            builder: (context, setModalState) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: ParishColors.cardWhite,
              title: Text(
                isEdit ? 'Edit Location' : 'Add New Location',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ParishColors.textDark,
                ),
              ),
              content: ConstrainedBox(
                constraints:
                BoxConstraints(maxWidth: min(screenWidth - 48, 440)),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: acronymController,
                          enabled: !isEdit,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ParishColors.textDark,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Acronym * (e.g. C, S, PEAC)',
                            labelStyle:
                            TextStyle(color: ParishColors.textDark),
                            hintText: 'e.g. C, S, PEAC',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: ParishColors.textMuted,
                            ),
                            helperText: isEdit
                                ? 'Acronym is locked to protect control numbers.'
                                : 'Short uppercase code used in Control #',
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: ParishColors.borderGrey),
                            ),
                          ),
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Acronym is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          style: TextStyle(
                            fontSize: 14,
                            color: ParishColors.textDark,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Location Name * (e.g. Church)',
                            labelStyle:
                            TextStyle(color: ParishColors.textDark),
                            hintText: 'e.g. Church Main Nave',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: ParishColors.textMuted,
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: ParishColors.borderGrey),
                            ),
                          ),
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Location name is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 13,
                            color: ParishColors.textDark,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            labelStyle:
                            TextStyle(color: ParishColors.textDark),
                            hintText:
                            'e.g. Main church sanctuary and altar area',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: ParishColors.textMuted,
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: ParishColors.borderGrey),
                            ),
                          ),
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: ParishColors.oliveGreen,
                            title: const Text(
                              'Active Status',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                  onPressed: () async {
                    if (isFormDirty()) {
                      final discard =
                      await showUnsavedChangesConfirmationDialog(ctx);
                      if (discard && ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                    } else {
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: ParishColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final confirmed =
                    await showAssetActionConfirmationDialog(
                      ctx,
                      title: isEdit ? 'Update Location?' : 'Add New Location?',
                      message: isEdit
                          ? 'Commit updates to location "${nameController.text.trim()}" (${itemToEdit.acronym})?'
                          : 'Register "${nameController.text.trim()}" (${acronymController.text.trim().toUpperCase()}) as an official parish storage location?',
                      confirmLabel: isEdit ? 'Update' : 'Save Location',
                      icon: isEdit
                          ? Icons.edit_outlined
                          : Icons.add_location_alt_outlined,
                      accentColor: ParishColors.marianBlue,
                    );

                    if (!confirmed) return;

                    Navigator.pop(ctx);

                    setState(() {
                      _isBusy = true;
                      _busyMessage = isEdit
                          ? 'Updating location record...'
                          : 'Saving new location...';
                    });

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
                      await _loadReferences();
                      widget.onReferencesUpdated?.call();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit
                              ? 'Location updated successfully.'
                              : 'Location added successfully.'),
                          backgroundColor: ParishColors.oliveGreen,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: ParishColors.mercyRed,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isBusy = false);
                    }
                  },
                  child: Text(isEdit ? 'Update' : 'Save Location'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openClassificationFormDialog(
      [AssetClassificationModel? itemToEdit]) {
    final nameController =
    TextEditingController(text: itemToEdit?.classificationName ?? '');
    final acronymController =
    TextEditingController(text: itemToEdit?.acronym ?? '');
    final descController =
    TextEditingController(text: itemToEdit?.description ?? '');
    bool isActive = itemToEdit?.isActive ?? true;
    final isEdit = itemToEdit != null;
    final formKey = GlobalKey<FormState>();

    bool isFormDirty() {
      if (isEdit) {
        if (nameController.text.trim() != itemToEdit.classificationName) {
          return true;
        }
        if (descController.text.trim() != (itemToEdit.description ?? '')) {
          return true;
        }
        if (isActive != itemToEdit.isActive) return true;
        return false;
      } else {
        return acronymController.text.trim().isNotEmpty ||
            nameController.text.trim().isNotEmpty ||
            descController.text.trim().isNotEmpty;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (isFormDirty()) {
              final discard =
              await showUnsavedChangesConfirmationDialog(ctx);
              if (discard && ctx.mounted) {
                Navigator.pop(ctx);
              }
            } else {
              Navigator.pop(ctx);
            }
          },
          child: StatefulBuilder(
            builder: (context, setModalState) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: ParishColors.cardWhite,
              title: Text(
                isEdit ? 'Edit Classification' : 'Add New Classification',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ParishColors.textDark,
                ),
              ),
              content: ConstrainedBox(
                constraints:
                BoxConstraints(maxWidth: min(screenWidth - 48, 440)),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: acronymController,
                          enabled: !isEdit,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ParishColors.textDark,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Acronym * (e.g. SI, SV, FF)',
                            labelStyle:
                            TextStyle(color: ParishColors.textDark),
                            hintText: 'e.g. SI, SV, FF',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: ParishColors.textMuted,
                            ),
                            helperText: isEdit
                                ? 'Acronym is locked to protect control numbers.'
                                : 'Short uppercase code used in Control #',
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: ParishColors.borderGrey),
                            ),
                          ),
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Acronym is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          style: TextStyle(
                            fontSize: 14,
                            color: ParishColors.textDark,
                          ),
                          decoration: InputDecoration(
                            labelText:
                            'Classification Name * (e.g. Sacred Image)',
                            labelStyle:
                            TextStyle(color: ParishColors.textDark),
                            hintText: 'e.g. Sacred Image',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: ParishColors.textMuted,
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: ParishColors.borderGrey),
                            ),
                          ),
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Classification name is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 13,
                            color: ParishColors.textDark,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            labelStyle:
                            TextStyle(color: ParishColors.textDark),
                            hintText:
                            'e.g. Statues, sacred representations and icons',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: ParishColors.textMuted,
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                              BorderSide(color: ParishColors.borderGrey),
                            ),
                          ),
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: ParishColors.oliveGreen,
                            title: const Text(
                              'Active Status',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                  onPressed: () async {
                    if (isFormDirty()) {
                      final discard =
                      await showUnsavedChangesConfirmationDialog(ctx);
                      if (discard && ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                    } else {
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: ParishColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final confirmed =
                    await showAssetActionConfirmationDialog(
                      ctx,
                      title: isEdit
                          ? 'Update Classification?'
                          : 'Add New Classification?',
                      message: isEdit
                          ? 'Commit updates to classification "${nameController.text.trim()}" (${itemToEdit.acronym})?'
                          : 'Register "${nameController.text.trim()}" (${acronymController.text.trim().toUpperCase()}) as an official asset classification?',
                      confirmLabel:
                      isEdit ? 'Update' : 'Save Classification',
                      icon: isEdit
                          ? Icons.edit_outlined
                          : Icons.category_outlined,
                      accentColor: ParishColors.marianBlue,
                    );

                    if (!confirmed) return;

                    Navigator.pop(ctx);

                    setState(() {
                      _isBusy = true;
                      _busyMessage = isEdit
                          ? 'Updating classification record...'
                          : 'Saving new classification...';
                    });

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
                      await _loadReferences();
                      widget.onReferencesUpdated?.call();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit
                              ? 'Classification updated successfully.'
                              : 'Classification added successfully.'),
                          backgroundColor: ParishColors.oliveGreen,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: ParishColors.mercyRed,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isBusy = false);
                    }
                  },
                  child: Text(isEdit ? 'Update' : 'Save Classification'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteLocation(AssetLocationModel loc) async {
    final confirmed = await showAssetActionConfirmationDialog(
      context,
      title: 'Delete Location?',
      message:
      'Are you sure you want to remove "${loc.locationName}" (${loc.acronym})? Deletion will be blocked if any registered parish assets are assigned to this location.',
      itemIdentifier: '${loc.acronym} • ${loc.locationName}',
      confirmLabel: 'Delete Location',
      icon: Icons.delete_forever_outlined,
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _isBusy = true;
      _busyMessage = 'Deleting location...';
    });

    try {
      await AssetReferenceService.deleteLocation(
          loc.locationId, loc.acronym);
      if (!mounted) return;
      await _loadReferences();
      widget.onReferencesUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location deleted successfully.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteClassification(AssetClassificationModel cls) async {
    final confirmed = await showAssetActionConfirmationDialog(
      context,
      title: 'Delete Classification?',
      message:
      'Are you sure you want to remove "${cls.classificationName}" (${cls.acronym})? Deletion will be blocked if any registered parish assets belong to this category.',
      itemIdentifier: '${cls.acronym} • ${cls.classificationName}',
      confirmLabel: 'Delete Classification',
      icon: Icons.delete_forever_outlined,
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _isBusy = true;
      _busyMessage = 'Deleting classification...';
    });

    try {
      await AssetReferenceService.deleteClassification(
          cls.classificationId, cls.acronym);
      if (!mounted) return;
      await _loadReferences();
      widget.onReferencesUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Classification deleted successfully.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final cardWhite = ParishColors.cardWhite;
    final textMuted = ParishColors.textMuted;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 620;

        return AssetLoadingOverlay(
          isLoading: _isBusy,
          message: _busyMessage,
          child: Scaffold(
            backgroundColor: ParishColors.backgroundLight,
            appBar: AppBar(
              backgroundColor: cardWhite,
              elevation: 0,
              leading: IconButton(
                icon:
                const Icon(Icons.arrow_back, color: ParishColors.marianBlue),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Locations & Classifications Management',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Master reference data used to auto-generate diocesan control numbers',
                    style: TextStyle(
                      fontSize: isMobile ? 10.5 : 12,
                      color: textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: ParishColors.mercyRed),
              ),
            )
                : TabBarView(
              controller: _tabController,
              children: [
                _buildLocationsList(isMobile),
                _buildClassificationsList(isMobile),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationsList(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Parish Storage Locations',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                    color: ParishColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.oliveGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: isMobile ? 8 : 10,
                  ),
                ),
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
                            color: loc.isActive
                                ? ParishColors.marianBlue
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  loc.locationName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: loc.isActive
                                        ? ParishColors.textDark
                                        : ParishColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                  child: const Text(
                                    'INACTIVE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.mercyRed,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (loc.description != null &&
                              loc.description!.isNotEmpty)
                            Text(
                              loc.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: ParishColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: ParishColors.marianBlue,
                      ),
                      tooltip: 'Edit Location',
                      onPressed: () => _openLocationFormDialog(loc),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: ParishColors.mercyRed,
                      ),
                      tooltip: 'Delete Location',
                      onPressed: () => _deleteLocation(loc),
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

  Widget _buildClassificationsList(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Property Classifications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                    color: ParishColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.oliveGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: isMobile ? 8 : 10,
                  ),
                ),
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
                            color: cls.isActive
                                ? ParishColors.goldAccent
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  cls.classificationName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: cls.isActive
                                        ? ParishColors.textDark
                                        : ParishColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                  child: const Text(
                                    'INACTIVE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.mercyRed,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (cls.description != null &&
                              cls.description!.isNotEmpty)
                            Text(
                              cls.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: ParishColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: ParishColors.marianBlue,
                      ),
                      tooltip: 'Edit Classification',
                      onPressed: () => _openClassificationFormDialog(cls),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: ParishColors.mercyRed,
                      ),
                      tooltip: 'Delete Classification',
                      onPressed: () => _deleteClassification(cls),
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