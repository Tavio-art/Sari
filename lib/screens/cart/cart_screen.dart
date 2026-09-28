import 'package:flutter/material.dart';
import '../../services/cart_store.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_image.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final bool embedded;

  const CartScreen({super.key, this.embedded = false});

  void _goToCheckout(BuildContext context) {
    final cart = CartStore.instance;
    if (cart.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          totalAmount: cart.subtotal,
          itemCount: cart.itemCount,
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, CartStore cart) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.fieldGreen,
        title: const Text(
          'Clear cart?',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: const Text(
          'All items will be removed.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
    if (shouldClear == true) cart.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkBackgroundGradient,
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              CartStore.instance,
              SettingsStore.instance,
            ]),
            builder: (context, _) {
              final cart = CartStore.instance;
              final items = cart.items;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (!embedded)
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: AppColors.textWhite),
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        else
                          const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Cart',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (items.isNotEmpty)
                          TextButton(
                            onPressed: () => _confirmClear(context, cart),
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: AppColors.accentRed),
                            ),
                          )
                        else
                          const SizedBox(width: 64),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 56,
                                    color: AppColors.textFaint,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Cart is empty',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add items from Home or Scan',
                                    style: TextStyle(
                                      color: AppColors.textFaint,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return Dismissible(
                                  key: ValueKey(item.product.id),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) =>
                                      cart.remove(item.product.id),
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentRed
                                          .withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.delete_outline,
                                        color: Colors.white),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.fieldGreen
                                          .withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.mintIcon
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            width: 52,
                                            height: 52,
                                            color: Colors.white,
                                            child: ProductImage(
                                              imageUrl: item.product.imageUrl,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.product.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.textWhite,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${SettingsStore.instance.formatMoney(item.product.price)} each',
                                                style: const TextStyle(
                                                  color: AppColors.accentOrange,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: AppColors.textMuted,
                                                size: 22,
                                              ),
                                              onPressed: () => cart
                                                  .decrement(item.product.id),
                                            ),
                                            Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                color: AppColors.textWhite,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                                color: AppColors.mintIcon,
                                                size: 22,
                                              ),
                                              onPressed: () => cart
                                                  .increment(item.product.id),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (items.isNotEmpty) ...[
                      const Divider(
                          color: AppColors.mintIcon, thickness: 0.15),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            SettingsStore.instance.formatMoney(cart.subtotal),
                            style: const TextStyle(
                              color: AppColors.accentOrange,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _goToCheckout(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Checkout',
                            style: TextStyle(
                              color: AppColors.darkGreenTop,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
