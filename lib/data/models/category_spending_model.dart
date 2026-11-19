import 'package:expensetracker/core/constants/category_constants.dart';

/// Represents spending breakdown for a specific category.
class CategorySpendingModel {
  final CategoryItem category;
  final double amount;
  final double percentage; // Value between 0.0 and 1.0 (e.g. 0.25 = 25%)
  final bool usesCategoryBudget;

  const CategorySpendingModel({
    required this.category,
    required this.amount,
    required this.percentage,
    this.usesCategoryBudget = false,
  });

  double get percentageDisplay => percentage * 100;
  String get percentageBasis =>
      usesCategoryBudget ? 'of category budget' : 'of total expenses';
}
