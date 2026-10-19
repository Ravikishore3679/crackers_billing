import 'package:flutter/material.dart';

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    String initial(double value) => value > 0 ? value.toString() : '';
    _cash = TextEditingController(text: initial(widget.invoice.cashPaid));
    _upi = TextEditingController(text: initial(widget.invoice.upiPaid));
    _card = TextEditingController(text: initial(widget.invoice.cardPaid));
  }

  @override
  void dispose() {
    _cash.dispose();
    _upi.dispose();
    _card.dispose();
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0.0;

  double get _entered => _value(_cash) + _value(_upi) + _value(_card);

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

  Widget _field(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixText: '₹ ',
        suffixIcon: TextButton(
          onPressed: () => _fillRemaining(controller),
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
          _field('Cash', _cash),
          const SizedBox(height: 8),
          _field('UPI', _upi),
          const SizedBox(height: 8),
          _field('Card', _card),
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
