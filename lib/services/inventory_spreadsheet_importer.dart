import 'package:excel/excel.dart';

import '../models/cracker_item.dart';
import 'inventory_code_generator.dart';

class InventorySpreadsheetTemplate {
  static const List<String> headers = [
    'Item Name',
    'Category',
    'Subcategory',
    'Unit Price',
    'Stock Quantity',
    'Tax Rate',
  ];

  static List<int> createBytes() {
    final workbook = Excel.createExcel();
    final sheetName = workbook.getDefaultSheet() ?? 'Sheet1';
    workbook.appendRow(
      sheetName,
      headers.map((header) => TextCellValue(header)).toList(),
    );

    return workbook.save(fileName: 'inventory_template.xlsx') ??
        (throw StateError('Could not create the inventory Excel template.'));
  }
}

class InventorySpreadsheetRow {
  const InventorySpreadsheetRow({
    required this.rowNumber,
    required this.values,
  });

  final int rowNumber;
  final List<String> values;
}

class InventorySpreadsheetSheet {
  const InventorySpreadsheetSheet({
    required this.name,
    required this.headers,
    required this.rows,
  });

  final String name;
  final List<String> headers;
  final List<InventorySpreadsheetRow> rows;
}

class InventorySpreadsheetWorkbook {
  const InventorySpreadsheetWorkbook({required this.sheets});

  final List<InventorySpreadsheetSheet> sheets;

  factory InventorySpreadsheetWorkbook.fromBytes(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final sheets = <InventorySpreadsheetSheet>[];

    for (final entry in workbook.tables.entries) {
      final rows = entry.value.rows
          .map((row) => row.map(_cellText).toList())
          .toList();
      final headerIndex = rows.indexWhere(
        (row) => row.any((value) => value.trim().isNotEmpty),
      );
      if (headerIndex < 0) {
        continue;
      }

      final rawHeaders = rows[headerIndex];
      final headers = List<String>.generate(rawHeaders.length, (index) {
        final header = rawHeaders[index].trim();
        return header.isEmpty ? 'Column ${index + 1}' : header;
      });

      final dataRows = <InventorySpreadsheetRow>[];
      for (var index = headerIndex + 1; index < rows.length; index++) {
        final values = List<String>.generate(headers.length, (column) {
          return column < rows[index].length ? rows[index][column].trim() : '';
        });
        if (values.every((value) => value.isEmpty)) {
          continue;
        }
        dataRows.add(
          InventorySpreadsheetRow(rowNumber: index + 1, values: values),
        );
      }

      sheets.add(
        InventorySpreadsheetSheet(
          name: entry.key,
          headers: headers,
          rows: dataRows,
        ),
      );
    }

    if (sheets.isEmpty) {
      throw const FormatException('The workbook has no readable sheets.');
    }

    return InventorySpreadsheetWorkbook(sheets: sheets);
  }

  static String _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    if (value is TextCellValue) return value.value.text ?? '';
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is DateCellValue) {
      return value.asDateTimeLocal().toIso8601String();
    }
    if (value is BoolCellValue) return value.value.toString();
    if (value is FormulaCellValue) return value.formula;
    return value.toString();
  }
}

enum InventoryImportField {
  name,
  category,
  subCategory,
  unitPrice,
  stockAvailable,
  taxRate,
}

extension InventoryImportFieldDetails on InventoryImportField {
  String get label => switch (this) {
    InventoryImportField.name => 'Item name',
    InventoryImportField.category => 'Category',
    InventoryImportField.subCategory => 'Subcategory',
    InventoryImportField.unitPrice => 'Unit price',
    InventoryImportField.stockAvailable => 'Stock quantity',
    InventoryImportField.taxRate => 'Tax rate',
  };

  bool get isRequired => switch (this) {
    InventoryImportField.name ||
    InventoryImportField.category ||
    InventoryImportField.unitPrice ||
    InventoryImportField.stockAvailable => true,
    _ => false,
  };

  List<String> get headerAliases => switch (this) {
    InventoryImportField.name => ['name', 'itemname', 'product', 'productname'],
    InventoryImportField.category => ['category', 'group', 'type'],
    InventoryImportField.subCategory => ['subcategory', 'subcat', 'subtype'],
    InventoryImportField.unitPrice => ['unitprice', 'price', 'rate'],
    InventoryImportField.stockAvailable => [
      'stock',
      'quantity',
      'qty',
      'stockquantity',
      'stockavailable',
    ],
    InventoryImportField.taxRate => ['taxrate', 'tax', 'gst', 'gstpercent'],
  };
}

class InventoryImportPreview {
  const InventoryImportPreview({
    required this.items,
    required this.errors,
    required this.scannedRows,
  });

  final List<CrackerItem> items;
  final List<String> errors;
  final int scannedRows;
}

class InventorySpreadsheetImporter {
  static Map<InventoryImportField, int> suggestMapping(List<String> headers) {
    final normalizedHeaders = headers
        .map(
          (header) => header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
        )
        .toList();
    final mapping = <InventoryImportField, int>{};

    for (final field in InventoryImportField.values) {
      final index = normalizedHeaders.indexWhere(
        (header) => field.headerAliases.contains(header),
      );
      mapping[field] = index;
    }

    return mapping;
  }

  static InventoryImportPreview preview({
    required InventorySpreadsheetSheet sheet,
    required Map<InventoryImportField, int> mapping,
    required List<CrackerItem> existingItems,
  }) {
    final importedItems = <CrackerItem>[];
    final errors = <String>[];
    final nonEmptyRows = sheet.rows
        .where((row) => row.values.any((value) => value.trim().isNotEmpty))
        .toList();

    for (final row in nonEmptyRows) {
      String valueFor(InventoryImportField field) {
        final column = mapping[field] ?? -1;
        if (column < 0 || column >= row.values.length) return '';
        return row.values[column].trim();
      }

      final name = valueFor(InventoryImportField.name);
      final category = valueFor(InventoryImportField.category);
      final subCategory = valueFor(InventoryImportField.subCategory);
      final rawPrice = valueFor(InventoryImportField.unitPrice);
      final rawStock = valueFor(InventoryImportField.stockAvailable);
      final price = _parseNumber(rawPrice);
      final stockValue = _parseNumber(rawStock);
      final rowErrors = <String>[];

      if (name.isEmpty) rowErrors.add('item name is empty');
      if (category.isEmpty) rowErrors.add('category is empty');
      if (price == null || price < 0) rowErrors.add('unit price is invalid');
      if (stockValue == null || stockValue <= 0 || stockValue % 1 != 0) {
        rowErrors.add('stock quantity must be a positive whole number');
      }

      final rawTax = valueFor(InventoryImportField.taxRate);
      var taxRate = rawTax.isEmpty ? 0.18 : _parseNumber(rawTax);
      if (taxRate != null && taxRate > 1 && taxRate <= 100) {
        taxRate /= 100;
      }
      if (taxRate == null || taxRate < 0) {
        rowErrors.add('tax rate is invalid');
      }

      if (rowErrors.isNotEmpty) {
        errors.add('Row ${row.rowNumber}: ${rowErrors.join(', ')}.');
        continue;
      }

      final itemCode = _generateItemCode(
        category: category,
        subCategory: subCategory,
        itemName: name,
        existingItems: existingItems,
        importedItems: importedItems,
      );

      importedItems.add(
        CrackerItem(
          id: 'xlsx-${DateTime.now().microsecondsSinceEpoch}-${row.rowNumber}',
          name: name,
          category: category,
          subCategory: subCategory,
          itemCode: itemCode,
          unitPrice: price!,
          stockAvailable: stockValue!.toInt(),
          taxRate: taxRate!,
        ),
      );
    }

    return InventoryImportPreview(
      items: importedItems,
      errors: errors,
      scannedRows: nonEmptyRows.length,
    );
  }

  static String _generateItemCode({
    required String category,
    required String subCategory,
    required String itemName,
    required List<CrackerItem> existingItems,
    required List<CrackerItem> importedItems,
  }) {
    final relatedItems = [
      ...existingItems.where(
        (item) => item.category == category && item.subCategory == subCategory,
      ),
      ...importedItems.where(
        (item) => item.category == category && item.subCategory == subCategory,
      ),
    ];

    return InventoryCodeGenerator.generateUniqueAutoCode(
      category: category,
      subCategory: subCategory,
      itemName: itemName,
      existingCodes: relatedItems.map((item) => item.itemCode ?? ''),
      startSequence: relatedItems.length + 1,
    );
  }

  static double? _parseNumber(String value) {
    final normalized = value
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }
}
