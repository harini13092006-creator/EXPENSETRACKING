import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';

/// A premium, customizable app bar tailored for modern fintech applications.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showNotificationBadge;
  final VoidCallback? onNotificationTap;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showNotificationBadge = false,
    this.onNotificationTap,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: Row(
          children: [
            if (showBackButton)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.roundedMd,
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                  ),
                ),
              )
            else if (leading != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: leading!,
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null) ...[
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ...?actions,
            if (showNotificationBadge)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, size: 22),
                      onPressed: onNotificationTap ?? () {},
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.roundedMd,
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
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
              ),
          ],
        ),
      ),
    );
  }
}
