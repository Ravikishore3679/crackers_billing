import 'dart:convert';

import 'package:crackers_billing/models/cracker_item.dart';
import 'package:crackers_billing/view_models/sales_view_model.dart';
import 'package:crackers_billing/views/app_shell.dart';
import 'package:crackers_billing/views/expense_screen.dart';
import 'package:crackers_billing/views/inventory_screen.dart';
import 'package:crackers_billing/views/reports_screen.dart';
import 'package:crackers_billing/views/sales_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('expense screen records expenditures and totals them by date', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Title',
    );
    final amountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Amount',
    );

    await tester.enterText(titleField, 'Raw materials');
    await tester.enterText(amountField, '250');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(find.text('Total expenditure'), findsOneWidget);
    expect(find.textContaining('₹250.00'), findsWidgets);
    expect(find.text('Raw materials'), findsAtLeastNWidgets(1));
  });

  testWidgets('expense screen keeps entries after a rebuild', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Title',
    );
    final amountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Amount',
    );

    await tester.enterText(titleField, 'Fuel');
    await tester.enterText(amountField, '300');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Fuel'), findsOneWidget);
  });

  testWidgets(
    'expense screen restores user-scoped fallback data after a relogin',
    (WidgetTester tester) async {
      final payload = jsonEncode([
        {
          'title': 'Fuel',
          'amount': 300.0,
          'date': DateTime.now().millisecondsSinceEpoch,
          'icon': 'receipt',
        },
      ]);

      SharedPreferences.setMockInitialValues({
        'expense_entries_v1_anonymous': payload,
      });

      await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Fuel'), findsOneWidget);
    },
  );

  testWidgets('expense screen allows deleting an entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ExpenseScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Fuel');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '300');

    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(find.text('Fuel'), findsAtLeastNWidgets(1));

    await tester.tap(find.byTooltip('Delete expense').first);
    await tester.pumpAndSettle();

    expect(find.text('Fuel'), findsNothing);
    expect(find.text('Total expenditure'), findsOneWidget);
  });

  testWidgets('reports screen shows generated invoices and print action', (
    WidgetTester tester,
  ) async {
    final viewModel = SalesViewModel();
    await Future<void>.delayed(Duration.zero);
    viewModel.addCatalogItem(
      CrackerItem(
        id: 'report-item',
        name: 'Report Item',
        category: 'Sparklers',
        unitPrice: 10,
        stockAvailable: 5,
      ),
    );
    viewModel.customerEmailController.text = 'customer@example.com';
    viewModel.addToCart(viewModel.catalog.first);
    await viewModel.checkout();

    await tester.pumpWidget(
      ChangeNotifierProvider<SalesViewModel>.value(
        value: viewModel,
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Print invoice'), findsOneWidget);
    expect(find.byTooltip('Email invoice'), findsOneWidget);
    expect(find.textContaining('Invoice:'), findsOneWidget);
    expect(find.text('Total bills generated: 1'), findsOneWidget);
  });

  testWidgets('reports screen shows total expenditure', (
    WidgetTester tester,
  ) async {
    final viewModel = SalesViewModel();

    await tester.pumpWidget(
      ChangeNotifierProvider<SalesViewModel>.value(
        value: viewModel,
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expenditure'), findsOneWidget);
    expect(find.textContaining('₹'), findsWidgets);
  });

  testWidgets('cart accepts a fixed or percentage discount', (
    WidgetTester tester,
  ) async {
    final viewModel = SalesViewModel(catalog: const []);
    await tester.pumpWidget(
      MaterialApp(home: CartScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    final item = CrackerItem(
      id: 'discount-widget-item',
      name: 'Discount Widget Item',
      category: 'Sparklers',
      unitPrice: 100,
      stockAvailable: 2,
    );
    viewModel.addCatalogItem(item);
    viewModel.addToCart(item);
    await tester.pumpAndSettle();

    final valueField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Discount value',
    );
    final percentField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Discount percent',
    );

    await tester.enterText(valueField, '25');
    expect(viewModel.discountAmount, 25);
    expect(viewModel.discountPercent, 0);

    await tester.enterText(percentField, '10');
    expect(viewModel.discountAmount, 10);
    expect(viewModel.discountValue, 0);
  });

  testWidgets('sales screen renders the catalog and app header', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    expect(find.text('Crackers Sales & Invoices'), findsOneWidget);
    expect(find.text('Available Crackers'), findsOneWidget);
  });

  testWidgets('sales screen can search by item code', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'SP-STD-001');
    await tester.pumpAndSettle();

    expect(find.text('Silver Sparklers 15cm'), findsOneWidget);
  });

  testWidgets('sales screen shows item codes beside category labels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sparklers'), findsWidgets);
    expect(find.textContaining('SP-STD-001'), findsOneWidget);
  });

  testWidgets('sales screen opens a dedicated cart page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    await tester.tap(find.byTooltip('Open cart'));
    await tester.pumpAndSettle();

    expect(find.text('Cart'), findsAtLeastNWidgets(1));
    expect(find.text('Generate Invoice'), findsOneWidget);
  });

  testWidgets('sales screen action buttons stay inside a mobile layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cart ('), findsOneWidget);
    expect(find.byTooltip('Open cart'), findsOneWidget);
    expect(find.byType(Chip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('newly added inventory items appear at the top of the list', (
    WidgetTester tester,
  ) async {
    final viewModel = SalesViewModel();

    final firstItem = CrackerItem(
      id: 'first-item',
      name: 'First Item',
      category: 'Sparklers',
      subCategory: 'Standard',
      unitPrice: 10,
      stockAvailable: 5,
      itemCode: 'SP-STD-001',
    );

    final secondItem = CrackerItem(
      id: 'second-item',
      name: 'Second Item',
      category: 'Sparklers',
      subCategory: 'Standard',
      unitPrice: 12,
      stockAvailable: 6,
      itemCode: 'SP-STD-002',
    );

    viewModel.addCatalogItem(firstItem);
    viewModel.addCatalogItem(secondItem);

    expect(viewModel.catalog.first.id, secondItem.id);
    expect(viewModel.catalog[1].id, firstItem.id);
  });

  testWidgets('new item row is added at the top of the purchase order list', (
    WidgetTester tester,
  ) async {
    final viewModel = SalesViewModel();
    await tester.pumpWidget(
      MaterialApp(home: PurchaseOrderEntryScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    final firstNameField = find
        .byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Item name',
        )
        .first;
    await tester.enterText(firstNameField, 'Alpha');
    await tester.pump();

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    final topNameField = find
        .byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Item name',
        )
        .first;
    final topField = tester.widget<TextField>(topNameField);

    expect(topField.controller?.text, isEmpty);
  });

  testWidgets('sales screen shows quantity already added beside the item', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('1 in cart'), findsOneWidget);
  });

  testWidgets('cart updates immediately when quantity is changed', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open cart'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsWidgets);

    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pumpAndSettle();

    expect(find.text('No items in cart yet.'), findsOneWidget);
  });

  testWidgets('inventory add button opens purchase order entry page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Purchase Order'), findsOneWidget);
    expect(find.text('Add item'), findsWidgets);
  });

  testWidgets(
    'purchase order suggests known item names from the first 3 letters',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final itemNameField = find.widgetWithText(TextField, 'Item name');
      await tester.enterText(itemNameField, 'Sil');
      await tester.pumpAndSettle();

      expect(find.text('Silver Sparklers 15cm'), findsWidgets);
    },
  );

  testWidgets(
    'purchase order gives unique codes to different rows in one save',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final viewModel = SalesViewModel();
      await tester.pumpWidget(
        MaterialApp(home: PurchaseOrderEntryScreen(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      final firstNameField = find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Item name',
          )
          .at(0);
      final quantityFields = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Quantity',
      );

      await tester.enterText(firstNameField, 'Silver Spark Deluxe');
      await tester.enterText(quantityFields.at(0), '1');

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();

      final secondNameField = find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Item name',
          )
          .at(1);
      await tester.enterText(secondNameField, 'Silver Spark Premium');
      await tester.enterText(quantityFields.at(1), '2');

      await tester.tap(find.text('Save Purchase Order'));
      await tester.pumpAndSettle();

      final newItems = viewModel.catalog
          .where(
            (item) =>
                item.name.contains('Silver Spark Deluxe') ||
                item.name.contains('Silver Spark Premium'),
          )
          .toList();
      expect(newItems.length, 2);
      expect(newItems.map((item) => item.itemCode).toSet().length, 2);
    },
  );
}
