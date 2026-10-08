import 'invoice_line_item.dart';

class Invoice {
  Invoice({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.date,
    required List<InvoiceLineItem> lineItems,
    this.discountAmount = 0.0,
  })  : lineItems = List<InvoiceLineItem>.from(lineItems),
        grossTotal = 0.0,
        netTotal = 0.0 {
    recalculateTotals();
  }

  final String id;
  final String customerName;
  final String customerPhone;
  final DateTime date;
  final List<InvoiceLineItem> lineItems;
  double discountAmount;
  double grossTotal;
  double netTotal;

  double get taxTotal => lineItems.fold(
        0.0,
        (total, item) => total + item.taxAmount,
      );

  String get invoiceSummaryText {
    final customer = customerName.trim().isNotEmpty ? customerName : 'Walk-in Customer';
    final lines = <String>[
      'CRACKERS SALES & INVOICES',
      'Invoice: $id',
      'Customer: $customer',
      'Phone: ${customerPhone.isEmpty ? 'Not provided' : customerPhone}',
      'Date: ${date.day}/${date.month}/${date.year}',
      '---',
      ...lineItems.map(
        (item) =>
            '${item.crackerItem.name} x ${item.quantity} = ₹${item.subtotal.toStringAsFixed(2)}',
      ),
      '---',
      'Gross Total: ₹${grossTotal.toStringAsFixed(2)}',
      'GST: ₹${taxTotal.toStringAsFixed(2)}',
      'Discount: ₹${discountAmount.toStringAsFixed(2)}',
      'Net Payable: ₹${netTotal.toStringAsFixed(2)}',
    ];

    return lines.join('\n');
  }

  void recalculateTotals() {
    grossTotal = lineItems.fold(
      0.0,
      (total, item) => total + item.subtotal,
    );

    final safeDiscount = discountAmount.clamp(0.0, grossTotal);
    netTotal = grossTotal + taxTotal - safeDiscount;
    if (netTotal < 0) {
      netTotal = 0.0;
    }
  }

  Invoice copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    DateTime? date,
    List<InvoiceLineItem>? lineItems,
    double? discountAmount,
  }) {
    final updatedInvoice = Invoice(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      date: date ?? this.date,
      lineItems: lineItems ?? this.lineItems,
      discountAmount: discountAmount ?? this.discountAmount,
    );
    updatedInvoice.recalculateTotals();
    return updatedInvoice;
  }
}
