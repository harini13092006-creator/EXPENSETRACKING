import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/constants/category_constants.dart';

/// Responsive grid component displaying selectable category icons with highlighted state.
class CategorySelectorGrid extends StatelessWidget {
  final List<CategoryItem> categories;
  final String selectedCategoryId;
  final ValueChanged<CategoryItem> onSelectCategory;

  const CategorySelectorGrid({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = cat.id == selectedCategoryId;

        final cardBgColor = isSelected
            ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.2) : cat.backgroundColor)
            : (isDark ? AppColors.darkCard : AppColors.surface);

        final borderColor = isSelected
            ? (isDark ? AppColors.darkPrimary : cat.color)
            : (isDark ? AppColors.darkBorder : AppColors.border);

        return InkWell(
          onTap: () => onSelectCategory(cat),
          borderRadius: AppSpacing.roundedLg,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: borderColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: cat.color.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: isSelected ? 0.25 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        cat.icon,
                        color: cat.color,
                        size: 24,
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: cat.color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? AppColors.darkPrimaryText : AppColors.primaryText)
                        : (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
