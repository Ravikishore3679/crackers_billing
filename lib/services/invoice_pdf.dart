import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';
import 'pdf_theme.dart';

const _deepOrange = PdfColor.fromInt(0xFFBF360C);
const _orange = PdfColor.fromInt(0xFFF57C00);
const _cream = PdfColor.fromInt(0xFFFFF3E0);
const _ink = PdfColor.fromInt(0xFF212121);
const _muted = PdfColor.fromInt(0xFF757575);

String _money(double value) => '₹${value.toStringAsFixed(2)}';

Future<Uint8List> buildInvoicePdf(Invoice invoice) async {
  final pdf = pw.Document(theme: await loadPdfTheme());
  final customer = invoice.customerName.trim().isEmpty
      ? 'Walk-in Customer'
      : invoice.customerName;
  final roundedNet = (invoice.netTotal / 10).round() * 10.0;
  final roundOff = roundedNet - invoice.netTotal;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => _header(),
      footer: (_) => _footer(),
      build: (context) => [
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _label('BILLED TO'),
                pw.Text(
                  customer,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                if (invoice.customerPhone.isNotEmpty)
                  pw.Text(
                    invoice.customerPhone,
                    style: const pw.TextStyle(color: _muted),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _label('INVOICE'),
                pw.Text(
                  invoice.id,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                pw.Text(
                  invoice.formattedDateTime,
                  style: const pw.TextStyle(color: _muted),
                ),
                if (invoice.createdBy.isNotEmpty)
                  pw.Text(
                    'Billed by ${invoice.createdBy}',
                    style: const pw.TextStyle(color: _muted),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: const ['#', 'Item', 'Qty', 'Rate', 'Amount'],
          data: [
            for (var i = 0; i < invoice.lineItems.length; i++)
              [
                '${i + 1}',
                invoice.lineItems[i].crackerItem.nameWithSubCategory,
                '${invoice.lineItems[i].quantity}',
                _money(invoice.lineItems[i].crackerItem.unitPrice),
                _money(invoice.lineItems[i].subtotal),
              ],
          ],
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          headerDecoration: const pw.BoxDecoration(color: _deepOrange),
          cellStyle: const pw.TextStyle(fontSize: 10, color: _ink),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          oddRowDecoration: const pw.BoxDecoration(color: _cream),
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(36),
            3: const pw.FixedColumnWidth(70),
            4: const pw.FixedColumnWidth(80),
          },
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.center,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 230,
            child: pw.Column(
              children: [
                _totalRow('Gross Total', _money(invoice.grossTotal)),
                _totalRow('GST', _money(invoice.taxTotal)),
                _totalRow('Discount', '-${_money(invoice.discountAmount)}'),
                _totalRow('Net Payable', _money(invoice.netTotal)),
                _totalRow(
                  'Round Off',
                  '${roundOff >= 0 ? '+' : '-'}${_money(roundOff.abs())}',
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _deepOrange,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _money(roundedNet),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            invoice.paymentRecorded
                ? '${invoice.paymentStatusLabel.toUpperCase()}${invoice.paymentBreakdown.isEmpty ? '' : '  -  ${invoice.paymentBreakdown}'}'
                : 'PAYMENT PENDING',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: invoice.isFullyPaid ? PdfColors.green800 : _deepOrange,
            ),
          ),
        ),
      ],
    ),
  );
  return pdf.save();
}

pw.Widget _header() {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: pw.BoxDecoration(
      gradient: const pw.LinearGradient(colors: [_deepOrange, _orange]),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          '*  HAPPY DIWALI  *',
          style: pw.TextStyle(
            color: PdfColors.amber100,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'CRACKERS SALES & INVOICES',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _footer() {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _orange, width: 1.5)),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          'Wishing you and your family a very Happy & Safe Diwali!',
          style: pw.TextStyle(
            color: _deepOrange,
            fontWeight: pw.FontWeight.bold,
            fontSize: 11,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Thank you for shopping with us. Please celebrate safely.',
          style: const pw.TextStyle(color: _muted, fontSize: 9),
        ),
      ],
    ),
  );
}

pw.Widget _label(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 2),
  child: pw.Text(
    text,
    style: pw.TextStyle(
      color: _orange,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 1,
    ),
  ),
);

pw.Widget _totalRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: const pw.TextStyle(color: _muted, fontSize: 10)),
      pw.Text(value, style: const pw.TextStyle(color: _ink, fontSize: 10)),
    ],
  ),
);
