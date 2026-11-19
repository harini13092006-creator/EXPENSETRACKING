import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _savingsGoal = TextEditingController();
  final _password = TextEditingController();
  String _currency = 'INR';
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  static const _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AUD', 'CAD', 'JPY'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final profile = context.read<DashboardProvider>();
    _name.text = profile.fullName;
    _email.text = profile.email;
    _savingsGoal.text = profile.savingsGoal.toStringAsFixed(2);
    _currency = _currencies.contains(profile.currencyCode)
        ? profile.currencyCode
        : 'INR';
    _loaded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _savingsGoal.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<DashboardProvider>().updateProfile(
        fullName: _name.text,
        currencyCode: _currency,
        savingsGoal: double.parse(_savingsGoal.text),
      );
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not save profile. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() async {
    final provider = context.read<DashboardProvider>();
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (file == null || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      final bytes = await file.readAsBytes();
      final contentType = file.mimeType ?? 'image/jpeg';
      final ref = FirebaseStorage.instance.ref(
        'users/${provider.uid}/profile/avatar',
      );
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      final url = await ref.getDownloadURL();
      await provider.updateProfile(photoUrl: url);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not update profile photo. Check Firebase Storage setup.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateEmail() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    try {
      await context.read<DashboardProvider>().updateEmail(email);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your current email to verify the change.'),
          ),
        );
    } on FirebaseAuthException catch (e) {
      if (mounted)
        setState(
          () => _error = e.code == 'requires-recent-login'
              ? 'Sign out and sign in again before changing your email.'
              : 'Could not request an email change (${e.code}).',
        );
    }
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password (at least 6 characters)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (value.length < 6) {
      setState(() => _error = 'Use at least 6 characters.');
      return;
    }
    try {
      await context.read<DashboardProvider>().updatePassword(value);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Password updated.')));
    } on FirebaseAuthException catch (e) {
      if (mounted)
        setState(
          () => _error = e.code == 'requires-recent-login'
              ? 'Sign out and sign in again before changing your password.'
              : 'Could not update password (${e.code}).',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profile = context.watch<DashboardProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: profile.photoUrl == null
                            ? null
                            : NetworkImage(profile.photoUrl!),
                        child: profile.photoUrl == null
                            ? const Icon(Icons.person_outline, size: 44)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          onPressed: _busy ? null : _changePhoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  'Firebase UID: ${user?.uid ?? ''}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: (v) => (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Enter your name.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: const InputDecoration(
                          labelText: 'Preferred currency',
                        ),
                        items: _currencies
                            .map(
                              (code) => DropdownMenuItem(
                                value: code,
                                child: Text('$code (${_symbol(code)})'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _currency = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _savingsGoal,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monthly savings goal',
                        ),
                        validator: (v) {
                          final number = double.tryParse(v ?? '');
                          return number != null && number >= 0
                              ? null
                              : 'Enter a non-negative amount.';
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _updateEmail,
                          child: const Text('Request email change'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _changePassword,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Change password'),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const CircularProgressIndicator()
                            : const Text('Save profile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _symbol(String code) => switch (code) {
    'INR' => '₹',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    'AUD' || 'CAD' => r'$',
    'JPY' => '¥',
    _ => code,
  };
}
