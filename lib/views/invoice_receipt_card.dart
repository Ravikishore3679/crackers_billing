import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice.dart';

/// Itemised bill that can be captured as a PNG through [boundaryKey].
class InvoiceReceiptCard extends StatelessWidget {
  const InvoiceReceiptCard({
    super.key,
    required this.invoice,
    required this.boundaryKey,
  });

  final Invoice invoice;
  final GlobalKey boundaryKey;

  static const _ink = Color(0xFF212121);

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final customer = invoice.customerName.trim().isNotEmpty
        ? invoice.customerName
        : 'Walk-in Customer';
    final date = invoice.date;
    final roundedNet = (invoice.netTotal / 10).round() * 10.0;
    final roundOff = roundedNet - invoice.netTotal;

    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: const TextStyle(color: _ink, fontSize: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CRACKERS SALES & INVOICES',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text('Invoice: ${invoice.id}'),
              Text('Customer: $customer'),
              if (invoice.customerPhone.isNotEmpty)
                Text('Phone: ${invoice.customerPhone}'),
              Text('Date: ${date.day}/${date.month}/${date.year}'),
              const Divider(height: 20, color: _ink),
              for (final line in invoice.lineItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${line.crackerItem.nameWithSubCategory} x ${line.quantity}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _money(line.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20, color: _ink),
              _row('Gross Total', _money(invoice.grossTotal)),
              _row('GST', _money(invoice.taxTotal)),
              _row('Discount', '-${_money(invoice.discountAmount)}'),
              _row('Net Payable', _money(invoice.netTotal), bold: true),
              _row(
                'Round Off',
                '${roundOff >= 0 ? '+' : '-'}${_money(roundOff.abs())}',
              ),
              const Divider(height: 20, color: _ink),
              _row('TOTAL', _money(roundedNet), bold: true, large: true),
              const SizedBox(height: 8),
              const Text(
                'Thank you! Visit again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    bool large = false,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: large ? 16 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

Future<Uint8List?> captureBoundaryPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 3.0,
}) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}

Future<void> shareInvoiceImage(
  BuildContext context,
  GlobalKey boundaryKey,
  Invoice invoice,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await captureBoundaryPng(boundaryKey);
    if (bytes == null) throw StateError('Bill is not ready to capture.');
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'invoice_${invoice.id}.png',
          ),
        ],
        fileNameOverrides: ['invoice_${invoice.id}.png'],
        subject: 'Crackers Invoice ${invoice.id}',
      ),
    );
  } catch (error) {
    debugPrint('Failed to share invoice image: $error');
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Could not share bill image.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
