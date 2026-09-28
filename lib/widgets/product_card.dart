import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onAddToCart;
  final VoidCallback? onEdit;

  const ProductCard({
    super.key,
    required this.product,
    this.onAddToCart,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        final money = SettingsStore.instance.formatMoney(product.price);
        return GestureDetector(
          onLongPress: onEdit,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.fieldGreen.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.mintIcon.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onAddToCart,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: Container(
                        width: double.infinity,
                        color: Colors.white,
                        child: ProductImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.contain,
                          placeholderIcon: Icons.inventory_2_outlined,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.category,
                        style: const TextStyle(
                          color: AppColors.mintIcon,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              money,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (onEdit != null)
                            InkWell(
                              onTap: onEdit,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_outlined,
                                        size: 12,
                                        color: AppColors.darkGreenTop),
                                    SizedBox(width: 4),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: AppColors.darkGreenTop,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: onAddToCart,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_shopping_cart,
                                        size: 12,
                                        color: AppColors.darkGreenTop),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: AppColors.darkGreenTop,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
