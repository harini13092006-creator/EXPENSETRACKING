import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';

/// Header widget displaying the application name, personalized greeting,
/// active month & year, and an interactive notification icon.
class DashboardHeader extends StatelessWidget {
  final String userName;
  final DateTime selectedMonth;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAddTransaction;

  const DashboardHeader({
    super.key,
    this.userName = 'there',
    required this.selectedMonth,
    this.onNotificationTap,
    this.onAddTransaction,
  });

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final monthYearFormatted = DateFormat('MMMM yyyy').format(selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Greeting & App info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.income,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $monthYearFormatted',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getTimeGreeting()}, $userName 👋',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark
                        ? AppColors.darkPrimaryText
                        : AppColors.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.add_rounded),
                onPressed: onAddTransaction,
                tooltip: 'Add Transaction',
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 22),
                    onPressed: onNotificationTap ?? () {},
                    tooltip: 'Notifications',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.darkCard
                          : AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.roundedMd,
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.border,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.expense,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
