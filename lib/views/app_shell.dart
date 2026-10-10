import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/inventory_code_generator.dart';
import '../view_models/sales_view_model.dart';
import 'expense_screen.dart';
import 'inventory_screen.dart';
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
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2_rounded),
      label: 'Inventory',
    ),
    NavigationDestination(
      icon: Icon(Icons.attach_money_rounded),
      selectedIcon: Icon(Icons.attach_money_rounded),
      label: 'Expense',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_rounded),
      selectedIcon: Icon(Icons.bar_chart_rounded),
      label: 'Reports',
    ),
  ];

  static final List<Widget> _screens = [
    const SalesScreen(),
    const InventoryScreen(),
    const ExpenseScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SalesViewModel>(
      create: (_) {
        final viewModel = SalesViewModel();
        InventoryCatalogManager.loadFromFirestore();
        return viewModel;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crackers Sales & Invoices'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
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
