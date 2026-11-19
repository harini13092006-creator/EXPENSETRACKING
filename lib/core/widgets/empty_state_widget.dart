import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/widgets/app_buttons.dart';

/// Reusable empty state placeholder widget.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkPrimary.withValues(alpha: 0.12)
                    : AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 38,
                color: isDark ? AppColors.darkPrimary : AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onActionPressed != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
                child: PrimaryButton(
                  text: actionText!,
                  onPressed: onActionPressed,
                  icon: Icons.add_rounded,
                  height: 46,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
