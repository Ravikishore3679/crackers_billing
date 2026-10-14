import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/cracker_item.dart';
import '../models/invoice.dart';
import '../models/invoice_line_item.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();
  static final Set<String> _initializedCollectionsForSession = <String>{};

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

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _db.collection('users');

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) =>
      _usersCollection.doc(uid);

  CollectionReference<Map<String, dynamic>> _salesCollection(String uid) =>
      _userDocument(uid).collection('sales');

  CollectionReference<Map<String, dynamic>> _inventoryCollection(String uid) =>
      _userDocument(uid).collection('inventory');

  CollectionReference<Map<String, dynamic>> _settingsCollection(String uid) =>
      _userDocument(uid).collection('app_settings');

  DocumentReference<Map<String, dynamic>> _reportsDocument(String uid) =>
      _userDocument(uid).collection('reports').doc('summary');

  DocumentReference<Map<String, dynamic>> _expenseDocument(String uid) =>
      _userDocument(uid).collection('expenses').doc('entries');

  Future<void> _ensureUserDocument(
    String uid, {
    bool refreshCollections = false,
  }) async {
    final userDocument = _userDocument(uid);
    await userDocument.set({
      'uid': uid,
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!refreshCollections && _initializedCollectionsForSession.contains(uid)) {
      return;
    }

    final batch = _db.batch();
    final metadata = {
      'recordType': 'collection_metadata',
      'userId': uid,
    };
    final metadataDocumentId = '_collection';

    batch.set(
      _salesCollection(uid).doc(metadataDocumentId),
      metadata,
      SetOptions(merge: true),
    );
    batch.set(
      _inventoryCollection(uid).doc(metadataDocumentId),
      metadata,
      SetOptions(merge: true),
    );
    batch.set(
      _settingsCollection(uid).doc(metadataDocumentId),
      metadata,
      SetOptions(merge: true),
    );
    batch.set(
      _reportsDocument(uid).parent.doc(metadataDocumentId),
      metadata,
      SetOptions(merge: true),
    );
    batch.set(
      _expenseDocument(uid).parent.doc(metadataDocumentId),
      metadata,
      SetOptions(merge: true),
    );
    batch.set(
      userDocument,
      {'subcollectionsInitialized': true},
      SetOptions(merge: true),
    );

    await batch.commit();
    _initializedCollectionsForSession.add(uid);
  }

  Future<void> ensureUserCollections({String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _ensureUserDocument(uid, refreshCollections: true);
  }

  Future<void> saveExpenseEntries(
    List<Map<String, dynamic>> entries, {
    String? userId,
  }) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _ensureUserDocument(uid);

    await _expenseDocument(uid).set({
      'userId': uid,
      'entries': entries,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> fetchExpenseEntries({
    String? userId,
  }) async {
    if (Firebase.apps.isEmpty) {
      return const [];
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return const [];
    }

    await _ensureUserDocument(uid);

    final snapshot = await _expenseDocument(uid).get();
    final data = snapshot.data();
    final rawEntries = data?['entries'];

    if (rawEntries is! List) {
      return const [];
    }

    return rawEntries
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  Future<void> saveReportSummary({
    required double totalRevenue,
    required int totalUnitsSold,
    required double totalExpenditure,
    String? userId,
  }) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _ensureUserDocument(uid);

    await _reportsDocument(uid).set({
      'userId': uid,
      'totalRevenue': totalRevenue,
      'totalUnitsSold': totalUnitsSold,
      'totalExpenditure': totalExpenditure,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> fetchReportSummary({String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return {};
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return {};
    }

    await _ensureUserDocument(uid);

    final scopedSnapshot = await _reportsDocument(uid).get();
    final scopedData = scopedSnapshot.data();
    return scopedData ?? {};
  }

  Future<void> saveInventoryItem(CrackerItem item, {String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _ensureUserDocument(uid);

    await _inventoryCollection(uid).doc(item.id).set({
      'id': item.id,
      'name': item.name,
      'category': item.category,
      'subCategory': item.subCategory,
      'categoryCode': FieldValue.delete(),
      'subCategoryCode': FieldValue.delete(),
      'variantCode': FieldValue.delete(),
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

    await _inventoryCollection(uid).doc(itemId).delete();
  }

  Future<List<CrackerItem>> fetchInventoryItems({String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return const [];
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return const [];
    }

    await _ensureUserDocument(uid);

    final snapshot = await _inventoryCollection(uid).orderBy('name').get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      return CrackerItem(
        id: data['id'] as String? ?? doc.id,
        name: data['name'] as String? ?? '',
        category: data['category'] as String? ?? '',
        subCategory: data['subCategory'] as String? ?? '',
        itemCode: data['itemCode'] as String?,
        unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
        stockAvailable: (data['stockAvailable'] as num?)?.toInt() ?? 0,
        taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0.18,
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return items;
  }

  Future<void> saveCategoryCatalog(
    Map<String, List<String>> catalog, {
    String? userId,
  }) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _ensureUserDocument(uid);

    await _settingsCollection(uid).doc('inventory_catalog').set({
      'catalog': catalog.map((key, value) => MapEntry(key, value)),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, List<String>>> fetchCategoryCatalog({
    String? userId,
  }) async {
    if (Firebase.apps.isEmpty) {
      return <String, List<String>>{};
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return <String, List<String>>{};
    }

    await _ensureUserDocument(uid);

    final snapshot = await _settingsCollection(
      uid,
    ).doc('inventory_catalog').get();
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

    return result;
  }

  Future<void> saveInvoice(Invoice invoice, {String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _ensureUserDocument(uid);

    await _salesCollection(uid).doc(invoice.id).set({
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
    }, SetOptions(merge: true));
  }

  Stream<List<Invoice>> invoicesStream({String? userId}) {
    if (Firebase.apps.isEmpty) {
      return const Stream.empty();
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }

    final query = _salesCollection(uid).orderBy('date', descending: true);

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
    if (Firebase.apps.isEmpty) {
      return const [];
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return const [];
    }

    await _ensureUserDocument(uid);

    final scopedSnapshot = await _salesCollection(
      uid,
    ).orderBy('date', descending: true).get();

    return scopedSnapshot.docs.map((doc) {
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
