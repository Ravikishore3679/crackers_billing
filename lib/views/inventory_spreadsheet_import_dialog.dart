import 'package:flutter/material.dart';

import '../models/cracker_item.dart';
import '../services/inventory_spreadsheet_importer.dart';

class InventorySpreadsheetImportDialog extends StatefulWidget {
  const InventorySpreadsheetImportDialog({
    super.key,
    required this.workbook,
    required this.existingItems,
  });

  final InventorySpreadsheetWorkbook workbook;
  final List<CrackerItem> existingItems;

  @override
  State<InventorySpreadsheetImportDialog> createState() =>
      _InventorySpreadsheetImportDialogState();
}

class _InventorySpreadsheetImportDialogState
    extends State<InventorySpreadsheetImportDialog> {
  late InventorySpreadsheetSheet _sheet;
  late Map<InventoryImportField, int> _mapping;

  @override
  void initState() {
    super.initState();
    _sheet = widget.workbook.sheets.first;
    _mapping = InventorySpreadsheetImporter.suggestMapping(_sheet.headers);
  }

  InventoryImportPreview? get _preview {
    final requiredFields = InventoryImportField.values.where(
      (field) => field.isRequired,
    );
    if (requiredFields.any((field) => (_mapping[field] ?? -1) < 0)) {
      return null;
    }

    return InventorySpreadsheetImporter.preview(
      sheet: _sheet,
      mapping: _mapping,
      existingItems: widget.existingItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AlertDialog(
      title: const Text('Map spreadsheet columns'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.workbook.sheets.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: _sheet.name,
                  decoration: const InputDecoration(labelText: 'Worksheet'),
                  items: widget.workbook.sheets
                      .map(
                        (sheet) => DropdownMenuItem(
                          value: sheet.name,
                          child: Text(sheet.name),
                        ),
                      )
                      .toList(),
                  onChanged: (name) {
                    if (name == null) return;
                    setState(() {
                      _sheet = widget.workbook.sheets.firstWhere(
                        (sheet) => sheet.name == name,
                      );
                      _mapping = InventorySpreadsheetImporter.suggestMapping(
                        _sheet.headers,
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              for (final field in InventoryImportField.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<int>(
                    initialValue: _mapping[field] ?? -1,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: field.isRequired
                          ? '${field.label} *'
                          : field.label,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: -1,
                        child: Text(
                          field.isRequired ? 'Select a column' : 'Not mapped',
                        ),
                      ),
                      for (final entry in _sheet.headers.indexed)
                        DropdownMenuItem(
                          value: entry.$1,
                          child: Text(
                            '${entry.$2} (${_columnName(entry.$1)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (column) {
                      if (column == null) return;
                      setState(() => _mapping[field] = column);
                    },
                  ),
                ),
              const SizedBox(height: 8),
              if (preview == null)
                Text(
                  'Map the required columns to continue.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else ...[
                Text(
                  '${preview.items.length} of ${preview.scannedRows} rows ready to import',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (preview.items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final item in preview.items.take(3))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name, maxLines: 1),
                      subtitle: Text(
                        '${item.category}${item.subCategory.isEmpty ? '' : ' · ${item.subCategory}'} · ${item.stockAvailable} in stock',
                        maxLines: 1,
                      ),
                      trailing: Text('₹${item.unitPrice.toStringAsFixed(2)}'),
                    ),
                ],
                if (preview.errors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${preview.errors.length} rows will be skipped:',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  for (final error in preview.errors.take(3))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        error,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: preview == null || preview.items.isEmpty
              ? null
              : () => Navigator.of(context).pop(preview.items),
          icon: const Icon(Icons.file_download_done_rounded),
          label: Text(
            preview == null || preview.items.isEmpty
                ? 'Import'
                : 'Import ${preview.items.length}',
          ),
        ),
      ],
    );
  }

  String _columnName(int columnIndex) {
    var number = columnIndex + 1;
    var name = '';
    while (number > 0) {
      final remainder = (number - 1) % 26;
      name = String.fromCharCode(65 + remainder) + name;
      number = (number - remainder - 1) ~/ 26;
    }
    return name;
  }
}
