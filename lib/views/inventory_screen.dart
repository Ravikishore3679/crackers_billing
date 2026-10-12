import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cracker_item.dart';
import '../services/inventory_code_generator.dart';
import '../view_models/sales_view_model.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SalesViewModel>();
    final totalItems = viewModel.catalog.length;
    final totalStock = viewModel.catalog.fold<int>(0, (sum, item) => sum + item.stockAvailable);
    final inventoryValue = viewModel.catalog.fold<double>(
      0,
      (sum, item) => sum + (item.unitPrice * item.stockAvailable),
    );
    final isCompact = MediaQuery.sizeOf(context).width < 420;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PurchaseOrderEntryScreen(viewModel: viewModel),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 10 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isCompact ? 14 : 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isCompact ? 10 : 12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: Colors.teal, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inventory Dashboard',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Track stock and product movement',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: isCompact ? 8 : 12,
                  runSpacing: isCompact ? 8 : 12,
                  children: [
                    _SummaryCard(
                      title: 'Items',
                      value: '$totalItems',
                      color: Colors.teal,
                      icon: Icons.widgets_rounded,
                    ),
                    _SummaryCard(
                      title: 'Units',
                      value: '$totalStock',
                      color: Colors.indigo,
                      icon: Icons.storage_rounded,
                    ),
                    _SummaryCard(
                      title: 'Value',
                      value: '₹${inventoryValue.toStringAsFixed(2)}',
                      color: Colors.orange,
                      icon: Icons.currency_rupee_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: viewModel.catalog.isEmpty
                      ? const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text(
                                'No inventory items yet. Add a product from the button below.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: viewModel.catalog.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = viewModel.catalog[index];
                            final lowStock = item.stockAvailable <= 5;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: lowStock ? Colors.orange.withValues(alpha: 0.35) : Colors.transparent,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: lowStock ? Colors.orange.withValues(alpha: 0.12) : Colors.teal.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      item.name.isNotEmpty ? item.name[0].toUpperCase() : 'I',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.category} • ${item.subCategory.isEmpty ? 'General' : item.subCategory}',
                                          style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.itemCode ?? 'Code pending',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.4,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${item.unitPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.stockAvailable}',
                                        style: TextStyle(
                                          color: lowStock ? Colors.orange.shade800 : Colors.green.shade700,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    tooltip: 'Remove item',
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    color: Colors.red.shade700,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    onPressed: () => _confirmDeleteItem(context, viewModel, item),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _confirmDeleteItem(BuildContext context, SalesViewModel viewModel, CrackerItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove inventory item?'),
          content: Text('Delete ${item.name} from the inventory list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                viewModel.removeInventoryItem(item.id);
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.name} removed from inventory')),
                );
              },
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  static void _showAddItemDialog(BuildContext context, SalesViewModel viewModel) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final codeController = TextEditingController();

    String? selectedCategory = InventoryCatalogManager.categories.isNotEmpty
        ? InventoryCatalogManager.categories.first
        : null;
    String? selectedSubCategory = selectedCategory != null &&
            InventoryCatalogManager.subcategoriesFor(selectedCategory).isNotEmpty
        ? InventoryCatalogManager.subcategoriesFor(selectedCategory).first
        : null;

    void updateCode() {
      final category = selectedCategory ?? '';
      final subCategory = selectedSubCategory ?? '';
      final name = nameController.text.trim();
      if (category.isEmpty || subCategory.isEmpty || name.isEmpty) {
        codeController.text = 'Auto code';
        return;
      }

      final nextSequence = viewModel.catalog
              .where((item) => item.category == category && item.subCategory == subCategory)
              .length +
          1;

      codeController.text = InventoryCodeGenerator.generateAutoCode(
        category: category,
        subCategory: subCategory,
        itemName: name,
        itemSequence: nextSequence,
      );
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final categoryOptions = InventoryCatalogManager.categories;
            final subCategoryOptions = selectedCategory == null
                ? <String>[]
                : InventoryCatalogManager.subcategoriesFor(selectedCategory!);

            if (selectedCategory != null &&
                !categoryOptions.contains(selectedCategory)) {
              selectedCategory = categoryOptions.first;
            }

            if (selectedSubCategory != null &&
                !subCategoryOptions.contains(selectedSubCategory)) {
              selectedSubCategory = subCategoryOptions.isNotEmpty ? subCategoryOptions.first : null;
            }

            return AlertDialog(
              title: const Text('Add Inventory Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categoryOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedCategory = value;
                          selectedSubCategory = InventoryCatalogManager.subcategoriesFor(value).isNotEmpty
                              ? InventoryCatalogManager.subcategoriesFor(value).first
                              : null;
                        });
                        updateCode();
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSubCategory,
                      decoration: const InputDecoration(
                        labelText: 'Subcategory',
                        border: OutlineInputBorder(),
                      ),
                      items: subCategoryOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedSubCategory = value;
                        });
                        updateCode();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      onChanged: (_) => updateCode(),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Example: 15cm, Electric, Crackling',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      onChanged: (_) => updateCode(),
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
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showManageCategoriesDialog(context),
                        icon: const Icon(Icons.manage_search_rounded),
                        label: const Text('Manage categories'),
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
                      final category = selectedCategory?.trim() ?? '';
                      final subCategory = selectedSubCategory?.trim() ?? '';
                      final name = nameController.text.trim();
                      final quantity = int.tryParse(stockController.text.trim()) ?? 0;
                      final price = double.tryParse(priceController.text.trim()) ?? 0.0;

                      if (category.isEmpty || subCategory.isEmpty || name.isEmpty) {
                        throw StateError('Category, subcategory and item name are required.');
                      }

                      final categoryIndex = InventoryCodeGenerator.resolveCategoryIndex(category);
                      final subCategoryIndex = InventoryCodeGenerator.resolveSubCategoryIndex(subCategory);
                      final variantIndex = InventoryCodeGenerator.resolveVariantIndex(name);
                      final nextSequence = viewModel.catalog
                              .where((item) => item.category == category && item.subCategory == subCategory)
                              .length +
                          1;
                      final itemCode = InventoryCodeGenerator.generateAutoCode(
                        category: category,
                        subCategory: subCategory,
                        itemName: name,
                        itemSequence: nextSequence,
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
      },
    );
  }

  static void _showManageCategoriesDialog(BuildContext context) {
    final categoryController = TextEditingController();
    final subCategoryController = TextEditingController();
    final pageController = PageController();
    var pageIndex = 0;
    String selectedCategory = InventoryCatalogManager.categories.isNotEmpty
        ? InventoryCatalogManager.categories.first
        : '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setState) {
            final categories = InventoryCatalogManager.categories;
            final subCategories = selectedCategory.isEmpty
                ? <String>[]
                : InventoryCatalogManager.subcategoriesFor(selectedCategory);

            Widget buildAddCell({
              required TextEditingController controller,
              required String label,
              required VoidCallback onAdd,
            }) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(innerContext).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: label,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: onAdd,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Manage Categories')),
                  TextButton.icon(
                    onPressed: () {
                      if (pageIndex == 0) {
                        pageController.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                        setState(() => pageIndex = 1);
                      } else {
                        pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                        setState(() => pageIndex = 0);
                      }
                    },
                    icon: Icon(pageIndex == 0 ? Icons.folder_copy_rounded : Icons.category_rounded),
                    label: Text(pageIndex == 0 ? 'Subcategories' : 'Categories'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 440,
                child: PageView(
                  controller: pageController,
                  onPageChanged: (value) => setState(() => pageIndex = value),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildAddCell(
                          controller: categoryController,
                          label: 'New category',
                          onAdd: () {
                            final newCategory = categoryController.text.trim();
                            if (newCategory.isEmpty) {
                              return;
                            }
                            InventoryCatalogManager.addCategory(newCategory);
                            categoryController.clear();
                            setState(() {
                              selectedCategory = newCategory;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text('Categories', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (categories.isEmpty)
                          const Text('No categories yet.')
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: categories.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = categories[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(innerContext).colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(item, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete category',
                                        onPressed: () {
                                          final removed = InventoryCatalogManager.removeCategory(item);
                                          if (removed) {
                                            setState(() {
                                              if (selectedCategory == item) {
                                                selectedCategory = categories
                                                    .where((entry) => entry != item)
                                                    .isNotEmpty
                                                    ? categories.where((entry) => entry != item).first
                                                    : '';
                                              }
                                            });
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline_rounded),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: categories.contains(selectedCategory) ? selectedCategory : null,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: categories
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              selectedCategory = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        buildAddCell(
                          controller: subCategoryController,
                          label: 'New subcategory',
                          onAdd: () {
                            final newSubCategory = subCategoryController.text.trim();
                            if (newSubCategory.isEmpty || selectedCategory.isEmpty) {
                              return;
                            }
                            InventoryCatalogManager.addSubcategory(selectedCategory, newSubCategory);
                            subCategoryController.clear();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Subcategories for ${selectedCategory.isEmpty ? 'selected category' : selectedCategory}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (subCategories.isEmpty)
                          const Text('No subcategories yet.')
                        else
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subCategories
                                  .map(
                                    (item) => InputChip(
                                      label: Text(item),
                                      backgroundColor: Theme.of(innerContext).colorScheme.primaryContainer,
                                      onPressed: () {},
                                      deleteIcon: const Icon(Icons.close, size: 18),
                                      onDeleted: () {
                                        InventoryCatalogManager.removeSubcategory(selectedCategory, item);
                                        setState(() {});
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class PurchaseOrderEntryScreen extends StatefulWidget {
  const PurchaseOrderEntryScreen({super.key, required this.viewModel});

  final SalesViewModel viewModel;

  @override
  State<PurchaseOrderEntryScreen> createState() => _PurchaseOrderEntryScreenState();
}

class _PurchaseOrderEntryScreenState extends State<PurchaseOrderEntryScreen> {
  final List<_PurchaseOrderLine> _lines = [_PurchaseOrderLine()];

  void _addLine() {
    setState(() {
      _lines.add(_PurchaseOrderLine());
    });
  }

  void _removeLine(int index) {
    if (_lines.length == 1) {
      return;
    }

    setState(() {
      final line = _lines.removeAt(index);
      line.dispose();
    });
  }

  void _savePurchaseOrder() {
    final addedItems = <CrackerItem>[];
    final batchSequenceCount = <String, int>{};

    for (final line in _lines) {
      final category = line.category.trim();
      final subCategory = line.subCategory.trim();
      final name = line.nameController.text.trim();
      final quantity = int.tryParse(line.quantityController.text.trim()) ?? 0;
      final price = double.tryParse(line.priceController.text.trim()) ?? 0.0;

      if (category.isEmpty || subCategory.isEmpty || name.isEmpty || quantity <= 0) {
        continue;
      }

      final categoryIndex = InventoryCodeGenerator.resolveCategoryIndex(category);
      final subCategoryIndex = InventoryCodeGenerator.resolveSubCategoryIndex(subCategory);
      final variantIndex = InventoryCodeGenerator.resolveVariantIndex(name);
      final categoryKey = '$category|$subCategory';
      final currentBatchCount = batchSequenceCount[categoryKey] ?? 0;
      final nextSequence = widget.viewModel.catalog
              .where((item) => item.category == category && item.subCategory == subCategory)
              .length +
          currentBatchCount +
          1;
      batchSequenceCount[categoryKey] = currentBatchCount + 1;

      final existingCodes = widget.viewModel.catalog
          .where((item) => item.category == category && item.subCategory == subCategory)
          .map((item) => item.itemCode ?? '')
          .where((code) => code.isNotEmpty)
          .toList();
      final uniqueCode = InventoryCodeGenerator.generateUniqueAutoCode(
        category: category,
        subCategory: subCategory,
        itemName: name,
        existingCodes: existingCodes,
        startSequence: nextSequence,
      );

      final item = CrackerItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '-${addedItems.length}',
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
        itemCode: uniqueCode,
      );

      addedItems.add(item);
    }

    if (addedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one valid item before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    for (final item in addedItems) {
      widget.viewModel.addCatalogItem(item);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${addedItems.length} item(s) to inventory')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Order'),
        actions: [
          TextButton(
            onPressed: _savePurchaseOrder,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add item'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _lines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    final categoryOptions = InventoryCatalogManager.categories;
                    final subCategoryOptions = line.category.isEmpty
                        ? <String>[]
                        : InventoryCatalogManager.subcategoriesFor(line.category);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Item ${index + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (_lines.length > 1)
                                IconButton(
                                  onPressed: () => _removeLine(index),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  color: Colors.red,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RawAutocomplete<CrackerItem>(
                            textEditingController: line.nameController,
                            focusNode: line.focusNode,
                            optionsBuilder: (TextEditingValue value) {
                              final query = value.text.trim();
                              if (query.length < 3) {
                                return const Iterable<CrackerItem>.empty();
                              }

                              final normalized = query.toLowerCase();
                              return widget.viewModel.catalog.where((item) {
                                final itemName = item.name.toLowerCase();
                                final category = item.category.toLowerCase();
                                final itemCode = (item.itemCode ?? '').toLowerCase();
                                return itemName.contains(normalized) ||
                                    category.contains(normalized) ||
                                    itemCode.contains(normalized);
                              });
                            },
                            displayStringForOption: (option) => option.name,
                            onSelected: (CrackerItem option) {
                              setState(() {
                                line.nameController.text = option.name;
                                line.category = option.category;
                                line.subCategory = option.subCategory;
                                line.priceController.text = option.unitPrice.toStringAsFixed(2);
                              });
                            },
                            fieldViewBuilder: (
                              BuildContext context,
                              TextEditingController fieldController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              return TextField(
                                controller: fieldController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Item name',
                                  border: OutlineInputBorder(),
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
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
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: line.category.isEmpty ? null : line.category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: categoryOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option,
                                    child: Text(option),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                line.category = value;
                                line.subCategory = InventoryCatalogManager.subcategoriesFor(value).isNotEmpty
                                    ? InventoryCatalogManager.subcategoriesFor(value).first
                                    : '';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: subCategoryOptions.contains(line.subCategory)
                                ? line.subCategory
                                : (subCategoryOptions.isNotEmpty ? subCategoryOptions.first : null),
                            decoration: const InputDecoration(
                              labelText: 'Subcategory',
                              border: OutlineInputBorder(),
                            ),
                            items: subCategoryOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option,
                                    child: Text(option),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                line.subCategory = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: line.quantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: line.priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Price',
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _savePurchaseOrder,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Purchase Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }
}

class _PurchaseOrderLine {
  _PurchaseOrderLine() {
    category = InventoryCatalogManager.categories.isNotEmpty
        ? InventoryCatalogManager.categories.first
        : '';
    subCategory = InventoryCatalogManager.subcategoriesFor(category).isNotEmpty
        ? InventoryCatalogManager.subcategoriesFor(category).first
        : '';
    quantityController.text = '1';
  }

  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  String category = '';
  String subCategory = '';

  void dispose() {
    focusNode.dispose();
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
