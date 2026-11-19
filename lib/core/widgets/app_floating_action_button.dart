import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';

/// Customized Floating Action Button for adding transactions or primary actions.
class AppFloatingActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String? label;
  final IconData icon;
  final String? tooltip;

  const AppFloatingActionButton({
    super.key,
    required this.onPressed,
    this.label,
    this.icon = Icons.add_rounded,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final fgColor = isDark ? Colors.black : Colors.white;

    if (label != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.roundedPill,
          boxShadow: AppSpacing.floatingShadow,
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          highlightElevation: 2,
          tooltip: tooltip,
          icon: Icon(icon, size: 22),
          label: Text(
            label!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppSpacing.floatingShadow,
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
        highlightElevation: 2,
        tooltip: tooltip,
        shape: const CircleBorder(),
        child: Icon(icon, size: 28),
      ),
    );
  }
}
