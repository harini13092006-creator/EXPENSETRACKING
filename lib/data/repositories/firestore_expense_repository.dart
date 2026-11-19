import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/data/models/budget_model.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/data/models/user_profile.dart';
import 'package:expensetracker/data/repositories/budget_repository.dart';
import 'package:expensetracker/data/repositories/transaction_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// All references are rooted below users/{uid}. Ownership is also enforced by
/// Firestore rules; this guard prevents a stale provider writing after sign-out.
class FirestoreExpenseRepository {
  FirestoreExpenseRepository({
    required this.uid,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final String uid;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _transactions =>
      _user.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _categories =>
      _user.collection('categories');
  CollectionReference<Map<String, dynamic>> get _budgets =>
      _user.collection('budgets');

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

  Future<T> _traceFirestore<T>(
    String operation,
    String path,
    Future<T> Function() request,
  ) async {
    final projectId = Firebase.apps.isEmpty
        ? 'unavailable'
        : Firebase.app().options.projectId;
    debugPrint(
      '[Firestore] operation=$operation started uid=${_auth.currentUser?.uid ?? 'none'} projectId=$projectId path=$path requestReachedFirebase=pending',
    );
    try {
      final result = await request();
      debugPrint(
        '[Firestore] operation=$operation succeeded uid=${_auth.currentUser?.uid ?? 'none'} projectId=$projectId path=$path requestReachedFirebase=yes',
      );
      return result;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[Firestore] operation=$operation failed uid=${_auth.currentUser?.uid ?? 'none'} projectId=$projectId path=$path plugin=${error.plugin} FirebaseException.code=${error.code} message=${error.message ?? 'none'} requestReachedFirebase=${_requestReachedFirebase(error)}\n$stackTrace',
      );
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        '[Firestore] operation=$operation failed uid=${_auth.currentUser?.uid ?? 'none'} projectId=$projectId path=$path type=${error.runtimeType} message=$error requestReachedFirebase=unknown\n$stackTrace',
      );
      rethrow;
    }
  }

  void _checkOwner() {
    if (_auth.currentUser?.uid != uid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'user-changed',
        message: 'The signed-in account changed.',
      );
    }
  }

  Future<void> ensureProfile(User authUser) async {
    _checkOwner();
    final profile = await _traceFirestore(
      'profile.get',
      _user.path,
      () => _user.get(),
    );
    final batch = _db.batch();
    var writes = 0;
    if (!profile.exists) {
      batch.set(_user, {
        'uid': uid,
        'fullName': authUser.displayName ?? '',
        if (authUser.email != null) 'email': authUser.email,
        if (authUser.photoURL != null) 'photoUrl': authUser.photoURL,
        'currencyCode': 'INR',
        'savingsGoal': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      writes++;
    }
    final currentCategories = await _traceFirestore(
      'categories.list',
      _categories.path,
      () => _categories.get(),
    );
    final presentIds = currentCategories.docs.map((doc) => doc.id).toSet();
    for (final category in CategoryCatalog.allCategories) {
      if (presentIds.contains(category.id)) continue;
      batch.set(_categories.doc(category.id), {
        'name': category.name,
        'type': category.isExpense ? 'expense' : 'income',
        'iconCodePoint': category.icon.codePoint,
        'colorValue': category.color.toARGB32(),
        'monthlyBudget': 0.0,
        'isDefault': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      writes++;
    }
    final preferencesRef = _user.collection('settings').doc('preferences');
    final preferences = await _traceFirestore(
      'preferences.get',
      preferencesRef.path,
      () => preferencesRef.get(),
    );
    if (!preferences.exists) {
      batch.set(preferencesRef, {
        'currencyCode': (profile.data()?['currencyCode'] as String?) ?? 'INR',
        'themeMode': 'system',
        'notificationsEnabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      writes++;
    }
    if (writes > 0) await batch.commit();
  }

  /// Atomically saves the user's reviewed profile and current-month budget.
  /// Existing createdAt values are preserved; new documents receive server time.
  Future<void> saveOnboardingProfile({
    required User authUser,
    required String fullName,
    required int? age,
    required String occupation,
    required double monthlyIncome,
    required double monthlyBudget,
    required double savingsTarget,
    required String financialGoal,
    required String regularExpenses,
    required List<String> categories,
  }) async {
    if (authUser.uid != uid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'user-changed',
        message: 'The signed-in account changed.',
      );
    }
    final now = DateTime.now();
    final budget = _budgets.doc(
      '${now.year}-${now.month.toString().padLeft(2, '0')}',
    );
    var operation = 'profile.get';
    var path = _user.path;
    await _traceFirestore<
      void
    >('onboarding.save', '${_user.path} and ${budget.path}', () async {
      _checkOwner();
      try {
        await _db.runTransaction<void>((transaction) async {
          _checkOwner();
          operation = 'profile.get';
          path = _user.path;
          debugPrint(
            '[Firestore] operation=$operation started uid=$uid projectId=${Firebase.app().options.projectId} path=$path',
          );
          final existingProfile = await transaction.get(_user);
          operation = 'budget.get';
          path = budget.path;
          debugPrint(
            '[Firestore] operation=$operation started uid=$uid projectId=${Firebase.app().options.projectId} path=$path',
          );
          final existingBudget = await transaction.get(budget);

          final profileCreatedAt = existingProfile.data()?['createdAt'];
          final budgetCreatedAt = existingBudget.data()?['createdAt'];
          final profileData = <String, dynamic>{
            'uid': uid,
            'name': fullName.trim(),
            'fullName': fullName.trim(),
            'age': age,
            'occupation': occupation.trim(),
            'email': authUser.email ?? '',
            'monthlyIncome': monthlyIncome,
            'monthlyBudget': monthlyBudget,
            'savingsTarget': savingsTarget,
            'savingsGoal': savingsTarget,
            'currency': 'INR',
            'currencyCode': 'INR',
            'financialGoal': financialGoal.trim(),
            'goal': financialGoal.trim(),
            'primaryGoal': financialGoal.trim(),
            'regularExpenses': regularExpenses.trim(),
            'categories': categories,
            'preferredCategories': categories,
            'onboardingCompleted': true,
            'createdAt': profileCreatedAt is Timestamp
                ? profileCreatedAt
                : FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          final budgetData = <String, dynamic>{
            'year': now.year,
            'month': now.month,
            'amount': monthlyBudget,
            'createdAt': budgetCreatedAt is Timestamp
                ? budgetCreatedAt
                : FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          operation = existingProfile.exists
              ? 'profile.update+budget.set'
              : 'profile.create+budget.set';
          path = '${_user.path} and ${budget.path}';
          transaction.set(_user, profileData, SetOptions(merge: true));
          transaction.set(budget, budgetData, SetOptions(merge: true));
        });
      } on FirebaseException catch (error, stackTrace) {
        debugPrint(
          '[Firestore] operation=$operation failed uid=$uid projectId=${Firebase.app().options.projectId} path=$path plugin=${error.plugin} FirebaseException.code=${error.code} message=${error.message ?? 'none'} requestReachedFirebase=${_requestReachedFirebase(error)}\n$stackTrace',
        );
        rethrow;
      }
    });
  }

  Stream<UserProfile?> watchProfile() => _user.snapshots().map(
    (doc) => doc.exists ? UserProfile.fromMap(doc.data()!, uid) : null,
  );

  Future<void> updateProfile({
    required String fullName,
    required String currencyCode,
    required double savingsGoal,
    String? photoUrl,
  }) async {
    _checkOwner();
    final oldData = (await _traceFirestore(
      'profile.get',
      _user.path,
      () => _user.get(),
    )).data();
    await _traceFirestore(
      'profile.update',
      _user.path,
      () => _user.set({
        'uid': uid,
        'name': fullName.trim(),
        'fullName': fullName.trim(),
        if (_auth.currentUser?.email != null) 'email': _auth.currentUser!.email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'currency': currencyCode,
        'currencyCode': currencyCode,
        'savingsTarget': savingsGoal,
        'savingsGoal': savingsGoal,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': oldData?['createdAt'] ?? FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  Future<void> updateEmailInProfile(String email) async {
    _checkOwner();
    await _user.update({
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategoryBudget(String categoryId, double amount) async {
    _checkOwner();
    await _categories.doc(categoryId).update({
      'monthlyBudget': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<TransactionModel>> watchTransactions() =>
      _transactions.snapshots().map((snapshot) {
        final items = snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
            .toList();
        items.sort((a, b) => b.date.compareTo(a.date));
        return items;
      });

  Future<String> addTransaction(TransactionModel transaction) async {
    final ref = _transactions.doc();
    await _traceFirestore('transaction.create', ref.path, () async {
      _checkOwner();
      await ref.set(transaction.toFirestore());
    });
    return ref.id;
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    _checkOwner();
    final id = transaction.id?.toString();
    if (id == null || id.isEmpty)
      throw ArgumentError('Transaction ID is required.');
    final ref = _transactions.doc(id);
    await _traceFirestore('transaction.update', ref.path, () async {
      _checkOwner();
      await ref.update({
        ...transaction.toFirestore(),
        'createdAt': transaction.createdAt,
      });
    });
  }

  Future<void> deleteTransaction(String id) async {
    final ref = _transactions.doc(id);
    await _traceFirestore('transaction.delete', ref.path, () async {
      _checkOwner();
      await ref.delete();
    });
  }

  Stream<List<BudgetModel>> watchBudgets() => _budgets.snapshots().map(
    (snapshot) => snapshot.docs
        .map((doc) => BudgetModel.fromFirestore(doc.id, doc.data()))
        .toList(),
  );

  Future<void> setBudget(BudgetModel budget) async {
    _checkOwner();
    final id = '${budget.year}-${budget.month.toString().padLeft(2, '0')}';
    final ref = _budgets.doc(id);
    final old = await ref.get();
    await ref.set({
      'month': budget.month,
      'year': budget.year,
      'amount': budget.amount,
      'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CategoryItem>> watchCategories() => _categories.snapshots().map((
    snapshot,
  ) {
    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      final color = Color((data['colorValue'] as num?)?.toInt() ?? 0xFF087F5B);
      final isExpense = (data['type'] as String? ?? 'expense') == 'expense';
      return CategoryItem(
        id: doc.id,
        name:
            doc.id == CategoryCatalog.healthcare.id && data['isDefault'] == true
            ? 'Health'
            : data['name'] as String? ?? 'Category',
        icon: CategoryCatalog.iconForCodePoint(
          (data['iconCodePoint'] as num?)?.toInt() ?? Icons.category.codePoint,
        ),
        color: color,
        backgroundColor: color.withValues(alpha: .12),
        isExpense: isExpense,
        monthlyBudget: (data['monthlyBudget'] as num?)?.toDouble() ?? 0,
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    return items;
  });

  Future<void> saveCategory(
    CategoryItem category, {
    double monthlyBudget = 0,
  }) async {
    _checkOwner();
    final ref = _categories.doc(category.id);
    final old = await ref.get();
    await ref.set({
      'name': category.name.trim(),
      'type': category.isExpense ? 'expense' : 'income',
      'iconCodePoint': category.icon.codePoint,
      'colorValue': category.color.toARGB32(),
      'monthlyBudget': monthlyBudget,
      'isDefault': old.data()?['isDefault'] ?? false,
      'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategory(String id) async {
    _checkOwner();
    await _categories.doc(id).delete();
  }

  Future<void> savePreferences({
    required String currencyCode,
    required String themeMode,
    required bool notificationsEnabled,
  }) async {
    _checkOwner();
    final ref = _user.collection('settings').doc('preferences');
    final old = await ref.get();
    await ref.set({
      'currencyCode': currencyCode,
      'themeMode': themeMode,
      'notificationsEnabled': notificationsEnabled,
      'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<Map<String, dynamic>?> watchPreferences() => _user
      .collection('settings')
      .doc('preferences')
      .snapshots()
      .map((snapshot) => snapshot.data());

  Future<List<TransactionModel>> getAllTransactions() async {
    _checkOwner();
    final snapshot = await _transactions.get();
    final items = snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc.id, doc.data()))
        .toList();
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<List<BudgetModel>> getAllBudgets() async {
    _checkOwner();
    final snapshot = await _budgets.get();
    return snapshot.docs
        .map((doc) => BudgetModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Future<void> deleteAllUserData() async {
    _checkOwner();
    for (final collection in [
      _transactions,
      _categories,
      _budgets,
      _user.collection('settings'),
    ]) {
      while (true) {
        final page = await collection.limit(400).get();
        if (page.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (page.docs.length < 400) break;
      }
    }
    await _user.delete();
  }

  Future<void> deleteProfilePhoto() async {
    _checkOwner();
    try {
      await FirebaseStorage.instance.ref('users/$uid/profile/avatar').delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}

class FirestoreTransactionRepository implements TransactionRepository {
  FirestoreTransactionRepository(this.cloud);
  final FirestoreExpenseRepository cloud;

  @override
  Future<void> addTransaction(TransactionModel transaction) async {
    await cloud.addTransaction(transaction);
  }

  @override
  Future<int> insertTransaction(TransactionModel transaction) async {
    await cloud.addTransaction(transaction);
    return 1;
  }

  @override
  Future<int> updateTransaction(TransactionModel transaction) async {
    await cloud.updateTransaction(transaction);
    return 1;
  }

  @override
  Future<int> deleteTransaction(dynamic id) async {
    await cloud.deleteTransaction(id.toString());
    return 1;
  }

  @override
  Future<List<TransactionModel>> getAllTransactions() =>
      cloud.getAllTransactions();
  @override
  Future<List<TransactionModel>> getMonthlyTransactions(
    int month,
    int year,
  ) async => (await cloud.getAllTransactions())
      .where((item) => item.date.month == month && item.date.year == year)
      .toList();
  @override
  Future<TransactionModel?> getTransactionById(int id) async {
    final matches = (await cloud.getAllTransactions()).where(
      (item) => item.id.toString() == id.toString(),
    );
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<Map<String, double>> getCategoryExpenseTotals(
    int month,
    int year,
  ) async => _totals(await getMonthlyTransactions(month, year));
  @override
  Future<Map<String, double>> getAllCategoryExpenseTotals() async =>
      _totals(await cloud.getAllTransactions());

  Map<String, double> _totals(List<TransactionModel> transactions) {
    final totals = <String, double>{};
    for (final transaction in transactions.where((item) => item.isExpense)) {
      totals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return totals;
  }
}

class FirestoreBudgetRepository implements BudgetRepository {
  FirestoreBudgetRepository(this.cloud);
  final FirestoreExpenseRepository cloud;
  @override
  Future<BudgetModel?> getBudget(int month, int year) async {
    for (final budget in await cloud.getAllBudgets()) {
      if (budget.month == month && budget.year == year) return budget;
    }
    return null;
  }

  @override
  Future<int> setBudget(BudgetModel budget) async {
    await cloud.setBudget(budget);
    return 1;
  }

  @override
  Future<List<BudgetModel>> getAllBudgets() => cloud.getAllBudgets();
}
