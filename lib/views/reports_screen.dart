import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../view_models/sales_view_model.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      value: '₹${viewModel.totalExpenditure.toStringAsFixed(2)}',
                      color: Colors.red,
                      icon: Icons.folder_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.confirmation_number_rounded, size: 18),
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
                          child: Text('No invoices yet. Generate one from the sales screen.'),
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
                                invoice.customerName.isEmpty ? 'Walk-in Customer' : invoice.customerName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${invoice.date.day}/${invoice.date.month}/${invoice.date.year} • ${invoice.lineItems.length} items',
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
                                    style: const TextStyle(fontWeight: FontWeight.bold),
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
