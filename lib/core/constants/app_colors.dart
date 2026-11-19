import 'package:flutter/material.dart';

/// Centralized color palette for the ExpenseTracker design system.
/// Adheres strictly to modern fintech styling with emerald and mint tones.
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF087F5B); // Deep Emerald Green
  static const Color primaryDark = Color(0xFF065F44);
  static const Color primaryLight = Color(0xFFE6F5F0);
  static const Color primaryAccent = Color(0xFF10B981);

  // Secondary & Accents
  static const Color secondary = Color(0xFFDDF5E8); // Mint Green
  static const Color secondaryDark = Color(0xFF1F4A38);
  static const Color secondaryLight = Color(0xFFF0FAF4);

  // Light Theme Neutral Colors
  static const Color background = Color(0xFFF7F9F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EBE8);
  static const Color divider = Color(0xFFEDF2EF);

  // Typography Colors (Light Mode)
  static const Color primaryText = Color(0xFF172B24);
  static const Color secondaryText = Color(0xFF84918A);
  static const Color subtleText = Color(0xFFA6B4AD);

  // Transaction Semantic Indicators
  static const Color expense = Color(0xFFEF5350); // Red
  static const Color expenseLight = Color(0xFFFDECEC);
  static const Color income = Color(0xFF2EAD73); // Green
  static const Color incomeLight = Color(0xFFE8F8F1);
  static const Color warning = Color(0xFFF4B740); // Amber / Warning
  static const Color warningLight = Color(0xFFFEF7E6);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);

  // Dark Theme Palette
  static const Color darkBackground = Color(0xFF0F1714);
  static const Color darkSurface = Color(0xFF17221D);
  static const Color darkCard = Color(0xFF1D2B24);
  static const Color darkBorder = Color(0xFF283B32);
  static const Color darkDivider = Color(0xFF203028);

  static const Color darkPrimary = Color(0xFF20C997);
  static const Color darkPrimaryContainer = Color(0xFF144738);
  static const Color darkSecondary = Color(0xFF234438);

  static const Color darkPrimaryText = Color(0xFFF1F6F3);
  static const Color darkSecondaryText = Color(0xFF8E9F97);
  static const Color darkSubtleText = Color(0xFF677770);

  static const Color darkExpense = Color(0xFFFF6B6B);
  static const Color darkExpenseLight = Color(0xFF382020);
  static const Color darkIncome = Color(0xFF38D394);
  static const Color darkIncomeLight = Color(0xFF19382C);
  static const Color darkWarning = Color(0xFFFFC043);
  static const Color darkWarningLight = Color(0xFF3B321C);
}
