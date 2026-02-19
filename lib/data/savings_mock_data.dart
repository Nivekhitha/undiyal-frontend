import '../models/savings_model.dart';

final budgetOverview = BudgetOverview(
  monthlyBudget: 20000,
  totalSpent: 11874,
  remaining: 8126,
  percentage: 59,
  status: BudgetStatus.onTrack,
);

final savingsGoals = [
  SavingsGoal(
    id: '1',
    emoji: '🚗',
    name: 'Buy a Car',
    targetAmount: 600000,
    savedAmount: 420000,
    targetDate: 'May 2027',
    status: GoalStatus.onTrack,
    iconBg: '#EEF2FF',
    iconBorder: '#6366F1',
  ),
  SavingsGoal(
    id: '2',
    emoji: '🌴',
    name: 'Goa Trip',
    targetAmount: 50000,
    savedAmount: 32000,
    targetDate: 'December 2026',
    status: GoalStatus.ahead,
    iconBg: '#F0FDF4',
    iconBorder: '#22C55E',
  ),
  SavingsGoal(
    id: '3',
    emoji: '❄️',
    name: 'Emergency Fund',
    targetAmount: 100000,
    savedAmount: 68000,
    targetDate: 'no timeline',
    status: GoalStatus.onTrack,
    iconBg: '#FFF7ED',
    iconBorder: '#F97316',
  ),
];

final categoryBudgets = [
  CategoryBudget(
    id: '1',
    emoji: '🍕',
    name: 'Food & Dining',
    budgetLimit: 5000,
    spent: 3200,
    remaining: 1800,
    status: CategoryStatus.warning,
    suggestion: 'Cook at home 2x this week to save ~₹600. You\'re close to your limit!',
  ),
  CategoryBudget(
    id: '2',
    emoji: '🚗',
    name: 'Transport',
    budgetLimit: 2000,
    spent: 1200,
    remaining: 800,
    status: CategoryStatus.onTrack,
    suggestion: 'Great job! Try metro on weekends to save another ₹200.',
  ),
  CategoryBudget(
    id: '3',
    emoji: '🎬',
    name: 'Entertainment',
    budgetLimit: 3000,
    spent: 2800,
    remaining: 200,
    status: CategoryStatus.overspending,
    suggestion: 'You\'re almost over budget! Pause your streaming sub to save ₹499.',
  ),
  CategoryBudget(
    id: '4',
    emoji: '🛒',
    name: 'Shopping',
    budgetLimit: 4000,
    spent: 2700,
    remaining: 1300,
    status: CategoryStatus.onTrack,
    suggestion: 'Wait 24hrs before impulse buys. You could save ₹500+ this month.',
  ),
];

final smartSuggestions = [
  SmartSuggestion(
    id: '1',
    title: 'Cook at home twice this week',
    estimatedSavings: 600,
    difficulty: Difficulty.easy,
    explanation: 'Replacing 2 outside meals saves you roughly ₹600 this week.',
  ),
  SmartSuggestion(
    id: '2',
    title: 'Use public transport on weekends',
    estimatedSavings: 400,
    difficulty: Difficulty.medium,
    explanation: 'Switching from cabs to bus/metro on weekends adds up fast.',
  ),
  SmartSuggestion(
    id: '3',
    title: 'Pause streaming subscription',
    estimatedSavings: 499,
    difficulty: Difficulty.easy,
    explanation: 'You watched only 2 hours last month. Pause and save ₹499.',
  ),
];

final weeklyCheckin = WeeklyCheckin(
  weeklyTarget: 2000,
  actualSavings: 1400,
  status: CheckinStatus.behind,
  recoverySuggestion: 'Skip 1 food delivery → Save ₹300',
);

final dailySpending = DailySpending(
  planned: 650,
  actual: 780,
  predictedOvershoot: 1950,
);

final goalInsight = GoalInsight(
  message: 'Saving ₹600 on food helps your Goa Trip goal reach 60%!',
  linkedGoal: 'Goa Trip',
);
