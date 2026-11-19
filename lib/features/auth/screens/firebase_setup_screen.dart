import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';

class FirebaseSetupScreen extends StatefulWidget {
  final String error;
  final Future<void> Function()? onRetry;

  const FirebaseSetupScreen({super.key, required this.error, this.onRetry});

  @override
  State<FirebaseSetupScreen> createState() => _FirebaseSetupScreenState();
}

class _FirebaseSetupScreenState extends State<FirebaseSetupScreen> {
  String? _retryError;
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying || widget.onRetry == null) return;
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    try {
      await widget.onRetry!();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[Firebase] retry initialization failed plugin=${error.plugin} code=${error.code} message=${error.message ?? 'none'} uid=none requestReachedFirebase=false\n$stackTrace',
      );
      if (mounted)
        setState(
          () => _retryError =
              '${error.code}: ${error.message ?? 'Firebase initialization failed.'}',
        );
    } catch (error, stackTrace) {
      debugPrint(
        '[Firebase] retry initialization failed type=${error.runtimeType} message=$error uid=none requestReachedFirebase=false\n$stackTrace',
      );
      if (mounted) setState(() => _retryError = error.toString());
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.primary,
                  size: 42,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Connect Firebase to continue',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Register this app in your Firebase project, enable Email/Password under Authentication, '
                  'and confirm lib/firebase_options.dart has the correct platform app details. See README.md for details.',
                ),
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  _retryError ?? widget.error,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _retrying ? null : _retry,
                    icon: _retrying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _retrying ? 'Retrying…' : 'Retry Firebase setup',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
