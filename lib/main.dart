import 'package:flutter/material.dart';

import 'views/app_shell.dart';

void main() {
  runApp(const CrackersBillingApp());
}

class CrackersBillingApp extends StatelessWidget {
  const CrackersBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crackers Sales & Invoices',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
