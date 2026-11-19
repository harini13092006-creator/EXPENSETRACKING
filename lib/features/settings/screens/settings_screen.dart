import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/widgets/custom_app_bar.dart';
import 'package:expensetracker/providers/theme_provider.dart';
import 'package:expensetracker/features/auth/services/social_auth_service.dart';
import 'package:expensetracker/features/auth/widgets/social_sign_in_buttons.dart';
import 'package:expensetracker/features/settings/screens/profile_screen.dart';
import 'package:expensetracker/features/settings/screens/category_management_screen.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';
import 'package:expensetracker/features/onboarding/screens/financial_qa_screen.dart';

/// Settings & Preferences screen for theme switching, currency, notifications, and profile.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricsEnabled = true;
  String? _linkingProvider;

  Future<void> _linkProvider(String provider) async {
    setState(() => _linkingProvider = provider);
    try {
      final result = await SocialAuthService().link(provider);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.user?.providerData.last.providerId ?? 'Sign-in method'} linked to this account.',
            ),
          ),
        );
    } on FirebaseAuthException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(socialAuthErrorMessage(error))));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not link this provider. Check your connection and provider setup.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _linkingProvider = null);
    }
  }

  Future<void> _openProfile() {
    final dashboard = context.read<DashboardProvider>();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<DashboardProvider>.value(
          value: dashboard,
          child: const ProfileScreen(),
        ),
      ),
    );
  }

  Future<void> _manageCategories() {
    final dashboard = context.read<DashboardProvider>();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<DashboardProvider>.value(
          value: dashboard,
          child: const CategoryManagementScreen(),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account and data?'),
        content: const Text(
          'This permanently deletes your ExpenseTracker profile, transactions, budgets and profile photo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    String? password;
    if (user.providerData.any(
      (provider) => provider.providerId == 'password',
    )) {
      final controller = TextEditingController();
      password = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm your password'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Delete account'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (password == null) return;
    }
    try {
      await context.read<DashboardProvider>().deleteAccount(password: password);
    } on FirebaseAuthException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'requires-recent-login' ||
                      error.code == 'wrong-password'
                  ? 'Reauthentication failed. Sign in again, then retry account deletion.'
                  : 'Could not delete account (${error.code}).',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not delete account. Check your connection and Firebase permissions.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUser = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    final dashboard = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Settings',
        subtitle: 'App preferences & configuration',
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          // 1. User Profile Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surface,
              borderRadius: AppSpacing.roundedXl,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                width: 1,
              ),
              boxShadow: AppSpacing.subtleShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: dashboard.photoUrl == null
                      ? null
                      : NetworkImage(dashboard.photoUrl!),
                  backgroundColor: isDark
                      ? AppColors.darkPrimary.withValues(alpha: 0.2)
                      : AppColors.secondary,
                  child: dashboard.photoUrl == null
                      ? Text(
                          dashboard.fullName.isNotEmpty
                              ? dashboard.fullName[0].toUpperCase()
                              : '•',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkPrimary
                                : AppColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dashboard.fullName.isNotEmpty
                            ? dashboard.fullName
                            : 'Your account',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkPrimaryText
                              : AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dashboard.email.isNotEmpty
                            ? dashboard.email
                            : 'Signed in with Firebase',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.secondaryText,
                        ),
                      ),
                      if (currentUser?.uid != null)
                        Text(
                          'UID: ${currentUser!.uid}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.secondaryText,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.incomeLight,
                          borderRadius: AppSpacing.roundedPill,
                        ),
                        child: const Text(
                          'Firebase account',
                          style: TextStyle(
                            color: AppColors.income,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  tooltip: 'Sign out',
                  onPressed: currentUser == null
                      ? null
                      : () async {
                          try {
                            await FirebaseAuth.instance.signOut();
                          } on FirebaseAuthException catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error.message ?? 'Could not sign out.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  color: isDark
                      ? AppColors.darkSecondaryText
                      : AppColors.secondaryText,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit profile',
                  onPressed: currentUser == null ? null : _openProfile,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _SettingsSectionTitle(title: 'Linked sign-in methods'),
          SocialSignInButtons(
            busy: _linkingProvider != null,
            loadingProvider: _linkingProvider,
            labelPrefix: 'Link',
            onSelected: _linkProvider,
          ),

          const SizedBox(height: AppSpacing.lg),

          // 2. Appearance Section
          _SettingsSectionTitle(title: 'Appearance'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surface,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.brightness_6_rounded,
                  title: 'Theme Mode',
                  subtitle: _getThemeLabel(themeProvider.themeMode),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 16),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) async {
                      themeProvider.setThemeMode(newSelection.first);
                      try {
                        await dashboard.savePreferences(
                          themeMode: newSelection.first.name,
                          notificationsEnabled: dashboard.notificationsEnabled,
                        );
                      } catch (_) {}
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const Divider(),
                _SettingsTile(
                  icon: Icons.attach_money_rounded,
                  title: 'Default Currency',
                  subtitle: dashboard.currencyCode,
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: dashboard.currencyCode,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items:
                          const [
                                'INR',
                                'USD',
                                'EUR',
                                'GBP',
                                'AUD',
                                'CAD',
                                'JPY',
                              ]
                              .map(
                                (code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(code),
                                ),
                              )
                              .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        try {
                          await dashboard.updateProfile(currencyCode: value);
                          await dashboard.savePreferences(
                            themeMode: themeProvider.themeMode.name,
                            notificationsEnabled:
                                dashboard.notificationsEnabled,
                          );
                        } catch (_) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not save currency preference.',
                                ),
                              ),
                            );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _SettingsSectionTitle(title: 'Financial profile'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surface,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: _SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Edit financial Q&A',
              subtitle:
                  'Update your income, budget, goals and spending preferences',
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FinancialQaScreen(user: user, editing: true),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 3. Security & Notifications
          _SettingsSectionTitle(title: 'Security & Preferences'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surface,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Lock',
                  subtitle: 'Require FaceID / Fingerprint on launch',
                  trailing: Switch(
                    value: _biometricsEnabled,
                    activeTrackColor: isDark
                        ? AppColors.darkPrimary
                        : AppColors.primary,
                    onChanged: (val) =>
                        setState(() => _biometricsEnabled = val),
                  ),
                ),
                const Divider(),
                _SettingsTile(
                  icon: Icons.alarm_rounded,
                  title: 'Daily Expense Reminder',
                  subtitle: 'Remind me to log transactions at 8 PM',
                  trailing: Switch(
                    value: dashboard.notificationsEnabled,
                    activeTrackColor: isDark
                        ? AppColors.darkPrimary
                        : AppColors.primary,
                    onChanged: (val) async {
                      try {
                        await dashboard.savePreferences(
                          themeMode: themeProvider.themeMode.name,
                          notificationsEnabled: val,
                        );
                      } catch (_) {}
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 4. Data Management & About
          _SettingsSectionTitle(title: 'Data & About'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surface,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.cloud_download_outlined,
                  title: 'Export Transactions',
                  subtitle: 'Download your records as CSV or Excel',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {},
                ),
                const Divider(),
                _SettingsTile(
                  icon: Icons.category_outlined,
                  title: 'Manage Categories',
                  subtitle: 'Customize expense and income categories',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: _manageCategories,
                ),
                const Divider(),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'App Version',
                  subtitle:
                      '${AppConstants.appName} v${AppConstants.appVersion}',
                  trailing: const SizedBox.shrink(),
                ),
                const Divider(),
                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete Account',
                  subtitle: 'Permanently remove your account and its data',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light Theme';
      case ThemeMode.dark:
        return 'Dark Theme';
      case ThemeMode.system:
        return 'System Default';
    }
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String title;

  const _SettingsSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
      child: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.roundedLg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSecondary : AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkPrimaryText
                          : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
