import 'package:crackers_billing/models/cracker_item.dart';
import 'package:crackers_billing/models/invoice.dart';
import 'package:crackers_billing/models/invoice_line_item.dart';
import 'package:crackers_billing/services/inventory_code_generator.dart';
import 'package:crackers_billing/view_models/sales_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SalesViewModel', () {
    test(
      'can start with an explicit empty catalog for isolated logic tests',
      () {
        final viewModel = SalesViewModel(catalog: const []);

        expect(viewModel.catalog, isEmpty);
      },
    );

    test(
      'adds items to cart up to stock availability and rejects excess stock',
      () {
        final viewModel = SalesViewModel(
          catalog: [
            CrackerItem(
              id: 'item-1',
              name: 'Sparkler Burst',
              category: 'Sparklers',
              unitPrice: 25.0,
              stockAvailable: 2,
            ),
          ],
        );

        viewModel.addToCart(viewModel.catalog.first);
        viewModel.addToCart(viewModel.catalog.first);

        expect(viewModel.cart.length, 1);
        expect(viewModel.cart.first.quantity, 2);
        expect(
          () => viewModel.addToCart(viewModel.catalog.first),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('checkout creates invoice and clears cart', () async {
      final viewModel = SalesViewModel(
        catalog: [
          CrackerItem(
            id: 'item-2',
            name: 'Rocket 50',
            category: 'Rockets',
            unitPrice: 50.0,
            stockAvailable: 5,
          ),
        ],
      );

      viewModel.customerNameController.text = 'Ravi';
      viewModel.customerPhoneController.text = '9876543210';
      viewModel.notesController.text = 'Deliver after 5 PM';
      viewModel.addToCart(viewModel.catalog.first);
      final invoice = await viewModel.checkout();

      expect(invoice.customerName, 'Ravi');
      expect(invoice.notes, 'Deliver after 5 PM');
      expect(invoice.invoiceSummaryText, contains('Notes: Deliver after 5 PM'));
      expect(invoice.lineItems.length, 1);
      expect(viewModel.cart, isEmpty);
      expect(invoice.netTotal, greaterThanOrEqualTo(0));
    });

    test('gross price includes GST without adding GST to the bill', () async {
      final item = CrackerItem(
        id: 'inclusive-tax-item',
        name: 'Inclusive Tax Item',
        category: 'Sparklers',
        unitPrice: 100,
        stockAvailable: 1,
        taxRate: 0.18,
      );
      final viewModel = SalesViewModel(catalog: [item]);
      viewModel.addToCart(item);

      expect(viewModel.grossTotal, 100);
      expect(viewModel.taxTotal, closeTo(15.25, 0.01));
      expect(viewModel.netTotal, 100);
      final invoice = await viewModel.checkout();
      expect(invoice.netTotal, 100);
      expect(invoice.invoiceSummaryText, isNot(contains('GST:')));
    });

    test('rounds bill total down to the previous ten', () {
      final item = CrackerItem(
        id: 'round-down-item',
        name: 'Round Down Item',
        category: 'Sparklers',
        unitPrice: 246,
        stockAvailable: 1,
      );
      final viewModel = SalesViewModel(catalog: [item]);
      viewModel.addToCart(item);

      expect(viewModel.netTotal, 246);
      expect(viewModel.roundedNetTotal, 240);
      expect(viewModel.roundOffAmount, -6);
    });

    test('cart notes survive hold and resume', () {
      final viewModel = SalesViewModel(
        catalog: [
          CrackerItem(
            id: 'notes-item',
            name: 'Notes Item',
            category: 'Sparklers',
            unitPrice: 10,
            stockAvailable: 1,
          ),
        ],
      );
      viewModel.addToCart(viewModel.catalog.first);
      viewModel.notesController.text = 'Deliver after 5 PM';

      viewModel.holdCurrentCart();
      viewModel.resumeHeldCart(viewModel.heldCarts.first.id);

      expect(viewModel.notesController.text, 'Deliver after 5 PM');
    });

    test('fixed and percentage discounts are mutually exclusive', () {
      final viewModel = SalesViewModel(
        catalog: [
          CrackerItem(
            id: 'discount-item',
            name: 'Discount Item',
            category: 'Sparklers',
            unitPrice: 100,
            stockAvailable: 1,
          ),
        ],
      );
      viewModel.addToCart(viewModel.catalog.first);

      viewModel.applyDiscountValue(25);
      expect(viewModel.discountAmount, 25);
      expect(viewModel.discountPercent, 0);

      viewModel.applyDiscountPercent(10);
      expect(viewModel.discountAmount, 10);
      expect(viewModel.discountValue, 0);
    });

    test('invoice copy preserves who marked the payment', () {
      final invoice = Invoice(
        id: 'payment-marker',
        customerName: 'Ravi',
        customerPhone: '',
        date: DateTime(2026),
        lineItems: [
          InvoiceLineItem(
            crackerItem: CrackerItem(
              id: 'marker-item',
              name: 'Marker Item',
              category: 'Sparklers',
              unitPrice: 10,
              stockAvailable: 1,
            ),
            quantity: 1,
          ),
        ],
        paymentMarkedBy: 'staff@example.com',
      );

      expect(
        invoice.copyWith(customerName: 'Updated').paymentMarkedBy,
        'staff@example.com',
      );
      expect(
        invoice.invoiceSummaryText,
        contains('Payment marked by: staff@example.com'),
      );
    });

    test('merges duplicate item entries by category, subcategory and name', () {
      final viewModel = SalesViewModel(catalog: const []);

      final first = CrackerItem(
        id: 'dup-1',
        name: 'Silver 15cm',
        category: 'Sparklers',
        subCategory: 'Standard company',
        unitPrice: 30.0,
        stockAvailable: 4,
      );

      final second = CrackerItem(
        id: 'dup-2',
        name: 'silver 15cm',
        category: 'Sparklers',
        subCategory: 'Standard company',
        unitPrice: 32.0,
        stockAvailable: 3,
      );

      viewModel.addCatalogItem(first);
      viewModel.addCatalogItem(second);

      expect(viewModel.catalog.length, 1);
      expect(viewModel.catalog.first.stockAvailable, 7);
      expect(viewModel.catalog.first.name, 'Silver 15cm');
    });

    test('removes an item from the inventory catalog', () {
      final viewModel = SalesViewModel(
        catalog: [
          CrackerItem(
            id: 'remove-me',
            name: 'Remove Me',
            category: 'Sparklers',
            subCategory: 'Standard',
            unitPrice: 10.0,
            stockAvailable: 5,
          ),
        ],
      );

      viewModel.removeInventoryItem('remove-me');

      expect(viewModel.catalog, isEmpty);
    });

    test(
      'generates sequential codes for items in the same category and subcategory',
      () {
        final viewModel = SalesViewModel(
          catalog: [
            CrackerItem(
              id: 'seq-1',
              name: '7cm',
              category: 'Sparklers',
              subCategory: 'Standard',
              unitPrice: 10.0,
              stockAvailable: 5,
              itemCode: 'SP-STD-001',
            ),
          ],
        );

        final nextSequence =
            viewModel.catalog
                .where(
                  (item) =>
                      item.category == 'Sparklers' &&
                      item.subCategory == 'Standard',
                )
                .length +
            1;

        final firstCode = InventoryCodeGenerator.generateAutoCode(
          category: 'Sparklers',
          subCategory: 'Standard',
          itemName: '7cm',
          itemSequence: 1,
        );

        final secondCode = InventoryCodeGenerator.generateAutoCode(
          category: 'Sparklers',
          subCategory: 'Standard',
          itemName: '15cm-plane',
          itemSequence: nextSequence,
        );

        expect(firstCode, 'SP-STD-001');
        expect(secondCode, 'SP-STD-002');
      },
    );
  });
}
