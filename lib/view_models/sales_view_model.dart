import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/cracker_item.dart';
import '../models/invoice.dart';
import '../models/invoice_line_item.dart';
import '../services/firestore_service.dart';

class SalesViewModel extends ChangeNotifier {
  SalesViewModel({List<CrackerItem>? catalog}) : _catalog = List<CrackerItem>.from(catalog ?? defaultCatalog) {
    discountController.text = '0.00';
    Future.microtask(loadCatalog);
  }

  static const List<CrackerItem> defaultCatalog = [];

  final List<CrackerItem> _catalog;
  final List<InvoiceLineItem> _cart = [];
  final List<Invoice> _invoices = [];
  Invoice? _lastGeneratedInvoice;
  String? _errorMessage;
  double _discountAmount = 0.0;

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
        userId: FirebaseAuth.instance.currentUser?.uid,
      );

      _catalog
        ..clear()
        ..addAll(items);
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Unable to load inventory: $error';
      notifyListeners();
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
        unitPrice: existingItem.unitPrice == 0.0 ? item.unitPrice : existingItem.unitPrice,
        itemCode: existingItem.itemCode ?? item.itemCode,
      );

      _catalog[duplicateIndex] = mergedItem;
      _errorMessage = null;
      notifyListeners();

      FirestoreService.instance.saveInventoryItem(
        mergedItem,
        userId: FirebaseAuth.instance.currentUser?.uid,
      ).catchError((error) {
        _errorMessage = 'Item updated locally but cloud sync failed: $error';
        notifyListeners();
      });
      return;
    }

    if (_catalog.any((existing) => existing.id == item.id)) {
      throw StateError('An item with the same ID already exists.');
    }

    _catalog.add(item);
    _errorMessage = null;
    notifyListeners();

    FirestoreService.instance.saveInventoryItem(
      item,
      userId: FirebaseAuth.instance.currentUser?.uid,
    ).catchError((error) {
      _errorMessage = 'Item saved locally but cloud sync failed: $error';
      notifyListeners();
    });
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
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (error) {
      _errorMessage = 'Invoice saved locally but cloud sync failed: $error';
      notifyListeners();
    }

    return invoice;
  }

  @override
  void dispose() {
    customerNameController.dispose();
    customerPhoneController.dispose();
    discountController.dispose();
    super.dispose();
  }
}
