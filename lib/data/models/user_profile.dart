class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.photoUrl,
    required this.currencyCode,
    required this.savingsGoal,
    this.age,
    this.occupation = '',
    this.monthlyIncome = 0,
    this.monthlyBudget = 0,
    this.primaryGoal = '',
    this.regularExpenses = '',
    this.preferredCategories = const [],
    this.onboardingCompleted = false,
  });

  final String uid;
  final String fullName;
  final String? email;
  final String? photoUrl;
  final String currencyCode;
  final double savingsGoal;
  final int? age;
  final String occupation;
  final double monthlyIncome;
  final double monthlyBudget;
  final String primaryGoal;
  final String regularExpenses;
  final List<String> preferredCategories;
  final bool onboardingCompleted;

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) =>
      UserProfile(
        uid: uid,
        fullName: map['fullName'] is String
            ? map['fullName'] as String
            : map['name'] is String
            ? map['name'] as String
            : '',
        email: map['email'] is String ? map['email'] as String : null,
        photoUrl: map['photoUrl'] is String ? map['photoUrl'] as String : null,
        currencyCode: map['currencyCode'] is String
            ? map['currencyCode'] as String
            : map['currency'] is String
            ? map['currency'] as String
            : 'INR',
        savingsGoal: ((map['savingsGoal'] ?? map['savingsTarget']) is num)
            ? ((map['savingsGoal'] ?? map['savingsTarget']) as num).toDouble()
            : 0,
        age: map['age'] is num ? (map['age'] as num).toInt() : null,
        occupation: map['occupation'] is String
            ? map['occupation'] as String
            : '',
        monthlyIncome: map['monthlyIncome'] is num
            ? (map['monthlyIncome'] as num).toDouble()
            : 0,
        monthlyBudget: map['monthlyBudget'] is num
            ? (map['monthlyBudget'] as num).toDouble()
            : 0,
        primaryGoal: map['primaryGoal'] is String
            ? map['primaryGoal'] as String
            : map['financialGoal'] is String
            ? map['financialGoal'] as String
            : map['goal'] is String
            ? map['goal'] as String
            : '',
        regularExpenses: map['regularExpenses'] is String
            ? map['regularExpenses'] as String
            : '',
        preferredCategories:
            ((map['preferredCategories'] ?? map['categories']) is List)
            ? ((map['preferredCategories'] ?? map['categories']) as List)
                  .whereType<String>()
                  .toList()
            : const [],
        onboardingCompleted: map['onboardingCompleted'] is bool
            ? map['onboardingCompleted'] as bool
            : false,
      );
}
