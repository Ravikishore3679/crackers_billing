import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../services/firestore_service.dart';
import '../services/invoice_pdf.dart';
import '../view_models/sales_view_model.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
              const SizedBox(height: 12),
              Expanded(
                child: viewModel.invoiceHistory.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No invoices yet. Generate one from the sales screen.',
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: viewModel.invoiceHistory.length,
                        itemBuilder: (context, index) {
                          final invoice = viewModel.invoiceHistory[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
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
                                  Text(
                                    'Invoice: ${invoice.id}',
                                    style: const TextStyle(fontSize: 12),
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
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
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
    );
  }
}
