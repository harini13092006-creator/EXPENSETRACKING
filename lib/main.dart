import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:expensetracker/app.dart';
import 'package:expensetracker/features/auth/screens/firebase_setup_screen.dart';
import 'package:expensetracker/features/auth/screens/session_gate.dart';
import 'package:expensetracker/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Widget home;
  try {
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          )
        : Firebase.app();
    debugPrint(
      '[Firebase] initialization status=success projectId=${app.options.projectId}',
    );
    home = const SessionGate();
  } on FirebaseException catch (error, stackTrace) {
    debugPrint(
      '[Firebase] initialization failed projectId=${Firebase.apps.isEmpty ? DefaultFirebaseOptions.currentPlatform.projectId : Firebase.app().options.projectId} plugin=${error.plugin} code=${error.code} message=${error.message ?? 'none'} uid=${Firebase.apps.isEmpty ? 'none' : FirebaseAuth.instance.currentUser?.uid ?? 'none'} requestReachedFirebase=false\n$stackTrace',
    );
    home = FirebaseSetupScreen(
      error: error.message ?? error.code,
      onRetry: () async {
        final app = Firebase.apps.isEmpty
            ? await Firebase.initializeApp(
                options: DefaultFirebaseOptions.currentPlatform,
              )
            : Firebase.app();
        debugPrint(
          '[Firebase] retry initialization succeeded projectId=${app.options.projectId}',
        );
        runApp(ExpenseTrackerApp(home: const SessionGate()));
      },
    );
  } catch (error, stackTrace) {
    debugPrint(
      '[Firebase] initialization failed type=${error.runtimeType} message=$error projectId=${Firebase.apps.isEmpty ? DefaultFirebaseOptions.currentPlatform.projectId : Firebase.app().options.projectId} uid=none requestReachedFirebase=false\n$stackTrace',
    );
    home = FirebaseSetupScreen(
      error: error.toString(),
      onRetry: () async {
        final app = Firebase.apps.isEmpty
            ? await Firebase.initializeApp(
                options: DefaultFirebaseOptions.currentPlatform,
              )
            : Firebase.app();
        debugPrint(
          '[Firebase] retry initialization succeeded projectId=${app.options.projectId}',
        );
        runApp(ExpenseTrackerApp(home: const SessionGate()));
      },
    );
  }

  runApp(ExpenseTrackerApp(home: home));
}
