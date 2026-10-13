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
    return SafeArea(
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _CatalogPanel(viewModel: viewModel),
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

      final existingCodes = viewModel.catalog
          .where((item) => item.category == category && item.subCategory == subCategory)
          .map((item) => item.itemCode ?? '')
          .where((code) => code.isNotEmpty)
          .toList();

      codeController.text = InventoryCodeGenerator.generateUniqueAutoCode(
        category: category,
        subCategory: subCategory,
        itemName: name,
        existingCodes: existingCodes,
        startSequence: 1,
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

    final nameFocusNode = FocusNode();
    final nameField = RawAutocomplete<CrackerItem>(
      textEditingController: nameController,
      focusNode: nameFocusNode,
      optionsBuilder: (TextEditingValue value) {
        final query = value.text.trim();
        if (query.length < 3) {
          return const Iterable<CrackerItem>.empty();
        }

        final normalized = query.toLowerCase();
        return viewModel.catalog.where((item) {
          final itemName = item.name.toLowerCase();
          final category = item.category.toLowerCase();
          return itemName.contains(normalized) || category.contains(normalized) ||
              (item.itemCode ?? '').toLowerCase().contains(normalized);
        });
      },
      displayStringForOption: (option) => option.name,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          onChanged: (_) {
            updateCode();
          },
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Type at least 3 letters to search existing items',
            border: OutlineInputBorder(),
          ),
        );
      },
      onSelected: (CrackerItem option) {
        nameController.text = option.name;
        categoryController.text = option.category;
        subCategoryController.text = option.subCategory;
        updateCode();
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 380),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option.name),
                    subtitle: Text('${option.category} • ${option.subCategory.isEmpty ? 'General' : option.subCategory}'),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
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
                  final existingCodes = viewModel.catalog
                      .where((item) => item.category == category && item.subCategory == subCategory)
                      .map((item) => item.itemCode ?? '')
                      .where((code) => code.isNotEmpty)
                      .toList();

                  final itemCode = InventoryCodeGenerator.generateUniqueAutoCode(
                    category: category,
                    subCategory: subCategory,
                    itemName: name,
                    existingCodes: existingCodes,
                    startSequence: 1,
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
            final itemCode = (item.itemCode ?? '').toLowerCase();
            final categoryCode = (item.categoryCode ?? '').toLowerCase();
            final subCategoryCode = (item.subCategoryCode ?? '').toLowerCase();
            return itemName.contains(query) ||
                category.contains(query) ||
                itemCode.contains(query) ||
                categoryCode.contains(query) ||
                subCategoryCode.contains(query);
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
            Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Open cart',
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CartScreen(viewModel: widget.viewModel),
                          ),
                        ),
                        icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                        label: Text('Cart (${widget.viewModel.cart.length})'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${filteredItems.length} items'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, category or code',
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
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ProductCard(
                            item: item,
                            viewModel: widget.viewModel,
                            onAddedToCart: () {
                              _searchController.clear();
                              setState(() {});
                            },
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

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.viewModel});

  final SalesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Cart'),
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: 'Close cart',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: _CartPanel(viewModel: viewModel),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.viewModel,
    this.onAddedToCart,
  });

  final CrackerItem item;
  final SalesViewModel viewModel;
  final VoidCallback? onAddedToCart;

  @override
  Widget build(BuildContext context) {
    final canAdd = item.stockAvailable > 0;
    final cartQuantity = viewModel.cart
        .where((line) => line.crackerItem.id == item.id)
        .fold<int>(0, (total, line) => total + line.quantity);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: (item.itemCode ?? '').isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.category}-${item.subCategory.isEmpty ? 'General' : item.subCategory}-${item.name}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.itemCode!,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '${item.category}-${item.subCategory.isEmpty ? 'General' : item.subCategory}-${item.name}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cartQuantity > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      '$cartQuantity in cart',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.stockAvailable > 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${item.stockAvailable} in stock',
                        style: TextStyle(
                          color: item.stockAvailable > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '₹${item.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (cartQuantity > 0) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          try {
                            viewModel.updateQuantity(item.id, cartQuantity - 1);
                          } catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error.toString()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            Icons.remove,
                            color: Colors.grey.shade700,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: canAdd
                          ? () {
                              try {
                                viewModel.addToCart(item);
                                onAddedToCart?.call();
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
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: canAdd ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          Icons.add,
                          color: canAdd ? Theme.of(context).colorScheme.onPrimary : Colors.grey.shade600,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bill Details',
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Items',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (viewModel.cart.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('No items in cart yet.'),
                        ),
                      )
                    else ...[
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Item',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 50, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                          SizedBox(width: 80, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const Divider(),
                      ...viewModel.cart.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.crackerItem.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₹${line.crackerItem.unitPrice.toStringAsFixed(2)} each',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 84,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        final nextQty = line.quantity - 1;
                                        if (nextQty <= 0) {
                                          viewModel.removeFromCart(line.crackerItem);
                                          return;
                                        }
                                        viewModel.updateQuantity(line.crackerItem.id, nextQty);
                                      },
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Icon(Icons.remove, size: 14),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        try {
                                          viewModel.updateQuantity(line.crackerItem.id, line.quantity + 1);
                                        } catch (error) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(error.toString()),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Icon(Icons.add, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '₹${line.subtotal.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                onPressed: () => viewModel.removeFromCart(line.crackerItem),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                tooltip: 'Remove item',
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                padding: const EdgeInsets.only(left: 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Discount')),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: viewModel.discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    const SizedBox(height: 8),
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
                    _SummaryRow(label: 'Net Payable', value: viewModel.netTotal, isTotal: true),
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
                  ],
                ),
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
