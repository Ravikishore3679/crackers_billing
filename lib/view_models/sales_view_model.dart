import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/cracker_item.dart';
import '../models/invoice.dart';
import '../models/invoice_line_item.dart';
import '../services/firestore_service.dart';

class SalesViewModel extends ChangeNotifier {
  StreamSubscription<User?>? _authSubscription;

  String? get _currentUserId => Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;

  SalesViewModel({List<CrackerItem>? catalog}) : _catalog = List<CrackerItem>.from(catalog ?? defaultCatalog) {
    discountController.text = '0.00';
    if (Firebase.apps.isNotEmpty) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        Future.microtask(() async {
          await loadCatalog();
          await loadInvoiceHistory();
          await loadExpenseSummary();
        });
      });
    }
    Future.microtask(loadCatalog);
    Future.microtask(loadInvoiceHistory);
    Future.microtask(loadExpenseSummary);
  }

  static List<CrackerItem> get defaultCatalog => [
    CrackerItem(
      id: 'seed-sparklers-standard-15cm',
      name: 'Silver Sparklers 15cm',
      category: 'Sparklers',
      subCategory: 'Standard',
      unitPrice: 18.0,
      stockAvailable: 50,
      itemCode: 'SP-STD-001',
      categoryCode: 'SP',
      subCategoryCode: 'STD',
      variantCode: '15',
    ),
    CrackerItem(
      id: 'seed-sparklers-premium-15cm',
      name: 'Premium Sparklers 15cm',
      category: 'Sparklers',
      subCategory: 'Premium',
      unitPrice: 25.0,
      stockAvailable: 30,
      itemCode: 'SP-PRE-001',
      categoryCode: 'SP',
      subCategoryCode: 'PRE',
      variantCode: '15',
    ),
    CrackerItem(
      id: 'seed-rockets-standard-30cm',
      name: 'Rocket 30cm',
      category: 'Rockets',
      subCategory: 'Standard',
      unitPrice: 35.0,
      stockAvailable: 20,
      itemCode: 'RK-STD-001',
      categoryCode: 'RK',
      subCategoryCode: 'STD',
      variantCode: '30',
    ),
    CrackerItem(
      id: 'seed-flower-pots-special',
      name: 'Flower Pot Special',
      category: 'Flower Pots',
      subCategory: 'Special',
      unitPrice: 40.0,
      stockAvailable: 15,
      itemCode: 'FP-SPC-001',
      categoryCode: 'FP',
      subCategoryCode: 'SPC',
      variantCode: 'SPC',
    ),
    CrackerItem(
      id: 'seed-ground-crackers-mini',
      name: 'Ground Crackers Mini',
      category: 'Ground Crackers',
      subCategory: 'Mini',
      unitPrice: 55.0,
      stockAvailable: 12,
      itemCode: 'GC-MIN-001',
      categoryCode: 'GC',
      subCategoryCode: 'MIN',
      variantCode: 'MIN',
    ),
    CrackerItem(
      id: 'seed-specials-electric',
      name: 'Electric Special',
      category: 'Specials',
      subCategory: 'Electric',
      unitPrice: 65.0,
      stockAvailable: 10,
      itemCode: 'SPC-ELE-001',
      categoryCode: 'SPC',
      subCategoryCode: 'ELE',
      variantCode: 'ELE',
    ),
  ];

  final List<CrackerItem> _catalog;
  final List<InvoiceLineItem> _cart = [];
  final List<Invoice> _invoices = [];
  Invoice? _lastGeneratedInvoice;
  String? _errorMessage;
  double _discountAmount = 0.0;
  double totalExpenditure = 0.0;

  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController discountController = TextEditingController();

  List<CrackerItem> get catalog => List.unmodifiable(_catalog);
  List<InvoiceLineItem> get cart => List.unmodifiable(_cart);
  List<Invoice> get invoiceHistory => List.unmodifiable(_invoices);
  Invoice? get lastGeneratedInvoice => _lastGeneratedInvoice;
  String? get errorMessage => _errorMessage;
  double get discountAmount => _discountAmount;
  double get totalRevenue => _invoices.fold(
        0.0,
        (total, invoice) => total + invoice.netTotal,
      );
  int get totalUnitsSold => _invoices.fold(
        0,
        (total, invoice) => total +
            invoice.lineItems.fold(
              0,
              (lineTotal, item) => lineTotal + item.quantity,
            ),
      );

  double get grossTotal => _cart.fold(
        0.0,
        (total, lineItem) => total + lineItem.subtotal,
      );

  double get taxTotal => _cart.fold(
        0.0,
        (total, lineItem) => total + lineItem.taxAmount,
      );

  double get netTotal {
    final safeDiscount = _discountAmount.clamp(0.0, grossTotal);
    return grossTotal + taxTotal - safeDiscount;
  }

  Future<void> loadCatalog() async {
    try {
      final items = await FirestoreService.instance.fetchInventoryItems(
        userId: _currentUserId,
      );

      if (items.isEmpty && _currentUserId != null) {
        await seedDefaultCatalog();
        final seededItems = await FirestoreService.instance.fetchInventoryItems(
          userId: _currentUserId,
        );
        _catalog
          ..clear()
          ..addAll(seededItems);
      } else {
        _catalog
          ..clear()
          ..addAll(items);
      }
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Unable to load inventory: $error';
      notifyListeners();
    }
  }

  Future<void> loadInvoiceHistory() async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    try {
      final reportSummary = await FirestoreService.instance.fetchReportSummary(
        userId: _currentUserId,
      );
      final invoices = await FirestoreService.instance.fetchInvoices(
        userId: _currentUserId,
      );
      _invoices
        ..clear()
        ..addAll(invoices);

      if (reportSummary.isNotEmpty) {
        totalExpenditure = (reportSummary['totalExpenditure'] as num?)?.toDouble() ?? totalExpenditure;
      }
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Unable to load invoice history: $error';
      notifyListeners();
    }
  }

  Future<void> loadExpenseSummary() async {
    if (Firebase.apps.isEmpty) {
      totalExpenditure = 0.0;
      notifyListeners();
      return;
    }

    try {
      final entries = await FirestoreService.instance.fetchExpenseEntries(
        userId: _currentUserId,
      );
      totalExpenditure = entries.fold<double>(
        0.0,
        (sum, entry) => sum + (entry['amount'] as num? ?? 0).toDouble(),
      );
    } catch (_) {
      totalExpenditure = 0.0;
    }

    notifyListeners();
  }

  Future<void> seedDefaultCatalog() async {
    if (_currentUserId == null || Firebase.apps.isEmpty) {
      return;
    }

    for (final item in defaultCatalog) {
      final existing = _catalog.any((candidate) => candidate.id == item.id);
      if (!existing) {
        await FirestoreService.instance.saveInventoryItem(
          item,
          userId: _currentUserId,
        );
      }
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
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
      orElse: () => throw StateError('Requested cracker item not found: $itemId'),
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
        FirestoreService.instance.saveInventoryItem(
          mergedItem,
          userId: _currentUserId,
        ).catchError((error) {
          _errorMessage = 'Item updated locally but cloud sync failed: $error';
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
      FirestoreService.instance.saveInventoryItem(
        item,
        userId: _currentUserId,
      ).catchError((error) {
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
      _errorMessage = 'Only ${item.stockAvailable} units of ${item.name} are available in stock.';
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

  void removeInventoryItem(String itemId) {
    final index = _catalog.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }

    _catalog.removeAt(index);
    _errorMessage = null;
    notifyListeners();

    if (Firebase.apps.isNotEmpty) {
      FirestoreService.instance.deleteInventoryItem(
        itemId,
        userId: _currentUserId,
      ).catchError((error) {
        _errorMessage = 'Item removed locally but cloud sync failed: $error';
        notifyListeners();
      });
    }
  }

  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(_itemById(itemId));
      return;
    }

    final item = _itemById(itemId);
    if (quantity > item.stockAvailable) {
      _errorMessage = 'Only ${item.stockAvailable} units of ${item.name} are available in stock.';
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
    final safeAmount = amount.clamp(0.0, grossTotal);
    _discountAmount = safeAmount;
    discountController.text = safeAmount.toStringAsFixed(2);
    notifyListeners();
  }

  Future<Invoice> checkout() async {
    if (_cart.isEmpty) {
      _errorMessage = 'Your cart is empty. Add items before generating the invoice.';
      notifyListeners();
      throw StateError(_errorMessage!);
    }

    final safeDiscount = _discountAmount.clamp(0.0, grossTotal);
    final invoice = Invoice(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      customerName: customerNameController.text.trim(),
      customerPhone: customerPhoneController.text.trim(),
      date: DateTime.now(),
      lineItems: _cart.map((lineItem) => lineItem.copyWith()).toList(),
      discountAmount: safeDiscount,
    );

    for (final entry in _cart) {
      final index = _catalog.indexWhere((item) => item.id == entry.crackerItem.id);
      if (index != -1) {
        final currentItem = _catalog[index];
        final nextStock = currentItem.stockAvailable - entry.quantity;
        _catalog[index] = currentItem.copyWith(stockAvailable: nextStock);
      }
    }

    _lastGeneratedInvoice = invoice;
    _invoices.insert(0, invoice);
    _cart.clear();
    _discountAmount = 0.0;
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
      await FirestoreService.instance.saveReportSummary(
        totalRevenue: _invoices.fold(
          0.0,
          (sum, invoice) => sum + invoice.netTotal,
        ),
        totalUnitsSold: _invoices.fold(
          0,
          (sum, invoice) => sum +
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
