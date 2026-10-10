import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/cracker_item.dart';
import '../models/invoice.dart';
import '../services/inventory_code_generator.dart';
import '../view_models/sales_view_model.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SalesViewModel>();
    return _SalesScreenBody(viewModel: viewModel);
  }
}

class _SalesScreenBody extends StatelessWidget {
  const _SalesScreenBody({required this.viewModel});

  final SalesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 980;

    return SafeArea(
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isWideLayout
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _CatalogPanel(viewModel: viewModel),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 420,
                      child: _CartPanel(viewModel: viewModel),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _CatalogPanel(viewModel: viewModel),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 430,
                      child: _CartPanel(viewModel: viewModel),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CatalogPanel extends StatefulWidget {
  const _CatalogPanel({required this.viewModel});

  final SalesViewModel viewModel;

  @override
  State<_CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends State<_CatalogPanel> {
  final TextEditingController _searchController = TextEditingController();

  void _showAddItemDialog(BuildContext context, SalesViewModel viewModel) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final subCategoryController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final codeController = TextEditingController();

    void updateCode() {
      final category = categoryController.text.trim();
      final subCategory = subCategoryController.text.trim();
      final name = nameController.text.trim();
      if (category.isEmpty || subCategory.isEmpty || name.isEmpty) {
        codeController.text = 'Auto code';
        return;
      }

      codeController.text = InventoryCodeGenerator.generateAutoCode(
        category: category,
        subCategory: subCategory,
        itemName: name,
        itemSequence: (int.tryParse(stockController.text.trim()) ?? 0).clamp(0, 9),
      );
    }

    final categoryField = TextField(
      controller: categoryController,
      onChanged: (_) => updateCode(),
      decoration: const InputDecoration(
        labelText: 'Category',
        hintText: 'Example: Sparklers',
        border: OutlineInputBorder(),
      ),
    );

    final subCategoryField = TextField(
      controller: subCategoryController,
      onChanged: (_) => updateCode(),
      decoration: const InputDecoration(
        labelText: 'Subcategory',
        hintText: 'Example: Standard company',
        border: OutlineInputBorder(),
      ),
    );

    final nameField = TextField(
      controller: nameController,
      onChanged: (_) => updateCode(),
      decoration: const InputDecoration(
        labelText: 'Name',
        hintText: 'Example: 15cm, Electric, Crackling',
        border: OutlineInputBorder(),
      ),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Inventory Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                categoryField,
                const SizedBox(height: 12),
                subCategoryField,
                const SizedBox(height: 12),
                nameField,
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final category = categoryController.text.trim();
                  final subCategory = subCategoryController.text.trim();
                  final name = nameController.text.trim();
                  final quantity = int.tryParse(stockController.text.trim()) ?? 0;
                  final price = double.tryParse(priceController.text.trim()) ?? 0.0;

                  if (category.isEmpty || subCategory.isEmpty || name.isEmpty) {
                    throw StateError('Category, subcategory and item name are required.');
                  }

                  final categoryIndex = InventoryCodeGenerator.resolveCategoryIndex(category);
                  final subCategoryIndex = InventoryCodeGenerator.resolveSubCategoryIndex(subCategory);
                  final variantIndex = InventoryCodeGenerator.resolveVariantIndex(name);
                  final safeSequence = quantity.clamp(0, 9);

                  final itemCode = InventoryCodeGenerator.generateAutoCode(
                    category: category,
                    subCategory: subCategory,
                    itemName: name,
                    itemSequence: safeSequence,
                  );

                  final item = CrackerItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    category: category,
                    subCategory: subCategory,
                    unitPrice: price,
                    stockAvailable: quantity,
                    categoryCode: InventoryCodeGenerator.generateCategoryCode(categoryIndex),
                    subCategoryCode: InventoryCodeGenerator.generateSubcategoryCode(
                      categoryIndex,
                      subCategoryIndex,
                    ),
                    variantCode: InventoryCodeGenerator.generateVariantCode(
                      categoryIndex,
                      subCategoryIndex,
                      variantIndex,
                    ),
                    itemCode: itemCode,
                  );

                  viewModel.addCatalogItem(item);
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${item.name} with code $itemCode')),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? widget.viewModel.catalog
        : widget.viewModel.catalog.where((item) {
            final itemName = item.name.toLowerCase();
            final category = item.category.toLowerCase();
            return itemName.contains(query) || category.contains(query);
          }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Available Crackers',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddItemDialog(context, widget.viewModel),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add Item'),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${filteredItems.length} items'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or category',
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (filteredItems.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No crackers match your search.'),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in filteredItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ProductCard(
                            item: item,
                            viewModel: widget.viewModel,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, required this.viewModel});

  final CrackerItem item;
  final SalesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final canAdd = item.stockAvailable > 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.stockAvailable > 0
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${item.stockAvailable} in stock',
                    style: TextStyle(
                      color: item.stockAvailable > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.category,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Price:'),
                const Spacer(),
                Text(
                  '₹${item.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canAdd
                    ? () {
                        try {
                          viewModel.addToCart(item);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.name} added to cart.'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        } catch (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Add to Cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.viewModel});

  final SalesViewModel viewModel;

  Future<void> _shareInvoice(BuildContext context, Invoice invoice) async {
    await SharePlus.instance.share(
      ShareParams(
        text: invoice.invoiceSummaryText,
        subject: 'Crackers Invoice ${invoice.id}',
      ),
    );
  }

  Future<Uint8List> _buildInvoicePdfBytes(Invoice invoice) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CRACKERS SALES & INVOICES',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Invoice: ${invoice.id}'),
              pw.Text(
                'Customer: ${invoice.customerName.isEmpty ? 'Walk-in Customer' : invoice.customerName}',
              ),
              pw.Text(
                'Phone: ${invoice.customerPhone.isEmpty ? 'Not provided' : invoice.customerPhone}',
              ),
              pw.Text('Date: ${invoice.date.day}/${invoice.date.month}/${invoice.date.year}'),
              pw.Divider(),
              ...invoice.lineItems.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${item.crackerItem.name} x ${item.quantity}'),
                      pw.Text('₹${item.subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
              pw.Divider(),
              pw.Text('Gross Total: ₹${invoice.grossTotal.toStringAsFixed(2)}'),
              pw.Text('GST: ₹${invoice.taxTotal.toStringAsFixed(2)}'),
              pw.Text('Discount: ₹${invoice.discountAmount.toStringAsFixed(2)}'),
              pw.Text(
                'Net Payable: ₹${invoice.netTotal.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  Future<void> _printInvoice(Invoice invoice) async {
    try {
      final pdfBytes = await _buildInvoicePdfBytes(invoice);

      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'invoice_${invoice.id}.pdf',
        );
        return;
      }

      await Printing.layoutPdf(
        name: 'invoice_${invoice.id}.pdf',
        onLayout: (_) async => pdfBytes,
      );
    } catch (error) {
      debugPrint('Failed to print invoice: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cart',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: viewModel.customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: viewModel.customerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (viewModel.cart.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No items in cart yet.'),
                  ),
                )
              else
                ...viewModel.cart.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  line.crackerItem.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    viewModel.removeFromCart(line.crackerItem),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove item',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('₹${line.subtotal.toStringAsFixed(2)}'),
                              const Spacer(),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      final nextQty = line.quantity - 1;
                                      if (nextQty <= 0) {
                                        viewModel.removeFromCart(
                                          line.crackerItem,
                                        );
                                        return;
                                      }
                                      viewModel.updateQuantity(
                                        line.crackerItem.id,
                                        nextQty,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text('${line.quantity}'),
                                  IconButton(
                                    onPressed: () {
                                      try {
                                        viewModel.updateQuantity(
                                          line.crackerItem.id,
                                          line.quantity + 1,
                                        );
                                      } catch (error) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(error.toString()),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(child: Text('Discount')),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: viewModel.discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        suffixText: '₹',
                      ),
                      onChanged: (value) {
                        final parsedValue = double.tryParse(value) ?? 0.0;
                        viewModel.applyDiscount(parsedValue);
                      },
                    ),
                  ),
                ],
              ),
              Slider(
                value: viewModel.discountAmount,
                max: (viewModel.grossTotal).clamp(0.0, 5000.0),
                onChanged: (value) {
                  viewModel.applyDiscount(value);
                },
              ),
              const SizedBox(height: 8),
              _SummaryRow(label: 'Gross', value: viewModel.grossTotal),
              _SummaryRow(label: 'GST Tax', value: viewModel.taxTotal),
              _SummaryRow(label: 'Discount', value: viewModel.discountAmount),
              const Divider(),
              _SummaryRow(
                label: 'Net Payable',
                value: viewModel.netTotal,
                isTotal: true,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: viewModel.cart.isEmpty
                    ? null
                    : () async {
                        try {
                          final invoice = await viewModel.checkout();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Invoice ${invoice.id} generated for ${invoice.customerName.isNotEmpty ? invoice.customerName : 'customer'}',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Generate Invoice'),
              ),
              if (viewModel.lastGeneratedInvoice != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill ready for customer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        viewModel.lastGeneratedInvoice!.invoiceSummaryText,
                        softWrap: true,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 140,
                            child: OutlinedButton.icon(
                              onPressed: () => _shareInvoice(context, viewModel.lastGeneratedInvoice!),
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Share'),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: FilledButton.icon(
                              onPressed: () => _printInvoice(viewModel.lastGeneratedInvoice!),
                              icon: const Icon(Icons.print_rounded),
                              label: const Text('Print'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (viewModel.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    viewModel.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final double value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
