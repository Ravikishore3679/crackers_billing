import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  static const String _storageKey = 'expense_entries_v1';
  StreamSubscription<User?>? _authSubscription;

  List<_ExpenseEntry> _entries = <_ExpenseEntry>[];

  static String _storageKeyForUser(String? uid) =>
      '${_storageKey}_${uid ?? 'anonymous'}';

  String? _currentUserId() {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    if (Firebase.apps.isNotEmpty) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        if (!mounted) {
          return;
        }
        _loadEntries();
      });
    }
    _loadEntries();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    if (Firebase.apps.isNotEmpty) {
      final uid = _currentUserId();
      if (uid != null) {
        final storedEntries = await FirestoreService.instance
            .fetchExpenseEntries(userId: uid);
        final loadedEntries = storedEntries
            .map((entry) => _ExpenseEntry.fromJson(entry))
            .toList();

        if (!mounted) {
          return;
        }

        setState(() {
          _entries = loadedEntries;
        });
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final rawEntries = prefs.getString(_storageKeyForUser(_currentUserId()));

    if (rawEntries == null || rawEntries.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = <_ExpenseEntry>[];
      });
      return;
    }

    try {
      final decoded = jsonDecode(rawEntries) as List<dynamic>;
      final loadedEntries = decoded
          .map((entry) => _ExpenseEntry.fromJson(entry as Map<String, dynamic>))
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = loadedEntries;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = <_ExpenseEntry>[];
      });
    }
  }

  Future<void> _saveEntries() async {
    if (Firebase.apps.isNotEmpty) {
      final uid = _currentUserId();
      if (uid != null) {
        await FirestoreService.instance.saveExpenseEntries(
          _entries.map((entry) => entry.toJson()).toList(),
          userId: uid,
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      _entries.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString(_storageKeyForUser(_currentUserId()), payload);
  }

  double get totalExpenditure =>
      _entries.fold(0.0, (sum, entry) => sum + entry.amount);

  double get monthExpenditure {
    final now = DateTime.now();
    return _entries
        .where((entry) {
          final date = entry.date ?? DateTime.now();
          return date.year == now.year && date.month == now.month;
        })
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  List<MapEntry<String, List<_ExpenseEntry>>> get groupedEntries {
    final grouped = <String, List<_ExpenseEntry>>{};
    for (final entry
        in _entries.toList()..sort(
          (a, b) =>
              (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()),
        )) {
      final key = _formatDate(entry.date ?? DateTime.now());
      grouped.putIfAbsent(key, () => <_ExpenseEntry>[]).add(entry);
    }
    return grouped.entries.toList();
  }

  void _deleteExpense(_ExpenseEntry expense) {
    setState(() {
      _entries.remove(expense);
    });
    _saveEntries();
  }

  void _showAddExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(_formatDate(selectedDate)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (title.isEmpty || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid title and amount.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _entries.insert(
                        0,
                        _ExpenseEntry(
                          title: title,
                          amount: amount,
                          date: selectedDate,
                          icon: _defaultExpenseIcon(title),
                        ),
                      );
                    });
                    _saveEntries();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save expense'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _defaultExpenseIcon(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('transport') || normalized.contains('delivery')) {
      return Icons.local_shipping_rounded;
    }
    if (normalized.contains('pack')) {
      return Icons.inventory_2_rounded;
    }
    if (normalized.contains('staff') ||
        normalized.contains('salary') ||
        normalized.contains('wage')) {
      return Icons.people_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  String _formatDate(DateTime? date) {
    final value = date ?? DateTime.now();
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year;
    return '$day/$month/$year';
  }

  static DateTime? _parseDate(dynamic rawValue) {
    if (rawValue == null || rawValue.toString().isEmpty) {
      return null;
    }
    final seconds = int.tryParse(rawValue.toString());
    if (seconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;
    final grouped = groupedEntries;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.55),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 10 : 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
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
                        padding: EdgeInsets.all(isCompact ? 8 : 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.attach_money_rounded,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Track operating costs and expenses',
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Row(
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _ExpenseStatCard(
                            title: 'Total expenditure',
                            value: '₹${totalExpenditure.toStringAsFixed(2)}',
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: cardWidth,
                          child: _ExpenseStatCard(
                            title: 'This month',
                            value: '₹${monthExpenditure.toStringAsFixed(2)}',
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Expenses by date',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showAddExpenseDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add expense'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...grouped.map((group) {
                  final dateLabel = group.key;
                  final dayTotal = group.value.fold<double>(
                    0.0,
                    (sum, item) => sum + item.amount,
                  );
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              dateLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '₹${dayTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...group.value.map((expense) {
                          return Dismissible(
                            key: ValueKey('${expense.title}_${expense.amount}_${expense.date?.millisecondsSinceEpoch ?? 0}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete_forever_rounded,
                                color: Colors.red,
                              ),
                            ),
                            onDismissed: (_) => _deleteExpense(expense),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      expense.icon,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      expense.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${expense.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _deleteExpense(expense),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    label: const Text('Remove'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
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
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 190),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
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
    required this.date,
    required this.icon,
  });

  final String title;
  final double amount;
  final DateTime? date;
  final IconData icon;

  factory _ExpenseEntry.fromJson(Map<String, dynamic> json) {
    final parsedDate = _ExpenseScreenState._parseDate(json['date']);
    return _ExpenseEntry(
      title: json['title'] as String? ?? 'Expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: parsedDate ?? DateTime.now(),
      icon: _iconFromCode(json['icon'] as String? ?? 'receipt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'date': (date ?? DateTime.now()).millisecondsSinceEpoch,
      'icon': _iconCode(icon),
    };
  }

  static IconData _iconFromCode(String code) {
    switch (code) {
      case 'inventory':
        return Icons.inventory_2_rounded;
      case 'shipping':
        return Icons.local_shipping_rounded;
      case 'people':
        return Icons.people_rounded;
      case 'receipt':
      default:
        return Icons.receipt_long_rounded;
    }
  }

  static String _iconCode(IconData icon) {
    if (icon == Icons.inventory_2_rounded) return 'inventory';
    if (icon == Icons.local_shipping_rounded) return 'shipping';
    if (icon == Icons.people_rounded) return 'people';
    return 'receipt';
  }
}
