import 'cracker_item.dart';

class InvoiceLineItem {
  InvoiceLineItem({required this.crackerItem, this.quantity = 1}) {
    recalculateTotals();
  }

  final CrackerItem crackerItem;
  int quantity;
  double subtotal = 0.0;
  double taxAmount = 0.0;

  double get taxRate => crackerItem.taxRate;

  void recalculateTotals() {
    subtotal = crackerItem.unitPrice * quantity;
    final taxRate = crackerItem.taxRate;
    taxAmount = taxRate == 0 ? 0 : subtotal * taxRate / (1 + taxRate);
  }

  InvoiceLineItem copyWith({CrackerItem? crackerItem, int? quantity}) {
    final updatedLineItem = InvoiceLineItem(
      crackerItem: crackerItem ?? this.crackerItem,
      quantity: quantity ?? this.quantity,
    );
    return updatedLineItem;
  }

  Map<String, dynamic> toMap() {
    return {
      'crackerItem': crackerItem.toMap(),
      'quantity': quantity,
      'subtotal': subtotal,
      'taxAmount': taxAmount,
    };
  }

  factory InvoiceLineItem.fromMap(Map<String, dynamic> map) {
    final crackerItem = CrackerItem.fromMap(
      Map<String, dynamic>.from(map['crackerItem'] as Map),
    );

    return InvoiceLineItem(
        crackerItem: crackerItem,
        quantity: map['quantity'] as int,
      )
      ..subtotal = (map['subtotal'] as num).toDouble()
      ..taxAmount = (map['taxAmount'] as num).toDouble();
  }
}
