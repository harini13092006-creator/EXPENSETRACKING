import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/features/auth/services/social_auth_service.dart';
import 'package:expensetracker/features/auth/widgets/social_sign_in_buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _creatingAccount = false;
  bool _obscurePassword = true;
  bool _busy = false;
  String? _socialBusy;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final projectId = Firebase.app().options.projectId;
      final operation = _creatingAccount ? 'registration' : 'login';
      debugPrint(
        '[Auth] $operation request status=started projectId=$projectId',
      );
      if (_creatingAccount) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final uid = credential.user?.uid;
        if (uid == null) {
          debugPrint(
            '[Auth] registration request status=failed '
            'reason=Firebase returned no user projectId=$projectId',
          );
          if (mounted) {
            setState(
              () => _error =
                  'Firebase did not return the new account. Please try again.',
            );
          }
          return;
        }
        debugPrint('[Auth] registration created Firebase user uid=$uid');
      } else {
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      debugPrint(
        '[Auth] $operation request status=success projectId=$projectId',
      );
    } on FirebaseAuthException catch (exception) {
      final projectId = Firebase.apps.isEmpty
          ? 'unavailable'
          : Firebase.app().options.projectId;
      debugPrint(
        '[Auth] ${_creatingAccount ? 'registration' : 'login'} failed '
        'FirebaseAuthException.code=${exception.code} message=${exception.message ?? 'none'} '
        'projectId=$projectId uid=${FirebaseAuth.instance.currentUser?.uid ?? 'none'}',
      );
      if (mounted) {
        setState(() => _error = _messageFor(exception));
      }
    } catch (exception) {
      final projectId = Firebase.apps.isEmpty
          ? 'unavailable'
          : Firebase.app().options.projectId;
      debugPrint(
        '[Auth] ${_creatingAccount ? 'registration' : 'login'} failed '
        'type=${exception.runtimeType} projectId=$projectId',
      );
      if (mounted) {
        setState(
          () => _error = 'Could not complete authentication. Please check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signInSocial(String provider) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _socialBusy = provider;
      _error = null;
    });
    try {
      await SocialAuthService().signIn(provider);
    } on FirebaseAuthException catch (exception) {
      final projectId = Firebase.apps.isEmpty
          ? 'unavailable'
          : Firebase.app().options.projectId;
      debugPrint(
        '[Auth] ${_creatingAccount ? 'registration' : 'login'} failed FirebaseAuthException.code=${exception.code} message=${exception.message ?? 'none'} projectId=$projectId uid=${FirebaseAuth.instance.currentUser?.uid ?? 'none'}',
      );
      if (mounted) setState(() => _error = socialAuthErrorMessage(exception));
    } catch (error, stackTrace) {
      debugPrint(
        '[Auth] social login failed provider=$provider type=${error.runtimeType} message=$error uid=${FirebaseAuth.instance.currentUser?.uid ?? 'none'}\n$stackTrace',
      );
      if (mounted)
        setState(
          () => _error = 'Could not complete sign-in. Check your connection and provider setup.',
        );
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _socialBusy = null;
        });
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () => _error =
            'Enter your email address first, then tap Forgot password.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    } on FirebaseAuthException catch (exception) {
      if (mounted) {
        setState(() => _error = _messageFor(exception));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _messageFor(
    FirebaseAuthException exception,
  ) => switch (exception.code) {
    'invalid-email' => 'That email address is not valid.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for this email.',
    'weak-password' => 'Choose a password with at least 6 characters.',
    'configuration-not-found' => 'Firebase Authentication is not configured for this app or sign-in provider. Check the existing Firebase project configuration.',
    'operation-not-allowed' => 'Email and password sign-in is disabled for this Firebase project. Enable the Email/Password provider in Firebase Authentication settings.',
    'unauthorized-domain' => 'This app domain is not authorized for Firebase Authentication. Add the current domain in Firebase Authentication settings.',
    'invalid-api-key' || 'app-not-authorized' => 'This app is not authorized to use the configured Firebase project. Check the Firebase web app configuration and API key restrictions.',
    'account-exists-with-different-credential' => 'An account already exists for this email with a different sign-in method.',
    'network-request-failed' =>
      'Could not connect. Check your internet connection and try again.',
    'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
    'email-change-needs-verification' =>
      'Verify the email address before changing it.',
    _ =>
      exception.message == null || exception.message!.trim().isEmpty
          ? 'Authentication failed (${exception.code}). Please try again.'
          : 'Authentication failed (${exception.code}): ${exception.message}',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width: 76,
                          height: 76,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _creatingAccount ? 'Create your account' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _creatingAccount
                          ? 'Start building healthier money habits.'
                          : 'Sign in to manage your money with confidence.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(email)
                            ? null
                            : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: _creatingAccount
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      textInputAction: _creatingAccount
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: (_) =>
                          _creatingAccount ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) >= 6
                          ? null
                          : 'Use at least 6 characters',
                    ),
                    if (_creatingAccount) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (value) => value == _passwordController.text
                            ? null
                            : 'Passwords do not match',
                      ),
                    ],
                    if (!_creatingAccount)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.expenseLight,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.expense),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _creatingAccount ? 'Create account' : 'Sign in',
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _creatingAccount = !_creatingAccount;
                              _error = null;
                            }),
                      child: Text(
                        _creatingAccount
                            ? 'Already have an account? Sign in'
                            : 'New here? Create an account',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SocialSignInButtons(
                      busy: _busy,
                      loadingProvider: _socialBusy,
                      onSelected: _signInSocial,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
