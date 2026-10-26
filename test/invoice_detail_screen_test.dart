import 'package:crackers_billing/models/invoice.dart';
import 'package:crackers_billing/models/cracker_item.dart';
import 'package:crackers_billing/models/invoice_line_item.dart';
import 'package:crackers_billing/view_models/sales_view_model.dart';
import 'package:crackers_billing/views/invoice_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('invoice detail screen shows details and actions', (
    WidgetTester tester,
  ) async {
    final viewModel = SalesViewModel(catalog: const []);
    addTearDown(viewModel.dispose);
    final invoice = Invoice(
      id: 'INV-DETAIL-1',
      customerName: 'Ravi',
      customerPhone: '9876543210',
      customerEmail: 'ravi@example.com',
      notes: 'Deliver after 5 PM',
      date: DateTime(2026, 10, 22),
      lineItems: [
        InvoiceLineItem(
          crackerItem: CrackerItem(
            id: 'detail-item',
            name: 'Detail Item',
            category: 'Sparklers',
            unitPrice: 100,
            stockAvailable: 1,
          ),
        ),
      ],
      createdBy: 'Billing Staff',
      paymentMarkedBy: 'Owner',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceDetailScreen(invoice: invoice, viewModel: viewModel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invoice INV-DETAIL-1'), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('ravi@example.com'), findsOneWidget);
    expect(find.text('Note: Deliver after 5 PM'), findsOneWidget);
    expect(find.text('Billed by Billing Staff'), findsOneWidget);
    expect(find.text('Payment marked by Owner'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Share image'), findsOneWidget);
    expect(find.text('Step 2: Record payment'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Discount value',
      ),
      '25',
    );
    await tester.pumpAndSettle();
    expect(find.text('Amount to collect: ₹70.00'), findsOneWidget);
  });
}
