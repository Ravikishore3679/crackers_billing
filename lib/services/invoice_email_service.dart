import 'package:flutter/foundation.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:printing/printing.dart';

import '../models/invoice.dart';
import 'invoice_pdf.dart';

Future<bool> composeInvoiceEmail(Invoice invoice) async {
  final recipient = invoice.customerEmail.trim();
  if (!recipient.contains('@')) {
    throw StateError(
      'Enter a valid customer email before emailing the invoice.',
    );
  }

  final pdfBytes = await buildInvoicePdf(invoice);
  if (kIsWeb) {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'invoice_${invoice.id}.pdf',
    );
    return false;
  }

  await FlutterEmailSender.send(
    Email(
      recipients: [recipient],
      subject: 'Invoice ${invoice.id}',
      body:
          'Hello ${invoice.customerName},\n\nPlease find your invoice attached.',
      attachments: [
        EmailAttachment.data(
          pdfBytes,
          fileName: 'invoice_${invoice.id}.pdf',
          mimeType: 'application/pdf',
        ),
      ],
    ),
  );
  return true;
}
