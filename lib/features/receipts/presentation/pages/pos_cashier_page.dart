import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/pos_item_model.dart';
import '../../services/particulars_service.dart';
import '../../services/secretary_service.dart';
import '../dialogs/manage_particulars_dialog.dart';
import '../dialogs/receipt_detail_dialog.dart';

/// Auto-masking phone input formatter for Philippine phone numbers
class _PhilippinePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 11) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      if ((i == 3 || i == 6) && i != digitsOnly.length - 1) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Title case formatter for names
class _TitleCaseInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final words = text.split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');

    return TextEditingValue(
      text: capitalized,
      selection: newValue.selection,
    );
  }
}

class PosCashierPage extends StatefulWidget {
  final VoidCallback? onTransactionCompleted;

  const PosCashierPage({super.key, this.onTransactionCompleted});

  @override
  State<PosCashierPage> createState() => _PosCashierPageState();
}

class _PosCashierPageState extends State<PosCashierPage> {
  final List<PosCartItem> _cart = [];
  List<PosItemModel> _catalog = [];
  bool _isLoadingCatalog = true;
  String? _catalogError;

  String _selectedCategory = 'All';
  String _searchQuery = '';

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
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoadingCatalog = true;
      _catalogError = null;
    });

    try {
      final items = await ParticularsService.getParticulars(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _catalog = items;
        _isLoadingCatalog = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingCatalog = false;
      });
    }
  }

  List<PosItemModel> get _filteredCatalog {
    var list = _catalog;
    if (_selectedCategory != 'All') {
      list = list.where((item) => item.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((item) {
        return item.title.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.total);
  int get _totalItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  void _addToCart(PosItemModel item) {
    if (item.allowsCustomPrice) {
      _promptCustomPriceAndAdd(item);
      return;
    }

    setState(() {
      final index = _cart.indexWhere((c) => c.item.id == item.id);
      if (index != -1) {
        _cart[index].quantity++;
      } else {
        _cart.add(PosCartItem(item: item));
      }
    });
  }

  Future<void> _promptCustomPriceAndAdd(PosItemModel item) async {
    final controller = TextEditingController(text: item.defaultPrice.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Enter Amount for ${item.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This offering supports a discretionary amount:', style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: 'P ',
                labelText: 'Amount (PHP)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 0) {
                Navigator.pop(ctx, parsed);
              }
            },
            child: const Text('Add to Slip'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _cart.add(PosCartItem(item: item, customPrice: result));
      });
    }
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  void _openManageParticulars() {
    showManageParticularsModal(
      context,
      onParticularsUpdated: _loadCatalog,
    );
  }

  void _openCheckoutDialog() {
    if (_cart.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CheckoutModal(
        cartItems: _cart,
        totalAmount: _subtotal,
        onPaid: (Map<String, dynamic> result, String chosenTenderMode) {
          _clearCart();
          widget.onTransactionCompleted?.call();
          _showReceiptSuccessDialog(result, chosenTenderMode);
        },
      ),
    );
  }

  void _showReceiptSuccessDialog(Map<String, dynamic> record, String chosenTenderMode) {
    final receiptNo = record['receipt_number'] ?? 'REC-XXXX';
    final payer = record['payor_name'] ?? 'Walk-In Parishioner';
    final service = record['related_service'] ?? 'Parish Offering';

    final rawAmount = record['transaction_amount'];
    final double amountVal = (rawAmount is num)
        ? rawAmount.toDouble()
        : (double.tryParse(rawAmount?.toString() ?? '0') ?? _subtotal);

    final amount = 'P ${amountVal.toStringAsFixed(2)}';
    final date = record['transaction_date']?.toString().substring(0, 10) ?? 'Today';

    showReceiptDetailModal(
      context,
      receiptNo: receiptNo,
      payer: payer,
      purpose: service,
      amount: amount,
      date: date,
      payorContact: record['payor_contact'],
      transactionDetails: record['transaction_details'],
      paymentMode: chosenTenderMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

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
              'Parish Cashier Desk (POS)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
            ),
            Text(
              'St. John Paul II Parish • On-site Transaction Terminal',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: ParishColors.marianBlue),
            tooltip: 'Manage Particulars Catalog (CRUD)',
            onPressed: _openManageParticulars,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
            tooltip: 'Reload Catalog',
            onPressed: _loadCatalog,
          ),
          if (_cart.isNotEmpty)
            TextButton.icon(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_sweep, color: ParishColors.mercyRed, size: 18),
              label: const Text('Clear Order', style: TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 65,
                  child: _buildCatalogSection(isWide: true),
                ),
                VerticalDivider(width: 1, color: borderGrey),
                Expanded(
                  flex: 35,
                  child: _buildOrderCartPanel(isWide: true),
                ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: _buildCatalogSection(isWide: false),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildMobileCheckoutBottomBar(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCatalogSection({required bool isWide}) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    if (_isLoadingCatalog) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    if (_catalogError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: ParishColors.mercyRed),
              const SizedBox(height: 10),
              Text('Failed to load particulars: $_catalogError', textAlign: TextAlign.center, style: const TextStyle(color: ParishColors.mercyRed)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadCatalog,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const Icon(Icons.search, size: 20, color: ParishColors.marianBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 14, color: textDark),
                    decoration: InputDecoration(
                      hintText: 'Search service, sacrament, certificate, or offering...',
                      hintStyle: TextStyle(fontSize: 13, color: textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() => _searchQuery = ''),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: ParishColors.marianBlue,
                    backgroundColor: cardWhite,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_selectedCategory Catalog (${_filteredCatalog.length})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
              ),
              TextButton.icon(
                onPressed: _openManageParticulars,
                icon: const Icon(Icons.edit_note, size: 16, color: ParishColors.marianBlue),
                label: const Text('Edit Particulars', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _filteredCatalog.isEmpty
              ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderGrey),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 40, color: borderGrey),
                const SizedBox(height: 10),
                Text('No active offerings in this category.', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 4),
                Text('Tap "Edit Particulars" to activate or add new offerings.', style: TextStyle(fontSize: 12, color: textMuted)),
              ],
            ),
          )
              : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredCatalog.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 3 : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 1.35 : 1.1,
            ),
            itemBuilder: (context, index) {
              final item = _filteredCatalog[index];
              return _buildItemCard(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(PosItemModel item) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return InkWell(
      onTap: () => _addToCart(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderGrey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: ParishColors.marianBlue, size: 22),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ParishColors.goldLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.allowsCustomPrice ? 'Custom / Tithe' : 'P ${item.defaultPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.goldAccent,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  item.description.isNotEmpty ? item.description : item.category,
                  style: TextStyle(fontSize: 11, color: textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlueSurface,
                  foregroundColor: ParishColors.marianBlue,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _addToCart(item),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add to Slip', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCartPanel({required bool isWide}) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return Container(
      color: cardWhite,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: ParishColors.marianBlue, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Current Order Slip',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                  ),
                ],
              ),
              if (_cart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ParishColors.oliveGreenSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalItemCount items',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.oliveGreen,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),

          Expanded(
            child: _cart.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 54, color: borderGrey),
                  const SizedBox(height: 12),
                  Text(
                    'No items in current order',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap items on the catalog to add to order slip',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            )
                : ListView.separated(
              itemCount: _cart.length,
              separatorBuilder: (_, __) => const Divider(height: 14),
              itemBuilder: (context, index) {
                final cartItem = _cart[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cartItem.item.title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                          ),
                          Text(
                            'P ${cartItem.customPrice.toStringAsFixed(2)} each',
                            style: TextStyle(fontSize: 11, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                          onPressed: () => _removeFromCart(index),
                          color: ParishColors.mercyRed,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        Text(
                          '${cartItem.quantity}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          onPressed: () => _addToCart(cartItem.item),
                          color: ParishColors.oliveGreen,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'P ${cartItem.total.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 24),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal:', style: TextStyle(fontSize: 13, color: textMuted)),
                  Text('P ${_subtotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, color: textDark)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amount Due:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                  Text(
                    'P ${_subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cart.isEmpty ? borderGrey : ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _cart.isEmpty ? null : _openCheckoutDialog,
                  icon: const Icon(Icons.payment, size: 20),
                  label: const Text('Proceed to Checkout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCheckoutBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        border: Border(top: BorderSide(color: ParishColors.borderGrey)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_totalItemCount items in slip', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
              Text(
                'P ${_subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cart.isEmpty ? ParishColors.borderGrey : ParishColors.marianBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _cart.isEmpty ? null : _openCheckoutDialog,
            icon: const Icon(Icons.payment, size: 18),
            label: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _CheckoutModal extends StatefulWidget {
  final List<PosCartItem> cartItems;
  final double totalAmount;
  final Function(Map<String, dynamic> transactionRecord, String paymentMode) onPaid;

  const _CheckoutModal({
    required this.cartItems,
    required this.totalAmount,
    required this.onPaid,
  });

  @override
  State<_CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<_CheckoutModal> {
  final _formKey = GlobalKey<FormState>();
  final _payorNameController = TextEditingController();
  final _payorContactController = TextEditingController();
  final _tenderedController = TextEditingController();
  final _gcashRefController = TextEditingController();
  final _remarksController = TextEditingController();

  String _paymentMode = 'Cash';
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default cash tendered to total amount
    _tenderedController.text = widget.totalAmount.toStringAsFixed(2);
    _tenderedController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _payorNameController.dispose();
    _payorContactController.dispose();
    _tenderedController.dispose();
    _gcashRefController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _tenderedAmount => double.tryParse(_tenderedController.text.trim()) ?? 0.0;
  double get _changeAmount => (_tenderedAmount - widget.totalAmount).clamp(0.0, 999999.0);

  String _resolveTransactionTypeCategory() {
    if (widget.cartItems.isEmpty) return 'donation';

    final category = widget.cartItems.first.item.category.toLowerCase();
    if (category.contains('sacrament')) return 'sacrament';
    if (category.contains('intention')) return 'mass_intention';
    if (category.contains('certificate')) return 'certificate';
    return 'donation';
  }

  Future<void> _submitTransaction() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    if (_paymentMode == 'Cash' && _tenderedAmount < widget.totalAmount) {
      setState(() => _errorMessage = 'Tendered cash is less than total amount due.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String summaryServices;
      if (widget.cartItems.length == 1) {
        summaryServices = '${widget.cartItems.first.item.title} (x${widget.cartItems.first.quantity})';
      } else {
        summaryServices = '${widget.cartItems.first.item.title} + ${widget.cartItems.length - 1} other item(s)';
      }

      if (summaryServices.length > 90) {
        summaryServices = '${summaryServices.substring(0, 87)}...';
      }

      // Line items stored cleanly
      final lineDetails = widget.cartItems
          .map((c) => '- ${c.item.title} x${c.quantity} @ P ${c.customPrice.toStringAsFixed(2)} = P ${c.total.toStringAsFixed(2)}')
          .join('\n');

      // Notes saved into transaction details for audit trail
      final remarksText = [
        if (_paymentMode == 'Cash') 'Cash Tendered: P ${_tenderedAmount.toStringAsFixed(2)} (Change: P ${_changeAmount.toStringAsFixed(2)})',
        if (_paymentMode == 'GCash') 'GCash Ref: ${_gcashRefController.text.trim()}',
        if (_paymentMode == 'Gratis') 'Canonical Gratis / Exemption granted by Secretariat.',
        if (_remarksController.text.trim().isNotEmpty) 'Remarks: ${_remarksController.text.trim()}',
      ].join(' | ');

      final fullDetails = remarksText.isNotEmpty ? '$lineDetails\n$remarksText' : lineDetails;
      final resolvedType = _resolveTransactionTypeCategory();

      final record = await SecretaryService.createTransaction(
        payorName: _payorNameController.text.trim(),
        payorContact: _payorContactController.text.trim(),
        relatedService: summaryServices,
        transactionDetails: fullDetails,
        transactionAmount: _paymentMode == 'Gratis' ? 0.00 : widget.totalAmount,
        transactionType: resolvedType,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onPaid(record, _paymentMode);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isProcessing = false;
      });
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
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
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
                    decoration: const BoxDecoration(
                      color: ParishColors.marianBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.point_of_sale, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Complete Cashier Payment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
                        Text('Issue official ecclesiastical transaction receipt', style: TextStyle(fontSize: 11.5, color: textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

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
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ),
                      ],

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Amount Payable:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
                            Text('P ${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Payor / Parishioner Full Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _payorNameController,
                        inputFormatters: [_TitleCaseInputFormatter()],
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Payor name is required' : null,
                        style: TextStyle(fontSize: 14, color: textDark),
                        decoration: _inputDecoration(hint: 'e.g. Maria Clara Santos'),
                      ),
                      const SizedBox(height: 14),

                      Text('Contact Number (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _payorContactController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _PhilippinePhoneInputFormatter(),
                        ],
                        style: TextStyle(fontSize: 14, color: textDark),
                        decoration: _inputDecoration(hint: '09XX-XXX-XXXX'),
                      ),
                      const SizedBox(height: 16),

                      Text('Payment Tender Mode *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _paymentMode,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'Cash',
                            child: Text('Cash (Secretariat Desk)', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'GCash',
                            child: Text('GCash (Direct Transfer)', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'Gratis',
                            child: Text('Gratis (Canonically Exempt)', overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        onChanged: (val) => setState(() => _paymentMode = val!),
                        decoration: _inputDecoration(),
                      ),
                      const SizedBox(height: 14),

                      // CASH TENDERED & CHANGE COMPUTATION PRESERVED IN MODAL CARD
                      if (_paymentMode == 'Cash') ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cash Tendered (P) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _tenderedController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                                    decoration: _inputDecoration(hint: '0.00'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Change Due (P)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    alignment: Alignment.centerLeft,
                                    decoration: BoxDecoration(
                                      color: ParishColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderGrey),
                                    ),
                                    child: Text(
                                      'P ${_changeAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: _changeAmount >= 0 ? ParishColors.oliveGreen : ParishColors.mercyRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (_paymentMode == 'GCash') ...[
                        Text('GCash Reference Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _gcashRefController,
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'GCash Reference number is required' : null,
                          style: TextStyle(fontSize: 14, color: textDark),
                          decoration: _inputDecoration(hint: 'e.g. 1002 9847 1120'),
                        ),
                        const SizedBox(height: 14),
                      ],

                      Text('Internal Remarks / Specific Purpose', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _remarksController,
                        maxLines: 2,
                        style: TextStyle(fontSize: 13, color: textDark),
                        decoration: _inputDecoration(hint: 'Optional notes, batch intentions, or special clearances'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(fontSize: 14, color: textMuted)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.oliveGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: _isProcessing ? null : _submitTransaction,
                      icon: _isProcessing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.receipt_long, size: 20),
                      label: Text(
                        _isProcessing ? 'Generating...' : 'Confirm & Issue Receipt',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
    );
  }
}