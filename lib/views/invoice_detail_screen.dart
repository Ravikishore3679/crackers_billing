import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/invoice.dart';
import '../services/invoice_email_service.dart';
import '../services/invoice_pdf.dart';
import '../view_models/sales_view_model.dart';
import 'invoice_receipt_card.dart';
import 'payment_section.dart';

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
    required this.viewModel,
  });

  final Invoice invoice;
  final SalesViewModel viewModel;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final GlobalKey _receiptKey = GlobalKey();

  Future<void> _printInvoice() async {
    try {
      final pdfBytes = await buildInvoicePdf(widget.invoice);
      await Printing.layoutPdf(
        name: 'invoice_${widget.invoice.id}.pdf',
        onLayout: (_) async => pdfBytes,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not print invoice: $error')),
      );
    }
  }

  Future<void> _emailInvoice() async {
    try {
      final composerOpened = await composeInvoiceEmail(widget.invoice);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            composerOpened
                ? 'Email composer opened.'
                : 'Invoice PDF ready to attach to an email.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open email: $error')));
    }
  }

  Future<void> _shareImage() async {
    await shareInvoiceImage(context, _receiptKey, widget.invoice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Invoice ${widget.invoice.id}')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.viewModel,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: InvoiceReceiptCard(
                    invoice: widget.invoice,
                    boundaryKey: _receiptKey,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _printInvoice,
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.invoice.customerEmail.trim().isEmpty
                        ? null
                        : _emailInvoice,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _shareImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Share image'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PaymentSection(
                key: ValueKey(widget.invoice.id),
                invoice: widget.invoice,
                viewModel: widget.viewModel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
