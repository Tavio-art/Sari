import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'firebase_service.dart';

class ScanService {
  ScanService({FirebaseService? firebase})
      : _firebase = firebase ?? FirebaseService();

  final FirebaseService _firebase;

  void _log(String message, [Object? error]) {
    if (error != null) {
      debugPrint('[ScanService] $message → $error');
    } else {
      debugPrint('[ScanService] $message');
    }
  }

  Future<String?> _requireUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _log('No authenticated user');
      return null;
    }
    return user.uid;
  }

  
  Future<ScanResult> lookupBarcode(String barcode) async {
    final code = barcode.trim();
    _log('lookupBarcode code=$code');

    if (code.isEmpty) {
      return ScanResult(
        success: false,
        message: 'Empty barcode scanned.',
      );
    }

    try {
      final product = await _firebase.getProductByBarcode(code);
      if (product == null) {
        _log('Barcode not found: $code');
        return ScanResult(
          success: true,
          message: 'Bagong item — wala pang record sa inventory.',
          barcode: code,
          found: false,
        );
      }

      _log('Barcode found: ${product.name} stock=${product.stock}');
      return ScanResult(
        success: true,
        message: 'Nakita: ${product.name}',
        barcode: code,
        found: true,
        itemName: product.name,
        newStockCount: product.stock,
        product: product,
      );
    } catch (e) {
      _log('lookupBarcode failed', e);
      return ScanResult(
        success: false,
        message: 'Hindi ma-connect sa Firebase: $e',
        barcode: code,
      );
    }
  }

  
  Future<ScanResult> addToInventory({
    required String barcode,
    required String name,
    required String category,
    required double price,
    required int quantity,
    String imageUrl = '',
    bool addToExistingStock = true,
  }) async {
    final uid = await _requireUser();
    if (uid == null) {
      return ScanResult(
        success: false,
        message: 'Walang naka-login na user. Mag-login muna.',
        barcode: barcode,
      );
    }

    _log(
      'addToInventory barcode=$barcode qty=$quantity price=$price user=$uid',
    );

    try {
      final product = await _firebase.upsertInventoryItem(
        barcode: barcode,
        name: name,
        category: category,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
        addToExistingStock: addToExistingStock,
      );

      _log('addToInventory OK stock=${product.stock}');
      return ScanResult(
        success: true,
        message:
            'Na-save sa inventory: ${product.name} (stock ${product.stock})',
        barcode: barcode,
        found: true,
        itemName: product.name,
        newStockCount: product.stock,
        product: product,
      );
    } catch (e) {
      _log('addToInventory failed', e);
      return ScanResult(
        success: false,
        message: 'Hindi na-save ang inventory: $e',
        barcode: barcode,
      );
    }
  }


  Future<ScanResult> addStock({
    required String barcode,
    required int quantity,
  }) async {
    final uid = await _requireUser();
    if (uid == null) {
      return ScanResult(
        success: false,
        message: 'Walang naka-login na user. Mag-login muna.',
        barcode: barcode,
      );
    }

    _log('addStock barcode=$barcode qty=$quantity');

    try {
      await _firebase.addStock(barcode, quantity);
      final updated = await _firebase.getProductByBarcode(barcode);
      return ScanResult(
        success: true,
        message:
            'Added +$quantity stock${updated != null ? ' (new total: ${updated.stock})' : ''}',
        barcode: barcode,
        found: true,
        itemName: updated?.name,
        newStockCount: updated?.stock,
        product: updated,
      );
    } catch (e) {
      _log('addStock failed', e);
      return ScanResult(
        success: false,
        message: 'Hindi na-update ang stock: $e',
        barcode: barcode,
      );
    }
  }
}

class ScanResult {
  final bool success;
  final String message;
  final String? barcode;
  final bool found;
  final String? itemName;
  final int? newStockCount;
  final double? checkoutTotal;
  final Product? product;

  ScanResult({
    required this.success,
    required this.message,
    this.barcode,
    this.found = false,
    this.itemName,
    this.newStockCount,
    this.checkoutTotal,
    this.product,
  });
}
