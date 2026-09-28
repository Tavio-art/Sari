import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/product_categories.dart';
import '../../models/product.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_image.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product? product;

  const ProductDetailScreen({super.key, this.product});

  static Future<void> show(BuildContext context, {Product? product}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => ProductDetailScreen(product: product),
    );
  }

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _barcodeController;

  late String _category;
  String _imageUrl = '';
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  List<String> get _categories {
    final values = ProductCategories.forPicker.toList();
    if (_category.isNotEmpty && !values.contains(_category)) {
      values.insert(0, _category);
    }
    return values;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController =
        TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _stockController =
        TextEditingController(text: p != null ? p.stock.toString() : '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _imageUrl = p?.imageUrl ?? '';
    final existing = p?.category.trim() ?? '';
    _category = existing.isEmpty ? 'Snacks' : existing;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
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
    final base64Str = base64Encode(bytes);
    setState(() {
      _imageUrl = 'data:image/jpeg;base64,$base64Str';
    });
  }

  Future<void> _pasteImageLink() async {
    final controller = TextEditingController(
      text: _imageUrl.startsWith('data:image') ? '' : _imageUrl,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGreenMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Paste image link',
            style: TextStyle(color: AppColors.textWhite)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle: const TextStyle(color: AppColors.textFaint),
            filled: true,
            fillColor: AppColors.fieldGreen.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _imageUrl = result);
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.darkGreenMid,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.mintIcon.withValues(alpha: 0.18),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mintIcon.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Product photo',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.fieldGreen,
                  child: Icon(Icons.photo_library_outlined,
                      color: AppColors.mintIcon),
                ),
                title: const Text('Choose from gallery',
                    style: TextStyle(color: AppColors.textWhite)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.fieldGreen,
                  child: Icon(Icons.link, color: AppColors.mintIcon),
                ),
                title: const Text('Paste image link',
                    style: TextStyle(color: AppColors.textWhite)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pasteImageLink();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _barcodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kailangan ng Name at Barcode.')),
      );
      return;
    }

    setState(() => _saving = true);

    final barcode = _barcodeController.text.trim();
    final updatedProduct = Product(
      id: barcode,
      name: _nameController.text.trim(),
      category: _category,
      // SKU is kept internally as barcode — not shown on Home UI.
      sku: barcode,
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
      imageUrl: _imageUrl,
      barcode: barcode,
    );

    try {
      if (_isEditing) {
        await _firebaseService.updateProduct(
          widget.product!.barcode,
          updatedProduct,
        );
      } else {
        await _firebaseService.registerProduct(updatedProduct);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Na-update na!' : 'Naidagdag na!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('May error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGreenMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Remove this product?',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          '“${widget.product!.name}” will be deleted from your store. This cannot be undone.',
          style: const TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              minimumSize: const Size(120, 44),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await _firebaseService.deleteProduct(widget.product!.barcode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nabura na ang product.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('May error: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF16382C), AppColors.darkGreenTop],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: AppColors.mintIcon.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mintIcon.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close,
                            color: AppColors.textMuted),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _isEditing ? 'Edit product' : 'New product',
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _isEditing
                                  ? 'Update details or remove from store'
                                  : 'Add an item to your sari-sari inventory',
                              style: const TextStyle(
                                color: AppColors.textFaint,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showImageOptions,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: ProductImage(
                                    imageUrl: _imageUrl,
                                    fit: BoxFit.cover,
                                    placeholderIcon: Icons.add_a_photo_outlined,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.darkGreenTop,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(Icons.camera_alt_outlined,
                                    size: 14, color: AppColors.darkGreenTop),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _field(
                          label: 'Item name',
                          controller: _nameController,
                          icon: Icons.inventory_2_outlined,
                        ),
                        _categoryField(),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label:
                                    'Price (${SettingsStore.instance.currencySymbol})',
                                controller: _priceController,
                                icon: Icons.payments_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                label: 'Stock',
                                controller: _stockController,
                                icon: Icons.layers_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        _field(
                          label: 'Barcode',
                          controller: _barcodeController,
                          icon: Icons.qr_code_2,
                          readOnly: _isEditing,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.darkGreenTop,
                                    ),
                                  )
                                : Text(_isEditing
                                    ? 'Save changes'
                                    : 'Add product'),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _delete,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove product'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentRed,
                                side: const BorderSide(
                                    color: AppColors.accentRed),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _categories.contains(_category) ? _category : null,
        items: _categories
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(c, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _category = value);
        },
        dropdownColor: AppColors.darkGreenMid,
        icon: const Icon(Icons.keyboard_arrow_down,
            color: AppColors.mintIcon),
        style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
        decoration: InputDecoration(
          labelText: 'Category',
          prefixIcon: const Icon(Icons.category_outlined,
              color: AppColors.mintIcon, size: 20),
          labelStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.fieldGreen.withValues(alpha: 0.45),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: const TextStyle(color: AppColors.textWhite),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.mintIcon, size: 20),
          labelStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.fieldGreen.withValues(alpha: 0.45),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
