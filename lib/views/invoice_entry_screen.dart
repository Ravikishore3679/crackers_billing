import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../services/pdf_theme.dart';
import 'invoice_receipt_card.dart';
import '../view_models/sales_view_model.dart';

class InvoiceEntryScreen extends StatelessWidget {
  const InvoiceEntryScreen({super.key});

  static final GlobalKey _billKey = GlobalKey();

  Future<Uint8List> _buildInvoicePdfBytes(Invoice invoice) async {
    final pdf = pw.Document(theme: await loadPdfTheme());
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
              pw.Text(
                'Date: ${invoice.date.day}/${invoice.date.month}/${invoice.date.year}',
              ),
              pw.Divider(),
              ...invoice.lineItems.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${item.crackerItem.nameWithSubCategory} x ${item.quantity}',
                      ),
                      pw.Text('₹${item.subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
              pw.Divider(),
              pw.Text('Gross Total: ₹${invoice.grossTotal.toStringAsFixed(2)}'),
              pw.Text('GST: ₹${invoice.taxTotal.toStringAsFixed(2)}'),
              pw.Text(
                'Discount: ₹${invoice.discountAmount.toStringAsFixed(2)}',
              ),
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
    final viewModel = context.watch<SalesViewModel>();
    final lastInvoice = viewModel.lastGeneratedInvoice;

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Entry')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: viewModel.customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: viewModel.customerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Cart Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (viewModel.cart.isEmpty)
                        const Text('No items added to the invoice yet.')
                      else
                        ...viewModel.cart.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.crackerItem.nameWithSubCategory,
                                    softWrap: true,
                                  ),
                                ),
                                Text(
                                  '${item.quantity} x ₹${item.crackerItem.unitPrice.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Text('Gross Total')),
                  Text('₹${viewModel.grossTotal.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('GST')),
                  Text('₹${viewModel.taxTotal.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Discount')),
                  Text('₹${viewModel.discountAmount.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Net Payable')),
                  Text(
                    '₹${viewModel.netTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: viewModel.cart.isEmpty
                    ? null
                    : () async {
                        try {
                          final invoice = await viewModel.checkout();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invoice created: ${invoice.id}'),
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
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Generate Invoice'),
              ),
              if (lastInvoice != null) ...[
                const SizedBox(height: 24),
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bill ready for customer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InvoiceReceiptCard(
                          invoice: lastInvoice,
                          boundaryKey: _billKey,
                        ),
                        const SizedBox(height: 16),
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
                                  lastInvoice,
                                ),
                                icon: const Icon(Icons.image_rounded),
                                label: const Text('Share Image'),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: FilledButton.icon(
                                onPressed: () => _printInvoice(lastInvoice),
                                icon: const Icon(Icons.print_rounded),
                                label: const Text('Print'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
