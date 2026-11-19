import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expensetracker/data/repositories/firestore_expense_repository.dart';

/// Four-step personal finance setup, also used to edit the saved profile.
class FinancialQaScreen extends StatefulWidget {
  const FinancialQaScreen({
    super.key,
    required this.user,
    this.onComplete,
    this.editing = false,
  });
  final User user;
  final VoidCallback? onComplete;
  final bool editing;

  @override
  State<FinancialQaScreen> createState() => _FinancialQaScreenState();
}

class _FinancialQaScreenState extends State<FinancialQaScreen> {
  static const _categories = [
    'Food',
    'Transportation',
    'Shopping',
    'Bills',
    'Healthcare',
    'Education',
    'Entertainment',
    'Rent',
    'Other',
  ];
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _occupation = TextEditingController();
  final _income = TextEditingController();
  final _budget = TextEditingController();
  final _savings = TextEditingController();
  final _goal = TextEditingController();
  final _regular = TextEditingController();
  final Set<String> _selected = {};
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  bool _profileLoadFailed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _profileLoadFailed = false;
    _error = null;
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw StateError('No authenticated Firebase user is available.');
      }
      if (authUser.uid != widget.user.uid) {
        throw StateError(
          'The authenticated account changed while loading the profile.',
        );
      }
      final projectId = Firebase.apps.isEmpty
          ? 'unavailable'
          : Firebase.app().options.projectId;
      debugPrint(
        '[FinancialProfile] load started uid=${authUser.uid} projectId=$projectId path=users/${authUser.uid} operation=profile.get requestReachedFirebase=pending',
      );
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();
      debugPrint(
        '[FinancialProfile] load completed uid=${authUser.uid} projectId=$projectId path=users/${authUser.uid} operation=profile.get exists=${doc.exists} requestReachedFirebase=true',
      );
      final d = doc.data() ?? {};
      _name.text =
          _stringValue(d['name'] ?? d['fullName']) ??
          widget.user.displayName ??
          '';
      _age.text = _numberValue(d['age'])?.toInt().toString() ?? '';
      _occupation.text = _stringValue(d['occupation']) ?? '';
      _income.text = _numberValue(d['monthlyIncome'])?.toString() ?? '';
      _budget.text = _numberValue(d['monthlyBudget'])?.toString() ?? '';
      _savings.text =
          _numberValue(d['savingsTarget'] ?? d['savingsGoal'])?.toString() ??
          '';
      _goal.text =
          _stringValue(d['financialGoal'] ?? d['goal'] ?? d['primaryGoal']) ??
          '';
      _regular.text = _stringValue(d['regularExpenses']) ?? '';
      final categories = d['categories'] ?? d['preferredCategories'];
      if (categories is List) {
        _selected.addAll(categories.whereType<String>());
      }
      debugPrint(
        '[FinancialProfile] load ${doc.exists ? 'found' : 'profile missing; ready for onboarding'} uid=${authUser.uid}',
      );
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint(
        '[FinancialProfile] load failed uid=${FirebaseAuth.instance.currentUser?.uid ?? 'none'} projectId=${Firebase.apps.isEmpty ? 'unavailable' : Firebase.app().options.projectId} path=users/${widget.user.uid} operation=profile.get FirebaseAuthException.code=${error.code} message=${error.message ?? 'none'} requestReachedFirebase=unknown\n$stackTrace',
      );
      _error = _friendlyFirebaseError(
        error,
        'load',
        operation: 'profile.get',
        path: 'users/${widget.user.uid}',
      );
      _profileLoadFailed = true;
    } on FirebaseException catch (error, stackTrace) {
      _logFirebaseError(
        'profile.get',
        'users/${widget.user.uid}',
        error,
        stackTrace,
      );
      _error = _friendlyFirebaseError(
        error,
        'load',
        operation: 'profile.get',
        path: 'users/${widget.user.uid}',
      );
      _profileLoadFailed = true;
    } catch (error, stackTrace) {
      debugPrint(
        '[FinancialProfile] load failed uid=${FirebaseAuth.instance.currentUser?.uid ?? 'none'} type=${error.runtimeType} message=$error\n$stackTrace',
      );
      _error = error is StateError ? error.message : 'Could not load the profile because the saved data has an unexpected format.';
      _profileLoadFailed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  String? _stringValue(Object? value) => value is String ? value : null;

  double? _numberValue(Object? value) => value is num ? value.toDouble() : null;

  void _logFirebaseError(
    String operation,
    String path,
    FirebaseException error,
    StackTrace stackTrace,
  ) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'none';
    final projectId = Firebase.apps.isEmpty
        ? 'unavailable'
        : Firebase.app().options.projectId;
    debugPrint(
      '[FinancialProfile] operation=$operation failed uid=$uid projectId=$projectId path=$path plugin=${error.plugin} FirebaseException.code=${error.code} message=${error.message ?? 'none'} requestReachedFirebase=${_requestReachedFirebase(error)}\n$stackTrace',
    );
  }

  String _requestReachedFirebase(FirebaseException error) =>
      switch (error.code) {
        'permission-denied' ||
        'unauthenticated' ||
        'not-found' ||
        'failed-precondition' ||
        'invalid-argument' ||
        'resource-exhausted' => 'yes',
        'network-request-failed' => 'no',
        _ => 'unknown',
      };

  String _friendlyFirebaseError(
    FirebaseException error,
    String action, {
    String? operation,
    String? path,
  }) {
    final details = error.message?.toLowerCase() ?? '';
    if (details.contains('service_disabled') ||
        details.contains('cloud firestore api has not been used') ||
        details.contains('firestore.googleapis.com is disabled')) {
      return 'Cloud Firestore is disabled for this Firebase project. Enable the Firestore API in Google Cloud, then retry.';
    }
    return switch (error.code) {
      'permission-denied' =>
        'Firestore denied ${operation ?? action} at ${path ?? 'users/${widget.user.uid}'}. Check the deployed rules for this user-owned path.',
      'unauthenticated' => 'Your sign-in has expired. Sign in again and retry.',
      'configuration-not-found' => 'Firebase Authentication configuration was not found for this app or provider.',
      'unavailable' || 'network-request-failed' =>
        'Firebase is temporarily unavailable. Check your connection and retry.',
      'not-found' => 'The profile document was not found. You can complete the questionnaire to create it.',
      _ =>
        'Could not $action the profile (${error.code}). ${error.message ?? ''}'
            .trim(),
    };
  }

  Future<void> _retryProfileLoad() async {
    setState(() {
      _loading = true;
      _error = null;
      _profileLoadFailed = false;
    });
    await _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _age,
      _occupation,
      _income,
      _budget,
      _savings,
      _goal,
      _regular,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _amount(String? value, {bool optional = false}) {
    if (optional && (value == null || value.trim().isEmpty)) return null;
    final n = double.tryParse((value ?? '').trim());
    if (n == null || !n.isFinite || n < 0 || n > 1000000000)
      return 'Enter a valid amount from ₹0 to ₹1,000,000,000';
    return null;
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool required = true,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    String? prefix,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters:
          keyboard == const TextInputType.numberWithOptions(decimal: true)
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]
          : null,
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty)
                    ? 'This field is required'
                    : null
              : null),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );

  bool _validateStep() {
    if (_step == 0) return (_key.currentState?.validate() ?? false);
    if (_step == 1) return (_key.currentState?.validate() ?? false);
    if (_step == 3) return _validateReviewedInformation();
    return true;
  }

  bool _validateReviewedInformation() {
    String? message;
    if (_name.text.trim().isEmpty) {
      message = 'Enter your name before continuing.';
    } else if (_name.text.trim().length > 100) {
      message = 'Keep your name under 100 characters.';
    } else if (_occupation.text.trim().isEmpty) {
      message = 'Enter your occupation before continuing.';
    } else if (_occupation.text.trim().length > 100) {
      message = 'Keep your occupation under 100 characters.';
    } else if (_age.text.trim().isNotEmpty &&
        (int.tryParse(_age.text.trim()) == null ||
            int.parse(_age.text.trim()) < 13 ||
            int.parse(_age.text.trim()) > 120)) {
      message = 'Enter an age from 13 to 120, or leave it blank.';
    } else if (_amount(_income.text) != null ||
        _amount(_budget.text) != null ||
        _amount(_savings.text) != null) {
      message = 'Check the income, budget, and savings amounts.';
    } else if (_goal.text.trim().isEmpty) {
      message = 'Enter your primary financial goal.';
    } else if (_goal.text.trim().length > 200) {
      message = 'Keep your financial goal under 200 characters.';
    } else if (_regular.text.trim().length > 1000) {
      message = 'Keep regular expenses under 1,000 characters.';
    } else if (_selected.isEmpty) {
      message = 'Select at least one spending category.';
    } else if ((FirebaseAuth.instance.currentUser?.email ?? '').isEmpty) {
      message = 'Your signed-in account does not have an email address.';
    }
    if (message == null) return true;
    setState(() => _error = message);
    return false;
  }

  Future<void> _next() async {
    if (!_validateStep()) return;
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var failedOperation = 'profile.get';
    var failedPath = 'users/${widget.user.uid}';
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw StateError('Sign in again before saving your financial profile.');
      }
      if (authUser.uid != widget.user.uid) {
        throw StateError(
          'The authenticated account changed. Sign in again before saving.',
        );
      }
      final projectId = Firebase.apps.isEmpty
          ? 'unavailable'
          : Firebase.app().options.projectId;
      debugPrint(
        '[FinancialProfile] save started uid=${authUser.uid} projectId=$projectId path=users/${authUser.uid} operation=profile.save requestReachedFirebase=pending',
      );
      final income = double.parse(_income.text);
      final monthlyBudget = double.parse(_budget.text);
      final savingsTarget = double.parse(_savings.text);
      failedOperation = 'profile+budget.transaction';
      final profilePath = 'users/${authUser.uid}';
      final currentMonth = DateTime.now();
      final budgetPath =
          '$profilePath/budgets/${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}';
      failedPath = '$profilePath and $budgetPath';
      debugPrint(
        '[FinancialProfile] save started uid=${authUser.uid} projectId=$projectId path=$failedPath operation=$failedOperation requestReachedFirebase=pending',
      );
      final profileRepository = FirestoreExpenseRepository(uid: authUser.uid);
      await profileRepository.saveOnboardingProfile(
        authUser: authUser,
        fullName: _name.text.trim(),
        age: int.tryParse(_age.text),
        occupation: _occupation.text.trim(),
        monthlyIncome: income,
        monthlyBudget: monthlyBudget,
        savingsTarget: savingsTarget,
        financialGoal: _goal.text.trim(),
        regularExpenses: _regular.text.trim(),
        categories: _selected.toList(),
      );
      debugPrint(
        '[FinancialProfile] save committed uid=${authUser.uid} projectId=$projectId path=$profilePath operation=profile+budget.transaction requestReachedFirebase=true',
      );
      failedOperation = 'profile.verify';
      failedPath = profilePath;
      final saved = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get(const GetOptions(source: Source.server));
      if (!saved.exists || saved.data()?['onboardingCompleted'] != true) {
        throw StateError('Firebase did not confirm that onboarding was saved.');
      }
      debugPrint(
        '[FinancialProfile] save verified uid=${authUser.uid} projectId=$projectId path=users/${authUser.uid} operation=profile.verify onboardingCompleted=true requestReachedFirebase=true',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editing
                ? 'Financial profile updated.'
                : 'Your financial profile is ready.',
          ),
        ),
      );
      if (widget.onComplete != null)
        widget.onComplete!();
      else
        Navigator.of(context).pop();
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint(
        '[FinancialProfile] save failed uid=${FirebaseAuth.instance.currentUser?.uid ?? 'none'} projectId=${Firebase.apps.isEmpty ? 'unavailable' : Firebase.app().options.projectId} path=$failedPath operation=$failedOperation FirebaseAuthException.code=${error.code} message=${error.message ?? 'none'} requestReachedFirebase=unknown\n$stackTrace',
      );
      if (mounted)
        setState(
          () => _error = _friendlyFirebaseError(
            error,
            'save',
            operation: failedOperation,
            path: failedPath,
          ),
        );
    } on FirebaseException catch (error, stackTrace) {
      _logFirebaseError(failedOperation, failedPath, error, stackTrace);
      if (mounted)
        setState(
          () => _error = _friendlyFirebaseError(
            error,
            'save',
            operation: failedOperation,
            path: failedPath,
          ),
        );
    } catch (error, stackTrace) {
      debugPrint(
        '[FinancialProfile] save failed uid=${FirebaseAuth.instance.currentUser?.uid ?? 'none'} type=${error.runtimeType} message=$error\n$stackTrace',
      );
      if (mounted)
        setState(
          () => _error = error is StateError ? error.message : 'Could not save your profile because the saved data has an unexpected format.',
        );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final titles = ['About you', 'Monthly finances', 'Your spending', 'Review'];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing ? 'Edit financial profile' : 'Financial setup',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      4,
                      (i) => Expanded(
                        child: Container(
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i <= _step
                                ? const Color(0xFF13B981)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Step ${_step + 1} of 4',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      titles[_step],
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Form(
                      key: _key,
                      child: SingleChildScrollView(child: _buildStepContent()),
                    ),
                  ),
                  _error == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              if (_profileLoadFailed)
                                TextButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : _retryProfileLoad,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry profile load'),
                                ),
                              if (!_profileLoadFailed && _step == 3)
                                TextButton.icon(
                                  onPressed: _saving ? null : _next,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry profile save'),
                                ),
                            ],
                          ),
                        ),
                  if (_step == 3)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _step--),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back'),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: _saving ? null : _next,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF20C997),
                              foregroundColor: const Color(0xFF06281F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF06281F),
                                    ),
                                  )
                                : const Text('Continue to Dashboard \u2192'),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        if (_step > 0)
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _step--),
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _saving ? null : _next,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: const Text('Next'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == 0) {
      return Column(
        children: [
          _field('Full name', _name),
          _field(
            'Age (optional)',
            _age,
            required: false,
            keyboard: TextInputType.number,
            validator: (v) =>
                v == null ||
                    v.isEmpty ||
                    (int.tryParse(v) != null &&
                        int.parse(v) >= 13 &&
                        int.parse(v) <= 120)
                ? null
                : 'Enter an age from 13 to 120',
          ),
          _field('Occupation', _occupation),
          TextFormField(
            initialValue: widget.user.email ?? '',
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Email (from your account)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    }
    if (_step == 1) {
      return Column(
        children: [
          _field(
            'Monthly income',
            _income,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            prefix: '\u20B9 ',
            validator: _amount,
          ),
          _field(
            'Monthly budget',
            _budget,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            prefix: '\u20B9 ',
            validator: _amount,
          ),
          _field(
            'Monthly savings target',
            _savings,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            prefix: '\u20B9 ',
            validator: _amount,
          ),
          _field('Primary financial goal', _goal),
        ],
      );
    }
    if (_step == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Regular monthly expenses', _regular, required: false),
          const Text(
            'Categories you spend on',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _categories
                .map(
                  (c) => FilterChip(
                    label: Text(c),
                    selected: _selected.contains(c),
                    onSelected: (v) => setState(
                      () => v ? _selected.add(c) : _selected.remove(c),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      );
    }
    return _review();
  }

  Widget _review() {
    final rows = {
      'Name': _name.text,
      'Age': _age.text.isEmpty ? 'Not provided' : _age.text,
      'Occupation': _occupation.text,
      'Email': widget.user.email ?? '',
      'Monthly income': '₹${_income.text}',
      'Monthly budget': '₹${_budget.text}',
      'Savings target': '₹${_savings.text}',
      'Goal': _goal.text,
      'Regular expenses': _regular.text.isEmpty
          ? 'Not provided'
          : _regular.text,
      'Categories': _selected.join(', '),
    };
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _step = 0),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit details'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: rows.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 125,
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(child: Text(e.value)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
