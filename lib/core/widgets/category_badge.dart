import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/constants/category_constants.dart';

/// Reusable category badge / chip for transactions, filters, and forms.
class CategoryBadge extends StatelessWidget {
  final CategoryItem category;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback? onTap;

  const CategoryBadge({
    super.key,
    required this.category,
    this.isSelected = false,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBgColor = isSelected
        ? (isDark ? AppColors.darkPrimary : AppColors.primary)
        : (isDark ? category.color.withValues(alpha: 0.15) : category.backgroundColor);

    final effectiveTextColor = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? category.color : category.color);

    final effectiveIconColor = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : category.color;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDark ? category.color.withValues(alpha: 0.15) : category.backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          category.icon,
          color: category.color,
          size: 18,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.roundedPill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: AppSpacing.roundedPill,
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                : (isDark ? AppColors.darkBorder : Colors.transparent),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              color: effectiveIconColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: TextStyle(
                color: effectiveTextColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
