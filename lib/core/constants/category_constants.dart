import 'package:flutter/material.dart';

/// Predefined category model for visual consistency across badges, transaction tiles, and analytics.
class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final bool isExpense;
  final double monthlyBudget;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.isExpense = true,
    this.monthlyBudget = 0,
  });
}

/// Central catalog of standard categories and their visual representations.
class CategoryCatalog {
  CategoryCatalog._();

  /// Resolves Firestore icon IDs through bundled constant Material icons so
  /// release builds can tree-shake the icon font safely.
  static IconData iconForCodePoint(int codePoint) {
    const supported = <IconData>[
      Icons.restaurant,
      Icons.receipt_long,
      Icons.shopping_bag,
      Icons.directions_car,
      Icons.medical_services,
      Icons.movie,
      Icons.school,
      Icons.flight,
      Icons.category,
      Icons.home,
      Icons.pets,
      Icons.sports,
      Icons.work,
      Icons.payments,
      Icons.restaurant_rounded,
      Icons.directions_car_rounded,
      Icons.shopping_bag_rounded,
      Icons.movie_filter_rounded,
      Icons.medical_services_rounded,
      Icons.school_rounded,
      Icons.receipt_long_rounded,
      Icons.flight_takeoff_rounded,
      Icons.more_horiz_rounded,
      Icons.account_balance_wallet_rounded,
    ];
    for (final icon in supported) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.category;
  }

  // ================= EXPENSE CATEGORIES =================

  // 1. Food
  static const CategoryItem food = CategoryItem(
    id: 'food',
    name: 'Food',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFF97316),
    backgroundColor: Color(0xFFFFF7ED),
  );

  // 2. Transport
  static const CategoryItem transport = CategoryItem(
    id: 'transport',
    name: 'Transport',
    icon: Icons.directions_car_rounded,
    color: Color(0xFF0284C7),
    backgroundColor: Color(0xFFF0F9FF),
  );

  // 3. Shopping
  static const CategoryItem shopping = CategoryItem(
    id: 'shopping',
    name: 'Shopping',
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFF8B5CF6),
    backgroundColor: Color(0xFFF5F3FF),
  );

  // 4. Entertainment
  static const CategoryItem entertainment = CategoryItem(
    id: 'entertainment',
    name: 'Entertainment',
    icon: Icons.movie_filter_rounded,
    color: Color(0xFFEC4899),
    backgroundColor: Color(0xFFFDF2F8),
  );

  // 5. Healthcare
  static const CategoryItem healthcare = CategoryItem(
    id: 'healthcare',
    name: 'Healthcare',
    icon: Icons.medical_services_rounded,
    color: Color(0xFFEF4444),
    backgroundColor: Color(0xFFFEF2F2),
  );

  // 6. Education
  static const CategoryItem education = CategoryItem(
    id: 'education',
    name: 'Education',
    icon: Icons.school_rounded,
    color: Color(0xFF0D9488),
    backgroundColor: Color(0xFFF0FDFA),
  );

  // 7. Bills
  static const CategoryItem bills = CategoryItem(
    id: 'bills',
    name: 'Bills',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFFEAB308),
    backgroundColor: Color(0xFFFEFCE8),
  );

  // 8. Travel
  static const CategoryItem travel = CategoryItem(
    id: 'travel',
    name: 'Travel',
    icon: Icons.flight_takeoff_rounded,
    color: Color(0xFF06B6D4),
    backgroundColor: Color(0xFFECFEFF),
  );

  static const CategoryItem home = CategoryItem(
    id: 'home',
    name: 'Home',
    icon: Icons.home_rounded,
    color: Color(0xFF0D9488),
    backgroundColor: Color(0xFFF0FDFA),
  );

  // 9. Other (Expense)
  static const CategoryItem other = CategoryItem(
    id: 'other',
    name: 'Other',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF64748B),
    backgroundColor: Color(0xFFF8FAFC),
  );

  // ================= INCOME CATEGORIES =================

  // 1. Salary
  static const CategoryItem salary = CategoryItem(
    id: 'salary',
    name: 'Salary',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF2EAD73),
    backgroundColor: Color(0xFFE8F8F1),
    isExpense: false,
  );

  // 2. Freelance
  static const CategoryItem freelance = CategoryItem(
    id: 'freelance',
    name: 'Freelance',
    icon: Icons.laptop_chromebook_rounded,
    color: Color(0xFF2563EB),
    backgroundColor: Color(0xFFEFF6FF),
    isExpense: false,
  );

  // 3. Business
  static const CategoryItem business = CategoryItem(
    id: 'business',
    name: 'Business',
    icon: Icons.store_rounded,
    color: Color(0xFF0EA5E9),
    backgroundColor: Color(0xFFF0F9FF),
    isExpense: false,
  );

  // 4. Investment
  static const CategoryItem investment = CategoryItem(
    id: 'investment',
    name: 'Investment',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF059669),
    backgroundColor: Color(0xFFECFDF5),
    isExpense: false,
  );

  // 5. Gift
  static const CategoryItem gift = CategoryItem(
    id: 'gift',
    name: 'Gift',
    icon: Icons.card_giftcard_rounded,
    color: Color(0xFFA855F7),
    backgroundColor: Color(0xFFFAF5FF),
    isExpense: false,
  );

  // 6. Other (Income)
  static const CategoryItem incomeOther = CategoryItem(
    id: 'income_other',
    name: 'Other',
    icon: Icons.attach_money_rounded,
    color: Color(0xFF10B981),
    backgroundColor: Color(0xFFECFDF5),
    isExpense: false,
  );

  // Aliases for backwards compatibility
  static CategoryItem get housing => bills;
  static CategoryItem get health => healthcare;

  /// All 9 required expense categories
  static List<CategoryItem> get expenseCategories => [
    food,
    transport,
    shopping,
    bills,
    entertainment,
    CategoryItem(
      id: healthcare.id,
      name: 'Health',
      icon: healthcare.icon,
      color: healthcare.color,
      backgroundColor: healthcare.backgroundColor,
    ),
    home,
    education,
    other,
  ];

  /// All 6 required income categories
  static List<CategoryItem> get incomeCategories => [
    salary,
    freelance,
    business,
    investment,
    gift,
    incomeOther,
  ];

  /// Combined catalog
  static List<CategoryItem> get allCategories => [
    ...incomeCategories,
    ...expenseCategories,
  ];

  static CategoryItem findById(String id) {
    if (id == 'health') {
      return expenseCategories.firstWhere(
        (category) => category.id == healthcare.id,
      );
    }
    if (id == 'travel') return travel;
    if (id == 'housing') return bills;

    return allCategories.firstWhere((c) => c.id == id, orElse: () => other);
  }
}
