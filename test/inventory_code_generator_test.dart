import 'package:crackers_billing/services/inventory_code_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryCodeGenerator', () {
    test('generates category prefix pattern', () {
      expect(InventoryCodeGenerator.generateCategoryCode(1), '1XXX');
      expect(InventoryCodeGenerator.generateCategoryCode(2), '2XXX');
    });

    test('generates subcategory prefix pattern', () {
      expect(InventoryCodeGenerator.generateSubcategoryCode(1, 1), '11XX');
      expect(InventoryCodeGenerator.generateSubcategoryCode(1, 2), '12XX');
      expect(InventoryCodeGenerator.generateSubcategoryCode(2, 1), '21XX');
    });

    test('generates item variant code pattern', () {
      expect(InventoryCodeGenerator.generateVariantCode(1, 1, 1), '111X');
      expect(InventoryCodeGenerator.generateVariantCode(1, 2, 1), '121X');
      expect(InventoryCodeGenerator.generateVariantCode(1, 2, 9), '129X');
    });

    test('creates a concrete item code with sequence number', () {
      expect(InventoryCodeGenerator.generateItemCode(1, 1, 1, 0), '1110');
      expect(InventoryCodeGenerator.generateItemCode(1, 1, 1, 9), '1119');
      expect(InventoryCodeGenerator.generateItemCode(1, 2, 5, 2), '1252');
    });

    test('uses the supplied sequence for sequential category codes', () {
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
        itemSequence: 2,
      );

      expect(firstCode, 'SP-STD-001');
      expect(secondCode, 'SP-STD-002');
      expect(firstCode, isNot(secondCode));
    });

    test('removes category and subcategory entries from the catalog manager', () {
      const category = 'Delete Test Category';
      const subCategory = 'Delete Test Subcategory';

      InventoryCatalogManager.addCategory(category);
      InventoryCatalogManager.addSubcategory(category, subCategory);

      expect(InventoryCatalogManager.categories, contains(category));
      expect(InventoryCatalogManager.subcategoriesFor(category), contains(subCategory));

      expect(InventoryCatalogManager.removeSubcategory(category, subCategory), isTrue);
      expect(InventoryCatalogManager.subcategoriesFor(category), isNot(contains(subCategory)));

      expect(InventoryCatalogManager.removeCategory(category), isTrue);
      expect(InventoryCatalogManager.categories, isNot(contains(category)));
    });
  });
}
