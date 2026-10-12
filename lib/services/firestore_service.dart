import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/cracker_item.dart';
import '../models/invoice.dart';
import '../models/invoice_line_item.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  static String? resolveUserId({String? userId}) {
    final explicitUserId = userId?.trim();
    if (explicitUserId != null && explicitUserId.isNotEmpty) {
      return explicitUserId;
    }

    if (Firebase.apps.isEmpty) {
      return null;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim();
    if (currentUserId != null && currentUserId.isNotEmpty) {
      return currentUserId;
    }

    return null;
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _salesCollection =>
      _db.collection('sales');

  CollectionReference<Map<String, dynamic>> get _inventoryCollection =>
      _db.collection('inventory');

  CollectionReference<Map<String, dynamic>> get _settingsCollection =>
      _db.collection('app_settings');

  Future<void> saveInventoryItem(CrackerItem item, {String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _inventoryCollection.doc(item.id).set({
      'id': item.id,
      'name': item.name,
      'category': item.category,
      'subCategory': item.subCategory,
      'categoryCode': item.categoryCode,
      'subCategoryCode': item.subCategoryCode,
      'variantCode': item.variantCode,
      'itemCode': item.itemCode,
      'unitPrice': item.unitPrice,
      'stockAvailable': item.stockAvailable,
      'taxRate': item.taxRate,
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteInventoryItem(String itemId, {String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _inventoryCollection.doc(itemId).delete();
  }

  Future<List<CrackerItem>> fetchInventoryItems({String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return const [];
    }

    final resolvedUserId = resolveUserId(userId: userId);
    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    if (resolvedUserId != null) {
      queries.add(_inventoryCollection.where('userId', isEqualTo: resolvedUserId).get());
      queries.add(_inventoryCollection.where('userId', isEqualTo: 'anonymous').get());
    } else {
      queries.add(_inventoryCollection.where('userId', isEqualTo: 'anonymous').get());
    }

    for (final snapshot in await Future.wait(queries)) {
      for (final doc in snapshot.docs) {
        docsById.putIfAbsent(doc.id, () => doc);
      }
    }

    if (resolvedUserId != null) {
      final anonymousItems = docsById.values
          .where((doc) => doc.data()['userId'] == 'anonymous')
          .toList();

      for (final doc in anonymousItems) {
        final data = doc.data();
        await _inventoryCollection.doc(doc.id).set({
          ...data,
          'userId': resolvedUserId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    final items = docsById.values.map((doc) {
      final data = doc.data();
      return CrackerItem(
        id: data['id'] as String? ?? doc.id,
        name: data['name'] as String? ?? '',
        category: data['category'] as String? ?? '',
        subCategory: data['subCategory'] as String? ?? '',
        categoryCode: data['categoryCode'] as String?,
        subCategoryCode: data['subCategoryCode'] as String?,
        variantCode: data['variantCode'] as String?,
        itemCode: data['itemCode'] as String?,
        unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
        stockAvailable: (data['stockAvailable'] as num?)?.toInt() ?? 0,
        taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0.18,
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return items;
  }

  Future<void> saveCategoryCatalog(Map<String, List<String>> catalog, {String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _settingsCollection.doc('inventory_catalog').set({
      'catalog': catalog.map((key, value) => MapEntry(key, value)),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, List<String>>> fetchCategoryCatalog({String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return <String, List<String>>{};
    }

    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final snapshot = await _settingsCollection.doc('inventory_catalog').get();
    final data = snapshot.data();

    if (data == null || data['catalog'] is! Map) {
      return <String, List<String>>{};
    }

    final rawCatalog = data['catalog'] as Map<String, dynamic>;
    final result = <String, List<String>>{};

    rawCatalog.forEach((key, value) {
      if (value is List) {
        result[key] = value.map((item) => item.toString()).toList();
      }
    });

    if (result.isNotEmpty && data['userId'] == uid) {
      return result;
    }

    if (result.isEmpty && userId == null) {
      return <String, List<String>>{};
    }

    return result;
  }

  Future<void> saveInvoice(Invoice invoice, {String? userId}) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    await _salesCollection.add({
      'id': invoice.id,
      'customerName': invoice.customerName,
      'customerPhone': invoice.customerPhone,
      'date': Timestamp.fromDate(invoice.date),
      'discountAmount': invoice.discountAmount,
      'grossTotal': invoice.grossTotal,
      'taxTotal': invoice.taxTotal,
      'netTotal': invoice.netTotal,
      'lineItems': invoice.lineItems.map((item) => item.toMap()).toList(),
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Invoice>> invoicesStream({String? userId}) {
    Query<Map<String, dynamic>> query = _salesCollection.orderBy('date', descending: true);

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final lineItems = (data['lineItems'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .map((item) => InvoiceLineItem.fromMap(item))
            .toList();

        final invoice = Invoice(
          id: data['id'] as String? ?? doc.id,
          customerName: data['customerName'] as String? ?? '',
          customerPhone: data['customerPhone'] as String? ?? '',
          date: (data['date'] as Timestamp).toDate(),
          lineItems: lineItems,
          discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
        );
        invoice.recalculateTotals();
        return invoice;
      }).toList();
    });
  }

  Future<List<Invoice>> fetchInvoices({String? userId}) async {
    Query<Map<String, dynamic>> query = _salesCollection.orderBy('date', descending: true);

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final lineItems = (data['lineItems'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map((item) => InvoiceLineItem.fromMap(item))
          .toList();

      final invoice = Invoice(
        id: data['id'] as String? ?? doc.id,
        customerName: data['customerName'] as String? ?? '',
        customerPhone: data['customerPhone'] as String? ?? '',
        date: (data['date'] as Timestamp).toDate(),
        lineItems: lineItems,
        discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      );
      invoice.recalculateTotals();
      return invoice;
    }).toList();
  }
}
