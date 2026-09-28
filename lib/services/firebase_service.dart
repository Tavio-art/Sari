import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';

class FirebaseService {
  FirebaseService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String inventoryPath = 'inventory';
  static const String legacyProductsPath = 'products';
  static const String ordersPath = 'orders';
  static const String creditsPath = 'credits';

  CollectionReference<Map<String, dynamic>> get _inventory =>
      _db.collection(inventoryPath);

  CollectionReference<Map<String, dynamic>> get _legacyProducts =>
      _db.collection(legacyProductsPath);

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(ordersPath);

  CollectionReference<Map<String, dynamic>> get _credits =>
      _db.collection(creditsPath);

  void _log(String message, [Object? error, StackTrace? stack]) {
    if (error != null) {
      debugPrint('[FirebaseService] $message → $error');
      if (stack != null) debugPrint('$stack');
    } else {
      debugPrint('[FirebaseService] $message');
    }
  }

  Map<String, dynamic> _withTimestamps(
    Map<String, dynamic> data, {
    bool isCreate = false,
  }) {
    final now = FieldValue.serverTimestamp();
    final out = Map<String, dynamic>.from(data)..['updatedAt'] = now;
    if (isCreate) out['createdAt'] = now;
    return out;
  }

  /// App + web both filter products by `userId`. Also mirror `image` for web.
  Map<String, dynamic> _ownedProductData(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      out['userId'] = uid;
    }
    final imageUrl = (out['imageUrl'] ?? out['image'] ?? '').toString();
    if (imageUrl.isNotEmpty) {
      out['imageUrl'] = imageUrl;
      out['image'] = imageUrl;
    }
    return out;
  }

  Future<void> _removeDuplicateBarcodeDocs(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return;

    try {
      for (final collection in [_inventory, _legacyProducts]) {
        final query = await collection.where('barcode', isEqualTo: code).get();
        for (final doc in query.docs) {
          if (doc.id != code) {
            _log('Removing duplicate ${collection.path}/${doc.id} (barcode=$code)');
            await doc.reference.delete();
          }
        }
      }
    } catch (e, st) {
      _log('cleanup duplicates failed for $code', e, st);
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;

    try {
      _log('Looking up barcode=$code in$inventoryPath');
      final invDoc = await _inventory.doc(code).get();
      if (invDoc.exists && invDoc.data() != null) {
        _log('Found in $inventoryPath/$code');
        await _removeDuplicateBarcodeDocs(code);
        return Product.fromMap(invDoc.id, invDoc.data()!);
      }

      final invQuery = await _inventory
          .where('barcode', isEqualTo: code)
          .limit(1)
          .get();
      if (invQuery.docs.isNotEmpty) {
        final found = invQuery.docs.first;
        final product = Product.fromMap(found.id, found.data());
        _log('Found via inventory barcode query ${found.id} — normalizing to doc id=$code');

        await _mirrorToInventory(product.copyWithBarcode(code), fromLegacy: false);
        if (found.id != code) {
          await found.reference.delete();
        }
        await _removeDuplicateBarcodeDocs(code);
        return Product.fromMap(code, {
          ...found.data(),
          'barcode': code,
        });
      }

      _log('Not in inventory — checking legacy $legacyProductsPath');
      final legacyDoc = await _legacyProducts.doc(code).get();
      if (legacyDoc.exists && legacyDoc.data() != null) {
        final product =
            Product.fromMap(legacyDoc.id, legacyDoc.data()!);
        await _mirrorToInventory(product, fromLegacy: true);
        await _removeDuplicateBarcodeDocs(code);
        return product;
      }

      final legacyQuery = await _legacyProducts
          .where('barcode', isEqualTo: code)
          .limit(1)
          .get();
      if (legacyQuery.docs.isNotEmpty) {
        final found = legacyQuery.docs.first;
        final product = Product.fromMap(found.id, {
          ...found.data(),
          'barcode': code,
        });
        await _mirrorToInventory(product.copyWithBarcode(code), fromLegacy: true);
        if (found.id != code) {
          await found.reference.delete();
        }
        await _removeDuplicateBarcodeDocs(code);
        return product.copyWithBarcode(code);
      }

      _log('Barcode $code not found in inventory or products');
      return null;
    } catch (e, st) {
      _log('getProductByBarcode failed for $code', e, st);
      rethrow;
    }
  }

  Future<void> _mirrorToInventory(
    Product product, {
    bool fromLegacy = false,
  }) async {
    try {
      final code = product.barcode.trim();
      if (code.isEmpty) return;
      final data = _withTimestamps(
        _ownedProductData({
          ...product.toMap(),
          'barcode': code,
        }),
        isCreate: true,
      );
      await _inventory.doc(code).set(data, SetOptions(merge: true));
      await _legacyProducts.doc(code).set(data, SetOptions(merge: true));
      if (fromLegacy) {
        _log('Mirrored legacy product $code → $inventoryPath +$legacyProductsPath');
      }
    } catch (e, st) {
      _log('Failed to mirror ${product.barcode}', e, st);
    }
  }

  Future<void> registerProduct(Product product) async {
    final code = product.barcode.trim();
    if (code.isEmpty) {
      throw ArgumentError('Barcode is required to register a product');
    }

    final data = _withTimestamps(
      _ownedProductData({
        ...product.toMap(),
        'barcode': code,
      }),
      isCreate: true,
    );
    _log('Registering inventory/$code userId=${data['userId']}');

    try {
      final batch = _db.batch();
      // Sinisigurong isinusulat sa parehong inventory at legacyProducts (products collection)
      batch.set(_inventory.doc(code), data, SetOptions(merge: true));
      batch.set(_legacyProducts.doc(code), data, SetOptions(merge: true));
      await batch.commit();
      await _removeDuplicateBarcodeDocs(code);
      _log('Registered product to inventory & products OK');
    } catch (e, st) {
      _log('registerProduct failed for $code', e, st);
      rethrow;
    }
  }

  Future<void> addStock(String productId, int quantityToAdd) async {
    if (quantityToAdd <= 0) {
      throw ArgumentError('quantityToAdd must be > 0');
    }
    final code = productId.trim();
    _log('Adding +$quantityToAdd stock to$code');

    try {
      await _db.runTransaction((tx) async {
        final invRef = _inventory.doc(code);
        final legacyRef = _legacyProducts.doc(code);

        final invSnap = await tx.get(invRef);
        final legacySnap = await tx.get(legacyRef);

        DocumentSnapshot<Map<String, dynamic>>? source;
        if (invSnap.exists) {
          source = invSnap;
        } else if (legacySnap.exists) {
          source = legacySnap;
        }

        if (source == null) {
          throw StateError('Product $code not found — cannot add stock');
        }

        final current = (source.data()?['stock'] as num?)?.toInt() ?? 0;
        final next = current + quantityToAdd;
        final patch = {
          'stock': next,
          'barcode': code,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        tx.set(invRef, {...?source.data(), ...patch}, SetOptions(merge: true));
        tx.set(legacyRef, {...?source.data(), ...patch},
            SetOptions(merge: true));
      });
      await _removeDuplicateBarcodeDocs(code);
      _log('Stock update OK for $code');
    } catch (e, st) {
      _log('addStock failed for $code', e, st);
      rethrow;
    }
  }

  Future<Product> upsertInventoryItem({
    required String barcode,
    required String name,
    required String category,
    required double price,
    required int quantity,
    String imageUrl = '',
    String? sku,
    bool addToExistingStock = true,
  }) async {
    final code = barcode.trim();
    if (code.isEmpty) throw ArgumentError('Barcode required');
    if (name.trim().isEmpty) throw ArgumentError('Product name required');
    if (price < 0) throw ArgumentError('Price cannot be negative');
    if (quantity < 0) throw ArgumentError('Quantity cannot be negative');

    _log(
      'upsertInventory barcode=$code qty=$quantity addToExisting=$addToExistingStock',
    );

    try {
      final product = await _db.runTransaction((tx) async {
        final invRef = _inventory.doc(code);
        final legacyRef = _legacyProducts.doc(code);
        final invSnap = await tx.get(invRef);
        final legacySnap = await tx.get(legacyRef);

        final existing = invSnap.exists
            ? invSnap.data()
            : (legacySnap.exists ? legacySnap.data() : null);

        final prevStock = (existing?['stock'] as num?)?.toInt() ?? 0;
        final nextStock =
            addToExistingStock && existing != null ? prevStock + quantity : quantity;

        final product = Product(
          id: code,
          name: name.trim(),
          category: category.trim().isEmpty ? 'Uncategorized' : category.trim(),
          sku: (sku ?? code).trim(),
          price: price,
          stock: nextStock,
          imageUrl: imageUrl.isNotEmpty
              ? imageUrl
              : (existing?['imageUrl'] as String? ??
                  existing?['image'] as String? ??
                  ''),
          barcode: code,
        );

        final owned = _ownedProductData({
          ...product.toMap(),
        });
        final existingUid = existing?['userId']?.toString().trim();
        if (existingUid != null && existingUid.isNotEmpty) {
          owned['userId'] = existingUid;
        }

        final data = _withTimestamps(
          owned,
          isCreate: existing == null,
        );

        // Sabay na isinusulat sa inventory at products para mag-sync sa web
        tx.set(invRef, data, SetOptions(merge: true));
        tx.set(legacyRef, data, SetOptions(merge: true));
        return product;
      });

      await _removeDuplicateBarcodeDocs(code);
      return product;
    } catch (e, st) {
      _log('upsertInventoryItem failed for $code', e, st);
      rethrow;
    }
  }

  Stream<List<Product>> watchProducts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _legacyProducts
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final byBarcode = <String, Product>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final normalizedData = {
          ...data,
          'imageUrl': data['imageUrl'] ?? data['image'] ?? '',
          'barcode': data['barcode'] ?? doc.id,
        };
        
        final product = Product.fromMap(doc.id, normalizedData);
        final key = product.key;
        if (key.isEmpty) continue;

        final existing = byBarcode[key];
        if (existing == null || doc.id == key) {
          byBarcode[key] = product;
        }
      }
      final list = byBarcode.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<void> initializeDefaultProducts(String userId) async {
    try {
      final querySnapshot = await _legacyProducts.where('userId', isEqualTo: userId).get();

      if (querySnapshot.docs.isEmpty) {
        _log('No products found for user in mobile. Inserting default products...');
        final batch = _db.batch();

        final List<Map<String, dynamic>> defaultProducts = [
          { 'name': 'Sisters Sanitary Pad', 'category': 'Household', 'price': 38.00, 'stock': 15, 'image': 'sist.jpg' },
          { 'name': 'Modess Sanitary Napkin 8s', 'category': 'Household', 'price': 45.00, 'stock': 15, 'image': 'mod.jpg' },
          { 'name': 'Scotch Brite Sponge', 'category': 'Household', 'price': 25.00, 'stock': 15, 'image': 'sb.jpg' },
          { 'name': 'Katol (Mosquito Coil)', 'category': 'Household', 'price': 22.00, 'stock': 20, 'image': 'kat.jpg' },
          { 'name': 'Zonrox Bleach 250ml', 'category': 'Household', 'price': 22.00, 'stock': 15, 'image': 'zon.jpg' },
          { 'name': 'Champion Bar Soap', 'category': 'Household', 'price': 28.00, 'stock': 25, 'image': 'champ.jpg' },
          { 'name': 'Downy Fabric Conditioner Sachet', 'category': 'Household', 'price': 8.00, 'stock': 50, 'image': 'down.jpg' },
          { 'name': 'Sunsilk Shampoo Sachet', 'category': 'Household', 'price': 7.00, 'stock': 50, 'image': 'suns.jpg' },
          { 'name': 'Colgate Toothpaste Small', 'category': 'Household', 'price': 24.00, 'stock': 20, 'image': 'colg.jpg' },
          { 'name': 'Creamsilk Conditioner Sachet', 'category': 'Household', 'price': 8.00, 'stock': 50, 'image': 'cream.jpg' },
          { 'name': 'Palmolive Shampoo Sachet', 'category': 'Household', 'price': 7.00, 'stock': 50, 'image': 'palm.jpg' },
          { 'name': 'Safeguard Bar Soap White', 'category': 'Household', 'price': 32.00, 'stock': 25, 'image': 'safe.jpg' },
          { 'name': 'Gatorade Blue Bolt', 'category': 'Beverage', 'price': 40.00, 'stock': 15, 'image': 'gat.jpg' },
          { 'name': 'Zesto Juice Orange', 'category': 'Beverage', 'price': 10.00, 'stock': 30, 'image': 'zes_o.jpg' },
          { 'name': 'Zesto Juice Apple', 'category': 'Beverage', 'price': 10.00, 'stock': 30, 'image': 'zes_a.jpg' },
          { 'name': 'Sprite 1.5L', 'category': 'Beverage', 'price': 72.00, 'stock': 10, 'image': 'spr_15.jpg' },
          { 'name': 'Royal 1.5L', 'category': 'Beverage', 'price': 72.00, 'stock': 10, 'image': 'roy_15.jpg' },
          { 'name': "Nature's Spring 500ml", 'category': 'Beverage', 'price': 12.00, 'stock': 40, 'image': 'nat.jpg' },
          { 'name': 'C2 Apple 500ml', 'category': 'Beverage', 'price': 25.00, 'stock': 25, 'image': 'c2_a.jpg' },
          { 'name': 'Sting Energy Drink', 'category': 'Beverage', 'price': 25.00, 'stock': 30, 'image': 'sti.jpg' },
          { 'name': 'Coke 500ml', 'category': 'Beverage', 'price': 35.00, 'stock': 24, 'image': 'cok.jpg' },
        ];

        for (final prod in defaultProducts) {
          final newDocRef = _legacyProducts.doc();
          batch.set(newDocRef, {
            'userId': userId,
            'name': prod['name'],
            'category': prod['category'],
            'price': prod['price'],
            'stock': prod['stock'],
            'image': prod['image'],
            'imageUrl': prod['image'],
            'barcode': newDocRef.id,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        _log('Default products successfully initialized in mobile!');
      }
    } catch (e, st) {
      _log('initializeDefaultProducts mobile failed', e, st);
    }
  }

  Stream<QuerySnapshot> getAllProducts() {
    return _inventory.orderBy('name').snapshots();
  }

  Stream<QuerySnapshot> getInventoryStream() {
    return _inventory.orderBy('name').snapshots();
  }

  Future<void> updateProduct(String oldBarcode, Product updated) async {
    final data = _withTimestamps(
      _ownedProductData({
        ...updated.toMap(),
        'barcode': updated.barcode.trim(),
      }),
    );
    try {
      if (oldBarcode == updated.barcode) {
        final batch = _db.batch();
        batch.set(_inventory.doc(oldBarcode), data, SetOptions(merge: true));
        batch.set(_legacyProducts.doc(oldBarcode), data, SetOptions(merge: true));
        await batch.commit();
        await _removeDuplicateBarcodeDocs(oldBarcode);
      } else {
        final batch = _db.batch();
        batch.set(_inventory.doc(updated.barcode), data);
        batch.set(_legacyProducts.doc(updated.barcode), data);
        batch.delete(_inventory.doc(oldBarcode));
        batch.delete(_legacyProducts.doc(oldBarcode));
        await batch.commit();
        await _removeDuplicateBarcodeDocs(updated.barcode);
      }
      _log('Updated product ${updated.barcode}');
    } catch (e, st) {
      _log('updateProduct failed', e, st);
      rethrow;
    }
  }

  Future<void> deleteProduct(String barcode) async {
    final code = barcode.trim();
    final batch = _db.batch();
    batch.delete(_inventory.doc(code));
    batch.delete(_legacyProducts.doc(code));
    await batch.commit();
    await _removeDuplicateBarcodeDocs(code);
    _log('Deleted product $code');
  }

  Future<String> checkoutOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    String customerName = '',
    String? userId,
  }) async {
    if (items.isEmpty) {
      throw StateError('Cart is empty — nothing to checkout');
    }

    _log('Starting checkout: ${items.length} lines, total=$totalAmount');

    try {
      final orderId = await _db.runTransaction<String>((tx) async {
        final stockPatches = <String, int>{};
        final resolvedItems = <Map<String, dynamic>>[];

        for (final raw in items) {
          final barcode = (raw['barcode'] ?? raw['id'] ?? '').toString().trim();
          final qty = (raw['quantity'] as num?)?.toInt() ?? 0;
          if (barcode.isEmpty || qty <= 0) {
            throw StateError('Invalid cart line: barcode/qty missing');
          }

          final invRef = _inventory.doc(barcode);
          final legacyRef = _legacyProducts.doc(barcode);
          final invSnap = await tx.get(invRef);
          final legacySnap = await tx.get(legacyRef);

          Map<String, dynamic>? data;
          if (invSnap.exists) {
            data = invSnap.data();
          } else if (legacySnap.exists) {
            data = legacySnap.data();
          }

          if (data == null) {
            throw StateError('Item "$barcode" is not in inventory');
          }

          final stock = (data['stock'] as num?)?.toInt() ?? 0;
          if (qty > stock) {
            final name = data['name'] ?? barcode;
            throw StateError(
              'Not enough stock for $name (have $stock, need$qty)',
            );
          }

          stockPatches[barcode] = stock - qty;
          resolvedItems.add({
            'barcode': barcode,
            'id': barcode,
            'name': data['name'] ?? raw['name'] ?? barcode,
            'price': (raw['price'] as num?)?.toDouble() ??
                (data['price'] as num?)?.toDouble() ??
                0,
            'quantity': qty,
            'subtotal': ((raw['price'] as num?)?.toDouble() ??
                    (data['price'] as num?)?.toDouble() ??
                    0) *
                qty,
          });
        }

        final orderRef = _orders.doc();
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        tx.set(orderRef, {
          'orderId': orderRef.id,
          'items': resolvedItems,
          'totalAmount': totalAmount,
          'paymentMethod': paymentMethod,
          'customerName': customerName,
          'userId': userId,
          'status': 'completed',
          'source': 'mobile_app',
          'createdAtMs': nowMs,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        for (final entry in stockPatches.entries) {
          final patch = {
            'stock': entry.value,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          tx.set(_inventory.doc(entry.key), patch, SetOptions(merge: true));
          tx.set(_legacyProducts.doc(entry.key), patch, SetOptions(merge: true));
        }

        return orderRef.id;
      });

      _log('Checkout OK orderId=$orderId');
      return orderId;
    } catch (e, st) {
      _log('checkoutOrder failed', e, st);
      rethrow;
    }
  }

  Future<String> addCredit({
    required String userId,
    required String customerName,
    required double amount,
    required String saleId,
    String date = '',
  }) async {
    final ref = _credits.doc();
    await ref.set({
      'creditId': ref.id,
      'userId': userId,
      'customerName': customerName,
      'amount': amount,
      'date': date,
      'isPaid': false,
      'saleId': saleId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log('Credit saved ${ref.id} for$customerName');
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCreditsStream(String userId) {
    return _credits.where('userId', isEqualTo: userId).snapshots();
  }

  Future<void> setCreditPaid(String creditId, bool isPaid) async {
    await _credits.doc(creditId).update({
      'isPaid': isPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Orders for [userId] (defaults to the signed-in user).
  /// Queries by userId without composite index so it works out-of-the-box.
  Stream<QuerySnapshot> getOrdersStream({
    String? userId,
    int limit = 50,
  }) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }

    return _orders
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  Future<String> createManualOrder({
    required String customerName,
    required double totalAmount,
    required int itemCount,
    required String paymentMethod,
    required String status,
    String? userId,
    String note = '',
  }) async {
    final ref = _orders.doc();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await ref.set({
      'orderId': ref.id,
      'customerName': customerName.trim().isEmpty ? 'Walk-in' : customerName.trim(),
      'totalAmount': totalAmount,
      'itemCount': itemCount,
      'paymentMethod': paymentMethod,
      'status': status,
      'note': note,
      'userId': userId,
      'items': [
        {
          'name': note.isNotEmpty ? note : 'Manual order',
          'quantity': itemCount <= 0 ? 1 : itemCount,
          'price': itemCount > 0 ? totalAmount / itemCount : totalAmount,
          'subtotal': totalAmount,
        },
      ],
      'source': 'manual',
      'createdAtMs': nowMs,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log('Manual order created ${ref.id}');
    return ref.id;
  }
}