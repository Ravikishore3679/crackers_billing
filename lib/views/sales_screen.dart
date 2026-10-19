import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/cracker_item.dart';
import '../models/invoice.dart';
import '../services/invoice_pdf.dart';
import '../view_models/sales_view_model.dart';
import 'invoice_receipt_card.dart';

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
  final Set<String> _expandedCategories = <String>{};

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
            final itemCode = (item.itemCode ?? '').toLowerCase();
            return itemName.contains(query) || itemCode.contains(query);
          }).toList();
    final isSearching = query.isNotEmpty;

    final groupedItems = <String, List<CrackerItem>>{};
    if (!isSearching) {
      for (final item in filteredItems) {
        final category = item.category.trim().isEmpty
            ? 'Uncategorized'
            : item.category.trim();
        groupedItems.putIfAbsent(category, () => <CrackerItem>[]).add(item);
      }
    }

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
                            builder: (_) =>
                                CartScreen(viewModel: widget.viewModel),
                          ),
                        ),
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 18,
                        ),
                        label: Text(
                          widget.viewModel.heldCarts.isEmpty
                              ? 'Cart (${widget.viewModel.cart.length})'
                              : 'Cart (${widget.viewModel.cart.length}) • Hold ${widget.viewModel.heldCarts.length}',
                        ),
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
                hintText: 'Search by item name or code',
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
            if (widget.viewModel.errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  widget.viewModel.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
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
                child: isSearching
                    ? ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ProductCard(
                              item: item,
                              viewModel: widget.viewModel,
                              onAddedToCart: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                          );
                        },
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in groupedItems.entries) ...[
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (_expandedCategories.contains(
                                      entry.key,
                                    )) {
                                      _expandedCategories.remove(entry.key);
                                    } else {
                                      _expandedCategories.add(entry.key);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    bottom: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _expandedCategories.contains(entry.key)
                                            ? Icons.expand_more_rounded
                                            : Icons.chevron_right_rounded,
                                        size: 20,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        '${entry.value.length}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_expandedCategories.contains(entry.key))
                                for (final item in entry.value)
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
                tooltip: 'Hold current cart',
                onPressed: viewModel.cart.isEmpty
                    ? null
                    : () {
                        viewModel.holdCurrentCart();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Current cart moved to hold.'),
                          ),
                        );
                      },
                icon: const Icon(Icons.pause_circle_outline_rounded),
              ),
              IconButton(
                tooltip: 'Close cart',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          body: SafeArea(child: _CartPanel(viewModel: viewModel)),
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

  void _showAddedToast(BuildContext context, int quantity) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),
          backgroundColor: Colors.green.shade700,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$quantity × ${item.nameWithSubCategory} added to cart',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = item.stockAvailable > 0;
    final cartQuantity = viewModel.cart
        .where((line) => line.crackerItem.id == item.id)
        .fold<int>(0, (total, line) => total + line.quantity);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: canAdd ? Colors.orange.shade700 : Colors.grey.shade400,
              width: 4,
            ),
          ),
        ),
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
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.stockAvailable > 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${item.stockAvailable} in stock',
                        style: TextStyle(
                          color: item.stockAvailable > 0
                              ? Colors.green
                              : Colors.red,
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
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canAdd)
                      for (final n in const [2, 5])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              try {
                                viewModel.updateQuantity(
                                  item.id,
                                  cartQuantity + n,
                                );
                                _showAddedToast(context, n);
                                onAddedToCart?.call();
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '+$n',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                    InkWell(
                      onTap: canAdd
                          ? () {
                              try {
                                viewModel.addToCart(item);
                                _showAddedToast(context, 1);
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: canAdd
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ADD',
                          style: TextStyle(
                            color: canAdd
                                ? Theme.of(context).colorScheme.onPrimary
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (cartQuantity > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            try {
                              viewModel.updateQuantity(
                                item.id,
                                cartQuantity - 1,
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$cartQuantity',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            try {
                              viewModel.updateQuantity(
                                item.id,
                                cartQuantity + 1,
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
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.grey.shade700,
                              size: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  static final GlobalKey _billKey = GlobalKey();

  Future<void> _printInvoice(Invoice invoice) async {
    try {
      final pdfBytes = await buildInvoicePdf(invoice);

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
              if (viewModel.heldCarts.isNotEmpty) ...[
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
                      Text(
                        'Held Bills (${viewModel.heldCarts.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...viewModel.heldCarts.map(
                        (draft) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  draft.customerName.isEmpty
                                      ? 'Walk-in Customer'
                                      : draft.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${draft.totalQuantity} items • ₹${draft.grossTotal.toStringAsFixed(2)} • ${draft.discountPercent.toStringAsFixed(2)}% discount',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    FilledButton.tonal(
                                      onPressed: () {
                                        viewModel.resumeHeldCart(draft.id);
                                      },
                                      child: const Text('Resume'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () {
                                        viewModel.discardHeldCart(draft.id);
                                      },
                                      child: const Text('Discard'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (viewModel.cart.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('No items in cart yet.')),
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
                          SizedBox(
                            width: 50,
                            child: Text(
                              'Qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              'Amount',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
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
                                      line.crackerItem.nameWithSubCategory,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₹${line.crackerItem.unitPrice.toStringAsFixed(2)} each',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
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
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Text(
                                        '${line.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        try {
                                          viewModel.updateQuantity(
                                            line.crackerItem.id,
                                            line.quantity + 1,
                                          );
                                        } catch (error) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
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
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    viewModel.removeFromCart(line.crackerItem),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
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
                        const Expanded(child: Text('Discount (%)')),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            key: ValueKey(viewModel.cart.length),
                            initialValue: viewModel.discountPercent == 0
                                ? ''
                                : viewModel.discountPercent.toString(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              hintText: '0',
                              suffixText: '%',
                            ),
                            onChanged: (value) {
                              final parsedValue = double.tryParse(value) ?? 0.0;
                              viewModel.applyDiscount(parsedValue);
                            },
                            onFieldSubmitted: (value) {
                              final parsedValue = double.tryParse(value) ?? 0.0;
                              viewModel.applyDiscount(parsedValue);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(label: 'Gross', value: viewModel.grossTotal),
                    _SummaryRow(label: 'GST Tax', value: viewModel.taxTotal),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount'),
                        Text(
                          '${viewModel.discountPercent.toStringAsFixed(2)}% (₹${viewModel.discountAmount.toStringAsFixed(2)})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Net Payable',
                      value: viewModel.netTotal,
                      isTotal: true,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Round Off (to ₹10)'),
                        Text(
                          '${viewModel.roundOffAmount >= 0 ? '+' : '-'}₹${viewModel.roundOffAmount.abs().toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _SummaryRow(
                      label: 'Rounded Payable',
                      value: viewModel.roundedNetTotal,
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
                      InvoiceReceiptCard(
                        invoice: viewModel.lastGeneratedInvoice!,
                        boundaryKey: _billKey,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 140,
                            child: OutlinedButton.icon(
                              onPressed: () => shareInvoiceImage(
                                context,
                                _billKey,
                                viewModel.lastGeneratedInvoice!,
                              ),
                              icon: const Icon(Icons.image_rounded),
                              label: const Text('Share Image'),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: FilledButton.icon(
                              onPressed: () => _printInvoice(
                                viewModel.lastGeneratedInvoice!,
                              ),
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
