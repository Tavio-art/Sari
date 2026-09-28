import 'dart:convert';
import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData placeholderIcon;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.inventory_2_outlined,
  });

  bool get _isDataUri => imageUrl.startsWith('data:image');

  bool get _isNetworkUrl =>
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

  /// Firestore often stores just a filename (e.g. `sist.jpg`) from uploads/.
  String? get _assetPath {
    final raw = imageUrl.trim().replaceAll('\\', '/');
    if (raw.isEmpty || _isDataUri || _isNetworkUrl) return null;

    if (raw.startsWith('assets/')) return raw;

    final fileName = raw.split('/').last;
    if (fileName.isEmpty) return null;
    return 'assets/uploads/$fileName';
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _placeholder();
    }

    if (_isDataUri) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      } catch (_) {
        return _placeholder();
      }
    }

    final assetPath = _assetPath;
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      child: Icon(placeholderIcon, color: Colors.grey.shade600),
    );
  }
}