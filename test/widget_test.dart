import 'package:crackers_billing/views/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sales screen renders the catalog and app header', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    expect(find.text('Crackers Sales & Invoices'), findsOneWidget);
    expect(find.text('Available Crackers'), findsOneWidget);
  });
}
