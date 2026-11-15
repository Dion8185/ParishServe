import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/pos_item_model.dart';
import '../../services/particulars_service.dart';
import '../../../asset_inventory/presentation/widgets/asset_loading_overlay.dart';

void showManageParticularsModal(BuildContext context, {VoidCallback? onParticularsUpdated}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ManageParticularsDialog(onParticularsUpdated: onParticularsUpdated),
  );
}

class ManageParticularsDialog extends StatefulWidget {
  final VoidCallback? onParticularsUpdated;

  const ManageParticularsDialog({super.key, this.onParticularsUpdated});

  @override
  State<ManageParticularsDialog> createState() => _ManageParticularsDialogState();
}

class _ManageParticularsDialogState extends State<ManageParticularsDialog> {
  List<PosItemModel> _particulars = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Sacraments',
    'Mass Intentions',
    'Certificates',
    'Devotionals',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _loadParticulars();
  }

  Future<void> _loadParticulars() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ParticularsService.getParticulars(activeOnly: false);
      if (!mounted) return;
      setState(() {
        _particulars = data;
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

  List<PosItemModel> get _filteredList {
    var list = _particulars;
    if (_selectedCategory != 'All') {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void _openCreateOrEditDialog([PosItemModel? itemToEdit]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ParticularFormDialog(
        itemToEdit: itemToEdit,
        onSaved: () {
          _loadParticulars();
          widget.onParticularsUpdated?.call();
        },
      ),
    );
  }

  Future<void> _toggleStatus(PosItemModel item, bool newStatus) async {
    try {
      await ParticularsService.toggleStatus(item.id, newStatus);
      _loadParticulars();
      widget.onParticularsUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  Future<void> _confirmDelete(PosItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: ParishColors.mercyRed, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Remove from Catalog?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.title}" from the parish offering particulars? Past receipts will remain intact.',
          style: TextStyle(fontSize: 13.5, color: ParishColors.textDark, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ParticularsService.deleteParticular(item.id);
        _loadParticulars();
        widget.onParticularsUpdated?.call();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.title}" removed from catalog.'),
            backgroundColor: ParishColors.oliveGreen,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete item: $e'), backgroundColor: ParishColors.mercyRed),
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
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return AssetLoadingOverlay(
      isLoading: _isLoading,
      message: 'Loading...',
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cardWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 780,
            maxHeight: screenSize.height * 0.85,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 14),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: borderGrey)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ParishColors.marianBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Offerings & Particulars',
                            style: TextStyle(fontSize: isMobile ? 15.5 : 17, fontWeight: FontWeight.w700, color: textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Configure sacraments, certificates, and stipends',
                            style: TextStyle(fontSize: 11.5, color: textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.oliveGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 10),
                      ),
                      onPressed: () => _openCreateOrEditDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        isMobile ? 'New' : 'New Offering',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Controls: Search (Floating Label) & Category Chips
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(fontSize: 14, color: textDark),
                      decoration: InputDecoration(
                        labelText: 'Search offerings by title or description',
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        prefixIcon: const Icon(Icons.search, size: 19, color: ParishColors.marianBlue),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 17),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                            : null,
                        filled: true,
                        fillColor: ParishColors.backgroundLight,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderGrey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderGrey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: ParishColors.marianBlue,
                                backgroundColor: ParishColors.backgroundLight,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? Colors.white : textDark,
                                ),
                                onSelected: (_) => setState(() => _selectedCategory = cat),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // List of Items
              Expanded(
                child: _errorMessage != null
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Error: $_errorMessage',
                      style: const TextStyle(color: ParishColors.mercyRed),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                    : _filteredList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: borderGrey),
                      const SizedBox(height: 8),
                      Text('No offerings found.', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
                      Text('Tap "+ New Offering" to register a custom service.', style: TextStyle(color: textMuted, fontSize: 12)),
                    ],
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    return _buildParticularTile(item, isMobile);
                  },
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: borderGrey)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredList.length} items in catalog',
                      style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: TextStyle(color: textMuted, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticularTile(PosItemModel item, bool isMobile) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    final actionControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 19, color: ParishColors.marianBlue),
          tooltip: 'Edit Offering Details',
          onPressed: () => _openCreateOrEditDialog(item),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 19, color: ParishColors.mercyRed),
          tooltip: 'Delete Offering',
          onPressed: () => _confirmDelete(item),
        ),
        Switch(
          value: item.isActive,
          activeColor: ParishColors.oliveGreen,
          onChanged: (val) => _toggleStatus(item, val),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isActive ? ParishColors.cardWhite : ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isActive ? borderGrey : borderGrey.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.isActive ? ParishColors.marianBlueSurface : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  color: item.isActive ? ParishColors.marianBlue : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: item.isActive ? textDark : textMuted,
                              decoration: item.isActive ? null : TextDecoration.lineThrough,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ParishColors.goldLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.category,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.description.isNotEmpty ? item.description : 'Standard offering entry',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '₱ ${item.defaultPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: item.isActive ? ParishColors.oliveGreen : textMuted,
                          ),
                        ),
                        if (item.allowsCustomPrice)
                          const Text(
                            '(Allows Custom Amount)',
                            style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: ParishColors.marianBlue),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 10),
                actionControls,
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: actionControls,
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Particular Create / Edit Form Modal (Floating Labels + Taller Remarks)
// =============================================================================
class _ParticularFormDialog extends StatefulWidget {
  final PosItemModel? itemToEdit;
  final VoidCallback onSaved;

  const _ParticularFormDialog({this.itemToEdit, required this.onSaved});

  @override
  State<_ParticularFormDialog> createState() => _ParticularFormDialogState();
}

class _ParticularFormDialogState extends State<_ParticularFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'Sacraments';
  String _iconName = 'church';
  bool _allowsCustomPrice = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool get isEditMode => widget.itemToEdit != null;

  final List<String> _categoryOptions = [
    'Sacraments',
    'Mass Intentions',
    'Certificates',
    'Devotionals',
    'Others',
  ];

  final List<Map<String, dynamic>> _iconPresets = [
    {'name': 'church', 'label': 'Church', 'icon': Icons.church_outlined},
    {'name': 'water_drop', 'label': 'Baptism', 'icon': Icons.water_drop_outlined},
    {'name': 'fire', 'label': 'Pentecost', 'icon': Icons.local_fire_department_outlined},
    {'name': 'communion', 'label': 'Communion', 'icon': Icons.restaurant_outlined},
    {'name': 'heart', 'label': 'Marriage', 'icon': Icons.favorite_border},
    {'name': 'funeral', 'label': 'Funeral', 'icon': Icons.church},
    {'name': 'celebration', 'label': 'Thanksgiving', 'icon': Icons.celebration_outlined},
    {'name': 'soul', 'label': 'Soul / Person', 'icon': Icons.person_outline},
    {'name': 'petition', 'label': 'Prayer / Petition', 'icon': Icons.volunteer_activism_outlined},
    {'name': 'certificate', 'label': 'Certificate', 'icon': Icons.badge_outlined},
    {'name': 'verified', 'label': 'Verified', 'icon': Icons.verified_outlined},
    {'name': 'lamp', 'label': 'Candle / Lamp', 'icon': Icons.light_mode_outlined},
    {'name': 'flower', 'label': 'Flower', 'icon': Icons.yard_outlined},
    {'name': 'donation', 'label': 'Offering', 'icon': Icons.favorite},
    {'name': 'receipt', 'label': 'Receipt', 'icon': Icons.receipt_long_outlined},
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    if (item != null) {
      _titleController.text = item.title;
      _priceController.text = item.defaultPrice.toStringAsFixed(2);
      _descriptionController.text = item.description;
      _category = item.category;
      _iconName = item.iconName;
      _allowsCustomPrice = item.allowsCustomPrice;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final parsedPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    setState(() => _isSaving = true);

    try {
      if (isEditMode) {
        final updated = widget.itemToEdit!.copyWith(
          title: _titleController.text.trim(),
          category: _category,
          defaultPrice: parsedPrice,
          description: _descriptionController.text.trim(),
          iconName: _iconName,
          icon: PosItemModel.resolveIcon(_iconName),
          allowsCustomPrice: _allowsCustomPrice,
        );
        await ParticularsService.updateParticular(updated);
      } else {
        await ParticularsService.createParticular(
          title: _titleController.text.trim(),
          category: _category,
          defaultPrice: parsedPrice,
          description: _descriptionController.text.trim(),
          iconName: _iconName,
          allowsCustomPrice: _allowsCustomPrice,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode ? 'Offering details updated.' : 'New offering registered to catalog.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final screenSize = MediaQuery.of(context).size;

    return AssetLoadingOverlay(
      isLoading: _isSaving,
      message: 'Saving...',
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cardWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: screenSize.height * 0.88,
          ),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: borderGrey)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ParishColors.marianBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isEditMode ? Icons.edit_note : Icons.add_business, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditMode ? 'Edit Offering Particular' : 'Create Offering Particular',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Configure item wording and default stipend amount',
                            style: TextStyle(fontSize: 11.5, color: textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: ParishColors.mercyRedSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ParishColors.mercyRed),
                            ),
                            child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],

                        TextFormField(
                          controller: _titleController,
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
                          style: TextStyle(fontSize: 14.5, color: textDark),
                          decoration: _inputDecoration(labelText: 'Offering / Service Title *'),
                        ),
                        const SizedBox(height: 14),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final categoryField = DropdownButtonFormField<String>(
                              value: _category,
                              isExpanded: true,
                              items: _categoryOptions
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13.5))))
                                  .toList(),
                              onChanged: (val) => setState(() => _category = val!),
                              decoration: _inputDecoration(labelText: 'Category *'),
                            );

                            final priceField = TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Price required';
                                if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                                return null;
                              },
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textDark),
                              decoration: _inputDecoration(labelText: 'Default Price (₱) *', prefixText: '₱ '),
                            );

                            if (constraints.maxWidth < 380) {
                              return Column(
                                children: [
                                  categoryField,
                                  const SizedBox(height: 14),
                                  priceField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(flex: 3, child: categoryField),
                                const SizedBox(width: 12),
                                Expanded(flex: 2, child: priceField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Taller Remarks / Description Field (Floating Label Only)
                        TextFormField(
                          controller: _descriptionController,
                          minLines: 3,
                          maxLines: 5,
                          style: TextStyle(fontSize: 14, color: textDark, height: 1.4),
                          decoration: _inputDecoration(
                            labelText: 'Description / Remarks (Optional)',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Icon Selector Chips
                        Text('Offering Emblem / Icon', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textMuted)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ParishColors.backgroundLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderGrey),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _iconPresets.map((preset) {
                              final name = preset['name'] as String;
                              final icon = preset['icon'] as IconData;
                              final label = preset['label'] as String;
                              final isSelected = _iconName == name;

                              return Tooltip(
                                message: label,
                                child: InkWell(
                                  onTap: () => setState(() => _iconName = name),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? ParishColors.marianBlue : cardWhite,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? ParishColors.marianBlue : borderGrey,
                                        width: isSelected ? 1.8 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 18, color: isSelected ? Colors.white : ParishColors.marianBlue),
                                        const SizedBox(width: 6),
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? Colors.white : textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Allow custom price toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: ParishColors.marianBlue,
                          title: const Text('Allow Custom Amount at Checkout', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          subtitle: const Text('Useful for discretionary donations and tithes', style: TextStyle(fontSize: 11.5)),
                          value: _allowsCustomPrice,
                          onChanged: (val) => setState(() => _allowsCustomPrice = val),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Modal Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: borderGrey)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: textMuted, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(120, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        _isSaving ? 'Saving...' : (isEditMode ? 'Update Offering' : 'Register Offering'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? prefixText,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      alignLabelWithHint: alignLabelWithHint,
      labelStyle: TextStyle(fontSize: 13.5, color: ParishColors.textMuted),
      floatingLabelStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: ParishColors.marianBlue,
      ),
      prefixText: prefixText,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
}