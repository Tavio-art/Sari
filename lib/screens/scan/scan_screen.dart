import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/product.dart';
import '../../services/cart_store.dart';
import '../../services/scan_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_image.dart';
import '../cart/cart_screen.dart';

enum _ScanAction { choose, addInventory, checkout }

class ScanScreen extends StatefulWidget {
  final String? scannedBarcode;
  final bool showBackButton;
  final VoidCallback? onOpenCart;
  final bool isActive;

  const ScanScreen({
    super.key,
    this.scannedBarcode,
    this.showBackButton = false,
    this.onOpenCart,
    this.isActive = true,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  final ScanService _scanService = ScanService();

  String? _lastCode;
  Product? _matchedProduct;
  bool _notFound = false;
  bool _loading = false;
  bool _torchOn = false;
  bool _busy = false;
  String? _errorMessage;
  _ScanAction _action = _ScanAction.choose;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      autoStart: widget.isActive,
    );
    if (widget.scannedBarcode != null && widget.scannedBarcode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleCode(widget.scannedBarcode!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      unawaited(_controller.start());
    } else {
      unawaited(_controller.stop());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_controller.stop());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_controller.start());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String code) async {
    if (_busy || code == _lastCode) return;

    debugPrint('[ScanScreen] Scanned barcode=$code — querying Firebase…');

    setState(() {
      _busy = true;
      _lastCode = code;
      _loading = true;
      _matchedProduct = null;
      _notFound = false;
      _errorMessage = null;
      _action = _ScanAction.choose;
    });

    // Pause camera so we don't keep re-firing while the prompt is open.
    try {
      await _controller.stop();
    } catch (_) {}

    final result = await _scanService.lookupBarcode(code);
    if (!mounted) return;

    if (!result.success) {
      debugPrint('[ScanScreen] Lookup failed: ${result.message}');
      setState(() {
        _loading = false;
        _errorMessage = result.message;
        _busy = false;
        _lastCode = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.accentRed,
        ),
      );
      unawaited(_controller.start());
      return;
    }

    setState(() {
      _loading = false;
      _matchedProduct = result.product;
      _notFound = !result.found;
    });

    // Always prompt: Inventory vs Cart after a successful scan.
    await _showScanChoiceDialog(
      code: code,
      product: result.product,
      found: result.found,
    );
  }

  Future<void> _showScanChoiceDialog({
    required String code,
    required Product? product,
    required bool found,
  }) async {
    final choice = await showDialog<_ScanAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.darkGreenMid,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            found ? (product?.name ?? 'Item found') : 'New barcode',
            style: const TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                found
                    ? 'Barcode $code detected. What do you want to do?'
                    : 'Barcode "$code" is not in inventory yet.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              if (found && product != null) ...[
                const SizedBox(height: 8),
                Text(
                  '₱${product.price.toStringAsFixed(2)} · ${product.stock} in stock',
                  style: const TextStyle(
                    color: AppColors.mintIcon,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, _ScanAction.addInventory),
              child: const Text(
                'Add to Inventory',
                style: TextStyle(
                  color: AppColors.mintIcon,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, _ScanAction.checkout),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
              ),
              child: const Text(
                'Add to Cart',
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

    if (choice == null) {
      _clearResult();
      unawaited(_controller.start());
      return;
    }

    if (choice == _ScanAction.checkout && product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Register the item first via Add to Inventory.',
          ),
        ),
      );
      setState(() => _action = _ScanAction.addInventory);
      return;
    }

    setState(() => _action = choice);
  }

  void _openCart() {
    if (widget.onOpenCart != null) {
      widget.onOpenCart!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    if (capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;
    _handleCode(rawValue);
  }

  void _clearResult() {
    setState(() {
      _lastCode = null;
      _matchedProduct = null;
      _notFound = false;
      _loading = false;
      _busy = false;
      _errorMessage = null;
      _action = _ScanAction.choose;
    });
    unawaited(_controller.start());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartStore.instance,
      builder: (context, _) {
        final cartItemCount = CartStore.instance.itemCount;
        final showResultArea = _matchedProduct != null ||
            _notFound ||
            _loading ||
            (_errorMessage != null && _lastCode != null);

        return Scaffold(
          backgroundColor: AppColors.darkGreenTop,
          body: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  return _CameraErrorView(
                    message: error.errorDetails?.message ??
                        error.errorCode.name,
                    onRetry: () => _controller.start(),
                  );
                },
              ),
              _ScannerOverlay(),
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      widget.showBackButton
                          ? _circleIconButton(
                              icon: Icons.arrow_back,
                              onTap: () => Navigator.of(context).pop(),
                            )
                          : const SizedBox(width: 42),
                      const Text(
                        'Scan Item',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          _circleIconButton(
                            icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                            onTap: () async {
                              await _controller.toggleTorch();
                              setState(() => _torchOn = !_torchOn);
                            },
                          ),
                          const SizedBox(width: 8),
                          Stack(
                            children: [
                              _circleIconButton(
                                icon: Icons.shopping_cart_outlined,
                                onTap: _openCart,
                              ),
                              if (cartItemCount > 0)
                                Positioned(
                                  right: 2,
                                  top: 2,
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 110,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.mintIcon),
                  ),
                )
              else if (showResultArea)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 90,
                  child: _ScanResultCard(
                    product: _matchedProduct,
                    scannedCode: _lastCode ?? '',
                    action: _action,
                    onActionChanged: (a) => setState(() => _action = a),
                    onDismiss: _clearResult,
                    onRegistered: () {
                      final code = _lastCode;
                      _clearResult();
                      if (code != null && code.isNotEmpty) {
                        _handleCode(code);
                      }
                    },
                    onOpenCart: _openCart,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textWhite, size: 20),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CameraErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkGreenTop,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined,
              color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Camera is not available',
            style: TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameSize = constraints.maxWidth * 0.7;
          return Stack(
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.45),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                    ),
                    Center(
                      child: Container(
                        width: frameSize,
                        height: frameSize,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Container(
                  width: frameSize,
                  height: frameSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.mintIcon, width: 2.5),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScanResultCard extends StatefulWidget {
  final Product? product;
  final String scannedCode;
  final _ScanAction action;
  final ValueChanged<_ScanAction> onActionChanged;
  final VoidCallback onDismiss;
  final VoidCallback onRegistered;
  final VoidCallback onOpenCart;

  const _ScanResultCard({
    required this.product,
    required this.scannedCode,
    required this.action,
    required this.onActionChanged,
    required this.onDismiss,
    required this.onRegistered,
    required this.onOpenCart,
  });

  @override
  State<_ScanResultCard> createState() => _ScanResultCardState();
}

class _ScanResultCardState extends State<_ScanResultCard> {
  final ScanService _scanService = ScanService();
  final ImagePicker _picker = ImagePicker();

  int _quantity = 1;
  bool _saving = false;
  String _imageUrl = '';

  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _hydrateFromProduct();
  }

  @override
  void didUpdateWidget(covariant _ScanResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product?.barcode != widget.product?.barcode ||
        oldWidget.scannedCode != widget.scannedCode) {
      _hydrateFromProduct();
    }
  }

  void _hydrateFromProduct() {
    final p = widget.product;
    _nameController.text = p?.name ?? '';
    _categoryController.text = p?.category ?? '';
    _priceController.text =
        p != null ? p.price.toStringAsFixed(2) : '';
    _stockController.text = '1';
    _imageUrl = p?.imageUrl ?? '';
    _quantity = 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 60,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _onCheckoutAdd() async {
    final product = widget.product;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'I-register muna ang item (Add to Inventory) bago i-checkout.',
          ),
        ),
      );
      return;
    }

    final alreadyInCart = CartStore.instance.quantityOf(
      product.barcode.isNotEmpty ? product.barcode : product.id,
    );
    final needed = alreadyInCart + _quantity;
    if (needed > product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kulang ang stock. Available: ${product.stock}, '
            'nasa cart: $alreadyInCart, hinihingi: $_quantity',
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    try {
      CartStore.instance.add(product, quantity: _quantity);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }
    debugPrint(
      '[ScanScreen] Added to cart: ${product.barcode} x$_quantity '
      '(cart total items: ${CartStore.instance.itemCount})',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $_quantity × ${product.name} to Cart'),
        action: SnackBarAction(
          label: 'VIEW CART',
          textColor: AppColors.accentOrange,
          onPressed: widget.onOpenCart,
        ),
      ),
    );
    widget.onDismiss();
  }

  Future<void> _onSubmitInventory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kailangan ng product name.')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid price.')),
      );
      return;
    }

    final qty = int.tryParse(_stockController.text.trim()) ?? _quantity;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be at least 1.')),
      );
      return;
    }

    setState(() => _saving = true);
    debugPrint(
      '[ScanScreen] Saving inventory barcode=${widget.scannedCode} qty=$qty',
    );

    final result = await _scanService.addToInventory(
      barcode: widget.scannedCode,
      name: name,
      category: _categoryController.text.trim().isEmpty
          ? 'Uncategorized'
          : _categoryController.text.trim(),
      price: price,
      quantity: qty,
      imageUrl: _imageUrl,
      addToExistingStock: widget.product != null,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? null : AppColors.accentRed,
      ),
    );

    if (result.success) {
      widget.onRegistered();
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final maxHeight = MediaQuery.of(context).size.height * 0.62;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        gradient: AppColors.backgroundGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.mintIcon.withValues(alpha: 0.25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textFaint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textFaint, size: 20),
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
            _buildHeader(product),
            const SizedBox(height: 14),
            if (widget.action == _ScanAction.choose) ...[
              const Text(
                'What do you want to do?',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          widget.onActionChanged(_ScanAction.addInventory),
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: const Text(
                        'Add to Inventory',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mintIcon,
                        side: const BorderSide(
                            color: AppColors.mintIcon, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: product == null
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Register the item first via Add to Inventory.',
                                  ),
                                ),
                              );
                              widget.onActionChanged(_ScanAction.addInventory);
                            }
                          : () =>
                              widget.onActionChanged(_ScanAction.checkout),
                      icon: const Icon(Icons.shopping_cart,
                          size: 18, color: AppColors.darkGreenTop),
                      label: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          color: AppColors.darkGreenTop,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (widget.action == _ScanAction.addInventory) ...[
              _buildInventoryForm(product),
            ] else ...[
              _buildCheckoutForm(product!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Product? product) {
    if (product != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ProductImage(
              imageUrl: product.imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.category,
                    style: const TextStyle(
                        color: AppColors.mintIcon,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                Text(product.name,
                    style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '₱${product.price.toStringAsFixed(2)} · ${product.stock} in stock',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
                Text(
                  'Barcode: ${widget.scannedCode}',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentRed.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, color: AppColors.accentRed),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New item',
                  style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Text(
                'Barcode "${widget.scannedCode}" — not in inventory yet.',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryForm(Product? product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => widget.onActionChanged(_ScanAction.choose),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back'),
          style: TextButton.styleFrom(foregroundColor: AppColors.mintIcon),
        ),
        Text(
          'Barcode: ${widget.scannedCode}',
          style: const TextStyle(
            color: AppColors.mintIcon,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Auto-filled from scan — no manual entry needed.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: const InputDecoration(labelText: 'Product Name'),
        ),
        TextField(
          controller: _categoryController,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: const InputDecoration(labelText: 'Category'),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _priceController,
                style: const TextStyle(color: AppColors.textWhite),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _stockController,
                style: const TextStyle(color: AppColors.textWhite),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: product != null ? 'Qty to add' : 'Initial Stock',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ProductImage(
                imageUrl: _imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(
                  _imageUrl.isEmpty ? 'Attach picture' : 'Change picture',
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mintIcon,
                  side: const BorderSide(color: AppColors.mintIcon),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _onSubmitInventory,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    product != null ? 'Save to Inventory' : 'Register Item',
                    style: const TextStyle(
                      color: AppColors.darkGreenTop,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutForm(Product product) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => widget.onActionChanged(_ScanAction.choose),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back'),
            style: TextButton.styleFrom(foregroundColor: AppColors.mintIcon),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Quantity:',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(width: 16),
            _stepperButton(Icons.remove, () {
              if (_quantity > 1) setState(() => _quantity--);
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$_quantity',
                  style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            _stepperButton(Icons.add, () {
              if (_quantity < product.stock) {
                setState(() => _quantity++);
              }
            }),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Available: ${product.stock} · Line total: ₱${(product.price * _quantity).toStringAsFixed(2)}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: product.stock <= 0 || _saving ? null : _onCheckoutAdd,
            icon: const Icon(Icons.add_shopping_cart,
                size: 18, color: AppColors.darkGreenTop),
            label: Text(
              product.stock <= 0 ? 'Out of stock' : 'Add to Cart',
              style: const TextStyle(
                color: AppColors.darkGreenTop,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        TextButton(
          onPressed: widget.onOpenCart,
          child: Text(
            'View cart (${CartStore.instance.itemCount}) · ₱${CartStore.instance.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.mintIcon),
          ),
        ),
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.fieldGreen.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.textWhite),
      ),
    );
  }
}
