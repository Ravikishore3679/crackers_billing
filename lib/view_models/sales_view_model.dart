import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/cracker_item.dart';
import '../models/invoice.dart';
import '../models/invoice_line_item.dart';
import '../services/firestore_service.dart';
import '../services/inventory_code_generator.dart';

class HeldCartDraft {
  HeldCartDraft({
    required this.id,
    required this.lineItems,
    required this.customerName,
    required this.customerPhone,
    required this.discountPercent,
    required this.createdAt,
  });

  final String id;
  final List<InvoiceLineItem> lineItems;
  final String customerName;
  final String customerPhone;
  final double discountPercent;
  final DateTime createdAt;

  int get totalQuantity =>
      lineItems.fold(0, (total, item) => total + item.quantity);

  double get grossTotal =>
      lineItems.fold(0.0, (total, item) => total + item.subtotal);
}

class SalesViewModel extends ChangeNotifier {
  StreamSubscription<User?>? _authSubscription;
  String? _activeUserId;
  int _authEpoch = 0;

  String? get _currentUserId =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;

  SalesViewModel({List<CrackerItem>? catalog})
    : _catalog = List<CrackerItem>.from(catalog ?? const <CrackerItem>[]) {
    discountController.text = '0.00';
    if (Firebase.apps.isNotEmpty) {
      _activeUserId = FirebaseAuth.instance.currentUser?.uid;
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        Future.microtask(() async {
          await _handleAuthStateChanged(user);
        });
      });
    }
    Future.microtask(() async {
      await _handleAuthStateChanged(
        Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser,
      );
    });
  }

  final List<CrackerItem> _catalog;
  final List<InvoiceLineItem> _cart = [];
  final List<HeldCartDraft> _heldCarts = [];
  final List<Invoice> _invoices = [];
  Invoice? _lastGeneratedInvoice;
  String? _errorMessage;
  double _discountPercent = 0.0;
  double totalExpenditure = 0.0;
  int _guestCustomerSequence = 1;

  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController discountController = TextEditingController();

  List<CrackerItem> get catalog => List.unmodifiable(_catalog);
  List<InvoiceLineItem> get cart => List.unmodifiable(_cart);
  List<HeldCartDraft> get heldCarts => List.unmodifiable(_heldCarts);
  List<Invoice> get invoiceHistory => List.unmodifiable(_invoices);
  Invoice? get lastGeneratedInvoice => _lastGeneratedInvoice;
  String? get errorMessage => _errorMessage;
  double get discountPercent => _discountPercent;
  double get discountAmount => grossTotal * _discountPercent / 100.0;
  double get totalRevenue =>
      _invoices.fold(0.0, (total, invoice) => total + invoice.netTotal);
  int get totalUnitsSold => _invoices.fold(
    0,
    (total, invoice) =>
        total +
        invoice.lineItems.fold(
          0,
          (lineTotal, item) => lineTotal + item.quantity,
        ),
  );

  double get grossTotal =>
      _cart.fold(0.0, (total, lineItem) => total + lineItem.subtotal);

  double get taxTotal =>
      _cart.fold(0.0, (total, lineItem) => total + lineItem.taxAmount);

  double get netTotal {
    final safeDiscount = discountAmount.clamp(0.0, grossTotal);
    return grossTotal + taxTotal - safeDiscount;
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    final previousUserId = _activeUserId;
    _authEpoch += 1;
    final epoch = _authEpoch;
    final uid = user?.uid;
    _activeUserId = uid;

    if (uid == null || uid.isEmpty) {
      _guestCustomerSequence = 1;
      InventoryCatalogManager.resetToDefaults();
      _clearUserScopedState();
      notifyListeners();
      return;
    }

    if (uid != previousUserId) {
      _guestCustomerSequence = 1;
    }

    try {
      await FirestoreService.instance.ensureUserCollections(userId: uid);
    } catch (error) {
      _errorMessage = 'Unable to initialize user collections: $error';
    }

    await InventoryCatalogManager.loadFromFirestore(userId: uid);

    await loadCatalog(forUserId: uid, authEpoch: epoch);
    await loadInvoiceHistory(forUserId: uid, authEpoch: epoch);
    await loadExpenseSummary(forUserId: uid, authEpoch: epoch);
  }

  void _clearUserScopedState() {
    _catalog.clear();
    _cart.clear();
    _heldCarts.clear();
    _invoices.clear();
    _lastGeneratedInvoice = null;
    _discountPercent = 0.0;
    discountController.text = '0.00';
    totalExpenditure = 0.0;
    _errorMessage = null;
  }

  String _nextGuestCustomerName() {
    final value = 'Customer-${_guestCustomerSequence.toString().padLeft(4, '0')}';
    _guestCustomerSequence += 1;
    return value;
  }

  int _nextGuestSequenceFromInvoices(List<Invoice> invoices) {
    var nextSequence = 1;
    final customerPattern = RegExp(r'^Customer-(\d+)$');

    for (final invoice in invoices) {
      final match = customerPattern.firstMatch(invoice.customerName.trim());
      final sequence = int.tryParse(match?.group(1) ?? '');
      if (sequence != null && sequence >= nextSequence) {
        nextSequence = sequence + 1;
      }
    }

    return nextSequence;
  }

  bool _isStaleRequest({required String userId, int? authEpoch}) {
    final currentAuthUserId = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser?.uid;
    if (authEpoch != null && authEpoch != _authEpoch) {
      return true;
    }
    return userId != _activeUserId || userId != currentAuthUserId;
  }

  Future<void> loadCatalog({String? forUserId, int? authEpoch}) async {
    final uid = forUserId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      _clearUserScopedState();
      notifyListeners();
      return;
    }

    try {
      if (_isStaleRequest(userId: uid, authEpoch: authEpoch)) {
        return;
      }

      final items = await FirestoreService.instance.fetchInventoryItems(
        userId: uid,
      );

      if (_isStaleRequest(userId: uid, authEpoch: authEpoch)) {
        return;
      }

      _catalog
        ..clear()
        ..addAll(items);
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      if (_isStaleRequest(userId: uid, authEpoch: authEpoch)) {
        return;
      }
      _errorMessage = 'Unable to load inventory: $error';
      notifyListeners();
    }
  }

  Future<void> loadInvoiceHistory({String? forUserId, int? authEpoch}) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final uid = forUserId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      _invoices.clear();
      _lastGeneratedInvoice = null;
      totalExpenditure = 0.0;
      notifyListeners();
      return;
    }

    try {
      final reportSummary = await FirestoreService.instance.fetchReportSummary(
        userId: uid,
      );
      final invoices = await FirestoreService.instance.fetchInvoices(
        userId: uid,
      );

      if (_isStaleRequest(userId: uid, authEpoch: authEpoch)) {
        return;
      }

      _invoices
        ..clear()
        ..addAll(invoices);

      final nextGuestSequence = _nextGuestSequenceFromInvoices(invoices);
      if (nextGuestSequence > _guestCustomerSequence) {
        _guestCustomerSequence = nextGuestSequence;
      }

      if (reportSummary.isNotEmpty) {
        totalExpenditure =
            (reportSummary['totalExpenditure'] as num?)?.toDouble() ??
            totalExpenditure;
      }
      notifyListeners();
    } catch (error) {
      if (_isStaleRequest(userId: uid, authEpoch: authEpoch)) {
        return;
      }
      _errorMessage = 'Unable to load invoice history: $error';
      notifyListeners();
    }
  }

  Future<void> loadExpenseSummary({String? forUserId, int? authEpoch}) async {
    if (Firebase.apps.isEmpty) {
      totalExpenditure = 0.0;
      notifyListeners();
      return;
    }

    final uid = forUserId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      totalExpenditure = 0.0;
      notifyListeners();
      return;
    }

    try {
      final entries = await FirestoreService.instance.fetchExpenseEntries(
        userId: uid,
      );

      if (_isStaleRequest(userId: uid, authEpoch: authEpoch)) {
        return;
      }

      totalExpenditure = entries.fold<double>(
        0.0,
        (sum, entry) => sum + (entry['amount'] as num? ?? 0).toDouble(),
      );
    } catch (_) {
      totalExpenditure = 0.0;
    }

    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void setTotalExpenditure(double amount) {
    totalExpenditure = amount;
    notifyListeners();
  }

  InvoiceLineItem? _findCartItem(String itemId) {
    for (final lineItem in _cart) {
      if (lineItem.crackerItem.id == itemId) {
        return lineItem;
      }
    }
    return null;
  }

  CrackerItem _itemById(String itemId) {
    return _catalog.firstWhere(
      (item) => item.id == itemId,
      orElse: () =>
          throw StateError('Requested cracker item not found: $itemId'),
    );
  }

  bool _canAddQuantity(CrackerItem item, int quantity) {
    final existingQuantity = _findCartItem(item.id)?.quantity ?? 0;
    return existingQuantity + quantity <= item.stockAvailable;
  }

  void addCatalogItem(CrackerItem item) {
    if (item.name.trim().isEmpty) {
      throw StateError('Item name cannot be empty.');
    }
    if (item.category.trim().isEmpty) {
      throw StateError('Category cannot be empty.');
    }

    final duplicateIndex = _catalog.indexWhere(
      (existing) =>
          existing.category == item.category &&
          existing.subCategory == item.subCategory &&
          existing.name.trim().toLowerCase() == item.name.trim().toLowerCase(),
    );

    if (duplicateIndex >= 0) {
      final existingItem = _catalog[duplicateIndex];
      final mergedItem = existingItem.copyWith(
        stockAvailable: existingItem.stockAvailable + item.stockAvailable,
        unitPrice: item.unitPrice > 0 ? item.unitPrice : existingItem.unitPrice,
        itemCode: existingItem.itemCode ?? item.itemCode,
      );

      _catalog.removeAt(duplicateIndex);
      _catalog.insert(0, mergedItem);
      _errorMessage = null;
      notifyListeners();

      if (Firebase.apps.isNotEmpty) {
        FirestoreService.instance
            .saveInventoryItem(mergedItem, userId: _currentUserId)
            .catchError((error) {
              _errorMessage =
                  'Item updated locally but cloud sync failed: $error';
              notifyListeners();
            });
      }
      return;
    }

    if (_catalog.any((existing) => existing.id == item.id)) {
      throw StateError('An item with the same ID already exists.');
    }

    _catalog.insert(0, item);
    _errorMessage = null;
    notifyListeners();

    if (Firebase.apps.isNotEmpty) {
      FirestoreService.instance
          .saveInventoryItem(item, userId: _currentUserId)
          .catchError((error) {
            _errorMessage = 'Item saved locally but cloud sync failed: $error';
            notifyListeners();
          });
    }
  }

  void addToCart(CrackerItem item) {
    if (item.stockAvailable <= 0) {
      _errorMessage = 'Sorry, ${item.name} is currently out of stock.';
      notifyListeners();
      throw StateError(_errorMessage!);
    }

    if (!_canAddQuantity(item, 1)) {
      _errorMessage =
          'Only ${item.stockAvailable} units of ${item.name} are available in stock.';
      notifyListeners();
      throw StateError(_errorMessage!);
    }

    final existingLine = _findCartItem(item.id);
    if (existingLine == null) {
      _cart.add(InvoiceLineItem(crackerItem: item, quantity: 1));
    } else {
      existingLine.quantity += 1;
      existingLine.recalculateTotals();
    }

    _errorMessage = null;
    notifyListeners();
  }

  void removeFromCart(CrackerItem item) {
    _cart.removeWhere((lineItem) => lineItem.crackerItem.id == item.id);
    notifyListeners();
  }

  void holdCurrentCart() {
    if (_cart.isEmpty) {
      return;
    }

    final customerName = customerNameController.text.trim().isEmpty
        ? _nextGuestCustomerName()
        : customerNameController.text.trim();

    final draft = HeldCartDraft(
      id: 'HOLD-${DateTime.now().millisecondsSinceEpoch}',
      lineItems: _cart.map((lineItem) => lineItem.copyWith()).toList(),
      customerName: customerName,
      customerPhone: customerPhoneController.text.trim(),
      discountPercent: _discountPercent,
      createdAt: DateTime.now(),
    );

    _heldCarts.insert(0, draft);
    _cart.clear();
    _discountPercent = 0.0;
    discountController.text = '0.00';
    customerNameController.clear();
    customerPhoneController.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void resumeHeldCart(String draftId) {
    final index = _heldCarts.indexWhere((draft) => draft.id == draftId);
    if (index == -1) {
      return;
    }

    if (_cart.isNotEmpty) {
      holdCurrentCart();
    }

    final draft = _heldCarts.removeAt(index);
    _cart
      ..clear()
      ..addAll(draft.lineItems.map((lineItem) => lineItem.copyWith()));
    customerNameController.text = draft.customerName;
    customerPhoneController.text = draft.customerPhone;
    _discountPercent = draft.discountPercent;
    discountController.text = draft.discountPercent.toStringAsFixed(2);
    _errorMessage = null;
    notifyListeners();
  }

  void discardHeldCart(String draftId) {
    _heldCarts.removeWhere((draft) => draft.id == draftId);
    notifyListeners();
  }

  Future<void> removeInventoryItem(String itemId) async {
    final index = _catalog.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }

    _catalog.removeAt(index);
    _errorMessage = null;
    notifyListeners();

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirestoreService.instance.deleteInventoryItem(
          itemId,
          userId: _currentUserId,
        );
      } catch (error) {
        _errorMessage = 'Item removed locally but cloud sync failed: $error';
        notifyListeners();
      }
    }
  }

  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(_itemById(itemId));
      return;
    }

    final item = _itemById(itemId);
    if (quantity > item.stockAvailable) {
      _errorMessage =
          'Only ${item.stockAvailable} units of ${item.name} are available in stock.';
      notifyListeners();
      throw StateError(_errorMessage!);
    }

    final existingLine = _findCartItem(itemId);
    if (existingLine == null) {
      _cart.add(InvoiceLineItem(crackerItem: item, quantity: quantity));
    } else {
      existingLine.quantity = quantity;
      existingLine.recalculateTotals();
    }

    _errorMessage = null;
    notifyListeners();
  }

  void applyDiscount(double amount) {
    final safePercent = amount.clamp(0.0, 100.0);
    _discountPercent = safePercent;
    notifyListeners();
  }

  Future<Invoice> checkout() async {
    if (_cart.isEmpty) {
      _errorMessage =
          'Your cart is empty. Add items before generating the invoice.';
      notifyListeners();
      throw StateError(_errorMessage!);
    }

    final safeDiscount = discountAmount.clamp(0.0, grossTotal);
    final customerName = customerNameController.text.trim().isEmpty
      ? _nextGuestCustomerName()
        : customerNameController.text.trim();
    final invoice = Invoice(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      customerName: customerName,
      customerPhone: customerPhoneController.text.trim(),
      date: DateTime.now(),
      lineItems: _cart.map((lineItem) => lineItem.copyWith()).toList(),
      discountAmount: safeDiscount,
    );

    final updatedItems = <CrackerItem>[];
    for (final entry in _cart) {
      final index = _catalog.indexWhere(
        (item) => item.id == entry.crackerItem.id,
      );
      if (index != -1) {
        final currentItem = _catalog[index];
        final nextStock = currentItem.stockAvailable - entry.quantity;
        final updatedItem = currentItem.copyWith(stockAvailable: nextStock);
        _catalog[index] = updatedItem;
        updatedItems.add(updatedItem);
      }
    }

    _lastGeneratedInvoice = invoice;
    _invoices.insert(0, invoice);
    _cart.clear();
    _discountPercent = 0.0;
    discountController.text = '0.00';
    customerNameController.clear();
    customerPhoneController.clear();
    _errorMessage = null;
    notifyListeners();

    try {
      await FirestoreService.instance.saveInvoice(
        invoice,
        userId: _currentUserId,
      );

      for (final item in updatedItems) {
        await FirestoreService.instance.saveInventoryItem(
          item,
          userId: _currentUserId,
        );
      }

      await FirestoreService.instance.saveReportSummary(
        totalRevenue: _invoices.fold(
          0.0,
          (sum, invoice) => sum + invoice.netTotal,
        ),
        totalUnitsSold: _invoices.fold(
          0,
          (sum, invoice) =>
              sum +
              invoice.lineItems.fold(
                0,
                (lineSum, item) => lineSum + item.quantity,
              ),
        ),
        totalExpenditure: totalExpenditure,
        userId: _currentUserId,
      );
    } catch (error) {
      _errorMessage = 'Invoice saved locally but cloud sync failed: $error';
      notifyListeners();
    }

    return invoice;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    customerNameController.dispose();
    customerPhoneController.dispose();
    discountController.dispose();
    super.dispose();
  }
}
