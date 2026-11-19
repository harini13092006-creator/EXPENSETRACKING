import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expensetracker/app.dart';

void main() {
  testWidgets('ExpenseTracker UI design system & navigation test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build app and trigger frame
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pumpAndSettle();

    // 1. Verify Home Dashboard components
    expect(find.text('ExpenseTracker'), findsWidgets);
    expect(find.textContaining('Alex 👋'), findsOneWidget);
    expect(find.text('Remaining Budget'), findsOneWidget);
    expect(find.text('Category Spending'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);

    // 2. Verify all 4 navigation destinations exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // 3. Switch to Transactions tab
    await tester.tap(find.byIcon(Icons.receipt_long_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Review & manage your spending'), findsOneWidget);
    expect(find.text('All Activity'), findsOneWidget);

    // 4. Switch to Analytics tab
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Financial Analytics'), findsOneWidget);
    expect(find.text('Spending by Category'), findsOneWidget);

    // 5. Switch to Settings tab
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
  });
}
