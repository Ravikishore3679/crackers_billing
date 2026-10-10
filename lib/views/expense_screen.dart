import 'package:flutter/material.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = [
      _ExpenseEntry(title: 'Raw materials', amount: 1840.00, icon: Icons.inventory_2_rounded),
      _ExpenseEntry(title: 'Packaging', amount: 620.00, icon: Icons.local_shipping_rounded),
      _ExpenseEntry(title: 'Transport', amount: 450.00, icon: Icons.local_shipping_rounded),
      _ExpenseEntry(title: 'Staff wages', amount: 980.00, icon: Icons.people_rounded),
    ];
    final isCompact = MediaQuery.sizeOf(context).width < 420;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.55),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 10 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isCompact ? 14 : 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.attach_money_rounded, color: Colors.red, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expense Overview',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Track operating costs and expenses',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: isCompact ? 8 : 12,
                runSpacing: isCompact ? 8 : 12,
                children: [
                  _ExpenseStatCard(title: 'This month', value: '₹4,890.00', color: Colors.red),
                  _ExpenseStatCard(title: 'Daily avg', value: '₹163.00', color: Colors.orange),
                  _ExpenseStatCard(title: 'Pending', value: '₹920.00', color: Colors.blue),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Expense categories',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: expenses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Container(
                      padding: EdgeInsets.all(isCompact ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(expense.icon, color: Colors.red),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              expense.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ),
                          Text(
                            '₹${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseStatCard extends StatelessWidget {
  const _ExpenseStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ExpenseEntry {
  const _ExpenseEntry({
    required this.title,
    required this.amount,
    required this.icon,
  });

  final String title;
  final double amount;
  final IconData icon;
}
