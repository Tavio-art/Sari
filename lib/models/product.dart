class Product {
  final String id;
  final String name;
  final String category;
  final String sku;
  final double price;
  final int stock;
  final String imageUrl;
  final String barcode;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.sku,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.barcode,
  });

  bool get isLowStock => stock > 0 && stock <= 5;
  bool get isOutOfStock => stock == 0;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'sku': sku,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'barcode': barcode,
    };
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    final barcode = (map['barcode'] ?? '').toString().trim();
    final resolvedBarcode = barcode.isNotEmpty ? barcode : id;
    return Product(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      sku: map['sku'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      stock: (map['stock'] ?? 0).toInt(),
      imageUrl: (map['imageUrl'] ?? map['image'] ?? '').toString(),
      barcode: resolvedBarcode,
    );
  }


  String get key => barcode.isNotEmpty ? barcode : id;

  Product copyWithBarcode(String newBarcode) {
    final code = newBarcode.trim();
    return Product(
      id: code.isNotEmpty ? code : id,
      name: name,
      category: category,
      sku: sku,
      price: price,
      stock: stock,
      imageUrl: imageUrl,
      barcode: code.isNotEmpty ? code : barcode,
    );
  }
}