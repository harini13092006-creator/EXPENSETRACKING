import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/core/widgets/app_buttons.dart';
import 'package:expensetracker/core/widgets/category_badge.dart';
import 'package:expensetracker/core/widgets/empty_state_widget.dart';
import 'package:expensetracker/core/widgets/summary_card.dart';
import 'package:expensetracker/core/widgets/transaction_tile.dart';

void main() {
  group('UI Design System Reusable Components Tests', () {
    testWidgets('SummaryCard renders balance, income, expense correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              totalBalance: 5400.50,
              totalIncome: 7000.00,
              totalExpense: 1599.50,
              period: 'November 2026',
            ),
          ),
        ),
      );

      expect(find.text('Total Balance'), findsOneWidget);
      expect(find.text(r'$5400.50'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text(r'$7000.00'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text(r'$1599.50'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('TransactionTile displays title, amount with sign, and category icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(
              title: 'Starbucks Coffee',
              subtitle: 'Today • Coffee',
              amount: 5.50,
              isExpense: true,
              category: CategoryCatalog.food,
            ),
          ),
        ),
      );

      expect(find.text('Starbucks Coffee'), findsOneWidget);
      expect(find.text('Today • Coffee'), findsOneWidget);
      expect(find.text(r'-$5.50'), findsOneWidget);
      expect(find.byIcon(CategoryCatalog.food.icon), findsOneWidget);
    });

    testWidgets('CategoryBadge renders in both standard and compact modes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CategoryBadge(category: CategoryCatalog.shopping),
                CategoryBadge(category: CategoryCatalog.housing, isCompact: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Shopping'), findsOneWidget);
      expect(find.byIcon(CategoryCatalog.shopping.icon), findsOneWidget);
      expect(find.byIcon(CategoryCatalog.housing.icon), findsOneWidget);
    });

    testWidgets('PrimaryButton and SecondaryButton trigger onPressed callback', (tester) async {
      bool primaryClicked = false;
      bool secondaryClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PrimaryButton(
                  text: 'Add Expense',
                  onPressed: () => primaryClicked = true,
                ),
                SecondaryButton(
                  text: 'Cancel',
                  onPressed: () => secondaryClicked = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Expense'));
      await tester.pump();
      expect(primaryClicked, isTrue);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(secondaryClicked, isTrue);
    });

    testWidgets('EmptyStateWidget renders icon, title, description and button', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.receipt_long,
              title: 'No Data Found',
              description: 'Try again later',
              actionText: 'Retry',
              onActionPressed: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No Data Found'), findsOneWidget);
      expect(find.text('Try again later'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(actionTapped, isTrue);
    });
  });
}
