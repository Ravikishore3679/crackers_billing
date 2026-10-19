import 'dart:convert';

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
  static final Map<String, Future<void>> _workspacePreparations = {};
  static String? _activeUserId;
  static String? _activeWorkspaceId;
  static String? _activeRole;

  bool get isWorkspaceOwner => Firebase.apps.isEmpty || _activeRole == 'owner';
  bool get canManageInventory => isWorkspaceOwner;
  bool get canManageStaff => isWorkspaceOwner;

  static void clearWorkspaceSession() {
    final userId = _activeUserId;
    if (userId != null) {
      _workspacePreparations.remove(userId);
    }
    _activeUserId = null;
    _activeWorkspaceId = null;
    _activeRole = null;
  }

  static String _inviteDocumentId(String email) => base64Url
      .encode(utf8.encode(email.trim().toLowerCase()))
      .replaceAll('=', '');

  Future<void> prepareWorkspace(User user) {
    final cached = _workspacePreparations[user.uid];
    if (cached != null) {
      return cached;
    }

    final future = _prepareWorkspace(user).catchError((error) {
      _workspacePreparations.remove(user.uid);
      throw error;
    });
    _workspacePreparations[user.uid] = future;
    return future;
  }

  Future<void> _prepareWorkspace(User user) async {
    final userDocument = _userDocument(user.uid);
    final userSnapshot = await _workspaceStep(
      'Reading the signed-in user profile',
      userDocument.get,
    );
    final existingWorkspace =
        userSnapshot.data()?['workspaceOwnerUid'] as String?;

    if (existingWorkspace != null && existingWorkspace.isNotEmpty) {
      final membership = await _workspaceStep(
        'Reading the workspace membership',
        _userDocument(existingWorkspace).collection('members').doc(user.uid).get,
      );
      if (membership.exists) {
        _activeUserId = user.uid;
        _activeWorkspaceId = existingWorkspace;
        _activeRole = membership.data()?['role'] as String? ?? 'billing';
        return;
      }
    }

    final email = user.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      final inviteReference = _db
          .collection('accessInvites')
          .doc(_inviteDocumentId(email));
      DocumentSnapshot<Map<String, dynamic>>? inviteSnapshot;
      try {
        inviteSnapshot = await inviteReference.get();
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') {
          rethrow;
        }
      }
      final invite = inviteSnapshot?.data();
      final ownerUid = invite?['ownerUid'] as String?;
      if (inviteSnapshot?.exists == true &&
          ownerUid != null &&
          ownerUid != user.uid) {
        final memberReference = _userDocument(
          ownerUid,
        ).collection('members').doc(user.uid);
        await _workspaceStep(
          'Accepting the staff invitation',
          () => _db.runTransaction((transaction) async {
            transaction.set(memberReference, {
              'uid': user.uid,
              'email': email,
              'role': 'billing',
              'inviteId': _inviteDocumentId(email),
              'joinedAt': FieldValue.serverTimestamp(),
            });
            transaction.set(userDocument, {
              'uid': user.uid,
              'workspaceOwnerUid': ownerUid,
              'workspaceInviteId': _inviteDocumentId(email),
              'role': 'billing',
            }, SetOptions(merge: true));
            transaction.delete(inviteReference);
          }),
        );
        _activeUserId = user.uid;
        _activeWorkspaceId = ownerUid;
        _activeRole = 'billing';
        return;
      }
    }

    await _workspaceStep(
      'Creating the owner workspace profile',
      () => userDocument.set({
        'uid': user.uid,
        'role': 'owner',
        'workspaceOwnerUid': FieldValue.delete(),
        'workspaceInviteId': FieldValue.delete(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
    _activeUserId = user.uid;
    _activeWorkspaceId = user.uid;
    _activeRole = 'owner';
  }

  Future<T> _workspaceStep<T>(
    String label,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on FirebaseException catch (error) {
      throw StateError('$label failed (${error.code}): ${error.message}');
    }
  }

  Future<void> inviteBillingStaff(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final ownerUid = resolveUserId();
    if (!isWorkspaceOwner || ownerUid == null || normalizedEmail.isEmpty) {
      throw StateError('Only the workspace owner can invite staff.');
    }

    await _db
        .collection('accessInvites')
        .doc(_inviteDocumentId(normalizedEmail))
        .set({
          'ownerUid': ownerUid,
          'email': normalizedEmail,
          'role': 'billing',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<bool> hasPendingBillingInvite(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || Firebase.apps.isEmpty) {
      return false;
    }

    try {
      final snapshot = await _db
          .collection('accessInvites')
          .doc(_inviteDocumentId(normalizedEmail))
          .get();
      return snapshot.exists && snapshot.data()?['email'] == normalizedEmail;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return false;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchWorkspaceMembers() async {
    final ownerUid = resolveUserId();
    if (!isWorkspaceOwner || ownerUid == null) {
      return const [];
    }

    final snapshot = await _userDocument(ownerUid).collection('members').get();
    return snapshot.docs.map((document) => document.data()).toList();
  }

  Future<void> revokeWorkspaceMember(String memberUid) async {
    final ownerUid = resolveUserId();
    if (!isWorkspaceOwner || ownerUid == null) {
      throw StateError('Only the workspace owner can revoke staff access.');
    }

    await _userDocument(ownerUid).collection('members').doc(memberUid).delete();
  }

  static String? resolveUserId({String? userId}) {
    final explicitUserId = userId?.trim();
    if (explicitUserId != null && explicitUserId.isNotEmpty) {
      if (explicitUserId == _activeUserId && _activeWorkspaceId != null) {
        return _activeWorkspaceId;
      }
      return explicitUserId;
    }

    if (Firebase.apps.isEmpty) {
      return null;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim();
    if (currentUserId != null && currentUserId.isNotEmpty) {
      if (currentUserId == _activeUserId && _activeWorkspaceId != null) {
        return _activeWorkspaceId;
      }
      return currentUserId;
    }

    return null;
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Emits when another device changes a workspace collection; skips the initial snapshot and local writes.
  Stream<void> watchWorkspace(String collection, {String? userId}) {
    if (Firebase.apps.isEmpty) {
      return const Stream.empty();
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }

    return _userDocument(uid)
        .collection(collection)
        .snapshots()
        .handleError((_) {})
        .skip(1)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((_) {});
  }

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
    if (_activeRole != 'owner' && uid == _activeWorkspaceId) {
      return;
    }

    final userDocument = _userDocument(uid);
    await userDocument.set({
      'uid': uid,
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!refreshCollections &&
        _initializedCollectionsForSession.contains(uid)) {
      return;
    }

    final batch = _db.batch();
    final metadata = {'recordType': 'collection_metadata', 'userId': uid};
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
    batch.set(userDocument, {
      'subcollectionsInitialized': true,
    }, SetOptions(merge: true));

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

    if (!isWorkspaceOwner) {
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

  Future<void> saveInvoicePayment(Invoice invoice, {String? userId}) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = resolveUserId(userId: userId);
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _salesCollection(uid).doc(invoice.id).set({
      'cashPaid': invoice.cashPaid,
      'upiPaid': invoice.upiPaid,
      'cardPaid': invoice.cardPaid,
      'paidAt': invoice.paidAt == null
          ? null
          : Timestamp.fromDate(invoice.paidAt!),
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
          cashPaid: (data['cashPaid'] as num?)?.toDouble() ?? 0.0,
          upiPaid: (data['upiPaid'] as num?)?.toDouble() ?? 0.0,
          cardPaid: (data['cardPaid'] as num?)?.toDouble() ?? 0.0,
          paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
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
        cashPaid: (data['cashPaid'] as num?)?.toDouble() ?? 0.0,
        upiPaid: (data['upiPaid'] as num?)?.toDouble() ?? 0.0,
        cardPaid: (data['cardPaid'] as num?)?.toDouble() ?? 0.0,
        paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      );
      invoice.recalculateTotals();
      return invoice;
    }).toList();
  }
}
