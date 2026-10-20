import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../services/firestore_service.dart';
import '../services/invoice_pdf.dart';
import '../view_models/sales_view_model.dart';
import 'payment_section.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _pendingOnly = false;

  void _showRevenueBreakdown(List<Invoice> invoices) {
    final cash = invoices.fold(0.0, (t, i) => t + i.cashPaid);
    final upi = invoices.fold(0.0, (t, i) => t + i.upiPaid);
    final card = invoices.fold(0.0, (t, i) => t + i.cardPaid);
    final billed = invoices.fold(0.0, (t, i) => t + i.roundedNetTotal);
    final pending = invoices.fold(0.0, (t, i) => t + i.balanceDue);
    final pendingBills = invoices.where((i) => !i.isFullyPaid).length;
    final collected = cash + upi + card;

    Widget row(IconData icon, String label, double value, Color color) {
      final share = collected > 0 ? value / collected * 100 : 0.0;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${share.toStringAsFixed(1)}% of collected'),
        trailing: Text(
          '₹${value.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Revenue breakdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text('Total billed: ₹${billed.toStringAsFixed(2)}'),
              const Divider(height: 24),
              row(Icons.payments_rounded, 'Cash', cash, Colors.green.shade700),
              row(Icons.qr_code_2_rounded, 'UPI', upi, Colors.indigo),
              row(Icons.credit_card_rounded, 'Card', card, Colors.deepOrange),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total collected',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '₹${collected.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pending ($pendingBills bills)',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                  Text(
                    '₹${pending.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPayment(SalesViewModel viewModel, Invoice invoice) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${invoice.customerName.isEmpty ? 'Walk-in Customer' : invoice.customerName} • ${invoice.id}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(invoice.formattedDateTime),
              if (invoice.createdBy.isNotEmpty)
                Text('Billed by ${invoice.createdBy}'),
              const SizedBox(height: 10),
              PaymentSection(
                key: ValueKey(invoice.id),
                invoice: invoice,
                viewModel: viewModel,
                onSaved: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printInvoice(Invoice invoice) async {
    try {
      final pdfBytes = await buildInvoicePdf(invoice);
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
    final viewModel = context.watch<SalesViewModel>();
    final isOwner = FirestoreService.instance.isWorkspaceOwner;
    final allInvoices = viewModel.invoiceHistory;
    final pendingCount = allInvoices.where((i) => !i.isFullyPaid).length;
    final invoices = _pendingOnly
        ? allInvoices.where((i) => !i.isFullyPaid).toList()
        : allInvoices;

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Reports')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOwner)
                Row(
                  children: [
                    Expanded(
                      child: _FolderSummaryCard(
                        title: 'Revenue',
                        value: '₹${viewModel.totalRevenue.toStringAsFixed(2)}',
                        color: Colors.green,
                        icon: Icons.folder_rounded,
                        onTap: () => _showRevenueBreakdown(allInvoices),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FolderSummaryCard(
                        title: 'Expense',
                        value:
                            '₹${viewModel.totalExpenditure.toStringAsFixed(2)}',
                        color: Colors.red,
                        icon: Icons.folder_rounded,
                      ),
                    ),
                  ],
                ),
              if (isOwner) const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(
                    Icons.confirmation_number_rounded,
                    size: 18,
                  ),
                  label: Text('Units sold: ${viewModel.totalUnitsSold}'),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Recent Invoices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: !_pendingOnly,
                    onSelected: (_) => setState(() => _pendingOnly = false),
                  ),
                  ChoiceChip(
                    label: Text('Pending payment ($pendingCount)'),
                    selected: _pendingOnly,
                    onSelected: (_) => setState(() => _pendingOnly = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: invoices.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _pendingOnly
                                ? 'No pending payments.'
                                : 'No invoices yet. Generate one from the sales screen.',
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: invoices.length,
                        itemBuilder: (context, index) {
                          final invoice = invoices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onTap: () => _openPayment(viewModel, invoice),
                              title: Text(
                                invoice.customerName.isEmpty
                                    ? 'Walk-in Customer'
                                    : invoice.customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${invoice.formattedDateTime} • ${invoice.lineItems.length} items',
                                  ),
                                  const SizedBox(height: 6),
                                  if (invoice.createdBy.isNotEmpty)
                                    Text('Billed by ${invoice.createdBy}'),
                                  Text(
                                    'Invoice: ${invoice.id}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    invoice.paymentBreakdown.isEmpty
                                        ? invoice.paymentStatusLabel
                                        : '${invoice.paymentStatusLabel} • ${invoice.paymentBreakdown}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: invoice.isFullyPaid
                                          ? Colors.green.shade800
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${invoice.netTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: invoice.isFullyPaid
                                        ? 'View payment'
                                        : 'Record payment',
                                    onPressed: () =>
                                        _openPayment(viewModel, invoice),
                                    icon: Icon(
                                      invoice.isFullyPaid
                                          ? Icons.check_circle_rounded
                                          : Icons.payments_rounded,
                                      color: invoice.isFullyPaid
                                          ? Colors.green
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Print invoice',
                                    onPressed: () => _printInvoice(invoice),
                                    icon: const Icon(Icons.print_rounded),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderSummaryCard extends StatelessWidget {
  const _FolderSummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final VoidCallback? onTap;
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 130, maxWidth: 190),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
