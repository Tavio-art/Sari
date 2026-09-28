import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/product_categories.dart';
import '../../models/product.dart';
import '../../services/cart_store.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_store.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  final String? userName;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenNotif;

  const HomeScreen({
    super.key,
    this.userName,
    this.onOpenCart,
    this.onOpenNotif,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();
  Timer? _cartPopupTimer;
  bool _showCartPopup = false;

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
          _storeName = 'Sari-Sari Store';
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
    _cartPopupTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _goToCart() {
    final openCart = widget.onOpenCart;
    if (openCart != null) {
      openCart();
    } else {
      CartStore.instance.requestOpenCart();
    }
  }

  void _addToCart(Product product) {
    try {
      CartStore.instance.add(product);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }
    setState(() => _showCartPopup = true);
    _cartPopupTimer?.cancel();
    _cartPopupTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showCartPopup = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const categories = ProductCategories.all;

    return Container(
      decoration:
          const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: CartStore.instance,
          builder: (context, _) {
            final cartItemCount = CartStore.instance.itemCount;
            final cartSubtotal = CartStore.instance.subtotal;

            return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.fieldGreen,
                        child: Icon(Icons.store,
                            color: AppColors.textWhite, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _storeName,
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _iconCircle(
                            Icons.shopping_cart_outlined,
                            onTap: _goToCart,
                          ),
                          if (cartItemCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.accentRed,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$cartItemCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      ListenableBuilder(
                        listenable: NotificationStore.instance,
                        builder: (context, _) {
                          final unread =
                              NotificationStore.instance.unreadCount;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _iconCircle(
                                Icons.notifications_none_rounded,
                                onTap: widget.onOpenNotif,
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.accentRed,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: AppColors.textWhite),
                    decoration: InputDecoration(
                      hintText: 'Search by name or barcode...',
                      hintStyle: const TextStyle(color: AppColors.textFaint),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textFaint),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppColors.textFaint, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.fieldGreen.withValues(alpha: 0.6),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: AppColors.mintIcon.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final selected = category == _selectedCategory;
                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = category),
                          selectedColor: AppColors.accentOrange,
                          backgroundColor: Colors.transparent,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: AppColors.mintIcon.withValues(alpha: 0.4),
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.darkGreenTop
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Products',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = 'All';
                            _searchController.clear();
                          });
                        },
                        child: const Text(
                          'See All',
                          style: TextStyle(
                            color: AppColors.accentOrange,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: StreamBuilder<List<Product>>(
                      stream: _firebaseService.watchProducts(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
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
                              style:
                                  const TextStyle(color: AppColors.textMuted),
                            ),
                          );
                        }

                        final allProducts = snapshot.data ?? const <Product>[];
                        final q = _searchController.text.toLowerCase().trim();
                        // Strip spaces so scanned barcodes with gaps still match.
                        final qCompact = q.replaceAll(RegExp(r'\s+'), '');

                        final filteredProducts = allProducts.where((product) {
                          final barcode = product.barcode.toLowerCase().trim();
                          final id = product.id.toLowerCase().trim();
                          final barcodeCompact =
                              barcode.replaceAll(RegExp(r'\s+'), '');
                          final matchesSearch = q.isEmpty ||
                              product.name.toLowerCase().contains(q) ||
                              barcode.contains(q) ||
                              barcodeCompact.contains(qCompact) ||
                              barcodeCompact == qCompact ||
                              id.contains(q) ||
                              id.replaceAll(RegExp(r'\s+'), '') == qCompact ||
                              product.category.toLowerCase().contains(q);
                          // When searching (esp. by barcode), ignore category
                          // so a Snacks filter doesn't hide a Beverage barcode.
                          final matchesCategory = q.isNotEmpty ||
                              _selectedCategory == 'All' ||
                              product.category.toUpperCase() ==
                                  _selectedCategory.toUpperCase();
                          return matchesSearch && matchesCategory;
                        }).toList();

                        // Prefer exact barcode/id matches at the top.
                        if (qCompact.isNotEmpty) {
                          filteredProducts.sort((a, b) {
                            int score(Product p) {
                              final code = p.barcode
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'\s+'), '');
                              final id = p.id
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'\s+'), '');
                              if (code == qCompact || id == qCompact) return 0;
                              if (code.startsWith(qCompact) ||
                                  id.startsWith(qCompact)) {
                                return 1;
                              }
                              return 2;
                            }

                            return score(a).compareTo(score(b));
                          });
                        }

                        if (filteredProducts.isEmpty) {
                          return const Center(
                            child: Text(
                              'No products found',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: EdgeInsets.only(
                              bottom: _showCartPopup && cartItemCount > 0
                                  ? 170
                                  : 96),
                          itemCount: filteredProducts.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ProductCard(
                              product: product,
                              onAddToCart: () => _addToCart(product),
                              // Edit lives on Inventory — not Home.
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_showCartPopup && cartItemCount > 0)
              Positioned(
                left: 20,
                right: 20,
                bottom: 88,
                child: ListenableBuilder(
                  listenable: SettingsStore.instance,
                  builder: (context, _) {
                    return ElevatedButton(
                      onPressed: _goToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'View Cart · $cartItemCount item${cartItemCount > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: AppColors.darkGreenTop,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            SettingsStore.instance.formatMoney(cartSubtotal),
                            style: const TextStyle(
                              color: AppColors.darkGreenTop,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
          },
        ),
      ),
    );
  }

  Widget _iconCircle(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: AppColors.mintIcon.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: AppColors.textWhite,
        ),
      ),
    );
  }
}