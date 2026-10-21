import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice.dart';

/// Itemised bill that can be captured as a PNG through [boundaryKey].
/// Mirrors the layout of the PDF invoice.
class InvoiceReceiptCard extends StatelessWidget {
  const InvoiceReceiptCard({
    super.key,
    required this.invoice,
    required this.boundaryKey,
  });

  final Invoice invoice;
  final GlobalKey boundaryKey;

  static const _deepOrange = Color(0xFFBF360C);
  static const _orange = Color(0xFFF57C00);
  static const _cream = Color(0xFFFFF3E0);
  static const _ink = Color(0xFF212121);
  static const _muted = Color(0xFF757575);

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final customer = invoice.customerName.trim().isNotEmpty
        ? invoice.customerName
        : 'Walk-in Customer';
    final roundedNet = (invoice.netTotal / 10).floor() * 10.0;
    final roundOff = roundedNet - invoice.netTotal;

    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(14),
        child: DefaultTextStyle(
          style: const TextStyle(color: _ink, fontSize: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_deepOrange, _orange],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Text(
                      '*  HAPPY DIWALI  *',
                      style: TextStyle(
                        color: Color(0xFFFFECB3),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'CRACKERS SALES & INVOICES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('BILLED TO'),
                        Text(
                          customer,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (invoice.customerPhone.isNotEmpty)
                          Text(
                            invoice.customerPhone,
                            style: const TextStyle(color: _muted),
                          ),
                        if (invoice.customerEmail.isNotEmpty)
                          Text(
                            invoice.customerEmail,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        if (invoice.notes.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Note: ${invoice.notes.trim()}',
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _label('INVOICE'),
                      Text(
                        invoice.id,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        invoice.formattedDateTime,
                        style: const TextStyle(color: _muted),
                      ),
                      if (invoice.createdBy.isNotEmpty)
                        Text(
                          'Billed by ${invoice.createdBy}',
                          style: const TextStyle(color: _muted),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                color: _deepOrange,
                child: const Row(
                  children: [
                    Expanded(child: _HeadText('Item')),
                    SizedBox(width: 34, child: _HeadText('Qty', center: true)),
                    SizedBox(
                      width: 74,
                      child: _HeadText('Amount', right: true),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < invoice.lineItems.length; i++)
                Container(
                  color: i.isOdd ? Colors.white : _cream,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          invoice.lineItems[i].crackerItem.nameWithSubCategory,
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${invoice.lineItems[i].quantity}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 74,
                        child: Text(
                          _money(invoice.lineItems[i].subtotal),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _row('Gross Total (incl. GST)', _money(invoice.grossTotal)),
              _row('Discount', '-${_money(invoice.discountAmount)}'),
              _row('Net Payable', _money(invoice.netTotal)),
              _row(
                'Round Off',
                '${roundOff >= 0 ? '+' : '-'}${_money(roundOff.abs())}',
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _deepOrange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _money(roundedNet),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                invoice.paymentRecorded
                    ? '${invoice.paymentStatusLabel.toUpperCase()}${invoice.paymentBreakdown.isEmpty ? '' : ' - ${invoice.paymentBreakdown}'}'
                    : 'PAYMENT PENDING',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: invoice.isFullyPaid
                      ? const Color(0xFF2E7D32)
                      : _deepOrange,
                ),
              ),
              if (invoice.paymentMarkedBy.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Payment marked by ${invoice.paymentMarkedBy}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _orange, width: 1.5)),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Wishing you and your family a very Happy & Safe Diwali!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _deepOrange,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Thank you for shopping with us. Please celebrate safely.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: const TextStyle(
        color: _orange,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _muted)),
        Text(value),
      ],
    ),
  );
}

class _HeadText extends StatelessWidget {
  const _HeadText(this.text, {this.center = false, this.right = false});

  final String text;
  final bool center;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: right
          ? TextAlign.right
          : center
          ? TextAlign.center
          : TextAlign.left,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 11,
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
