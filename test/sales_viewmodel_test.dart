import 'package:crackers_billing/models/cracker_item.dart';
import 'package:crackers_billing/view_models/sales_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SalesViewModel', () {
    test('starts with an empty catalog until real inventory is added', () {
      final viewModel = SalesViewModel();

      expect(viewModel.catalog, isEmpty);
    });

    test('adds items to cart up to stock availability and rejects excess stock', () {
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
    });

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
      viewModel.addToCart(viewModel.catalog.first);
      final invoice = await viewModel.checkout();

      expect(invoice.customerName, 'Ravi');
      expect(invoice.lineItems.length, 1);
      expect(viewModel.cart, isEmpty);
      expect(invoice.netTotal, greaterThanOrEqualTo(0));
    });

    test('merges duplicate item entries by category, subcategory and name', () {
      final viewModel = SalesViewModel();

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
  });
}
