import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/sales_view_model.dart';
import 'add_item_screen.dart';
import 'invoice_entry_screen.dart';
import 'reports_screen.dart';
import 'sales_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.point_of_sale),
      selectedIcon: Icon(Icons.point_of_sale_rounded),
      label: 'Sales',
    ),
    NavigationDestination(
      icon: Icon(Icons.add_box_outlined),
      selectedIcon: Icon(Icons.add_box_rounded),
      label: 'Add Item',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_rounded),
      selectedIcon: Icon(Icons.bar_chart_rounded),
      label: 'Reports',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Invoice',
    ),
  ];

  static final List<Widget> _screens = [
    const SalesScreen(),
    const AddItemScreen(),
    const ReportsScreen(),
    const InvoiceEntryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SalesViewModel>(
      create: (_) => SalesViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crackers Sales & Invoices'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: _destinations,
        ),
      ),
    );
  }
}
