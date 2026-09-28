import 'package:flutter/material.dart';
import '../../services/cart_store.dart';
import '../../services/sales_service.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../credit/credit_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final double totalAmount;
  final int itemCount;

  const CheckoutScreen({
    super.key,
    required this.totalAmount,
    required this.itemCount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final SalesService _salesService = SalesService();
  final _customerController = TextEditingController();
  String _selectedPaymentMethod = 'Cash';
  String? _errorMessage;
  bool _saving = false;

  @override
  void dispose() {
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _confirmOrder() async {
    final customerName = _customerController.text.trim();
    final isCredit = _selectedPaymentMethod == 'Credit / Utang';

    if (isCredit && customerName.isEmpty) {
      setState(() {
        _errorMessage = 'Lagyan ng pangalan kung Credit / Utang!';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _saving = true;
    });

    try {
      // Re-validate stock against cart before hitting Firebase.
      for (final item in CartStore.instance.items) {
        if (item.quantity > item.product.stock) {
          throw StateError(
            'Kulang ang stock para sa ${item.product.name} '
            '(need ${item.quantity}, have ${item.product.stock}).',
          );
        }
      }

      final itemsMap = CartStore.instance.items
          .map((item) => {
                'id': item.product.barcode.isNotEmpty
                    ? item.product.barcode
                    : item.product.id,
                'name': item.product.name,
                'barcode': item.product.barcode.isNotEmpty
                    ? item.product.barcode
                    : item.product.id,
                'price': item.product.price,
                'quantity': item.quantity,
              })
          .toList();

      debugPrint(
        '[Checkout] Pushing order to Firestore orders/ + deducting stock…',
      );

      final orderId = await _salesService.recordSale(
        items: itemsMap,
        totalAmount: widget.totalAmount,
        paymentMethod: _selectedPaymentMethod,
        customerName: customerName,
      );

      debugPrint('[Checkout] Success orderId=$orderId');
      CartStore.instance.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Check Notifications for the receipt alert.'),
          duration: Duration(seconds: 3),
        ),
      );

      if (isCredit) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: AppColors.fieldGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Icon(
                Icons.assignment_turned_in_outlined,
                color: AppColors.accentOrange,
                size: 48,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Utang Recorded!',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Na-save ang utang ni $customerName '
                    '(${SettingsStore.instance.formatMoney(widget.totalAmount)}).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'View Credit / Utang',
                    style: TextStyle(
                      color: AppColors.darkGreenTop,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CreditScreen()),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.fieldGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Icon(
              Icons.check_circle_outline,
              color: AppColors.mintIcon,
              size: 48,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Order Confirmed!',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order $orderId saved. Stock updated for ${customerName.isEmpty ? 'Walk-in' : customerName} via $_selectedPaymentMethod.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Store',
                  style: TextStyle(
                    color: AppColors.darkGreenTop,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('[Checkout] Failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checkout failed: $e'),
          backgroundColor: AppColors.accentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = _selectedPaymentMethod == 'Credit / Utang';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkBackgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textWhite),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Checkout',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.fieldGreen.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.mintIcon.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ORDER SUMMARY',
                              style: TextStyle(
                                color: AppColors.textFaint,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Items:',
                                    style:
                                        TextStyle(color: AppColors.textMuted)),
                                Text('${widget.itemCount} pcs',
                                    style: const TextStyle(
                                        color: AppColors.textWhite,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Payable:',
                                    style:
                                        TextStyle(color: AppColors.textMuted)),
                                Text(
                                    SettingsStore.instance
                                        .formatMoney(widget.totalAmount),
                                    style: const TextStyle(
                                        color: AppColors.accentOrange,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text(
                            'Customer Name',
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isCredit)
                            const Text(
                              ' * (Required)',
                              style: TextStyle(
                                color: AppColors.accentRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customerController,
                        style: const TextStyle(color: AppColors.textWhite),
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: isCredit
                              ? 'Enter borrower name (e.g., Juan Cruz)'
                              : 'Enter name (Optional)',
                          hintStyle:
                              const TextStyle(color: AppColors.textFaint),
                          filled: true,
                          fillColor:
                              AppColors.fieldGreen.withValues(alpha: 0.4),
                          errorText: _errorMessage,
                          errorStyle:
                              const TextStyle(color: AppColors.accentRed),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isCredit
                                  ? AppColors.accentOrange
                                  : AppColors.mintIcon.withValues(alpha: 0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isCredit
                                  ? AppColors.accentOrange
                                  : AppColors.mintIcon.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _paymentOption('Cash', Icons.payments_outlined),
                      _paymentOption(
                          'GCash', Icons.account_balance_wallet_outlined),
                      _paymentOption(
                          'Credit / Utang', Icons.assignment_outlined),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _confirmOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.darkGreenTop,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isCredit
                                ? 'Save Utang & View List'
                                : 'Complete Order',
                            style: const TextStyle(
                              color: AppColors.darkGreenTop,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentOption(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.fieldGreen.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.accentOrange
              : AppColors.mintIcon.withValues(alpha: 0.2),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon,
              color: isSelected ? AppColors.accentOrange : AppColors.mintIcon),
          title: Text(method,
              style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          trailing: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? AppColors.accentOrange : AppColors.textFaint,
          ),
          onTap: () {
            setState(() {
              _selectedPaymentMethod = method;
              _errorMessage = null;
            });
          },
        ),
      ),
    );
  }
}