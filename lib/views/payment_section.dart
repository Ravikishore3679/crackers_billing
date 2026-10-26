import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/invoice.dart';
import '../view_models/sales_view_model.dart';

class PaymentSection extends StatefulWidget {
  const PaymentSection({
    super.key,
    required this.invoice,
    required this.viewModel,
    this.onSaved,
  });

  final Invoice invoice;
  final SalesViewModel viewModel;
  final VoidCallback? onSaved;

  @override
  State<PaymentSection> createState() => PaymentSectionState();
}

class PaymentSectionState extends State<PaymentSection> {
  late final TextEditingController _cash;
  late final TextEditingController _upi;
  late final TextEditingController _card;
  late final TextEditingController _discountValue;
  late final TextEditingController _discountPercent;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    String initial(double value) => value > 0 ? value.toString() : '';
    _cash = TextEditingController(text: initial(widget.invoice.cashPaid));
    _upi = TextEditingController(text: initial(widget.invoice.upiPaid));
    _card = TextEditingController(text: initial(widget.invoice.cardPaid));
    _discountValue = TextEditingController(
      text: initial(widget.invoice.discountAmount),
    );
    _discountPercent = TextEditingController();
  }

  @override
  void dispose() {
    _cash.dispose();
    _upi.dispose();
    _card.dispose();
    _discountValue.dispose();
    _discountPercent.dispose();
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0.0;

  double get _entered => _value(_cash) + _value(_upi) + _value(_card);

  void _applyDiscountValue(String value) {
    _discountPercent.clear();
    widget.viewModel.updateInvoiceDiscount(
      widget.invoice,
      double.tryParse(value.trim()) ?? 0.0,
    );
    setState(() {});
  }

  void _applyDiscountPercent(String value) {
    _discountValue.clear();
    final percent = (int.tryParse(value.trim()) ?? 0).clamp(0, 100);
    widget.viewModel.updateInvoiceDiscount(
      widget.invoice,
      widget.invoice.grossTotal * percent / 100.0,
    );
    setState(() {});
  }

  void _fillRemaining(TextEditingController controller) {
    final others = _entered - _value(controller);
    final remaining = widget.invoice.roundedNetTotal - others;
    controller.text = remaining > 0 ? remaining.toStringAsFixed(2) : '';
    setState(() {});
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final payable = widget.invoice.roundedNetTotal;
    var cash = _value(_cash);
    final upi = _value(_upi);
    final card = _value(_card);

    final excess = cash + upi + card - payable;
    if (excess > 0) {
      if (excess > cash) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('UPI/Card amounts cannot exceed the bill total.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      cash -= excess;
    }

    setState(() => _saving = true);
    try {
      await widget.viewModel.recordPayment(
        widget.invoice,
        cash: cash,
        upi: upi,
        card: card,
      );
      widget.onSaved?.call();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            widget.invoice.isFullyPaid
                ? 'Payment recorded. Bill marked as Paid.'
                : 'Part payment recorded. Balance ₹${widget.invoice.balanceDue.toStringAsFixed(2)}',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixText: '₹ ',
        suffixIcon: TextButton(
          onPressed: enabled ? () => _fillRemaining(controller) : null,
          child: const Text('Full'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final payable = invoice.roundedNetTotal;
    final entered = _entered;
    final balance = payable - entered;
    final recorded = invoice.paymentRecorded;
    final locked = invoice.isFullyPaid;
    final statusColor = !recorded
        ? Colors.orange.shade800
        : invoice.isFullyPaid
        ? Colors.green.shade800
        : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Step 2: Record payment',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  invoice.paymentStatusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text('Amount to collect: ₹${payable.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountValue,
                  enabled: !recorded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Discount value',
                    isDense: true,
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _applyDiscountValue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _discountPercent,
                  enabled: !recorded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Discount percent',
                    isDense: true,
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _applyDiscountPercent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _field('Cash', _cash, enabled: !locked),
          const SizedBox(height: 8),
          _field('UPI', _upi, enabled: !locked),
          const SizedBox(height: 8),
          _field('Card', _card, enabled: !locked),
          const SizedBox(height: 8),
          Text(
            balance > 0.005
                ? 'Balance due: ₹${balance.toStringAsFixed(2)}'
                : balance < -0.005
                ? 'Change to return: ₹${(-balance).toStringAsFixed(2)}'
                : 'Fully covered',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: balance > 0.005
                  ? Colors.red.shade700
                  : Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 10),
          if (locked)
            Text(
              'Payment completed. This bill can no longer be edited.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.green.shade800,
              ),
            )
          else
            FilledButton.icon(
              onPressed: _saving || entered <= 0 ? null : _save,
              icon: const Icon(Icons.payments_rounded),
              label: Text(recorded ? 'Update Payment' : 'Confirm Payment'),
            ),
        ],
      ),
    );
  }
}
