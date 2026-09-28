import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../home/product_detail_screen.dart';
import '../scan/scan_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String? userName;

  const InventoryScreen({
    super.key,
    this.userName,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _searchController = TextEditingController();
  String _storeName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchStoreName();
  }

  Future<void> _fetchStoreName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          setState(() {
            _storeName = doc.data()!['storeName'] ?? 'Sari-Sari Store';
          });
        }
      } catch (e) {
        setState(() {
          _storeName = widget.userName ?? 'Sari-Sari Store';
        });
      }
    } else {
      setState(() {
        _storeName = widget.userName ?? 'Sari-Sari Store';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStockColor(int stock) {
    if (stock == 0) {
      return AppColors.accentRed;
    } else if (stock <= 5) {
      return AppColors.accentOrange;
    } else {
      return AppColors.mintIcon;
    }
  }

  void _openAddProduct() {
    ProductDetailScreen.show(context);
  }

  void _openFullEdit(Product product) {
    ProductDetailScreen.show(context, product: product);
  }

  void _showQuickEditDialog(Product product) {
    final priceController =
        TextEditingController(text: product.price.toStringAsFixed(2));
    final stockController =
        TextEditingController(text: product.stock.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.darkGreenMid,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                    color: AppColors.textWhite, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'Quick update price and stock',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.textWhite),
                decoration: InputDecoration(
                  labelText:
                      'Price (${SettingsStore.instance.currencySymbol})',
                  prefixIcon: const Icon(Icons.payments_outlined,
                      color: AppColors.mintIcon),
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.fieldGreen.withValues(alpha: 0.45),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textWhite),
                decoration: InputDecoration(
                  labelText: 'Stock quantity',
                  prefixIcon: const Icon(Icons.layers_outlined,
                      color: AppColors.mintIcon),
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.fieldGreen.withValues(alpha: 0.45),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openFullEdit(product);
                  },
                  child: const Text('Edit all details',
                      style: TextStyle(
                          color: AppColors.accentOrange, fontSize: 13)),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPrice =
                    double.tryParse(priceController.text) ?? product.price;
                final newStock =
                    int.tryParse(stockController.text) ?? product.stock;

                final updated = Product(
                  id: product.id,
                  name: product.name,
                  category: product.category,
                  sku: product.sku,
                  price: newPrice,
                  stock: newStock,
                  imageUrl: product.imageUrl,
                  barcode: product.barcode,
                );

                await _firebaseService.updateProduct(product.barcode, updated);

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGreenMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Remove this product?',
            style: TextStyle(color: AppColors.textWhite)),
        content: Text(
          '“${product.name}” will be deleted from your store.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 44),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firebaseService.deleteProduct(product.barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.fieldGreen,
                    child: Icon(Icons.store, color: AppColors.textWhite, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _storeName,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Manage Your Sari-Sari Store',
                style: TextStyle(
                    color: AppColors.accentOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                      color: AppColors.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search all items or barcodes',
                    hintStyle: const TextStyle(
                        color: AppColors.textFaint, fontSize: 12),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textFaint, size: 18),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppColors.textFaint, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppColors.mintIcon, size: 18),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ScanScreen(showBackButton: true)),
                            );
                          },
                        ),
                      ],
                    ),
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: AppColors.fieldGreen.withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                          color: AppColors.mintIcon.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<List<Product>>(
                  stream: _firebaseService.watchProducts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.mintIcon),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'May error: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }

                    final products = snapshot.data ?? const <Product>[];

                    final filteredProducts = products.where((p) {
                      final query = _searchController.text.toLowerCase();
                      return p.name.toLowerCase().contains(query) ||
                          p.barcode.toLowerCase().contains(query) ||
                          p.category.toLowerCase().contains(query);
                    }).toList();

                    final totalItems = products.length;
                    final lowStock =
                        products.where((p) => p.isLowStock).length;
                    final outOfStock =
                        products.where((p) => p.isOutOfStock).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: StatCard(
                                    label: 'Total Items',
                                    value: '$totalItems')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: StatCard(
                                    label: 'Low Stock', value: '$lowStock')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                                child: StatCard(
                                    label: 'Best Sellers', value: '0')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: StatCard(
                                    label: 'Out of Stock',
                                    value: '$outOfStock')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.mintIcon
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          flex: 3,
                                          child: Text('ITEM',
                                              style: TextStyle(
                                                  color: AppColors.textFaint,
                                                  fontSize: 10))),
                                      Expanded(
                                          flex: 2,
                                          child: Text('CODE',
                                              style: TextStyle(
                                                  color: AppColors.textFaint,
                                                  fontSize: 10))),
                                      Expanded(
                                          flex: 2,
                                          child: Text('PRICE',
                                              style: TextStyle(
                                                  color: AppColors.textFaint,
                                                  fontSize: 10))),
                                      Expanded(
                                          flex: 2,
                                          child: Text('STOCK',
                                              style: TextStyle(
                                                  color: AppColors.textFaint,
                                                  fontSize: 10))),
                                      Expanded(
                                          flex: 3,
                                          child: Text('ACTIONS',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: AppColors.textFaint,
                                                  fontSize: 10))),
                                    ],
                                  ),
                                ),
                                const Divider(
                                    color: AppColors.mintIcon,
                                    thickness: 0.15,
                                    height: 8),
                                Expanded(
                                  child: filteredProducts.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'Walang products',
                                            style: TextStyle(
                                                color: AppColors.textMuted),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: filteredProducts.length,
                                          itemBuilder: (context, index) {
                                            final p = filteredProducts[index];
                                            final stockColor =
                                                _getStockColor(p.stock);

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 4),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                      flex: 3,
                                                      child: Text(p.name,
                                                          style: const TextStyle(
                                                              color: AppColors
                                                                  .textWhite,
                                                              fontSize: 12))),
                                                  Expanded(
                                                      flex: 2,
                                                      child: Text(p.barcode,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              color: AppColors
                                                                  .textFaint,
                                                              fontSize: 11))),
                                                  Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                          SettingsStore.instance
                                                              .formatMoney(
                                                                  p.price),
                                                          style: const TextStyle(
                                                              color: AppColors
                                                                  .textMuted,
                                                              fontSize: 11))),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: stockColor
                                                              .withValues(
                                                                  alpha: 0.2),
                                                          border: Border.all(
                                                              color: stockColor
                                                                  .withValues(
                                                                      alpha:
                                                                          0.6),
                                                              width: 1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: Text(
                                                          '${p.stock}',
                                                          style: TextStyle(
                                                            color: stockColor,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Material(
                                                          color: Colors
                                                              .transparent,
                                                          child: InkWell(
                                                            onTap: () =>
                                                                _showQuickEditDialog(
                                                                    p),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            child: Container(
                                                              constraints:
                                                                  const BoxConstraints(
                                                                minWidth: 44,
                                                                minHeight: 44,
                                                              ),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 10,
                                                                vertical: 8,
                                                              ),
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: AppColors
                                                                    .accentOrange,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              child:
                                                                  const Icon(
                                                                Icons
                                                                    .edit_outlined,
                                                                size: 18,
                                                                color: AppColors
                                                                    .darkGreenTop,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          width: 1,
                                                          height: 28,
                                                          margin:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10),
                                                          color: AppColors
                                                              .mintIcon
                                                              .withValues(
                                                                  alpha: 0.35),
                                                        ),
                                                        Material(
                                                          color: Colors
                                                              .transparent,
                                                          child: InkWell(
                                                            onTap: () =>
                                                                _deleteProduct(
                                                                    p),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            child: Container(
                                                              constraints:
                                                                  const BoxConstraints(
                                                                minWidth: 44,
                                                                minHeight: 44,
                                                              ),
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: AppColors
                                                                    .accentRed
                                                                    .withValues(
                                                                        alpha:
                                                                            0.18),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              child: Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                size: 20,
                                                                color: AppColors
                                                                    .accentRed
                                                                    .withValues(
                                                                        alpha:
                                                                            0.95),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _openAddProduct,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Item',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(120, 38)),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}