import 'invoice_line_item.dart';

class Invoice {
  Invoice({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.date,
    required List<InvoiceLineItem> lineItems,
    this.discountAmount = 0.0,
    this.cashPaid = 0.0,
    this.upiPaid = 0.0,
    this.cardPaid = 0.0,
    this.paidAt,
  }) : lineItems = List<InvoiceLineItem>.from(lineItems),
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
  double cashPaid;
  double upiPaid;
  double cardPaid;
  DateTime? paidAt;

  double get roundedNetTotal => (netTotal / 10).round() * 10.0;
  double get amountPaid => cashPaid + upiPaid + cardPaid;
  double get balanceDue =>
      (roundedNetTotal - amountPaid).clamp(0.0, double.infinity);
  bool get paymentRecorded => paidAt != null;
  bool get isFullyPaid => paymentRecorded && balanceDue < 0.005;

  String get paymentStatusLabel {
    if (!paymentRecorded) return 'Payment pending';
    return isFullyPaid ? 'Paid' : 'Partially paid';
  }

  String get paymentBreakdown {
    final parts = <String>[
      if (cashPaid > 0) 'Cash ₹${cashPaid.toStringAsFixed(2)}',
      if (upiPaid > 0) 'UPI ₹${upiPaid.toStringAsFixed(2)}',
      if (cardPaid > 0) 'Card ₹${cardPaid.toStringAsFixed(2)}',
    ];
    return parts.join(' • ');
  }

  double get taxTotal =>
      lineItems.fold(0.0, (total, item) => total + item.taxAmount);

  String get formattedDateTime {
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day}/${date.month}/${date.year} $hour12:$minute $period';
  }

  String get invoiceSummaryText {
    final customer = customerName.trim().isNotEmpty
        ? customerName
        : 'Walk-in Customer';
    final lines = <String>[
      'CRACKERS SALES & INVOICES',
      'Invoice: $id',
      'Customer: $customer',
      'Phone: ${customerPhone.isEmpty ? 'Not provided' : customerPhone}',
      'Date: $formattedDateTime',
      '---',
      ...lineItems.map(
        (item) =>
            '${item.crackerItem.nameWithSubCategory} x ${item.quantity} = ₹${item.subtotal.toStringAsFixed(2)}',
      ),
      '---',
      'Gross Total: ₹${grossTotal.toStringAsFixed(2)}',
      'GST: ₹${taxTotal.toStringAsFixed(2)}',
      'Discount: ₹${discountAmount.toStringAsFixed(2)}',
      'Net Payable: ₹${netTotal.toStringAsFixed(2)}',
      'Payment: $paymentStatusLabel${paymentRecorded && paymentBreakdown.isNotEmpty ? ' ($paymentBreakdown)' : ''}',
    ];

    return lines.join('\n');
  }

  void recalculateTotals() {
    grossTotal = lineItems.fold(0.0, (total, item) => total + item.subtotal);

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
    double? cashPaid,
    double? upiPaid,
    double? cardPaid,
    DateTime? paidAt,
  }) {
    final updatedInvoice = Invoice(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      date: date ?? this.date,
      lineItems: lineItems ?? this.lineItems,
      discountAmount: discountAmount ?? this.discountAmount,
      cashPaid: cashPaid ?? this.cashPaid,
      upiPaid: upiPaid ?? this.upiPaid,
      cardPaid: cardPaid ?? this.cardPaid,
      paidAt: paidAt ?? this.paidAt,
    );
    updatedInvoice.recalculateTotals();
    return updatedInvoice;
  }
}
