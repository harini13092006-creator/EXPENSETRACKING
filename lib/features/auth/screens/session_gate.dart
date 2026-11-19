import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/features/auth/screens/login_screen.dart';
import 'package:expensetracker/features/dashboard/screens/main_nav_screen.dart';
import 'package:expensetracker/features/onboarding/screens/financial_qa_screen.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';
import 'package:expensetracker/providers/theme_provider.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null
            ? const LoginScreen()
            : _SignedInGate(
                key: ValueKey(snapshot.data!.uid),
                user: snapshot.data!,
              );
      },
    );
  }
}

class _SignedInGate extends StatefulWidget {
  const _SignedInGate({super.key, required this.user});
  final User user;
  @override
  State<_SignedInGate> createState() => _SignedInGateState();
}

class _SignedInGateState extends State<_SignedInGate> {
  late Future<bool> _profileComplete;
  bool? _completedHere;

  @override
  void initState() {
    super.initState();
    _check();
  }

  void _check() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != widget.user.uid) {
      _profileComplete = Future.error(
        StateError('The signed-in Firebase user is not available.'),
      );
      return;
    }
    final projectId = Firebase.app().options.projectId;
    debugPrint(
      '[SessionGate] profile check started uid=${currentUser.uid} projectId=$projectId path=users/${currentUser.uid} operation=profile.get requestReachedFirebase=pending',
    );
    _profileComplete = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get()
        .then((doc) {
          debugPrint(
            '[SessionGate] profile check completed uid=${currentUser.uid} path=users/${currentUser.uid} exists=${doc.exists} onboardingCompleted=${doc.data()?['onboardingCompleted'] == true} requestReachedFirebase=true',
          );
          return doc.exists && doc.data()?['onboardingCompleted'] == true;
        })
        .catchError((Object error, StackTrace stackTrace) {
          final uid = FirebaseAuth.instance.currentUser?.uid ?? 'none';
          if (error is FirebaseException) {
            debugPrint(
              '[SessionGate] profile check failed uid=$uid projectId=$projectId path=users/$uid operation=profile.get plugin=${error.plugin} FirebaseException.code=${error.code} message=${error.message ?? 'none'} requestReachedFirebase=${_requestReachedFirebase(error)}\n$stackTrace',
            );
          } else {
            debugPrint(
              '[SessionGate] profile check failed uid=$uid type=${error.runtimeType} message=$error\n$stackTrace',
            );
          }
          throw error;
        });
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

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _profileComplete,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          _completedHere == null)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.hasError && _completedHere == null) {
        final error = snapshot.error;
        final details = error is FirebaseException
            ? error.message?.toLowerCase() ?? ''
            : '';
        final message =
            details.contains('service_disabled') ||
                details.contains('cloud firestore api has not been used')
            ? 'Cloud Firestore is disabled for this Firebase project. Enable the Firestore API, then retry.'
            : error is FirebaseAuthException &&
                  error.code == 'configuration-not-found'
            ? 'Firebase Authentication configuration was not found for this app or provider.'
            : error is FirebaseException && error.code == 'unauthenticated'
            ? 'Your Firebase sign-in expired. Sign in again and retry.'
            : error is FirebaseException &&
                  (error.code == 'failed-precondition' ||
                      error.code == 'not-found')
            ? 'Cloud Firestore is not ready for this project. Check that its database has been created.'
            : error is FirebaseException && error.code == 'permission-denied'
            ? 'Firebase denied access to your profile. Check the deployed Firestore rules.'
            : error is FirebaseException &&
                  (error.code == 'unavailable' ||
                      error.code == 'network-request-failed')
            ? 'Firebase is temporarily unavailable. Check your connection and retry.'
            : 'Could not check your saved profile. Retry to continue.';
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(_check),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      final complete = _completedHere ?? (snapshot.data ?? false);
      if (!complete)
        return FinancialQaScreen(
          user: widget.user,
          onComplete: () => setState(() => _completedHere = true),
        );
      return ChangeNotifierProvider(
        key: ValueKey(widget.user.uid),
        create: (_) => DashboardProvider.forUser(widget.user.uid),
        child: const _UserPreferenceThemeBridge(child: MainNavScreen()),
      );
    },
  );
}

class _UserPreferenceThemeBridge extends StatelessWidget {
  const _UserPreferenceThemeBridge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Consumer2<DashboardProvider, ThemeProvider>(
        child: child,
        builder: (context, dashboard, theme, child) {
          if (dashboard.preferencesLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              final target = ThemeMode.values.firstWhere(
                (mode) => mode.name == dashboard.savedThemeMode,
                orElse: () => ThemeMode.system,
              );
              if (theme.themeMode != target) theme.setThemeMode(target);
            });
          }
          return child!;
        },
      );
}
