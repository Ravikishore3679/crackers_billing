import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/sales_view_model.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SalesViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 300,
                      child: _StatCard(
                        title: 'Revenue',
                        value: '₹${viewModel.totalRevenue.toStringAsFixed(2)}',
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: _StatCard(
                        title: 'Units Sold',
                        value: '${viewModel.totalUnitsSold}',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Recent Invoices',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (viewModel.invoiceHistory.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No invoices yet. Generate one from the sales screen.'),
                    ),
                  )
                else
                  ...viewModel.invoiceHistory.map(
                    (invoice) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          invoice.customerName.isEmpty ? 'Walk-in Customer' : invoice.customerName,
                        ),
                        subtitle: Text(
                          '${invoice.date.day}/${invoice.date.month}/${invoice.date.year} • ${invoice.lineItems.length} items',
                        ),
                        trailing: Text(
                          '₹${invoice.netTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
