import 'package:crackers_billing/models/cracker_item.dart';
import 'package:crackers_billing/services/inventory_spreadsheet_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventorySpreadsheetImporter', () {
    test('template headers map to all supported inventory fields', () {
      final workbook = InventorySpreadsheetWorkbook.fromBytes(
        InventorySpreadsheetTemplate.createBytes(),
      );
      final headers = workbook.sheets.single.headers;
      final mapping = InventorySpreadsheetImporter.suggestMapping(headers);

      expect(headers, InventorySpreadsheetTemplate.headers);
      expect(mapping[InventoryImportField.name], 0);
      expect(mapping[InventoryImportField.category], 1);
      expect(mapping[InventoryImportField.subCategory], 2);
      expect(mapping[InventoryImportField.unitPrice], 3);
      expect(mapping[InventoryImportField.stockAvailable], 4);
      expect(mapping[InventoryImportField.taxRate], 5);
    });

    test('suggests mappings from common inventory headers', () {
      final mapping = InventorySpreadsheetImporter.suggestMapping([
        'Product Name',
        'Category',
        'Sub Category',
        'Rate',
        'Qty',
      ]);

      expect(mapping[InventoryImportField.name], 0);
      expect(mapping[InventoryImportField.category], 1);
      expect(mapping[InventoryImportField.subCategory], 2);
      expect(mapping[InventoryImportField.unitPrice], 3);
      expect(mapping[InventoryImportField.stockAvailable], 4);
    });

    test(
      'maps valid rows and generates the existing unique item-code format',
      () {
        const sheet = InventorySpreadsheetSheet(
          name: 'Inventory',
          headers: ['Product', 'Category', 'Subcategory', 'Price', 'Qty'],
          rows: [
            InventorySpreadsheetRow(
              rowNumber: 2,
              values: ['15cm plane', 'Sparklers', 'Standard', '25.50', '8'],
            ),
          ],
        );

        final preview = InventorySpreadsheetImporter.preview(
          sheet: sheet,
          mapping: const {
            InventoryImportField.name: 0,
            InventoryImportField.category: 1,
            InventoryImportField.subCategory: 2,
            InventoryImportField.unitPrice: 3,
            InventoryImportField.stockAvailable: 4,
          },
          existingItems: const <CrackerItem>[],
        );

        expect(preview.errors, isEmpty);
        expect(preview.items, hasLength(1));
        expect(preview.items.single.unitPrice, 25.5);
        expect(preview.items.single.stockAvailable, 8);
        expect(preview.items.single.itemCode, 'SP-STD-001');
      },
    );

    test('generates the next available item code from existing inventory', () {
      const sheet = InventorySpreadsheetSheet(
        name: 'Inventory',
        headers: ['Product', 'Category', 'Subcategory', 'Price', 'Qty'],
        rows: [
          InventorySpreadsheetRow(
            rowNumber: 2,
            values: ['Giant', 'Sparklers', 'Standard', '25.50', '8'],
          ),
        ],
      );

      final preview = InventorySpreadsheetImporter.preview(
        sheet: sheet,
        mapping: const {
          InventoryImportField.name: 0,
          InventoryImportField.category: 1,
          InventoryImportField.subCategory: 2,
          InventoryImportField.unitPrice: 3,
          InventoryImportField.stockAvailable: 4,
        },
        existingItems: const [
          CrackerItem(
            id: 'existing',
            name: 'Silver Sparklers',
            category: 'Sparklers',
            subCategory: 'Standard',
            itemCode: 'SP-STD-001',
            unitPrice: 10,
            stockAvailable: 5,
          ),
        ],
      );

      expect(preview.items.single.itemCode, 'SP-STD-002');
    });

    test(
      'skips rows with invalid required values and reports their row numbers',
      () {
        const sheet = InventorySpreadsheetSheet(
          name: 'Inventory',
          headers: ['Name', 'Category', 'Price', 'Stock'],
          rows: [
            InventorySpreadsheetRow(
              rowNumber: 2,
              values: ['Broken Item', 'Sparklers', 'not a price', '2'],
            ),
          ],
        );

        final preview = InventorySpreadsheetImporter.preview(
          sheet: sheet,
          mapping: const {
            InventoryImportField.name: 0,
            InventoryImportField.category: 1,
            InventoryImportField.unitPrice: 2,
            InventoryImportField.stockAvailable: 3,
          },
          existingItems: const <CrackerItem>[],
        );

        expect(preview.items, isEmpty);
        expect(preview.errors.single, contains('Row 2'));
        expect(preview.errors.single, contains('unit price is invalid'));
      },
    );
  });
}
