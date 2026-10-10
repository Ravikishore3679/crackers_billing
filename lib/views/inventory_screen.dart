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
        onPressed: () => _showAddItemDialog(context, viewModel),
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
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = viewModel.catalog[index];
                            final lowStock = item.stockAvailable <= 5;

                            return Container(
                              padding: EdgeInsets.all(isCompact ? 12 : 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: lowStock ? Colors.orange.withValues(alpha: 0.4) : Colors.transparent,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: isCompact ? 20 : 26,
                                    backgroundColor: lowStock ? Colors.orange.withValues(alpha: 0.12) : Colors.teal.withValues(alpha: 0.12),
                                    child: Text(
                                      item.name.isNotEmpty ? item.name[0].toUpperCase() : 'I',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.category} • ${item.subCategory.isEmpty ? 'General' : item.subCategory}',
                                          style: TextStyle(color: Colors.grey.shade700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.itemCode ?? 'Code pending',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${item.unitPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${item.stockAvailable} in stock',
                                        style: TextStyle(
                                          color: lowStock ? Colors.orange.shade800 : Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
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
              ],
            ),
          ),
        ),
      ),
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

      codeController.text = InventoryCodeGenerator.generateAutoCode(
        category: category,
        subCategory: subCategory,
        itemName: name,
        itemSequence: 0,
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
                      final itemCode = InventoryCodeGenerator.generateAutoCode(
                        category: category,
                        subCategory: subCategory,
                        itemName: name,
                        itemSequence: 0,
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

            return AlertDialog(
              title: const Text('Manage Categories'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: categoryController,
                            decoration: const InputDecoration(
                              labelText: 'New category',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
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
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
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
                        ),
                        if (selectedCategory.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Delete category',
                            onPressed: () {
                              final categoryToDelete = selectedCategory;
                              final removed = InventoryCatalogManager.removeCategory(categoryToDelete);
                              if (removed) {
                                setState(() {
                                  selectedCategory = categories
                                      .where((item) => item != categoryToDelete)
                                      .isNotEmpty
                                      ? categories.where((item) => item != categoryToDelete).first
                                      : '';
                                });
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: subCategoryController,
                            decoration: const InputDecoration(
                              labelText: 'New subcategory',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            final newSubCategory = subCategoryController.text.trim();
                            if (newSubCategory.isEmpty || selectedCategory.isEmpty) {
                              return;
                            }
                            InventoryCatalogManager.addSubcategory(selectedCategory, newSubCategory);
                            subCategoryController.clear();
                            setState(() {});
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Subcategories for $selectedCategory',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (subCategories.isEmpty)
                      const Text('No subcategories yet.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: subCategories
                            .map(
                              (item) => Chip(
                                label: Text(item),
                                backgroundColor: Theme.of(innerContext).colorScheme.primaryContainer,
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () {
                                  InventoryCatalogManager.removeSubcategory(selectedCategory, item);
                                  setState(() {});
                                },
                              ),
                            )
                            .toList(),
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
