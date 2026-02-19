class BudgetOverview {
  final double monthlyBudget;
  final double totalSpent;
  final double remaining;
  final int percentage;
  final BudgetStatus status;

  BudgetOverview({
    required this.monthlyBudget,
    required this.totalSpent,
    required this.remaining,
    required this.percentage,
    required this.status,
  });
}

enum BudgetStatus { onTrack, slightlyBehind, overspending }

class SavingsGoal {
  final String id;
  final String emoji;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final String targetDate;
  final GoalStatus status;
  final String iconBg;
  final String iconBorder;

  SavingsGoal({
    required this.id,
    required this.emoji,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.targetDate,
    required this.status,
    required this.iconBg,
    required this.iconBorder,
  });

  double get percentage => (savedAmount / targetAmount) * 100;
  double get toGo => targetAmount - savedAmount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emoji': emoji,
      'name': name,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'targetDate': targetDate,
      'status': status.toString().split('.').last,
      'iconBg': iconBg,
      'iconBorder': iconBorder,
    };
  }

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'],
      emoji: json['emoji'],
      name: json['name'],
      targetAmount: json['targetAmount'],
      savedAmount: json['savedAmount'],
      targetDate: json['targetDate'],
      status: GoalStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
      iconBg: json['iconBg'],
      iconBorder: json['iconBorder'],
    );
  }
}

enum GoalStatus { onTrack, behind, ahead }

class CategoryBudget {
  final String id;
  final String emoji;
  final String name;
  final double budgetLimit;
  final double spent;
  final double remaining;
  final CategoryStatus status;
  final String suggestion;

  CategoryBudget({
    required this.id,
    required this.emoji,
    required this.name,
    required this.budgetLimit,
    required this.spent,
    required this.remaining,
    required this.status,
    required this.suggestion,
  });

  double get percentage => (spent / budgetLimit) * 100;
}

enum CategoryStatus { onTrack, warning, overspending }

class SmartSuggestion {
  final String id;
  final String title;
  final double estimatedSavings;
  final Difficulty difficulty;
  final String explanation;

  SmartSuggestion({
    required this.id,
    required this.title,
    required this.estimatedSavings,
    required this.difficulty,
    required this.explanation,
  });
}

enum Difficulty { easy, medium, hard }

class WeeklyCheckin {
  final double weeklyTarget;
  final double actualSavings;
  final CheckinStatus status;
  final String? recoverySuggestion;

  WeeklyCheckin({
    required this.weeklyTarget,
    required this.actualSavings,
    required this.status,
    this.recoverySuggestion,
  });

  double get percentage => (actualSavings / weeklyTarget) * 100;
}

enum CheckinStatus { onTrack, behind }

class DailySpending {
  final double planned;
  final double actual;
  final double predictedOvershoot;

  DailySpending({
    required this.planned,
    required this.actual,
    required this.predictedOvershoot,
  });
}

class GoalInsight {
  final String message;
  final String linkedGoal;

  GoalInsight({
    required this.message,
    required this.linkedGoal,
  });
}
