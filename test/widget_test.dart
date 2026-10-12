import 'package:crackers_billing/view_models/sales_view_model.dart';
import 'package:crackers_billing/views/app_shell.dart';
import 'package:crackers_billing/views/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('sales screen can search by item code', (WidgetTester tester) async {
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

  testWidgets('sales screen opens a dedicated cart page', (WidgetTester tester) async {
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

  testWidgets('sales screen shows quantity already added beside the item', (WidgetTester tester) async {
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

  testWidgets('cart updates immediately when quantity is changed', (WidgetTester tester) async {
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

  testWidgets('inventory add button opens purchase order entry page', (WidgetTester tester) async {
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

  testWidgets('purchase order suggests known item names from the first 3 letters', (WidgetTester tester) async {
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
  });

  testWidgets('purchase order gives unique codes to different rows in one save', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final viewModel = SalesViewModel();
    await tester.pumpWidget(MaterialApp(home: PurchaseOrderEntryScreen(viewModel: viewModel)));
    await tester.pumpAndSettle();

    final firstNameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Item name',
    ).at(0);
    final quantityFields = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Quantity',
    );

    await tester.enterText(firstNameField, 'Silver Spark Deluxe');
    await tester.enterText(quantityFields.at(0), '1');

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    final secondNameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Item name',
    ).at(1);
    await tester.enterText(secondNameField, 'Silver Spark Premium');
    await tester.enterText(quantityFields.at(1), '2');

    await tester.tap(find.text('Save Purchase Order'));
    await tester.pumpAndSettle();

    final newItems = viewModel.catalog.where(
      (item) => item.name.contains('Silver Spark Deluxe') || item.name.contains('Silver Spark Premium'),
    ).toList();
    expect(newItems.length, 2);
    expect(newItems.map((item) => item.itemCode).toSet().length, 2);
  });
}
