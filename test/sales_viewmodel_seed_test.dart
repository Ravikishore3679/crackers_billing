import 'package:crackers_billing/models/cracker_item.dart';
import 'package:crackers_billing/view_models/sales_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SalesViewModel inventory catalog', () {
    test('starts with an empty catalog', () {
      final viewModel = SalesViewModel();

      expect(viewModel.catalog, isEmpty);
    });

    test('merges restocks into the existing item instead of creating duplicates', () {
      final viewModel = SalesViewModel(catalog: [
        CrackerItem(
          id: 'seed-sparklers-standard-15cm',
          name: 'Silver Sparklers 15cm',
          category: 'Sparklers',
          subCategory: 'Standard company',
          unitPrice: 18.0,
          stockAvailable: 10,
        ),
      ]);

      viewModel.addCatalogItem(
        CrackerItem(
          id: 'restock-1',
          name: 'Silver Sparklers 15cm',
          category: 'Sparklers',
          subCategory: 'Standard company',
          unitPrice: 18.0,
          stockAvailable: 25,
        ),
      );

      expect(viewModel.catalog.length, 1);
      expect(viewModel.catalog.first.stockAvailable, 35);
    });
  });
}
